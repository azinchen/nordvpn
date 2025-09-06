#!/command/with-contenv bash
# shellcheck shell=bash

[[ "${DEBUG,,}" == trace* ]] && set -x
set -euo pipefail

PUID=${PUID:-912}
PGID=${PGID:-912}

echo "Set nordvpn user uid $PUID and nordvpn group gid $PGID"

groupmod --non-unique --gid "$PGID" nordvpn
usermod --non-unique --uid "$PUID" nordvpn

exit 0
