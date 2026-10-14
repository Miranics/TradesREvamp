# GoldNYSweep Expert Advisor

`GoldNYSweep.mq5` trades the sweep model in `docs/sweep_model.md` on gold (Exness symbol `XAUUSDm`), with the sizing and adds in `docs/RULES_v2.md`.

## What it does each day

| Time (UTC) | Kigali | Action |
|---|---|---|
| 07:00–12:00 | 09:00–14:00 | Records the London high and low |
| 13:00–17:00 | 15:00–19:00 | Watches 5-minute bars for the first sweep of the London high or low |
| After the sweep | | Waits up to 29 bars for a 5-minute close beyond the last swing point, with a body at least 1.5× the median of the previous 20 |
| When the bar after the break closes | | Takes the most recent fair value gap. Entry is its near edge; the stop is $0.50 beyond the sweep's extreme |
| Until 20:00 | 22:00 | Enters at market when the bid reaches the entry. Cancels if the bid reaches the stop first |
| While in the trade | | From $250: adds the same size at +1R, +2R, +3R, +4R and moves every stop to the first entry |
| 20:58 | 22:58 | Closes everything |

One trade per day, weekdays only.

The bot waits for the bar after the break to close before it places anything. `research/05_realtime_check.ipynb` shows why: placing the order the moment the break bar closes loses the edge, while waiting one bar keeps it (+0.54R per trade with adds, 2024–2026).

## Inputs

| Input | Default | Meaning |
|---|---|---|
| MagicNumber | 260514 | Identifies the bot's positions |
| ServerUTCOffsetHours | 0 | Server time minus UTC. Exness MT5 servers run on UTC, so 0. Check it in Market Watch: server time should equal UTC |
| SeedLots | 0.01 | Lot size below AddStartBalance |
| AddStartBalance | 250 | Balance at which growth sizing and adds begin |
| GrowthRiskPct | 10 | Risk per position from AddStartBalance, as % of balance. Lots never go below the broker minimum (0.01) |
| AllowAdds | true | Adds to winners from AddStartBalance |
| AddLevelsR | 1,2,3,4 | Add levels in R |
| WriteTradeLog | true | Writes every event to `GoldNYSweep_trades.csv` in MT5's Common\Files folder |

The time and setup inputs match the research. Leave them as they are unless a new notebook tests a change.

## Install

1. In MT5 on a computer (Windows, or Linux/Mac with MetaQuotes' installer), open **File → Open Data Folder → MQL5 → Experts** and copy `GoldNYSweep.mq5` there.
2. Open it in MetaEditor (F4) and press **Compile** (F7). It should report 0 errors.
3. In the Navigator, drag **GoldNYSweep** onto an `XAUUSDm` chart (any timeframe) and tick **Allow Algo Trading**.

The bot reads 5-minute and 1-minute bars itself, so the chart timeframe does not matter.

## Check it in the Strategy Tester first

1. **View → Strategy Tester**. Expert: GoldNYSweep. Symbol: `XAUUSDm`. Dates: 2024-01-01 to today.
2. Modelling: **Every tick based on real ticks**. Deposit: 50 USD. Leverage: your account's.
3. Run, then open the **Journal** and **Backtest** tabs.
4. Copy `GoldNYSweep_trades.csv` from `Terminal\Common\Files` into `My Trades/results` and run `research/06_compare_tester.py` in Colab. It lists every day where the bot and `reference_trades.csv` disagree.

The setups (days, direction, entry, stop) should match the reference list almost one for one. Profits will differ slightly, because the tester uses the real spread on every tick and fills at market.

## Going live

The bot runs on any account, demo or real. The live forward test is the first 20 trades on a $50 real account (see `docs/RULES_v2.md`).

The bot only trades while an MT5 terminal with it attached is running, from 07:00 to 21:00 UTC (09:00–23:00 Kigali), every weekday. The MT5 phone app cannot run Expert Advisors. It does not need your own computer: a cloud server does the job.

| Option | Cost | Notes |
|---|---|---|
| MetaQuotes virtual hosting | $15 a month (less if rented for longer) | Rented inside desktop MT5 (right-click the account → Register a Virtual Server). One click copies the chart and bot to the server; it then runs 24/7 with your computer off. Watch trades from the phone app |
| Exness VPS | free above a balance and volume threshold | Requested from the Exness Personal Area once the account qualifies |
| Any Windows cloud server | from about $5 a month | Install MT5 on it, attach the bot, and leave it running |

With MetaQuotes hosting, desktop MT5 is needed only once, to attach the bot and start the migration. On Linux, MetaQuotes' installer runs MT5 through Wine.

If the bot restarts during the day, it rebuilds the day's setup from the chart and keeps managing open positions. If price reached the entry while it was offline, it skips the day instead of chasing.
