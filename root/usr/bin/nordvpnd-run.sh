#!/command/with-contenv bash
# shellcheck shell=bash

[[ "${DEBUG,,}" == trace* ]] && set -x
set -euo pipefail

authfile="/tmp/auth"
ovpnfile="/tmp/nordvpn.ovpn"

exec sg nordvpn -c "openvpn --config $ovpnfile --auth-user-pass $authfile --auth-nocache ${OPENVPN_OPTS}"
