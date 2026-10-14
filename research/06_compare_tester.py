"""Compare the Expert Advisor's Strategy Tester trades with the research reference list.

Put GoldNYSweep_trades.csv (from MT5's Terminal/Common/Files) in My Trades/results, then
run this in Colab after mounting Drive, or locally with RESULTS pointing at that folder.
"""
import os

import pandas as pd

RESULTS = "/content/drive/MyDrive/My Trades /results"
if not os.path.isdir(RESULTS):
    RESULTS = "/content/drive/MyDrive/My Trades/results"

ref = pd.read_csv(os.path.join(RESULTS, "reference_trades.csv"))
ea = pd.read_csv(os.path.join(RESULTS, "GoldNYSweep_trades.csv"))

ea["day"] = pd.to_datetime(ea["time_utc"].str.replace(".", "-", regex=False)).dt.date.astype(str)
ref["day"] = ref["day"].astype(str)
entries = ea[ea["event"] == "entry"].drop_duplicates("day")[["day", "direction", "entry", "stop", "price", "lots"]]

first, last = entries["day"].min(), entries["day"].max()
ref = ref[(ref["day"] >= first) & (ref["day"] <= last)]
m = ref.merge(entries, on="day", how="outer", suffixes=("_ref", "_bot"), indicator=True)

both = m[m["_merge"] == "both"]
print(f"Period: {first} to {last}")
print(f"Reference trades: {len(ref)}   Bot trades: {len(entries)}   On the same day: {len(both)}")
print(f"Same direction: {(both['direction_ref'] == both['direction_bot']).mean() * 100:.0f}%")
print(f"Entry level difference: median ${(both['entry_ref'] - both['entry_bot']).abs().median():.2f}, "
      f"max ${(both['entry_ref'] - both['entry_bot']).abs().max():.2f}")
print(f"Stop level difference:  median ${(both['stop_ref'] - both['stop_bot']).abs().median():.2f}, "
      f"max ${(both['stop_ref'] - both['stop_bot']).abs().max():.2f}")

only_ref = m[m["_merge"] == "left_only"]["day"].tolist()
only_bot = m[m["_merge"] == "right_only"]["day"].tolist()
print(f"\nDays only in the research list ({len(only_ref)}): {', '.join(only_ref) or 'none'}")
print(f"Days only in the bot's trades ({len(only_bot)}): {', '.join(only_bot) or 'none'}")
print("\nA few mismatched days are normal (tick data and research minute bars differ slightly).")
print("Many mismatches, or different directions, mean something is set up differently: check ServerUTCOffsetHours.")
