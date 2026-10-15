# CLAUDE.md

@AGENTS.md

## Claude Code specifics
- The `roblox-dev` skill (`.claude/skills/roblox-dev/`) holds the step-by-step loop; invoke it with `/roblox-dev` or let it
  load automatically for Roblox tasks.
- Subagents in `.claude/agents/`: `roblox-implementer` (one disjoint file set per worker, never publishes),
  `roblox-verifier` (read-only + shell, audits a merged build), `roblox-ui-fixer` (fast-lane UI fit without design changes).
- Studio MCP (preferred for editing): `.mcp.json` registers Studio's built-in server `Roblox_Studio`
  (Windows: `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`; macOS: `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`).
  `.claude/settings.json` enables it and pre-allows the read-only tools; edit/play tools still ask the owner once.
  Start of every session: `list_roblox_studios` → keep the `studio_id`. Check with `/mcp` or `claude mcp list`.
  If it isn't connected: owner opens Studio → Assistant → `…` → Manage MCP Servers → Enable Studio as MCP server,
  then restarts Claude Code. Until then keep working with the rig and say "NOT playtested".
- After MCP edits the owner Saves (Ctrl+S / File → Save to File) and publishes from Studio. Never publish a pipeline
  build over Studio-only edits.
- Secrets: `ROBLOX_API_KEY`, `UNIVERSE_ID`, `PLACE_ID` come from the shell environment. Never echo the key.
- Keep replies short: version, change, screenshots, Verified / Not verified, one "your call".

Windows: run the PowerShell twins `.\tools\rig\*.ps1` (same arguments/output as the `.sh` scripts); see docs/windows.md.
