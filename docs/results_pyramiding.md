# Pyramiding results (run 14 Oct 2026)

Same 214 sweep-model trades as the bake-off (Exness XAUUSDm, Jan 2024 – Oct 2026, $0.16 cost per position). 1R = distance from the first entry to the original stop. Source: `research/03_pyramiding.ipynb` and `research/04_phase_sizing.py`.

## Per trade

| Add rule | 2024 | 2025 | 2026 | Avg R | Worst trade | Max drawdown | Longest losing run |
|---|---|---|---|---|---|---|---|
| 1 No adds | +0.04 | +0.17 | +0.48 | +0.19 | −1.1R | 12.3R | 6 |
| 2 Adds at +1R, +2R | +0.12 | +0.56 | +0.79 | +0.43 | −3.3R | 16.2R | 8 |
| 3 Adds every 1R to +4R | +0.10 | +0.86 | +0.93 | +0.55 | −3.3R | 16.2R | 8 |
| 4 Adds every 0.5R to +3R | −0.14 | +1.16 | +0.80 | +0.50 | −8.0R | 45.1R | 9 |
| 5 Adds to +4R, trailing stop | −0.01 | +0.58 | +0.66 | +0.34 | −1.1R | 16.3R | 8 |
| 6 Growing adds (1, 2, 3) | +0.16 | +1.08 | +1.42 | +0.76 | −8.5R | 25.5R | 8 |
| 7 Adds to +4R, hold overnight | −0.45 | +1.61 | +0.48 | +0.41 | −10.2R | 86.3R | 24 |

## Why adds hurt a $50 account

With the stop moved to the first entry, each add is still exposed back to that entry. A reversal after adds at +1R and +2R loses 1R + 2R = 3R; after four adds the theoretical worst case is 10R. With stops of $13–25 at 0.01 lot, one such trade ends a $50 attempt.

| Single-rule plan (2025–2026 trades) | Reach $250 | Reach $1,000 | Bust |
|---|---|---|---|
| 1 No adds | 58.6% | 49.2% | 42.8% |
| 2 Adds at +1R, +2R | 49.3% | 41.7% | 55.7% |
| 3 Adds every 1R to +4R | 51.0% | 44.4% | 53.6% |
| 6 Growing adds | 46.1% | 32.2% | 67.6% |

## Phase-dependent plan (best combinations, 6,000 attempts each)

| Below $250 | From $250 | Risk from $250 | Reach $250 | Reach $1,000 | Bust |
|---|---|---|---|---|---|
| No adds | Adds every 1R to +4R | 10% | 60.3% | 53.8% | 40.3% |
| No adds | Adds at +1R, +2R | 10% | 58.6% | 51.0% | 42.2% |
| No adds | No adds | 20% | 60.6% | 50.6% | 40.8% |
| Trailing adds | any | any | ~42% | 28–39% | 59–71% |

Chosen plan: one position with no adds until the account reaches $250, then adds every 1R up to +4R with 10% of the balance at risk per position.

These odds assume future trades resemble 2025–2026. Differences of 1–2 points between plans are within simulation noise.
