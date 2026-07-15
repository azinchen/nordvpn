# NordVPN OpenVPN Docker Container — Wiki

Welcome to the wiki for the **NordVPN OpenVPN Docker Container**. This wiki provides detailed configuration guides, examples, and troubleshooting information beyond what's covered in the [README](https://github.com/azinchen/nordvpn#readme).

> **Looking for WireGuard?** This has a sibling project, [**azinchen/nordvpn-wg**](https://github.com/azinchen/nordvpn-wg) — the same auto-routing NordVPN container over WireGuard (NordLynx). See its [wiki](https://github.com/azinchen/nordvpn-wg/wiki) for WireGuard-specific guides.

## Getting Started

If you're new, start with the [README](https://github.com/azinchen/nordvpn#readme) for a quick-start guide, then explore the pages below for advanced configuration.

## Pages

### Configuration
- **[Server Selection](Server-Selection)** — Filter by country, city, group, or specific server hostname
- **[Server Groups](Server-Groups)** — Specialty server groups: Double VPN, Onion Over VPN, P2P, obfuscated, dedicated IP, and regional filters
- **[Technologies](Technologies)** — Supported OpenVPN technologies including XOR obfuscation
- **[IPv6 Configuration](IPv6-Configuration)** — Prevent IPv6 leaks with daemon, container, or host-level options
- **[Automatic Reconnection](Automatic-Reconnection)** — Scheduled reconnection, failure handling, and health monitoring
- **[Local Network Access](Local-Network-Access)** — Allow LAN and inter-container traffic through the firewall
- **[VPN Gateway Mode](VPN-Gateway-Mode)** — Route other containers' traffic out through the tunnel with `FORWARD_FROM`
- **[OpenVPN Options](OpenVPN-Options)** — Custom OpenVPN flags, default ciphers, and reconnection tuning
- **[Custom DNS](Custom-DNS)** — Override NordVPN's DNS servers with custom ones (Cloudflare, Google, etc.)
- **[Permissions](Permissions)** — PUID/PGID configuration for volume permissions

### Security
- **[Security Model](Security-Model)** — Kill switch behavior, rule precedence, and network access control
- **[Firewall Backends](Firewall-Backends)** — How nftables vs iptables-legacy selection works at runtime

### Examples
- **[Docker Compose Examples](Docker-Compose-Examples)** — Simple, advanced, and web-proxy compose setups
- **[Docker Run Examples](Docker-Run-Examples)** — Basic and advanced `docker run` usage

### Operations
- **[Updating and Maintenance](Updating-and-Maintenance)** — How to update the VPN container and restart dependent services
- **[Troubleshooting](Troubleshooting)** — Common problems, diagnostic tools, and log reading tips
- **[Network Diagnostics Guide](Network-Diagnostics-Guide)** — Using the built-in diagnostic tool and interpreting output

### Reference
- **[FAQ](FAQ)** — Frequently asked questions
- **[Supported Platforms](Supported-Platforms)** — Available architectures and Raspberry Pi notes
- **[Architecture and Internals](Architecture-and-Internals)** — How the s6-overlay stages, scripts, and firewall work under the hood
