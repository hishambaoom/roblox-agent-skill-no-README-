# Project state files (templates)

Three small files make any agent able to continue the work. Keep them at the game repo root.

## 1. `QUEUE.md` — the version log (append-only, newest at the bottom)

Line types:
```
- DONE <time>: LIVE = <file> (version <N>) = <base> + <patch/hook>. <what changed, with numbers>. Tests: <result vs base>. <NOT playtested | playtested how>. BASE next: <file>.
- BUILT <time> (NOT published): <file> = <base> + <patch>. <why not published>.
- IN PROGRESS <time> (<who>): <scope> → <patch dir> on <base>. Others: do NOT touch <files/systems>.
- CLAIM <time>: <patch dir> = <scope> by <who>. Apply order on <base>: <a> then <b>. Don't duplicate.
- HOLD <time>: no <kind of change> until the owner approves <plan>.
- DECIDED <time> (owner): <decision, exact numbers>.
- NOTE <time>: <fact a future agent must know, e.g. a parallel run overwrote X>.
- PLAN <time> (awaiting OK): <plan summary>.
```
Real examples:
```
- DONE 13:10 Oct 9: v62 (version 105) = v61 + 'You escaped with…' banner removed (gated by Config.GameSettings@ShowEscapeBanner=false). His rule: NO safe popup at all. BASE next: work/v62.rbxl.
- 14:55 Oct 9 HOLD: no popup/toast/banner/announcement edits until the owner approves a popup plan.
- DECIDED 15:08 Oct 9 (owner): per-loot $/s labels do NOT include the rebirth multiplier. Leave them.
- NOTE 23:44 Oct 10: a parallel run overwrote v88a/build.luau with a near-identical patch (5 studs). LIVE stays v88 (6.5 studs). Don't rebuild v88 from v88a.
- DONE 01:13 Oct 10: LIVE = work/v94.rbxl = v93 + v94a (ROOT CAUSE upper-floor pedestals invisible: weak Instance-keyed table GC'd → originals now attributes FloorHid_*) + v93b POLISH. BASE next: work/v94.rbxl.
```
Rules: one line per event; always name the base; always end a DONE with `BASE next`; "MUST be rebased onto X" when a
parallel build is stale; retention keeps newest + 3 older builds and never the LIVE file.

## 2. `PROJECT.md` — the project brief
```markdown
# <Game name> — project brief
Universe <id> · place <id> · owner: <name/handle> · LIVE: version <N> (see QUEUE.md)

## Owner's standing rules (verbatim + date)
- 2026-10-07: "I WANNA BE ABLE TO CHANGE AND EDIT ANYTHING I WANT" → everything visible is a Studio instance.
- 2026-10-08: "DON'T CHANGE THE DESIGN" (phone fixes = fit only).
- Fast-lane tweaks publish automatically after tests pass; report version + change + screenshots.
- Public posts / ads / prices need approval of the exact text/number.

## Game in 5 lines
Core loop · economy · progression · monetization · audience.

## Decisions (date — decision — why)
- 2026-10-09 — victim leaves mid-carry: thief keeps loot — anti-abuse.

## Open questions (owner's call)
- Crow ambience has no SoundId — needs an ID.

## Where things are
Build: games/<game>/build.luau · hooks · tests · rig: tools/rig · ui-map.md · Config: ReplicatedStorage.Config.*
Publishing: Open Cloud key in env ROBLOX_API_KEY (scope universe-places:write) · Studio MCP: tunnel link from owner per session.
```

## 3. `ui-map.md` — generated
Never hand-edit. `python3 tools/uimap/uimap_build.py <place>` (format in docs/ui-conventions.md).

## Optional
- `work/sweep-<version>.md` bug sweeps · `work/launch-readiness.md` · `work/perf-audit-<v>.md` (read-only audits).
- `work/<vN>/patches/<from>-to-<owner>.md` patch notes between parallel agents (docs/subagents.md).
- A README ModuleScript inside the place for the owner.
