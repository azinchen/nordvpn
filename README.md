[![logo](https://github.com/azinchen/nordvpn/raw/master/NordVpn_logo.png)](https://www.nordvpn.com/)

# NordVPN

[![Docker Pulls][dockerhub-pulls]][dockerhub-link]
[![GitHub build][github-build]][github-link]
[![Docker image size][dockerhub-size]][dockerhub-link]
[![GitHub Last Commit][github-lastcommit]][github-link]

This is an OpenVPN client docker container that uses recommended NordVPN server. It makes routing containers traffic through OpenVPN easy.

## What is OpenVPN?

OpenVPN is an open-source software application that implements virtual private network (VPN) techniques for creating secure point-to-point or site-to-site connections in routed or bridged configurations and remote access facilities. It uses a custom security protocol that utilizes SSL/TLS for key exchange. It is capable of traversing network address translators (NATs) and firewalls.

## How to use this image

This container was designed to be started first to provide a connection to other containers (using `--net=container:vpn`, see below *Starting an NordVPN client instance*).

**NOTE**: More than the basic privileges are needed for NordVPN. With docker 1.2 or newer you can use the `--cap-add=NET_ADMIN` and `--device /dev/net/tun` options. Earlier versions, or with fig, and you'll have to run it in privileged mode.

**NOTE 2**: If you need a template for using this container with `docker-compose`, see the example [file](https://github.com/dperson/openvpn-client/raw/master/docker-compose.yml).

### Supported Architectures

The image supports multiple architectures such as `amd64`, `x86`, `arm/v6`, `arm/v7`, `arm64` and `ppc64le`.

### Starting an NordVPN instance

```bash
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e USER=user@email.com -e PASS=password \
           -e RANDOM_TOP=n -e RECREATE_VPN_CRON=string \
           -e COUNTRY=country1;country2 -e GROUP=group \
           -e TECHNOLOGY=technology -d azinchen/nordvpn
```

Once it's up other containers can be started using it's network connection:

```bash
docker run -it --net=container:vpn -d some/docker-container
```

### docker-compose

```Dockerfile
version: "3"
services:
  vpn:
    image: azinchen/nordvpn:latest
    cap_add:
      - net_admin
    devices:
      - /dev/net/tun
    environment:
      - USER=user@email.com
      - PASS=password
      - COUNTRY=Spain;Hong Kong;IE;131
      - GROUP=Standard VPN servers
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=5 */3 * * *
      - NETWORK=192.168.1.0/24;192.168.2.0/24
      - OPENVPN_OPTS=--mute-replay-warnings
    ports:
      - 8080:80
    restart: unless-stopped
  
  web:
    image: nginx
    network_mode: service:vpn
```

### Filter NordVPN servers

This container selects recommended. The list of recommended servers can be filtered by setting `COUNTRY`, `GROUP` and/or `TECHNOLOGY` environment variables.

### Reconnect by cron

This container selects server and its config during startup and maintains connection until stop. Selected server might be changed using cron via `RECREATE_VPN_CRON` environment variable.

```bash
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e RECREATE_VPN_CRON="5 */3 * * *" -e RANDOM_TOP=10
           -e USER=user@email.com -e PASS=password -d azinchen/nordvpn
```

In this example the VPN connection will be reconnected in the 5th minute every 3 hours.

### Reconnect

By the fault the container will try to reconnect to the same server when disconnected, in order to reconnect to another recommended server automatically add env variable:

```bash
 - OPENVPN_OPTS=--pull-filter ignore "ping-restart" --ping-exit 180
```

### Check Internet connection by cron

This container checks Internet connection via VPN by cron.

```bash
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e CHECK_CONNECTION_CRON="*/5 * * * *" -e CHECK_CONNECTION_URL="https://www.google.com"
           -e USER=user@email.com -e PASS=password -d azinchen/nordvpn
```

In this example the VPN connection will be checked every 5 minutes.

### Local Network access to services connecting to the internet through the VPN

The environment variable NETWORK must be your local network that you would connect to the server running the docker containers on. Running the following on your docker host should give you the correct network: `ip route | awk '!/ (docker0|br-)/ && /src/ {print $1}'`

```bash
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -p 8080:80 -e NETWORK=192.168.1.0/24 \ 
           -e USER=user@email.com -e PASS=password -d azinchen/nordvpn
```

Now just create the second container _without_ the `-p` parameter, only inlcude the `--net=container:vpn`, the port should be declare in the vpn container.

```bash
docker run -ti --rm --net=container:vpn -d bubuntux/riot-web
```

now the service provided by the second container would be available from the host machine (<http://localhost:8080>) or anywhere inside the local network (<http://192.168.1.xxx:8080>).

### Local Network access to services connecting to the internet through the VPN using a Web proxy

```bash
docker run -it --name web -p 80:80 -p 443:443 \
           --link vpn:<service_name> -d dperson/nginx \
           -w "http://<service_name>:<PORT>/<URI>;/<PATH>"
```

Which will start a Nginx web server on local ports 80 and 443, and proxy any requests under `/<PATH>` to the to `http://<service_name>:<PORT>/<URI>`. To use a concrete example:

```bash
docker run -it --name bit --net=container:vpn -d bubundut/nordvpn
docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
           -d dperson/nginx -w "http://bit:9091/transmission;/transmission"
```

For multiple services (non-existant 'foo' used as an example):

```bash
docker run -it --name bit --net=container:vpn -d dperson/transmission
docker run -it --name foo --net=container:vpn -d dperson/foo
docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
           --link vpn:foo -d dperson/nginx \
           -w "http://bit:9091/transmission;/transmission" \
           -w "http://foo:8000/foo;/foo"
```

## Environment variables

Container images are configured using environment variables passed at runtime.

* `COUNTRY`           - Use servers from countries in the list (IE Australia;New Zeland). Several countries can be selected using semicolon. Country can be defined by Country name, Code or ID [full list][nordvpn-countries].
* `GROUP`             - Use servers from specific group. Only one group can be selected. Group can be defined by Name, Identifier or ID [full list][nordvpn-groups].
* `TECHNOLOGY`        - User servers with specific technology supported. Only one technololgy can be selected. Technology can be defined by Name, Identifier or ID [full list][nordvpn-technologies]. NOTE: Only OpenVPN servers are supported by this container.
* `RANDOM_TOP`        - Place n servers from filtered list in random order. Useful with `RECREATE_VPN_CRON`.
* `RECREATE_VPN_CRON` - Set period of selecting new server in format for crontab file. Disabled by default.
* `CHECK_CONNECTION_CRON` - Set period of checking Internet connection in format for crontab file. Disabled by default.
* `CHECK_CONNECTION_URL` - Use list of URI for checking Internet connection.
* `CHECK_CONNECTION_ATTEMPTS` - Set number of attemps of checking. Default value is 5.
* `CHECK_CONNECTION_ATTEMPT_INTERVAL` - Set sleep timeouts between failed attepms. Default value is 10.
* `USER`              - User for NordVPN account.
* `PASS`              - Password for NordVPN account.
* `WHITELIST`         - List of domains that are going to be accessible outside vpn.
* `NETWORK`           - CIDR network (IE 192.168.1.0/24), add a route to allows replies once the VPN is up. Several networks can be added to route using semicolon.
* `NETWORK6`          - CIDR IPv6 network (IE fe00:d34d:b33f::/64), add a route to allows replies once the VPN is up. Several networks can be added to route using semicolon.
* `OPENVPN_OPTS`      - Used to pass extra parameters to openvpn [full list](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/).
* `DEBUG`             - info, trace or trace+. Set to 'trace' for troubleshooting, 'trace+' will log your User and Pass.

## Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue][github-issues] or [email][email-link].

[dockerhub-badge]: https://img.shields.io/docker/pulls/azinchen/nordvpn?style=flat-square
[dockerhub-link]: https://hub.docker.com/repository/docker/azinchen/nordvpn
[dockerhub-pulls]: https://img.shields.io/docker/pulls/azinchen/nordvpn
[dockerhub-size]: https://img.shields.io/docker/image-size/azinchen/nordvpn/latest
[github-lastcommit]: https://img.shields.io/github/last-commit/azinchen/nordvpn
[github-link]: https://github.com/azinchen/nordvpn
[github-issues]: https://github.com/azinchen/nordvpn/issues
[github-build]: https://img.shields.io/github/workflow/status/azinchen/nordvpn/CI_CD_Task
[nordvpn-cities]: https://github.com/azinchen/nordvpn/blob/master/CITIES.md
[nordvpn-countries]: https://github.com/azinchen/nordvpn/blob/master/COUNTRIES.md
[nordvpn-groups]: https://github.com/azinchen/nordvpn/blob/master/GROUPS.md
[nordvpn-technologies]: https://github.com/azinchen/nordvpn/blob/master/TECHNOLOGIES.md
[email-link]: mailto:alexander@zinchenko.com
