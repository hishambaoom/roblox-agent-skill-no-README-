# roblox-agent-skill

A portable, agent-agnostic **Roblox game development skill**: the rules, workflow, scripts and worked examples that
shipped 144 versions of *Don't Wake the Pumpkin King* with AI agents — packaged so any agent (Claude Code, Codex CLI,
Cursor, OpenCode, Google Antigravity, Gemini CLI, ChatGPT/Claude projects) and any frontier model can work on a Roblox
game the same way.

What it gives an agent:
- **Standing rules** that keep the game owner in control: everything visible is a real, editable Studio instance
  ("I WANNA BE ABLE TO CHANGE AND EDIT ANYTHING I WANT"), tunables are attributes, UI clones existing templates,
  "DON'T CHANGE THE DESIGN", the owner's game design is final, never claim a playtest you didn't run.
- **A fast loop**: edit a build hook → `tools/rig/go.sh` builds the .rbxl with Lune (~2 s), renders PC + phone
  screenshots (~1 s), runs guard tests (~3 s) and publishes through Open Cloud only if they pass.
- **A gameplay lane** with tests that must fail on the base build, full-suite comparison, and parallel workers +
  an independent verifier.
- **Lessons** from real bugs (weak Instance-keyed tables, TextScaled without TextWrapped, Lune meshes that don't render,
  Studio edits wiped by pipeline publishes, …).

## Layout
```
AGENTS.md            main instructions (persona, rules, loop, decision table, report format)  ← start here
SKILL.md             Agent-Skills style entry point (name/description frontmatter) → docs index
docs/                workflow, studio-first rule, Lune pipeline, testing, publishing, Studio MCP, UI, monetization,
                     security, launch checklist, lessons, state templates, thinking, subagents, model setup, resources
docs/examples/       5 worked sessions: request → plan → commands → output → report
adapters/            ready-to-copy files: claude-code/ codex/ antigravity/ cursor/ opencode/ chat-only/ + install.sh
tools/rig/           go.sh shot.sh fast.sh run_all.sh compare_runs.sh publish.sh prices.sh retention.sh config.sh
                     render.py (rig screenshot renderer) dump.example.luau (layout dumper, adapt boot to your game)
tools/uimap/         ui-map generator (grep-able map of every UI element and its look)
tools/mcp/           Studio MCP HTTP client + example UI probe
tools/example-game/  example build.luau + hook + tests (feature, studio-rule guard, text size) + rbxsim.luau
```

## Install

### Any agent, 30 seconds
```bash
git clone https://github.com/<you>/roblox-agent-skill ~/roblox-agent-skill
bash ~/roblox-agent-skill/adapters/install.sh /path/to/your-game claude codex antigravity cursor opencode
```
Copies `AGENTS.md`, `SKILL.md`, `docs/`, `tools/` and the adapters you name into your game repo (never overwrites
unless `FORCE=1`), creates `QUEUE.md`/`PROJECT.md` stubs and `.gitignore` entries.

| Agent | What it reads | Details |
|---|---|---|
| Claude Code | `CLAUDE.md` (`@AGENTS.md` import), `.claude/skills/roblox-dev/`, `.claude/agents/*`, `.mcp.json` | docs/model-setup.md |
| Codex CLI | `AGENTS.md`, `.agents/skills/roblox-dev/`, `~/.codex/config.toml` | docs/model-setup.md |
| Antigravity | `AGENTS.md`, `.agents/rules/*.md` (trigger frontmatter), `.agents/skills/`, `.agents/workflows/` | docs/model-setup.md |
| Cursor | `AGENTS.md`, `.cursor/rules/*.mdc` | docs/model-setup.md |
| OpenCode | `AGENTS.md`, `opencode.json` | docs/model-setup.md |
| Chat-only (ChatGPT, Claude.ai, Gems) | paste `adapters/chat-only/system-prompt.md`, upload AGENTS.md + docs | docs/model-setup.md |

### Requirements
Lune (https://github.com/lune-org/lune/releases) at `tools/lune` (0.8.x) and `tools/lune10` (0.10.x for files from
recent Studio) · bash · Python 3 + Pillow (screenshots) · for publishing: an Open Cloud API key with
`universe-places:write` in `ROBLOX_API_KEY`, plus `UNIVERSE_ID` and `PLACE_ID` · optional: Roblox Studio MCP (built in).

## Quick start (no key needed)
```bash
export GAME_DIR=tools/example-game BASE=path/to/your-place.rbxl
BUILD_OUT=work/x/t1.rbxl tools/lune run tools/example-game/build.luau      # build: base + example hook
tools/rig/fast.sh work/x/t1.rbxl example_feature_test                      # guard + feature tests
tools/rig/shot.sh work/x/t1.rbxl t1                                        # work/rig/out/t1_pc.png, t1_phone.png
DRY_RUN=1 tools/rig/go.sh t2 example_feature_test                          # whole fast lane, publish rehearsed
```
Then point `GAME_DIR` at your own game folder (its `build.luau`, hooks and tests), copy `tools/rig/dump.example.luau`
to `tools/rig/dump.luau` and adapt its boot section to your client scripts, and set the publish env vars.

## Ask your agent
- "The shop cards overlap the jump button on phone." → fast lane, shots, version.
- "Free steal every 120 s, paid cooldown 30 s." → tunable change, test, publish, one "your call" if risky.
- "Players lose their bag order on rejoin." → gameplay lane: root cause, saved field + migration, test fails on base.
- "Are we ready to launch?" → read-only audit, verdict, ordered blockers.

## Safety
No secrets, keys, emails or place files are included. Keys live in your environment only. Universe/place IDs of the
reference game appear as public examples.

License: MIT.
