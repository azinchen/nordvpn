This container uses OpenVPN exclusively. The `TECHNOLOGY` environment variable selects the protocol variant. Non-OpenVPN technologies (WireGuard, IKEv2, SOCKS, HTTP Proxy) are **not supported**.

## Supported Technologies

| Value | Protocol | Obfuscation | Default Port(s) | Requires `GROUP`? |
|-------|----------|-------------|------------------|-------------------|
| `openvpn_udp` | UDP | None | 1194 | No |
| `openvpn_tcp` | TCP | None | 443 | No |
| `openvpn_xor_udp` | UDP | XOR scramble | 53, 1194, 1198, 1214, 1215, 1216, 2231 | Yes |
| `openvpn_xor_tcp` | TCP | XOR scramble | 20, 21, 80, 443, 465, 587, 993, 995 | Yes |
| `openvpn_dedicated_udp` | UDP | None | 1194 | Yes |
| `openvpn_dedicated_tcp` | TCP | None | 443 | Yes |

The default is `openvpn_udp`.

You can also use the human-readable names from the NordVPN API (e.g., `OpenVPN UDP`, `OpenVPN TCP`). The full list is in [TECHNOLOGIES.md](https://github.com/azinchen/nordvpn/blob/master/TECHNOLOGIES.md).

## Standard OpenVPN (`openvpn_udp` / `openvpn_tcp`)

The default mode. Connects to NordVPN's standard server fleet using a single port (UDP 1194 or TCP 443).

```yaml
environment:
  - TECHNOLOGY=openvpn_udp   # or openvpn_tcp
```

UDP is faster (less overhead); TCP is more reliable on restrictive networks that block UDP.

## XOR Obfuscated OpenVPN (`openvpn_xor_udp` / `openvpn_xor_tcp`)

XOR obfuscation disguises OpenVPN traffic using the [Tunnelblick XOR patch](https://github.com/Tunnelblick/Tunnelblick/tree/main/third_party/sources/openvpn), making it harder for deep packet inspection (DPI) to detect and block.

### When to use

- Your ISP or network blocks standard OpenVPN traffic
- You're behind a corporate firewall that performs DPI
- You're in a region where VPN protocols are actively filtered

### Configuration

XOR technologies **require** the `legacy_obfuscated_servers` group:

```yaml
environment:
  - TECHNOLOGY=openvpn_xor_tcp
  - GROUP=legacy_obfuscated_servers
```

Without the `GROUP`, the NordVPN API returns no servers and connection will fail.

All of this is transparent; just set `TECHNOLOGY` and `GROUP`.

### XOR key override

The default XOR scramble key is NordVPN's built-in key. If you need to override it (e.g., for a custom XOR server), set:

```yaml
environment:
  - XOR_KEY=your_custom_key
```

### Multi-port behavior

XOR connections use multiple ports with `remote-random`:

| Protocol | Ports |
|----------|-------|
| XOR TCP | 20, 21, 80, 443, 465, 587, 993, 995 |
| XOR UDP | 53, 1194, 1198, 1214, 1215, 1216, 2231 |

The firewall automatically opens pinholes for all configured remote ports. Using common service ports (80, 443, 53) helps bypass port-based blocking.

### Custom port selection

By default, XOR configs include all available ports. To force a specific port, set the `PORT` environment variable:

```yaml
environment:
  - TECHNOLOGY=openvpn_xor_tcp
  - GROUP=legacy_obfuscated_servers
  - PORT=443
```

The port must be one the server actually listens on (see table above), otherwise the connection will fail. This also works with standard (non-XOR) technologies to override the default port.

## Dedicated IP (`openvpn_dedicated_udp` / `openvpn_dedicated_tcp`)

For NordVPN accounts with the [Dedicated IP add-on](https://nordvpn.com/features/dedicated-ip/). Requires the `legacy_dedicated_ip` group:

```yaml
environment:
  - TECHNOLOGY=openvpn_dedicated_tcp
  - GROUP=legacy_dedicated_ip
```

> **Note:** The API returns Dedicated IP servers regardless of your subscription status, but you need an active Dedicated IP add-on for your NordVPN account to successfully authenticate and use these servers.

## Unsupported Technologies

The NordVPN API lists several other OpenVPN technology identifiers that have **no servers assigned** and will not work:

| Identifier | Status |
|------------|--------|
| `openvpn_udp_v6` | No servers |
| `openvpn_tcp_v6` | No servers |
| `openvpn_udp_tls_crypt` | No servers |
| `openvpn_tcp_tls_crypt` | No servers |

Non-OpenVPN technologies (`ikev2`, `wireguard_udp`, `socks`, `proxy`, etc.) are not compatible with this container.
