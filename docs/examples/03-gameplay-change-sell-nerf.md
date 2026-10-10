# Example 3 — Gameplay lane: an economy change with tests against base

Real change from the reference game (Oct 9, version 108).

## Owner
> selling is abusable, nerf it. sell = half a second of the loot's income. and selling a pedestal should collect its cash first

## Agent — orient
- QUEUE: LIVE v64 (version 107, rebirth rework, just published). A parallel sell-nerf run had started from v63 →
  **must rebuild on work/v64.rbxl** or it reverts the rebirth rework. Wrote that warning into QUEUE.
- PROJECT decisions: per-loot $/s labels don't include the rebirth multiplier (owner, separate decision — don't touch).

## Agent — plan (5 lines, not sent to owner unless asked)
1. New `GameSettings@SellIncomeSeconds = 0.5` (tunable in Studio). Price = SellIncomeSeconds × loot $/s (level, mutation,
   `@IncomeMult`) × player multiplier, via one new `SharedUtils.CalculateSellPrice`.
2. Every sell path goes through `SellServer.Remove`: pedestal prompt, Sell menu, bag, bulk sell, auto-sell.
3. Selling pedestal loot first collects its stored Cash + OfflineCash (quests/stats still count it).
4. Labels: pedestal "Sell: $X", Sell menu values, bag "Sells for" use the same function.
5. Not changed: steal compensation and bank FX values (not sales).

## Agent — test first (must fail on base)
```lua
-- sellnerf_v65_test.luau (excerpt)
check(GS:GetAttribute("SellIncomeSeconds") == 0.5, "GameSettings.SellIncomeSeconds = 0.5 (owner 14:07)")
local price = SharedUtils.CalculateSellPrice(loot, player)
check(math.abs(price - 0.5 * income * mult) < 0.01, ("price = 0.5 s x income x mult (%s)"):format(price))
-- sell a pedestal with $1,200 stored: cash +1,200 first, then the sale
check(cashAfter - cashBefore == 1200 + price, "pedestal cash collected before sale")
GS:SetAttribute("SellIncomeSeconds", 1)   -- tunable is live
check(SharedUtils.CalculateSellPrice(loot, player) == 2 * price, "attribute change doubles the price")
```
```
$ tools/lune run tests/sellnerf_v65_test.luau work/v64.rbxl   →  FAIL 6   (base: old 20 s formula)
$ tools/lune run tests/sellnerf_v65_test.luau work/v65.rbxl   →  PASS
```
`sell_v13_test` asserted the old price → made adaptive (reads the attribute) so it passes on both.

## Agent — full suite vs base
```
$ tools/rig/run_all.sh work/v64.rbxl logs/run64 ; tools/rig/run_all.sh work/v65.rbxl logs/run65
$ tools/rig/compare_runs.sh logs/run64 logs/run65
== rc changes (base -> new)
  sellnerf_v65_test MISSING rc=0
== FAIL-line counts that differ
done
```
Same pass/fail set as v64 + the new test. fast.sh = v64 (one pre-existing text-size item, content-only).

## Agent — publish, log, report
```
- DONE ~14:35 Oct 9: v65 (LIVE version 108, built on v64) = SELL NERF … Example Lollipop Gold L5 at x1.66: old $797 -> new $49. Tests: sellnerf_v65_test PASS; run_all identical to v64. NOT playtested in Studio (MCP 403). BASE next: work/v65.rbxl.
```
> Version 108 is live, so rejoin. Every sale now collects the pedestal's cash first, then pays 0.5 s of income: a
> $100/s loot sells for $50. Change it in Studio: GameSettings → SellIncomeSeconds.
> Tests pass, same as before; not playtested in Studio (MCP is down).
> One thing to check: loot $/s labels leave out the rebirth multiplier, so sales show more than half the label.
> Should labels include it?

(Owner answered: no — leave labels. Logged as `DECIDED 15:08 Oct 9 (owner)`.)

## Why this is right
New tunable in Studio, one price function for every path, test that fails on base, suite compared to base, rebase
hazard caught and written down, honest "not playtested", exactly one question with context.

---
*Facts (numbers, versions, quotes) come from the reference project's version log and chat; command output is abbreviated and reformatted to the shipped rig's format.*
