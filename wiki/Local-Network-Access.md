By default, all traffic is routed through the VPN. To allow access to local services, your LAN, or inter-container networks, you must explicitly define them with the `NETWORK` variable.

## Finding Your Local Network

```bash
ip route | awk '!/ (docker0|br-)/ && /src/ {print $1}'
```

## Configuration

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun \
           -e NETWORK=192.168.1.0/24 \
           -e USER=service_username -e PASS=service_password \
           azinchen/nordvpn
```

Multiple CIDRs are semicolon-separated:

```bash
-e NETWORK="192.168.1.0/24;172.20.0.0/16;10.0.0.0/8"
```

## What `NETWORK` Does

When `NETWORK` is set, the `init-firewall` script:

1. Adds a **static route** for each CIDR via the default gateway (so traffic bypasses the VPN tunnel)
2. Adds **bidirectional iptables rules** allowing traffic to/from those CIDRs
3. These rules apply **regardless of VPN state** — they remain active even if the VPN drops

## Important Notes

- **Docker subnets are NOT auto-allowed.** If containers sharing the VPN namespace need to talk to each other or to services on your LAN/host, include those CIDRs in `NETWORK`.
- **Only CIDRs (IP ranges) are supported**, not domain names.
- **Keep `NETWORK` as narrow as possible.** Broad CIDRs weaken the kill switch since traffic to those destinations is always allowed.

## Common Scenarios

### Access services on your LAN
```bash
-e NETWORK=192.168.1.0/24
```

### Allow Docker inter-container communication
```bash
-e NETWORK="192.168.1.0/24;172.20.0.0/16"
```

### Multiple network segments
```bash
-e NETWORK="10.0.0.0/8;172.16.0.0/12;192.168.0.0/16"
```

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
      - NETWORK=192.168.1.0/24;172.20.0.0/16
    ports:
      - "8080:8080"
    restart: unless-stopped

  app:
    image: nginx:alpine
    network_mode: "service:vpn"
    depends_on:
      - vpn
```
