echo "Clear firewall"
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
ip6tables -P OUTPUT DROP 2>/dev/null
ip6tables -P INPUT DROP 2>/dev/null
ip6tables -P FORWARD DROP 2>/dev/null
iptables -F
iptables -X
ip6tables -F 2>/dev/null
ip6tables -X 2>/dev/null

exit 0
