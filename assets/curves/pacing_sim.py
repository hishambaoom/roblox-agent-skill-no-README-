"""Generic Monte Carlo pacing sim (example). Compare two economy configs on the same seeds before publishing.
Loop: craft an item, push it +1 at a time (risk of breaking grows per level, cut by the upgrade's mult),
sell at the expected-value stop level, buy the cheapest affordable upgrade, rebirth when affordable + max upgrade.
Replace craft/push/sell with your game's real formulas (read them from the scripts + Config).
Usage: python3 pacing_sim.py [seeds]   -> median minutes to each milestone, share of seeds that reached it."""
import random, statistics, sys

BASE = dict(
    upgrades=[(0, 1.0), (2_000, .92), (15_000, .85), (60_000, .78), (200_000, .72)],  # (cost, break mult)
    item_value=120, value_growth=1.35, break_base=0.04, break_growth=1.18,
    hit_seconds=0.67, craft_seconds=3, rebirth_cost=500_000, rebirth_growth=2.0, rebirth_mult=0.45,
)
PROPOSED = dict(BASE, upgrades=[(0, 1.0), (2_000, .95), (15_000, .90), (60_000, .85), (200_000, .80)])

def break_p(c, lvl, mult): return min(0.95, c["break_base"] * c["break_growth"] ** lvl * mult)

def stop_level(c, mult):  # push while the expected value of one more hit beats stopping
    lvl = 0
    while (1 - break_p(c, lvl, mult)) * c["value_growth"] > 1 and lvl < 30: lvl += 1
    return lvl

def run(c, seed, hours=3):
    rng = random.Random(seed); t = cash = 0.0; up = R = 0; ms = {}
    while t < hours * 3600:
        mult = c["upgrades"][up][1]; target = stop_level(c, mult); lvl = 0; t += c["craft_seconds"]
        while lvl < target:
            t += c["hit_seconds"]
            if rng.random() < break_p(c, lvl, mult): lvl = -1; break
            lvl += 1
        if lvl > 0: cash += c["item_value"] * c["value_growth"] ** lvl * (1 + c["rebirth_mult"] * R)
        if up + 1 < len(c["upgrades"]) and cash >= c["upgrades"][up + 1][0]:
            up += 1; cash -= c["upgrades"][up][0]; ms.setdefault("U%d" % up, t / 60)
        cost = c["rebirth_cost"] * c["rebirth_growth"] ** R
        if up == len(c["upgrades"]) - 1 and cash >= cost:
            R += 1; cash = 0; up = 0; ms.setdefault("R%d" % R, t / 60)
    return ms

def summary(c, seeds):
    runs = [run(c, 1000 + s) for s in range(seeds)]; keys = sorted({k for r in runs for k in r}, key=lambda k: (k[0] != "U", int(k[1:])))
    return {k: (round(statistics.median([r[k] for r in runs if k in r]), 1), sum(k in r for r in runs)) for k in keys}

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    a, b = summary(BASE, n), summary(PROPOSED, n)
    print("milestone  base_min(reached)  proposed_min(reached)  delta%")
    for k in sorted(set(a) | set(b), key=lambda k: (k[0] != "U", int(k[1:]))):
        x, y = a.get(k, (None, 0)), b.get(k, (None, 0))
        d = round((y[0] - x[0]) / x[0] * 100, 1) if x[0] and y[0] else None
        print(f"{k:9} {x[0]} ({x[1]}/{n})   {y[0]} ({y[1]}/{n})   {d}")
