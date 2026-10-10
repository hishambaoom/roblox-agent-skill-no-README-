# Workflow: fast lane vs gameplay lane

Every change follows the same loop; the lane decides how heavy each step is.

```
read state ─▶ plan ─▶ smallest change ─▶ build ─▶ test ─▶ screenshot ─▶ publish ─▶ log ─▶ report
   QUEUE.md    1-3 lines   one hook/file    ~2 s     fast/full   PC+phone   Open Cloud  DONE line  3-6 lines
```

## Two numbers, don't mix them
- **Build label** (`v76`, `v94a`, `v144` sweep file names): your internal name for a build/patch dir, in QUEUE.md.
- **Roblox versionNumber** (from the publish response, e.g. 144): what the owner sees and what you put in reports
  ("Version 144 is live, so rejoin now"). Always read it from the API response — a retried upload can skip numbers
  (it happened: 8 → 10). Old servers keep the previous version until players rejoin.

## Why the rig exists (real history)
Small tweaks used to take 10+ minutes because every helper agent wrote its own screenshot/test tool (~20 copies).
One shared rig fixed it: shots ~1 s, fast tests ~2.5 s, full suite ~24 s, one command build→shots→tests→publish ~13 s.
Reuse it; never rebuild tooling for a tweak.

## Choosing the lane

| Signal in the request | Lane |
|---|---|
| "make X smaller / bigger / move it / it overlaps on phone / text too small / change the label" | FAST |
| A single attribute value the owner names ("cooldown 30 s", "prompt 7 studs high") | FAST (value only) |
| Anything that changes what the server decides, what is saved, what costs Robux, what players can exploit | GAMEPLAY |
| New system, new remote, new saved field, new product | GAMEPLAY |
| "Bug: X doesn't work" | Start GAMEPLAY (root-cause first), drop to FAST if the fix is one value |

When unsure, treat it as GAMEPLAY. Slower is recoverable, a broken save is not.

---

## FAST lane (tiny UI tweaks) — target 1–3 minutes

1. `grep -n "<Element>" ui-map.md` → exact instance path + current values + which hook bakes it.
2. Edit **only** that hook (or the attribute it seeds). Keep the look.
3. `tools/rig/go.sh v<N> open=<MenuName>` — builds (~2 s), renders PC 1920×1080 + phone 667×375 (~1–2 s),
   runs STRICT guard + text-size tests (~3 s), publishes **only if tests pass**, refreshes ui-map in background.
   Use `NOPUBLISH=1` when the owner wants to look first.
4. Open both PNGs. Check: element where intended, nothing overlapping, text ≥ 12 px, nothing off-screen.
5. Append `DONE` line to QUEUE.md. Report version + change + shots.

Rules: never write a new renderer or one-off harness for a fast tweak; never "improve" neighbours; never change colours/
fonts/art in a phone fix.

### Worked example — playtime gift icon too big (real, v76)

Owner: *"the gift icon on the right is too big, same as the other cards"*

```
$ grep -n "PlaytimeGift" ui-map.md
212:- `RightSide.PlaytimeGift` [ImageButton] — gift card (clone of SleepOffer, LayoutOrder 0) · …
213:  - `RightSide.PlaytimeGift.GiftIcon` [ImageLabel] img 1234… · size 0,56,0,56
```
Plan (said to self, not to owner): *GiftIcon 56→40 px in build_v75b hook; same as SleepOffer icon; no other change.*

```lua
-- games/<game>/build_v75b_gift.luau  (the hook that bakes RightSide.PlaytimeGift)
local icon = card:FindFirstChild("GiftIcon")
icon.Size = UDim2.fromOffset(40, 40)          -- was 56: match SleepOffer.Icon (owner 20:00)
ctx.note("v76: PlaytimeGift.GiftIcon 56 -> 40 px")
```
```
$ tools/rig/go.sh v76
fast PASS: 3 pass / 0 fail | studio_rule_test:ok text_size_test:ok example_feature_test:ok  (2.9 s)
shots: work/rig/out/v76_pc.png work/rig/out/v76_phone.png   <- LOOK at both before reporting
published (Published) versionNumber=<N>
total 13 s
```
QUEUE line:
```
- DONE 20:00 Oct 9: LIVE = work/x/v76.rbxl (version <N>) = v75 + build_v75b (RightSide.PlaytimeGift.GiftIcon 56→40 px). BASE next: work/x/v76.rbxl.
```
Report:
```
Version <N> is live, so rejoin now. The gift icon is 40 px, same as the other cards.
[v76_pc.png] [v76_phone.png]
Verified: build + fast tests + rig shots. Not checked on a real phone.
```

### Worked example — prompt height (value-only fast lane)

Owner: *"cauldron prompt is way too high, put it at like 7 studs"* → one attribute/position in one hook, test asserts
`PromptAttachment.WorldPosition.Y - floorY == 7`, ship. If two agents raced on the same value (it happened: one wrote
6.5, one 5, one 7), the **QUEUE.md** line decides what is live; never rebuild from a scratch dir another run overwrote.

---

## GAMEPLAY lane — logic, economy, data, remotes

1. **Read** QUEUE (BASE next, HOLDs, claims), PROJECT.md decisions, the systems involved.
2. **Root-cause first** for bugs (below). For features, write a 5–10 line plan: files, instances/attributes baked,
   remotes, saved fields (+migration), tests. Ask the owner only for real decisions (numbers, design), with a default.
3. **Implement** in build hooks + `src/`. Seed every tunable as an attribute. Bake every visual.
4. **Test:**
   - New test for the new behaviour that **FAILS on the base build and PASSES on the new build** (proves it tests the change).
   - `tools/rig/run_all.sh work/x/base.rbxl logs/base` and on the new build → `tools/rig/compare_runs.sh logs/base logs/new`.
     Same pass/fail set + your new test = good. Any new failure is yours.
   - STRICT guard (studio rule) must pass.
5. **Shots** of every screen touched, PC + phone.
6. **Publish** (standing rule or owner's go) → **log** → **report** with Verified / Automated-only / Unverified and
   "needs your playtest: 1) … 2) … 3) …".
7. If the change is big, split it (docs/subagents.md): disjoint files, fixed merge order, one verifier.

### Rebasing (the #1 multi-agent failure)
Two builds started from the same base each undo the other when published. Rule:
- Every build records its base in QUEUE (`= v67w + patch dir`).
- Before publishing, if BASE next moved, **re-apply your patch on the new BASE** and re-test. Write
  "MUST be rebased onto X" on any build that is now stale.
- Patches are written as **anchor patches** (find exact text once → replace; assert if missing or found twice) so they
  re-apply cleanly on a newer base.

---

## Root-cause walkthrough — the invisible pedestal bug (real, v144)

**Symptom (owner):** after unlocking floor 2, upper-floor pedestals are invisible and their upgrade buttons don't click.
Tests: all green. Rig: fine.

1. **Reproduce the mechanism, not the symptom.** Floors hide with `Plot.HideInst(d)` and reveal with `ShowInst(d)`.
   HideInst saved each part's original Transparency/CanCollide/CanQuery so ShowInst could restore them.
2. **Read the storage:**
   ```lua
   local hiddenProps = setmetatable({}, { __mode = "k" })   -- weak keys, keyed by Instance
   ```
3. **Why tests pass but live fails:** in Roblox, an Instance used as a table key is a userdata reference that the Lua GC
   may collect from a weak table even though the part still exists in the DataModel. ShowInst then finds no saved props
   → parts stay `Transparency = 1, CanQuery = false`. A SurfaceGui on a `CanQuery = false` adornee can't be clicked →
   "upgrades dead". The Lune simulator never runs that GC → tests can't see it.
4. **Fix (Studio-first and GC-proof):** store the originals **as attributes on the instance itself**:
   ```lua
   local function HideInst(d)
       if d:GetAttribute("FloorHid") then return end
       if d:IsA("BasePart") then
           d:SetAttribute("FloorHid_T", d.Transparency); d:SetAttribute("FloorHid_CQ", d.CanQuery)
           d:SetAttribute("FloorHid_CC", d.CanCollide); d:SetAttribute("FloorHid_CT", d.CanTouch)
           d.Transparency = 1; d.CanQuery = false; d.CanCollide = false; d.CanTouch = false
       elseif d:IsA("ProximityPrompt") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
           d:SetAttribute("FloorHid_E", d.Enabled); d.Enabled = false
       else return end
       d:SetAttribute("FloorHid", true)
   end
   ```
   ShowInst reads them back and clears them. Bonus: the owner can see the hidden state in the Attributes panel.
5. **Prove it:** the patch asserts the old `hiddenProps` is gone (`assert(not src:find("hiddenProps"))`), a test
   hides/shows a floor and checks every part's restored values, and the owner confirmed in-game ("own-base pedestals
   visible + upgrades work"). Only then was it marked **RESOLVED**.
6. **Generalize:** added to lessons-learned + a guard grep for `__mode` on Instance-keyed tables.

Pattern to copy: *symptom → mechanism → storage → why the sim differs → fix that also makes state visible in Studio →
test that would have failed → owner confirmation before "resolved".*

---

## Bug sweep (no change requested, "check everything")
1. `run_all.sh` on LIVE and on the previous LIVE → compare. Identical set = no regression.
2. For each failure: stale assertion (owner changed design later) vs real. Prove "stale" with the QUEUE decision line.
3. Report real nits as "your call" (e.g. *SaleBadge 11 px < 12 px min on two cards — not changed (design rule)*).
4. Publish nothing unless asked. Write the sweep to `work/sweep-<version>.md`.
