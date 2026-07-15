The container supports three reconnection mechanisms: scheduled switching, connection failure handling, and health monitoring.

## Scheduled Reconnection

Use `RECREATE_VPN_CRON` to periodically switch to a different server. This uses standard cron syntax.

```bash
# Reconnect every 6 hours at minute 0
-e RECREATE_VPN_CRON="0 */6 * * *"

# Reconnect daily at 3 AM
-e RECREATE_VPN_CRON="0 3 * * *"

# Reconnect every 4 hours
-e RECREATE_VPN_CRON="0 */4 * * *"
```

When triggered, the cron job stops the `svc-nordvpn` service, which causes it to restart automatically. On restart, `vpn-config` re-fetches the server list and selects a new server based on current load.

## Connection Failure Handling

Use `OPENVPN_OPTS` to control OpenVPN's behavior when the connection drops:

```bash
# Force reconnect to different server on connection loss
-e OPENVPN_OPTS="--pull-filter ignore ping-restart --ping-exit 180"

# Alternative: More aggressive reconnection
-e OPENVPN_OPTS="--ping 10 --ping-exit 60 --ping-restart 300"
```

| Option | Effect |
|--------|--------|
| `--ping-exit N` | Exit OpenVPN if no ping response in N seconds (triggers service restart → new server) |
| `--ping-restart N` | Restart connection after N seconds of no pings (stays on same server) |
| `--pull-filter ignore ping-restart` | Ignore server-pushed ping-restart, use your own value |
| `--ping N` | Send ping every N seconds |

Using `--ping-exit` causes OpenVPN to **exit** on timeout, which triggers svc-nordvpn to restart and pick a new server. Using `--ping-restart` keeps the same server.

## Connection Health Monitoring

Use the `CHECK_CONNECTION_*` variables for active health probing:

```bash
-e CHECK_CONNECTION_CRON="*/5 * * * *"
-e CHECK_CONNECTION_URL="https://1.1.1.1;https://8.8.8.8"
-e CHECK_CONNECTION_ATTEMPTS=3
-e CHECK_CONNECTION_ATTEMPT_INTERVAL=10
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CHECK_CONNECTION_CRON` | Disabled | Cron schedule for health checks |
| `CHECK_CONNECTION_URL` | `https://www.google.com` | URLs to probe (semicolon-separated) |
| `CHECK_CONNECTION_ATTEMPTS` | `5` | Number of retry attempts |
| `CHECK_CONNECTION_ATTEMPT_INTERVAL` | `10` | Seconds between retries |

## Docker Health Status

The image ships a Docker [`HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck) that reports the container's health (`healthy` / `unhealthy`) to Docker, Compose `depends_on: condition: service_healthy`, Swarm/Kubernetes, and monitoring or autoheal sidecars. It is **observational only** — it never reconnects. Active recovery is handled separately by `CHECK_CONNECTION_*`, `OPENVPN_OPTS` ping options, and `RECREATE_VPN_CRON`.

It is **opt-in**: while disabled (the default) the probe always reports healthy without testing anything. Set `HEALTHCHECK_ENABLED=true` to activate it.

```bash
-e HEALTHCHECK_ENABLED=true
```

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTHCHECK_ENABLED` | `false` | Enable the Docker `HEALTHCHECK` probe. When disabled, the container always reports healthy. |

When enabled, the probe checks that the `tun0` interface exists and that a single short request to `CHECK_CONNECTION_URL` succeeds. The probe runs every 60s with a 60s start period and 3 retries before the container is marked `unhealthy`; unlike the cron `CHECK_CONNECTION_*` check it performs no retry loop of its own and never triggers a reconnect.

## Recommended Setup

For most users, combining scheduled reconnection with health monitoring provides robust connectivity:

```yaml
environment:
  - RECREATE_VPN_CRON=0 */6 * * *           # Switch server every 6 hours
  - CHECK_CONNECTION_CRON=*/5 * * * *       # Check every 5 minutes
  - CHECK_CONNECTION_URL=https://1.1.1.1    # Fast, reliable endpoint
  - CHECK_CONNECTION_ATTEMPTS=3
  - OPENVPN_OPTS=--ping-exit 180            # Exit if server unresponsive for 3 min
```
