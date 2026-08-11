_Last updated: 2026-08-11 · 24 technologies (6 supported by this image)_

Values for the `TECHNOLOGY` variable — name, identifier, or ID: `-e TECHNOLOGY=openvpn_xor_udp`

> ✅ Supported by this image · ⚠️ OpenVPN-based but currently no servers in the fleet · — not supported (non-OpenVPN). XOR and Dedicated IP technologies additionally require the matching `GROUP` — see [Technologies](Technologies).

| Technology | Identifier | ID | Supported |
|------------|------------|----|-----------|
| IKEv2/IPSec | ikev2 | 1 | — |
| OpenVPN UDP | openvpn_udp | 3 | ✅ |
| OpenVPN TCP | openvpn_tcp | 5 | ✅ |
| Socks 5 | socks | 7 | — |
| HTTP Proxy | proxy | 9 | — |
| PPTP | pptp | 11 | — |
| L2TP/IPSec | l2tp | 13 | — |
| OpenVPN UDP Obfuscated | openvpn_xor_udp | 15 | ✅ |
| OpenVPN TCP Obfuscated | openvpn_xor_tcp | 17 | ✅ |
| HTTP CyberSec Proxy | proxy_cybersec | 19 | — |
| HTTP Proxy (SSL) | proxy_ssl | 21 | — |
| HTTP CyberSec Proxy (SSL) | proxy_ssl_cybersec | 23 | — |
| IKEv2/IPSec IPv6 | ikev2_v6 | 26 | — |
| OpenVPN UDP IPv6 | openvpn_udp_v6 | 29 | ⚠️ No servers |
| OpenVPN TCP IPv6 | openvpn_tcp_v6 | 32 | ⚠️ No servers |
| Wireguard | wireguard_udp | 35 | — |
| OpenVPN UDP TLS Crypt | openvpn_udp_tls_crypt | 38 | ⚠️ No servers |
| OpenVPN TCP TLS Crypt | openvpn_tcp_tls_crypt | 41 | ⚠️ No servers |
| OpenVPN UDP Dedicated | openvpn_dedicated_udp | 42 | ✅ |
| OpenVPN TCP Dedicated | openvpn_dedicated_tcp | 45 | ✅ |
| Skylark | skylark | 48 | — |
| Mesh Relay | mesh_relay | 50 | — |
| NordWhisper | nordwhisper | 51 | — |
| NordWhisper UDP | nordwhisper_udp | 56 | — |

---
_Generated from the NordVPN API; this page reflects the server lists baked into the latest released image._

See [Technologies](Technologies) · [Countries List](Countries-List) · [Cities List](Cities-List) · [Groups List](Groups-List)
