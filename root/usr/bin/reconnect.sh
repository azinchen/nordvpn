#!/command/with-contenv bash
#shellcheck shell=bash disable=SC1008

[[ "${DEBUG,,}" == trace* ]] && set -x

createvpnconfig.sh

echo "Reconnect to selected VPN server"
s6-svc -h /run/service/nordvpnd

exit 0
