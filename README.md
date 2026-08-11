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
- **🌍 Smart Server Selection** — Auto-select servers by country, city, group, or specific hostname ([details][wiki-server])
- **⚖️ Load Balancing** — Intelligent sorting by server load when multiple locations specified
- **🔄 Auto-Reconnection** — Periodic server switching and health monitoring ([details][wiki-reconnect])
- **🕵️ XOR Obfuscation** — Built-in XOR patches disguise OpenVPN traffic to bypass DPI ([details][wiki-xor])
- **🛡️ Kill Switch** — Default-deny firewall blocks all traffic when VPN is down ([details][wiki-security])
- **🏠 Local/LAN Access** — Allow specific CIDRs with `NETWORK=...` ([details][wiki-network])
- **🧭 Custom DNS** — Resolve through the tunnel; override with `DNS=...` ([details][wiki-custom-dns])
- **📵 IPv6 Firewall** — Built-in chains default to DROP ([details][wiki-ipv6])
- **🧱 iptables Compatibility** — Auto-selects nft or legacy backend ([details][wiki-firewall])
- **🚪 VPN Gateway Mode** — Route downstream subnets through the tunnel with `FORWARD_FROM` ([details][wiki-gateway])

> **📖 [Full documentation on the Wiki][wiki-home]** — configuration guides, examples, troubleshooting, FAQ, and architecture.

---

## Quick Start

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

## Docker Compose Example

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

## Environment Variables

> **List values** (countries, cities, CIDRs, URLs, IPs) accept `;` or `,` as separators; whitespace around separators is ignored.

### Credentials

NordVPN **service credentials**, set directly or fetched automatically with an access token — see [Getting Service Credentials](#getting-service-credentials) above.

| Variable | Details |
|---|---|
| **USER** | NordVPN service credentials username. **Required** unless `TOKEN` is set. |
| **PASS** | NordVPN service credentials password. **Required** unless `TOKEN` is set. |
| **TOKEN** | NordVPN access token; the service credentials are fetched from the NordVPN API at startup. Ignored when `USER`/`PASS` are set. |

### Server Selection

Pick which servers to connect to; filters combine to narrow the pool. See [Server Selection][wiki-server].

| Variable | Details |
|---|---|
| **COUNTRY** | Filter by countries: names, codes, IDs, or server hostnames ([list][nordvpn-countries]). |
| **CITY** | Filter by cities: names, IDs, or server hostnames ([list][nordvpn-cities]). |
| **GROUP** | Filter by server group ([list][nordvpn-groups], [details][wiki-groups]). |
| **RANDOM_TOP** | Randomize top N servers. Default: `0` |

### OpenVPN Connection

Protocol, port, and traffic obfuscation. See [Technologies][wiki-tech].

| Variable | Details |
|---|---|
| **TECHNOLOGY** | OpenVPN protocol: name, identifier, or ID ([list][nordvpn-technologies]). Default: `openvpn_udp` |
| **PORT** | Force a specific port for the VPN connection. Must be supported by the server. Default: auto |
| **DNS** | DNS servers written to `resolv.conf`; resolution goes through the tunnel ([details][wiki-custom-dns]). `off` leaves `resolv.conf` untouched. Default: server‑pushed resolvers |
| **XOR<wbr>_KEY** | XOR scramble obfuscation key for `openvpn_xor_*` technologies ([details][wiki-xor-key]). Default: NordVPN's built-in key |
| **OPENVPN<wbr>_OPTS** | Additional OpenVPN parameters ([details][wiki-openvpn-opts]). |

### Reconnection & Health Monitoring

Rotate servers on a schedule and verify the tunnel actually works. See [Automatic Reconnection][wiki-reconnect].

| Variable | Details |
|---|---|
| **RECREATE<wbr>_VPN<wbr>_CRON** | Server switching schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_CRON** | Health monitoring schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_URL** | URLs to test connectivity. Default: `https://www.google.com` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPTS** | Connection test retry count. Default: `5` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPT<wbr>_INTERVAL** | Seconds between retries. Default: `10` |
| **HEALTHCHECK<wbr>_ENABLED** | Enable the Docker `HEALTHCHECK` probe (checks `tun0` + connectivity via `CHECK_CONNECTION_URL`). When `false`, the container always reports healthy. Default: `false` |

### Local Network & VPN Gateway

Open the kill‑switch firewall for LAN access and downstream routing. See [Local Network Access][wiki-network] and [VPN Gateway Mode][wiki-gateway].

| Variable | Details |
|---|---|
| **NETWORK** | LAN/inter‑container CIDRs to allow. Default: none |
| **FORWARD<wbr>_FROM** | Downstream CIDRs allowed to route OUT through the tunnel (gateway mode). Traffic must arrive already SNATed into these nets. Default: none |
| **GATEWAY<wbr>_DNS** | DNS interception for `FORWARD_FROM` clients: `redirect` (DNAT port 53 to the tunnel resolvers — server‑pushed, or `DNS` when set), `local` (DNAT port 53 to this container, for a co‑located resolver such as AdGuard Home), `forward` (DNAT port 53 to `GATEWAY_DNS_SERVER`, reached directly over the uplink — **not** through the tunnel), `off`. Default: `off` |
| **GATEWAY<wbr>_DNS<wbr>_SERVER** | External IPv4 resolver(s) for `GATEWAY_DNS=forward` (e.g. an AdGuard Home on your LAN). With a list, the first resolver answering a DNS probe at startup is used. Default: none |

### Advanced

Low‑level settings; the defaults work for most setups.

| Variable | Details |
|---|---|
| **NORDVPNAPI<wbr>_IP** | IPs used for all NordVPN API access (no DNS involved). Default: `104.16.208.203;104.19.159.190` |
| **NETWORK<wbr>_DIAGNOSTIC<wbr>_ENABLED** | Enable network diagnostics on connect ([details][wiki-diagnostics]). Default: `false` |

## Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue][github-issues-link] or [email][email-link].

Check the **[Troubleshooting][wiki-troubleshoot]** and **[FAQ][wiki-faq]** wiki pages first.

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
[nordvpn-cities]: https://github.com/azinchen/nordvpn/blob/master/CITIES.md
[nordvpn-countries]: https://github.com/azinchen/nordvpn/blob/master/COUNTRIES.md
[nordvpn-groups]: https://github.com/azinchen/nordvpn/blob/master/GROUPS.md
[nordvpn-technologies]: https://github.com/azinchen/nordvpn/blob/master/TECHNOLOGIES.md

<!-- Links: Wiki -->
[wiki-home]: https://github.com/azinchen/nordvpn/wiki
[wiki-server]: https://github.com/azinchen/nordvpn/wiki/Server-Selection
[wiki-groups]: https://github.com/azinchen/nordvpn/wiki/Server-Groups
[wiki-reconnect]: https://github.com/azinchen/nordvpn/wiki/Automatic-Reconnection
[wiki-security]: https://github.com/azinchen/nordvpn/wiki/Security-Model#traffic-control--kill-switch
[wiki-network]: https://github.com/azinchen/nordvpn/wiki/Local-Network-Access
[wiki-custom-dns]: https://github.com/azinchen/nordvpn/wiki/Custom-DNS
[wiki-ipv6]: https://github.com/azinchen/nordvpn/wiki/IPv6-Configuration
[wiki-firewall]: https://github.com/azinchen/nordvpn/wiki/Firewall-Backends
[wiki-gateway]: https://github.com/azinchen/nordvpn/wiki/VPN-Gateway-Mode
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
