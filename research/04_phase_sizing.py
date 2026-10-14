"""Phase-dependent sizing: which add rule to use below and above $250.

Reads results/pyramiding_trades.csv (produced by research/03_pyramiding.ipynb) and simulates
6,000 $50 attempts per combination, drawing trades at random from 2025-2026 results.
Run: python research/04_phase_sizing.py   (output saved in results/phase_sizing_output.txt)
"""
import numpy as np, pandas as pd
r = pd.read_csv("results/pyramiding_trades.csv")
r = r[r["year"] >= 2025]
wide = r.pivot_table(index="day", columns="variant", values="R")
risk = r.groupby("day")["risk"].first().loc[wide.index].to_numpy()
V = {c[0]: wide[c].to_numpy() for c in wide.columns}
rng = np.random.default_rng(11)

def sim(seed_v, growth_v, growth_risk, n=6000, start=50, seed_until=250, max_trades=150):
    reach250 = reach1000 = bust = 0
    for _ in range(n):
        bal, h250, h1000 = start, False, False
        for _ in range(max_trades):
            i = rng.integers(len(risk))
            if bal < seed_until:
                oz, R = 1, V[seed_v][i]
            else:
                oz, R = max(1, int(bal * growth_risk / risk[i])), V[growth_v][i]
            if risk[i] * oz > bal:
                if bal < risk.min():
                    bust += 1
                    break
                continue
            bal += R * risk[i] * oz
            h250 |= bal >= 250
            h1000 |= bal >= 1000
            if bal < 5:
                bust += 1
                break
            if h1000:
                break
        reach250 += h250
        reach1000 += h1000
    return round(100 * reach250 / n, 1), round(100 * reach1000 / n, 1), round(100 * bust / n, 1)

names = {"1": "no adds", "2": "adds +1R,+2R", "3": "adds to +4R", "5": "adds to +4R, trailing", "6": "growing adds"}
rows = []
for seed_v in ("1", "5"):
    for growth_v in ("1", "2", "3", "5", "6"):
        for gr in (0.10, 0.20):
            a, b, c = sim(seed_v, growth_v, gr)
            rows.append({"below $250": names[seed_v], "from $250": names[growth_v], "risk from $250": f"{int(gr*100)}%",
                         "reach_$250_%": a, "reach_$1000_%": b, "bust_%": c})
out = pd.DataFrame(rows).sort_values("reach_$1000_%", ascending=False)
print(out.to_string(index=False))
