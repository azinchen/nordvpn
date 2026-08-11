_Last updated: 2026-08-11 · 24 technologies (6 supported by this image)_

Values for the `TECHNOLOGY` variable — name, identifier, or ID: `-e TECHNOLOGY=openvpn_xor_udp`

## Supported by this image

> XOR and Dedicated IP technologies additionally require the matching `GROUP` — see [Technologies](Technologies).

| Technology | Identifier | ID |
|------------|------------|----|
| OpenVPN UDP | openvpn_udp | 3 |
| OpenVPN TCP | openvpn_tcp | 5 |
| OpenVPN UDP Obfuscated | openvpn_xor_udp | 15 |
| OpenVPN TCP Obfuscated | openvpn_xor_tcp | 17 |
| OpenVPN UDP Dedicated | openvpn_dedicated_udp | 42 |
| OpenVPN TCP Dedicated | openvpn_dedicated_tcp | 45 |

## Other technologies

Non-OpenVPN protocols and OpenVPN variants without servers — not usable with this image.

<details>
<summary>Show all (18)</summary>

| Technology | Identifier | ID | Why not |
|------------|------------|----|---------|
| IKEv2/IPSec | ikev2 | 1 | non-OpenVPN |
| Socks 5 | socks | 7 | non-OpenVPN |
| HTTP Proxy | proxy | 9 | non-OpenVPN |
| PPTP | pptp | 11 | non-OpenVPN |
| L2TP/IPSec | l2tp | 13 | non-OpenVPN |
| HTTP CyberSec Proxy | proxy_cybersec | 19 | non-OpenVPN |
| HTTP Proxy (SSL) | proxy_ssl | 21 | non-OpenVPN |
| HTTP CyberSec Proxy (SSL) | proxy_ssl_cybersec | 23 | non-OpenVPN |
| IKEv2/IPSec IPv6 | ikev2_v6 | 26 | non-OpenVPN |
| OpenVPN UDP IPv6 | openvpn_udp_v6 | 29 | no servers in the fleet |
| OpenVPN TCP IPv6 | openvpn_tcp_v6 | 32 | no servers in the fleet |
| Wireguard | wireguard_udp | 35 | non-OpenVPN |
| OpenVPN UDP TLS Crypt | openvpn_udp_tls_crypt | 38 | no servers in the fleet |
| OpenVPN TCP TLS Crypt | openvpn_tcp_tls_crypt | 41 | no servers in the fleet |
| Skylark | skylark | 48 | non-OpenVPN |
| Mesh Relay | mesh_relay | 50 | non-OpenVPN |
| NordWhisper | nordwhisper | 51 | non-OpenVPN |
| NordWhisper UDP | nordwhisper_udp | 56 | non-OpenVPN |

</details>

---
_Generated from the NordVPN API; this page reflects the server lists baked into the latest released image._

See [Technologies](Technologies) · [Countries List](Countries-List) · [Cities List](Cities-List) · [Groups List](Groups-List)
