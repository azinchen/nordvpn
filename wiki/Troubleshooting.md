## Connection Problems

### VPN won't connect

**Symptoms:** Container starts but OpenVPN never establishes a tunnel.

**Check:**
1. **Credentials:** Verify you're using **service credentials**, not regular NordVPN login. See the [Getting Service Credentials](https://github.com/azinchen/nordvpn#getting-service-credentials) section in the README.
2. **Logs:** `docker logs vpn` — look for auth errors or connection timeouts.
3. **API access:** The container needs HTTPS access to NordVPN API IPs during bootstrap. If running behind a corporate proxy/firewall, ensure TCP/443 to the `NORDVPNAPI_IP` addresses is allowed.
4. **TUN device:** Ensure `--device /dev/net/tun` is set and the device exists on the host.

### Connection drops frequently

**Fix:** Use health monitoring and aggressive reconnection:
```yaml
environment:
  - CHECK_CONNECTION_CRON=*/5 * * * *
  - CHECK_CONNECTION_URL=https://1.1.1.1
  - OPENVPN_OPTS=--ping-exit 180
  - RECREATE_VPN_CRON=0 */6 * * *
```

See [Automatic Reconnection](Automatic-Reconnection#connection-health-monitoring) for details.

### VPN appears running but traffic is blocked

**Symptoms:** tun0 exists but no traffic flows. Container started without errors.

**Check:**
1. **Connection timeout:** The container waits up to 60 seconds for tun0 to appear. If OpenVPN is slow to connect, it may proceed before the tunnel is fully established. Check logs for `Initialization Sequence Completed`.
2. **Firewall rules:** `docker exec vpn iptables -L OUTPUT -n -v` — verify tun0 ACCEPT rule exists.
3. **Diagnostics:** `docker exec vpn /usr/local/bin/network-diagnostic`

## Networking Problems

### Containers behind VPN have no network

**Symptoms:** `docker exec app curl https://example.com` fails.

**Check:**
1. **VPN is up:** `docker exec vpn ip link show tun0` — if tun0 doesn't exist, the VPN isn't connected.
2. **DNS:** `docker exec app cat /etc/resolv.conf` — the nameserver should be pushed by OpenVPN (usually `10.x.x.x`).
3. **Firewall:** `docker exec vpn iptables -L -n` — verify OUTPUT chain allows traffic via tun0.

### Can't access containers from LAN

**Symptoms:** Can't reach published ports from your host or other LAN machines.

**Fix:** Set `NETWORK` to include your LAN CIDR:
```bash
-e NETWORK=192.168.1.0/24
```

Docker subnets are **not** auto-allowed. If inter-container communication is needed, include Docker's subnet too.

### DNS leaks

**Symptoms:** DNS queries go through your ISP instead of the VPN tunnel.

**Check:**
1. Run diagnostics: `docker exec vpn /usr/local/bin/network-diagnostic`
2. Look at the DNS section — nameservers should be VPN-provided addresses
3. If using IPv6, it may bypass the VPN. See [IPv6 Configuration](IPv6-Configuration)

### NETWORK setting defeats the kill switch

**Symptoms:** Traffic leaks when VPN is down.

**Cause:** `NETWORK` CIDRs are always allowed, regardless of VPN state. If you set `NETWORK=0.0.0.0/0`, **all traffic bypasses the VPN**.

**Fix:** Keep `NETWORK` as narrow as possible — only include your LAN subnet and any Docker networks that need direct access.

## Firewall & Permissions

### iptables errors on container start

**Symptoms:** Errors like `iptables: No chain/target/match by that name` or `Permission denied`.

**Check:**
1. **NET_ADMIN capability:** Ensure `--cap-add=NET_ADMIN` is set.
2. **Kernel compatibility:** The container auto-detects nft vs legacy. Check logs for `[ENTRYPOINT] Using IPv4 backend:` to see which was selected.
3. **Host iptables modules:** Some minimal hosts (e.g., certain NAS devices) may lack required kernel modules.

## Technologies

### No servers found with XOR or Dedicated IP technology

**Check:**
- Verify `GROUP` is set correctly (`legacy_obfuscated_servers` for XOR, `legacy_dedicated_ip` for Dedicated IP)
- Check that NordVPN has obfuscated/dedicated servers in your selected `COUNTRY`
- Not all countries have obfuscated servers — try without `COUNTRY` first

### Connection reset with XOR

The TLS auth key swap happens automatically. If you see `Connection reset`, check the logs for TLS errors. Try the other protocol (`xor_tcp` ↔ `xor_udp`).

### Connection timeout with XOR

Standard OpenVPN uses a single port; XOR uses multiple. Ensure your network allows the required ports (see [Technologies](Technologies#multi-port-behavior)). If all XOR ports are blocked, standard OpenVPN TCP on port 443 may still work since it looks like HTTPS traffic.

### Connection fails with PORT set

Some servers don't accept all declared ports. If `PORT` is set and the connection fails, try a different port or remove `PORT` to let OpenVPN cycle through all available ports automatically.

## Scheduling

### Cron jobs not running

**Symptoms:** `RECREATE_VPN_CRON` or `CHECK_CONNECTION_CRON` is set but the scheduled task never fires.

**Check:**
1. **Syntax:** Ensure valid cron format (5 fields: minute hour day month weekday). Invalid expressions are silently ignored by crond.
2. **Logs:** Look for `[INIT-SETUPCRON]` lines at startup — they show the parsed schedule in human-readable format.
3. **Crontab:** Verify the job was written: `docker exec vpn cat /var/spool/cron/crontabs/root`

## Diagnostics

### Built-in Network Diagnostics

Enable automatic diagnostics on every VPN connection:

```bash
-e NETWORK_DIAGNOSTIC_ENABLED=true
```

Or run manually:

```bash
docker exec vpn /usr/local/bin/network-diagnostic          # full diagnostics
docker exec vpn /usr/local/bin/network-diagnostic --basic   # IP + location only
```

The diagnostic tool checks: public IP and geolocation, OpenVPN connection status, network interfaces, firewall rules, DNS nameservers, IP routing table, and kernel version.

### Reading Container Logs

```bash
docker logs vpn              # full logs
docker logs -f vpn           # follow in real-time
docker logs --tail 50 vpn    # last 50 lines
```

Key log messages:

| Log message | Meaning |
|------------|---------|
| `[ENTRYPOINT] Using IPv4 backend: ...` | Firewall backend selected |
| `[VPN-CONFIG] Server: ...` | Selected VPN server |
| `Initialization Sequence Completed` | OpenVPN connected successfully |
| `[HEALTHCHECK] Connection check failed` | Health check triggered reconnection |
| `[VPN-RECONNECT] Reconnecting...` | Service restarting |

### Inspecting the Container

```bash
docker exec vpn ip link show tun0            # check if VPN tunnel exists
docker exec vpn ip route                     # view routing table
docker exec vpn iptables -L -n -v            # check iptables rules
docker exec vpn cat /run/xt/nordvpn.ovpn     # view OpenVPN config
docker exec vpn env | sort                   # check environment
```
