## Credentials

**Q: Can I use my regular NordVPN email and password?**
No. You need **service credentials** (a separate username/password) specifically for OpenVPN connections. See [Getting Service Credentials](https://github.com/azinchen/nordvpn#getting-service-credentials).

**Q: Where do I find my service credentials?**
Log into [Nord Account Dashboard](https://my.nordaccount.com/) → NordVPN → Advanced Settings → Set up NordVPN manually → Service credentials tab.

## Features

**Q: Does this support WireGuard?**
No. This container uses OpenVPN only. See [Technologies](Technologies#supported-technologies) for the full list of supported values.

The `TECHNOLOGY` variable accepts the following values:

| Value | Description | Requires `GROUP`? |
|-------|-------------|-------------------|
| `openvpn_udp` | Standard OpenVPN over UDP (default) | No |
| `openvpn_tcp` | Standard OpenVPN over TCP | No |
| `openvpn_xor_udp` | Obfuscated OpenVPN over UDP | Yes — `GROUP=legacy_obfuscated_servers` |
| `openvpn_xor_tcp` | Obfuscated OpenVPN over TCP | Yes — `GROUP=legacy_obfuscated_servers` |
| `openvpn_dedicated_udp` | Dedicated IP OpenVPN over UDP | Yes — `GROUP=legacy_dedicated_ip` |
| `openvpn_dedicated_tcp` | Dedicated IP OpenVPN over TCP | Yes — `GROUP=legacy_dedicated_ip` |

> **Note:** Other OpenVPN technologies listed in the NordVPN API (`openvpn_udp_v6`, `openvpn_tcp_v6`, `openvpn_udp_tls_crypt`, `openvpn_tcp_tls_crypt`) have no servers assigned and will not work. Non-OpenVPN technologies (IKEv2, WireGuard, SOCKS, etc.) are not supported by this container.

**Q: Can I use port forwarding / access services from the internet?**
No. NordVPN does not support inbound port forwarding. You can only access services from your LAN by publishing ports on the VPN container and setting `NETWORK` to include your LAN CIDR.

**Q: How do I know which server I'm connected to?**
Check the container logs: `docker logs vpn | grep "Server:"`. Or run the network diagnostic: `docker exec vpn /usr/local/bin/network-diagnostic --basic`.

**Q: Can I connect to a specific server?**
Yes. Use the server hostname in `COUNTRY` or `CITY`: `-e COUNTRY=es1234` or `-e CITY=uk2567`. Specific servers get priority with `load=0`.

## Networking

**Q: Why can't my app containers reach my LAN?**
Set `NETWORK` to include your LAN CIDR (e.g., `-e NETWORK=192.168.1.0/24`). Docker subnets and LAN ranges are not auto-allowed. See [Local Network Access](Local-Network-Access).

**Q: Why do I need to publish ports on the VPN container instead of the app container?**
Containers using `network_mode: "service:vpn"` share the VPN container's network namespace. They don't have their own network stack, so port publishing only works on the VPN container.

**Q: Does IPv6 work?**
The container applies an IPv6 firewall (default DROP), but does not route IPv6 through the VPN. To prevent IPv6 leaks, disable it at the daemon or container level. See [IPv6 Configuration](IPv6-Configuration).

## Operations

**Q: Why do my app containers lose network after VPN restarts?**
Containers sharing the VPN's network namespace reference the old namespace after a restart. You must restart them too. See [Updating and Maintenance](Updating-and-Maintenance#why-dependent-containers-must-restart).

**Q: How often should I reconnect?**
Every 4–8 hours is common. Use `RECREATE_VPN_CRON` for scheduled switching and `CHECK_CONNECTION_CRON` for health monitoring. See [Automatic Reconnection](Automatic-Reconnection).

**Q: What happens if the VPN drops?**
The kill switch blocks all traffic except `NETWORK` CIDRs and NordVPN API IPs. If health monitoring is configured, the container will automatically reconnect. See [Security Model](Security-Model#traffic-control--kill-switch).

## Permissions

**Q: I'm getting permission errors on mounted volumes. How do I fix this?**
The container runs OpenVPN as the `nordvpn` user (UID/GID `912` by default). Set `PUID` and `PGID` to match your host user's UID/GID. See [Permissions](Permissions).

## Compatibility

**Q: Does this work on Raspberry Pi?**
Yes. The image supports `arm/v6`, `arm/v7`, and `arm64`. Docker pulls the correct architecture automatically.

**Q: Does this work on Synology / QNAP NAS?**
Generally yes, but some NAS devices have older kernels or limited iptables support. The container auto-detects nft vs legacy backends. Check logs for `[ENTRYPOINT] Using IPv4 backend:` to verify.

**Q: What's the difference between Docker Hub and GHCR images?**
They are identical. Use whichever registry is more convenient: `azinchen/nordvpn` (Docker Hub) or `ghcr.io/azinchen/nordvpn` (GitHub Container Registry).

## Logs & Messages

**Q: I see `DEPRECATED OPTION: --persist-key option ignored` and `--fast-io option ignored` in the logs. Is something wrong?**
No. These are harmless, cosmetic notices from newer OpenVPN versions. Both options are set in the bundled `.ovpn` config template; modern OpenVPN no longer needs them (keys are always persisted now, and `--fast-io` was removed), so it simply ignores them and prints the notice. Your connection is unaffected.

**Q: Can I silence these deprecation notices with `OPENVPN_OPTS`?**
No. They originate from options inside the config file, and OpenVPN has no command-line flag to unset a config option (`--pull-filter` only affects options *pushed by the server*). The only way to hide them would be lowering verbosity with `--verb 0`/`--verb 1`, but that also suppresses useful connection status and error messages, so it is not recommended. Leave the notices as-is — they are safe to ignore.

**Q: I see `DEPRECATED OPTION: --cipher set to 'AES-256-CBC' but missing in --data-ciphers (DEFAULT). OpenVPN ignores --cipher for cipher negotiations.` in the logs. Is something wrong?**
No. This is a cosmetic notice. NordVPN's `.ovpn` template sets `cipher AES-256-CBC`, but modern OpenVPN (2.5+) negotiates the data cipher with the server instead of using the legacy `--cipher` value. The server selects a strong cipher (you'll see `Data Channel: cipher 'AES-256-GCM'` later in the log), so the connection is unaffected and the warning can be safely ignored.

**Q: How do I disable the `--cipher ... missing in --data-ciphers` warning?**
Set `--data-ciphers` via `OPENVPN_OPTS` and include the legacy `AES-256-CBC` cipher so the value from the config is no longer reported as missing. For example:

```yaml
environment:
  - OPENVPN_OPTS=--data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305:AES-256-CBC
```

Keep `AES-256-GCM` (and optionally the others) first so the strong cipher is still preferred during negotiation; appending `AES-256-CBC` only suppresses the notice. This is purely cosmetic — the negotiated cipher does not change.


