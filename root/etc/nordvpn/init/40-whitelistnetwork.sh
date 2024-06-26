#!/command/with-contenv bash

[[ "${DEBUG,,}" == trace* ]] && set -x

echo "Bypass requests to domains from whitelist thru regular connection"

docker_network="$(ip -o addr show dev eth0 | awk '$3 == "inet" {print $4}')"
docker6_network="$(ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4; exit}')"

if [[ -n ${WHITELIST} ]]; then
    for domain in ${WHITELIST//[;,]/ }; do
        domain=$(echo "$domain" | sed 's/^.*:\/\///;s/\/.*$//')
        echo "Enabling connection to host "${domain}""
        if [[ -n ${docker_network} ]]; then
            sg nordvpn -c "iptables  -A OUTPUT -o eth0 -d "${domain}" -j ACCEPT"
        fi
        if [[ -n ${docker6_network} ]]; then
            sg nordvpn -c "ip6tables -A OUTPUT -o eth0 -d "${domain}" -j ACCEPT 2>/dev/null"
        fi

    done
fi

echo "Bypass requests to NordVPN API thru regular connection"
if [[ -n ${docker_network} ]]; then
    sg nordvpn -c "iptables  -A OUTPUT -d "api.nordvpn.com" -j ACCEPT"
fi
if [[ -n ${docker6_network} ]]; then
    sg nordvpn -c "ip6tables -A OUTPUT -d "api.nordvpn.com" -j ACCEPT 2> /dev/null"
fi

exit 0
