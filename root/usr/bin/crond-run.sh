#!/command/with-contenv bash
#shellcheck shell=bash disable=SC1008

echo "Run crond service"

crond -f
