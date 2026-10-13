# Splitting work across parallel agents (with a verifier)

> Building a whole new game with many agents? See `docs/swarm-integration.md` (contract of shared names, serial
> integration chain, organize last) and `scripts/swarm/CONTRACT.template.md`.

Parallel agents are how big batches ship in an hour instead of a day — and how builds get silently undone. These rules
are what made it work on the reference game (batches of 2–6 workers, one verifier, one publish).

## When to split
- Split: ≥ 2 independent parts that touch **disjoint files** (e.g. inventory UI / store cards / shield pad / loot labels).
- Don't split: a one-value tweak (do it yourself — handoff costs more than the edit), or parts that edit the same
  script/template.
- Read-only work (audits, research, sims) parallelizes freely.

## The plan you write before dispatching
```
Batch v18 (base: work/x/v17.rbxl, LIVE version 43)
Workers (one hook file each, nobody edits build.luau):
  STEAL   → build_v18_steal.luau  + src/.../StolenCarry.lua, MonetizationHandler.lua
  FIXES   → build_v18_fixes.luau  (anchor patches: GiftingClient, WalkingSoundsClient)
  KING    → build_v18_king.luau   + src/.../PumpkinKing/*
  JUICE   → build_v18_juice.luau  + UITemplates.Juice.*
  VISUALS → build_v18_visuals.luau + Assets.LootBlink, Assets.LootDisplay
Hook order in build.luau: steal → fixes → king → juice → systems → visuals → text → organize(LAST)
Cross-file needs: write work/v18/patches/<from>-to-<owner>.md, never edit another worker's file.
Each worker: test for its area (fails on base, passes on its build), STRICT guard, rig shots of touched screens.
Nobody publishes. Verifier → full suite → ONE publish.
```

## Worker brief template (give each worker everything; it can't see your chat)
```
You own ONLY: <files>. Do not edit anything else. Base: <file>. Output build: BUILD_OUT=work/x/<scope>.rbxl.
Task: <owner's words + exact numbers + decisions with dates>.
Rules: AGENTS.md §1 (Studio-first, attributes for tunables, clone templates, don't change the design).
Done = 1) hook idempotent, one ctx.note line 2) <scope>_test.luau FAILS on base, PASSES on yours 3) STRICT guard passes
4) shots PC+phone of <screens> 5) a 5-line report: files, instances/attributes baked, tests, shots, open questions.
Do NOT publish. If you need a change in a file you don't own: write work/<batch>/patches/<you>-to-<owner>.md
(file + anchor, exact replacement, Studio paths it relies on, how to test).
```

## Patch notes between workers
`work/<batch>/patches/G-to-D.md`: file + function/line anchor · exact replacement or diff · Studio paths/attributes and
which hook creates them · how to test. One file per pair; append under `## <time>`. The owner of the file applies it and
writes `APPLIED <time>`. The verifier checks every note is APPLIED.

## The verifier (separate agent, didn't write the code)
Checklist:
1. Merge in the fixed order on the stated base; clean build; build log has every hook's note.
2. Full suite on base and merged → `compare_runs.sh`. New failures = blockers. Each worker's new test passes.
3. STRICT guard: no new runtime creation; no style writes added.
4. Every owner request in the batch ticked: done / missing / broken (with evidence).
5. Every screen touched: rig shots at phone/tablet/PC sizes; compare look against the reference template (fail
   anything off-style).
6. Code scan for leftovers: debug prints, `wait()` loops, TODOs, unthrottled remotes, Instance-keyed weak tables.
7. Real playtest via MCP if available (console errors, one pass through each feature).
8. Verdict: SHIP / FIX FIRST (list). Fixers can run in parallel on the verifier's list, then re-verify the delta.

## Merging and publishing
- One publish per batch. Record: `DONE … = v17 + v18{steal,fixes,king,juice,visuals}`.
- Late worker? Ship without it only if its files are untouched by the batch; otherwise next batch.
- Owner says "stop": cancel all workers, publish nothing, write a handoff (what's half-done, which scratch files exist,
  every pending order) so the next session resumes cleanly. Confirm "nothing half-made went out; LIVE is still vX".

## In specific agents
- **Claude Code:** project subagents in `.claude/agents/` (see `adapters/claude-code/.claude/agents/`:
  `roblox-implementer`, `roblox-verifier`, `roblox-ui-fixer`). Main session plans and merges; verifier has no Edit tool.
- **Codex CLI / OpenCode / Antigravity / Cursor:** run separate sessions (or git worktrees) per worker with the worker
  brief above; the main session merges. Worktrees keep scratch builds from colliding.
- **Chat-only model:** do the parts sequentially yourself in the same order; still do the verifier checklist yourself
  before saying "ready".
