The `GROUP` environment variable filters the NordVPN server fleet by specialty. Each group is a separate set of servers with different capabilities. Only **one** group can be set at a time.

## Quick Reference

| Group | Identifier | Compatible Technologies | Availability |
|-------|-----------|------------------------|--------------|
| Standard VPN servers | `legacy_standard` | `openvpn_udp`, `openvpn_tcp` | All countries |
| P2P | `legacy_p2p` | `openvpn_udp`, `openvpn_tcp` | Most countries |
| Double VPN | `legacy_double_vpn` | `openvpn_udp`, `openvpn_tcp` | Limited country pairs |
| Onion Over VPN | `legacy_onion_over_vpn` | `openvpn_udp`, `openvpn_tcp` | Very limited (NL, SE, CH) |
| Obfuscated Servers | `legacy_obfuscated_servers` | `openvpn_xor_udp`, `openvpn_xor_tcp` | Many countries |
| Dedicated IP | `legacy_dedicated_ip` | `openvpn_dedicated_udp`, `openvpn_dedicated_tcp` | Subscription-dependent |
| Anti DDoS | `legacy_anti_ddos` | `openvpn_udp`, `openvpn_tcp` | Limited |
| Europe | `europe` | `openvpn_udp`, `openvpn_tcp` | Regional |
| The Americas | `the_americas` | `openvpn_udp`, `openvpn_tcp` | Regional |
| Asia Pacific | `asia_pacific` | `openvpn_udp`, `openvpn_tcp` | Regional |
| Africa, the Middle East and India | `africa_the_middle_east_and_india` | `openvpn_udp`, `openvpn_tcp` | Regional |

You can also use the human-readable names (e.g., `GROUP=Double VPN`) or numeric IDs. The full list is in [GROUPS.md](https://github.com/azinchen/nordvpn/blob/master/GROUPS.md).

When `GROUP` is not set, the API returns servers from the default recommended pool (equivalent to `legacy_standard`).

## Standard VPN Servers (`legacy_standard`)

The default NordVPN fleet. General-purpose servers suitable for everyday use.

```yaml
environment:
  - TECHNOLOGY=openvpn_udp
  # GROUP not needed — this is the default
  - COUNTRY=United States
```

Available in all countries and cities. This is what you get when `GROUP` is omitted.

## P2P (`legacy_p2p`)

Servers optimized for peer-to-peer traffic. These allow the incoming connections that BitTorrent and other P2P protocols require.

```yaml
environment:
  - TECHNOLOGY=openvpn_udp
  - GROUP=legacy_p2p
  - COUNTRY=Netherlands
```

Use when torrenting or file sharing. Available in most countries, though some countries where P2P is restricted by law may not have P2P servers.

## Double VPN (`legacy_double_vpn`)

Traffic is encrypted twice and routed through two VPN servers in different countries. The entry server re-encrypts your traffic and forwards it to the exit server.

```yaml
environment:
  - TECHNOLOGY=openvpn_udp
  - GROUP=legacy_double_vpn
```

Server names show both countries (e.g., `ca-us75` = Canada entry → United States exit). You can filter by `COUNTRY` to select the exit country, but only pre-defined country pairs are available.

### When to use

- Maximum privacy requirements (journalism, activism, whistleblowing)
- When you need two layers of encryption
- When you want your traffic to pass through two jurisdictions

### Trade-offs

- Higher latency than standard servers (traffic traverses two hops)
- Lower throughput due to double encryption
- Not compatible with P2P traffic

## Onion Over VPN (`legacy_onion_over_vpn`)

The VPN server routes your outbound traffic into the Tor network. No local Tor client is needed.

```yaml
environment:
  - TECHNOLOGY=openvpn_udp
  - GROUP=legacy_onion_over_vpn
```

Available in very few locations (Netherlands, Sweden, Switzerland at time of writing).

### When to use

- Accessing `.onion` sites without installing Tor
- Adding a VPN layer before Tor for extra anonymity
- When you want your ISP to see only VPN traffic, not Tor traffic

### Important: DNS configuration

**Do not override DNS** when using Onion Over VPN. The server pushes NordVPN's own DNS servers (`103.86.96.100`, `103.86.99.100`) which route DNS queries through the Tor network. If you override DNS with external resolvers (e.g., Cloudflare `1.1.1.1`), DNS queries will fail because Tor only carries TCP traffic and standard DNS uses UDP.

```yaml
# CORRECT — let the server push its own DNS
environment:
  - TECHNOLOGY=openvpn_udp
  - GROUP=legacy_onion_over_vpn
  - OPENVPN_OPTS=--mute-replay-warnings --ping-exit 60

# WRONG — this will break DNS resolution
environment:
  - OPENVPN_OPTS=--pull-filter ignore "dhcp-option DNS" --dhcp-option DNS 1.1.1.1
```

### Trade-offs

- Significantly slower than standard or Double VPN (Tor adds multiple hops)
- Not compatible with P2P traffic
- Some websites block Tor exit nodes

## Obfuscated Servers (`legacy_obfuscated_servers`)

Servers that support XOR scrambling to disguise OpenVPN traffic, evading deep packet inspection (DPI).

```yaml
environment:
  - TECHNOLOGY=openvpn_xor_tcp
  - GROUP=legacy_obfuscated_servers
  - COUNTRY=United Kingdom
```

**Requires** an XOR technology (`openvpn_xor_udp` or `openvpn_xor_tcp`). Standard OpenVPN technologies will return no servers from this group.

See [Technologies](Technologies#xor-obfuscated-openvpn-openvpn_xor_udp--openvpn_xor_tcp) for XOR-specific details including multi-port behavior and custom port selection.

## Dedicated IP (`legacy_dedicated_ip`)

For NordVPN accounts with the [Dedicated IP add-on](https://nordvpn.com/features/dedicated-ip/). Provides a static IP address assigned exclusively to your account.

```yaml
environment:
  - TECHNOLOGY=openvpn_dedicated_udp
  - GROUP=legacy_dedicated_ip
```

**Requires** a dedicated technology (`openvpn_dedicated_udp` or `openvpn_dedicated_tcp`). The API returns Dedicated IP servers regardless of your subscription status, but you need an active Dedicated IP add-on for your NordVPN account to successfully authenticate and use these servers.

### When to use

- IP whitelisting for remote access
- Services that block shared VPN IP addresses
- When you need a consistent public IP

## Anti DDoS (`legacy_anti_ddos`)

Servers with DDoS protection.

```yaml
environment:
  - TECHNOLOGY=openvpn_udp
  - GROUP=legacy_anti_ddos
```

Useful for gaming or hosting services exposed through the VPN. This group may have limited server availability.

## Regional Groups

Broad geographic filters that return servers from an entire region rather than a specific country.

| Group | Identifier |
|-------|-----------|
| Europe | `europe` |
| The Americas | `the_americas` |
| Asia Pacific | `asia_pacific` |
| Africa, the Middle East and India | `africa_the_middle_east_and_india` |

```yaml
environment:
  - TECHNOLOGY=openvpn_udp
  - GROUP=europe
  - RANDOM_TOP=10
```

Use when you don't need a specific country — just a region. These work with standard OpenVPN technologies.

## Combining with Other Parameters

`GROUP` is sent to the NordVPN API as an AND filter alongside other parameters. All filters must match for a server to be returned.

| Parameter | Combines with `GROUP`? | Notes |
|-----------|----------------------|-------|
| `COUNTRY` | Yes | Servers must match both group and country |
| `CITY` | Yes | Servers must match both group and city |
| `TECHNOLOGY` | Yes | Some groups **require** specific technologies (see table above) |
| `RANDOM_TOP` | Yes | Applied after filtering — picks randomly from top N results |
| `PORT` | Yes | Overrides the default port for the selected technology |

### Restrictions

- **One group at a time.** The API accepts a single group filter. You cannot combine `legacy_p2p` with `legacy_double_vpn`, for example.
- **Technology pairing matters.** Obfuscated and Dedicated groups require their matching technologies. Standard groups work with `openvpn_udp` or `openvpn_tcp`.
- **Empty results.** If the combination of `GROUP` + `COUNTRY` + `TECHNOLOGY` has no matching servers, the container falls back to default recommended servers (without the group filter).

## Legacy and Internal Groups

The NordVPN API also lists groups that are **not useful** for this container:

| Group | Reason |
|-------|--------|
| `legacy_ultra_fast_tv` (ID 5) | Legacy streaming group — few or no servers |
| `legacy_netflix_usa` (ID 13) | Legacy streaming group — few or no servers |
| `legacy_socks5_proxy` (ID 245) | SOCKS5 protocol — not supported by this container |
| `anycast-dns`, `geo_dns`, `grafana`, `kapacitor`, `fastnetmon` | NordVPN internal infrastructure |
