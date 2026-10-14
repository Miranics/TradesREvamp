# TradesREvamp

Research and automation for an intraday gold (XAUUSD) strategy traded on Exness MT5: from a review of real trade history, to backtests on 1-minute data, to an MT5 Expert Advisor.

## Structure

```
TradesREvamp/
├── README.md
├── docs/
│   ├── sweep_model.md              # exact rules of the strategy being tested
│   └── results_bakeoff.md          # 2024–2026 comparison results
├── results/
│   ├── bakeoff_trades.csv          # every simulated trade from the bake-off
│   ├── pyramiding_trades.csv       # every trade under the 7 add rules
│   └── phase_sizing_output.txt     # output of 04_phase_sizing.py
└── research/
    ├── 01_trade_review.ipynb       # review of 2026 Exness trades + first backtests (with saved outputs)
    ├── 02_strategy_bakeoff.ipynb   # 2024–2026 comparison of candidate strategies (with saved outputs)
    ├── 03_pyramiding.ipynb         # how aggressively to add to winners (with saved outputs)
    └── 04_phase_sizing.py          # which add rule to use below and above $250
```

An `mql5/` folder with the Expert Advisor will be added once a strategy passes the bake-off.

## Running the notebooks

1. Open the notebook in Google Colab (the badge at the top of each notebook, or from Google Drive).
2. Run all cells. `02_strategy_bakeoff.ipynb` mounts Google Drive and stores downloaded price data in `My Trades/data`, so it only downloads once.
3. `02_strategy_bakeoff.ipynb` uses Exness's free tick archive (`ticks.ex2archive.com`, symbol XAUUSDm), converted to 1-minute candles with the real spread. `01_trade_review.ipynb` used Dukascopy data via `dukascopy-node`.

## Findings so far

| Question | Answer |
|---|---|
| Do the original 2026 gold entries have an edge? | No. The best stop and target combination across 245 trades was about breakeven. |
| Does the sweep model work on 2026 data? | Yes, in-sample: +0.45R per trade (hold) and +0.65R (with adds), 47 trades. Robust to the displacement threshold. |
| Which timeframe for the break? | 5-minute. The 1-minute version lost money; the 15-minute version was weaker. |
| Does it hold out-of-sample (Exness data 2024–2025)? | Yes. Positive in 2024, 2025 and 2026, for buys and sells, and beats random direction (p = 0.005 with adds). Weaker before 2026: +0.12R and +0.56R per trade with adds. See `docs/results_bakeoff.md`. |
| Do other published intraday strategies work on gold? | No. Intraday momentum and opening-range breakout failed all checks after costs. |
| How hard should winners be pressed? | Per trade, more adds earn more R (adds to +4R: +0.55R; growing adds: +0.76R). But with the stop moved to entry, a reversal after two adds loses about 3R, which ends a $50 account. Best plan: no adds below $250, then adds every 1R up to +4R at 10% risk. See `docs/results_pyramiding.md`. |
