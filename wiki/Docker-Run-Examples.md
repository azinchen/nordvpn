## Basic Example

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun \
           -e USER=service_username \
           -e PASS=service_password \
           azinchen/nordvpn

# Run application through VPN
docker run -d --name app --net=container:vpn nginx
```

## Advanced Example with Port Mapping

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun \
           -p 8080:8080 \
           -p 9091:9091 \
           -e USER=service_username \
           -e PASS=service_password \
           -e COUNTRY="Germany;NL;202" \
           -e CITY="Amsterdam;6076868;uk2567" \
           -e GROUP="Standard VPN servers" \
           -e RANDOM_TOP=3 \
           -e RECREATE_VPN_CRON="0 */6 * * *" \
           -e NETWORK=192.168.1.0/24 \
           azinchen/nordvpn

# Applications using VPN (access via host ports)
docker run -d --name webapp --net=container:vpn \
           nginx:alpine

docker run -d --name api-service --net=container:vpn \
           -v ./app:/app -w /app \
           node:alpine npm start
```

## Key Points

- **`--cap-add=NET_ADMIN`** and **`--device /dev/net/tun`** are always required.
- **Ports** must be published on the VPN container (`-p` on the `vpn` container), not on the application containers.
- Application containers connect via `--net=container:vpn`.
- For GitHub Container Registry, replace `azinchen/nordvpn` with `ghcr.io/azinchen/nordvpn`.

## XOR Obfuscation Example

Use XOR obfuscation to bypass deep packet inspection. See [Technologies](Technologies#xor-obfuscated-openvpn-openvpn_xor_udp--openvpn_xor_tcp) for details.

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun \
           -p 8080:8080 \
           -e USER=service_username \
           -e PASS=service_password \
           -e TECHNOLOGY=openvpn_xor_tcp \
           -e GROUP=legacy_obfuscated_servers \
           -e COUNTRY=Netherlands \
           -e NETWORK=192.168.1.0/24 \
           azinchen/nordvpn

docker run -d --name app --net=container:vpn nginx
```

> **Note:** `GROUP=legacy_obfuscated_servers` is required for XOR technologies. Not all countries have obfuscated servers.
