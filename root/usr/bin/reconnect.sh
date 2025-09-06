#!/command/with-contenv bash
# shellcheck shell=bash

[[ "${DEBUG,,}" == trace* ]] && set -x
set -euo pipefail

createvpnconfig.sh

echo "Reconnect to selected VPN server"
s6-svc -h /run/service/nordvpnd

exit 0
