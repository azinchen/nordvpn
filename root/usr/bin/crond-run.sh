#!/command/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

echo "Run crond service"

crond -f
