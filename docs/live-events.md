# Live events (timed events, admin events, rewards that stay relevant)

How the reference game ran eight timed events (vault raid, meteor shower, blood moon, trick-or-treat doors, ghost hunt,
midnight hour, mystery pumpkin, random-event rotation) without breaking the Studio-first rule or the economy.

## Shape of one event
| Piece | Where it lives | Notes |
|---|---|---|
| Tunables | `ReplicatedStorage.Config.<EventName>` (Configuration, attributes) | duration, interval, weights, rewards, caps. Baked at build time so the owner sees them in Studio. |
| Models / props | `ServerStorage.<EventName>` or `ServerStorage.Events.<EventName>.Models` | real instances (the owner's own meshes when he has them). Server clones into `Workspace.Map.Events.Live<EventName>` and destroys the clone at the end. |
| Client look | `ReplicatedStorage.Assets.<EventName>` (FX, sounds) + a `MainUI.<EventName>Banner` / pill | client clones and tweens; never `Instance.new` visuals. |
| Server logic | `ServerScriptService.Systems.Events.<EventName>` | owns state, validates every hit/pickup server-side, pays rewards. |
| Scheduler | `Systems.Loot.RandomEvents` + `Config.RandomEvents` | one queue, e.g. every 900 s pick from a weighted list; "Auto" toggles per event include/exclude it. |
| Admin rows | Admin panel → Server tab: **Start X now**, **Auto X on/off** | server-checked remote; non-admin callers are refused (and counted as an exploit strike). |

## Rules learned the hard way
- **One scheduler, many events.** Each event registers with the queue; never give each event its own `while true` timer
  (they drift into each other and stack by accident).
- **Admin start = start now, and it stacks.** Owners use admin starts for "admin abuse" sessions and want to fire several
  at once. Make admin-start bypass the queue, allow stacking with running events, restart the same event if it is already
  running, but keep events that share a physical spot (one vault) one-at-a-time. Keep the old behaviour behind an
  attribute (`Config.RandomEvents@AdminStartStacks`) so it can be flipped back.
- **Scale rewards with progression, not constants.** A flat `$5,000` treat is huge at rebirth 0 and worthless at rebirth 8.
  Pay `max(oldBase x RebirthCashMult, IncomePerSecond x N seconds)` with `N` as a tunable per event
  (`CandyIncomeSeconds 10`, `TopRewardIncomeSeconds 60`, `TreatCashIncomeSeconds 30`, `MilestoneIncomeSeconds 20`).
  Stat-based rewards (steal bonus) get a `...RebirthScale` attribute.
- **Rare things must stay rare.** When an event introduces a special variant (special meteors, golden ghost), gate the
  callout/announcement to the top rarities only, and let the owner list which mutations count (`SpecialMutations=Rainbow`).
  An agent that adds "Gold" to the special list is changing the design.
- **Weights of 0 are a feature.** Owners tune by zeroing junk tiers in an event's loot table (`Weights Common 0 / Uncommon 0`)
  rather than asking for code; expose every weight as an attribute.
- **Streaming-safe events.** With `StreamingEnabled`, the client may not have the event model when the server says "hit".
  Snap/position on the server, give the client a remote path (`Remotes.<Event>.Hit` for click/tap/tool swing), allow range
  slack, and show "Get closer" hints instead of silent misses. Raycast spawn spots to the real floor and anchor everything
  (a vault fell through the map when its pivot was computed against a streamed-out floor).
- **Highlights are a shared budget** (31 rendered at once). Events that outline many objects must share one Highlight per
  group (see `docs/performance.md`).
- **Event rewards and "once per X" milestones need a reset story.** A milestone that pays at every 3 filled pedestals
  re-paid after rebirth because loot stayed on the pedestals: decide (and test) what rebirth resets.
- **Tests that pin old design break on purpose.** When the owner changes an event rule, mark the old asserts as expected
  failures in the report (cite the decision line) instead of "fixing" the game back.

More: income-scaled reward formulas, one merged event pill, boss variants and badge wiring are in
`docs/economy-and-events.md`.

## Event checklist
1. Config attributes baked, default = code value.
2. Models/FX/UI are Studio instances; event works with the owner's mesh swapped in (no hard-coded sizes).
3. Server validates every interaction (distance, cooldown, rate, NaN), refuses right after a teleport.
4. Admin Start/Auto rows; admin start stacks; queue resumes after.
5. Rewards scale with income/rebirth; caps on simultaneous pickups (`MaxPickupsAlive`).
6. Highlights/lights tagged `KeepInLowGfx` only if gameplay-critical.
7. Update-log entry + one short toast/pill; no new popup unless the owner asked.
8. Test: event starts, ends, cleans up every clone, pays once, survives a player leaving mid-event.
