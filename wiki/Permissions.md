The container runs OpenVPN as a dedicated `nordvpn` user and group. You can control the UID and GID of this user with environment variables.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `912` | User ID for the `nordvpn` user |
| `PGID` | `912` | Group ID for the `nordvpn` group |

## When You Need This

If you mount host volumes into containers that share the VPN's network namespace, OpenVPN (running as UID 912) may not have permission to read/write those files. Setting `PUID` and `PGID` to match your host user avoids permission issues.

## Finding Your Host UID/GID

```bash
id -u    # your UID
id -g    # your GID
```

## Usage

```bash
docker run -d --cap-add=NET_ADMIN --device /dev/net/tun \
           -e USER=service_username -e PASS=service_password \
           -e PUID=1000 -e PGID=1000 \
           azinchen/nordvpn
```

### Docker Compose

```yaml
services:
  vpn:
    image: azinchen/nordvpn:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - USER=service_username
      - PASS=service_password
      - PUID=1000
      - PGID=1000
```
