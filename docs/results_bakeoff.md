# Strategy bake-off results (run 14 Oct 2026)

Exness XAUUSDm tick data, Jan 2024 – 13 Oct 2026, converted to 1-minute bid candles. Cost per position: Exness median New York spread ($0.16), stress-tested at $0.32. Profit in $ per 0.01 lot.

## Verdict

| Strategy | 2024 | 2025 | 2026 | Checks passed |
|---|---|---|---|---|
| A2 Sweep model, adds at +1R/+2R | +146.5 | +291.6 | +953.2 | **4/4** |
| A1 Sweep model, hold to 23:00 | +90.1 | +112.3 | +657.1 | **4/4** |
| D1 Always sell NY hours | −8.3 | −299.3 | +659.1 | 1/4 |
| D2 Always buy Asian hours | +139.7 | +465.5 | −25.4 | 1/4 |
| B NY intraday momentum | −52.9 | −14.8 | +152.6 | 0/4 |
| C NY opening-range breakout | −0.4 | +107.9 | −38.5 | 0/4 |

Checks: positive every year, t-stat above 2, beats random direction (p < 0.05), still positive at double spread.

## Sweep model in R

| Version | 2024 | 2025 | 2026 (design period) | Median stop |
|---|---|---|---|---|
| Hold to 23:00 | +0.04R (94 trades) | +0.17R (64) | +0.48R (56) | $9 / $13 / $25 |
| Adds at +1R/+2R | +0.12R | +0.56R | +0.79R | |

All years combined, with adds: 214 trades, 40.7% wins, profit factor 1.98, t = 2.43, p vs random = 0.005.

Buys and sells were both profitable in every year, so the edge is not just the 2026 decline in gold during US hours.

## Dollar index (DXYm) filter, sweep model with adds

| Condition (known before 15:00 Kigali) | Trades | Avg R when true | Avg R when false |
|---|---|---|---|
| Gold trade opposite the dollar's move so far | 79 | +0.67 | +0.28 |
| ...and the dollar moved more than usual | 28 | +0.77 | +0.37 |
| Dollar broke yesterday's high or low | 134 | +0.50 | +0.30 |

Aligned trades did better, but non-aligned trades were still profitable, so this is a candidate for sizing rather than a filter. Samples are small.

## Other observations

- Exness gold spread was about $0.16 from mid-2024 to Jan 2026, then $0.24–0.33 from Feb 2026.
- Session drift flipped between years (NY hours: −$299 in 2025, +$659 in 2026), so it is a regime, not an edge.
- Trend following (60-day) was positive each year but earned less than buy-and-hold in 2024–2025, before swap costs.

## Limitations

- 1-minute bid candles; if stop and entry or target fall in the same minute, the stop is assumed first.
- Buy fills use bid prices; the spread cost per position approximates the ask.
- 2024 out-of-sample result for the hold version is close to breakeven.
