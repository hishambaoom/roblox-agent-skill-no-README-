# Using a VFX pack (and its limits)

From ForgeTax vfx24 (plan) + v25 (build): top-tier idle/swing/hit FX for three hammers from the owner's VFX pack.

## Rules
- **Real saved instances only**: ParticleEmitter, Beam, Trail, Attachment, PointLight in the place, editable in Studio.
  Scripts only **toggle / :Emit / tween**. No `Instance.new`, no FX built at runtime (`studio-first-rule.md`).
- **Pack first**: clone the pack emitter, scale it down, recolour. Web textures only for what the pack lacks.
  Tag each clone (`@SrcPack` = source path, `@PlanId` = plan row) and clear the pack's own attributes.
- **Never use assets the owner excludes.** Assert it in apply and make a test scan the whole place for them.
- Plan before building: a table per item (idle / swing / hit) with source emitter, texture, key values and budget;
  owner approves; then build exactly that.

## Placement
- Point FX in Attachments (e.g. `ForgeEffects*`). Attachment emitters fire along +Y: rotate a hit attachment so +Y
  points back out of the struck face, and VelocityPerpendicular rings lie flat on the surface.
- **Box/Sphere/Cylinder emitter shapes only work with a BasePart parent** -> shaped emitters sit on the glow MeshPart.
- Every Beam needs a texture (untextured Beams render as flat boxes). Two curved Beams (RingA->RingB, B->A) with
  scrolling texture = an animated ring around a mesh.
- Copies: held = idle + swing + hit (sizes/speeds baked x held scale); display = idle only; **ViewportFrame previews
  get nothing** (particles and lights don't render there).

## Budgets (per item, enforced by a test that counts Rate x Lifetime)
| | Desktop | Graphics Low |
|---|---|---|
| Idle live particles | <= 32 | ~12 |
| Hit burst | <= 30 | ~12 |
| Swing | <= 2 trails + 18 particles | 1 trail + 6 |
- Low: continuous Rate x0.35, bursts x0.4, `@LowHide` on extra beams/trails/emitters, `@HighOnly` flipbook rings with
  `@LowOnly` single-texture twins (old phones may drop flipbooks).
- Settings toggle "Others' hit FX" gates other players' bursts.

## Studio tunables (model attributes)
`EffectScale` (sizes, speeds, beam widths, light range; live), `IdleRateMult` (continuous rates; live), `HitBurstMult`
(burst counts), per-burst counts as attrs (`ShardBurst 10`...), `TrailLinger`. Lights: `@FlashTime`, `@Peak`.

## Risks
- **Texture ownership**: pack/web textures belong to other creators; if one is moderated the emitter goes blank.
  Verify each ID is an Image (AssetTypeId 1, not a Decal) and consider re-uploading used images to the owner's account.
- Delete placeholder default-texture Sparkles that came with the models.
- Mock stills are not Studio: report the real look, brightness and phone perf as unverified.
