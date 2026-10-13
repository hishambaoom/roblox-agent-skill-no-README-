# Economy and events that keep up with progression

Lessons from tuning two tycoon-style games live. Event mechanics are in `docs/live-events.md`; this file is about the
numbers and the patterns around them. The owner's numbers are orders; every proposal below was shipped only after a yes.

## Rewards that scale with the player's income
A flat event reward is huge at rebirth 0 and worthless at rebirth 8. Pay
```lua
local reward = math.max(oldBase * RebirthCashMult(player), IncomePerSecond(player) * cfg:GetAttribute("XIncomeSeconds"))
```
with one `...IncomeSeconds` attribute per reward (catch a ghost 10 s, golden x5, top event reward 60 s, opened door 30 s,
pedestal milestone 20 s). Stat-based rewards (steal bonus) get a `...RebirthScale`. Test both ends: a new player and a
late-game save.

## Progression levers that worked
- **Per-zone rarity floor**: `Wing<n>MinRarity` (Common / Uncommon / Epic / Mythic) + `Wing<n>RarityShift` (weight x
  shift^(steps above floor)). Deeper zones feel deeper; secrets keep their own absolute share so they stay rare. Never let
  a pick fall back to the lowest tier: take the nearest lower rarity that has loot. It compressed mid/late game ~15% in
  the sim; flag that to the owner with the knob that undoes it.
- **Offline earnings rate** as an attribute (it was halved once, 0.25 -> 0.125, on the owner's call).
- **Rebirth ladder**: many cheap rebirths each worth a little (+cash multiplier, extra carry every few) beats a few huge
  walls. Keep existing players' unlocks when the ladder changes.
- **Public announce thresholds**: announce rebirths only at multiples of `RebirthAnnounceEvery` (e.g. 50) or chat fills up.
- **Early-game feel check** (second game): average value per cycle / cycle time = $/min, then time to the first upgrade.
  "First upgrade in ~3 min with passive income of $0.5/s" felt thin; the proposal was smelt 8->5 s, passive x3, first
  upgrade cost -30%, landing at ~1.5-2 min. Write it as a table of before/after and wait for the owner.

## Event presentation that scales
- **One event pill**: instead of one banner per event, the existing top pill shows the running event's text in that
  event's colour (`Pill@Color<State>`, `UIStroke@Color<State>`), grows while an event is on (`EventPcSize`,
  `EventPhoneSize`), newest-started wins, falls back to the next running event, shows warnings when idle. Old banners stay
  as hidden templates behind `MergeEvents = true` (untick = old behaviour).
- **Event objects big enough to see on a phone**: `GhostScale = 2` via `Model:ScaleTo` at spawn, and grow the server
  catch range and prompt distance by the size difference.
- Admin starts start now and stack (docs/live-events.md); one shared Highlight per event group (docs/performance.md).

## Boss variants ("King variants") pattern
A world boss with rare variants, rolled per server:
- `ServerStorage.<Boss>Variants/<Tier>/` holds each variant's body, FX and special loot as real instances; a
  `Variants` module rolls a tier every `RerollMinutes` (180) with weights in attributes; no cross-server sync needed.
- Players see it four ways: chat announce + a HUD tier tag, tier VFX/roar pitch/lighting tint (a cloned
  ColorCorrection, not a brightness multiplier that fights other lighting scripts), an Index tab of variants seen (saved
  per player, sanitised), and badges for meeting/surviving the rare ones.
- Admin rows: Force <Tier>, Reroll. Update-log entry. Special loot lives in one place only (two agents once put it in two
  places; pick one at merge).
- Split as three parallel agents (core, player FX, index/admin) and merge in that order.

## Badges
- Created in Creator Hub (free up to a daily quota per experience; one was left for the next day). Open Cloud place keys
  can't create them. IDs are baked into the build, never pasted in Studio.
- Store IDs as `IntValue`s or **string** attributes (Lune truncates number attributes over 2^31); `0` / empty = off.
- Count-based badges (`VaultRaiderCount 10`, `GhostHunterCount 25`) keep counters in saved data even while the ID is 0, so
  turning a badge on later awards it retroactively on join. Award retro on join for rebirth/index badges too.
- Fire awards from a signal (a BindableEvent fired right after each gameplay Fx) instead of sprinkling `AwardBadge` into
  game code; `pcall` + retry delay; `Enabled` attribute.
