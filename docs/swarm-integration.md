# Swarm builds: many agents, one place file, a serial integration chain

How the second reference game (*ForgeTax*, a forging/upgrade tycoon) went from an owner's Studio save to six published
versions in one day with 20+ parallel agents. `docs/subagents.md` covers small batches (2-6 workers + a verifier); this is
the scaled-up version for a whole game.

## The contract (one file every agent reads first)
Write `games/<game>/CONTRACT.md` before dispatching anyone. Template: `scripts/swarm/CONTRACT.template.md`. It holds:
- **BASE**: the owner's Studio save (`build/<game>_v0.rbxl`). Nobody edits it.
- **Tooling**: one Lune binary (`tools/lune10`), one patch shape: `work/<agent>/apply.luau` reads env `IN`, writes env `OUT`;
  `work/<agent>/test.luau` runs on `OUT`. Never write a renderer (reuse the rig).
- **Integration order**: e.g. `1 core, 2 fx, 3 plots, 4 racks, 5 ui`. Every apply must work on BASE *and* on BASE + every
  earlier agent in the order: touch only your scope, `FindFirstChild` before create, idempotent.
- **The owner's hard rules** copied verbatim (Studio-first, style, phone fit, server authority, no `require(id)`).
- **Existing assets** in BASE with their exact paths (verify names before you write the contract).
- **Shared names** everyone codes against: the Config module shape (tables, field names, formulas), the full list of
  RemoteEvents (one owner creates *all* of them, even ones handled by others), Fx event kinds and payloads, player
  attributes (who sets, who reads), server module APIs (`PlayerData.Get(player)`, `PlotService.GetPlot(player)`).
- **Report format**: <= 15 lines (files, apply path, test result, what the owner can edit in Studio, open issues).

Shared names are the whole trick: with them, five agents can write server, FX, plots, racks and UI at the same time
without seeing each other's code.

## The serial chain
```
BASE -> core -> fx -> plots -> racks -> ui -> ui2 -> anvil -> furnace -> wow -> tutorial -> cine -> hammerfix
     -> ui3 -> forgemode -> hammer2 -> badges -> sky -> (one-attribute tweak) -> organize (ALWAYS LAST)
```
- One **integrator** owns the chain and is the only one who publishes. Workers never publish.
- Build into `work/int<N>/`: save the **pre-organize** file of each step you may need again (`s_ui3.rbxl`, `s_wind.rbxl`,
  `s_fix5.rbxl`) plus the final `v<N>.rbxl`. Agent tests use pre-organize paths, so run them on the `s_*` file.
- Next version starts from the last pre-organize file, not from the organized one: `int5/s_fix5 -> ui5 -> vfx5 -> organize`.
- Text patches inside shared scripts carry a marker (`-- [badges]`, `-- [fix5]`). Two agents editing the same script is
  allowed only if their anchors differ; the integrator asserts every anchor is unique before applying (see
  `scripts/apply-template.luau`).
- Write a `STATUS.md` line per version: chain, files, every test count, what is Studio-unverified, what waits for the
  owner (economy changes, look). Example line:
  `v5 = int4/s_wind -> fix5 -> organize. Tests: core 1436, fx 192, ... fix5 95/0 on pre-organize AND organized. refcheck 0 regressions.`

## When an agent finishes late or out of order
- Its NOTES.md states where it goes in the chain (`Chain: after ui3, BEFORE organize`) and any TODO for the integrator
  (`set HammerAnimClient@WindupTime 0.05 at integration`, `add ForgeVFX2 = "VFX" to the organize map`).
- A later agent may supersede an earlier one's test (`ui3/test` obsolete -> replaced by `ui5/test`): drop it from the
  chain and list the expected fails in STATUS.
- Scope checks ("Workspace changed", "other Lighting changed") in older tests will flag a newer agent's legit changes.
  Add a narrow exempt list (`skyExempt = {Workspace.Map.Clouds*, Lighting.*}`) and run those tests with `IN` = the place
  right before the newer agent, not after.

## Per-agent NOTES.md (what made integration painless)
```
# <agent> (date) — one line of what it does. Chain: <where it sits>.
Apply: IN=<place> OUT=<out> tools/lune10 run games/<game>/work/<agent>/apply.luau  (idempotent; marker <attr or "[agent]">)
Test:  IN=<in> OUT=<out> tools/lune10 run .../test.luau  (N checks; works on pre-organize AND organized files?)
Adds only: <exact instance paths>. Edits: <script + anchor>.
Tunables (attributes): <list>.  Studio-unverified: <list>.  Expected fails in other tests: <list + why>.
```

## Rules that came out of it
- The integrator runs the full chain plus every agent test after each version; counts go in STATUS, not "all green".
- One agent's root cause can live in another agent's script (sword sinking came from an animation client, not the anvil
  display). Reproduce on both the organized and pre-organize file before blaming organize.
- Retention: keep only the pre-organize step files you still chain from plus the published file per `int<N>`.
- Owner-facing changes that are proposals (economy numbers) stay out of the chain until the owner says yes.
