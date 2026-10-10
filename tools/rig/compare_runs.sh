#!/bin/bash
# Diff two run_all.sh log dirs: which tests changed rc, and per-log FAIL-line counts.
# usage: tools/rig/compare_runs.sh <base logdir> <new logdir>
A=${1:?usage}; B=${2:?usage}
echo "== rc changes (base -> new)"
join <(sort "$A/rc.txt") <(sort "$B/rc.txt") -a1 -a2 -e MISSING -o 0,1.2,2.2 2>/dev/null | awk '$2!=$3{print "  "$0}'
diff <(sort "$A/rc.txt") <(sort "$B/rc.txt") > /dev/null && echo "  (identical rc set)"
echo "== FAIL-line counts that differ"
for f in "$B"/*.log; do n=$(basename "$f")
  if [ -f "$A/$n" ]; then a=$(grep -c "FAIL" "$A/$n"); else a=-; fi; b=$(grep -c "FAIL" "$f")
  [ "$a" != "$b" ] && echo "  $n: $a -> $b"; done
echo "done"
