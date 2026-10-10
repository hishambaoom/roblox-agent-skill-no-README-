# Studio MCP bridge (talking to a live Studio)

The rig tests a built file. To check the **real engine** (rendering, physics, input, the owner's current Studio state)
use the Roblox Studio MCP server. Docs: https://create.roblox.com/docs/studio/mcp

## Setup
1. Studio → Assistant → `…` → **Manage MCP Servers** → turn on **Enable Studio as MCP server**.
2. Connect your agent over stdio:
   - Windows: `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`
   - macOS: `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`
   - Quick connect exists for Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI, VS Code, Antigravity.
   - JSON config (most clients):
     ```json
     { "mcpServers": { "Roblox_Studio": { "command": "cmd.exe", "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"] } } }
     ```
3. **Agent in the cloud / another machine:** wrap stdio as HTTP and tunnel it (what the reference project used):
   ```
   npx -y supergateway --stdio "cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat" --outputTransport streamableHttp --port 8000
   cloudflared tunnel --url http://localhost:8000        # prints https://<words>.trycloudflare.com
   export STUDIO_MCP_URL=https://<words>.trycloudflare.com/mcp
   python3 tools/mcp/mcpc.py tools
   ```
   Quick-tunnel URLs change on every restart: the owner pastes the new link. Anyone with the URL can drive Studio: share
   it only with the agent and stop the tunnel after the session.

## Two ways of working (both used for real)
| Mode | How | Best for | Catch |
|---|---|---|---|
| **Pipeline** (default) | Lune build from repo → rig tests → Open Cloud publish | everything testable, full suite, publishing | can't see edits that exist only in Studio |
| **Live Studio via MCP** | edit/playtest in the owner's open Studio (`multi_edit`, `execute_luau`, `start_stop_play`) | fast UI tweaks with real rendering, real clicks, reading another AI's work | owner must Save + publish from Studio; your repo is now stale |
Owner's verdict after trying both: *MCP is better for editing (real Studio, real playtest); the pipeline wins on
tests and publishing.* Combined routine: edit via MCP → owner saves to file (.rbxl) → that file becomes the pipeline
BASE → full tests → publish. **Never publish the pipeline build over Studio-only edits** — it wipes them (and an Open
Cloud place key can't download the live place for you).

## Tools you'll use most (built-in server)
`list_roblox_studios` (get `studio_id`), `get_studio_state`, `execute_luau` (`datamodel_type` Edit | Client | Server),
`start_stop_play`, `get_console_output`, `screen_capture`, `inspect_instance`, `search_game_tree`, `script_read`,
`script_grep`, `multi_edit`, `character_navigation`, `user_mouse_input`, `user_keyboard_input`. Every call takes
`studio_id`.

## Rules that bit us
- **~30 s per call.** Split probes; return one short JSON string (`HttpService:JSONEncode`).
- **Screen captures can be stale** (previous frame / wrong camera). Measure instead: `AbsoluteSize`, `AbsolutePosition`,
  `Visible`, `TextBounds`, world positions. Example: `tools/mcp/probe_ui.luau`.
- **Close menus before clicking or capturing** — a menu left open hides the next thing and swallows clicks.
- **Cameras don't replicate:** set the camera from a Client datamodel; server changes do nothing.
- **Edit datamodel = the owner's working file.** Read freely; write only with the owner's OK; prefer building with Lune
  and publishing so the source of truth stays in the repo. If the owner edits in Studio, pull those edits back
  (export the instance / read attributes) before the next build overwrites them.
- If the bridge is down (403, tunnel gone), continue with the rig and label results "NOT playtested".

## A minimal playtest script (via MCP)
1. `start_stop_play` (start) → wait for `get_studio_state` = playing.
2. `execute_luau` Client: probe UI (sizes on screen, element visible, text height).
3. `execute_luau` Server: read player data / attributes after an action (fire the remote or use `user_mouse_input`).
4. `get_console_output` → grep `error|warn|Stack`.
5. `start_stop_play` (stop). Report what was **Verified** in Studio vs rig-only.
