This page describes how the container works internally. Useful for contributors, debugging, and understanding the boot sequence.

## Boot Sequence

The container uses [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision. Services start in a defined order:

```
entrypoint (container start)
  │
  ├─ init-adduser        Create nordvpn user/group
  ├─ init-createauth     Write credentials file (0600, owned by nordvpn)
  ├─ init-createmgmtpwfile  Generate management interface password
  ├─ init-firewall       Apply iptables rules (depends on entrypoint backend selection)
  ├─ init-setupcron      Configure cron jobs from RECREATE_VPN_CRON / CHECK_CONNECTION_CRON
  │
  ├─ svc-nordvpn         Main OpenVPN service (long-running)
  └─ svc-cron            Cron daemon (long-running)
```

## Key Scripts

### `entrypoint` — Backend selection & default-deny

Location: `/usr/local/bin/entrypoint`

1. Detects kernel version
2. Tests nft and legacy iptables backends by toggling a chain policy (`DROP` ↔ `ACCEPT` on `OUTPUT`)
3. If preferred backend fails, tests the fallback
4. If legacy is selected and nft tables already contain rules, flushes nft tables to avoid mixed stacks
5. Exports selected backends (`IPT`, `IP6T`) to `/run/xt/backend.env`
6. Sets `INPUT`, `OUTPUT`, `FORWARD` to `DROP` on both IPv4 and IPv6
7. Allows loopback traffic

Backend preference by kernel:

| Kernel version | Preferred backend | Fallback |
|---------------|-------------------|----------|
| ≥ 4.18 | nft (`iptables`) | legacy (`iptables-legacy`) |
| < 4.18 | legacy (`iptables-legacy`) | nft (`iptables`) |

### `backend-functions` — Shared utilities

Location: `/usr/local/bin/backend-functions`

Sourced by every script. Provides:
- `run4()` / `run6()` — Execute iptables commands with logging (non-fatal)
- `run4_critical()` / `run6_critical()` — Execute or sleep forever on failure
- `is_vpn_connected()` — Checks for tun0 interface
- `mgmt_cmd()` — Sends authenticated commands to OpenVPN management interface
- `log()` / `log_error()` / `log_warning()` — Timestamped logging
- `parse_cron()` — Converts cron expressions to human-readable descriptions

### `vpn-config` — Server selection

Location: `/usr/local/bin/vpn-config`

1. Resolves COUNTRY/CITY/GROUP/TECHNOLOGY to numeric IDs using JSON data files
2. Builds NordVPN API query URL
3. Fetches server list using pinned API IPs (no DNS)
4. Detects specific server hostnames and gives them `load=0`
5. Sorts by load (multi-location) or keeps API order (single location)
6. Applies `RANDOM_TOP` if set
7. Writes selected server's OpenVPN config to disk

For XOR technologies (`openvpn_xor_*`), the script also:
- Generates multiple `remote` lines from the XOR port list (with `remote-random`)
- Adds the `scramble obfuscate` directive with the XOR pre-shared key
- Swaps the `<tls-auth>` block with the XOR-specific key from `tls-auth-xor.pem`

### `svc-nordvpn/run` — OpenVPN launcher

Location: `/etc/s6-overlay/s6-rc.d/svc-nordvpn/run`

1. Calls `vpn-config` to get server configuration
2. Extracts VPN server IP/port/protocol from the OVPN file
3. Adds temporary firewall rules in `VPN-SERVER` chain for every `remote` line (XOR configs have multiple ports)
4. Appends `--data-ciphers` if not already set
5. Launches OpenVPN with auth, management port, and nordvpn group
6. Waits for tun0 interface (up to 60 seconds)
7. Optionally runs network diagnostics
8. Blocks on OpenVPN process

### `svc-nordvpn/finish` — Cleanup on disconnect

Location: `/etc/s6-overlay/s6-rc.d/svc-nordvpn/finish`

1. Flushes `VPN-SERVER` iptables chain
2. Sends SIGTERM via management interface (5-second timeout)
3. Removes OVPN config file

### `vpn-healthcheck` — Connection monitoring

Location: `/usr/local/bin/vpn-healthcheck`

1. Sends HTTP HEAD requests to configured URL(s)
2. Retries `CHECK_CONNECTION_ATTEMPTS` times with configurable interval
3. If all fail, calls `vpn-reconnect`

### `vpn-reconnect` — Service restart

Location: `/usr/local/bin/vpn-reconnect`

1. Stops `svc-nordvpn` via s6-rc
2. Waits 2 seconds
3. Restarts `svc-nordvpn`

### `network-diagnostic` — Debug tool

Location: `/usr/local/bin/network-diagnostic`

Two modes:
- `--basic`: Public IP + geolocation only
- `--full` (default): Complete diagnostics including interfaces, iptables rules, DNS, routes, OpenVPN status

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

## OpenVPN Management Interface

The container runs an OpenVPN management interface for status queries and graceful shutdown:

| Setting | Value |
|---------|-------|
| Host | `127.0.0.1` |
| Port | `7505` |
| Auth | Password from `/run/xt/mgmt-pw` |

Used internally by:
- `vpn-healthcheck` — queries connection state
- `network-diagnostic` — fetches uptime, remote IP, protocol details
- `svc-nordvpn/finish` — sends SIGTERM for graceful shutdown

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

### Phase 3 — svc-nordvpn (per-connection pinhole)

When OpenVPN connects:
- The VPN server IP/port gets a temporary rule in the `VPN-SERVER` chain
- For XOR technologies, multiple rules are added (one per `remote` port — see [Technologies](Technologies#multi-port-behavior) for port lists)
- When the connection drops, `svc-nordvpn/finish` flushes that chain

## Firewall Chain Structure

```
INPUT chain:  ACCEPT lo → ACCEPT ESTABLISHED,RELATED → [NETWORK CIDRs] → DROP
OUTPUT chain: ACCEPT lo → ACCEPT ESTABLISHED,RELATED → VPN-SERVER → [NETWORK CIDRs] → ACCEPT tun0 → [NORDVPNAPI IPs] → DROP
FORWARD chain: ACCEPT ESTABLISHED,RELATED → ACCEPT tun0 → DROP

VPN-SERVER chain: [temporary rules for current VPN server IP:port(s) — one rule per remote line]

NAT/POSTROUTING: MASQUERADE on tun0
```
