By default, the container uses DNS servers pushed by NordVPN's OpenVPN server (typically `103.86.96.100` and `103.86.99.100`). These are NordVPN's own DNS servers and may apply regional filtering — for example, certain domains may be sinkholed when connected through UK exit nodes.

This page covers how to override the DNS servers used inside the VPN tunnel.

## Method 1: Bind-Mount a Custom `resolv.conf`

The simplest approach. Mount a custom `resolv.conf` file as read-only so OpenVPN's `up.sh` script cannot overwrite it:

**1. Create a `resolv.conf` file:**

```
nameserver 1.1.1.1
nameserver 1.0.0.1
```

**2. Mount it in your compose file:**

```yaml
services:
  vpn:
    volumes:
      - ./resolv.conf:/etc/resolv.conf:ro
```

The `:ro` (read-only) flag prevents OpenVPN from overwriting it with server-pushed DNS.

## Method 2: Pull-Filter with Custom DHCP Options

Use OpenVPN's `--pull-filter` to block server-pushed DNS and `--dhcp-option` to inject your own. This lets the container's built-in `up.sh` script write your custom DNS to `/etc/resolv.conf` naturally:

```yaml
services:
  vpn:
    environment:
      - OPENVPN_OPTS=--pull-filter ignore "dhcp-option DNS" --dhcp-option DNS 1.1.1.1 --dhcp-option DNS 1.0.0.1
```

**How it works:**
- `--pull-filter ignore "dhcp-option DNS"` — blocks DNS servers pushed by the NordVPN server
- `--dhcp-option DNS 1.1.1.1` — injects Cloudflare DNS as a client-side option
- The `up.sh` script reads these options and writes them to `/etc/resolv.conf`

## Popular DNS Providers

| Provider | Primary | Secondary |
|----------|---------|-----------|
| Cloudflare | `1.1.1.1` | `1.0.0.1` |
| Google | `8.8.8.8` | `8.8.4.4` |
| Quad9 | `9.9.9.9` | `149.112.112.112` |
| OpenDNS | `208.67.222.222` | `208.67.220.220` |

## Why Not Docker `dns:`?

Docker's `dns:` option configures an internal resolver (`127.0.0.11`) that forwards to the specified servers. However, in VPN containers with strict firewall rules (kill switch), Docker's internal DNS resolver cannot forward queries through the VPN tunnel, resulting in `connection refused` errors. Use one of the methods above instead.

## Verifying Your DNS Configuration

After the VPN connects, check which DNS servers are active:

```bash
docker exec vpn cat /etc/resolv.conf
```

Test resolution:

```bash
docker exec vpn host example.com
```

Run the full network diagnostic to see DNS details:

```bash
docker exec vpn /usr/local/bin/network-diagnostic
```

The diagnostic output includes a **DNS configuration** section showing the active nameservers and their geolocation.
