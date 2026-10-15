# Install guide for AI agents (Codex, Claude Code, Cursor, OpenCode, Antigravity)

This file is written for the agent. The owner pastes one line, the agent does the rest.

## The line the owner pastes

> Install the Roblox skill from https://github.com/hishambaoom/roblox-agent-skill-no-README- into this folder by
> following its INSTALL_FOR_AGENTS.md (I use <Claude Code / Codex>), connect Roblox Studio's MCP server, then use it
> for all Roblox work here.

## Steps for the agent

Run every command from the owner's game folder (the folder that holds, or will hold, the `.rbxl`).
Downloads need internet: if your sandbox blocks network, ask the owner to approve the command (Codex: approve the
prompt or run with network allowed for this step).

### Windows (PowerShell 7 or Windows PowerShell 5.1) - default for this skill
```powershell
# 1. prerequisites (skip any that already work: git --version, py -3 --version)
winget install --id Git.Git -e --source winget
winget install --id Python.Python.3.12 -e --source winget
py -3 -m pip install pillow

# 2. get the skill and install it here (copies AGENTS.md, SKILL.md, docs, tools, scripts, assets, the Codex skill
#    folder .agents\skills\roblox-dev, and downloads Lune into tools\lune.exe + tools\lune10.exe)
git clone https://github.com/hishambaoom/roblox-agent-skill-no-README- "$HOME\roblox-agent-skill"
powershell -ExecutionPolicy Bypass -File "$HOME\roblox-agent-skill\adapters\install.ps1" . codex
#    (other agents: replace "codex" with claude / cursor / opencode / antigravity / all)

# 3. check
.\tools\lune.exe --version      # lune 0.8.9
.\tools\lune10.exe --version    # lune 0.10.5
```
If `winget` is missing, install Git and Python from git-scm.com and python.org (tick "Add python.exe to PATH").
If Windows blocks `lune.exe`: `Unblock-File .\tools\lune.exe; Unblock-File .\tools\lune10.exe`.
If a script will not run because of execution policy, call it as
`powershell -ExecutionPolicy Bypass -File .\tools\rig\go.ps1 ...` (no admin rights needed).

### macOS / Linux / WSL / Git Bash
```bash
git clone https://github.com/hishambaoom/roblox-agent-skill-no-README- ~/roblox-agent-skill
bash ~/roblox-agent-skill/adapters/install.sh . codex
python3 -m pip install pillow
./tools/lune --version && ./tools/lune10 --version
```

### Claude Code
- Install with the `claude` target: `...\install.ps1 . claude` (Windows) or `bash .../install.sh . claude`.
  That copies `CLAUDE.md`, `.claude/skills/roblox-dev`, `.claude/agents/*`, `.claude/settings.json` and writes
  `.mcp.json` with the `Roblox_Studio` server (merged into an existing `.mcp.json`, never replaced).
- If you prefer the CLI instead of the file (project scope, same result):
  Windows `claude mcp add --scope project Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"`
  macOS `claude mcp add --scope project Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`
- Then: owner restarts Claude Code, approves the `Roblox_Studio` server if asked, and you check with `claude mcp list`
  (or `/mcp`) and a `list_roblox_studios` call.

### Roblox Studio MCP (all agents)
1. Owner: open the place in Roblox Studio (latest version) → Assistant → `…` → **Manage MCP Servers** → turn on
   **Enable Studio as MCP server**. (Quick connect there can also register Claude Code / Codex / Cursor in one click.)
2. Agent: call `list_roblox_studios`; the owner's place should be listed. Pass its `studio_id` on every call.
3. Green indicator in Studio's MCP panel = connected. Nothing listed → restart Studio and the agent.
4. Work rules: docs/studio-mcp-bridge.md (MCP edits the owner's open file; owner saves + publishes from Studio).

### Codex extras (optional)
- Merge `~/roblox-agent-skill/adapters/codex/config.toml.example` into `%USERPROFILE%\.codex\config.toml`
  (Windows) or `~/.codex/config.toml`. Do not replace the owner's file; add the keys.
- Live Studio access: in Roblox Studio enable *Studio as MCP server* and use its Quick connect for Codex, or keep the
  `[mcp_servers.Roblox_Studio]` block from the example.
- Restart Codex after installing so it picks up `AGENTS.md` and `.agents/skills/roblox-dev`.

### Publishing (only when the owner wants it)
Set these as environment variables, never in a file in the repo:
```powershell
$env:ROBLOX_API_KEY = '<Open Cloud key with universe-places:write>'
$env:UNIVERSE_ID = '<universe id>'; $env:PLACE_ID = '<place id>'
```

## After installing
1. Read `AGENTS.md`, then `SKILL.md`, then only the doc a task needs.
2. Fill `PROJECT.md` with the owner's game, rules and IDs; keep `QUEUE.md` as the version log.
3. Windows: use the `.ps1` twins in `tools\rig\` (`go.ps1`, `shot.ps1`, `fast.ps1`, `run_all.ps1`, `publish.ps1`).
   Details and troubleshooting: `docs/windows.md`.
4. Tell the owner in 3 lines what was installed and anything that failed.
