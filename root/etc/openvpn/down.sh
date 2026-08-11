#!/bin/sh
# OpenVPN down script — restore /etc/resolv.conf
# Part of azinchen/nordvpn (MIT)

# OpenVPN scrubs the environment for scripts; re-import the container env
# vars this script depends on from s6's container-environment store.
for _v in DNS PEER_DNS; do
    if [ -f "/run/s6/container_environment/$_v" ]; then
        export "$_v"="$(cat "/run/s6/container_environment/$_v")"
    fi
done

# DNS=off (preferred) or legacy PEER_DNS=no: leave resolv.conf untouched
[ "${DNS:-}" = "off" ] && exit 0
[ "${PEER_DNS:-}" = "no" ] && exit 0

_backup="/etc/resolv.conf.ovpn-${dev}"
if [ -f "$_backup" ]; then
    # Write into the existing inode instead of replacing the file:
    # /etc/resolv.conf is usually a Docker-managed (or user) bind mount and
    # cannot be recreated ("cp: can't create '/etc/resolv.conf': File exists").
    cat "$_backup" > /etc/resolv.conf
    rm -f "$_backup"
fi

exit 0
