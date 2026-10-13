---
name: roblox-dev
description: Build, test, screenshot and publish Roblox games the owner can fully edit in Studio. Use for any Roblox/Luau task - UI tweaks, phone layout fixes, gameplay systems, economy, monetization, DataStores, Lune .rbxl builds, Open Cloud publishing, Studio MCP checks, bug sweeps and launch readiness.
license: MIT
metadata:
  version: "1.2"
  origin: "Don't Wake the Pumpkin King and ForgeTax (Roblox), Oct 2026"
---

# Roblox game dev skill

Load `AGENTS.md` (repo root of this skill) first: persona, standing rules, the work loop, decision rules, report format.
Then open only the doc the task needs:

| Task | Read |
|---|---|
| Any change at all | `docs/workflow.md` (fast lane vs gameplay lane, worked examples) |
| Anything visible, any new UI/model/effect | `docs/studio-first-rule.md`, `docs/ui-conventions.md` |
| Building the place file | `docs/build-pipeline-lune.md`, `docs/lune10-gotchas.md` |
| Patching a place with Lune (apply.luau IN/OUT) | `docs/lune10-gotchas.md`, `scripts/apply-template.luau` |
| Writing / running tests | `docs/testing.md` |
| Shipping | `docs/publishing-open-cloud.md` |
| Talking to a live Studio | `docs/studio-mcp-bridge.md` |
| Robux products, passes, prices | `docs/monetization.md` |
| Remotes, data, free models | `docs/security.md` |
| Exploits, bans, suspect flags | `docs/anti-cheat.md` |
| "Is it ready to launch?" | `docs/launch-checklist.md` |
| Weird bug | `docs/lessons-learned.md` |
| Timed / admin events, event rewards | `docs/live-events.md`, `docs/economy-and-events.md` |
| Economy numbers, boss variants, badges wiring | `docs/economy-and-events.md` |
| 3D model previews in UI | `docs/viewport-previews.md` |
| Station focus mode, cameras, held tools, animation bugs | `docs/interaction-patterns.md` |
| Lag, phones, Highlights, streaming, Low Graphics | `docs/performance.md` |
| "Make it feel better / more dopamine" | `docs/juice.md` |
| Models from prompts, AI 3D rigs, sounds | `docs/models-and-audio.md`, `docs/model-prompts.md` |
| Icon, thumbnails, badges, promotion | `docs/marketing-launch.md` |
| Reusable assets and generators | `assets/README.md` |
| Splitting work across agents | `docs/subagents.md`; whole game: `docs/swarm-integration.md` |
| Tidying the place into folders | `docs/organize-and-refcheck.md`, `scripts/organize/` |
| How to reason / talk to the owner | `docs/thinking.md`, `docs/examples/` |
| Setting up a new project | `docs/project-state-template.md` |
| Installing this skill in an agent | `docs/model-setup.md`, `adapters/` |
| Running on Windows (PowerShell, no bash) | `docs/windows.md` |
| Official references | `docs/resources.md` |

Scripts: `tools/rig/*.sh` (go, shot, fast, run_all, compare_runs, publish, prices, retention) + PowerShell twins
`tools/rig/*.ps1` for native Windows (docs/windows.md), `tools/uimap/`,
`tools/mcp/`, `tools/example-game/` (example build.luau, hook, tests, rbxsim), `scripts/` (apply template, organize +
refcheck harness, viewport preview client, swarm contract template; scripts/README.md).

Non-negotiables (full list in AGENTS.md §1): everything visible is a real Studio instance; scripts only clone/show/fill/
tween; tunables are attributes; clone existing UI templates; don't change the design; never claim a playtest you didn't
do; the owner's design decisions are final; no secrets in files.
