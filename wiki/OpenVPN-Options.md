The `OPENVPN_OPTS` environment variable lets you pass additional flags directly to the OpenVPN process. This page documents the default behavior and commonly useful options.

## Default Cipher Configuration

The container automatically appends `--data-ciphers` if it's not already present in your `OPENVPN_OPTS`:

```
--data-ciphers AES-256-CBC:AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
```

This prevents OpenVPN cipher deprecation warnings. To override, specify your own `--data-ciphers` in `OPENVPN_OPTS` — the container won't add the default if the flag is already present.

## How OpenVPN Is Launched

The full command assembled by the container:

```
openvpn --group nordvpn \
        --config /run/xt/nordvpn.ovpn \
        --auth-user-pass /run/xt/auth \
        --auth-nocache \
        --management 127.0.0.1 7505 /run/xt/mgmt-pw \
        $OPENVPN_OPTS
```

Your `OPENVPN_OPTS` flags are appended at the end, so they can override settings from the `.ovpn` config.

## Commonly Useful Options

### Reconnection Control

| Option | Effect |
|--------|--------|
| `--ping-exit N` | Exit OpenVPN after N seconds with no ping response. Triggers a service restart → new server. |
| `--ping-restart N` | Restart the connection after N seconds of no pings (stays on same server). |
| `--pull-filter ignore ping-restart` | Ignore server-pushed ping-restart value. Use with your own `--ping-exit`. |
| `--ping N` | Send a ping every N seconds. |

**Recommended for aggressive reconnection:**
```bash
-e OPENVPN_OPTS="--pull-filter ignore ping-restart --ping-exit 180"
```

This ignores the server's ping-restart setting and exits after 3 minutes of silence, causing the container to pick a new server.

### Logging & Debugging

| Option | Effect |
|--------|--------|
| `--mute-replay-warnings` | Suppress replay warning messages (common with UDP). |
| `--verb N` | Set verbosity level (0–11). Default is 3. Use 4–5 for debug. |
| `--log /dev/stdout` | Explicit stdout logging (usually default). |

### Protocol & Connection

| Option | Effect |
|--------|--------|
| `--connect-retry N` | Wait N seconds between connection attempts. |
| `--connect-retry-max N` | Maximum number of retries. |
| `--resolv-retry N` | Retry DNS resolution for N seconds (or `infinite`). |
| `--keepalive N M` | Shortcut for `--ping N --ping-restart M`. |

### Security

| Option | Effect |
|--------|--------|
| `--data-ciphers LIST` | Override the cipher negotiation list. Colon-separated. |
| `--cipher ALG` | Set the fallback cipher (deprecated in favor of `--data-ciphers`). |
| `--tls-cipher LIST` | Restrict TLS control channel ciphers. |
| `--auth ALG` | HMAC authentication algorithm (e.g., `SHA256`). |

## Examples

```bash
# Aggressive reconnection + suppress warnings
-e OPENVPN_OPTS="--mute-replay-warnings --ping-exit 180"

# Debug logging
-e OPENVPN_OPTS="--verb 5"

# Custom cipher list
-e OPENVPN_OPTS="--data-ciphers AES-256-GCM:CHACHA20-POLY1305"

# Combined: quiet + fast reconnect
-e OPENVPN_OPTS="--mute-replay-warnings --pull-filter ignore ping-restart --ping-exit 60"
```

## Docker Compose

```yaml
environment:
  - OPENVPN_OPTS=--mute-replay-warnings --ping-exit 180
```

> **Note:** Do not quote the value in compose `environment:` list syntax. Multiple flags are space-separated as a single string.
