# Model / agent setup

The skill is plain Markdown + shell/Lune/Python scripts, so any frontier model (GPT-6.x, Claude Opus 5.x, Gemini, …)
can follow it. What differs per agent is **where it looks for instructions**. Ready-to-copy files are in `adapters/`.

Quick install into a game repo (copies AGENTS.md, SKILL.md, docs/, tools/ and the adapters you name; never overwrites
unless `FORCE=1`):
```bash
git clone <this repo> ~/roblox-agent-skill
bash ~/roblox-agent-skill/adapters/install.sh ~/games/my-game claude codex antigravity cursor opencode
# then: put Lune in ~/games/my-game/tools/lune (0.8.x) and tools/lune10 (0.10.x)
export ROBLOX_API_KEY=...  UNIVERSE_ID=...  PLACE_ID=...     # in your shell profile or a git-ignored .env
```

On Windows without bash, use the PowerShell twins: `.\adapters\install.ps1 C:\games\my-game claude codex …`, then
`tools\rig\*.ps1` — full walkthrough in [windows.md](windows.md).

Common prerequisites: git, bash (or PowerShell on Windows), Python 3 + Pillow (`pip install pillow`, for rig screenshots), Lune
(https://github.com/lune-org/lune/releases), optional Node.js + cloudflared for a remote Studio bridge.
Smoke test after install (no key needed):
```bash
GAME_DIR=tools/example-game BASE=<your.rbxl> BUILD_OUT=work/x/t1.rbxl tools/lune run tools/example-game/build.luau
GAME_DIR=tools/example-game BASE=<your.rbxl> DRY_RUN=1 tools/rig/go.sh t2 example_feature_test
```
```powershell
# Windows PowerShell / pwsh (docs/windows.md)
$env:GAME_DIR='tools\example-game'; $env:BASE='<your.rbxl>'
$env:BUILD_OUT='work\x\t1.rbxl'; .\tools\lune.exe run tools\example-game\build.luau; Remove-Item Env:BUILD_OUT
$env:DRY_RUN='1'; .\tools\rig\go.ps1 t2 example_feature_test; Remove-Item Env:DRY_RUN
```

---

## Claude Code
Files (from `adapters/claude-code/`):
```
CLAUDE.md                              # contains "@AGENTS.md" (import) + Claude-specific notes
.claude/skills/roblox-dev/SKILL.md     # project skill: /roblox-dev, auto-loads on Roblox tasks
.claude/agents/roblox-implementer.md   # parallel worker (owns a disjoint file set, never publishes)
.claude/agents/roblox-verifier.md      # independent verifier (Read/Grep/Glob/Bash only)
.claude/agents/roblox-ui-fixer.md      # fast-lane UI fit fixer ("don't change the design")
.mcp.json                              # Roblox_Studio MCP, written by the installer (Windows or macOS path)
.claude/settings.json                  # enables Roblox_Studio + pre-allows read-only MCP tools
```
Steps:
1. `bash adapters/install.sh <repo> claude` (or copy the files above to the repo root).
2. Start `claude` in the repo. Check: `/skills` lists `roblox-dev`; `/agents` reminder → files in `.claude/agents/`;
   `/mcp` shows `Roblox_Studio` (Studio must have *Enable Studio as MCP server* on). Studio's MCP panel also has
   one-click *Quick connect* for Claude Code.
3. Try: *"The sale badge is too small on phone"* → expect grep ui-map → hook edit → `go.sh` → shots → short report.
4. Batch: *"Use roblox-implementer subagents for the shop and the inventory parts, then roblox-verifier."*
Notes: Claude Code reads AGENTS.md directly in recent versions too; the `@AGENTS.md` import is harmless either way.
Docs: https://docs.anthropic.com/en/docs/claude-code/memory · /skills · /sub-agents (same site).

## OpenAI Codex CLI
Files: `AGENTS.md` (repo root — Codex reads it natively, walking from repo root to cwd; also `~/.codex/AGENTS.md`
for global defaults), `.agents/skills/roblox-dev/SKILL.md` (Codex scans `.agents/skills` up to the repo root),
`adapters/codex/config.toml.example` → merge into `~/.codex/config.toml`.
Steps:
1. `bash adapters/install.sh <repo> codex`.
2. Merge the example config: `project_doc_max_bytes` (default 32 KiB is enough for this AGENTS.md),
   `[mcp_servers.Roblox_Studio]` command (or use Studio's *Quick connect → Codex CLI*).
3. `codex` in the repo → ask *"What are your standing rules for this game?"* — it should quote the TOP RULE and the
   fast-lane loop. Run tasks with a sandbox mode that allows running `tools/rig/*.sh` (Windows: `tools\rig\*.ps1`) and network for publish.
Parallel work: separate Codex sessions in git worktrees, each with the worker brief from docs/subagents.md.
Docs: https://developers.openai.com/codex/guides/agents-md · https://developers.openai.com/codex/config-reference ·
https://developers.openai.com/codex/skills

## Google Antigravity (IDE / CLI / 2.0)
Antigravity reads `AGENTS.md`/`GEMINI.md` at the workspace root as always-on rules (no frontmatter), plus
`.agents/rules/*.md` (frontmatter **required**: `trigger: always_on | model_decision | glob | manual`, `description`,
`globs`; each rule ≤ 12,000 chars; legacy `.agent/rules` still read), skills in `.agents/skills/<name>/SKILL.md`, and
workflows in `.agents/workflows/*.md` invoked as `/workflow-name`.
Files (from `adapters/antigravity/`):
```
.agents/rules/roblox-luau-build.md   trigger: glob  ("*.luau, *.lua, **/build*.luau")
.agents/rules/roblox-ui.md           trigger: model_decision
.agents/rules/roblox-publish.md      trigger: model_decision
.agents/skills/roblox-dev/SKILL.md   the loop as a skill
.agents/workflows/fast-lane.md       /fast-lane
.agents/workflows/ship-batch.md      /ship-batch
```
⚠ Antigravity's docs announce that current **workflows stop working on 2026-10-19** in favour of a new system; migrate
with `/migrate-workflows` (turns them into skills) — the skill above already covers both workflows. An invalid
`trigger` (e.g. camelCase `alwaysOn`) makes Antigravity silently drop a rule.
Steps: `bash adapters/install.sh <repo> antigravity` → open the folder → Customizations → Rules shows the 3 rules →
Studio MCP via Studio's Quick connect (Antigravity is listed) → try `/fast-lane`.
Docs: https://antigravity.google/docs/rules · https://antigravity.google/docs/ide/workflows ·
https://antigravity.google/docs/migration/workflows-to-skills/

## Cursor
Cursor reads `AGENTS.md` natively and project rules from `.cursor/rules/*.mdc` (must be `.mdc` with frontmatter
`description`, `globs`, `alwaysApply`; plain `.md` there is ignored).
Files: `.cursor/rules/roblox-core.mdc` (alwaysApply), `roblox-luau.mdc` (globs `**/*.luau,**/*.lua`),
`roblox-ui.mdc` (agent-requested by description). Studio MCP: Studio Quick connect → Cursor, or Cursor MCP settings
with the same command as `.mcp.json`. Docs: https://cursor.com/docs/context/rules

## OpenCode
Reads `AGENTS.md` (falls back to `CLAUDE.md`, and `~/.claude/skills`). `adapters/opencode/opencode.json` adds the key
docs as extra `instructions` and the Studio MCP as a `local` server. Docs: https://opencode.ai/docs/rules/ ·
https://opencode.ai/docs/mcp-servers/

## Gemini CLI
Reads `GEMINI.md` by default; either symlink `GEMINI.md → AGENTS.md` or set `"context": {"fileName": ["AGENTS.md"]}` in
`.gemini/settings.json` (`context.fileName` accepts a string or list). Studio Quick connect supports Gemini CLI.
Docs: https://github.com/google-gemini/gemini-cli (docs/reference/configuration.md)

## ChatGPT / Claude.ai Projects / Gemini Gems (chat-only, no shell)
Use `adapters/chat-only/system-prompt.md`: paste the block into the project instructions, upload `AGENTS.md` and the
docs as knowledge. The model then gives full-script replacements with Studio paths + a 3-step Studio test, and labels
everything "not tested" until you report a playtest. Real-world note: the owner's flow that worked best with a chat
model was *chat model writes, Studio MCP agent or owner applies in Studio, owner saves .rbxl, pipeline tests + publishes*.

## Model tips (any vendor)
- Big models follow AGENTS.md well; the failure modes are **over-doing** (redesigning, adding popups, softening
  difficulty) and **over-claiming** (saying "tested"). The rules target exactly those — keep them at the top.
- Give the model the shell + the rig; a model that can run `go.sh` and look at PNGs is 10× faster than one that writes
  its own tooling.
- Keep reasoning effort high for gameplay/data changes, low for fast-lane tweaks.
- Long sessions: re-invoke the skill (`/roblox-dev`) after compaction; QUEUE.md lets a fresh session continue.
