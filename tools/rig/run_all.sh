#!/bin/bash
# FULL suite: every *_test.luau / *_check.luau in $TESTS against one place, in parallel. Writes rc.txt + one log per test.
# usage: tools/rig/run_all.sh <place.rbxl> <logdir>
# Compare two builds:  run_all.sh work/x/v144.rbxl /tmp/a; run_all.sh work/x/v145.rbxl /tmp/b; tools/rig/compare_runs.sh /tmp/a /tmp/b
# The rule is "same pass/fail set as the base build, plus the new test passing". Pre-existing failures are fine
# as long as they are known (stale assertions vs a later owner decision) and listed in the report.
HERE=$(cd "$(dirname "$0")" && pwd); source "$HERE/config.sh"
P=${1:?usage: run_all.sh <place> <logdir>}; D=${2:?usage}; mkdir -p "$D"; : > "$D/rc.txt"
run(){ name=$1; shift; timeout 600 "$LUNE" run "$@" > "$D/$name.log" 2>&1; echo "$name rc=$?" >> "$D/rc.txt"; }
for f in "$TESTS"/*.luau; do n=$(basename "$f" .luau)
  case $n in rbxsim|*_lib|*sim) continue;; esac   # helpers, not tests
  run "$n" "$f" "$P" &
done
wait
sort -o "$D/rc.txt" "$D/rc.txt"
echo "suite: $(grep -c 'rc=0' "$D/rc.txt") pass / $(grep -vc 'rc=0' "$D/rc.txt") fail  (logs $D)"
