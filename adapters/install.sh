#!/bin/bash
# Install the skill into a Roblox game repo.
# usage: bash adapters/install.sh <target repo> [claude] [codex] [antigravity] [cursor] [opencode] [all]
#   Always copies: AGENTS.md, SKILL.md, docs/ (as docs/ - skill doc names are unique), tools/rig, tools/uimap, tools/mcp,
#   tools/example-game (reference only). Never overwrites an existing file unless FORCE=1.
#   Lune binaries are NOT shipped: put lune (0.8.x) at <target>/tools/lune and lune 0.10.x at <target>/tools/lune10.
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
DST=${1:?usage: install.sh <target repo> [claude|codex|antigravity|cursor|opencode|all]}; shift
mkdir -p "$DST"
cp_safe(){ # cp_safe <src> <dst>
  if [ -e "$2" ] && [ "${FORCE:-0}" != 1 ]; then echo "  skip (exists) $2"; return; fi
  mkdir -p "$(dirname "$2")"; cp -r "$1" "$2"; echo "  + $2"; }
copy_tree(){ # copy_tree <src dir> <dst dir>
  (cd "$1" && find . -type f) | while read -r f; do cp_safe "$1/$f" "$2/$f"; done; }
echo "core:"
cp_safe "$SRC/AGENTS.md" "$DST/AGENTS.md"
cp_safe "$SRC/SKILL.md" "$DST/SKILL.md"
copy_tree "$SRC/docs" "$DST/docs"
copy_tree "$SRC/tools" "$DST/tools"
chmod +x "$DST"/tools/rig/*.sh 2>/dev/null || true
want(){ for a in "${TARGETS[@]}"; do [ "$a" = "$1" ] || [ "$a" = all ] && return 0; done; return 1; }
TARGETS=("$@")
if want claude; then echo "claude code:"; copy_tree "$SRC/adapters/claude-code" "$DST"; fi
if want codex; then echo "codex:"; copy_tree "$SRC/adapters/codex/.agents" "$DST/.agents"
  echo "  (merge adapters/codex/config.toml.example into ~/.codex/config.toml yourself)"; fi
if want antigravity; then echo "antigravity:"; copy_tree "$SRC/adapters/antigravity/.agents" "$DST/.agents"; fi
if want cursor; then echo "cursor:"; copy_tree "$SRC/adapters/cursor/.cursor" "$DST/.cursor"; fi
if want opencode; then echo "opencode:"; cp_safe "$SRC/adapters/opencode/opencode.json" "$DST/opencode.json"; fi
[ -f "$DST/QUEUE.md" ] || { printf '# QUEUE (version log) - format: docs/project-state-template.md\n' > "$DST/QUEUE.md"; echo "  + QUEUE.md"; }
[ -f "$DST/PROJECT.md" ] || { printf '# Project brief - template: docs/project-state-template.md\n' > "$DST/PROJECT.md"; echo "  + PROJECT.md"; }
grep -qs '^\.env$' "$DST/.gitignore" || { printf '.env\nwork/x/\nwork/rig/out/\n*.rbxl.log.txt\n' >> "$DST/.gitignore"; echo "  + .gitignore entries"; }
echo "done. Next: put Lune in tools/, export ROBLOX_API_KEY UNIVERSE_ID PLACE_ID, read docs/model-setup.md"
