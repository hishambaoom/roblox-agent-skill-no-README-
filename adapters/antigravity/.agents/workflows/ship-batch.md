---
description: Gameplay batch - plan disjoint workers, build, test against base, verify independently, publish once, log.
---

1. Read QUEUE.md (BASE next, HOLD, CLAIM) and PROJECT.md decisions. Write a 5-10 line plan: files per part, baked
   instances/attributes, remotes, saved fields + migration, tests. Ask the owner only real decisions, with a default.
2. If parts touch disjoint files, run one agent per part with the worker brief in docs/subagents.md; otherwise do them
   in order yourself. Nobody publishes.
3. Merge in the fixed hook order on BASE; build `work/x/<name>.rbxl`.
4. `tools/rig/run_all.sh <base> logs/base`, `tools/rig/run_all.sh work/x/<name>.rbxl logs/new`,
   `tools/rig/compare_runs.sh logs/base logs/new`. New failures block. Each new test must fail on base.
5. Independent verifier pass (docs/subagents.md checklist), shots of every touched screen.
6. Publish once (`tools/rig/publish.sh`), QUEUE `DONE` line, `tools/rig/retention.sh`.
7. Report: version, what changed, Verified / Automated-only / Unverified, "needs your playtest: 1) 2) 3)", one "your call".

Windows (PowerShell, docs/windows.md): `.\tools\rig\run_all.ps1 <base> logs\base`, `.\tools\rig\run_all.ps1 work\x\<name>.rbxl logs\new`,
`.\tools\rig\compare_runs.ps1 logs\base logs\new`, `.\tools\rig\publish.ps1 <place>`, `.\tools\rig\retention.ps1`.
