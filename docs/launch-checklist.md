# Launch checklist

Run as a **read-only audit**: change nothing, publish nothing, only GET requests. Write `work/launch-readiness.md`
with a table: item · PASS/FAIL/UNVERIFIED/INFO · reason. End with a verdict (**READY / NOT YET**) and ordered blockers.

| # | Item | How to check |
|---|---|---|
| 1 | Runtime errors | All scripts compile; undefined-global scan; **real** playtest console (Studio/MCP). No playtest since vX = UNVERIFIED, not PASS |
| 2 | Data saves | Session lock, pcall + retry, kick on load fail, BindToClose, migrations, sanitize clamps, old-save test |
| 3 | Monetization | Every pass/product ID exists, this universe, for sale, has a handler; ProcessReceipt dedupe; UI price = charged price |
| 4 | Remote security | Every client→server handler: args checked + per-player limit; admin gate; list gaps by risk |
| 5 | Mobile + PC layout | Device sign-off (phone landscape/portrait, tablet, PC). Rig shots alone = UNVERIFIED |
| 6 | Timers/resets | Daily/quest reset uses server time, never a past stamp; correct timezone statement to owner |
| 7 | Maturity questionnaire | Creator Hub → Audience/Maturity completed; check public age-rating API / content restriction |
| 8 | Store page | Icon 512 px approved, thumbnails approved (+ optional video), name, description accurate |
| 9 | Server size | Open Cloud place `serverSize` = plot count (live setting wins over the file) |
| 10 | Access | Public vs private, devices enabled (turn off VR unless tested), voice, console |
| 11 | Performance | Highlights < ~31 visible, CanvasGroup count, per-frame loops gated on visibility, SurfaceGui MaxDistance, streaming |
| 12 | Badges / analytics | IDs baked; award retry |

Real result (reference game, Oct 9): verdict **NOT YET** — blockers: questionnaire unset (later completed by owner),
one real playtest of the live version (19 builds shipped without one), device layout sign-off. Not blockers: price
drift vs suggested, two low-risk unthrottled remotes, perf items.

## Performance audit pattern (read-only)
Rank findings HIGH/MED/LOW with cause (file + line), fix, and flags: **[VIS]** visible change → owner sign-off,
**[GAME]** gameplay risk. Examples that were real: inventory grid rebuilt 8×/s while open (coalesce + ignore income
ticks); recursive `FindFirstChild(name, true)` every frame (cache); hidden menus still animating every frame (gate on
visibility); 60 SurfaceGuis with infinite MaxDistance (set 60–80); uncapped Highlights (budget nearest K).
Confirm top items with the MicroProfiler on a phone before claiming wins.
