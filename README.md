[![logo](https://github.com/azinchen/nordvpn/raw/master/NordVpn_logo.png)](https://www.nordvpn.com/)

# NordVPN OpenVPN Docker Container

[![Docker pulls][dockerhub-pulls]][dockerhub-link]
[![Docker image size][dockerhub-size]][dockerhub-link]
[![Docker stars][dockerhub-stars]][dockerhub-link]
[![GitHub stars][github-stars]][github-link]
[![GitHub forks][github-forks]][github-link]
[![GitHub release][github-release]][github-releases]
[![GitHub release date][github-releasedate]][github-releases]
[![GitHub build][github-build]][github-actions]
[![GitHub last commit][github-lastcommit]][github-link]
[![License][license-badge]][license-link]
[![OpenVPN][openvpn-badge]](https://openvpn.net/)

OpenVPN client docker container that routes other containers' traffic through NordVPN servers automatically.

## ✨ Key Features

- **🚀 Easy Setup**: Route any container's traffic through VPN with `--net=container:vpn`
- **🌍 Smart Server Selection**: Automatically selects optimal NordVPN servers by country, city, or group
- **🔄 Auto-Reconnection**: Periodic server switching and connection health monitoring with cron
- **⚖️ Load Balancing**: Intelligent sorting by server load when multiple locations specified
- **🔒 Local/LAN Access (explicit)**: Allow specific LAN or inter‑container CIDRs with `NETWORK=...`
- **🛡️ Strict(er) Kill Switch**: All non-exempt traffic is blocked when VPN is down; only `NETWORK` CIDRs you define remain reachable; **HTTPS requests to the IPs in `NORDVPNAPI_IP` are allowed for NordVPN API bootstrap.**
- **🧱 iptables compatibility**: Automatically falls back to **iptables‑legacy** on older or nft‑broken hosts
- **📵 IPv6**: IPv6 firewall is applied — built-in chains default to **DROP** if IPv6 is enabled
- **📌 Pinned NordVPN API IPs**: Bootstrap uses `NORDVPNAPI_IP` to reach `api.nordvpn.com` **without DNS**

---

<!-- TOC -->
## Table of contents

- [✨ Key Features](#key-features)
- [Quick Start](#quick-start)
  - [Basic Usage](#basic-usage)
  - [Requirements](#requirements)
  - [Security Features](#security-features)
  - [Container Registries](#container-registries)
  - [Firewall backends (nft vs legacy)](#firewall-backends-nft-vs-legacy)
  - [Getting Service Credentials](#getting-service-credentials)
- [Configuration Options](#configuration-options)
  - [Server Selection](#server-selection)
  - [IPv6 behavior](#ipv6-behavior)
  - [Automatic Reconnection](#automatic-reconnection)
    - [Scheduled Reconnection](#scheduled-reconnection)
    - [Connection Failure Handling](#connection-failure-handling)
    - [Connection Health Monitoring](#connection-health-monitoring)
  - [Local Network Access](#local-network-access)
- [Docker Compose Examples](#docker-compose-examples)
  - [Simple VPN + Application Setup](#simple-vpn--application-setup)
  - [Advanced Setup with Local Access](#advanced-setup-with-local-access)
  - [Web Proxy Setup](#web-proxy-setup)
- [Docker Run Examples](#docker-run-examples)
  - [Basic Example](#basic-example)
  - [Advanced Example with Port Mapping](#advanced-example-with-port-mapping)
- [Environment Variables](#environment-variables)
- [Supported Platforms](#supported-platforms)
- [Updating the VPN container & dependent services](#updating-the-vpn-container--dependent-services)
  - [With Docker Compose](#with-docker-compose)
  - [With plain Docker (no Compose)](#with-plain-docker-no-compose)
  - [Safer automated updates for Compose stacks](#safer-automated-updates-for-compose-stacks)
- [Issues](#issues)
<!-- /TOC -->

## Quick Start

### Basic Usage

**From Docker Hub:**
```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e USER=service_username -e PASS=service_password \
           azinchen/nordvpn
```

**From GitHub Container Registry:**
```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e USER=service_username -e PASS=service_password \
           ghcr.io/azinchen/nordvpn
```

Route other containers through VPN:
```bash
docker run --net=container:vpn -d your/application
```

### Requirements

- Docker with `--cap-add=NET_ADMIN` and `--device /dev/net/tun`
- **NordVPN Service Credentials** (not regular account credentials)
- The image includes both nftables and **iptables‑legacy** and auto‑selects the working backend at runtime — no manual config needed.

### Security Features

**🛡️ Traffic Control & Kill Switch**
- **Default‑deny (egress):** All outbound traffic is blocked unless it goes through the VPN interface, matches `NETWORK` (CIDRs you define) or is directed to NordVPN's API.
- **Bootstrap (pre‑VPN):** DNS egress is **blocked**. The container contacts NordVPN’s API via **pinned IP addresses** from `NORDVPNAPI_IP` to select a server (no DNS queries before the tunnel is up).
- **Kill switch:** If the VPN drops, traffic remains blocked **except** for destinations within your `NETWORK` CIDRs (e.g., local/LAN ranges you explicitly allowed) and to NordVPN's API.
- **Container routing:** Containers using `network_mode: "service:vpn"` share the VPN container’s network namespace and inherit these policies.
- **Inbound (local/LAN only):** No connections from the host or LAN reach the stack **unless you publish ports on the VPN container**. **Public inbound via NordVPN is not supported** (no port forwarding).

**🔒 Network Access Control (Exceptions)**
- **Local/LAN access (bidirectional, explicit):** Set `NETWORK=192.168.1.0/24` (semicolon‑separated CIDRs supported) to allow access to those subnets **regardless of VPN status**.
- **No domain names allowed:** Use IPs in `NETWORK` for any non‑VPN access you require.

**⚖️ Rule Precedence**
1. **Bootstrap-only (when VPN is down & before first connect):** Allow HTTPS only to the **NordVPN API IPs from `NORDVPNAPI_IP`** used by the image’s bootstrap script.
2. **Exceptions:** If destination matches `NETWORK` (CIDR), allow (bypass/LAN), regardless of VPN state.
3. **VPN path:** If VPN is **up** and traffic is not an exception, allow only via the VPN interface.
4. **Default‑deny:** Otherwise, block.

**⚠️ Security Note**
Because `NETWORK` remains open when the VPN is down, this is **not a strict kill switch** if you include broad CIDRs. Keep `NETWORK` as narrow as possible (e.g., just your LAN / management subnets).

### Container Registries

The image is available from two registries:

- **Docker Hub**: `azinchen/nordvpn` — Main distribution, publicly accessible
- **GitHub Container Registry**: `ghcr.io/azinchen/nordvpn` — Alternative source, same image

Both registries contain identical images. Use whichever is more convenient for your setup.

### Firewall backends (nft vs legacy)

This image ships **both** `iptables` (nft-backed) and `iptables-legacy` (xtables).
At runtime, the entrypoint selects a working backend:

- **New kernels (≥ 4.18)** → prefer **nft** (`iptables`) if it can change policy; otherwise fall back to legacy.
- **Old kernels (< 4.18, e.g., 4.4)** → prefer **legacy** (`iptables-legacy`); fall back to nft only if legacy is unavailable.

The selection is verified by attempting to toggle a chain policy (DROP ↔ ACCEPT) on `OUTPUT`. If that fails for a backend, it is not used. If legacy is selected and nft tables already contain rules in this network namespace, the entrypoint flushes nft tables **once** to avoid mixed stacks.

You’ll see logs like:

```
[ENTRYPOINT] Kernel: 6.8.0-xx
[ENTRYPOINT] Using IPv4 backend: iptables
```

or on older systems:

```
[ENTRYPOINT] Kernel: 4.4.0-xxx
[ENTRYPOINT] Using IPv4 backend: iptables-legacy
```

### Getting Service Credentials

1. Log into your [Nord Account Dashboard](https://my.nordaccount.com/)
2. Click on **NordVPN**
3. Under **Advanced Settings**, click **Set up NordVPN manually**
4. Go to the **Service credentials** tab
5. Copy the **Username** and **Password** shown there

**Note**: These are different from your regular NordVPN login credentials and are specifically required for OpenVPN connections.

## Configuration Options

### Server Selection

Filter NordVPN servers using location and server criteria:

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun \
           -e USER=service_username -e PASS=service_password \
           -e COUNTRY="United States;CA;153" \
           -e CITY="New York;2619989;es1234" \
           -e GROUP="Standard VPN servers" \
           -e RANDOM_TOP=5 \
           azinchen/nordvpn
```

**Location Specification Options:**
- **Country**: name (`United States`), code (`US`), or ID (`228`)
- **City**: name (`New York`) or ID (`8971718`)
- **Specific Server**: Use hostname (e.g., `es1234`, `uk2567`) in either COUNTRY or CITY — these get priority with load=0

**Server Selection Behavior:**
- **Specific servers**: Named servers are placed at the top of the list with load=0
- **Multiple locations**: Combined and sorted by load (lowest first)
- **Single location**: Keeps NordVPN’s recommended order
- **RANDOM_TOP**: Applies after filtering and sorting

### IPv6 behavior

This image **applies an IPv6 firewall** (when `ip6tables` is available and IPv6 is enabled): `INPUT`/`FORWARD`/`OUTPUT` default to `DROP`. It does **not** change IPv6 sysctls from inside the container (many environments mount `/proc/sys` read-only).

If your Docker runtime assigns IPv6 addresses and you want to avoid IPv6 leaks, choose **one** of the following:

#### Option A — Disable IPv6 for the Docker daemon/network (recommended)
- Daemon-wide: set `"ipv6": false` in Docker’s `daemon.json` and restart Docker.
- Per-network: create the network with `--ipv6=false`.

#### Option B — Disable IPv6 per container via runtime sysctls
Pass sysctls at **run** time (works even when `/proc/sys` is read-only inside the container):

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           --sysctl net.ipv6.conf.all.disable_ipv6=1 \
           --sysctl net.ipv6.conf.default.disable_ipv6=1 \
           --sysctl net.ipv6.conf.eth0.disable_ipv6=1 \
           azinchen/nordvpn
```

**docker-compose:**

```yaml
services:
  vpn:
    image: azinchen/nordvpn
    sysctls:
      net.ipv6.conf.all.disable_ipv6: "1"
      net.ipv6.conf.default.disable_ipv6: "1"
      net.ipv6.conf.eth0.disable_ipv6: "1"
```

#### Option C — Disable IPv6 on the host
Use host sysctls or OS network settings to turn off IPv6 globally.

#### How to verify IPv6 is truly off

Inside the container:

```bash
cat /proc/net/if_inet6            # no output means no IPv6 addresses
ip -6 addr show dev eth0          # should show "Device not found" or no inet6 lines
ip6tables -S 2>/dev/null || true  # may be empty/unavailable
```

> Note: Because this image does **not** touch `ip6tables`, if your environment leaves IPv6 **enabled**, IPv6 traffic may bypass the IPv4 firewall. Use one of the options above to disable IPv6 at runtime.

### Automatic Reconnection

#### Scheduled Reconnection
```bash
# Reconnect every 6 hours at minute 0
-e RECREATE_VPN_CRON="0 */6 * * *"

# Reconnect daily at 3 AM
-e RECREATE_VPN_CRON="0 3 * * *"

# Reconnect every 4 hours
-e RECREATE_VPN_CRON="0 */4 * * *"
```

#### Connection Failure Handling
```bash
# Force reconnect to different server on connection loss
-e OPENVPN_OPTS="--pull-filter ignore ping-restart --ping-exit 180"

# Alternative: More aggressive reconnection
-e OPENVPN_OPTS="--ping 10 --ping-exit 60 --ping-restart 300"
```

#### Connection Health Monitoring
```bash
# Check connection every 5 minutes
-e CHECK_CONNECTION_CRON="*/5 * * * *"
-e CHECK_CONNECTION_URL="https://1.1.1.1;https://8.8.8.8"
-e CHECK_CONNECTION_ATTEMPTS=3
-e CHECK_CONNECTION_ATTEMPT_INTERVAL=10
```

### Local Network Access

Allow local services or inter‑container networks **explicitly**:

```bash
# Find your local network
ip route | awk '!/ (docker0|br-)/ && /src/ {print $1}'

# Configure container with local network access
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun \
           -e NETWORK=192.168.1.0/24 \
           -e USER=service_username -e PASS=service_password \
           azinchen/nordvpn
```

- Docker subnets are **not** auto‑allowed. If containers sharing the VPN namespace need to talk to each other or to services on your LAN/host, include those CIDRs in `NETWORK`.

## Docker Compose Examples

### Simple VPN + Application Setup

```yaml
version: "3.8"
services:
  vpn:
    image: azinchen/nordvpn:latest
    container_name: nordvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - USER=service_username
      - PASS=service_password
      - COUNTRY=United States;CA;38
      - CITY=New York;Los Angeles;Toronto
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=0 */6 * * *  # Reconnect every 6 hours
      - NETWORK=192.168.1.0/24         # Your local network
    ports:
      - "8080:8080"  # Expose ports for services using VPN
      - "3000:3000"  # Application web UI
    restart: unless-stopped

  # Application using VPN  webapp:
  webapp:
    image: nginx:alpine
    container_name: webapp
    network_mode: "service:vpn"  # Route through VPN
    depends_on:
      - vpn
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped

  # Another application using VPN
  api-service:
    image: node:alpine
    container_name: api-service
    network_mode: "service:vpn"  # Route through VPN
    depends_on:
      - vpn
    working_dir: /app
    volumes:
      - ./app:/app
    command: ["npm", "start"]
    restart: unless-stopped
```

### Advanced Setup with Local Access

```yaml
version: "3.8"
services:
  # VPN Container with health monitoring
  vpn:
    image: azinchen/nordvpn:latest
    container_name: nordvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - USER=service_username
      - PASS=service_password
      - COUNTRY=Netherlands;DE;209
      - CITY=Amsterdam;Berlin;Frankfurt
      - GROUP=Standard VPN servers
      - RANDOM_TOP=5
      - RECREATE_VPN_CRON=0 */4 * * *
      - CHECK_CONNECTION_CRON=*/5 * * * *
      - CHECK_CONNECTION_URL=https://1.1.1.1;https://8.8.8.8
      - NETWORK=192.168.1.0/24;172.20.0.0/16
      - OPENVPN_OPTS=--mute-replay-warnings --ping-exit 60
    ports:
      - "8080:8080"   # Web application
      - "3000:3000"   # API service
      - "9000:9000"   # Monitoring dashboard
      - "6379:6379"   # Redis
    restart: unless-stopped

  # Web application using VPN
  webapp:
    image: nginx:alpine
    container_name: webapp
    network_mode: "service:vpn"
    depends_on:
      vpn:
        condition: service_healthy
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./web:/usr/share/nginx/html:ro
    restart: unless-stopped

  api-service:
    image: node:alpine
    container_name: api-service
    network_mode: "service:vpn"
    depends_on:
      - vpn
      - webapp
    working_dir: /app
    volumes:
      - ./api:/app
    command: ["npm", "start"]
    restart: unless-stopped

  redis:
    image: redis:alpine
    container_name: redis
    network_mode: "service:vpn"
    depends_on:
      - vpn
    volumes:
      - ./config/redis:/data
    restart: unless-stopped

  # Service that DOESN'T use VPN (runs on host network)
  monitoring:
    image: grafana/grafana:latest
    container_name: monitoring
    network_mode: host  # Direct host access for local monitoring
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./config/grafana:/var/lib/grafana
    restart: unless-stopped
```

### Web Proxy Setup

```yaml
version: "3.8"
services:
  vpn:
    image: azinchen/nordvpn:latest
    container_name: nordvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - USER=service_username
      - PASS=service_password
      - COUNTRY=CA;38
      - CITY=Toronto;Montreal
      - NETWORK=192.168.1.0/24
    restart: unless-stopped

  # Application behind VPN
  app:
    image: nginx:alpine
    container_name: webapp
    network_mode: "service:vpn"
    depends_on:
      - vpn
    volumes:
      - ./html:/usr/share/nginx/html
    restart: unless-stopped

  # Reverse proxy for local access
  nginx-proxy:
    image: nginx:alpine
    container_name: proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - vpn
    restart: unless-stopped
```

## Docker Run Examples

### Basic Example
```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun \
           -e USER=service_username \
           -e PASS=service_password \
           azinchen/nordvpn

# Run application through VPN
docker run -d --name app --net=container:vpn nginx
```

### Advanced Example with Port Mapping
```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun \
           -p 8080:8080 \
           -p 9091:9091 \
           -e USER=service_username \
           -e PASS=service_password \
           -e COUNTRY="Germany;NL;202" \
           -e CITY="Amsterdam;6076868;uk2567" \
           -e GROUP="Standard VPN servers" \
           -e RANDOM_TOP=3 \
           -e RECREATE_VPN_CRON="0 */6 * * *" \
           -e NETWORK=192.168.1.0/24 \
           azinchen/nordvpn

# Applications using VPN (access via host ports)
docker run -d --name webapp --net=container:vpn \
           nginx:alpine

docker run -d --name api-service --net=container:vpn \
           -v ./app:/app -w /app \
           node:alpine npm start
```

## Environment Variables

| Variable | Details |
|---|---|
| **USER** | **Required** — NordVPN service credentials username. <br> **Default:** — <br> **Example:** `service_username` |
| **PASS** | **Required** — NordVPN service credentials password. <br> **Default:** — <br> **Example:** `service_password` |
| **COUNTRY** | Filter by countries: names, codes, IDs, or specific server hostnames ([list][nordvpn-countries]). Use semicolons to separate multiple values. <br> **Default:** All countries <br> **Example:** `United States;CA;228;es1234` |
| **CITY** | Filter by cities: names, IDs, or specific server hostnames ([list][nordvpn-cities]). Use semicolons to separate multiple values. <br> **Default:** All cities <br> **Example:** `New York;8971718;uk2567` |
| **GROUP** | Filter by server group ([list][nordvpn-groups]). <br> **Default:** Not defined <br> **Example:** `Standard VPN servers` |
| **TECHNOLOGY** | Filter by technology — OpenVPN only supported ([list][nordvpn-technologies]). <br> **Default:** OpenVPN UDP <br> **Example:** `openvpn_udp` |
| **RANDOM_TOP** | Randomize top **N** servers from the filtered list. <br> **Default:** Disabled <br> **Example:** `10` |
| **RECREATE<wbr>_VPN<wbr>_CRON** | Schedule for server switching (cron format). <br> **Default:** Disabled <br> **Example:** `0 */6 * * *` *(every 6 hours)* |
| **CHECK<wbr>_CONNECTION<wbr>_CRON** | Schedule for connection monitoring (cron format). <br> **Default:** Disabled <br> **Example:** `*/5 * * * *` *(every 5 minutes)* |
| **CHECK<wbr>_CONNECTION<wbr>_URL** | URLs to test connectivity; semicolon‑separated. <br> **Default:** None <br> **Example:** `https://1.1.1.1;https://8.8.8.8` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPTS** | Number of connection test attempts. <br> **Default:** `5` <br> **Example:** `5` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPT<wbr>_INTERVAL** | Seconds between failed attempts. <br> **Default:** `10` <br> **Example:** `10` |
| **NETWORK** | Local/LAN or inter‑container networks to allow; semicolon‑separated CIDRs. <br> **Default:** None <br> **Example:** `10.0.0.0/8;172.16.0.0/12;192.168.0.0/16` |
| **NORDVPNAPI<wbr>_IP** | IPv4 list of `api.nordvpn.com` addresses (semicolon‑separated) used during **pre‑VPN bootstrap** to avoid DNS (HTTPS only). <br> **Default:** `104.16.208.203;104.19.159.190` <br> **Example:** `104.19.159.190;104.16.208.203` |
| **OPENVPN<wbr>_OPTS** | Additional OpenVPN parameters. <br> **Default:** None <br> **Example:** `--mute-replay-warnings` |
| **NETWORK<wbr>_DIAGNOSTIC<wbr>_ENABLED** | Enable automatic network diagnostics on VPN connection and reconnection. <br> **Default:** `false` <br> **Example:** `true` |

## Supported Platforms

This container supports multiple architectures and can run on various platforms:

| Architecture | Platform | Notes |
|--------------|----------|-------|
| `linux/386` | 32-bit x86 | Legacy systems |
| `linux/amd64` | 64-bit x86 | Most common desktop/server |
| `linux/arm/v6` | ARM v6 | Older ARM devices |
| `linux/arm/v7` | ARM v7 | Raspberry Pi 2/3, many ARM SBCs |
| `linux/arm64` | 64-bit ARM | Raspberry Pi 4, Apple M1, modern ARM |
| `linux/ppc64le` | PowerPC 64-bit LE | IBM Power Systems |
| `linux/riscv64` | 64-bit RISC-V | Emerging RISC-V hardware |
| `linux/s390x` | IBM System z | Enterprise mainframes |

Docker will automatically pull the correct architecture.

## Updating the VPN container & dependent services

When the `vpn` container is restarted — whether due to an image update or a manual restart — every container that uses `network_mode: "service:vpn"` must also be restarted so they reattach to the recreated network namespace.

### With Docker Compose
```bash
docker compose pull
docker compose up -d --force-recreate
```

### With plain Docker (no Compose)
```bash
docker pull azinchen/nordvpn:latest   # or ghcr.io/azinchen/nordvpn:latest
docker stop vpn && docker rm vpn
# Re-run your "vpn" container with the same args as before...
# Then restart each dependent container:
docker restart webapp api-service redis
```

### Safer automated updates for Compose stacks
Consider using
[azinchen/update-docker-containers](https://github.com/azinchen/update-docker-containers).

## Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue][github-issues] or [email][email-link].

[dockerhub-link]: https://hub.docker.com/r/azinchen/nordvpn
[dockerhub-pulls]: https://img.shields.io/docker/pulls/azinchen/nordvpn?style=flat-square&logo=docker&logoColor=white
[dockerhub-size]: https://img.shields.io/docker/image-size/azinchen/nordvpn/latest?style=flat-square&logo=docker&logoColor=white
[dockerhub-stars]: https://img.shields.io/docker/stars/azinchen/nordvpn?style=flat-square&logo=docker&logoColor=white
[github-link]: https://github.com/azinchen/nordvpn
[github-issues]: https://github.com/azinchen/nordvpn/issues
[github-releases]: https://github.com/azinchen/nordvpn/releases
[github-actions]: https://github.com/azinchen/nordvpn/actions
[github-stars]: https://img.shields.io/github/stars/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[github-forks]: https://img.shields.io/github/forks/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[github-release]: https://img.shields.io/github/v/release/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[github-releasedate]: https://img.shields.io/github/release-date/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[github-build]: https://img.shields.io/github/actions/workflow/status/azinchen/nordvpn/ci-build-deploy.yml?branch=master&style=flat-square&logo=github&logoColor=white&label=build
[github-lastcommit]: https://img.shields.io/github/last-commit/azinchen/nordvpn?style=flat-square&logo=github&logoColor=white
[license-badge]: https://img.shields.io/github/license/azinchen/nordvpn?style=flat-square&logo=opensourceinitiative&logoColor=white
[license-link]: https://github.com/azinchen/nordvpn/blob/master/LICENSE
[multiarch-badge]: https://img.shields.io/badge/multi--arch-linux%2F386%20%7C%20linux%2Famd64%20%7C%20linux%2Farm%2Fv6%20%7C%20linux%2Farm%2Fv7%20%7C%20linux%2Farm64%20%7C%20linux%2Fppc64le%20%7C%20linux%2Friscv64%20%7C%20linux%2Fs390x-blue?style=flat-square&logo=docker&logoColor=white
[openvpn-badge]: https://img.shields.io/badge/OpenVPN-supported-green?style=flat-square&logo=openvpn&logoColor=white
[nordvpn-cities]: https://github.com/azinchen/nordvpn/blob/master/CITIES.md
[nordvpn-countries]: https://github.com/azinchen/nordvpn/blob/master/COUNTRIES.md
[nordvpn-groups]: https://github.com/azinchen/nordvpn/blob/master/GROUPS.md
[nordvpn-technologies]: https://github.com/azinchen/nordvpn/blob/master/TECHNOLOGIES.md
[email-link]: mailto:alexander@zinchenko.com
