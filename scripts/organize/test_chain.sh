#!/bin/bash
# Organize regression harness.
# Usage: LUNE=tools/lune10 TESTS=games/<game>/work ORGANIZE=games/<game>/work/organize \
#        bash scripts/organize/test_chain.sh <place.rbxl> <label> "<agent>[:<IN>|:SELF] ..."
#   <agent>      = folder under $TESTS that has test.luau
#   :<IN>        = input place for tests that compare against an input file
#   :SELF        = the test reads the place under test from IN as well as OUT
# For each listed agent test, run it on:
#   1. the ORIGINAL place (baseline)
#   2. reverse(organize(place))  -> proves organize changed nothing but paths
#   3. organize(place) directly  -> shows which tests hard-code old paths
# Verdict REGRESSION = passed on baseline, fails after reverse(organize(place)).
set -u
L=${LUNE:-tools/lune10}
W=${TESTS:?set TESTS to the folder holding <agent>/test.luau}
ORG=${ORGANIZE:?set ORGANIZE to the folder holding check.luau and reverse.luau}
APPLY=${APPLY:-$ORG/apply.luau}   # your organize pass (start from scripts/organize/organize-template.luau)
O=${OUTDIR:-$ORG/out}
P=$1; LBL=$2; SPECS=$3
mkdir -p "$O/logs"
L=$(cd "$(dirname "$L")" && pwd)/$(basename "$L"); P=$(cd "$(dirname "$P")" && pwd)/$(basename "$P"); O=$(cd "$O" && pwd)
IN=$P OUT=$O/${LBL}_org.rbxl README_MD=$O/README_${LBL}.md $L run "$APPLY" > "$O/logs/${LBL}_apply.log" 2>&1 \
  || { echo "$LBL APPLY FAILED"; tail -5 "$O/logs/${LBL}_apply.log"; exit 1; }
IN=$O/${LBL}_org.rbxl BEFORE=$P $L run "$ORG/check.luau" > "$O/logs/${LBL}_check.log" 2>&1
echo "$LBL refcheck: $(tail -1 "$O/logs/${LBL}_check.log")"
IN=$O/${LBL}_org.rbxl OUT=$O/${LBL}_rev.rbxl $L run "$ORG/reverse.luau" > /dev/null || { echo "$LBL REVERSE FAILED"; exit 1; }
for spec in $SPECS; do
  a=${spec%%:*}; tin=${spec#*:}; [ "$tin" = "$a" ] && tin=""
  run() {
    (cd "$W/$a" && if [ "$tin" = "SELF" ]; then IN=$1 OUT=$1 $L run test.luau
      elif [ -n "$tin" ]; then IN=$tin OUT=$1 $L run test.luau
      else env -u IN OUT=$1 $L run test.luau; fi) > "$O/logs/${LBL}_${a}_$2.log" 2>&1; echo $?
  }
  b=$(run "$P" base); r=$(run "$O/${LBL}_rev.rbxl" rev); d=$(run "$O/${LBL}_org.rbxl" org)
  verdict=OK; [ "$b" = 0 ] && [ "$r" != 0 ] && verdict=REGRESSION
  [ "$b" != 0 ] && [ "$r" != 0 ] && { cmp -s <(grep -i fail "$O/logs/${LBL}_${a}_base.log") <(grep -i fail "$O/logs/${LBL}_${a}_rev.log") \
    || verdict="DIFF-FAILS(baseline already failing)"; }
  echo "$LBL $a: baseline=$b reversed=$r direct-on-organized=$d  $verdict"
done
