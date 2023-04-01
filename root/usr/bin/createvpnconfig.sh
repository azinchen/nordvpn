#!/command/with-contenv bash

[[ "${DEBUG,,}" == trace* ]] && set -x

nvcountries=$(jq -c '.[]' < "/etc/nordvpn/countries.json")
nvgroups=$(jq -c '.[]' < "/etc/nordvpn/groups.json")
nvtechnologies=$(jq -c '.[]' < "/etc/nordvpn/technologies.json")

numericregex="^[0-9]+$"
specific_country_regex="^[a-zA-Z]{2}[0-9]+$"

ovpntemplatefile="/etc/nordvpn/template.ovpn"
ovpnfile="/tmp/nordvpn.ovpn"

getcountryid()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        id=$(echo "$nvcountries" | jq -r --argjson ID "$input" 'select(.id == $ID) | .id')
    else
        id=$(echo "$nvcountries" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .id')
        if [ -z "$id" ]; then
            id=$(echo "$nvcountries" | jq -r --arg CODE "$input" 'select(.code == $CODE) | .id')
        fi
    fi

    printf '%s' "$id"

    if [ -z "$id" ]; then
        return 1
    fi

    return 0
}

getcountryname()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        name=$(echo "$nvcountries" | jq -r --argjson ID "$input" 'select(.id == $ID) | .name')
    else
        name=$(echo "$nvcountries" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .name')
        if [ -z "$name" ]; then
            name=$(echo "$nvcountries" | jq -r --arg CODE "$input" 'select(.code == $CODE) | .name')
        fi
    fi

    printf '%s' "$name"

    if [ -z "$name" ]; then
        return 1
    fi

    return 0
}

getgroupid()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        id=$(echo "$nvgroups" | jq -r --argjson ID "$input" 'select(.id == $ID) | .id')
    else
        id=$(echo "$nvgroups" | jq -r --arg TITLE "$input" 'select(.title == $TITLE) | .id')
        if [ -z "$id" ]; then
            id=$(echo "$nvgroups" | jq -r --arg IDENTIFIER "$input" 'select(.identifier == $IDENTIFIER) | .id')
        fi
    fi

    printf '%s' "$id"

    if [ -z "$id" ]; then
        return 1
    fi

    return 0
}

getgrouptitle()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        title=$(echo "$nvgroups" | jq -r --argjson ID "$input" 'select(.id == $ID) | .title')
    else
        title=$(echo "$nvgroups" | jq -r --arg TITLE "$input" 'select(.title == $TITLE) | .title')
        if [ -z "$id" ]; then
            title=$(echo "$nvgroups" | jq -r --arg IDENTIFIER "$input" 'select(.identifier == $IDENTIFIER) | .title')
        fi
    fi

    printf '%s' "$title"

    if [ -z "$title" ]; then
        return 1
    fi

    return 0
}

gettechnologyid()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        id=$(echo "$nvtechnologies" | jq -r --argjson ID "$input" 'select(.id == $ID) | .id')
    else
        id=$(echo "$nvtechnologies" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .id')
        if [ -z "$id" ]; then
            id=$(echo "$nvtechnologies" | jq -r --arg IDENTIFIER "$input" 'select(.identifier == $IDENTIFIER) | .id')
        fi
    fi

    printf '%s' "$id"

    if [ -z "$id" ]; then
        return 1
    fi

    return 0
}

gettechnologyname()
{
    input=$1

    if [[ "$input" =~ $numericregex ]]; then
        name=$(echo "$nvtechnologies" | jq -r --argjson ID "$input" 'select(.id == $ID) | .name')
    else
        name=$(echo "$nvtechnologies" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .name')
        if [ -z "$id" ]; then
            name=$(echo "$nvtechnologies" | jq -r --arg IDENTIFIER "$input" 'select(.identifier == $IDENTIFIER) | .name')
        fi
    fi

    printf '%s' "$name"

    if [ -z "$name" ]; then
        return 1
    fi

    return 0
}

getopenvpnprotocol()
{
    input=$1

    ident=$(echo "$nvtechnologies" | jq -r --arg NAME "$input" 'select(.name == $NAME) | .identifier')
    if [ -z "$ident" ]; then
        if [[ "$input" =~ $numericregex ]]; then
            ident=$(echo "$nvtechnologies" | jq -r --argjson ID "$input" 'select(.id == $ID) | .identifier')
        fi
    fi
    if [ -z "$ident" ]; then
        ident=$input
    fi

    if [[ $ident != *"openvpn"* ]]; then
        printf ""
        return 1
    elif [[ $ident == *"udp"* ]]; then
        printf "udp"
        return 0
    elif [[ $ident == *"tcp"* ]]; then
        printf "tcp"
        return 0
    else
        printf ""
        return 1
    fi
}

echo "Select NordVPN server and create config file"

echo "Apply filter technology \"$(gettechnologyname "$TECHNOLOGY")\""
filterserver="filters\[servers_technologies\]\[id\]=$(gettechnologyid "$TECHNOLOGY")"

IFS=';'
read -ra RA_GROUPS <<< "$GROUP"
for value in "${RA_GROUPS[@]}"; do
    if [ -n "$value" ]; then
        echo "Apply filter group \"$(getgrouptitle "$value")\""
        filterserver="$filterserver""&filters\[servers_groups\]\[id\]=$(getgroupid "$value")"
    fi
done

servers=""

echo "Request list of recommended servers"
if [ -z "$COUNTRY" ]; then
    servers=$(curl -s "https://api.nordvpn.com/v1/servers/recommendations?$filterserver" | jq -c '.[]')
    echo "Request nearest servers, $(echo "$servers" | jq -s 'length') servers received"
else
    read -ra RA_COUNTRIES <<< "$COUNTRY"
    for value in "${RA_COUNTRIES[@]}"; do
        if [[ "$value" =~ $specific_country_regex ]]; then
            hostname="${value,,}.nordvpn.com"
            ip="$(host -t A "$hostname" | awk '{print $4}')"
            name="$(getcountryname "${value:0:2}") #${value:2}"
            constructed_json=$(printf '{"name":"%s","hostname":"%s","load":0,"station":"%s"}' "$name" "$hostname" "$ip")
            servers="$servers""$constructed_json"
        elif [ -n "$value" ]; then
            countryid=$(getcountryid "$value")
            serversincountry=$(curl -s "https://api.nordvpn.com/v1/servers/recommendations?$filterserver&filters\[country_id\]=$countryid" | jq -c '.[]')
            echo "Request servers in \"$(getcountryname "$value")\", $(echo "$serversincountry" | jq -s 'length') servers received"
            servers="$servers""$serversincountry"
        fi
    done
fi

poollength=$(echo "$servers" | jq -s 'unique | length')
servers=$(echo "$servers" | jq -s -c 'unique | sort_by(.load) | .[]')

if [[ ! ($RANDOM_TOP -eq 0) ]]; then
    if [[ $RANDOM_TOP -lt poollength ]]; then
        filtered=$(echo "$servers" | head -n "$RANDOM_TOP" | shuf)
        servers="$filtered"$(echo "$servers" | tail -n +$((RANDOM_TOP + 1)))
    else
        servers=$(echo "$servers" | shuf)
    fi
fi

echo "$poollength"" recommended servers in pool"
if [[ ! ($poollength -eq 0) ]]; then
    echo "--- Top 20 servers in filtered pool ---"
    echo "$servers" | jq -r '[.hostname, .load] | "\(.[0]): \(.[1])"' | head -n 20
    echo "---------------------------------------"
fi

if [[ $poollength -eq 0 ]]; then
    echo "ERROR: list of selected servers is empty"
fi

serverip=$(echo "$servers" | jq -r '.station' | head -n 1)
name=$(echo "$servers" | jq -r '.name' | head -n 1)
hostname=$(echo "$servers" | jq -r '.hostname' | head -n 1)
protocol=$(getopenvpnprotocol "$TECHNOLOGY")

echo "Select server \"$name\" hostname=\"$hostname\" ip=\"$serverip\" protocol=\"$protocol\""

cp "$ovpntemplatefile" "$ovpnfile"

sed -i "s/__IP__/$serverip/g" "$ovpnfile"
sed -i "s/__PROTOCOL__/$protocol/g" "$ovpnfile"
sed -i "s/__X509_NAME__/$hostname/g" "$ovpnfile"

if [[ "$protocol" == "udp" ]]; then
    sed -i "s/__PORT__/1194/g" "$ovpnfile"
elif [[ "$protocol" == "tcp" ]]; then
    sed -i "s/__PORT__/443/g" "$ovpnfile"
else
    echo "ERROR: TECHNOLOGY environment variable contains wrong parameter \"$TECHNOLOGY\""
fi

exit 0
