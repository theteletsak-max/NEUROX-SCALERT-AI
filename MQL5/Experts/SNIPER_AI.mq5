//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_APEX_88                                              |
//| SNIPER AI — APEX ONLY (minimal, audited)                          |
//| Comment: SNIPER AI                                                |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "6.11"
#property description "SNIPER AI OK88: APEX-only minimal EA (line-audited fixes)"
#property description "BUILD SA_APEX_88 — stop normalize, swing bounds, fail throttle"

#include <Trade/Trade.mqh>
CTrade trade;

//---------------- inputs -------------------------------------------//
input group "GENERAL"
input long   MagicNumber  = 40001;
input string TradeComment = "SNIPER AI";

input group "APEX — ONLY ENTRY"
input bool   EnableAPEX              = true;
input ENUM_TIMEFRAMES APEX_BiasTF    = PERIOD_H4;
input ENUM_TIMEFRAMES EntryTF        = PERIOD_CURRENT;
input int    APEX_BiasMA_Period      = 200;
input int    APEX_SwingStrength      = 2;
input int    APEX_SwingLookback      = 40;
input int    APEX_PoolLookback       = 30;
input double APEX_EqualTolATR        = 0.12;
input int    APEX_SweepLookback      = 24;
input double APEX_MinSweepWickRatio  = 0.28;
input double APEX_MinSweepDepthATR   = 0.06;
input double APEX_DispMinBodyRatio   = 0.48;
input double APEX_DispMinATR         = 0.40;
input bool   APEX_BiasNeedStructOrMA = true;
input bool   APEX_RequireZone        = false;
input bool   APEX_RelaxedEntries     = true;
input bool   APEX_UseSweepSL         = true;
input double APEX_SL_BufferATR       = 0.12;
input double APEX_MaxSL_ATR          = 4.0;
input bool   APEX_Log                = true;

input group "SIZE & RISK"
input double LotSize           = 0.01;
input bool   UseFixedLot       = true;
input double RiskPercent       = 1.0;
input double MaxLotSizeHardCap = 5.0;
input int    MaxOpenTrades     = 1;
input int    SlippagePoints    = 30;
input int    ATR_Period        = 14;
input double SL_ATR_Mult       = 1.5;
input double TP_ATR_Mult       = 2.5;
input bool   UseBreakEven      = true;
input double BE_Trigger_R      = 1.0;
input bool   UseTrailing       = true;
input double Trail_ATR_Mult    = 1.2;
input int    TradeCooldownSec   = 15;

input group "DASHBOARD"
input bool EnableDashboard = true;
input int  DashboardRefreshMillis = 1000;

//---------------- state --------------------------------------------//
string   g_Sym = "";
datetime g_LastTradeTime = 0;
datetime g_LastFailTime  = 0;
long     g_LastDashMs = 0;
string   g_LastDetail = "-";
string   g_LastSide = "-";

//---------------- utils --------------------------------------------//
ENUM_TIMEFRAMES TF()
{
   return (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
}

double BidP(){ return SymbolInfoDouble(g_Sym, SYMBOL_BID); }
double AskP(){ return SymbolInfoDouble(g_Sym, SYMBOL_ASK); }
int    Digs(){ return (int)SymbolInfoInteger(g_Sym, SYMBOL_DIGITS); }
double PointP(){ return SymbolInfoDouble(g_Sym, SYMBOL_POINT); }

double PriceATR(const int period = 14)
{
   int p = MathMax(period, 5);
   if(Bars(g_Sym, TF()) < p + 3)
      return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= p; i++)
   {
      double h  = iHigh(g_Sym, TF(), i);
      double l  = iLow(g_Sym, TF(), i);
      double pc = iClose(g_Sym, TF(), i + 1);
      double tr = MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
      sum += tr;
   }
   return sum / p;
}

bool IsSwingHigh(const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(g_Sym, tf);
   if(bar - strength < 0 || bar + strength >= bars)
      return false;
   double h = iHigh(g_Sym, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iHigh(g_Sym, tf, bar - i) >= h || iHigh(g_Sym, tf, bar + i) >= h)
         return false;
   return true;
}

bool IsSwingLow(const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(g_Sym, tf);
   if(bar - strength < 0 || bar + strength >= bars)
      return false;
   double l = iLow(g_Sym, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iLow(g_Sym, tf, bar - i) <= l || iLow(g_Sym, tf, bar + i) <= l)
         return false;
   return true;
}

double BiasSMA()
{
   int p = MathMax(APEX_BiasMA_Period, 10);
   if(Bars(g_Sym, APEX_BiasTF) < p + 5)
      return 0.0;
   double s = 0.0;
   for(int i = 1; i <= p; i++)
      s += iClose(g_Sym, APEX_BiasTF, i);
   return s / p;
}

bool StructBull(string &d)
{
   ENUM_TIMEFRAMES tf = APEX_BiasTF;
   int lb = MathMax(APEX_SwingLookback, 20);
   int s  = MathMax(APEX_SwingStrength, 1);
   int sh1 = 0, sh2 = 0, sl1 = 0, sl2 = 0;
   for(int i = s + 1; i <= lb; i++)
   {
      if(sh1 == 0 && IsSwingHigh(tf, i, s)) sh1 = i;
      else if(sh1 > 0 && sh2 == 0 && IsSwingHigh(tf, i, s)) sh2 = i;
      if(sl1 == 0 && IsSwingLow(tf, i, s)) sl1 = i;
      else if(sl1 > 0 && sl2 == 0 && IsSwingLow(tf, i, s)) sl2 = i;
      if(sh1 > 0 && sh2 > 0 && sl1 > 0 && sl2 > 0)
         break;
   }
   if(sh1 == 0 || sh2 == 0 || sl1 == 0 || sl2 == 0)
   {
      d = "need BiasTF swings";
      return false;
   }
   bool ok = (iHigh(g_Sym, tf, sh1) > iHigh(g_Sym, tf, sh2)) &&
             (iLow(g_Sym, tf, sl1)  > iLow(g_Sym, tf, sl2));
   d = ok ? "BULL HH+HL" : "no HH+HL";
   return ok;
}

bool StructBear(string &d)
{
   ENUM_TIMEFRAMES tf = APEX_BiasTF;
   int lb = MathMax(APEX_SwingLookback, 20);
   int s  = MathMax(APEX_SwingStrength, 1);
   int sh1 = 0, sh2 = 0, sl1 = 0, sl2 = 0;
   for(int i = s + 1; i <= lb; i++)
   {
      if(sh1 == 0 && IsSwingHigh(tf, i, s)) sh1 = i;
      else if(sh1 > 0 && sh2 == 0 && IsSwingHigh(tf, i, s)) sh2 = i;
      if(sl1 == 0 && IsSwingLow(tf, i, s)) sl1 = i;
      else if(sl1 > 0 && sl2 == 0 && IsSwingLow(tf, i, s)) sl2 = i;
      if(sh1 > 0 && sh2 > 0 && sl1 > 0 && sl2 > 0)
         break;
   }
   if(sh1 == 0 || sh2 == 0 || sl1 == 0 || sl2 == 0)
   {
      d = "need BiasTF swings";
      return false;
   }
   bool ok = (iHigh(g_Sym, tf, sh1) < iHigh(g_Sym, tf, sh2)) &&
             (iLow(g_Sym, tf, sl1)  < iLow(g_Sym, tf, sl2));
   d = ok ? "BEAR LH+LL" : "no LH+LL";
   return ok;
}

bool BiasOK(const bool buy, string &d)
{
   string sd = "";
   bool st = buy ? StructBull(sd) : StructBear(sd);
   double sma = BiasSMA();
   double c1  = iClose(g_Sym, APEX_BiasTF, 1);
   bool ma = (sma > 0.0 && ((buy && c1 > sma) || (!buy && c1 < sma)));
   if(APEX_BiasNeedStructOrMA)
   {
      if(st || ma)
      {
         d = st ? sd : "MA bias";
         return true;
      }
      d = "need structure or MA";
      return false;
   }
   if(!st)
   {
      d = sd;
      return false;
   }
   d = sd;
   return true;
}

bool FindPool(const bool buy, double &pool)
{
   pool = 0.0;
   double atr = PriceATR(ATR_Period);
   if(atr <= 0.0)
      return false;
   double tol = atr * APEX_EqualTolATR;
   int lb = MathMax(APEX_PoolLookback, 10);
   ENUM_TIMEFRAMES tf = TF();
   if(Bars(g_Sym, tf) < lb + 2)
      return false;

   if(buy)
   {
      double lo = iLow(g_Sym, tf, iLowest(g_Sym, tf, MODE_LOW, lb, 1));
      int n = 0;
      for(int i = 1; i <= lb; i++)
         if(MathAbs(iLow(g_Sym, tf, i) - lo) <= tol)
            n++;
      if(n >= 2)
      {
         pool = lo;
         return true;
      }
   }
   else
   {
      double hi = iHigh(g_Sym, tf, iHighest(g_Sym, tf, MODE_HIGH, lb, 1));
      int n = 0;
      for(int i = 1; i <= lb; i++)
         if(MathAbs(iHigh(g_Sym, tf, i) - hi) <= tol)
            n++;
      if(n >= 2)
      {
         pool = hi;
         return true;
      }
   }
   return false;
}

bool SweepPool(const bool buy, const double pool, int &bar, double &ext)
{
   bar = 0;
   ext = 0.0;
   ENUM_TIMEFRAMES tf = TF();
   double atr = PriceATR(ATR_Period);
   double minD = (atr > 0.0) ? atr * APEX_MinSweepDepthATR : 0.0;
   int lb = MathMax(APEX_SweepLookback, 3);
   if(Bars(g_Sym, tf) < lb + 2)
      return false;

   for(int i = 1; i <= lb; i++)
   {
      double h = iHigh(g_Sym, tf, i);
      double l = iLow(g_Sym, tf, i);
      double c = iClose(g_Sym, tf, i);
      double rng = h - l;
      if(rng <= 0.0)
         continue;
      if(buy)
      {
         if(l < pool - minD && c > pool)
         {
            double wick = MathMin(c, pool) - l;
            if(wick / rng >= APEX_MinSweepWickRatio)
            {
               bar = i;
               ext = l;
               return true;
            }
         }
      }
      else if(h > pool + minD && c < pool)
      {
         double wick = h - MathMax(c, pool);
         if(wick / rng >= APEX_MinSweepWickRatio)
         {
            bar = i;
            ext = h;
            return true;
         }
      }
   }
   return false;
}

bool SwingSweep(const bool buy, double &pool, int &bar, double &ext)
{
   ENUM_TIMEFRAMES tf = TF();
   double atr = PriceATR(ATR_Period);
   double minD = (atr > 0.0) ? atr * APEX_MinSweepDepthATR : 0.0;
   int lb = MathMax(APEX_SweepLookback, 3);
   int bars = Bars(g_Sym, tf);
   if(bars < lb + 8)
      return false;

   for(int i = 1; i <= lb; i++)
   {
      double h = iHigh(g_Sym, tf, i);
      double l = iLow(g_Sym, tf, i);
      double c = iClose(g_Sym, tf, i);
      double rng = h - l;
      if(rng <= 0.0)
         continue;

      if(buy)
      {
         double prior = iLow(g_Sym, tf, i + 1);
         for(int j = i + 2; j <= i + 6; j++)
         {
            if(j >= bars)
               break;
            double x = iLow(g_Sym, tf, j);
            if(x > 0.0 && x < prior)
               prior = x;
         }
         if(l < prior - minD && c > prior)
         {
            double wick = MathMin(c, prior) - l;
            if(wick / rng >= APEX_MinSweepWickRatio)
            {
               bar = i;
               ext = l;
               pool = prior;
               return true;
            }
         }
      }
      else
      {
         double prior = iHigh(g_Sym, tf, i + 1);
         for(int j = i + 2; j <= i + 6; j++)
         {
            if(j >= bars)
               break;
            double x = iHigh(g_Sym, tf, j);
            if(x > prior)
               prior = x;
         }
         if(h > prior + minD && c < prior)
         {
            double wick = h - MathMax(c, prior);
            if(wick / rng >= APEX_MinSweepWickRatio)
            {
               bar = i;
               ext = h;
               pool = prior;
               return true;
            }
         }
      }
   }
   return false;
}

bool HasDisplacement(const bool buy)
{
   double o = iOpen(g_Sym, TF(), 1);
   double c = iClose(g_Sym, TF(), 1);
   double h = iHigh(g_Sym, TF(), 1);
   double l = iLow(g_Sym, TF(), 1);
   double rng = h - l;
   if(rng <= 0.0)
      return false;
   if(MathAbs(c - o) / rng < APEX_DispMinBodyRatio)
      return false;
   if(buy && c <= o)
      return false;
   if(!buy && c >= o)
      return false;
   double atr = PriceATR(ATR_Period);
   if(atr > 0.0 && rng < atr * APEX_DispMinATR)
      return false;
   return true;
}

bool HasZone(const bool buy)
{
   // Bullish FVG: low[1] > high[3]. Bearish FVG: high[1] < low[3].
   // OB proxy: opposite candle at [2] before displacement at [1].
   if(buy)
   {
      if(iLow(g_Sym, TF(), 1) > iHigh(g_Sym, TF(), 3))
         return true;
      double o2 = iOpen(g_Sym, TF(), 2);
      double c2 = iClose(g_Sym, TF(), 2);
      return (c2 < o2 && HasDisplacement(true));
   }
   if(iHigh(g_Sym, TF(), 1) < iLow(g_Sym, TF(), 3))
      return true;
   double o2 = iOpen(g_Sym, TF(), 2);
   double c2 = iClose(g_Sym, TF(), 2);
   return (c2 > o2 && HasDisplacement(false));
}

bool APEX_SetupOK(const bool buy, string &detail, double &inv)
{
   detail = "";
   inv = 0.0;
   if(!EnableAPEX)
   {
      detail = "disabled";
      return false;
   }
   if(Bars(g_Sym, APEX_BiasTF) < APEX_BiasMA_Period + 10)
   {
      detail = "BiasTF history";
      return false;
   }
   if(Bars(g_Sym, TF()) < APEX_PoolLookback + 10)
   {
      detail = "EntryTF history";
      return false;
   }

   string bd = "";
   if(!BiasOK(buy, bd))
   {
      detail = bd;
      return false;
   }

   double pool = 0.0;
   int sbar = 0;
   double sext = 0.0;
   bool swept = false;
   if(FindPool(buy, pool))
      swept = SweepPool(buy, pool, sbar, sext);
   if(!swept && APEX_RelaxedEntries)
      swept = SwingSweep(buy, pool, sbar, sext);
   if(!swept)
   {
      detail = buy ? "wait sell-side sweep" : "wait buy-side sweep";
      return false;
   }

   double c1 = iClose(g_Sym, TF(), 1);
   if(buy && c1 <= pool)
   {
      detail = "need reclaim";
      return false;
   }
   if(!buy && c1 >= pool)
   {
      detail = "need reclaim";
      return false;
   }
   if(!HasDisplacement(buy))
   {
      detail = "need displacement";
      return false;
   }

   bool zone = HasZone(buy);
   if(APEX_RequireZone && !zone)
   {
      detail = "need FVG/OB";
      return false;
   }

   double atr = PriceATR(ATR_Period);
   double buf = (atr > 0.0) ? atr * APEX_SL_BufferATR : 0.0;
   inv = buy ? (sext - buf) : (sext + buf);
   double px = buy ? AskP() : BidP();
   if(px > 0.0 && atr > 0.0 && MathAbs(px - inv) > atr * APEX_MaxSL_ATR)
   {
      detail = "SL too wide";
      return false;
   }

   detail = StringFormat("APEX %s %s pool=%s sweep@%d zone=%s",
                         buy ? "BUY" : "SELL", bd,
                         DoubleToString(pool, Digs()), sbar, zone ? "Y" : "N");
   return true;
}

//---------------- risk / exec --------------------------------------//
int CountOpen()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_Sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      n++;
   }
   return n;
}

double NormalizeVolume(double lots)
{
   double step = SymbolInfoDouble(g_Sym, SYMBOL_VOLUME_STEP);
   double amin = SymbolInfoDouble(g_Sym, SYMBOL_VOLUME_MIN);
   double amax = SymbolInfoDouble(g_Sym, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      step = 0.01;
   lots = MathFloor(lots / step + 1e-12) * step;
   if(lots < amin)
      lots = amin;
   if(lots > amax)
      lots = amax;
   if(lots > MaxLotSizeHardCap)
      lots = MaxLotSizeHardCap;
   int vdigits = 0;
   double s = step;
   while(vdigits < 8 && MathAbs(s - MathRound(s)) > 1e-8)
   {
      s *= 10.0;
      vdigits++;
   }
   return NormalizeDouble(lots, vdigits);
}

double CalcLot(const double slDist)
{
   if(UseFixedLot)
      return NormalizeVolume(LotSize);
   if(slDist <= 0.0)
      return NormalizeVolume(LotSize);

   double tickVal  = SymbolInfoDouble(g_Sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(g_Sym, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0)
      return NormalizeVolume(LotSize);

   double risk   = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double perLot = (slDist / tickSize) * tickVal;
   if(perLot <= 0.0)
      return NormalizeVolume(LotSize);
   return NormalizeVolume(risk / perLot);
}

bool AdjustStops(const bool buy, const double price, double &sl, double &tp)
{
   int stops = (int)SymbolInfoInteger(g_Sym, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze = (int)SymbolInfoInteger(g_Sym, SYMBOL_TRADE_FREEZE_LEVEL);
   int need = MathMax(stops, freeze);
   double minDist = need * PointP();
   if(minDist <= 0.0)
      minDist = PointP();

   if(buy)
   {
      if(sl > 0.0 && (price - sl) < minDist)
         sl = price - minDist;
      if(tp > 0.0 && (tp - price) < minDist)
         tp = price + minDist;
   }
   else
   {
      if(sl > 0.0 && (sl - price) < minDist)
         sl = price + minDist;
      if(tp > 0.0 && (price - tp) < minDist)
         tp = price - minDist;
   }

   sl = NormalizeDouble(sl, Digs());
   tp = NormalizeDouble(tp, Digs());

   if(buy && !(sl < price && tp > price))
      return false;
   if(!buy && !(sl > price && tp < price))
      return false;
   return true;
}

bool OpenTrade(const bool buy, const string detail, const double inv)
{
   if(CountOpen() >= MaxOpenTrades)
      return false;
   if(TimeCurrent() - g_LastTradeTime < TradeCooldownSec)
      return false;
   // Prevent tick-spam retries after broker rejects
   if(TimeCurrent() - g_LastFailTime < TradeCooldownSec)
      return false;

   double atr = PriceATR(ATR_Period);
   if(atr <= 0.0)
      return false;

   double price = buy ? AskP() : BidP();
   if(price <= 0.0)
      return false;

   double slDist = atr * SL_ATR_Mult;
   double sl = buy ? (price - slDist) : (price + slDist);
   double tp = buy ? (price + atr * TP_ATR_Mult) : (price - atr * TP_ATR_Mult);

   // Sweep invalidation: use if on correct side and farther than ATR floor (safer)
   if(APEX_UseSweepSL && inv > 0.0)
   {
      if(buy && inv < price && inv < sl)
         sl = inv;
      if(!buy && inv > price && inv > sl)
         sl = inv;
      slDist = MathAbs(price - sl);
   }

   if(!AdjustStops(buy, price, sl, tp))
   {
      Print("APEX stops invalid after broker min-distance adjust");
      g_LastFailTime = TimeCurrent();
      return false;
   }

   double lots = CalcLot(slDist);
   if(lots <= 0.0)
   {
      g_LastFailTime = TimeCurrent();
      return false;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(g_Sym);

   bool ok = false;
   for(int a = 0; a < 3 && !ok; a++)
   {
      ok = buy ? trade.Buy(lots, g_Sym, 0, sl, tp, TradeComment)
               : trade.Sell(lots, g_Sym, 0, sl, tp, TradeComment);
   }

   if(ok)
   {
      g_LastTradeTime = TimeCurrent();
      g_LastDetail = detail;
      g_LastSide = buy ? "BUY" : "SELL";
      Print("APEX FIRE ", g_LastSide, " lots=", lots,
            " sl=", DoubleToString(sl, Digs()),
            " tp=", DoubleToString(tp, Digs()),
            " — ", detail);
   }
   else
   {
      g_LastFailTime = TimeCurrent();
      Print("APEX order fail ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
   return ok;
}

void ManageOpen()
{
   double atr = PriceATR(ATR_Period);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_Sym)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long   type = PositionGetInteger(POSITION_TYPE);
      double price = (type == POSITION_TYPE_BUY) ? BidP() : AskP();
      double risk = MathAbs(open - sl);
      if(risk <= 0.0 && atr > 0.0)
         risk = atr * SL_ATR_Mult;

      if(UseBreakEven && risk > 0.0)
      {
         if(type == POSITION_TYPE_BUY && price >= open + risk * BE_Trigger_R && (sl < open || sl == 0.0))
            trade.PositionModify(ticket, NormalizeDouble(open, Digs()), tp);
         if(type == POSITION_TYPE_SELL && price <= open - risk * BE_Trigger_R && (sl > open || sl == 0.0))
            trade.PositionModify(ticket, NormalizeDouble(open, Digs()), tp);
      }

      if(UseTrailing && atr > 0.0)
      {
         double trail = atr * Trail_ATR_Mult;
         if(type == POSITION_TYPE_BUY)
         {
            double nsl = NormalizeDouble(price - trail, Digs());
            if(nsl > sl && nsl < price)
               trade.PositionModify(ticket, nsl, tp);
         }
         else
         {
            double nsl = NormalizeDouble(price + trail, Digs());
            if((sl == 0.0 || nsl < sl) && nsl > price)
               trade.PositionModify(ticket, nsl, tp);
         }
      }
   }
}

void Dash()
{
   if(!EnableDashboard)
      return;
   long now = (long)GetTickCount();
   if(now - g_LastDashMs < DashboardRefreshMillis)
      return;
   g_LastDashMs = now;
   Comment(
      "===== SNIPER AI APEX =====\n",
      g_Sym, " | ", EnumToString(TF()), " | Bias ", EnumToString(APEX_BiasTF), "\n",
      "Last: ", g_LastSide, "\n",
      StringSubstr(g_LastDetail, 0, 100), "\n",
      "Open: ", IntegerToString(CountOpen()), "\n",
      "BUILD SA_APEX_88 | Comment SNIPER AI\n",
      "=========================="
   );
}

void Evaluate()
{
   if(!EnableAPEX)
      return;
   if(Bars(g_Sym, TF()) < APEX_PoolLookback + 20)
      return;

   string db = "", ds = "";
   double ib = 0.0, isell = 0.0;
   bool buy  = APEX_SetupOK(true, db, ib);
   bool sell = APEX_SetupOK(false, ds, isell);

   if(buy && sell)
   {
      double sma = BiasSMA();
      double c1  = iClose(g_Sym, APEX_BiasTF, 1);
      if(sma > 0.0 && c1 > sma)
         sell = false;
      else if(sma > 0.0 && c1 < sma)
         buy = false;
      else
      {
         buy = false;
         sell = false;
      }
   }

   if(buy)
   {
      OpenTrade(true, db, ib);
      return;
   }
   if(sell)
   {
      OpenTrade(false, ds, isell);
      return;
   }

   if(APEX_Log)
   {
      static datetime lastBar = 0;
      datetime bt = iTime(g_Sym, TF(), 0);
      if(bt != lastBar)
      {
         lastBar = bt;
         g_LastDetail = "wait BUY[" + db + "] SELL[" + ds + "]";
         Print("APEX ", g_LastDetail);
      }
   }
}

int OnInit()
{
   g_Sym = _Symbol;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(g_Sym);
   Print("SNIPER AI Loaded BUILD_ID=SA_APEX_88 — APEX ONLY (AUDITED)");
   Print("Fixes: swing bounds, stop normalize, volume step, fail throttle");
   Print("CRITICAL: SOURCE SNIPER_AI_OK88 | Comment=", TradeComment);
   Dash();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){ Comment(""); }

void OnTick()
{
   ManageOpen();
   Evaluate();
   Dash();
}
//+------------------------------------------------------------------+
