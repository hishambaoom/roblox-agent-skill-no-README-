# Simulate the economy before publishing

From ForgeTax econ20 / v24 / v25. Any change to prices, multipliers, drop weights or new tiers gets a Monte Carlo
pacing sim **before** it ships. Read-only: no place edits.

## Method
1. **Model from the scripts, not memory**: loop timings, cooldowns, formulas, Config attributes read from the live
   place (dump with Lune). Write down every assumption (human pace, action seconds, event share, server size).
2. **Bot player**: a sensible greedy policy (stop level by expected value, risk floor ~20% survival, buy cheapest
   affordable upgrade, rebirth when policy says). Check the policy choice moves results little.
3. **Seeds**: 20 for a quick diff, 100 for a report; Unlucky / Average / Lucky (+ a paid-item buyer) profiles; 6 h session.
4. **Report milestone times** as medians with the share who reached them: each upgrade tier, first rare drop,
   rebirths R1/R5/R10/R14, plus "cost / income per second at purchase" (shows walls and dead zones).
5. **Diff old vs new on the same seeds**; a table of before/after and the Config knob for each recommendation.

## Guard rails
- Owner's limits are orders (e.g. "no milestone faster than 30%").
- Keep the **rarest tier's pacing** (first Mythic) roughly unchanged or slower; boosts should land mid/late, not on
  the top chase.
- Paid items: not pay-to-win early, a moderate edge late.
- Watch for: event loot that dwarfs normal income, rebirths cheaper than the gear before them, x2.5 cost walls,
  perks nobody can reach (check the odds).
- Say what the sim doesn't model (offline, bag cap, items not in the model) and that real players are ~1.5-2x slower.

## Example
`assets/curves/pacing_sim.py`: a small generic Monte Carlo (upgrade ladder + rebirths) printing median milestone
times for two configs side by side. Copy it and replace the loop with your game's formulas.
