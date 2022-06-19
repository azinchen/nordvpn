#!/command/with-contenv bash
#shellcheck shell=bash disable=SC1008

[[ "${DEBUG,,}" == trace* ]] && set -x

authfile="/tmp/auth"
ovpnfile="/tmp/nordvpn.ovpn"

exec sg nordvpn -c "openvpn --config "$ovpnfile" --auth-user-pass "$authfile" --auth-nocache ${OPENVPN_OPTS}"
