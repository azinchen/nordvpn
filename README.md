[![logo](https://github.com/azinchen/nordvpn/raw/master/NordVpn_logo.png)](https://www.nordvpn.com/)

# NordVPN Docker Container

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
- **🔒 Local Network Access**: Maintain access to local services while using VPN
- **🛡️ Kill Switch**: All traffic is blocked when VPN is down, except DNS, local networks, and whitelisted domains
- **🏗️ Multi-Architecture**: Supports different platforms including ARM, x86, and enterprise systems

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

- Docker with `--cap-add=NET_ADMIN` and `--device /dev/net/tun` support
- **NordVPN Service Credentials** (not regular account credentials)

### Security Features

**🛡️ Traffic Control & Kill Switch**
- **Default-deny (egress):** All outbound traffic is blocked unless it goes through the VPN interface **or** matches the configured exceptions (`NETWORK` or `WHITELIST`)
- **Bring-up:** Before the VPN tunnel is established, only **essential services** and the configured exceptions (`NETWORK`, `WHITELIST`) are allowed. Everything else is blocked
- **Kill switch:** If the VPN drops, traffic remains blocked **except** for **essential services** and the configured exceptions (`NETWORK`, `WHITELIST`)
- **Container routing:** Containers using `network_mode: "service:vpn"` share the VPN container’s network namespace and inherit these policies
- **Inbound (local/LAN only):** No connections from the host or LAN reach the stack **unless you publish ports on the VPN container**. **Public inbound via NordVPN is not supported** (no port forwarding)

**🔒 Network Access Control (Exceptions)**
- **Local network access (always on):** Set `NETWORK=192.168.1.0/24` (comma-separated CIDRs supported) to allow access to those subnets **regardless of VPN status**
- **Domain allowlist (always on):** Set `WHITELIST=example.com,foo.bar` to permit those domains to bypass the VPN **regardless of VPN status**
- **Essential services (always allowed):**
  - DNS lookups are **not blocked** (uses the image’s default resolvers)
  - NordVPN API over HTTPS to select a VPN server based on settings before establishing the tunnel

**⚖️ Rule Precedence**
1. **Always-allowed:** Essential services → DNS + VPN control/API
2. **Exceptions:** If destination matches `NETWORK` (CIDR) or `WHITELIST` (domain), allow (bypass/LAN), regardless of VPN state
3. **VPN path:** If VPN is **up** and traffic is not an exception, allow only via VPN interface
4. **Default-deny:** Otherwise, block

**⚠️ Security Note**
Because `NETWORK` and `WHITELIST` remain open when the VPN is down, this is **not a strict kill switch**. Limit exceptions to the minimum necessary and prefer CIDRs/domains you trust.

### Container Registries

The image is available from two registries:

- **Docker Hub**: `azinchen/nordvpn` - Main distribution, publicly accessible
- **GitHub Container Registry**: `ghcr.io/azinchen/nordvpn` - Alternative source, same image

Both registries contain identical images. Use whichever is more convenient for your setup.

### Getting Service Credentials

For manual OpenVPN setup, you need special service credentials from your NordVPN account:

1. Log into your [Nord Account Dashboard](https://my.nordaccount.com/)
2. Click on **NordVPN**
3. Under **Advanced Settings**, click **Set up NordVPN manually**
4. Go to the **Service credentials** tab
5. Copy the **Username** and **Password** shown there

**Note**: These are different from your regular NordVPN login credentials and are specifically required for OpenVPN connections.

## Docker Compose Examples

### Simple VPN + Application Setup

```yaml
version: "3.8"
services:
  # VPN Container
  vpn:
    image: azinchen/nordvpn:latest  # or ghcr.io/azinchen/nordvpn:latest
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

  # Application using VPN
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
    image: azinchen/nordvpn:latest  # or ghcr.io/azinchen/nordvpn:latest
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
    image: azinchen/nordvpn:latest  # or ghcr.io/azinchen/nordvpn:latest
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
- **Country**: Can be defined by name (`United States`), code (`US`), or ID (`228`)
- **City**: Can be defined by name (`New York`) or ID (`8971718`)
- **Specific Server**: Use server hostname (e.g., `es1234`, `uk2567`) in either COUNTRY or CITY - these servers get priority with load=0

**Server Selection Behavior:**
- **Specific servers**: Named servers (e.g., `es1234`) are placed at the top of the list with load=0 for highest priority
- **Multiple locations**: Servers are combined from all specified locations and sorted by load (lowest first)
- **Single location**: Maintains NordVPN's recommended server order for optimal performance  
- **RANDOM_TOP**: Applies after location filtering and load sorting for variety

### Automatic Reconnection

#### Scheduled Reconnection
Automatically switch to different servers on a schedule:

```bash
# Reconnect every 6 hours at minute 0
-e RECREATE_VPN_CRON="0 */6 * * *"

# Reconnect daily at 3 AM
-e RECREATE_VPN_CRON="0 3 * * *"

# Reconnect every 4 hours
-e RECREATE_VPN_CRON="0 */4 * * *"
```

#### Connection Failure Handling
Handle disconnections by switching to a new server automatically:

```bash
# Force reconnect to different server on connection loss
-e OPENVPN_OPTS="--pull-filter ignore ping-restart --ping-exit 180"

# Alternative: More aggressive reconnection
-e OPENVPN_OPTS="--ping 10 --ping-exit 60 --ping-restart 300"
```

#### Connection Health Monitoring
Monitor VPN connection and reconnect if internet is not accessible:

```bash
# Check connection every 5 minutes
-e CHECK_CONNECTION_CRON="*/5 * * * *"
-e CHECK_CONNECTION_URL="https://1.1.1.1;https://8.8.8.8"
-e CHECK_CONNECTION_ATTEMPTS=3
-e CHECK_CONNECTION_ATTEMPT_INTERVAL=10
```

### Local Network Access

Enable access to local services while using VPN:

```bash
# Find your local network
ip route | awk '!/ (docker0|br-)/ && /src/ {print $1}'

# Configure container with local network access
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun \
           -e NETWORK=192.168.1.0/24 \
           -e USER=service_username -e PASS=service_password \
           azinchen/nordvpn
```

**Multiple Networks:**
```bash
-e NETWORK="192.168.1.0/24;172.20.0.0/16;10.0.0.0/8"
```

**IPv6 Support:**
```bash
-e NETWORK6="fe00:d34d:b33f::/64"
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

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `USER` | **Required** - NordVPN service credentials username | - | `service_username` |
| `PASS` | **Required** - NordVPN service credentials password | - | `service_password` |
| `COUNTRY` | Filter by countries: name, code, ID, or specific server hostname ([list][nordvpn-countries]) | All countries | `United States;CA;228;es1234` |
| `CITY` | Filter by cities: name, ID, or specific server hostname ([list][nordvpn-cities]) | All cities | `New York;8971718;uk2567` |
| `GROUP` | Filter by server group ([list][nordvpn-groups]) | All groups | `P2P` or `Standard VPN servers` |
| `TECHNOLOGY` | Filter by technology - OpenVPN only supported ([list][nordvpn-technologies]) | OpenVPN UDP | `openvpn_udp` |
| `RANDOM_TOP` | Randomize top N servers from filtered list | Disabled | `10` |
| `RECREATE_VPN_CRON` | Schedule for server switching (cron format) | Disabled | `0 */6 * * *` (every 6 hours) |
| `CHECK_CONNECTION_CRON` | Schedule for connection monitoring | Disabled | `*/5 * * * *` (every 5 minutes) |
| `CHECK_CONNECTION_URL` | URLs to test connectivity (semicolon separated) | None | `https://1.1.1.1;https://8.8.8.8` |
| `CHECK_CONNECTION_ATTEMPTS` | Number of connection test attempts | `5` | `5` |
| `CHECK_CONNECTION_ATTEMPT_INTERVAL` | Seconds between failed attempts | `10` | `10` |
| `NETWORK` | Local networks for access (semicolon separated) | None | `192.168.1.0/24;172.20.0.0/16` |
| `NETWORK6` | IPv6 networks for access (semicolon separated) | None | `fe00:d34d:b33f::/64` |
| `WHITELIST` | Domains accessible outside VPN | None | `local.example.com` |
| `OPENVPN_OPTS` | Additional OpenVPN parameters | None | `--mute-replay-warnings` |

### Server Lists
- **Countries**: [View available countries][nordvpn-countries]
- **Cities**: [View available cities][nordvpn-cities]  
- **Groups**: [View server groups][nordvpn-groups]
- **Technologies**: [View technologies][nordvpn-technologies]

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

Docker will automatically pull the correct architecture for your system.

## Updating the VPN container & dependent services

When the `vpn` container is restarted—whether due to an image update or a manual restart—every container that uses `network_mode: "service:vpn"` must also be restarted. These containers share the VPN container’s network namespace; if they keep running while `vpn` is recreated, they remain attached to a stale namespace and can lose outbound connectivity until they are restarted.

### With Docker Compose

Use the same service names as in your compose file (examples below use `webapp`, `api-service`, and `redis`). The key is to recreate `vpn` first and then force-recreate all services that have `network_mode: "service:vpn"`:

```bash
# Pull and recreate the VPN container
docker compose pull vpn
docker compose up -d --no-deps --force-recreate vpn

# Then force-recreate all services that use vpn's network namespace
docker compose up -d --force-recreate webapp api-service redis
```

Tip (optional): capture this in a Makefile target so it's easy to run consistently.

### With plain Docker (no Compose)

Recreate `vpn` with the same flags you originally used, then restart the dependent containers:

```bash
docker pull azinchen/nordvpn:latest   # or ghcr.io/azinchen/nordvpn:latest
docker stop vpn && docker rm vpn
# Re-run your "vpn" container with the same args as before...
# Then restart each dependent container:
docker restart webapp api-service redis
```

### Safer automated updates for Compose stacks

For safer, repeatable updates of Compose-defined stacks, consider using
[azinchen/update-docker-containers](https://github.com/azinchen/update-docker-containers).
It can pull images and recreate services predictably; when updating `vpn`, ensure that all
services using `network_mode: "service:vpn"` are force-recreated immediately afterward.

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
