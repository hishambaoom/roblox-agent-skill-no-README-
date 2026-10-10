#!/bin/bash
# FAST LANE, one command: build -> PC + phone screenshots -> fast tests -> publish (only if tests pass) -> ui-map refresh.
# usage: tools/rig/go.sh <name> [open=<MenuName>] [extra dump flags] [test names...]
#   tools/rig/go.sh v145 open=ShopFrame                 # tweak a menu, check it, ship it
#   NOPUBLISH=1 tools/rig/go.sh v145 open=ShopFrame     # same, but stop before publishing (owner wants to look first)
# Typical wall time in the reference project: build ~2 s, shots ~1-2 s, fast tests ~3 s, publish ~3-5 s.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); source "$HERE/config.sh"
N=${1:?usage: go.sh <name> [open=Menu] [flags] [tests...]}; shift
SHOT=(); TST=()
for a in "$@"; do case $a in open=*|touch|lair|*=*) SHOT+=("$a");; *) TST+=("$a");; esac; done
P=$XDIR/$N.rbxl; mkdir -p "$XDIR"
t0=$(date +%s)
BUILD_OUT=$P "$LUNE" run "$GAME_DIR/build.luau" > "$XDIR/$N.build.log" 2>&1 || { echo "BUILD FAIL ($XDIR/$N.build.log)"; tail -5 "$XDIR/$N.build.log"; exit 1; }
bash "$HERE/shot.sh" "$P" "$N" "${SHOT[@]}" > /dev/null 2>&1 & S=$!
if ! bash "$HERE/fast.sh" "$P" "${TST[@]}"; then
  wait $S; echo "TESTS FAIL - not published. shots: $RIG_OUT/${N}_pc.png $RIG_OUT/${N}_phone.png"; exit 1
fi
wait $S
echo "shots: $RIG_OUT/${N}_pc.png $RIG_OUT/${N}_phone.png   <- LOOK at both before reporting"
if [ "${NOPUBLISH:-0}" = 1 ]; then echo "NOPUBLISH=1: built + tested, not published ($P)"; else bash "$HERE/publish.sh" "$P" || exit 1; fi
[ -f tools/uimap/uimap_build.py ] && (python3 tools/uimap/uimap_build.py "$P" > /dev/null 2>&1 &)
echo "total $(( $(date +%s) - t0 )) s"
