# NordVPN OpenVPN Docker Container — Wiki

**OpenVPN client for NordVPN in a Docker container, with a fail-closed kill switch.**

`nordvpn` packages OpenVPN — built from source with the Tunnelblick XOR patches — into a small Alpine-based image that picks a NordVPN server for you and routes other containers' traffic, or downstream subnets, through it. This wiki holds the detailed configuration guides, examples and troubleshooting beyond the [README](https://github.com/azinchen/nordvpn#readme).

> **Looking for WireGuard?** This has a sibling project, [**azinchen/nordvpn-wg**](https://github.com/azinchen/nordvpn-wg) — the same auto-routing NordVPN container over WireGuard (NordLynx). See its [wiki](https://github.com/azinchen/nordvpn-wg/wiki) for WireGuard-specific guides.

---

## What you get

- **Easy Setup** — Route any container's traffic through VPN with `--net=container:vpn` ([Docker Run Examples](Docker-Run-Examples))
- **Server Selection** — Auto-select servers by country, city, group, or specific hostname ([Server Selection](Server-Selection))
- **Load Balancing** — Sorts by server load when multiple locations are given ([Server Selection](Server-Selection#selection-behavior))
- **Access Token** — Pass `TOKEN` and the container fetches the service credentials itself ([FAQ](FAQ#credentials))
- **Automatic Reconnection** — Periodic server switching and health monitoring ([Automatic Reconnection](Automatic-Reconnection))
- **XOR Obfuscation** — Built-in XOR patches disguise OpenVPN traffic to bypass DPI ([Technologies](Technologies#xor-obfuscated-openvpn-openvpn_xor_udp--openvpn_xor_tcp))
- **Kill Switch** — Default-deny firewall blocks all traffic when VPN is down ([Security Model](Security-Model#traffic-control--kill-switch))
- **Local Network Access** — Allow specific CIDRs with `NETWORK=...` ([Local Network Access](Local-Network-Access))
- **Custom DNS** — Resolve through the tunnel; override with `DNS=...` ([Custom DNS](Custom-DNS))
- **IPv6 Configuration** — Built-in chains default to DROP ([IPv6 Configuration](IPv6-Configuration))
- **Firewall Backends** — Auto-selects nft or legacy backend ([Firewall Backends](Firewall-Backends))
- **VPN Gateway Mode** — Route downstream subnets through the tunnel with `FORWARD_FROM` ([VPN Gateway Mode](VPN-Gateway-Mode))
- **TTL Tuning** — `TTL_SET` / `TTL_INC` hide cascade hops from client traceroutes ([VPN Gateway Mode](VPN-Gateway-Mode#ttl-tuning-ttl_set--ttl_inc))
- **Docker Health Status** — Opt-in `HEALTHCHECK` reports tunnel state to Docker ([Automatic Reconnection](Automatic-Reconnection#docker-health-status))
- **Network Diagnostics** — Built-in network diagnostic tool and `status.json` status file ([Network Diagnostics Guide](Network-Diagnostics-Guide))

---

## Start here

| If you want to… | Go to |
|---|---|
| Get connected in 5 minutes | **[README — Quick Start](https://github.com/azinchen/nordvpn#-quick-start)** |
| Copy a complete compose stack | **[Docker Compose Examples](Docker-Compose-Examples)**, **[Docker Run Examples](Docker-Run-Examples)** |
| Pick countries, cities, groups or a specific server | **[Server Selection](Server-Selection)**, **[Server Groups](Server-Groups)** |
| Choose UDP / TCP, XOR obfuscation or Dedicated IP | **[Technologies](Technologies)** |
| Look up names and IDs for `COUNTRY`, `CITY`, `GROUP`, `TECHNOLOGY` | **[Countries](Countries-List)**, **[Cities](Cities-List)**, **[Groups](Groups-List)**, **[Technologies](Technologies-List)** |
| Reach published ports from your LAN | **[Local Network Access](Local-Network-Access)** |
| Route other-netns containers or a VPN server through the tunnel | **[VPN Gateway Mode](VPN-Gateway-Mode)** |
| Use your own DNS resolvers | **[Custom DNS](Custom-DNS)** |
| Stop IPv6 leaks | **[IPv6 Configuration](IPv6-Configuration)** |
| Understand the kill switch | **[Security Model](Security-Model)**, **[Firewall Backends](Firewall-Backends)** |
| Tune rotations, reconnects and the health check | **[Automatic Reconnection](Automatic-Reconnection)**, **[OpenVPN Options](OpenVPN-Options)** |
| Update the image without breaking dependent containers | **[Updating and Maintenance](Updating-and-Maintenance)** |
| Debug a connection | **[Troubleshooting](Troubleshooting)**, **[Network Diagnostics Guide](Network-Diagnostics-Guide)** |
| Check your CPU architecture is covered | **[Supported Platforms](Supported-Platforms)** |
| See how the image works inside | **[Architecture and Internals](Architecture-and-Internals)** |
| Build it yourself / understand image tags and releases | **[Building and CI](Building-and-CI)** |
| Quick answers | **[FAQ](FAQ)** |

The server lists are generated from the NordVPN API and reflect the data baked into the latest released image.

---

## At a glance

```bash
docker run -d --name vpn \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -e USER=service_username \
  -e PASS=service_password \
  -e COUNTRY="United States;CA" \
  -e NETWORK=192.168.1.0/24 \
  azinchen/nordvpn:latest
```

Then route an app container through it:

```bash
docker run -d --net=container:vpn my-app
```

Everything the app sends now goes through the tunnel — or nowhere. Publish the app's ports on the `vpn` container, and see the [README](https://github.com/azinchen/nordvpn#readme) for service credentials and the full variable list.

> **Project:** https://github.com/azinchen/nordvpn
> **License:** AGPL-3.0
