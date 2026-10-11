#!/usr/bin/env python3
"""Rebirth cost curve designer: print a cost table and plot current vs proposed curves (log scale).

Usage:
  python3 rebirth_curve.py                          # built-in example tables
  python3 rebirth_curve.py --scale 0.75 --stretch 1.5 --discount 0.55 --ease "1=30e3,2=100e3,3=500e3,4=3e6,5=15e6,6=80e6"
  python3 rebirth_curve.py --costs costs.txt        # one cost per line = your live curve
Options:
  --scale     multiply the live table (e.g. a -25% price pass = 0.75)
  --stretch   spread the curve over more rebirths (1.5 = R15 costs what R10 cost)
  --discount  multiply every proposed cost (0.55 = 45% cheaper)
  --ease      override early rebirths with hand-picked costs; later ones join the curve unchanged
  --unlocks   label area unlocks, e.g. "2=Graveyard,5=Orchard,9=Swamp"
  --out       PNG path (default rebirth_curve.png)
Needs: matplotlib. Interpolates geometrically between table entries, then grows x1.4 per rebirth past the table.
The point: show the owner one picture (grey = now, black = proposed) and a table with the step ratio per rebirth,
so a balance change is a decision about numbers he can see, not a guess.
"""
import argparse, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker

EXAMPLE = [110e3, 2.8e6, 68e6, 420e6, 1.1e9, 3e9, 6e9, 13e9, 24e9, 38e9, 68e9, 110e9, 170e9, 270e9, 420e9,
           680e9, 1.1e12, 1.7e12, 2.6e12, 3.8e12, 5.5e12, 8.1e12, 12e12, 17e12, 26e12]

def parse_map(s, conv=float):
    out = {}
    for part in filter(None, (s or "").split(",")):
        k, v = part.split("=")
        out[int(k)] = conv(v)
    return out

def fmt(x):
    for u, s in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if x >= u:
            return f"${x / u:.3g}{s}"
    return f"${x:.0f}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--costs"); ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--stretch", type=float, default=1.0); ap.add_argument("--discount", type=float, default=1.0)
    ap.add_argument("--ease", default=""); ap.add_argument("--unlocks", default="")
    ap.add_argument("--rebirths", type=int, default=30); ap.add_argument("--out", default="rebirth_curve.png")
    a = ap.parse_args()
    table = [float(l) for l in open(a.costs)] if a.costs else EXAMPLE
    live = [x * a.scale for x in table]
    n = len(live)

    def cur(p):  # cost at (possibly fractional) rebirth p
        if p <= 1:
            return live[0] * (live[1] / live[0]) ** (p - 1)
        i = int(math.floor(p)); f = p - i
        if i >= n:
            return live[-1] * 1.4 ** (p - n)
        return live[i - 1] * (live[i] / live[i - 1]) ** f

    ease = parse_map(a.ease)
    def new(k):
        if k in ease:
            return ease[k]
        return (live[0] if k == 1 else cur(1 + (k - 1) / a.stretch)) * a.discount

    print(f"{'R':>3} {'now':>10} {'proposed':>10} {'step':>6}")
    for k in range(1, a.rebirths + 1):
        step = f"x{new(k) / new(k - 1):.1f}" if k > 1 else ""
        print(f"{k:>3} {fmt(cur(k)):>10} {fmt(new(k)):>10} {step:>6}")

    ink, bg = "#1d1d1f", "#e8e8ea"
    fig, ax = plt.subplots(figsize=(9, 5.4), dpi=150, facecolor=bg); ax.set_facecolor(bg)
    xs = list(range(1, a.rebirths + 1))
    ax.plot(xs, [cur(k) for k in xs], color=ink, alpha=0.45, lw=1.8, label="now")
    ax.plot(xs, [new(k) for k in xs], color=ink, lw=1.8, label="proposed")
    ax.set_yscale("log"); ax.minorticks_off()
    ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True))
    for r, name in parse_map(a.unlocks, str).items():
        ax.axvline(r, color=ink, alpha=0.14, ls="--", lw=1)
        ax.annotate(name, (r, new(r)), xytext=(6, -14), textcoords="offset points", fontsize=9, color=ink)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.grid(axis="y", color=ink, alpha=0.07); ax.set_xlabel("Rebirth number"); ax.legend(frameon=False)
    ax.set_title("Cost of each rebirth (log scale): grey = now, black = proposed", loc="left", fontsize=12)
    fig.tight_layout(); fig.savefig(a.out, facecolor=bg); print("wrote", a.out)

if __name__ == "__main__":
    main()
