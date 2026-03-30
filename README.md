[![logo](https://github.com/azinchen/nordvpn/raw/master/NordVpn_logo.png)](https://www.nordvpn.com/)

# NordVPN OpenVPN Docker Container

<!-- Build & Releases -->
[![GitHub release][github-release]][github-releases]
[![GitHub release date][github-releasedate]][github-releases]
[![GitHub build][github-build]][github-actions]

<!-- GitHub Repo -->
[![GitHub stars][github-stars]][github-link]
[![GitHub forks][github-forks]][github-link]
[![Open issues][github-issues]][github-issues-link]
[![GitHub last commit][github-lastcommit]][github-link]

<!-- Docker Hub -->
[![Docker pulls][dockerhub-pulls]][dockerhub-link]
[![Docker stars][dockerhub-stars]][dockerhub-link]
[![Docker image size][dockerhub-size]][dockerhub-link]

<!-- Platform Support -->
[![Multi-arch][multiarch-badge]][wiki-platforms]

OpenVPN client docker container that routes other containers' traffic through NordVPN servers automatically.

## ✨ Key Features

- **🚀 Easy Setup** — Route any container's traffic through VPN with `--net=container:vpn`
- **🌍 Smart Server Selection** — Auto-select servers by country, city, group, or specific hostname ([details][wiki-server])
- **⚖️ Load Balancing** — Intelligent sorting by server load when multiple locations specified
- **🔄 Auto-Reconnection** — Periodic server switching and health monitoring ([details][wiki-reconnect])
- **🕵️ XOR Obfuscation** — Built-in Tunnelblick XOR patches disguise OpenVPN traffic to bypass DPI ([details][wiki-tech])
- **🛡️ Kill Switch** — Default-deny firewall blocks all traffic when VPN is down ([details][wiki-security])
- **🏠 Local/LAN Access** — Allow specific CIDRs with `NETWORK=...` ([details][wiki-network])
- **📵 IPv6 Firewall** — Built-in chains default to DROP ([details][wiki-ipv6])
- **🧱 iptables Compatibility** — Auto-selects nft or legacy backend ([details][wiki-firewall])

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
- **NordVPN Service Credentials** (not regular account credentials)

### Getting Service Credentials

1. Log into your [Nord Account Dashboard](https://my.nordaccount.com/)
2. Click on **NordVPN** → **Advanced Settings** → **Set up NordVPN manually**
3. Go to the **Service credentials** tab
4. Copy the **Username** and **Password** shown there

> **Note**: These are different from your regular NordVPN login credentials.

## Docker Compose Example

```yaml
version: "3.8"
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
      - COUNTRY=United States;CA
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=0 */6 * * *
      - NETWORK=192.168.1.0/24
    ports:
      - "8080:8080"
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

| Variable | Details |
|---|---|
| **USER** | **Required** — NordVPN service credentials username. |
| **PASS** | **Required** — NordVPN service credentials password. |
| **PUID** | User ID for the nordvpn process. Default: `912` |
| **PGID** | Group ID for the nordvpn process. Default: `912` |
| **COUNTRY** | Filter by countries: names, codes, IDs, or server hostnames ([list][nordvpn-countries]). Semicolon‑separated. |
| **CITY** | Filter by cities: names, IDs, or server hostnames ([list][nordvpn-cities]). Semicolon‑separated. |
| **GROUP** | Filter by server group ([list][nordvpn-groups]). |
| **TECHNOLOGY** | OpenVPN protocol ([list][nordvpn-technologies]). Default: `openvpn_udp` |
| **RANDOM_TOP** | Randomize top N servers. Default: `0` |
| **RECREATE<wbr>_VPN<wbr>_CRON** | Server switching schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_CRON** | Health monitoring schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_URL** | URLs to test connectivity; semicolon‑separated. Default: `https://www.google.com` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPTS** | Connection test retry count. Default: `5` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPT<wbr>_INTERVAL** | Seconds between retries. Default: `10` |
| **NETWORK** | LAN/inter‑container CIDRs to allow; semicolon‑separated. Default: none |
| **NORDVPNAPI<wbr>_IP** | API bootstrap IPs (semicolon‑separated). Default: `104.16.208.203;104.19.159.190` |
| **XOR<wbr>_KEY** | XOR scramble obfuscation key for `openvpn_xor_*` technologies. Default: NordVPN's built-in key |
| **OPENVPN<wbr>_OPTS** | Additional OpenVPN parameters. |
| **NETWORK<wbr>_DIAGNOSTIC<wbr>_ENABLED** | Enable network diagnostics on connect. Default: `false` |

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
[multiarch-badge]: https://img.shields.io/badge/multi--arch-386%20%7C%20amd64%20%7C%20arm%2Fv6%20%7C%20arm%2Fv7%20%7C%20arm64%20%7C%20ppc64le%20%7C%20riscv64%20%7C%20s390x-blue?logo=docker&logoColor=white

<!-- Links: Reference lists -->
[nordvpn-cities]: https://github.com/azinchen/nordvpn/blob/master/CITIES.md
[nordvpn-countries]: https://github.com/azinchen/nordvpn/blob/master/COUNTRIES.md
[nordvpn-groups]: https://github.com/azinchen/nordvpn/blob/master/GROUPS.md
[nordvpn-technologies]: https://github.com/azinchen/nordvpn/blob/master/TECHNOLOGIES.md

<!-- Links: Wiki -->
[wiki-home]: https://github.com/azinchen/nordvpn/wiki
[wiki-server]: https://github.com/azinchen/nordvpn/wiki/Server-Selection
[wiki-reconnect]: https://github.com/azinchen/nordvpn/wiki/Automatic-Reconnection
[wiki-security]: https://github.com/azinchen/nordvpn/wiki/Security-Model
[wiki-network]: https://github.com/azinchen/nordvpn/wiki/Local-Network-Access
[wiki-ipv6]: https://github.com/azinchen/nordvpn/wiki/IPv6-Configuration
[wiki-firewall]: https://github.com/azinchen/nordvpn/wiki/Firewall-Backends
[wiki-tech]: https://github.com/azinchen/nordvpn/wiki/Technologies
[wiki-compose]: https://github.com/azinchen/nordvpn/wiki/Docker-Compose-Examples
[wiki-run]: https://github.com/azinchen/nordvpn/wiki/Docker-Run-Examples
[wiki-troubleshoot]: https://github.com/azinchen/nordvpn/wiki/Troubleshooting
[wiki-faq]: https://github.com/azinchen/nordvpn/wiki/FAQ
[wiki-platforms]: https://github.com/azinchen/nordvpn/wiki/Supported-Platforms

[email-link]: mailto:alexander@zinchenko.com
