When the `vpn` container is restarted — whether due to an image update or a manual restart — every container that uses `network_mode: "service:vpn"` must also be restarted so they reattach to the recreated network namespace.

## With Docker Compose

```bash
docker compose pull
docker compose up -d --force-recreate
```

## With Plain Docker (no Compose)

```bash
docker pull azinchen/nordvpn:latest   # or ghcr.io/azinchen/nordvpn:latest
docker stop vpn && docker rm vpn
# Re-run your "vpn" container with the same args as before...
# Then restart each dependent container:
docker restart webapp api-service redis
```

## Safer Automated Updates for Compose Stacks

Consider using [azinchen/update-docker-containers](https://github.com/azinchen/update-docker-containers) for automated, safe container updates.

## Why Dependent Containers Must Restart

Containers that use `network_mode: "service:vpn"` share the VPN container's network namespace. When the VPN container is recreated, a new namespace is created. Dependent containers still reference the old (now dead) namespace and lose all network connectivity until they are restarted.
