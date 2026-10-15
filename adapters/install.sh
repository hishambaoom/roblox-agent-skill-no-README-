#!/bin/bash
# Install the skill into a Roblox game repo.
# usage: bash adapters/install.sh <target repo> [claude] [codex] [antigravity] [cursor] [opencode] [all]
#   Always copies: AGENTS.md, SKILL.md, INSTALL_FOR_AGENTS.md, docs/, tools/, scripts/, assets/. Never overwrites an
#   existing file unless FORCE=1. Then downloads Lune 0.8.9 -> tools/lune and 0.10.5 -> tools/lune10 (tools/get-lune.sh);
#   NO_LUNE=1 skips that. Native Windows: use install.ps1.
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
cp_safe "$SRC/INSTALL_FOR_AGENTS.md" "$DST/INSTALL_FOR_AGENTS.md"
copy_tree "$SRC/tools" "$DST/tools"
copy_tree "$SRC/scripts" "$DST/scripts"
copy_tree "$SRC/assets" "$DST/assets"
chmod +x "$DST"/tools/rig/*.sh 2>/dev/null || true
want(){ for a in "${TARGETS[@]}"; do [ "$a" = "$1" ] || [ "$a" = all ] && return 0; done; return 1; }
TARGETS=("$@")
if want claude; then echo "claude code:"
  cp_safe "$SRC/adapters/claude-code/CLAUDE.md" "$DST/CLAUDE.md"
  copy_tree "$SRC/adapters/claude-code/.claude" "$DST/.claude"
  # Studio MCP for Claude Code: project .mcp.json (merged into an existing one, never replaced)
  case "$(uname -s)" in Darwin) MCPJ="$SRC/adapters/claude-code/mcp/mcp.macos.json";; *) MCPJ="$SRC/adapters/claude-code/mcp/mcp.windows.json";; esac
  if [ ! -f "$DST/.mcp.json" ]; then cp "$MCPJ" "$DST/.mcp.json"; echo "  + $DST/.mcp.json (Roblox_Studio)"
  elif command -v python3 >/dev/null; then python3 - "$DST/.mcp.json" "$MCPJ" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); n=json.load(open(sys.argv[2]))
s=d.setdefault("mcpServers",{})
if "Roblox_Studio" in s: print("  skip (exists) Roblox_Studio in .mcp.json")
else: s["Roblox_Studio"]=n["mcpServers"]["Roblox_Studio"]; json.dump(d,open(sys.argv[1],"w"),indent=2); print("  + Roblox_Studio merged into .mcp.json")
PY
  else echo "  .mcp.json exists: add the Roblox_Studio entry from adapters/claude-code/mcp/ by hand"; fi
fi
if want codex; then echo "codex:"; copy_tree "$SRC/adapters/codex/.agents" "$DST/.agents"
  echo "  (merge adapters/codex/config.toml.example into ~/.codex/config.toml yourself)"; fi
if want antigravity; then echo "antigravity:"; copy_tree "$SRC/adapters/antigravity/.agents" "$DST/.agents"; fi
if want cursor; then echo "cursor:"; copy_tree "$SRC/adapters/cursor/.cursor" "$DST/.cursor"; fi
if want opencode; then echo "opencode:"; cp_safe "$SRC/adapters/opencode/opencode.json" "$DST/opencode.json"; fi
[ -f "$DST/QUEUE.md" ] || { printf '# QUEUE (version log) - format: docs/project-state-template.md\n' > "$DST/QUEUE.md"; echo "  + QUEUE.md"; }
[ -f "$DST/PROJECT.md" ] || { printf '# Project brief - template: docs/project-state-template.md\n' > "$DST/PROJECT.md"; echo "  + PROJECT.md"; }
grep -qs '^\.env$' "$DST/.gitignore" || { printf '.env\nwork/x/\nwork/rig/out/\n*.rbxl.log.txt\n' >> "$DST/.gitignore"; echo "  + .gitignore entries"; }
if [ "${NO_LUNE:-0}" != 1 ]; then bash "$SRC/tools/get-lune.sh" "$DST" || echo "  lune download failed - run tools/get-lune.sh later (needs internet)"; fi
echo "done. Next: export ROBLOX_API_KEY UNIVERSE_ID PLACE_ID (only to publish), read docs/model-setup.md"
