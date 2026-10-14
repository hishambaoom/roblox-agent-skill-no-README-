# Importing the owner's models (.rbxm) into a live game

From ForgeTax v24: 8 new hammers/furnaces from one owner `.rbxm`, patched into the live place with Lune, idempotent.
Rule zero: **follow the game's existing structure**, not the spec's wording (spec said "Tool"; hammers in this game are
plain models welded into the hand, so they stayed models).

## Pipeline (one apply.luau, IN place + UPLOAD rbxm -> OUT place)
1. **Inspect first** (read-only dump): names, classes, Anchored, welds, attachments, sizes, colours. Keep MeshParts +
   SurfaceAppearances exactly as delivered.
2. **Tag what you import** (`@V24` on each model) and rebuild it from the upload on every run; script patches use
   `[v24]` markers -> a re-run skips everything (see `lune10-gotchas.md`).
3. **Fix, don't redesign**, and keep the old value in an attribute so it's reversible:
   - White Neon `Glow_*` parts -> recolour from the model's own emitter colours, old colour in `@V24OldColor`.
   - Missing anchors/pivots -> add `GripAttachment` (at the owner's `GripPoint`) and `ModelOrigin` (bottom/base centre).
4. **One model, three copies**, each built for its job:
   | Copy | Where | Physics |
   |---|---|---|
   | Held | ServerStorage (cloned into the hand) | unanchored, classic `Weld` Handle->part (C0 from the owner's layout), `GripAttachment`, PrimaryPart = Handle |
   | Display / pedestal | ReplicatedStorage assets | anchored, pivot on `ModelOrigin` |
   | Preview (ViewportFrame) | Previews folder | anchored, **no FX** (particles/lights don't render in viewports) |
   Owner models often arrive all-anchored with WeldConstraints: fine for display, wrong for held copies.
5. **Scale against the existing family** (measure the current tier's held/display size, apply the same ratio; limited
   items may be bigger on purpose). Test-check bounding boxes: inside every plot, clear of neighbours.
6. **Rigs for stations** (furnace example): clone the previous level's FX rig, drop parts that don't fit, move emitters
   to the owner's markers (`FirePoint`, `SmokePoint`), output attachment at `BlankPoint`, recolour.
7. **Moving decorative parts** (wings, horns, rings) -> `CanCollide=false` (and CanQuery/CanTouch off if unused).

## Motion without scripts building anything
One LocalScript (e.g. `ForgeModelAnim`) reads per-part attributes: `Anim_Spin`, `Anim_Swing`, `Anim_SwingOffset`,
`Anim_Pivot`, `Anim_Bob`, `Anim_Pulse`, `Anim_Flicker`, model `AnimEnabled/AnimSpeed/FxScale`.
- Held copy: animate `Weld.C0` from its rest value. Anchored copies: set CFrame from Handle/ModelOrigin.
- Script attrs: `Enabled`, `MaxDistance` (140), `UpdateHz` (30), `PauseOnLow` -> Graphics Low = parked at rest.
- No `Instance.new`; the owner tunes everything in Studio.

## Data and saves
- New tiers go in Config (price, multiplier, perk) - data-driven UI cards pick them up; remove hard clamps (`1..6`).
- Inserting a tier mid-ladder breaks saved indexes: save the **model name**, and migrate old saves through a
  `LegacyOrder` table (old index 5 = Dragon -> new index 6). Test with an old save.

## Checklist
- [ ] dump inspected, owner's names kept  - [ ] held/display/preview copies correct  - [ ] old colours stored
- [ ] fits every plot (test)  - [ ] moving parts non-colliding  - [ ] Low graphics pauses motion
- [ ] save migration tested  - [ ] re-run idempotent  - [ ] list what is Studio-unverified (look, grip in a real swing)
