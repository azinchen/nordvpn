[![logo](https://github.com/azinchen/nordvpn/raw/master/NordVpn_logo.png)](https://www.nordvpn.com/)

# NordVPN OpenVPN Docker Container

[![GitHub release][github-release]][github-releases]
[![GitHub release date][github-releasedate]][github-releases]
[![GitHub build][github-build]][github-actions]<br>
[![GitHub stars][github-stars]][github-link]
[![GitHub forks][github-forks]][github-link]
[![Open issues][github-issues]][github-issues-link]
[![GitHub last commit][github-lastcommit]][github-link]<br>
[![Docker pulls][dockerhub-pulls]][dockerhub-link]
[![Docker stars][dockerhub-stars]][dockerhub-link]
[![Docker image size][dockerhub-size]][dockerhub-link]<br>
[![Multi-arch][multiarch-badge]][wiki-platforms]

OpenVPN client docker container that routes other containers' traffic through NordVPN servers automatically.

> **Prefer WireGuard?** This has a sibling project, [**azinchen/nordvpn-wg**](https://github.com/azinchen/nordvpn-wg) — the same auto-routing NordVPN container over WireGuard (NordLynx). Both share the same configuration model and feature set.

## ✨ Key Features

- **🚀 Easy Setup** — Route any container's traffic through VPN with `--net=container:vpn`
- **🌍 Server Selection** — Auto-select servers by country, city, group, or specific hostname ([details][wiki-server])
- **⚖️ Load Balancing** — Sorts by server load when multiple locations are given ([details][wiki-server-behavior])
- **🔑 Access Token** — Pass `TOKEN` and the container fetches the service credentials itself ([details][wiki-credentials])
- **🔄 Automatic Reconnection** — Periodic server switching and health monitoring ([details][wiki-reconnect])
- **🕵️ XOR Obfuscation** — Built-in XOR patches disguise OpenVPN traffic to bypass DPI ([details][wiki-xor])
- **🛡️ Kill Switch** — Default-deny firewall blocks all traffic when VPN is down ([details][wiki-security])
- **🏠 Local Network Access** — Allow specific CIDRs with `NETWORK=...` ([details][wiki-network])
- **🧭 Custom DNS** — Resolve through the tunnel; override with `DNS=...` ([details][wiki-custom-dns])
- **📵 IPv6 Configuration** — Built-in chains default to DROP ([details][wiki-ipv6])
- **🧱 Firewall Backends** — Auto-selects nft or legacy backend ([details][wiki-firewall])
- **🚪 VPN Gateway Mode** — Route downstream subnets through the tunnel with `FORWARD_FROM` ([details][wiki-gateway])
- **🪜 TTL Tuning** — `TTL_SET` / `TTL_INC` hide cascade hops from client traceroutes ([details][wiki-ttl])
- **🩺 Docker Health Status** — Opt-in `HEALTHCHECK` reports tunnel state to Docker ([details][wiki-healthcheck])
- **🔎 Network Diagnostics** — Built-in network diagnostic tool and `status.json` status file ([details][wiki-diagnostics])

> **📖 [Full documentation on the Wiki][wiki-home]** — configuration guides, examples, troubleshooting, FAQ, and architecture.

---

## 🚀 Quick Start

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e USER=service_username -e PASS=service_password \
           azinchen/nordvpn
```

Route other containers through VPN:
```bash
docker run --net=container:vpn -d your/application
```

Also available from GitHub Container Registry: `ghcr.io/azinchen/nordvpn`

### Requirements

- Docker with `--cap-add=NET_ADMIN` and `--device /dev/net/tun`
- **NordVPN service credentials** or an **access token** (not regular account credentials)

### Getting Service Credentials

1. Log into your [Nord Account Dashboard](https://my.nordaccount.com/)
2. Click on **NordVPN** → **Advanced Settings** → **Set up NordVPN manually**
3. Go to the **Service credentials** tab
4. Copy the **Username** and **Password** shown there

> **Note**: These are different from your regular NordVPN login credentials.

**Alternative — access token:** instead of copying the service credentials, generate an access token (**Nord Account Dashboard** → **NordVPN** → **Advanced Settings** → **Generate new token**) and pass it as `TOKEN`; the container then fetches the service credentials from the NordVPN API at startup. If `USER`/`PASS` are also set, they take priority over the token.

## 🐳 Docker Compose Example

```yaml
services:
  vpn:
    image: azinchen/nordvpn:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - USER=service_username
      - PASS=service_password
      # - TOKEN=access_token       # alternative to USER/PASS
      - COUNTRY=United States;CA
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=0 */6 * * *
      - NETWORK=192.168.1.0/24
    ports:
      - "8080:80"                  # host:container — use your app's listening port
    restart: unless-stopped

  app:
    image: nginx:alpine
    network_mode: "service:vpn"
    depends_on:
      - vpn
    restart: unless-stopped
```

> **More examples:** [Docker Compose][wiki-compose] · [Docker Run][wiki-run]

## ⚙️ Environment Variables

Grouped by feature; every variable is one line here — the linked wiki pages have the full descriptions. List values (countries, cities, CIDRs, URLs, IPs) accept `;` or `,` as separators; whitespace around separators is ignored.

### Credentials — [details][wiki-credentials]

| Variable | Default | Description |
|---|---|---|
| `USER` | — | NordVPN **service credentials** username ([how to get them](#getting-service-credentials)). Required unless `TOKEN` is set. |
| `PASS` | — | NordVPN service credentials password. Required unless `TOKEN` is set. |
| `TOKEN` | — | NordVPN access token; the service credentials are fetched from the NordVPN API at startup. Ignored when `USER`/`PASS` are set. |

### Server selection — [details][wiki-server]

| Variable | Default | Description |
|---|---|---|
| `COUNTRY` | — | Countries to pick servers from: names, codes, IDs, or specific server hostnames ([list][nordvpn-countries]). |
| `CITY` | — | Cities: names, IDs, or specific server hostnames ([list][nordvpn-cities]). |
| `GROUP` | — | Server group, e.g. `legacy_p2p` or `legacy_obfuscated_servers` ([list][nordvpn-groups], [details][wiki-groups]). |
| `RANDOM_TOP` | `0` | Shuffle the top N servers of the filtered pool before picking one. |

### OpenVPN connection — [details][wiki-tech]

| Variable | Default | Description |
|---|---|---|
| `TECHNOLOGY` | `openvpn_udp` | OpenVPN variant: `openvpn_udp` \| `openvpn_tcp` \| `openvpn_xor_udp` \| `openvpn_xor_tcp` \| `openvpn_dedicated_udp` \| `openvpn_dedicated_tcp`; API names and IDs also accepted ([list][nordvpn-technologies]). |
| `PORT` | _(auto)_ | Force a specific port for the VPN connection; must be one the server listens on. |
| `DNS` | server-pushed | DNS servers written to `resolv.conf`; resolution goes through the tunnel. `off` leaves `resolv.conf` untouched ([details][wiki-custom-dns]). |
| `XOR_KEY` | NordVPN's built-in key | XOR scramble key for the `openvpn_xor_*` technologies ([details][wiki-xor-key]). |
| `OPENVPN_OPTS` | — | Extra OpenVPN options, e.g. `--mute-replay-warnings --ping-exit 180` ([details][wiki-openvpn-opts]). |

### Reconnection and health — [details][wiki-reconnect]

| Variable | Default | Description |
|---|---|---|
| `RECREATE_VPN_CRON` | _(disabled)_ | Cron schedule for switching to a new server, e.g. `0 */6 * * *`. |
| `CHECK_CONNECTION_CRON` | _(disabled)_ | Cron schedule for the connectivity check that reconnects on failure. |
| `CHECK_CONNECTION_URL` | `https://www.google.com` | URL(s) probed through the tunnel by the check and by the Docker `HEALTHCHECK`. |
| `CHECK_CONNECTION_ATTEMPTS` | `5` | Failed attempts before the check declares the tunnel dead and reconnects. |
| `CHECK_CONNECTION_ATTEMPT_INTERVAL` | `10` | Seconds between attempts. |
| `HEALTHCHECK_ENABLED` | `false` | `true` = the Docker `HEALTHCHECK` probes `tun0` and `CHECK_CONNECTION_URL` instead of always reporting healthy ([details][wiki-healthcheck]). |

### Local network access — [details][wiki-network]

| Variable | Default | Description |
|---|---|---|
| `NETWORK` | — | LAN / inter-container IPv4 CIDRs allowed to bypass the tunnel (routes + firewall), e.g. `192.168.1.0/24`. |

### Gateway mode — [details][wiki-gateway]

| Variable | Default | Description |
|---|---|---|
| `FORWARD_FROM` | — | Downstream IPv4 CIDRs allowed to route out through the tunnel; traffic must arrive already SNATed into these nets. |
| `GATEWAY_DNS` | `off` | Client DNS interception for `FORWARD_FROM` sources: `redirect` (tunnel resolvers) \| `local` (co-located resolver) \| `forward` (`GATEWAY_DNS_SERVER`) \| `off` ([details][wiki-gateway-dns]). |
| `GATEWAY_DNS_SERVER` | — | External IPv4 resolver(s) for `GATEWAY_DNS=forward`, reached directly over the uplink, **not** through the tunnel; the first one answering a probe at startup is used. |
| `TTL_SET` | _(unset)_ | Rewrite the TTL of traffic leaving through the tunnel (`1`–`255`, e.g. `64`); hides every hop behind this container from client traceroutes ([details][wiki-ttl]). |
| `TTL_INC` | _(unset)_ | Add to the TTL of traffic arriving on `eth0` (`1`–`255`, e.g. `1`) so this container disappears from client traceroutes; needs `FORWARD_FROM` ([details][wiki-ttl]). |

### Diagnostics and advanced — [details][wiki-diagnostics]

| Variable | Default | Description |
|---|---|---|
| `NETWORK_DIAGNOSTIC_ENABLED` | `false` | Run the built-in network diagnostic after every connect. |
| `NORDVPNAPI_IP` | `104.16.208.203;104.19.159.190` | IPs used for all NordVPN API access (no DNS involved). |

## 🐛 Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue][github-issues-link] or [email][email-link].

Check the **[Troubleshooting][wiki-troubleshoot]** and **[FAQ][wiki-faq]** wiki pages first. For how the container works under the hood, see **[Architecture and Internals][wiki-architecture]**.

<!-- Links: Docker Hub -->
[dockerhub-link]: https://hub.docker.com/r/azinchen/nordvpn
[dockerhub-pulls]: https://img.shields.io/docker/pulls/azinchen/nordvpn?logo=docker&logoColor=white
[dockerhub-size]: https://img.shields.io/docker/image-size/azinchen/nordvpn/latest?logo=docker&logoColor=white
[dockerhub-stars]: https://img.shields.io/docker/stars/azinchen/nordvpn?logo=docker&logoColor=white

<!-- Links: GitHub -->
[github-link]: https://github.com/azinchen/nordvpn
[github-issues]: https://img.shields.io/github/issues/azinchen/nordvpn?logo=github&logoColor=white
[github-issues-link]: https://github.com/azinchen/nordvpn/issues
[github-releases]: https://github.com/azinchen/nordvpn/releases
[github-actions]: https://github.com/azinchen/nordvpn/actions
[github-stars]: https://img.shields.io/github/stars/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[github-forks]: https://img.shields.io/github/forks/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[github-release]: https://img.shields.io/github/v/release/azinchen/nordvpn?logo=github&logoColor=white
[github-releasedate]: https://img.shields.io/github/release-date/azinchen/nordvpn?logo=github&logoColor=white
[github-build]: https://img.shields.io/github/actions/workflow/status/azinchen/nordvpn/ci-build-deploy.yml?branch=master&label=build&logo=github&logoColor=white
[github-lastcommit]: https://img.shields.io/github/last-commit/azinchen/nordvpn?logo=github&logoColor=white
[multiarch-badge]: https://img.shields.io/badge/multi--arch-386%20%7C%20amd64%20%7C%20arm%2Fv6%20%7C%20arm%2Fv7%20%7C%20arm64%20%7C%20riscv64-blue?logo=docker&logoColor=white

<!-- Links: Reference lists -->
[nordvpn-cities]: https://github.com/azinchen/nordvpn/wiki/Cities-List
[nordvpn-countries]: https://github.com/azinchen/nordvpn/wiki/Countries-List
[nordvpn-groups]: https://github.com/azinchen/nordvpn/wiki/Groups-List
[nordvpn-technologies]: https://github.com/azinchen/nordvpn/wiki/Technologies-List

<!-- Links: Wiki -->
[wiki-home]: https://github.com/azinchen/nordvpn/wiki
[wiki-server]: https://github.com/azinchen/nordvpn/wiki/Server-Selection
[wiki-server-behavior]: https://github.com/azinchen/nordvpn/wiki/Server-Selection#selection-behavior
[wiki-credentials]: https://github.com/azinchen/nordvpn/wiki/FAQ#credentials
[wiki-healthcheck]: https://github.com/azinchen/nordvpn/wiki/Automatic-Reconnection#docker-health-status
[wiki-architecture]: https://github.com/azinchen/nordvpn/wiki/Architecture-and-Internals
[wiki-groups]: https://github.com/azinchen/nordvpn/wiki/Server-Groups
[wiki-reconnect]: https://github.com/azinchen/nordvpn/wiki/Automatic-Reconnection
[wiki-security]: https://github.com/azinchen/nordvpn/wiki/Security-Model#traffic-control--kill-switch
[wiki-network]: https://github.com/azinchen/nordvpn/wiki/Local-Network-Access
[wiki-custom-dns]: https://github.com/azinchen/nordvpn/wiki/Custom-DNS
[wiki-ipv6]: https://github.com/azinchen/nordvpn/wiki/IPv6-Configuration
[wiki-firewall]: https://github.com/azinchen/nordvpn/wiki/Firewall-Backends
[wiki-gateway]: https://github.com/azinchen/nordvpn/wiki/VPN-Gateway-Mode
[wiki-gateway-dns]: https://github.com/azinchen/nordvpn/wiki/VPN-Gateway-Mode#client-dns-gateway_dns
[wiki-ttl]: https://github.com/azinchen/nordvpn/wiki/VPN-Gateway-Mode#ttl-tuning-ttl_set--ttl_inc
[wiki-tech]: https://github.com/azinchen/nordvpn/wiki/Technologies
[wiki-xor]: https://github.com/azinchen/nordvpn/wiki/Technologies#xor-obfuscated-openvpn-openvpn_xor_udp--openvpn_xor_tcp
[wiki-xor-key]: https://github.com/azinchen/nordvpn/wiki/Technologies#xor-key-override
[wiki-openvpn-opts]: https://github.com/azinchen/nordvpn/wiki/OpenVPN-Options
[wiki-diagnostics]: https://github.com/azinchen/nordvpn/wiki/Network-Diagnostics-Guide
[wiki-compose]: https://github.com/azinchen/nordvpn/wiki/Docker-Compose-Examples
[wiki-run]: https://github.com/azinchen/nordvpn/wiki/Docker-Run-Examples
[wiki-troubleshoot]: https://github.com/azinchen/nordvpn/wiki/Troubleshooting
[wiki-faq]: https://github.com/azinchen/nordvpn/wiki/FAQ
[wiki-platforms]: https://github.com/azinchen/nordvpn/wiki/Supported-Platforms

[email-link]: mailto:alexander@zinchenko.com
