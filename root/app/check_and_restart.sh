#!/usr/bin/with-contenv bash

curl -m 4 connectivitycheck.gstatic.com  >>/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "restarting as unable to connect to connectivitycheck.gstatic.com"
    /app/reconnect.sh
fi