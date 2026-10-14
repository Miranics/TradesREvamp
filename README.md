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
│   └── bakeoff_trades.csv          # every simulated trade from the bake-off
└── research/
    ├── 01_trade_review.ipynb       # review of 2026 Exness trades + first backtests (with saved outputs)
    └── 02_strategy_bakeoff.ipynb   # 2024–2026 comparison of candidate strategies (with saved outputs)
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
