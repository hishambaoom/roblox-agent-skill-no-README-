# Organize LAST, prove it changed nothing: refcheck + reverse + test_chain

Owners want a tidy place they can navigate in Studio (folders, a README they can read inside Studio). Moving instances
breaks every script path that pointed at the old spot. This pattern moves things safely and proves it.

Scripts: `scripts/organize/` (`refcheck.luau`, `check.luau`, `reverse.luau`, `test_chain.sh`).

## 1. Organize runs last, every build
The organize pass is the final step of every integration chain. Agents keep coding against the old (pre-organize) paths,
so their tests keep working, and the organize map is the only place that knows the new layout. Add new scripts to the map
when they appear (`ForgeVFX2 = "VFX"`).

## 2. Transactional move groups + static reference check
`refcheck.luau` scans every script's source (comments stripped) and resolves each lookup chain that starts at a known
Instance: `game`, `workspace`, `script`, `game:GetService("X")`, or a local assigned from one of those. Each step
(`.Name`, `:WaitForChild("Name")`, `:FindFirstChild("Name"[, true])`) is recorded `ok` or `MISSING`. Player containers map
to their Starter templates (`PlayerGui -> StarterGui`, `PlayerScripts -> StarterPlayerScripts`).

The organizer moves things in **groups**. After each group it re-scans; if any lookup that resolved before now fails, the
whole group is undone and listed under "Left in place". It never deletes anything. Every moved instance gets attributes
`OrganizedFrom` (old full path), `OrganizedFromParent`, `OrganizedFromName`.

```bash
IN=<organized.rbxl> BEFORE=<pre-organize.rbxl> tools/lune10 run scripts/organize/check.luau
# -> refs=N unresolved=M (hard wait/dot=H, soft FindFirstChild=S); regressions vs BEFORE: 0   (exit 1 if any)
```
`FindFirstChild` misses are "soft" (code usually handles nil); `WaitForChild`/dot misses are "hard".

## 3. reverse.luau: run old tests unchanged
`reverse.luau` rebuilds the pre-organize layout from an organized file using the `OrganizedFrom*` attributes, reverses
rename rewrites in sources, and removes what organize created (README modules, empty folders). Test helper only: never
publish its output.

## 4. test_chain.sh: the regression harness
For each agent test it runs three times: on the original place (baseline), on `reverse(organize(place))` (proves organize
changed nothing but paths) and directly on `organize(place)` (shows which tests hard-code old paths).
```bash
bash scripts/organize/test_chain.sh work/int5/s_fix5.rbxl v5a "core:SELF fx plots:SELF racks ui anvil:SELF forgemode"
# v5a refcheck: regressions vs BEFORE: 0
# v5a core: baseline=0 reversed=0 direct-on-organized=0  OK
# v5a ui:   baseline=1 reversed=1 direct-on-organized=1  OK          (known pre-existing fail)
```
`agent:SELF` = the test reads the place under test from `IN`; `agent:<path>` = test compares against that input file.
Verdict `REGRESSION` = passed on baseline, fails after reverse(organize). That is a real bug in the organizer.

## 5. In-Studio README
Organize writes a `README` ModuleScript (in ReplicatedStorage, copy in ServerStorage) describing every folder, system and
tunable in plain words, and a matching `README.md` for the repo. Regenerate it in the same pass so it never drifts.
Keep a copy of the previous README per version (`README.v5.md`) so the owner can see what changed.

## Limits
- The checker is static. Dynamic names (`folder:FindFirstChild(kind .. "Panel")`) are not resolved; keep those targets
  out of move groups or add them to a never-move list.
- `game:GetService` on a missing service adds it to the saved place. The checker uses `FindFirstChildOfClass` instead.
