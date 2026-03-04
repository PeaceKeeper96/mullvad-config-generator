#!/bin/bash


# Set constants
ALLOWED_COUNTRIES=("Sweden") # Put your countries here!
ACCOUNT_NUMBER="" # Put your account number here!


priv_key=$(wg genkey)
WG_KEY=$(wg pubkey <<< ${priv_key})

RESPONSE="$(curl -sSL https://api.mullvad.net/wg -d account="$ACCOUNT_NUMBER" --data-urlencode pubkey="${WG_KEY}")" || die "Could not talk to Mullvad API."
[[ $RESPONSE =~ ^[0-9a-f:/.,]+$ ]] || die "$RESPONSE"
ADDRESS="$RESPONSE"


CONFIG_DIR="./mullvad/configs"
JSON_FILE="mullvad-relays.json"
IP_FAMILY=4



# required files exist???
if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: Mullvad JSON file not found at $JSON_FILE"
    exit 1
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "Error: Target configuration directory does not exist at $CONFIG_DIR"
    exit 1
fi

if [[ ${#WG_KEY} -ne 44 ]]; then
    echo "Error: Specified WireGuard key is not valid."
    exit 1
fi

# Parse Mullvad JSON relay
declare -A MULLVAD_ENDPOINTS

for country in "${ALLOWED_COUNTRIES[@]}"; do
    # Extract relays countries we want to use
    while IFS= read -r relay; do
        city_code=$(echo "$relay" | jq -r '.city.code')
        hostname=$(echo "$relay" | jq -r '.hostname' | sed 's/-wireguard//')
        relay_name="${hostname}-${city_code}"
        ip=$(echo "$relay" | jq -r '.ipv4_addr_in // empty')
        multihop_port=$(echo "$relay" | jq -r '.multihop_port')
        public_key=$(echo "$relay" | jq -r '.public_key')

        if [[ -z "$ip" ]]; then
            continue
        fi

        MULLVAD_ENDPOINTS["$relay_name"]="$ip $multihop_port $public_key"
    done < <(jq -c --arg country "$country" '.countries[] | select(.name==$country) | .cities[].relays[]' "$JSON_FILE")
done

# gen configs
for target in "${!MULLVAD_ENDPOINTS[@]}"; do
    IFS=' ' read -r target_ip target_port target_pubkey <<< "${MULLVAD_ENDPOINTS[$target]}"

    for endpoint in "${!MULLVAD_ENDPOINTS[@]}"; do
        if [[ "$target" == "$endpoint" ]]; then
            continue
        fi

        IFS=' ' read -r endpoint_ip endpoint_port endpoint_pubkey <<< "${MULLVAD_ENDPOINTS[$endpoint]}"
        multihop_target_name="${endpoint%%-*}${target%%-*}"
        final_config_path="${CONFIG_DIR}/mlvd-${multihop_target_name}.conf"

        if [[ $IP_FAMILY -eq 6 ]]; then
            final_config_path="${final_config_path/mlvd/mlvd6}"
        fi

        # Create config
        cat <<EOF > "$final_config_path"
[Interface]
PrivateKey = $priv_key
Address = $ADDRESS
DNS = 10.64.0.1

[Peer]
PublicKey = $target_pubkey
AllowedIPs = 0.0.0.0/0,::0/0
Endpoint = $endpoint_ip:$target_port
EOF
    done
done

echo "WireGuard configurations generated successfully in $CONFIG_DIR."

# sping up configs
CONFIG_FILENAME=$(find configs/ -type f | shuf -n 1)
sudo mv ${CONFIG_FILENAME} /etc/wireguard/Outward.conf
sudo wg-quick up Outward