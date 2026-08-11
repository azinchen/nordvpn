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

When triggered, `vpn-reconnect` selects a new server and prepares the new config **while the current tunnel stays up** — the API calls and load sorting no longer count as downtime. Only then is the service restarted to apply it, so the actual interruption is the OpenVPN restart and TLS handshake (a few seconds). If server selection fails (for example the API is unreachable), the existing connection is kept untouched.

### Making rotation effective

Server selection always takes the top of the filtered pool (NordVPN's recommended order for a single location, load-sorted for multiple locations). Without further settings a scheduled rotation can therefore re-select the very server you are already on. Set `RANDOM_TOP` so rotation actually lands somewhere new:

```bash
-e RANDOM_TOP=10
```

This shuffles the ten best servers in the pool and picks one — a genuinely different exit IP on almost every rotation, while still staying on low-load recommended servers. Larger values add IP variety but start including higher-load servers; see [Server Selection](Server-Selection) for how the pool is built.

### Choosing a schedule

- **Server hygiene** (avoid sitting on a server that slowly degrades): daily off-peak, e.g. `0 6 * * *`, is plenty. A good default for seedboxes and gateways, since every rotation changes the exit IP and drops long-lived connections (torrent peers re-announce, sessions reset). Note the container runs on UTC unless `TZ` is set.
- **IP rotation for privacy**: every few hours, e.g. `0 */6 * * *` or `0 */4 * * *`. Going below hourly gains little and constantly disturbs anything stateful.
- **Latency-sensitive, single pinned city**: scheduled rotation can be skipped entirely — recommended-order selection already favors the best server at connect time, and failure handling plus health monitoring (below) move you off a broken one.

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
-e CHECK_CONNECTION_CRON="* * * * *"
-e CHECK_CONNECTION_URL="https://www.gstatic.com/generate_204;https://cp.cloudflare.com/generate_204"
-e CHECK_CONNECTION_ATTEMPTS=3
-e CHECK_CONNECTION_ATTEMPT_INTERVAL=5
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CHECK_CONNECTION_CRON` | Disabled | Cron schedule for health checks |
| `CHECK_CONNECTION_URL` | `https://www.google.com` | URLs to probe (`;`/`,`-separated) |
| `CHECK_CONNECTION_ATTEMPTS` | `5` | Number of retry attempts |
| `CHECK_CONNECTION_ATTEMPT_INTERVAL` | `10` | Seconds between retries |

A check passes as soon as **any** URL answers with HTTP 2xx/3xx, so listing two URLs on independent infrastructure prevents a single provider's outage (or a geo-block on some exit servers) from triggering a spurious reconnect. The dedicated connectivity endpoints `https://www.gstatic.com/generate_204` and `https://cp.cloudflare.com/generate_204` are ideal: no body, no redirects, and they answer from everywhere.

### Tuning the schedule

Two timings matter:

- **Run length.** A fully failing check runs for about `ATTEMPTS × (2s timeout + ATTEMPT_INTERVAL)` seconds (the interval elapses after the last attempt too). Keep this below the cron period so runs don't overlap — the defaults (5 × ~12s ≈ 60s) are too long for an every-minute cron; pair a `* * * * *` schedule with `ATTEMPTS=3` and `ATTEMPT_INTERVAL=5` (~20s).
- **Worst-case recovery.** Time from outage to reconnect is roughly `cron period + run length` — about 1.5 minutes with an every-minute cron and 3×5s retries.

Don't shrink the retries too far: the retry window should outlast a transient blip (a brief ISP hiccup, a server-side pause) and the few seconds of downtime a scheduled rotation or an OpenVPN `--ping-restart` causes. A reconnect changes the exit IP, which resets anything sensitive to it — one failed request should never rotate the server; 15+ seconds of nothing getting through should.

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

For most users, combining scheduled rotation, OpenVPN's own failure detection and health monitoring provides robust connectivity:

```yaml
environment:
  - RECREATE_VPN_CRON=0 6 * * *             # Rotate daily, off-peak (UTC unless TZ is set)
  - RANDOM_TOP=10                           # So rotation lands on a different server
  - CHECK_CONNECTION_CRON=* * * * *         # Probe every minute
  - CHECK_CONNECTION_ATTEMPTS=3
  - CHECK_CONNECTION_ATTEMPT_INTERVAL=5
  - CHECK_CONNECTION_URL=https://www.gstatic.com/generate_204;https://cp.cloudflare.com/generate_204
  - HEALTHCHECK_ENABLED=true
  - OPENVPN_OPTS=--ping-exit 180            # Exit if server unresponsive for 3 min
```

This detects a dead tunnel and finishes reconnecting within ~1.5 minutes worst case (the `--ping-exit` layer catches server-side silence independently), tolerates short blips without rotating the exit IP, and rotates to a fresh low-load server once a day.

For long-lived connections where an IP change is disruptive (seedbox, remote sessions), lean more conservative: `CHECK_CONNECTION_CRON=*/2 * * * *`, `CHECK_CONNECTION_ATTEMPTS=4`, `CHECK_CONNECTION_ATTEMPT_INTERVAL=10` — about 45 seconds of confirmed failure before the server is rotated. If the check cron runs infrequently, pick a rotation minute that doesn't collide with it (e.g. check on `*/5`, rotate at minute 2); with an every-minute check the overlap is harmless — a check landing during the restart is absorbed by the retries.
