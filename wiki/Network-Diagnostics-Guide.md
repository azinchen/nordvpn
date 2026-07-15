The container includes a built-in diagnostic tool at `/usr/local/bin/network-diagnostic` that provides comprehensive network and VPN status information.

## Running Diagnostics

### Automatic (on every connection)

```bash
-e NETWORK_DIAGNOSTIC_ENABLED=true
```

### Manual

```bash
# Full diagnostics
docker exec vpn /usr/local/bin/network-diagnostic

# Quick IP + location check only
docker exec vpn /usr/local/bin/network-diagnostic --basic
```

## Modes

### `--basic` Mode

Outputs a single line:

```
Public IP address 203.0.113.42, location Amsterdam NL
```

Returns exit code 0 on success, 1 if the public IP couldn't be determined.

### `--full` Mode (default)

Produces a comprehensive report covering all sections below.

## Output Sections (Full Mode)

### 1. Header & VPN Status

```
═══════════════════════════════════════════
  OpenVPN DIAG — 2026-03-22 16:30:00 UTC
  VPN: CONNECTED | iptables: nft | Kernel: 6.8.0-45
═══════════════════════════════════════════
```

### 2. Device & Connection Info

- Interface name (tun0/tap0)
- Common name, local/remote ifconfig addresses
- Route gateway
- Connected peer IP:port
- Protocol (UDP/TCP)
- Local port
- Connection uptime (e.g., `2d 14:30:45`)

### 3. System Network State

- `ip addr` — all interface addresses
- `ip link` — link states
- `ip route` — routing table
- `ip rule` — policy routing rules

### 4. Firewall Rules

- Full iptables/ip6tables filter and NAT table dumps
- Detects whether nft or legacy backend is in use

### 5. Public IP & Geolocation

- JSON output from IP lookup service
- Shows IP, city, country, ISP/org

### 6. DNS Configuration

- Contents of `/etc/resolv.conf` or `resolvectl` output
- For each nameserver: geolocation lookup (city, country, organization)
- Resolver identity via `whoami.cloudflare` or `hostname.bind` queries

### 7. Connectivity Tests

- IPv4/IPv6 ping tests
- Traceroute to public test IP
- Route validation verdicts

## IP Resolution Fallback

The diagnostic tool uses a 2-tier fallback to determine your public IP:

| Tier | Service | What it returns |
|------|---------|-----------------|
| 1 | `ipinfo.io/json` | IP, city, country (single JSON request) |
| 2 | `ifconfig.co` + `/city` + `/country-iso` | IP, city, country (separate requests) |

Each request has a 4-second timeout. Tier 2 is only tried if tier 1 fails.

## Management Interface Queries

The diagnostic tool queries OpenVPN's management interface (localhost:7505) for live connection data:

| Command | Data returned |
|---------|--------------|
| `status` | Connected clients, traffic stats |
| `state` | Connection timestamp, remote IP, port, protocol |

From the `state` response, the tool calculates connection uptime and extracts the VPN server details.

## Example Output (Basic)

```
Public IP address 185.93.1.42, location Zurich CH
```

## Using Diagnostics for Troubleshooting

| Symptom | What to check in diagnostic output |
|---------|------|
| Wrong country | Public IP geolocation — confirms which exit you're using |
| DNS leaks | DNS section — nameservers should be VPN-provided (10.x.x.x) |
| No connectivity | VPN status line — check if connected, verify tun0 exists |
| Slow speeds | Connection details — check protocol (UDP vs TCP), server load |
| Firewall issues | Iptables dump — look for missing ACCEPT rules on tun0 |

See also: [Troubleshooting](Troubleshooting)
