# Real-time entry timing (research/05_realtime_check.ipynb)

## The problem

The bake-off and pyramiding tests started watching for the entry from the bar after the fair value gap. When the gap formed *before* the break bar, that meant the order could start a few minutes before the break had happened. A bot cannot do that. It happened in 41 of 214 trades.

## Three timings, same rules, Exness data January 2024 – October 2026

Cost: $0.16 per position (median New York spread).

| Timing | Trades | Hold to 23:00 | Adds to +4R | t (adds) |
|---|---|---|---|---|
| A. As tested before | 214 | +0.193R | +0.546R | 1.95 |
| B. Order when the break bar closes | 136 | +0.032R | +0.009R | 0.04 |
| C. Order when the bar after the break closes | 207 | +0.164R | +0.540R | 1.88 |

Adds to +4R, by year:

| Timing | 2024 | 2025 | 2026 |
|---|---|---|---|
| A | +0.104R | +0.862R | +0.926R |
| B | −0.088R | −0.481R | +0.763R |
| C | +0.129R | +0.874R | +0.850R |

## Checks on timing C (what the bot does)

| Check | Result |
|---|---|
| Double spread ($0.32) | +0.513R per trade with adds |
| Random direction (2,000 shuffles) | beats the real direction 1.2% of the time (p = 0.012) |
| Buys | 86 trades, +0.670R |
| Sells | 121 trades, +0.448R |
| Price already past the entry when the order goes in | 15 of 207. The bot enters at market at an equal or better price |

## Verdict

The edge survives realistic timing. In most setups (146 of 214), the gap is completed by the bar after the break, which is why waiting one bar keeps the edge and placing the order a bar earlier (B) loses it. The EA uses timing C.

The t-statistic is 1.88, slightly under 2. The edge is real by the random-direction test but not large; the forward test in `docs/RULES_v2.md` is the next check.

## EA check

A line-by-line Python copy of the EA's detection code (`ScanDay` in `mql5/GoldNYSweep.mq5`) produced the same 207 trades on the same days, with identical direction, entry and stop. The next check is MT5's Strategy Tester on Exness ticks, compared with `results/reference_trades.csv` using `research/06_compare_tester.py`.
