#!/bin/bash
# Keep the newest build + 3 older ones in $XDIR (and the LIVE file named in the version log). Deletes the rest.
# usage: tools/rig/retention.sh [keep=4]       DRY=1 to only list what would go.
# Never deletes: the file the latest "DONE ... LIVE = <file>" line in QUEUE.md names, or $CANON.
HERE=$(cd "$(dirname "$0")" && pwd); source "$HERE/config.sh"
KEEP=${1:-4}
LIVE=$(grep -oE 'LIVE = [^ ]+\.rbxl' QUEUE.md 2>/dev/null | tail -1 | awk '{print $3}')
ls -1t "$XDIR"/*.rbxl 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
  [ -n "$LIVE" ] && [ "$(realpath "$f")" = "$(realpath -m "$LIVE")" ] && { echo "keep (LIVE) $f"; continue; }
  if [ "${DRY:-0}" = 1 ]; then echo "would delete $f"; else rm -f "$f" "$f.log.txt" "${f%.rbxl}.build.log"; echo "deleted $f"; fi
done
