This image **applies an IPv6 firewall** (when `ip6tables` is available and IPv6 is enabled): `INPUT`/`FORWARD`/`OUTPUT` default to `DROP`. It does **not** change IPv6 sysctls from inside the container (many environments mount `/proc/sys` read-only).

If your Docker runtime assigns IPv6 addresses and you want to avoid IPv6 leaks, choose **one** of the following options.

## Option A — Disable IPv6 for the Docker daemon/network (recommended)

- **Daemon-wide:** set `"ipv6": false` in Docker's `daemon.json` and restart Docker.
- **Per-network:** create the network with `--ipv6=false`.

## Option B — Disable IPv6 per container via runtime sysctls

Pass sysctls at **run** time (works even when `/proc/sys` is read-only inside the container):

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           --sysctl net.ipv6.conf.all.disable_ipv6=1 \
           --sysctl net.ipv6.conf.default.disable_ipv6=1 \
           --sysctl net.ipv6.conf.eth0.disable_ipv6=1 \
           azinchen/nordvpn
```

**docker-compose:**

```yaml
services:
  vpn:
    image: azinchen/nordvpn
    sysctls:
      net.ipv6.conf.all.disable_ipv6: "1"
      net.ipv6.conf.default.disable_ipv6: "1"
      net.ipv6.conf.eth0.disable_ipv6: "1"
```

## Option C — Disable IPv6 on the host

Use host sysctls or OS network settings to turn off IPv6 globally.

## How to Verify IPv6 Is Off

Inside the container:

```bash
cat /proc/net/if_inet6            # no output means no IPv6 addresses
ip -6 addr show dev eth0          # should show "Device not found" or no inet6 lines
ip6tables -S 2>/dev/null || true  # may be empty/unavailable
```

> **Note:** If your environment leaves IPv6 **enabled**, IPv6 traffic may bypass the IPv4 firewall. Use one of the options above to disable IPv6 at runtime.
