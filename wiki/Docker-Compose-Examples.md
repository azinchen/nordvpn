## Simple VPN + Application Setup

```yaml
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
      - RECREATE_VPN_CRON=0 */6 * * *
      - NETWORK=192.168.1.0/24
    ports:
      - "8080:8080"
      - "3000:3000"
    restart: unless-stopped

  webapp:
    image: nginx:alpine
    container_name: webapp
    network_mode: "service:vpn"
    depends_on:
      - vpn
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped

  api-service:
    image: node:alpine
    container_name: api-service
    network_mode: "service:vpn"
    depends_on:
      - vpn
    working_dir: /app
    volumes:
      - ./app:/app
    command: ["npm", "start"]
    restart: unless-stopped
```

## Advanced Setup with Local Access

```yaml
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
      - "8080:8080"
      - "3000:3000"
      - "9000:9000"
      - "6379:6379"
    restart: unless-stopped

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
    network_mode: host
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./config/grafana:/var/lib/grafana
    restart: unless-stopped
```

## Web Proxy Setup

```yaml
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

  app:
    image: nginx:alpine
    container_name: webapp
    network_mode: "service:vpn"
    depends_on:
      - vpn
    volumes:
      - ./html:/usr/share/nginx/html
    restart: unless-stopped

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

## Key Concepts

- **Ports must be published on the VPN container**, not on application containers using `network_mode: "service:vpn"`.
- Use `depends_on` to ensure the VPN starts before dependent services.
- Services that should **not** use the VPN can use `network_mode: host` or a separate Docker network.
- When the VPN container restarts, all dependent containers must also be restarted. See [Updating and Maintenance](Updating-and-Maintenance#why-dependent-containers-must-restart).

## XOR Obfuscation Setup

Use XOR obfuscation to bypass deep packet inspection (DPI) on networks that block standard OpenVPN traffic. See [Technologies](Technologies#xor-obfuscated-openvpn-openvpn_xor_udp--openvpn_xor_tcp) for details.

```yaml
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
      - TECHNOLOGY=openvpn_xor_tcp
      - GROUP=legacy_obfuscated_servers
      - COUNTRY=Netherlands;DE
      - RECREATE_VPN_CRON=0 */6 * * *
      - CHECK_CONNECTION_CRON=*/5 * * * *
      - NETWORK=192.168.1.0/24
    ports:
      - "8080:8080"
    restart: unless-stopped

  app:
    image: nginx:alpine
    container_name: webapp
    network_mode: "service:vpn"
    depends_on:
      - vpn
    restart: unless-stopped
```

> **Note:** `GROUP=legacy_obfuscated_servers` is required — without it, no XOR servers will be returned. Not all countries have obfuscated servers.
