# Example 2 — A bug that needed three tries (and what the third did differently)

Real sequence from the reference game, Oct 9–10. The lesson is in the contrast.

## Try 1 (version 141) — fixed a real but different bug
Owner: upper-floor pedestals don't work. Agent found prompt anchors left on floor 1 (prompts stacked), re-anchored
slots 9–24 on their own floors. Real fix — but it wasn't the owner's whole problem.

## Try 2 (version 142) — fixed another real bug
Owner: now my floor-1 pedestals are gone. Cause: since the map-models update, pedestals were drawn only by a Lune-placed
mesh that **doesn't render in game**. Agent re-enabled the original studded pedestal parts and hid the mesh
(`Pedestal.Visual`). Lesson recorded: Lune-placed MeshParts may not render; keep primitives visible until seen in Studio.

## Try 3 (version 144) — the root cause
Owner: upper-floor pedestals invisible after unlocking and **upgrades do nothing**.

Agent's reasoning, written down before touching code:
1. *Upgrades dead + invisible* = the same parts are both transparent and non-queryable → something hid them and never
   restored them.
2. Who hides? `Plot.HideInst` on locked floors; `ShowInst` on unlock.
3. Where are originals kept?
   ```lua
   local hiddenProps = setmetatable({}, { __mode = "k" })   -- keyed by Instance, weak keys
   ```
4. Why tests pass: the Lune simulator never garbage-collects those keys. On Roblox, Instance keys in a weak table can be
   collected while the part still exists → `ShowInst` finds nothing → Transparency 1, CanQuery false → SurfaceGui
   upgrade buttons on a CanQuery=false part can't be clicked.

Fix (anchor patch on the live file, asserted):
```lua
local a = src:find("local hiddenProps = setmetatable", 1, true); assert(a, "anchor hiddenProps")
local b = src:find("local function SetSlotShown", 1, true);      assert(b and b > a, "anchor SetSlotShown")
-- replace HideInst/ShowInst: originals stored as attributes FloorHid_T / _CC / _CT / _CQ / _E on the instance
...
assert(not src:find("hiddenProps", 1, true), "leftover hiddenProps")
```
Build: `IN=work/v93.rbxl OUT=work/v94a/out.rbxl tools/lune run work/v94a/build.luau` → merged with the pending polish
patch → full suite identical to base → published as version 144.

Report to owner:
> Found it, and my last fix missed it, my mistake. Version 144 is live, so rejoin now. The pedestals hid fine on
> locked floors, but on unlock the game forgot their original look, so they stayed invisible and unclickable, which is
> also why upgrading did nothing. The original look is now stored on each part, so it can't be lost.

Next morning sweep: owner confirmed in-game (13:40) — own-base pedestals visible, upgrades work → only now marked
**RESOLVED** in QUEUE (`NOTE 13:45 Oct 10: pedestal bug RESOLVED (user confirmed in-game)`).

## What made try 3 work
- Explained the **mechanism** that produces *both* symptoms instead of patching the visible one.
- Asked "why do tests pass?" — the gap between simulator and engine pointed straight at GC.
- The fix also made the state visible in Studio (attributes), in line with the TOP RULE.
- Owned the earlier miss in one sentence; didn't call it resolved until the owner saw it.
- Added the lesson to lessons-learned + the verifier's code scan (`__mode` with Instance keys).
