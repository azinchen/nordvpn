Filter NordVPN servers using location and server criteria.

## Example

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun \
           -e USER=service_username -e PASS=service_password \
           -e TECHNOLOGY=openvpn_udp \
           -e COUNTRY="United States;CA;153" \
           -e CITY="New York;2619989;es1234" \
           -e GROUP="Standard VPN servers" \
           -e RANDOM_TOP=5 \
           azinchen/nordvpn
```

## Location Specification

| Filter | Accepted formats | Examples |
|--------|-----------------|----------|
| **COUNTRY** | Name, 2-letter code, or numeric ID | `United States`, `US`, `228` |
| **CITY** | Name or numeric ID | `New York`, `8971718` |
| **Specific server** | Hostname (in COUNTRY or CITY) | `es1234`, `uk2567` |

Multiple values are separated by `;` or `,` (whitespace around separators is ignored): `COUNTRY="United States;CA;228"`

### Specific Server Hostname Format

To connect to a specific NordVPN server, use its short hostname. Four patterns are recognized (case-insensitive):

| Pattern | Example | Resolved hostname | Server kind |
|---------|---------|-------------------|-------------|
| `<cc><num>` | `us1`, `DE456` | `us1.nordvpn.com` | Standard server |
| `<cc>-<cc><num>` | `ca-us100`, `uk-fr17` | `ca-us100.nordvpn.com` | Cross-country (Double VPN) |
| `<cc>-onion<num>` | `nl-onion6` | `nl-onion6.nordvpn.com` | Onion Over VPN |
| `socks-<cc><num>` | `socks-nl1` | `socks-nl1.nordvpn.com` | SOCKS proxy host |

(`<cc>` = 2-letter country code, `<num>` = one or more digits.)

Specific servers are:
- Looked up through the NordVPN API by hostname (not DNS) to obtain their address and metadata
- Given `load=0` so they always appear first in the server list
- Placed in either `COUNTRY` or `CITY` — both work the same way

**Invalid formats** (will be treated as country/city names): `usa1` (3-letter prefix), `u1` (1 letter), `us` (no digits).

Reference lists:
- [Countries](https://github.com/azinchen/nordvpn/blob/master/COUNTRIES.md)
- [Cities](https://github.com/azinchen/nordvpn/blob/master/CITIES.md)
- [Groups](https://github.com/azinchen/nordvpn/blob/master/GROUPS.md)
- [Technologies](https://github.com/azinchen/nordvpn/blob/master/TECHNOLOGIES.md)

## Selection Behavior

- **Specific servers** (e.g., `es1234`): Placed at the top of the list with `load=0`
- **Multiple locations**: Combined and sorted by server load (lowest first)
- **Single location**: Keeps NordVPN's recommended order
- **RANDOM_TOP=N**: After filtering and sorting, randomly picks from the top N servers

## Technology-Specific Groups

Some technologies require a specific `GROUP` to return servers from the API:

| Technology | Required `GROUP` |
|------------|-----------------|
| `openvpn_xor_udp` / `openvpn_xor_tcp` | `legacy_obfuscated_servers` |
| `openvpn_dedicated_udp` / `openvpn_dedicated_tcp` | `legacy_dedicated_ip` |

Without the matching group, the API returns no servers and the connection fails. Standard technologies (`openvpn_udp`, `openvpn_tcp`) work with any group or no group at all.

See [Technologies](Technologies) for full details.
