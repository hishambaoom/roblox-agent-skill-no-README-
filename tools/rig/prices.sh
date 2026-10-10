#!/bin/bash
# Change a game pass or developer product price (and/or for-sale flag) through Open Cloud.
# usage: tools/rig/prices.sh pass    <gamePassId> <priceRobux> [isForSale=true]
#        tools/rig/prices.sh product <productId>  <priceRobux> [isForSale=true]
# env:   ROBLOX_API_KEY (needs the game-pass / developer-product write scopes for this universe), UNIVERSE_ID
#        OPEN_CLOUD_BASE (default https://apis.roblox.com; only for pointing the rig at a local mock server)
# Endpoints (Open Cloud reference, features/game-passes and features/developer-products), multipart/form-data body:
#   PATCH https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes/{gamePassId}
#   PATCH https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/{productId}
# A price is a money decision: only run this with the owner's explicit number. Report old -> new.
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"; : "${UNIVERSE_ID:?set UNIVERSE_ID}"
KIND=${1:?pass|product}; ID=${2:?id}; PRICE=${3:?price}; SALE=${4:-true}
case $KIND in
  pass)    URL="${OPEN_CLOUD_BASE:-https://apis.roblox.com}/game-passes/v1/universes/$UNIVERSE_ID/game-passes/$ID";;
  product) URL="${OPEN_CLOUD_BASE:-https://apis.roblox.com}/developer-products/v2/universes/$UNIVERSE_ID/developer-products/$ID";;
  *) echo "kind must be pass or product"; exit 2;;
esac
TMP=$(mktemp)
code=$(curl -sS -o "$TMP" -w '%{http_code}' -X PATCH "$URL" -H "x-api-key: $ROBLOX_API_KEY" \
       -F "price=$PRICE" -F "isForSale=$SALE")
echo "$KIND $ID -> $PRICE R\$ (isForSale=$SALE): HTTP $code $(head -c 300 "$TMP")"; rm -f "$TMP"
[ "$code" = 200 ] || [ "$code" = 204 ]
