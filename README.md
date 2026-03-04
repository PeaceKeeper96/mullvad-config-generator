# mullvad-config-generator
A simple bash script for generating and destroying on the fly mullvad configs, in any location!

# Requirements
You will require:
- Unix System with BASH
- A mullvad account number
    - at least 1 free device on your mullvad account
- wireguard (`sudo apt install wireguard-tools`)

# Usage
In `destroy.sh` on line 1 - remove #ACCOUNTNUMBERHERE and replace it with your own.

```bash
access=$(curl --request POST --data '{"account_number":"#ACCOUNTNUMBERHERE"}' https://api.mullvad.net/auth/v1/token -H "Content-Type: application/json" | jq -r '.access_token')
echo -e $access

devices=$(curl -fsSL -H 'Content-Type: application/json' -H 'Accepts: application/json' -H "Authorization: Bearer $access" https://api.mullvad.net/accounts/v1/devices | jq .)

echo -e $devices | jq .
```

Do the same in `create.sh` on line 6

```bash
ACCOUNT_NUMBER="" # Put your account number here!
```

You can also change the countries you want to randomly generate by changing line 5 like so:

```bash
ALLOWED_COUNTRIES=("Sweden" "France" "Canada") # Put your countries here!
```