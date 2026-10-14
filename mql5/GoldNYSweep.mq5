//+------------------------------------------------------------------+
//| GoldNYSweep.mq5                                                  |
//| Gold (XAUUSD) New York sweep model.                              |
//|                                                                  |
//| 1. London range: high and low of 07:00-12:00 UTC.                |
//| 2. Sweep: a 5-minute bar between 13:00 and 17:00 UTC trades      |
//|    beyond the London high (sells) or low (buys).                 |
//| 3. Break: within 29 bars, a 5-minute bar closes beyond the last  |
//|    swing point before the sweep, with a body at least 1.5x the   |
//|    median of the previous 20 bodies.                             |
//| 4. Entry: when the bar after the break closes, take the most     |
//|    recent fair value gap; enter when the bid reaches its near    |
//|    edge. Stop $0.50 beyond the sweep's extreme.                  |
//| 5. Cancel if the stop is reached first or nothing fills by       |
//|    20:00 UTC. Close everything at 20:58 UTC. One trade per day.  |
//| 6. Below AddStartBalance: SeedLots, no adds. From it: risk       |
//|    GrowthRiskPct of balance, add the same size at +1R..+4R and   |
//|    move every stop to the first entry.                           |
//|                                                                  |
//| Research: research/02_strategy_bakeoff.ipynb,                    |
//| research/03_pyramiding.ipynb, research/05_realtime_check.ipynb   |
//+------------------------------------------------------------------+
#property copyright "Nanen Miracle Mbanaade"
#property link      "https://github.com/Miranics/TradesREvamp"
#property version   "1.00"
#property description "Gold NY sweep model: London range sweep, 5-minute displacement break, fair value gap entry."

#include <Trade/Trade.mqh>

input group "General"
input long   MagicNumber          = 260514;  // Magic number

input group "Time"
input int    ServerUTCOffsetHours = 0;       // Server time minus UTC, hours (Exness = 0)
input int    LondonStartHour      = 7;       // London range start, UTC
input int    LondonEndHour        = 12;      // London range end, UTC
input int    SweepStartHour       = 13;      // First sweep bar, UTC
input int    SweepEndHour         = 17;      // No new sweeps from, UTC
input int    LastFillHour         = 20;      // Cancel unfilled setup from, UTC
input int    ExitHour             = 20;      // Close everything at, UTC (hour)
input int    ExitMinute           = 58;      // Close everything at, UTC (minute)

input group "Setup"
input double DisplacementMult     = 1.5;     // Break body vs median of previous bodies
input int    BodyMedianBars       = 20;      // Bodies in the median
input double StopBufferUSD        = 0.50;    // Stop distance beyond the sweep extreme
input int    MaxBreakBars         = 29;      // Bars after the sweep to find the break
input int    SwingLookback        = 40;      // Bars before the sweep searched for a swing
input int    MinLondonBars        = 40;      // Minimum 5-minute bars in the London range

input group "Sizing and adds"
input double SeedLots             = 0.01;    // Lots below AddStartBalance
input double AddStartBalance      = 250.0;   // Balance where growth sizing and adds begin
input double GrowthRiskPct        = 10.0;    // Risk per position from AddStartBalance, % of balance
input bool   AllowAdds            = true;    // Add to winners from AddStartBalance
input string AddLevelsR           = "1,2,3,4"; // Add levels in R
input int    SlippagePoints       = 50;      // Maximum slippage, points

input group "Logging"
input bool   WriteTradeLog        = true;    // Write GoldNYSweep_trades.csv to Common\Files

enum DayState { WAIT_SETUP, WAIT_FILL, IN_TRADE, DONE };

CTrade   trade;
double   g_addLevels[];
datetime g_dayUtc      = 0;
DayState g_state       = WAIT_SETUP;
int      g_dir         = 0;
double   g_entry       = 0;
double   g_stop        = 0;
double   g_risk        = 0;
double   g_lots        = 0;
bool     g_addsOn      = false;
datetime g_readyUtc    = 0;
datetime g_lastBar     = 0;
bool     g_checkedGap  = false;

//+------------------------------------------------------------------+
//| Time helpers                                                     |
//+------------------------------------------------------------------+
datetime ToUtc(datetime server)   { return (datetime)((long)server - ServerUTCOffsetHours * 3600); }
datetime ToServer(datetime utc)   { return (datetime)((long)utc + ServerUTCOffsetHours * 3600); }
datetime NowUtc()                 { return ToUtc(TimeCurrent()); }
datetime DayStart(datetime t)     { return (datetime)((long)t - (long)t % 86400); }
int      IMax(int a, int b)       { return a > b ? a : b; }

int HourOf(datetime t)   { MqlDateTime s; TimeToStruct(t, s); return s.hour; }
int MinuteOf(datetime t) { MqlDateTime s; TimeToStruct(t, s); return s.min; }
int WeekdayOf(datetime t){ MqlDateTime s; TimeToStruct(t, s); return s.day_of_week; }

bool PastExit(datetime utc)
{
   int h = HourOf(utc), m = MinuteOf(utc);
   return h > ExitHour || (h == ExitHour && m >= ExitMinute);
}

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void LogTrade(string what, double price, double lots)
{
   PrintFormat("GoldNYSweep %s | %s %s entry=%.3f stop=%.3f risk=%.3f price=%.3f lots=%.2f",
               what, TimeToString(NowUtc(), TIME_DATE | TIME_MINUTES),
               g_dir == 1 ? "buy" : "sell", g_entry, g_stop, g_risk, price, lots);
   if(!WriteTradeLog)
      return;
   int f = FileOpen("GoldNYSweep_trades.csv", FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(f == INVALID_HANDLE)
      return;
   if(FileSize(f) == 0)
      FileWrite(f, "time_utc", "event", "direction", "entry", "stop", "risk", "price", "lots", "balance");
   FileSeek(f, 0, SEEK_END);
   FileWrite(f, TimeToString(NowUtc(), TIME_DATE | TIME_SECONDS), what, g_dir == 1 ? "buy" : "sell",
             DoubleToString(g_entry, 3), DoubleToString(g_stop, 3), DoubleToString(g_risk, 3),
             DoubleToString(price, 3), DoubleToString(lots, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   FileClose(f);
}

//+------------------------------------------------------------------+
//| Setup detection on completed 5-minute bars of the UTC day.       |
//| Mirrors find_setup2(mode="C") in research/05_realtime_check.     |
//| Returns 1 = setup ready, 0 = wait for more bars, -1 = no trade.  |
//+------------------------------------------------------------------+
double MedianBody(const MqlRates &b[], int j)
{
   int from = IMax(0, j - BodyMedianBars);
   int n = j - from;
   if(n < 5)
      return 0;
   double v[];
   ArrayResize(v, n);
   for(int x = 0; x < n; x++)
      v[x] = MathAbs(b[from + x].close - b[from + x].open);
   ArraySort(v);
   return (n % 2 == 1) ? v[n / 2] : (v[n / 2 - 1] + v[n / 2]) / 2.0;
}

bool IsSwing(const MqlRates &b[], int m, int sliceStart, int sliceEnd, int dir)
{
   if(m - 2 < sliceStart || m + 2 > sliceEnd)
      return false;
   if(dir == -1)   // sells break below a swing low
      return b[m].low < b[m - 1].low && b[m].low < b[m - 2].low &&
             b[m].low < b[m + 1].low && b[m].low < b[m + 2].low;
   return b[m].high > b[m - 1].high && b[m].high > b[m - 2].high &&
          b[m].high > b[m + 1].high && b[m].high > b[m + 2].high;
}

int ScanDay(const MqlRates &b[], int n, double lh, double ll, datetime nowUtc)
{
   for(int i = 0; i < n; i++)
   {
      int h = HourOf(ToUtc(b[i].time));
      if(h < SweepStartHour || h >= SweepEndHour)
         continue;
      for(int pass = 0; pass < 2; pass++)
      {
         int d = (pass == 0) ? -1 : 1;
         bool swept = (d == -1) ? b[i].high > lh : b[i].low < ll;
         if(!swept)
            continue;
         int sliceStart = IMax(0, i - SwingLookback - 2);
         int m = -1;
         for(int c = i - 1; c >= IMax(0, i - SwingLookback); c--)
            if(IsSwing(b, c, sliceStart, i, d)) { m = c; break; }
         if(m < 0)
            continue;
         double level   = (d == -1) ? b[m].low : b[m].high;
         double extreme = (d == -1) ? b[i].high : b[i].low;
         for(int j = i + 1; j <= i + MaxBreakBars; j++)
         {
            if(j >= n)
               return 0;                                  // break window still open
            extreme = (d == -1) ? MathMax(extreme, b[j].high) : MathMin(extreme, b[j].low);
            bool broke = (d == -1) ? b[j].close < level : b[j].close > level;
            double med = MedianBody(b, j);
            bool strong = med > 0 && MathAbs(b[j].close - b[j].open) >= DisplacementMult * med;
            if(!(broke && strong))
               continue;
            if(j + 1 >= n)
               return 0;                                  // wait for the bar after the break
            for(int k = j + 1; k > i; k--)
            {
               if(k - 2 < 0)
                  continue;
               bool gap = (d == -1) ? b[k - 2].low > b[k].high : b[k - 2].high < b[k].low;
               if(!gap)
                  continue;
               g_dir      = d;
               g_entry    = (d == -1) ? b[k].high : b[k].low;
               g_stop     = (d == -1) ? extreme + StopBufferUSD : extreme - StopBufferUSD;
               g_risk     = MathAbs(g_entry - g_stop);
               g_readyUtc = ToUtc(b[j].time) + 600;
               // a stop touch on the bar after the break cancels the setup
               if((d == -1 && b[j + 1].high >= g_stop) || (d == 1 && b[j + 1].low <= g_stop))
                  return -1;
               return 1;
            }
            return -1;                                    // break without a gap
         }
         return -1;                                       // no break in time
      }
   }
   return (HourOf(nowUtc) < SweepEndHour) ? 0 : -1;
}

int DetectSetup(datetime nowUtc)
{
   MqlRates r[];
   datetime from = ToServer(g_dayUtc);
   int n = CopyRates(_Symbol, PERIOD_M5, from, TimeCurrent(), r);
   if(n <= 0)
      return 0;
   // keep only completed bars of this UTC day
   int keep = 0;
   for(int x = 0; x < n; x++)
   {
      datetime u = ToUtc(r[x].time);
      if(u < g_dayUtc || u >= g_dayUtc + 86400)
         continue;
      if(r[x].time + PeriodSeconds(PERIOD_M5) > TimeCurrent())
         continue;
      r[keep++] = r[x];
   }
   ArrayResize(r, keep);
   double lh = -DBL_MAX, ll = DBL_MAX;
   int londonBars = 0;
   for(int x = 0; x < keep; x++)
   {
      int h = HourOf(ToUtc(r[x].time));
      if(h >= LondonStartHour && h < LondonEndHour)
      {
         lh = MathMax(lh, r[x].high);
         ll = MathMin(ll, r[x].low);
         londonBars++;
      }
   }
   if(HourOf(nowUtc) < LondonEndHour)
      return 0;
   if(londonBars < MinLondonBars)
      return -1;
   return ScanDay(r, keep, lh, ll, nowUtc);
}

//+------------------------------------------------------------------+
//| Position helpers                                                 |
//+------------------------------------------------------------------+
int CountPositions()
{
   int c = 0;
   for(int x = PositionsTotal() - 1; x >= 0; x--)
   {
      ulong t = PositionGetTicket(x);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         c++;
   }
   return c;
}

void CloseAll(string why)
{
   for(int x = PositionsTotal() - 1; x >= 0; x--)
   {
      ulong t = PositionGetTicket(x);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         trade.PositionClose(t);
   }
   LogTrade(why, SymbolInfoDouble(_Symbol, SYMBOL_BID), 0);
}

void MoveStops(double sl)
{
   sl = NormalizeDouble(sl, _Digits);
   for(int x = PositionsTotal() - 1; x >= 0; x--)
   {
      ulong t = PositionGetTicket(x);
      if(t > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         if(MathAbs(PositionGetDouble(POSITION_SL) - sl) > _Point / 2)
            trade.PositionModify(t, sl, 0);
   }
}

bool TradedToday()
{
   if(!HistorySelect(ToServer(g_dayUtc), TimeCurrent() + 60))
      return false;
   for(int x = HistoryDealsTotal() - 1; x >= 0; x--)
   {
      ulong d = HistoryDealGetTicket(x);
      if(HistoryDealGetString(d, DEAL_SYMBOL) == _Symbol && HistoryDealGetInteger(d, DEAL_MAGIC) == MagicNumber &&
         HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Sizing                                                           |
//+------------------------------------------------------------------+
double RoundLots(double lots)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lots = MathFloor(lots / step + 1e-9) * step;
   return MathMin(mx, MathMax(mn, lots));
}

// Lots for the first position, or 0 to skip. Also sets g_addsOn.
double SizeTrade()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double pnl = 0;
   ENUM_ORDER_TYPE type = (g_dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(type, _Symbol, 1.0, g_entry, g_stop, pnl) || pnl >= 0)
      return 0;
   double lossPerLot = -pnl;
   double lots;
   if(balance < AddStartBalance)
   {
      lots = RoundLots(SeedLots);
      g_addsOn = false;
   }
   else
   {
      lots = RoundLots(balance * GrowthRiskPct / 100.0 / lossPerLot);
      g_addsOn = AllowAdds;
   }
   if(lots * lossPerLot > balance)
      return 0;                                          // stop too wide for this balance
   return lots;
}

bool Open(double lots, double sl, string tag)
{
   double price = (g_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool ok = (g_dir == 1) ? trade.Buy(lots, _Symbol, 0, NormalizeDouble(sl, _Digits), 0, "GNS " + tag)
                          : trade.Sell(lots, _Symbol, 0, NormalizeDouble(sl, _Digits), 0, "GNS " + tag);
   if(ok && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED))
   {
      LogTrade(tag, trade.ResultPrice() > 0 ? trade.ResultPrice() : price, lots);
      return true;
   }
   PrintFormat("GoldNYSweep order failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
//| Day handling                                                     |
//+------------------------------------------------------------------+
void NewDay(datetime dayUtc)
{
   g_dayUtc = dayUtc;
   g_state = WAIT_SETUP;
   g_dir = 0; g_entry = 0; g_stop = 0; g_risk = 0; g_lots = 0;
   g_addsOn = false; g_readyUtc = 0; g_checkedGap = false;
   g_lastBar = 0;
   int wd = WeekdayOf(dayUtc);
   if(wd == 0 || wd == 6)
   {
      g_state = DONE;
      return;
   }
   // after a restart: recover today's trade from the chart and the account
   int open = CountPositions();
   if(open > 0 || TradedToday())
   {
      if(open > 0 && DetectSetup(NowUtc()) == 1)
      {
         g_state = IN_TRADE;
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         g_addsOn = AllowAdds && balance >= AddStartBalance;
         for(int x = PositionsTotal() - 1; x >= 0; x--)
         {
            ulong t = PositionGetTicket(x);
            if(t > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
               g_lots = PositionGetDouble(POSITION_VOLUME);
         }
      }
      else if(open > 0)
      {
         Print("GoldNYSweep: open positions found but today's setup could not be rebuilt; closing at exit time only.");
         g_state = IN_TRADE;
         g_addsOn = false;
      }
      else
         g_state = DONE;
   }
}

// On the first tick after the order time: if the bot was offline and price already
// reached the entry or the stop, skip the day rather than chase.
bool MissedWhileOffline()
{
   MqlRates m[];
   datetime nowMinute = (datetime)((long)TimeCurrent() - (long)TimeCurrent() % 60);
   int n = CopyRates(_Symbol, PERIOD_M1, ToServer(g_readyUtc), nowMinute - 1, m);
   for(int x = 0; x < n; x++)
   {
      if(m[x].time >= nowMinute)
         break;
      bool hitStop  = (g_dir == -1) ? m[x].high >= g_stop  : m[x].low <= g_stop;
      bool hitEntry = (g_dir == -1) ? m[x].high >= g_entry : m[x].low <= g_entry;
      if(hitStop || hitEntry)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert events                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   bool tester = (MQLInfoInteger(MQL_TESTER) != 0);
   if(_Period != PERIOD_M5)
      Print("GoldNYSweep works on 5-minute bars internally; any chart timeframe is fine.");
   string parts[];
   int n = StringSplit(AddLevelsR, ',', parts);
   ArrayResize(g_addLevels, 0);
   for(int x = 0; x < n; x++)
   {
      double v = StringToDouble(parts[x]);
      if(v > 0)
      {
         int s = ArraySize(g_addLevels);
         ArrayResize(g_addLevels, s + 1);
         g_addLevels[s] = v;
      }
   }
   ArraySort(g_addLevels);
   if(tester && WriteTradeLog)
      FileDelete("GoldNYSweep_trades.csv", FILE_COMMON);   // fresh log for every tester run
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_dayUtc = 0;
   return INIT_SUCCEEDED;
}

void OnTick()
{
   datetime nowUtc = NowUtc();
   datetime day = DayStart(nowUtc);
   if(day != g_dayUtc)
   {
      if(g_state == IN_TRADE && CountPositions() > 0)
         CloseAll("exit_day_change");
      NewDay(day);
   }
   if(g_state == DONE)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_state == WAIT_SETUP)
   {
      datetime bar = iTime(_Symbol, PERIOD_M5, 0);
      if(bar == g_lastBar)
         return;
      g_lastBar = bar;
      int r = DetectSetup(nowUtc);
      if(r < 0)
         g_state = DONE;
      else if(r == 1)
      {
         g_state = WAIT_FILL;
         LogTrade("setup", bid, 0);
      }
      if(g_state != WAIT_FILL)
         return;
   }

   if(g_state == WAIT_FILL)
   {
      if(nowUtc < g_readyUtc)
         return;
      if(HourOf(nowUtc) >= LastFillHour)
      {
         LogTrade("cancel_time", bid, 0);
         g_state = DONE;
         return;
      }
      if(!g_checkedGap)
      {
         g_checkedGap = true;
         if(MissedWhileOffline())
         {
            LogTrade("cancel_missed", bid, 0);
            g_state = DONE;
            return;
         }
      }
      bool hitStop  = (g_dir == -1) ? bid >= g_stop  : bid <= g_stop;
      bool hitEntry = (g_dir == -1) ? bid >= g_entry : bid <= g_entry;
      if(hitStop)
      {
         LogTrade("cancel_stop", bid, 0);
         g_state = DONE;
         return;
      }
      if(!hitEntry)
         return;
      g_lots = SizeTrade();
      if(g_lots <= 0)
      {
         LogTrade("skip_size", bid, 0);
         g_state = DONE;
         return;
      }
      if(Open(g_lots, g_stop, "entry"))
         g_state = IN_TRADE;
      else
         g_state = DONE;
      return;
   }

   if(g_state == IN_TRADE)
   {
      int open = CountPositions();
      if(open == 0)
      {
         LogTrade("closed", bid, 0);
         g_state = DONE;
         return;
      }
      if(PastExit(nowUtc))
      {
         CloseAll("exit_time");
         g_state = DONE;
         return;
      }
      if(!g_addsOn || g_risk <= 0)
         return;
      int done = open - 1;
      while(done < ArraySize(g_addLevels))
      {
         double target = g_entry + g_dir * g_addLevels[done] * g_risk;
         bool reached = (g_dir == 1) ? bid >= target : bid <= target;
         if(!reached)
            break;
         if(!Open(g_lots, g_entry, StringFormat("add%d", done + 1)))
            break;
         MoveStops(g_entry);
         done++;
      }
   }
}

void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
