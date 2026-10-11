# Juice: making rewards feel good ("make it more dopamine")

Owners ask for this in those words. These patterns shipped and were liked; all pieces are Studio templates with
attributes, scripts only clone and tween them.

## Cash-claimed popup (the most-seen reward)
Template `UITemplates.Juice.CashPopup`, driven by one client handler on a server fx event.
1. **Pop-in with tilt:** scale 0 -> `PopPeak` (1.3) -> 1, rotate +-`TiltDegrees` -> 0, alternate the side on combos.
2. **Count-up:** 0 -> amount with easing, abbreviated (`12.4K`), final text exact.
3. **Shine sweep** across the number (a gradient child tweened left->right).
4. **Glow + flash** behind the number (`CashPopupGlow`, `Flash`).
5. **Spray** of bills / `$` glyphs plus icons that fly to the cash counter.
6. **Sound pitched by amount** (`ClaimChaChing`), second cha-ching on bonuses.
7. **Screen shake only for big amounts** (`ShakeAtAmount`) and only if the player's ScreenShake setting is on.
8. **Counter lands:** `LandPulse` + shine on the money counter when the first icon arrives.

## Collect pad (touch-to-collect)
- Collect on the **centre** only (`CollectRadius` horizontal from the pad top centre), re-checked while standing; one
  collect per visit. A sprinting player crosses the pad between physics steps, so the client does a swept per-pad check
  each Heartbeat and the server allows a speed-based lead (`CollectSpeedLead`, capped). Radius too small = "pads skip
  me"; the owner tuned 1.5 -> 2.3.
- Combo x2..x5 within `ComboWindow`, pitch step per combo, small bonus at x5 (server-side math).
- Rarity-tinted shockwave ring + short PointLight flash, a few world coins, haptics (`HapticService`) per tier.
- A "BIG CASH" banner for collects > 25% of balance felt great at first and got turned off later; ship such extras behind
  a GameSettings boolean (`BigCashBanner=false`) so removing them is a tick, not a rebuild.

## Auto actions should still pay out visibly
Auto-sell / auto-collect that only shows a toast feels like nothing happened. Fire the same "+$" popup the manual action
uses, and keep the toast behind a flag (`AutoSellToast=false`).

## Loot reveal / vault burst
Squash on hit, sparks, random-pitch clang, damage numbers, stage changes at 66% / 33% HP (door glow), final burst
(coins + shake + sound), then a reveal card listing each drop with its income. Strict shared hit cooldown for every input
path (click, tap, tool swing) so juice never becomes an autoclicker exploit.

## Limits
- Popups are the owner's call. Juice an existing popup; do not add a new one unless asked. Keep a removed popup's template
  with `Enabled=false`.
- Dedupe and cap stacks (2 at a time on phones), never cover the thumbstick, jump button or a menu's X.
- The offline rig cannot draw gradients-on-text, glows or images: say "shine/glow not visible in rig shots, check in Studio".
