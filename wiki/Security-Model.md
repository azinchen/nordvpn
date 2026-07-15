This page describes the container's firewall behavior, kill switch, and network access control in detail.

## Traffic Control & Kill Switch

- **Default-deny (egress):** All outbound traffic is blocked unless it goes through the VPN interface, matches `NETWORK` (CIDRs you define), or is directed to NordVPN's API.
- **Bootstrap (pre-VPN):** DNS egress is **blocked**. The container contacts NordVPN's API via **pinned IP addresses** from `NORDVPNAPI_IP` to select a server (no DNS queries before the tunnel is up).
- **Kill switch:** If the VPN drops, traffic remains blocked **except** for destinations within your `NETWORK` CIDRs (e.g., local/LAN ranges you explicitly allowed) and to NordVPN's API.
- **Container routing:** Containers using `network_mode: "service:vpn"` share the VPN container's network namespace and inherit these policies.
- **Inbound (local/LAN only):** No connections from the host or LAN reach the stack **unless you publish ports on the VPN container**. **Public inbound via NordVPN is not supported** (no port forwarding).

## Network Access Control (Exceptions)

- **Local/LAN access (bidirectional, explicit):** Set `NETWORK=192.168.1.0/24` (semicolon-separated CIDRs supported) to allow access to those subnets **regardless of VPN status**.
- **No domain names allowed:** Use IPs in `NETWORK` for any non-VPN access you require.

## Rule Precedence

1. **Bootstrap-only (when VPN is down & before first connect):** Allow HTTPS only to the **NordVPN API IPs from `NORDVPNAPI_IP`** used by the image's bootstrap script.
2. **Exceptions:** If destination matches `NETWORK` (CIDR), allow (bypass/LAN), regardless of VPN state.
3. **VPN path:** If VPN is **up** and traffic is not an exception, allow only via the VPN interface.
4. **Default-deny:** Otherwise, block.

## Security Notes

### Kill Switch Limitations

Because `NETWORK` remains open when the VPN is down, this is **not a strict kill switch** if you include broad CIDRs. Keep `NETWORK` as narrow as possible (e.g., just your LAN / management subnets).

**Warning:** Setting `NETWORK=0.0.0.0/0` effectively disables the kill switch entirely — all traffic will bypass the VPN.

### Credential Exposure

Credentials passed via `USER` and `PASS` environment variables are:
- Visible via `docker inspect` on the container
- Visible in the process environment

To reduce exposure:
- Use a `.env` file with `env_file:` in Docker Compose (keeps credentials out of `docker-compose.yml`)
- Avoid passing credentials directly on the `docker run` command line (visible in process listings)
