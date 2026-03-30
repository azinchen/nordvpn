#!/bin/sh
# OpenVPN down script — restore /etc/resolv.conf
# Part of azinchen/nordvpn (MIT)

[ "${PEER_DNS}" = "no" ] && exit 0

_backup="/etc/resolv.conf.ovpn-${dev}"
if [ -f "$_backup" ]; then
    cp "$_backup" /etc/resolv.conf
    rm -f "$_backup"
fi

exit 0
