# Gold NY Sweep Model — Trading Rules v2

Editable copy: Google Drive, `My Trades/Trading Rules v2 — Gold NY Sweep Model`. All times are Kigali time (UTC+2).

## The model in one paragraph

One gold trade per day: New York sweeps the London high or low, a 5-minute candle breaks structure decisively the other way, and you enter on the fair value gap. The stop sits beyond the sweep and everything closes at 23:00 Kigali. Below $250 the trade is a single 0.01-lot position; from $250 you add at +1R, +2R, +3R and +4R with 10% of the balance at risk per position. On Exness gold data from January 2024 to October 2026 (207 trades, with the order placed only once the setup is complete), the model was profitable in every year, for buys and sells, and beat random direction. The budget is $150 a month, in three $50 attempts.

## Monthly budget

- Up to three $50 deposits per calendar month. No top-ups in between.
- When an attempt is stopped out, wait until the next trading day before depositing again.
- When the third attempt of the month is gone, stop until the 1st of next month.
- In simulation on 2025–2026 trades, a $50 attempt reached $250 about 60% of the time, $1,000 about 54%, and was wiped out about 40%.

## Daily routine and entry

1. **Before 15:00:** mark the London high and low (09:00–14:00). Write your bias in the journal.
2. **15:00–19:00, the sweep:** price trades beyond the London high or low. Only the first sweep counts.
3. **The break, 5-minute chart only:** within 30 candles of the sweep, a candle closes beyond the last swing point before the sweep, with a body at least 1.5× the median of the previous 20.
4. **Entry:** wait for the 5-minute candle *after* the break to close. Then place a limit order at the near edge of the most recent fair value gap. Swept the high → sell. Swept the low → buy. If price touched the stop during that candle, there is no trade.
5. **Cancel** if price reaches the stop before filling, or if unfilled by 22:00.
6. **No setup by 19:00:** no trade today.

## Managing the trade

- **Stop:** $0.50 beyond the sweep's extreme. 1R = entry to stop.
- **Adds (only from $250):** at +1R, +2R, +3R and +4R, add a position of the same size; at the first add, move the stop on all positions to the first entry.
- **Exit:** close everything at 23:00. No take-profit.
- **Worst case:** a reversal to the first entry after the +2R add loses 3R; after four adds, up to 10R.

## Position size

| Balance | Lot per position | Adds |
|---|---|---|
| $50–$249 | 0.01 | none |
| $250 and up | balance × 0.10 ÷ stop distance ÷ 100, rounded down to 0.01 (minimum 0.01) | at +1R, +2R, +3R, +4R, same lot |

Skip the setup if one position's risk in dollars is larger than the balance.

## Banking

- At $300: withdraw $50. At $1,000: withdraw half. Every $1,000 after that: withdraw half again.
- Withdraw after 23:00, never with a trade open.

## Never

- Trade without a stop; take a second trade the same day; add to a losing position or below $250; enter from the 1- or 15-minute chart; move a stop further away; trade before 15:00 or start a setup after 19:00; deposit more than $150 a month.

## Forward test

The first 20 trades are the test. Compare the average R with the backtest (+0.16R without adds, +0.54R with adds). Stop and review if three rules are broken or the first 10 trades average below −0.5R.

Evidence: `docs/results_bakeoff.md`, `docs/results_pyramiding.md`, `docs/results_realtime.md`. The Expert Advisor in `mql5/` follows these rules.
