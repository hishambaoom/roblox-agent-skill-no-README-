#!/bin/bash
# Approximate screenshots of a BUILT place, without Studio: PC 1920x1080 + phone 667x375 (touch).
# usage: tools/rig/shot.sh <place.rbxl> <name> [open=<MenuName>] [extra flags passed to the dump]
#   -> $RIG_OUT/<name>_pc.png + $RIG_OUT/<name>_phone.png   (dumps in $RIG_OUT/<name>_{pc,phone}/)
# These are rbxsim layout approximations (icons/3D = placeholders). They catch overflow, overlap, tiny text and
# off-screen elements in ~1-2 s. They are NOT a device test: say "rig render" in reports, never "verified on phone".
# Needs tools/rig/dump.luau (copy tools/rig/dump.example.luau and adapt its boot section to your game) + render.py (Pillow).
set -e
HERE=$(cd "$(dirname "$0")" && pwd); source "$HERE/config.sh"
P=${1:?usage}; N=${2:?usage}; shift 2
[ -f "$P" ] || { echo "shot.sh: no place $P"; exit 2; }
DUMP=$HERE/dump.luau; [ -f "$DUMP" ] || DUMP=$HERE/dump.example.luau
O=$RIG_OUT; mkdir -p "$O/${N}_pc" "$O/${N}_phone"
t0=$(date +%s.%N)
"$LUNE" run "$DUMP" "$P" "$O/${N}_pc" $PC_W $PC_H "$@" > "$O/${N}_pc/dump.log" 2>&1 & a=$!
"$LUNE" run "$DUMP" "$P" "$O/${N}_phone" $PHONE_W $PHONE_H touch "$@" > "$O/${N}_phone/dump.log" 2>&1 & b=$!
rc=0; wait $a || rc=1; wait $b || rc=1
if [ $rc != 0 ]; then echo "shot.sh: dump failed"; tail -5 "$O/${N}_pc/dump.log" "$O/${N}_phone/dump.log"; exit 1; fi
python3 "$HERE/render.py" "$O/${N}_pc/${PC_W}x${PC_H}.json" "$O/${N}_pc.png" > /dev/null &
python3 "$HERE/render.py" "$O/${N}_phone/${PHONE_W}x${PHONE_H}.json" "$O/${N}_phone.png" > /dev/null &
wait
printf "shot %s: %s %s  (%.1f s)\n" "$N" "$O/${N}_pc.png" "$O/${N}_phone.png" "$(awk -v a=$t0 -v b=$(date +%s.%N) 'BEGIN{print b-a}')"
