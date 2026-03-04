access=$(curl --request POST --data '{"account_number":"#ACCOUNTNUMBERHERE"}' https://api.mullvad.net/auth/v1/token -H "Content-Type: application/json" | jq -r '.access_token')
echo -e $access

devices=$(curl -fsSL -H 'Content-Type: application/json' -H 'Accepts: application/json' -H "Authorization: Bearer $access" https://api.mullvad.net/accounts/v1/devices | jq .)

echo -e $devices | jq .