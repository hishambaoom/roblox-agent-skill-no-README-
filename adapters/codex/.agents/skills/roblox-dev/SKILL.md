---
name: roblox-dev
description: Roblox game engineering the owner's way - Studio-editable instances only, Lune .rbxl builds with hooks, fast-lane UI tweaks (build, PC+phone shots, tests, publish), gameplay changes with tests vs base, Open Cloud publishing, Studio MCP checks, honest Verified/Unverified reports. Use for any Roblox, Luau, place file, UI, phone layout, economy, monetization or publishing task.
---

# Roblox dev (project skill)

1. Read `AGENTS.md` at the repo root (rules, loop, decision table, report format) if it is not already in context.
2. Check Studio MCP: call `list_roblox_studios` (server `Roblox_Studio`). If it lists the owner's place, the Live
   Studio lane is available; if the tool is missing or returns `[]`, use the rig and label results "NOT playtested".
3. Read `QUEUE.md` (what is LIVE, BASE next, HOLD/CLAIM lines) and `PROJECT.md` (owner's rules and decisions).
4. Pick the lane (docs/workflow.md):
   - **Fast lane** (look/value tweak): grep `ui-map.md` → edit the owning hook → `tools/rig/go.sh <name> open=<Menu>`
     → look at `work/rig/out/<name>_pc.png` and `_phone.png` → QUEUE `DONE` line → 3-line report with version.
   - **Gameplay lane**: plan → implement in hooks/src → new test that fails on base → `tools/rig/run_all.sh` base vs new
     + `compare_runs.sh` → shots → publish per rule → QUEUE → report Verified / Automated-only / Unverified.
   - **Live Studio lane (MCP)** (owner says "use MCP", or Studio is connected): `list_roblox_studios` → pass its
     `studio_id` on every call → read with `search_game_tree` / `inspect_instance` / `script_read` / `script_grep` →
     edit the owner's open place with `multi_edit` (scripts) or `execute_luau` datamodel_type=Edit (instances,
     attributes) → `start_stop_play` + `get_console_output` (+ `character_navigation`, `user_mouse_input`) to playtest →
     measure UI with `execute_luau` (AbsoluteSize/Visible), don't trust `screen_capture` alone. Keep calls under ~30 s,
     return short JSON. The owner Saves + publishes from Studio; never pipeline-publish over MCP edits
     (docs/studio-mcp-bridge.md).
5. Big batch with disjoint files → one session (or git worktree) per worker with the worker brief from
   docs/subagents.md, then an independent verifier pass, then one publish.
6. Never: runtime `Instance.new` of visuals, design changes in a phone fix, softening the owner's game design,
   claiming a playtest you didn't run, secrets in files, publishing over Studio-only edits.

Reference docs (open on demand): docs/studio-first-rule.md · build-pipeline-lune.md · testing.md ·
publishing-open-cloud.md · studio-mcp-bridge.md · ui-conventions.md · monetization.md · security.md ·
launch-checklist.md · lessons-learned.md · thinking.md · examples/

Windows (PowerShell, docs/windows.md): `.\tools\rig\go.ps1 <name> open=<Menu>`, `.\tools\rig\run_all.ps1 <place> <logdir>`,
`.\tools\rig\compare_runs.ps1 <base logs> <new logs>`; env vars as `$env:NOPUBLISH='1'`.
