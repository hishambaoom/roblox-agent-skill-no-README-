#!/bin/bash
# Publish a built place LIVE through Roblox Open Cloud (Place Publishing API). Only when the owner asked for it,
# or when the project's standing rule says fast-lane fixes ship after tests pass.
# usage: tools/rig/publish.sh <place.rbxl>
# env:   ROBLOX_API_KEY (Open Cloud key, scope universe-places:write, restricted to this universe), UNIVERSE_ID, PLACE_ID
#        VERSION_TYPE=Published (default; live for players) | Saved (uploads a version without making it live)
# Retries HTTP 409 (another publish/save in progress) up to 3 times with backoff. Prints versionNumber.
# Never hardcode the key in this file, a hook, a log, a commit or a chat message.
#        DRY_RUN=1 prints what would be sent (no network, no key needed) - use it to test the rig.
HERE=$(cd "$(dirname "$0")" && pwd); source "$HERE/config.sh"
P=${1:?usage: publish.sh <place.rbxl>}
[ -f "$P" ] || { echo "publish.sh: no place $P"; exit 2; }
if [ "${DRY_RUN:-0}" = 1 ]; then
  echo "DRY_RUN: would POST $(wc -c < "$P") bytes of $P to https://apis.roblox.com/universes/v1/${UNIVERSE_ID:-<UNIVERSE_ID>}/places/${PLACE_ID:-<PLACE_ID>}/versions?versionType=${VERSION_TYPE:-Published} (x-api-key: $([ -n "${ROBLOX_API_KEY:-}" ] && echo set || echo MISSING)) and copy it to $CANON"
  exit 0
fi
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY (Open Cloud API key) in the environment}"
: "${UNIVERSE_ID:?set UNIVERSE_ID}"; : "${PLACE_ID:?set PLACE_ID}"
VT=${VERSION_TYPE:-Published}
case "$P" in *.rbxlx) CT=application/xml;; *) CT=application/octet-stream;; esac
mkdir -p "$(dirname "$CANON")"
[ "$(realpath "$P")" = "$(realpath -m "$CANON")" ] || cp "$P" "$CANON"
URL="https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=$VT"
TMP=$(mktemp)
for try in 1 2 3 4; do
  code=$(curl -sS -o "$TMP" -w '%{http_code}' -X POST "$URL" -H "x-api-key: $ROBLOX_API_KEY" \
         -H "Content-Type: $CT" --data-binary @"$CANON")
  if [ "$code" = 200 ]; then
    echo "published ($VT) versionNumber=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("versionNumber"))' "$TMP")"
    rm -f "$TMP"; exit 0
  fi
  echo "publish try $try: HTTP $code $(head -c 300 "$TMP")"
  if [ "$code" = 409 ] && [ $try -lt 4 ]; then sleep $((try * 5)); continue; fi
  # 401/403: key wrong, expired, missing scope, or IP not allowed. 404: wrong universe/place pair. 413: file too big.
  rm -f "$TMP"; exit 1
done
rm -f "$TMP"; exit 1
