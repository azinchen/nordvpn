#!/command/with-contenv bash
# shellcheck shell=bash

[[ "${DEBUG,,}" == trace* ]] && set -x
set -euo pipefail

authfile="/tmp/auth"

echo "Create auth file"

echo "$USER" > "$authfile"
echo "$PASS" >> "$authfile"
chmod 0600 "$authfile"

exit 0
