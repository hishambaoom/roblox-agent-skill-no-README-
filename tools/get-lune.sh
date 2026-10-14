#!/bin/bash
# Download the two Lune versions the rig needs into <game repo>/tools/ (Linux, macOS, Git Bash on Windows).
# usage: bash tools/get-lune.sh [<game repo>]      (default: current folder)
#   tools/lune   = Lune 0.8.9  (builds + tests)
#   tools/lune10 = Lune 0.10.5 (place files saved by a recent Studio)
# Skips a binary that already exists unless FORCE=1. Override versions with LUNE_V8 / LUNE_V10.
set -e
ROOT=${1:-.}
TOOLS="$ROOT/tools"; mkdir -p "$TOOLS"
V8=${LUNE_V8:-0.8.9}; V10=${LUNE_V10:-0.10.5}
case "$(uname -s)" in
  Linux*) OS=linux; EXT= ;;
  Darwin*) OS=macos; EXT= ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows; EXT=.exe ;;
  *) echo "unknown OS $(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in arm64|aarch64) ARCH=aarch64 ;; *) ARCH=x86_64 ;; esac
command -v unzip >/dev/null || { echo "needs unzip (or run tools/get-lune.ps1 on Windows)"; exit 1; }
get(){ # get <version> <out name>
  out="$TOOLS/$2$EXT"
  if [ -e "$out" ] && [ "${FORCE:-0}" != 1 ]; then echo "  skip (exists) $out"; return; fi
  a=$ARCH; if [ "$OS" = windows ] && [ "${1#0.8}" != "$1" ]; then a=x86_64; fi
  zip="lune-$1-$OS-$a.zip"; url="https://github.com/lune-org/lune/releases/download/v$1/$zip"
  tmp=$(mktemp -d); echo "  downloading $url"
  curl -fsSL "$url" -o "$tmp/$zip"; unzip -q -o "$tmp/$zip" -d "$tmp"
  bin=$(find "$tmp" -type f -name "lune$EXT" | head -1); [ -n "$bin" ] || { echo "lune$EXT not in $zip"; exit 1; }
  cp "$bin" "$out"; chmod +x "$out"; rm -rf "$tmp"
  echo "  + $out  ($("$out" --version 2>&1))"; }
echo "lune ($OS-$ARCH):"
get "$V8" lune
get "$V10" lune10
echo "done."
