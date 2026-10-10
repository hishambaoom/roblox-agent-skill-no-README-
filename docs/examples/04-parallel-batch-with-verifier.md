# Example 4 — Parallel batch with a verifier, one publish

Based on the reference game's batches (v14–v18 used 3–6 workers; v71 merged three builds a/b/c as one version).

## Owner
> do all of these: toast text gets cut off, King wakes too fast (2.5 s windup, 45 s rage, add a chase loop sound),
> chase music bug + a camera cutaway when he wakes. launch agents and get it published faster

## Agent — split by files (QUEUE line written first)
```
- IN PROGRESS 16:11 Oct 9: v71 = v70 + work/v71a (toast text fit), v71b (King: windup 2.5, rage 45, chase loop),
  v71c (client: chase music fix, wake cutaway + Settings toggle). Merge a,b,c on work/v70.rbxl, then publish.
  Others: don't touch Toast/Alerts/PumpkinKing/Music.
```
| Worker | Owns | Must not touch |
|---|---|---|
| a (toast) | Alerts controller, UITemplates.Toast attrs | King, music |
| b (King) | Systems.PumpkinKing.*, GameSettings King attrs, SFX.ChaseLoop | client UI |
| c (client) | Music handler, WakeCutaway client, Settings row | server King logic |

Each worker gets the brief from docs/subagents.md (base file, owner's exact numbers, its files, "do not publish",
done = test fails on base + passes on its build + STRICT + shots).

## Worker reports (5 lines each, e.g. b)
```
1 files: src/.../PumpkinKing/Boss.lua, build_v71b.luau
2 baked: GameSettings@BossWindupSeconds=2.5 s, @BossRageSeconds=45 s; SoundService.SFX.ChaseLoop (Sound)
3 tests: king_v71b_test FAIL 3 on v70, PASS on v71b
4 shots: n/a (no UI)
5 open: ChaseLoop uses the footstep asset (no growl asset in the place) - owner's call
```

## Merge + verifier
```
$ IN=work/v70.rbxl OUT=work/v71.rbxl tools/lune run work/v71a/build.luau   # then b, then c, each on the previous output
$ tools/rig/run_all.sh work/v70.rbxl logs/run70 ; tools/rig/run_all.sh work/v71.rbxl logs/run71
$ tools/rig/compare_runs.sh logs/run70 logs/run71       # identical set + 3 new tests passing
```
Verifier (didn't write any of it) checklist → `SHIP`, with notes: toast widened 0.5 → 0.6 (the only layout change —
flag to owner), cutaway toggle not saved yet (needs a settings key), ChaseLoop asset placeholder.

## Publish once, log, report
```
- DONE 16:26 Oct 9: LIVE = work/v71.rbxl (v70 + v71a toast fit + v71b King windup 2.5/rage 45/ChaseLoop + v71c chase music fix + WakeCutaway). Suite = v70. BASE next: work/v71.rbxl. Open: cutaway toggle not saved; ChaseLoop uses footstep id; toast widened 0.5->0.6.
```
> Version 120 — rejoin now. Toast text wraps to 2 lines with "…"; King winds up in 2.5 s and rages 45 s with a chase
> loop; chase music fixed; a short camera cutaway when he wakes (toggle in Settings). Not playtested (MCP down).
> Your calls: I widened the toast 0.5 → 0.6 (set Toast width back if you want it compact); the chase loop is a
> footstep sound until you give me a growl ID.

## Rules this shows
Disjoint files, QUEUE claim before starting, fixed merge order on one base, independent verifier, one publish, every
deviation from "exactly what was asked" listed as the owner's call.

## When the owner says stop mid-batch
Real case (Oct 8): six workers running, owner said stop → all cancelled, nothing published, handoff written (what was
half-done, backups, every pending order). Reply: *"Stopped. Nothing half-made went out; v43 is still live and safe."*

---
*Facts (numbers, versions, quotes) come from the reference project's version log and chat; command output is abbreviated and reformatted to the shipped rig's format.*
