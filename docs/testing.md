# Testing

Tests run headless with Lune against the **built place**: they load the place, run its real ModuleScripts inside a
small Roblox stand-in (`rbxsim.luau`), drive time manually and assert. A 60-second gameplay scenario runs in < 1 s.

## Test tiers
| Tier | What | When |
|---|---|---|
| Guard (STRICT) | studio-rule scan, text-size ≥ 12 px, scaffolding exists | every build (fast.sh) |
| Area tests | the system you touched (`sell_test`, `steal_cooldown_test` …) | fast lane: name them; gameplay: always |
| Full suite | every test in `tests/` (`run_all.sh`) + compare with base | gameplay lane, sweeps |
| Real playtest | Studio Play / device | owner or MCP; the only thing that counts as "Verified" |

## rbxsim in 30 seconds
```lua
local Sim = require("./rbxsim")
local sim = Sim.new(PLACE, { side = "server" })     -- or "client"
sim.studio = true                                     -- DataStores fall back to in-memory (ProfileStore mock)
for _, m in Sim.ServerModules(sim.game:GetService("ServerScriptService")) do sim:RequireAsync(m) end
local p = sim:AddPlayer("Owner", 1); sim:Step(0.5)
sim:SpawnCharacter(p, Vector3.new(0, 4, 0)); sim:Step(4)       -- Step(dt) advances clock + Heartbeat + task.wait
-- remotes loop back: FireServer → OnServerEvent; sim.fired records server→client events
```
It gives instances signals, WaitForChild, PivotTo, attribute-changed events, Remote loopback, mock services
(RunService, TweenService, MarketplaceService, …). It does NOT render, does NOT GC Instance keys, does NOT run physics.

## The pattern for a new test
```lua
--!nocheck
-- <feature>_test.luau: what it proves, how to run:  tools/lune run games/<game>/tests/<feature>_test.luau [place]
local process = require("@lune/process")
local Sim = require("./rbxsim")
local PLACE = process.args[1] or "games/<game>/build/game.rbxl"
local failures = 0
local function check(cond, msg) if cond then print("  ok   " .. msg) else failures += 1; print("  FAIL " .. msg) end end

print("== 0. baked into the place (Studio-first)")
local sim = Sim.new(PLACE, { side = "server" }); sim.studio = true
local GS = sim.game.ReplicatedStorage.Config.GameSettings
check(GS:GetAttribute("StealCooldownSeconds") == 120, "GameSettings.StealCooldownSeconds = 120")
check(not sim.game.ServerScriptService.Systems.Steal.Plot.Source:find("Instance.new", 1, true), "Plot creates no instances")

print("== 1. behaviour")
-- arrange (players, data) → act (remotes, Step) → assert (state, fired events)

print("== 2. tunable is live")
GS:SetAttribute("StealCooldownSeconds", 30)   -- changing the attribute must change behaviour without code
-- …assert new duration…

print(failures == 0 and "PASS" or ("FAIL " .. failures)); process.exit(failures == 0 and 0 or 1)
```
Full runnable example: `tools/example-game/tests/example_feature_test.luau`.

## Rules
- **A new test must FAIL on the base build and PASS on the new build.** Run it on both and quote both results.
- Test the **baked instance** (exists, attributes seeded, no Instance.new) and the **behaviour** and that the **tunable is
  live**.
- Assert numbers the owner decided, with the decision in a comment (`-- owner 17:45 Oct 9: 30 s`).
- Adaptive tests for values the owner may retune (read the attribute instead of hard-coding where the test isn't
  about the number).
- Stale tests: when the owner later changes a design, the old assert fails. Don't change the game back; update the test
  or mark it stale in the report with the QUEUE line that changed the design.
- Errors inside sim handlers are collected in `sim.Errors` — assert it's empty.

## Comparing runs (the gameplay-lane gate)
```
$ tools/rig/run_all.sh work/x/v144.rbxl logs/v144 ; tools/rig/run_all.sh work/x/v145.rbxl logs/v145
suite: 31 pass / 6 fail  (logs logs/v144)
suite: 32 pass / 6 fail  (logs logs/v145)
$ tools/rig/compare_runs.sh logs/v144 logs/v145
== rc changes (base -> new)
  bag_persist_test MISSING rc=0
== FAIL-line counts that differ
done
```
Same failing set as base + new test passing = no regression. Report the 6 pre-existing failures as "stale (owner
changed X on <date>)", not as new problems.

## What tests can't tell you (say so)
Rendering (text actually drawn size, meshes visible), Instance-key GC, physics/network ownership, real device input,
real purchases, DataStore throttling. These stay **Unverified** until a playtest.
