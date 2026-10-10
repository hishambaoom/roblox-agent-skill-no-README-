# CLAUDE.md

@AGENTS.md

## Claude Code specifics
- The `roblox-dev` skill (`.claude/skills/roblox-dev/`) holds the step-by-step loop; invoke it with `/roblox-dev` or let it
  load automatically for Roblox tasks.
- Subagents in `.claude/agents/`: `roblox-implementer` (one disjoint file set per worker, never publishes),
  `roblox-verifier` (read-only + shell, audits a merged build), `roblox-ui-fixer` (fast-lane UI fit without design changes).
- Studio MCP: `.mcp.json` registers Studio's built-in server (`Roblox_Studio`); check with `/mcp`. If Studio isn't
  connected, keep working with the rig and say "NOT playtested".
- Secrets: `ROBLOX_API_KEY`, `UNIVERSE_ID`, `PLACE_ID` come from the shell environment. Never echo the key.
- Keep replies short: version, change, screenshots, Verified / Not verified, one "your call".
