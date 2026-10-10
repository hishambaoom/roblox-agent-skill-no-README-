#!/bin/bash
# Fast tests: the STRICT guard tests ($FAST_TESTS) + any tests you name, all in parallel, one-line summary.
# usage: tools/rig/fast.sh <place.rbxl> [test names or paths...]
#   tools/rig/fast.sh work/x/v145.rbxl shop_cards_test
# Exit 0 only if every test exits 0. Logs: $RIG_OUT/fast/<test>.log
HERE=$(cd "$(dirname "$0")" && pwd); source "$HERE/config.sh"
P=${1:?usage: fast.sh <place> [tests...]}; shift
[ -f "$P" ] || { echo "fast.sh: no place $P"; exit 2; }
D=$RIG_OUT/fast; mkdir -p "$D"; rm -f "$D"/*.rc
t0=$(date +%s.%N)
run(){ n=$1; f=$2; shift 2; ( env "$@" timeout 600 "$LUNE" run "$f" "$P" > "$D/$n.log" 2>&1; echo $? > "$D/$n.rc" ) & }
resolve(){ x=$1
  if [ -f "$x" ]; then echo "$x"; elif [ -f "$TESTS/$x.luau" ]; then echo "$TESTS/$x.luau"; elif [ -f "$TESTS/$x" ]; then echo "$TESTS/$x"; fi; }
for t in $FAST_TESTS; do f=$(resolve "$t"); [ -n "$f" ] && run "$t" "$f" STRICT=1; done
for x in "$@"; do f=$(resolve "$x"); [ -n "$f" ] || { echo "fast.sh: no test $x"; exit 2; }; run "$(basename "$f" .luau)" "$f" FAST=1; done
wait
pass=0; fail=0; s=""
for r in "$D"/*.rc; do [ -f "$r" ] || continue; n=$(basename "$r" .rc)
  if [ "$(cat "$r")" = 0 ]; then pass=$((pass+1)); s="$s $n:ok"; else fail=$((fail+1)); s="$s $n:FAIL"; fi; done
printf "fast %s: %d pass / %d fail |%s  (%.1f s, logs %s)\n" "$([ $fail = 0 ] && echo PASS || echo FAIL)" $pass $fail "$s" \
  "$(awk -v a=$t0 -v b=$(date +%s.%N) 'BEGIN{print b-a}')" "$D"
[ $fail = 0 ]
