---
name: roblox-dev
description: Roblox game engineering the owner's way - Studio-editable instances only, Lune .rbxl builds with hooks, fast-lane UI tweaks (build, PC+phone shots, tests, publish), gameplay changes with tests vs base, Open Cloud publishing, Studio MCP checks, honest Verified/Unverified reports. Use for any Roblox, Luau, place file, UI, phone layout, economy, monetization or publishing task.
---

# Roblox dev (project skill)

1. Read `AGENTS.md` at the repo root (rules, loop, decision table, report format) if it is not already in context.
2. Read `QUEUE.md` (what is LIVE, BASE next, HOLD/CLAIM lines) and `PROJECT.md` (owner's rules and decisions).
3. Pick the lane (docs/workflow.md):
   - **Fast lane** (look/value tweak): grep `ui-map.md` → edit the owning hook → `tools/rig/go.sh <name> open=<Menu>`
     → look at `work/rig/out/<name>_pc.png` and `_phone.png` → QUEUE `DONE` line → 3-line report with version.
   - **Gameplay lane**: plan → implement in hooks/src → new test that fails on base → `tools/rig/run_all.sh` base vs new
     + `compare_runs.sh` → shots → publish per rule → QUEUE → report Verified / Automated-only / Unverified.
4. Big batch with disjoint files → delegate to `roblox-implementer` subagents (one file set each), then
   `roblox-verifier`, then one publish (docs/subagents.md).
5. Never: runtime `Instance.new` of visuals, design changes in a phone fix, softening the owner's game design,
   claiming a playtest you didn't run, secrets in files, publishing over Studio-only edits.

Reference docs (open on demand): docs/studio-first-rule.md · build-pipeline-lune.md · testing.md ·
publishing-open-cloud.md · studio-mcp-bridge.md · ui-conventions.md · monetization.md · security.md ·
launch-checklist.md · lessons-learned.md · thinking.md · examples/
