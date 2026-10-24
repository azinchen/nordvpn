This page describes how the container works internally. Useful for contributors, debugging, and understanding the boot sequence.

## Boot Sequence

The container uses [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision. Services start in a defined order:

```
entrypoint (container start)
  │
  ├─ init-firewall       Apply iptables rules (depends on entrypoint backend selection)
  ├─ init-createauth     Write credentials file (0600, owned by nordvpn); with TOKEN,
  │                      fetches service credentials from the NordVPN API first
  │                      (runs after init-firewall so the API pinholes exist)
  ├─ init-createmgmtpwfile  Generate management interface password (after init-createauth,
  │                      so TOKEN-fetched credentials are available)
  ├─ init-setupcron      Configure cron jobs from RECREATE_VPN_CRON / CHECK_CONNECTION_CRON
  │
  ├─ svc-nordvpn         Main OpenVPN service (long-running)
  └─ svc-cron            Cron daemon (long-running; starts after svc-nordvpn so
                         scheduled jobs cannot fire before the first connect attempt)
```

Two more pieces run outside the s6 service tree:

- **OpenVPN script hooks** — `template.ovpn` carries `script-security 2`, `up /etc/openvpn/up.sh` and `down /etc/openvpn/down.sh`, so OpenVPN itself runs them on every (re)connect and teardown. See [`up.sh` / `down.sh`](#upsh--downsh--pushed-dns-and-resolvconf) below.
- **Docker `HEALTHCHECK`** — the image declares `HEALTHCHECK CMD /usr/local/bin/vpn-healthcheck-probe` (every 60 s, 15 s timeout, 60 s start period, 3 retries). Docker runs it independently of s6. See [`vpn-healthcheck-probe`](#vpn-healthcheck-probe--docker-healthcheck).

## Key Scripts

### `entrypoint` — Backend selection & default-deny

Location: `/usr/local/bin/entrypoint`

1. Detects kernel version
2. Tests nft and legacy iptables backends by toggling a chain policy (`DROP` ↔ `ACCEPT` on `OUTPUT`)
3. If preferred backend fails, tests the fallback
4. If legacy is selected and nft tables already contain rules, flushes nft tables to avoid mixed stacks
5. Exports selected backends (`IPT`, `IP6T`) to `/run/xt/backend.env`
6. Sets `INPUT`, `OUTPUT`, `FORWARD` to `DROP` on both IPv4 and IPv6
7. Flushes any pre-existing filter and NAT rules for both families
8. Allows loopback traffic

Backend preference by kernel:

| Kernel version | Preferred backend | Fallback |
|---------------|-------------------|----------|
| ≥ 4.18 | nft (`iptables`) | legacy (`iptables-legacy`) |
| < 4.18 | legacy (`iptables-legacy`) | nft (`iptables`) |

### `backend-functions` — Shared utilities

Location: `/usr/local/bin/backend-functions`

Sourced by every script. Provides:
- `run4()` / `run6()` — Execute iptables commands with logging (best-effort, always succeed)
- `run4_check()` — Like `run4` but propagates the real iptables status
- `run4_critical()` / `run6_critical()` — Execute or sleep forever on failure
- `is_vpn_connected()` — Checks for tun0 interface
- `is_mgmt_available()` — Checks whether the OpenVPN management port is listening
- `to_bool()` — Normalizes boolean variables (`true`/`1` → `true`, anything else → `false`)
- `nord_api_curl()` — Queries the NordVPN API via the bootstrap IPs (`NORDVPNAPI_IP`); no DNS dependency
- `fetch_token_credentials()` — Fetches service credentials from the API using `TOKEN` and writes the auth file
- `trim()` — Strips whitespace from list tokens (`;`/`,`-separated values)
- `mgmt_cmd()` — Sends authenticated commands to OpenVPN management interface
- `log()` / `log_error()` / `log_warning()` — Timestamped logging
- `parse_cron()` — Converts cron expressions to human-readable descriptions

In `TOKEN` mode the sourcing preamble also resolves `user`/`pass` from the fetched auth file, so every consumer (management password, diagnostics) sees valid credentials without `USER`/`PASS` being set.

### `vpn-config` — Server selection

Location: `/usr/local/bin/vpn-config`

1. Resolves COUNTRY/CITY/GROUP/TECHNOLOGY to numeric IDs using JSON data files
2. Builds NordVPN API query URL
3. Fetches server list using pinned API IPs (no DNS)
4. Resolves specific server hostnames (e.g. `us1234`) through the API; they join the pool with their real current load (see [Server Selection](Server-Selection#specific-server-hostname-format))
5. Sorts by load (multi-location) or keeps API order (single location)
6. Applies `RANDOM_TOP` if set
7. Writes selected server's OpenVPN config to disk (atomically, via a temp file)
8. Publishes the selection as `/run/xt/status.json` for monitoring

For XOR technologies (`openvpn_xor_*`), the script also:
- Generates multiple `remote` lines from the XOR port list (with `remote-random`)
- Adds the `scramble obfuscate` directive with the XOR pre-shared key
- Swaps the `<tls-auth>` block with the XOR-specific key from `tls-auth-xor.pem`

### `svc-nordvpn/run` — OpenVPN launcher

Location: `/etc/s6-overlay/s6-rc.d/svc-nordvpn/run`

1. In `TOKEN` mode, refreshes the service credentials from the NordVPN API (non-fatal; cached credentials are kept on failure)
2. Uses the config staged by `vpn-reconnect` if present, otherwise calls `vpn-config`
3. Extracts VPN server IP/port/protocol from the OVPN file
4. Adds temporary firewall rules in `VPN-SERVER` chain for every `remote` line (XOR configs have multiple ports)
5. Writes `OPENVPN_OPTS` to a config fragment (`/run/xt/openvpn-extra.conf`) that OpenVPN reads as a second `--config`; when `DNS` is set, appends the pull-filter/dhcp-option lines implementing the [custom DNS override](Custom-DNS). See [OpenVPN Options](OpenVPN-Options#how-openvpn-is-launched)
6. Launches OpenVPN with auth, management port, and nordvpn group, recording its PID in `/run/xt/openvpn.pid`
7. Waits for tun0 interface (up to 60 seconds)
8. Optionally runs network diagnostics
9. Blocks on OpenVPN process

### `svc-nordvpn/finish` — Cleanup on disconnect

Location: `/etc/s6-overlay/s6-rc.d/svc-nordvpn/finish`

1. Flushes `VPN-SERVER` iptables chain
2. Sends SIGTERM via management interface and polls for actual teardown (5-second cap)
3. If OpenVPN is still alive after the graceful window, escalates: SIGTERM by recorded PID, then SIGKILL (PID is validated against `/proc/<pid>/cmdline` first)
4. Removes the OVPN config file and pidfile

This is also the container's shutdown path: `docker stop` (SIGTERM to s6) runs `finish`, so the tunnel is torn down cleanly before the container exits.

### `vpn-healthcheck` — Connection monitoring

Location: `/usr/local/bin/vpn-healthcheck`

1. Sends HTTP HEAD requests to configured URL(s)
2. Retries `CHECK_CONNECTION_ATTEMPTS` times with configurable interval
3. If all fail, calls `vpn-reconnect`

Runs from cron (`CHECK_CONNECTION_CRON`); it does not use the management interface — the tunnel is judged by real HTTP requests only.

### `vpn-healthcheck-probe` — Docker HEALTHCHECK

Location: `/usr/local/bin/vpn-healthcheck-probe`

The command behind the image's `HEALTHCHECK` instruction. Unlike `vpn-healthcheck` it is observational only: no retry loop, no sleep, and it never calls `vpn-reconnect`.

1. Exits `0` (healthy) immediately unless `HEALTHCHECK_ENABLED=true`
2. Fails if `tun0` does not exist
3. Sends one short HEAD request (5 s timeout) per `CHECK_CONNECTION_URL` entry; healthy on the first 2xx/3xx answer, unhealthy otherwise

Docker's `--retries` absorbs transient blips. See [Docker Health Status](Automatic-Reconnection#docker-health-status).

### `vpn-reconnect` — Server rotation

Location: `/usr/local/bin/vpn-reconnect`

1. Takes an atomic lock (`/run/xt/vpn-reconnect.lock`) — a concurrent invocation (overlapping cron jobs, manual run) skips with a log line; a lock whose owner died is taken over
2. Selects the new server and builds the new config **while the current tunnel is still up** (`vpn-config --fail-fast`; a failed selection leaves the existing connection untouched)
3. Stages the new config and restarts `svc-nordvpn` — downtime is only the OpenVPN restart, not the API-bound server selection

### `network-diagnostic` — Debug tool

Location: `/usr/local/bin/network-diagnostic`

Two modes:
- `--basic`: Public IP + geolocation only
- `--full` (default): Complete diagnostics including interfaces, iptables rules, DNS, routes, OpenVPN status

See [Network Diagnostics Guide](Network-Diagnostics-Guide).

### `up.sh` / `down.sh` — Pushed DNS and resolv.conf

Location: `/etc/openvpn/up.sh`, `/etc/openvpn/down.sh`

OpenVPN runs `up.sh` once the tunnel is up and `down.sh` when it is torn down. OpenVPN scrubs the environment for these hooks, so both re-import `DNS`, `PEER_DNS`, `GATEWAY_DNS` and `FORWARD_FROM` from s6's `/run/s6/container_environment/` store.

`up.sh`:
1. Exits early when `DNS=off` (or the legacy `PEER_DNS=no`), leaving `/etc/resolv.conf` untouched
2. Backs up the current `/etc/resolv.conf` to `/etc/resolv.conf.ovpn-tun0`
3. Collects the `dhcp-option DNS` / `dhcp-option DOMAIN` values OpenVPN received — server-pushed, or injected via [`DNS`](Custom-DNS) / `OPENVPN_OPTS`
4. Calls `gateway-dns-update` with the nameserver list (see below)
5. Rewrites `/etc/resolv.conf` with the collected `nameserver` / `search` lines

`down.sh` restores the backup in place — it writes into the existing inode, because `/etc/resolv.conf` is normally a Docker-managed bind mount that cannot be replaced.

### `gateway-dns-update` — Client DNS redirect target

Location: `/usr/local/bin/gateway-dns-update`

Called by `up.sh` on every (re)connect. A no-op unless `GATEWAY_DNS=redirect` **and** `FORWARD_FROM` are set; otherwise it flushes the `GATEWAY-DNS` NAT chain and refills it with a DNAT to the first IPv4 resolver (`-m addrtype ! --dst-type LOCAL`, so queries aimed at a co-located resolver pass untouched). `PREROUTING` already jumps port-53 traffic from the `FORWARD_FROM` CIDRs into that chain, so this keeps [`GATEWAY_DNS=redirect`](VPN-Gateway-Mode#client-dns-gateway_dns) pointed at the current tunnel resolvers. Best-effort by design (`run4`, not `run4_critical`): it runs inside OpenVPN's up hook, where a hard failure would block the connect.

## Data Files

Located in `/usr/local/share/nordvpn/data/`:

| File | Purpose |
|------|---------|
| `countries.json` | Country name/code/ID mappings |
| `groups.json` | Server group definitions |
| `technologies.json` | VPN technology definitions |
| `template.ovpn` | Base OpenVPN configuration template |
| `tls-auth-xor.pem` | XOR-specific TLS pre-shared key (swapped in at runtime for XOR technologies) |

> **Origin of these files:** They are generated from NordVPN's own published material, not maintained by hand. The JSON files (`countries.json`, `groups.json`, `technologies.json`) come from the NordVPN public API (`https://api.nordvpn.com/`), and `template.ovpn` / `tls-auth-xor.pem` are derived from the official OpenVPN configuration files NordVPN distributes (`https://downloads.nordcdn.com/configs/`). The `.ovpn` template keeps NordVPN's settings, embedded CA certificate and `tls-auth` static key, with placeholders (`__PROTOCOL__`, `__REMOTES__`, `__SCRAMBLE__`, `__X509_NAME__`) that `vpn-config` substitutes at runtime. All of these are refreshed automatically by the [`maintenance-updates`](https://github.com/azinchen/nordvpn/actions/workflows/maintenance-updates.yml) GitHub Actions workflow, which opens a pull request when NordVPN changes its certificates, static key, API schema, or recommended options. **Do not edit them by hand** — manual changes are overwritten the next time the workflow runs.

## State Files

| Path | Purpose |
|------|---------|
| `/run/xt/backend.env` | Selected iptables backend (IPT, IP6T) |
| `/run/xt/nordvpn.ovpn` | Current server's OpenVPN config |
| `/run/xt/auth` | Credentials file (0600) |
| `/run/xt/mgmt-pw` | Management interface password |
| `/run/xt/status.json` | Last selected server as JSON (name, hostname, ip, protocol, technology, country, city, load, selected_at) — world-readable, for monitoring, e.g. `docker exec vpn cat /run/xt/status.json` |
| `/run/xt/openvpn.pid` | PID of the running OpenVPN process (used by `finish` for the hard-kill fallback) |
| `/run/xt/nordvpn.ovpn.staged` | Config pre-selected by `vpn-reconnect`, consumed by the next service start |
| `/run/xt/vpn-reconnect.lock/` | Lock directory serializing concurrent reconnections |
| `/run/xt/openvpn-extra.conf` | Config fragment holding `OPENVPN_OPTS` and the `DNS` override lines (0600) |
| `/etc/resolv.conf.ovpn-tun0` | Backup of the pre-connect `resolv.conf`, restored by `down.sh` |
| `/var/spool/cron/crontabs/root` | Crontab written by `init-setupcron` from `RECREATE_VPN_CRON` / `CHECK_CONNECTION_CRON` |

## OpenVPN Management Interface

The container runs an OpenVPN management interface for status queries and graceful shutdown:

| Setting | Value |
|---------|-------|
| Host | `127.0.0.1` |
| Port | `7505` |
| Auth | Password from `/run/xt/mgmt-pw` |

Used internally by:
- `network-diagnostic` — fetches uptime, remote IP, protocol details (`status`, `state`)
- `svc-nordvpn/finish` — sends `signal SIGTERM` for graceful shutdown

`vpn-healthcheck` and `vpn-healthcheck-probe` do **not** use it — they judge the tunnel by `tun0` and real HTTP requests.

Authentication flow: the `mgmt_cmd()` function connects via netcat, sends the password, waits for the prompt, sends the command, then quits.

## Firewall Build Phases

### Phase 1 — Entrypoint (default-deny)

The `entrypoint` script runs first and:
- Selects the iptables backend (nft or legacy — see [Firewall Backends](Firewall-Backends))
- Sets `INPUT`, `OUTPUT`, and `FORWARD` policies to `DROP` on both IPv4 and IPv6
- Allows loopback traffic (required for inter-process communication)

At this point, **all network traffic is blocked**.

### Phase 2 — init-firewall (allow VPN + exceptions)

The `init-firewall` service then:
- Detects the Docker network (eth0 subnet and gateway)
- Enables connection tracking (ESTABLISHED/RELATED)
- Sets up MASQUERADE on the tun0 (VPN) interface
- Creates a `VPN-SERVER` chain for temporary per-connection rules
- Adds NordVPN API IP exceptions (TCP/443 only) from `NORDVPNAPI_IP`
- If `NETWORK` is set, adds static routes and bidirectional allow rules for those CIDRs
- If `TTL_SET` / `TTL_INC` are set, adds the mangle rules that rewrite the TTL of traffic leaving via tun0 / arriving on eth0. Fatal on an invalid value or a rule the kernel refuses. See [TTL Tuning](VPN-Gateway-Mode#ttl-tuning-ttl_set--ttl_inc)
- If `FORWARD_FROM` is set, opens `FORWARD` for those CIDRs towards tun0 (plus the `ESTABLISHED,RELATED` return rule). Nothing else is forwarded, so with the tunnel down nothing leaks. See [VPN Gateway Mode](VPN-Gateway-Mode)
- If `GATEWAY_DNS` is not `off` (and `FORWARD_FROM` is set), adds the port-53 `PREROUTING` rules for the gateway clients: a jump into the `GATEWAY-DNS` chain (`redirect`), `REDIRECT` to this container (`local`) or `DNAT` to `GATEWAY_DNS_SERVER` (`forward`). In `forward` mode it also probes the `GATEWAY_DNS_SERVER` candidates and uses the first that answers, opens the eth0→eth0 hairpin in `FORWARD`, masquerades towards the resolver and pins a host route. An invalid mode is fatal. See [Client DNS](VPN-Gateway-Mode#client-dns-gateway_dns)

### Phase 3 — svc-nordvpn (per-connection pinhole)

When OpenVPN connects:
- The VPN server IP/port gets a temporary rule in the `VPN-SERVER` chain
- For XOR technologies, multiple rules are added (one per `remote` port — see [Technologies](Technologies#multi-port-behavior) for port lists)
- When the connection drops, `svc-nordvpn/finish` flushes that chain

## Firewall Chain Structure

Items in `[brackets]` exist only when the corresponding variable is set.

```
filter/INPUT:    ACCEPT lo → ACCEPT ESTABLISHED,RELATED → [NETWORK CIDRs in eth0]
                 → [GATEWAY_DNS=local: port 53 from FORWARD_FROM] → DROP
filter/OUTPUT:   ACCEPT lo → ACCEPT ESTABLISHED,RELATED → ACCEPT out tun0
                 → VPN-SERVER (udp/tcp out eth0) → [NORDVPNAPI_IP tcp/443]
                 → [NETWORK CIDRs out eth0] → DROP
filter/FORWARD:  [FORWARD_FROM → tun0] → [tun0 → FORWARD_FROM ESTABLISHED,RELATED]
                 → [GATEWAY_DNS=forward: eth0 → eth0 hairpin to GATEWAY_DNS_SERVER] → DROP

VPN-SERVER:      temporary rules for the current VPN server IP:port(s) — one per remote line

nat/PREROUTING:  [GATEWAY_DNS: port 53 from FORWARD_FROM → GATEWAY-DNS chain | REDIRECT | DNAT]
nat/POSTROUTING: MASQUERADE out tun0 → [GATEWAY_DNS=forward: MASQUERADE towards GATEWAY_DNS_SERVER]
GATEWAY-DNS:     [GATEWAY_DNS=redirect: DNAT to the current tunnel resolver, refilled on every connect]

mangle:          [TTL_INC: PREROUTING in eth0 → TTL --ttl-inc] [TTL_SET: POSTROUTING out tun0 → TTL --ttl-set]

IPv6 (when ip6tables is usable): INPUT/OUTPUT/FORWARD policy DROP, no exceptions — see IPv6 Configuration
```

See also [Security Model](Security-Model), [Firewall Backends](Firewall-Backends) and [IPv6 Configuration](IPv6-Configuration).
