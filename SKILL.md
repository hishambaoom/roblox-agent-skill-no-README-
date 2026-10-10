---
name: roblox-dev
description: Build, test, screenshot and publish Roblox games the owner can fully edit in Studio. Use for any Roblox/Luau task - UI tweaks, phone layout fixes, gameplay systems, economy, monetization, DataStores, Lune .rbxl builds, Open Cloud publishing, Studio MCP checks, bug sweeps and launch readiness.
license: MIT
metadata:
  version: "1.0"
  origin: "Don't Wake the Pumpkin King (Roblox), Oct 2026"
---

# Roblox game dev skill

Load `AGENTS.md` (repo root of this skill) first: persona, standing rules, the work loop, decision rules, report format.
Then open only the doc the task needs:

| Task | Read |
|---|---|
| Any change at all | `docs/workflow.md` (fast lane vs gameplay lane, worked examples) |
| Anything visible, any new UI/model/effect | `docs/studio-first-rule.md`, `docs/ui-conventions.md` |
| Building the place file | `docs/build-pipeline-lune.md` |
| Writing / running tests | `docs/testing.md` |
| Shipping | `docs/publishing-open-cloud.md` |
| Talking to a live Studio | `docs/studio-mcp-bridge.md` |
| Robux products, passes, prices | `docs/monetization.md` |
| Remotes, data, free models | `docs/security.md` |
| "Is it ready to launch?" | `docs/launch-checklist.md` |
| Weird bug | `docs/lessons-learned.md` |
| Splitting work across agents | `docs/subagents.md` |
| How to reason / talk to the owner | `docs/thinking.md`, `docs/examples/` |
| Setting up a new project | `docs/project-state-template.md` |
| Installing this skill in an agent | `docs/model-setup.md`, `adapters/` |
| Official references | `docs/resources.md` |

Scripts: `tools/rig/*.sh` (go, shot, fast, run_all, compare_runs, publish, prices, retention), `tools/uimap/`,
`tools/mcp/`, `tools/example-game/` (example build.luau, hook, tests, rbxsim).

Non-negotiables (full list in AGENTS.md §1): everything visible is a real Studio instance; scripts only clone/show/fill/
tween; tunables are attributes; clone existing UI templates; don't change the design; never claim a playtest you didn't
do; the owner's design decisions are final; no secrets in files.
