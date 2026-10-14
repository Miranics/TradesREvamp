# Sweep model (v1 specification)

One gold (XAUUSD) trade per day during the New York session. This is the exact rule set tested in `research/01_trade_review.ipynb` and `research/02_strategy_bakeoff.ipynb`, and the one the Expert Advisor will implement.

Times are UTC, with Kigali time (UTC+2) in brackets.

## Rules

| Step | Rule |
|---|---|
| 1. London range | High and low of 07:00–12:00 (09:00–14:00) |
| 2. Sweep | Between 13:00 and 17:00 (15:00–19:00), a 5-minute bar trades beyond the London high (look for sells) or low (look for buys). Only the first sweep counts. |
| 3. Break | Within 30 five-minute bars, a bar **closes** beyond the most recent swing point before the sweep, with a body at least 1.5× the median of the previous 20 bodies |
| 4. Entry | Limit order at the near edge of the fair value gap left by the break |
| 5. Cancel | If price reaches the stop before filling, or the order is not filled by 20:00 (22:00) |
| 6. Stop | $0.50 beyond the sweep's extreme |
| 7. Adds | Below $250: none. From $250: at +1R, +2R, +3R and +4R, add a position of the same size and move the stop on all positions to the first entry. A reversal after n adds loses 1+2+…+n R on the adds. |
| 8. Exit | Close everything at 21:00 (23:00). No take-profit. |
| 9. Limit | One trade per day |

A swing point is a 5-minute bar whose low (or high) is lower (or higher) than the two bars on each side.

## Results so far (Dukascopy 1-minute data, Feb–Oct 2026, $0.30 spread per position)

| Version | Trades | Win rate | Average |
|---|---|---|---|
| Hold to 21:00 | 47 | 53% | +0.45R |
| Adds at +1R and +2R | 47 | 40% | +0.65R |

These come from the same period the model was designed on, so they are in-sample. The bake-off notebook tests 2024 and 2025 as out-of-sample years.

## Known risks

- Small sample: 47 trades. On random data, a year of about 65 trades can average anywhere from −0.4R to +0.3R by chance.
- Almost all 2026 profit came from sells, in a year when gold fell during US hours.
- Fills are simulated on 1-minute bid candles. Exness execution and spreads will differ; the MT5 Strategy Tester on Exness ticks is the final check.
