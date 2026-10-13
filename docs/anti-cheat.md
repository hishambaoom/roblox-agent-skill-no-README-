# Anti-cheat in three phases (server-side, built against a real exploit kit)

Designed against what a common admin-command exploit script offers (fly, noclip, speed, teleport, fling, sit, remote
spam, godmode, instant prompts, auto-farm). Everything is server-side, tunable by attributes, and covered by a server-sim
test that runs both exploits and legit movement. Basics (remote validation, data) are in `docs/security.md`.

## Phase 1: detect and flag (no punishment)
- Every check writes a **flag** (kind, details, score) to a per-player history; admins see a suspect score next to names.
- Cash-per-minute monitor: every Cash increase goes through `Security.CashGain(player, gain, source)`. Flag only: legit big
  payouts (offline earnings, rare sells) will trip it.
- Remote flood counter per remote; impossible rates (`FloodImpossiblePerSecond`) are a hard flag.

## Phase 2: enforce (rubberband, refuse)
| Exploit | Server check | Response |
|---|---|---|
| speed / walkspeed / tp / tween | speed budget per step with ping-gated lag allowance | rubberband to last trusted spot |
| fly / float / infinite jump / jumppower | rise without ground, hover time | rubberband to last floor |
| noclip | ray between checkpoints hits a wall | rubberband |
| fling | angular velocity / spin | reset |
| sit tricks | only real `Seat`s skip movement checks | ignore |
| godmode (delete Humanoid/HRP) | `Workspace.RejectCharacterDeletions = Enabled` | respawn |
| instant prompts (`fireproximityprompt`) | `Security.HeldLongEnough`: real hold of ~0.7 x HoldDuration, record **consumed** on success | refuse |
| event catch / door knock from afar | `Security.Near` (movement check first) + per-player rate | refuse |

Server-initiated moves (boss yeet, zone push-outs, admin teleports) call `Security.ExpectMove(player, landing)` **before**
the push, so they don't count as teleports. A push that starts from a teleported spot grants nothing.
Carry rules: a "daze" (knock-back while carrying) is bounded; if out of bounds the loot drops at the last trusted spot; bank
waits `BankSettleSeconds` after a daze.

## Phase 3: bans
- `BanServer` (load order early): `Ban`, `BanUser` (offline by name/id), `Unban`, `Suspects` admin actions; admins and the
  owner can't be banned; reason text filtered. Uses `Players:BanAsync` where available + a DataStore ban list.
- Join check **re-reads** the ban list (a cached "banned" kept kicking players unbanned on another server); cache only
  when the read fails.
- Saves are queued (a save requested during an in-flight save was dropped); `BindToClose` saves pending kicks.
- Name resolution: exact online name -> unique online prefix (several = refuse) -> exact username lookup. A first-prefix
  match once banned the wrong "Sam".

## False positives found in the bug sweep (fix these before enforcing)
- High-ping phones: a frozen client reappearing round a corner looks like noclip through the wall. First sample after a
  high-ping freeze moves the checkpoint without the wall test (speed budget still applies).
- Touch-based catches in a cluster of event objects spammed soft flags; keep touch refusals quiet.
- Teleport-style tests trip your own checks: write tests that walk and fire prompts while standing at them.

## Limits (say them to the owner)
ESP / aimbot-style client visuals can't be stopped server-side (StreamingEnabled limits what a client can see). Needs a
real-device Team Test: prompt hold on phones, fly/noclip on real geometry (sim rays are boxes), mobile ping values,
`BanAsync` live.
