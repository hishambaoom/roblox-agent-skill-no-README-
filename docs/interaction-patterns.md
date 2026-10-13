# Interaction patterns: focus mode, cameras, held tools, bounce-back bugs

From the second reference game's core loop (smelt -> carry to the anvil -> hit to upgrade, risk shatter -> sell or rack).

## "Forge mode": a focus mode at a station
- `E` on your **own** station's prompt toggles a player attribute (`InForge`); the server owns it. Leave on E again, an
  EXIT button (a clone of the game's red close button), Backspace / gamepad B, death, respawn, disconnect, or walking past
  `MaxDistance`.
- While in the mode the server freezes movement (WalkSpeed / JumpPower / JumpHeight / AutoRotate saved and restored
  exactly) and places the root on a `ForgeStand` part beside the station facing it (`UseForgeStand`). Don't anchor the
  root if a client animates the arm.
- Gate the station's actions on the server (`Hit`, `Sell`, `Rack` refuse unless `InForge`), not only in the UI.
- **Auto-exit** after the cycle ends: the server fires a signal on Sell / Rack / Shatter and leaves after
  `AutoExitDelay 0.6` (`AutoExitShatterDelay 1`) if the station is still empty. Switches: `AutoExitOnSell/OnRack/OnShatter`.
  Players found the manual EXIT step pointless; the tutorial lost a step.
- The tutorial follows the mode: steps only move forward, state-based skip-ahead, arrows hidden while in the mode.

## Focus camera (client only)
- Bind to RenderStep at Camera priority: base CFrame at `Camera`, additive kicks at `Camera+1..3` (shake, hit push), so
  several effects stack without accumulating. Write FOV only if nobody else changed it since your last write.
- 3/4 view: `TopViewDistance 28`, `TopViewPitch 60`, `TopViewYaw 35` (toward the tool side), `TopViewScreenLift 4`, glide
  in/out 0.35 s, `HitFovPunch 3` per hit. Force `LocalTransparencyModifier = 0` so the character stays visible up close.
- Restore `CameraType = Custom`, FOV and any disabled DepthOfField on every exit path: death, CharacterRemoving,
  CurrentCamera swap, script disabled, errors, plus a watchdog.
- Build rotations with `CFrame.fromMatrix` in Lune (its `lookAt` is wrong); check camera feel in Studio, the sim can't.

## Held tool without a Tool (no hotbar)
- Weld the model to `RightHand` / `Right Arm` with a `Motor6D` at `Handle.GripAttachment`; no `Tool` means no hotbar slot.
  Click/tap near your station hits (`ClickToHit`, `ClickHitRange`).
- Fix the model first: `PrimaryPart = Handle`, pivot at the grip, classic `Weld`s with explicit `C0` (Lune-written
  WeldConstraints snap parts to the centre), parts unanchored + Massless + no collide/touch/query, size baked (no runtime
  `ScaleTo`).
- Animate with `Motor6D.Transform` in `RunService.Stepped` (runs after the Animator; RenderStepped gets overwritten):
  windup 0.05-0.10 s -> slam 0.08 s -> recoil 0.12 s -> return 0.18 s; a new hit restarts from the current pose. Every
  angle and time is an attribute. Sync the impact flash / "+N" popup to the slam landing (`WindupTime`).

## The bounce-back bug (store a RestPivot)
Symptom: after the first hit the sword sank into the anvil face; only the hilt showed. Cause: the display script lifted
the sword above the face, then the hit "bounce" tween returned it to the **raw** anchor pivot, undoing the lift.
Fix: whoever places an object stores its resting pivot (`Model@RestPivot`); every tween/bounce returns there. General
rule: never tween back to a template/anchor CFrame when another script may have adjusted the live one.

Found with it: a function called before its `local function` definition (nil call on every ChildAdded, silently in a
connection), and an Fx event that reached clients before the server built the object (Deferred signals -> `task.defer`
the fire). Reproduce on the pre- and post-organize file before blaming the organizer.

## Reveal moments
Reuse one nameplate template (`BillboardGui`: "Gold · COMMON", "Tier 5/15 · $50", "+0") and a rarity Highlight; pop it on
landing and on every rarity change, bigger from a tier threshold, a flash only for top rarities (`RevealBigFromTier`,
`RevealFlashFromTier`). Anvil hit sounds: 3 variants with pitch 0.95-1.08 and a heavy hit every 5th level.
