#!/bin/sh
# OpenVPN down script — restore /etc/resolv.conf
# Part of azinchen/nordvpn (MIT)

[ "${PEER_DNS}" = "no" ] && exit 0

_backup="/etc/resolv.conf.ovpn-${dev}"
if [ -f "$_backup" ]; then
    # Write into the existing inode instead of replacing the file:
    # /etc/resolv.conf is usually a Docker-managed (or user) bind mount and
    # cannot be recreated ("cp: can't create '/etc/resolv.conf': File exists").
    cat "$_backup" > /etc/resolv.conf
    rm -f "$_backup"
fi

exit 0
