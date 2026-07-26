//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| SNIPER AI — institutional single-file Expert Advisor              |
//|                                                                   |
//| Engines: Util / Config / Symbol / MarketData / Swing / Structure  |
//| Liquidity / Displacement / FVG / OB / Volatility / Entry          |
//| Decision / Risk / Money / Position / Execution / Statistics       |
//| System Core                                                       |
//|                                                                   |
//| Strategy: H4 bias → H1 setup → M5 confirm                         |
//| Paths: Continuation + Reversal | Comment: SNIPER AI               |
//| Install: copy to MQL5/Experts/ → F7 → attach chart                |
//+------------------------------------------------------------------+
#property copyright   "SNIPER AI"
#property link        "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version     "1.00"
#property description "SNIPER AI — institutional sniper EA (H4/H1/M5)"
#property description "24/7 adaptive execution. No session/news blocks."

#include <Trade/Trade.mqh>

#define SA_COMMENT     "SNIPER AI"
#define SA_LOG_PREFIX  "SNIPER AI | "
#define SA_H4_BARS     160
#define SA_H1_BARS     160
#define SA_M5_BARS     48
#define SA_ATR_PERIOD  14
#define SA_ATR_AVG_N   40
#define SA_SWING_KEEP  24
#define SA_STRUCT_LOOKBACK  20
#define SA_ZONE_LOOKBACK    24
#define SA_LIQ_LOOKBACK     12
#define SA_DISP_LOOKBACK    16

//==================================================================
// TYPES
//==================================================================
enum ENUM_SA_BIAS
  {
   SA_BIAS_FLAT = 0,
   SA_BIAS_BULL = 1,
   SA_BIAS_BEAR = 2
  };

enum ENUM_SA_SIDE
  {
   SA_SIDE_NONE = 0,
   SA_SIDE_BUY  = 1,
   SA_SIDE_SELL = 2
  };

enum ENUM_SA_PATH
  {
   SA_PATH_NONE = 0,
   SA_PATH_CONTINUATION = 1,
   SA_PATH_REVERSAL = 2
  };

enum ENUM_SA_MKT
  {
   SA_MKT_LOW = 0,
   SA_MKT_NORMAL = 1,
   SA_MKT_HIGH = 2,
   SA_MKT_EXTREME = 3
  };

enum ENUM_SA_STAGE
  {
   SA_STAGE_INIT = 0,
   SA_STAGE_DATA = 1,
   SA_STAGE_ANALYSIS = 2,
   SA_STAGE_DECISION = 3,
   SA_STAGE_RISK = 4,
   SA_STAGE_EXEC = 5,
   SA_STAGE_MANAGE = 6,
   SA_STAGE_SCAN = 7
  };

struct SaSwing
  {
   datetime time;
   double   price;
   int      bar;
   bool     isHigh;
  };

struct SaStructure
  {
   ENUM_SA_BIAS biasH4;
   bool         bosBull;
   bool         bosBear;
   bool         chochBull;
   bool         chochBear;
   double       swingHigh;
   double       swingLow;
   string       note;
  };

struct SaLiquidity
  {
   bool   buySideSweep;
   bool   sellSideSweep;
   bool   equalHighs;
   bool   equalLows;
   double poolHigh;
   double poolLow;
   int    score;
   string note;
  };

struct SaDisplacement
  {
   bool   bull;
   bool   bear;
   int    impulseBar;
   int    score;
   string note;
  };

struct SaFVG
  {
   bool   bull;
   bool   bear;
   bool   fresh;
   double lo;
   double hi;
   int    score;
   string note;
  };

struct SaOB
  {
   bool   bull;
   bool   bear;
   double lo;
   double hi;
   int    score;
   string note;
  };

struct SaZones
  {
   bool   bullDisp;
   bool   bearDisp;
   bool   bullFVG;
   bool   bearFVG;
   bool   bullOB;
   bool   bearOB;
   bool   bullZoneTouch;
   bool   bearZoneTouch;
   double zoneLo;
   double zoneHi;
   int    score;
   string note;
  };

struct SaSetup
  {
   ENUM_SA_SIDE side;
   ENUM_SA_PATH path;
   ENUM_SA_BIAS bias;
   ENUM_SA_MKT  mkt;
   int          score;
   int          confluence;
   string       reason;
   double       atrH1;
   double       spreadPts;
  };

//==================================================================
// INPUTS (plain input — portable across MT5 builds)
//==================================================================
input double InpLot                 = 0.01;
input int    InpMaxTrades           = 3;
input long   InpMagic               = 20260726;
input int    InpMaxSlippagePoints   = 100;
input int    InpMaxRetries          = 3;

input int    InpSwingStrength       = 2;
input int    InpMinScore            = 8;
input int    InpMinConfluence       = 3;
input bool   InpAllowContinuation   = true;
input bool   InpAllowReversal       = true;
input bool   InpRequireZoneTouch    = false;
input bool   InpOneEntryPerM5       = true;
input bool   InpTradeChartOnly      = true;

input double InpAtrMultSL           = 1.5;
input double InpRewardRatio         = 2.0;
input double InpBreakEvenR          = 1.0;
input bool   InpUseTrailing         = false;
input double InpTrailStartR         = 1.5;
input double InpTrailStepR          = 0.5;
input double InpMaxDailyDDPercent   = 0.0;
input int    InpMaxConsecutiveLoss  = 0;

input double InpHighVolAtrMult      = 1.8;
input double InpExtremeVolAtrMult   = 2.5;
input double InpVolSLBoostHigh      = 1.15;
input double InpVolSLBoostExtreme   = 1.35;
input double InpWideSpreadAtrFrac   = 0.12;

input bool   InpLogEvents           = true;

//==================================================================
// UTIL / LOGGING
//==================================================================
void SaLog(const string msg)
  {
   if(InpLogEvents)
      Print(SA_LOG_PREFIX, msg);
  }

int SaClampInt(const int v, const int lo, const int hi)
  {
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
  }

double SaBody(const MqlRates &r)
  {
   return MathAbs(r.close - r.open);
  }

//==================================================================
// CONFIG
//==================================================================
class CSaConfig
  {
public:
   bool Validate(string &why)
     {
      if(InpLot <= 0.0) { why = "lot<=0"; return false; }
      if(InpMaxTrades < 1) { why = "max trades<1"; return false; }
      if(InpAtrMultSL <= 0.0 || InpRewardRatio <= 0.0) { why = "SL/TP invalid"; return false; }
      if(InpMinScore < 0 || InpMinConfluence < 1) { why = "score/confluence invalid"; return false; }
      if(InpMaxSlippagePoints < 0 || InpMaxRetries < 1) { why = "exec params invalid"; return false; }
      why = "ok";
      return true;
     }
  };

//==================================================================
// SYMBOL MANAGER
//==================================================================
class CSaSymbolManager
  {
public:
   string symbol;
   int    digits;
   int    stopsLevel;
   int    freezeLevel;
   double point;
   double tickSize;
   double tickValue;
   double volMin;
   double volMax;
   double volStep;
   ENUM_SYMBOL_TRADE_MODE tradeMode;

   bool Init(const string sym)
     {
      symbol = sym;
      if(!SymbolSelect(symbol, true))
         return false;
      return RefreshSpecs();
     }

   bool RefreshSpecs()
     {
      digits      = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
      tickSize    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      tickValue   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      volMin      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      volMax      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      volStep     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      stopsLevel  = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      tradeMode   = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      if(volStep <= 0.0) volStep = 0.01;
      return (point > 0.0);
     }

   double Pip()
     {
      if(digits == 3 || digits == 5)
         return point * 10.0;
      return point;
     }

   double NormPrice(const double price)
     {
      return NormalizeDouble(price, digits);
     }

   double NormVol(double lots)
     {
      lots = MathFloor(lots / volStep + 1e-12) * volStep;
      if(lots < volMin) lots = volMin;
      if(lots > volMax) lots = volMax;
      const int d = (volStep < 0.01 ? 3 : 2);
      return NormalizeDouble(lots, d);
     }

   bool TradeAllowed(string &why)
     {
      tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
        { why = "symbol trade disabled"; return false; }
      // CLOSEONLY / LONGONLY / SHORTONLY still allow directional handling at order time
      why = "ok";
      return true;
     }

   void Quotes(double &bid, double &ask)
     {
      bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
     }
  };

//==================================================================
// MARKET DATA + INDICATOR MANAGER
//==================================================================
class CSaMarketData
  {
private:
   string   m_symbol;
   int      m_atrHandle;
   datetime m_h4Bar;
   datetime m_h1Bar;
   datetime m_m5Bar;
   datetime m_atrBar;
   MqlRates m_h4[];
   MqlRates m_h1[];
   MqlRates m_m5[];
   double   m_atrBuf[];
   double   m_atr;
   double   m_atrAvg;
   bool     m_ready;

   bool CopyTF(const ENUM_TIMEFRAMES tf, const int count, MqlRates &dst[], datetime &stamp)
     {
      datetime t[];
      if(CopyTime(m_symbol, tf, 0, 1, t) != 1)
         return false;
      if(t[0] == stamp && ArraySize(dst) >= count)
         return true;
      ArraySetAsSeries(dst, true);
      if(CopyRates(m_symbol, tf, 0, count, dst) < count)
         return false;
      stamp = t[0];
      return true;
     }

   bool RefreshATR()
     {
      if(m_atrHandle == INVALID_HANDLE)
         return false;
      // ATR updates with H1 bar — skip buffer copy when H1 stamp unchanged
      if(m_atrBar == m_h1Bar && m_atr > 0.0)
         return true;
      ArraySetAsSeries(m_atrBuf, true);
      if(CopyBuffer(m_atrHandle, 0, 1, SA_ATR_AVG_N, m_atrBuf) < SA_ATR_AVG_N)
         return false;
      m_atr = m_atrBuf[0];
      double sum = 0.0;
      for(int i = 0; i < SA_ATR_AVG_N; i++)
         sum += m_atrBuf[i];
      m_atrAvg = sum / (double)SA_ATR_AVG_N;
      m_atrBar = m_h1Bar;
      return (m_atr > 0.0);
     }

public:
                     CSaMarketData(void): m_atrHandle(INVALID_HANDLE), m_h4Bar(0), m_h1Bar(0),
                                          m_m5Bar(0), m_atrBar(0), m_atr(0.0), m_atrAvg(0.0), m_ready(false) {}
                    ~CSaMarketData(void) { Release(); }

   bool Init(const string symbol)
     {
      Release();
      m_symbol = symbol;
      m_atrHandle = iATR(m_symbol, PERIOD_H1, SA_ATR_PERIOD);
      m_ready = false;
      return (m_atrHandle != INVALID_HANDLE);
     }

   void Release()
     {
      if(m_atrHandle != INVALID_HANDLE)
        {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
        }
      m_ready = false;
     }

   bool Refresh()
     {
      if(!CopyTF(PERIOD_H4, SA_H4_BARS, m_h4, m_h4Bar)) { m_ready = false; return false; }
      if(!CopyTF(PERIOD_H1, SA_H1_BARS, m_h1, m_h1Bar)) { m_ready = false; return false; }
      if(!CopyTF(PERIOD_M5, SA_M5_BARS, m_m5, m_m5Bar)) { m_ready = false; return false; }
      if(!RefreshATR()) { m_ready = false; return false; }
      m_ready = true;
      return true;
     }

   bool Ready() { return m_ready; }

   bool NewM5Bar(datetime &last)
     {
      if(ArraySize(m_m5) < 2)
         return false;
      const datetime t = m_m5[0].time;
      if(t != last)
        {
         last = t;
         return true;
        }
      return false;
     }

   bool CopyRatesOut(const MqlRates &src[], MqlRates &out[])
     {
      const int n = ArraySize(src);
      if(n <= 0) return false;
      ArraySetAsSeries(out, true);
      if(ArrayResize(out, n) < 0) return false;
      for(int i = 0; i < n; i++)
         out[i] = src[i];
      return true;
     }

   bool H4(MqlRates &out[]) { return CopyRatesOut(m_h4, out); }
   bool H1(MqlRates &out[]) { return CopyRatesOut(m_h1, out); }
   bool M5(MqlRates &out[]) { return CopyRatesOut(m_m5, out); }

   int H4Count() { return ArraySize(m_h4); }
   int H1Count() { return ArraySize(m_h1); }
   int M5Count() { return ArraySize(m_m5); }

   double Atr() { return m_atr; }
   double AtrAvg() { return m_atrAvg; }
   datetime M5BarTime() { return m_m5Bar; }
  };

//==================================================================
// SWING ENGINE
//==================================================================
class CSaSwingEngine
  {
private:
   int m_strength;

public:
                     CSaSwingEngine(void): m_strength(2) {}
   void              SetStrength(const int s) { m_strength = SaClampInt(s, 1, 5); }

   void Collect(const MqlRates &r[], const int n, SaSwing &swings[], const int maxKeep)
     {
      ArrayResize(swings, 0);
      if(n < (m_strength * 2 + 3))
         return;

      // series index 0 = forming. Confirmed pivots require right side closed.
      for(int i = m_strength + 1; i < n - m_strength; i++)
        {
         bool hi = true;
         bool lo = true;
         for(int k = 1; k <= m_strength; k++)
           {
            if(r[i].high <= r[i - k].high || r[i].high <= r[i + k].high) hi = false;
            if(r[i].low >= r[i - k].low || r[i].low >= r[i + k].low) lo = false;
            if(!hi && !lo) break;
           }
         if(hi)
           {
            const int sz = ArraySize(swings);
            ArrayResize(swings, sz + 1);
            swings[sz].time = r[i].time;
            swings[sz].price = r[i].high;
            swings[sz].bar = i;
            swings[sz].isHigh = true;
           }
         if(lo)
           {
            const int sz = ArraySize(swings);
            ArrayResize(swings, sz + 1);
            swings[sz].time = r[i].time;
            swings[sz].price = r[i].low;
            swings[sz].bar = i;
            swings[sz].isHigh = false;
           }
         if(ArraySize(swings) >= maxKeep)
            break;
        }
     }

   ENUM_SA_BIAS BiasFromSwings(const SaSwing &swings[])
     {
      double h1 = 0, h2 = 0, l1 = 0, l2 = 0;
      int hc = 0, lc = 0;
      for(int i = 0; i < ArraySize(swings); i++)
        {
         if(swings[i].isHigh)
           {
            if(hc == 0) { h1 = swings[i].price; hc++; }
            else if(hc == 1) { h2 = swings[i].price; hc++; }
           }
         else
           {
            if(lc == 0) { l1 = swings[i].price; lc++; }
            else if(lc == 1) { l2 = swings[i].price; lc++; }
           }
         if(hc >= 2 && lc >= 2)
            break;
        }
      if(hc < 2 || lc < 2)
         return SA_BIAS_FLAT;

      const bool hh = (h1 > h2);
      const bool hl = (l1 > l2);
      const bool lh = (h1 < h2);
      const bool ll = (l1 < l2);

      if(hh && hl) return SA_BIAS_BULL;
      if(lh && ll) return SA_BIAS_BEAR;
      if(hh && !ll) return SA_BIAS_BULL;
      if(ll && !hh) return SA_BIAS_BEAR;
      return SA_BIAS_FLAT;
     }

   bool LatestHighLow(const SaSwing &swings[], double &hi, double &lo)
     {
      hi = 0.0;
      lo = 0.0;
      for(int i = 0; i < ArraySize(swings); i++)
        {
         if(swings[i].isHigh && hi == 0.0)
            hi = swings[i].price;
         if(!swings[i].isHigh && lo == 0.0)
            lo = swings[i].price;
         if(hi > 0.0 && lo > 0.0)
            return true;
        }
      return false;
     }
  };

//==================================================================
// STRUCTURE ENGINE (BOS / CHoCH / H4 bias)
//==================================================================
class CSaStructureEngine
  {
private:
   CSaSwingEngine m_swing;

   double SwingHighBefore(const SaSwing &swings[], const int barExclusive)
     {
      // newest-first swings: first high with bar > break bar is the prior swing high
      for(int i = 0; i < ArraySize(swings); i++)
        {
         if(!swings[i].isHigh)
            continue;
         if(swings[i].bar <= barExclusive)
            continue;
         return swings[i].price;
        }
      return 0.0;
     }

   double SwingLowBefore(const SaSwing &swings[], const int barExclusive)
     {
      for(int i = 0; i < ArraySize(swings); i++)
        {
         if(swings[i].isHigh)
            continue;
         if(swings[i].bar <= barExclusive)
            continue;
         return swings[i].price;
        }
      return 0.0;
     }

public:
   void SetStrength(const int s) { m_swing.SetStrength(s); }

   SaStructure Evaluate(const MqlRates &h4[], const int h4n,
                        const MqlRates &h1[], const int h1n)
     {
      SaStructure st;
      st.biasH4 = SA_BIAS_FLAT;
      st.bosBull = false;
      st.bosBear = false;
      st.chochBull = false;
      st.chochBear = false;
      st.swingHigh = 0.0;
      st.swingLow = 0.0;
      st.note = "structure";

      SaSwing sw4[];
      m_swing.Collect(h4, h4n, sw4, SA_SWING_KEEP);
      st.biasH4 = m_swing.BiasFromSwings(sw4);

      SaSwing sw1[];
      m_swing.Collect(h1, h1n, sw1, SA_SWING_KEEP);
      m_swing.LatestHighLow(sw1, st.swingHigh, st.swingLow);

      if(h1n < 5)
         return st;

      // Persist BOS/CHoCH across pullback window (non-repainting closed bars only)
      const int lb = MathMin(SA_STRUCT_LOOKBACK, h1n - 2);
      for(int i = 1; i <= lb; i++)
        {
         const double sh = SwingHighBefore(sw1, i);
         const double sl = SwingLowBefore(sw1, i);
         if(sh > 0.0 && h1[i].close > sh)
           {
            if(st.biasH4 == SA_BIAS_BULL || st.biasH4 == SA_BIAS_FLAT)
               st.bosBull = true;
            if(st.biasH4 == SA_BIAS_BEAR)
               st.chochBull = true;
           }
         if(sl > 0.0 && h1[i].close < sl)
           {
            if(st.biasH4 == SA_BIAS_BEAR || st.biasH4 == SA_BIAS_FLAT)
               st.bosBear = true;
            if(st.biasH4 == SA_BIAS_BULL)
               st.chochBear = true;
           }
        }

      if(st.bosBull) st.note = "BOS bullish";
      else if(st.bosBear) st.note = "BOS bearish";
      else if(st.chochBull) st.note = "CHoCH bullish";
      else if(st.chochBear) st.note = "CHoCH bearish";
      else st.note = "awaiting break";
      return st;
     }
  };

//==================================================================
// LIQUIDITY ENGINE
//==================================================================
class CSaLiquidityEngine
  {
public:
   SaLiquidity Evaluate(const MqlRates &r[], const int n, const double pip, const double atr)
     {
      SaLiquidity liq;
      liq.buySideSweep = false;
      liq.sellSideSweep = false;
      liq.equalHighs = false;
      liq.equalLows = false;
      liq.poolHigh = 0.0;
      liq.poolLow = 0.0;
      liq.score = 0;
      liq.note = "liquidity";
      if(n < 20 || pip <= 0.0 || atr <= 0.0)
         return liq;

      const double tol = MathMax(pip * 2.0, atr * 0.05);
      const int poolN = MathMin(n, 50);

      liq.poolHigh = r[2].high;
      liq.poolLow  = r[2].low;
      for(int i = 2; i < poolN; i++)
        {
         if(r[i].high > liq.poolHigh) liq.poolHigh = r[i].high;
         if(r[i].low < liq.poolLow) liq.poolLow = r[i].low;
        }

      int eqH = 0, eqL = 0;
      const double refH = r[2].high;
      const double refL = r[2].low;
      for(int i = 3; i < MathMin(n, 30); i++)
        {
         if(MathAbs(r[i].high - refH) <= tol) eqH++;
         if(MathAbs(r[i].low - refL) <= tol) eqL++;
        }
      liq.equalHighs = (eqH >= 1);
      liq.equalLows  = (eqL >= 1);
      if(liq.equalHighs) liq.score += 1;
      if(liq.equalLows)  liq.score += 1;

      // Recent pierce+reclaim sweeps (persist across a few bars)
      const int lb = MathMin(SA_LIQ_LOOKBACK, n - 4);
      for(int i = 1; i <= lb; i++)
        {
         double rh = r[i + 2].high;
         double rl = r[i + 2].low;
         for(int j = i + 2; j < MathMin(n, i + 14); j++)
           {
            if(r[j].high > rh) rh = r[j].high;
            if(r[j].low < rl) rl = r[j].low;
           }
         if(r[i].high > rh + tol * 0.25 && r[i].close < rh)
           {
            liq.buySideSweep = true;
            liq.score += 3;
            liq.note = "buy-side sweep";
            break;
           }
         if(r[i].low < rl - tol * 0.25 && r[i].close > rl)
           {
            liq.sellSideSweep = true;
            liq.score += 3;
            liq.note = "sell-side sweep";
            break;
           }
        }
      if(!liq.buySideSweep && !liq.sellSideSweep)
         liq.note = (liq.equalHighs || liq.equalLows) ? "eq liquidity" : "mapping";
      return liq;
     }
  };

//==================================================================
// DISPLACEMENT ENGINE
//==================================================================
class CSaDisplacementEngine
  {
   bool IsBullImpulse(const MqlRates &r[], const int i, const int n)
     {
      if(i + 3 >= n) return false;
      if(r[i].close <= r[i].open) return false;
      const double b = SaBody(r[i]);
      const double avg = (SaBody(r[i + 1]) + SaBody(r[i + 2]) + SaBody(r[i + 3])) / 3.0;
      double base = avg;
      if(base <= 0.0) base = MathMax(b, r[i].high - r[i].low);
      return (b >= base * 1.6);
     }

   bool IsBearImpulse(const MqlRates &r[], const int i, const int n)
     {
      if(i + 3 >= n) return false;
      if(r[i].close >= r[i].open) return false;
      const double b = SaBody(r[i]);
      const double avg = (SaBody(r[i + 1]) + SaBody(r[i + 2]) + SaBody(r[i + 3])) / 3.0;
      double base = avg;
      if(base <= 0.0) base = MathMax(b, r[i].high - r[i].low);
      return (b >= base * 1.6);
     }

public:
   SaDisplacement Evaluate(const MqlRates &r[], const int n)
     {
      SaDisplacement d;
      d.bull = false;
      d.bear = false;
      d.impulseBar = 0;
      d.score = 0;
      d.note = "no displacement";
      if(n < 8)
         return d;

      const int lb = MathMin(SA_DISP_LOOKBACK, n - 4);
      for(int i = 1; i <= lb; i++)
        {
         if(IsBullImpulse(r, i, n))
           {
            d.bull = true;
            d.impulseBar = i;
            d.score = 2;
            d.note = "bull displacement";
            return d;
           }
         if(IsBearImpulse(r, i, n))
           {
            d.bear = true;
            d.impulseBar = i;
            d.score = 2;
            d.note = "bear displacement";
            return d;
           }
        }
      return d;
     }
  };

//==================================================================
// FAIR VALUE GAP ENGINE
//==================================================================
class CSaFVGEngine
  {
   bool BullFilled(const MqlRates &r[], const int createdAt, const double lo, const double hi)
     {
      if(hi <= lo) return true;
      // Mitigated if a later closed bar trades fully through the gap low
      for(int j = 1; j < createdAt; j++)
        {
         if(r[j].low <= lo)
            return true;
        }
      return false;
     }

   bool BearFilled(const MqlRates &r[], const int createdAt, const double lo, const double hi)
     {
      if(hi <= lo) return true;
      for(int j = 1; j < createdAt; j++)
        {
         if(r[j].high >= hi)
            return true;
        }
      return false;
     }

public:
   SaFVG Evaluate(const MqlRates &r[], const int n)
     {
      SaFVG f;
      f.bull = false;
      f.bear = false;
      f.fresh = false;
      f.lo = 0.0;
      f.hi = 0.0;
      f.score = 0;
      f.note = "no fvg";
      if(n < 8)
         return f;

      const int lb = MathMin(SA_ZONE_LOOKBACK, n - 4);
      for(int i = 1; i <= lb; i++)
        {
         // 3-candle FVG ending at closed bar i : [i+2], [i+1], [i]
         if(r[i + 2].high < r[i].low)
           {
            const double lo = r[i + 2].high;
            const double hi = r[i].low;
            if(!BullFilled(r, i, lo, hi))
              {
               f.bull = true;
               f.fresh = true;
               f.lo = lo;
               f.hi = hi;
               f.score = 3;
               f.note = "bull FVG fresh";
               return f;
              }
           }
         if(r[i + 2].low > r[i].high)
           {
            const double lo = r[i].high;
            const double hi = r[i + 2].low;
            if(!BearFilled(r, i, lo, hi))
              {
               f.bear = true;
               f.fresh = true;
               f.lo = lo;
               f.hi = hi;
               f.score = 3;
               f.note = "bear FVG fresh";
               return f;
              }
           }
        }
      return f;
     }
  };

//==================================================================
// ORDER BLOCK ENGINE
//==================================================================
class CSaOBEngine
  {
public:
   SaOB Evaluate(const MqlRates &r[], const int n, const SaDisplacement &disp)
     {
      SaOB ob;
      ob.bull = false;
      ob.bear = false;
      ob.lo = 0.0;
      ob.hi = 0.0;
      ob.score = 0;
      ob.note = "no ob";
      if(n < 8)
         return ob;

      const int impulse = (disp.impulseBar > 0 ? disp.impulseBar : 1);

      if(disp.bull)
        {
         for(int i = impulse + 1; i <= impulse + 6 && i < n; i++)
           {
            if(r[i].close < r[i].open)
              {
               ob.bull = true;
               ob.lo = r[i].low;
               ob.hi = r[i].high;
               // invalidate if fully mitigated after impulse
               bool dead = false;
               for(int j = 1; j < impulse; j++)
                 {
                  if(r[j].low <= ob.lo)
                    { dead = true; break; }
                 }
               if(!dead)
                 {
                  ob.score = 2;
                  ob.note = "bull OB";
                  return ob;
                 }
               ob.bull = false;
              }
           }
        }
      if(disp.bear)
        {
         for(int i = impulse + 1; i <= impulse + 6 && i < n; i++)
           {
            if(r[i].close > r[i].open)
              {
               ob.bear = true;
               ob.lo = r[i].low;
               ob.hi = r[i].high;
               bool dead = false;
               for(int j = 1; j < impulse; j++)
                 {
                  if(r[j].high >= ob.hi)
                    { dead = true; break; }
                 }
               if(!dead)
                 {
                  ob.score = 2;
                  ob.note = "bear OB";
                  return ob;
                 }
               ob.bear = false;
              }
           }
        }
      return ob;
     }
  };

//==================================================================
// ZONE COMPOSITOR (location touch — not a second signal source)
//==================================================================
class CSaZoneCompositor
  {
public:
   SaZones Compose(const SaDisplacement &d, const SaFVG &f, const SaOB &ob, const double bid)
     {
      SaZones z;
      z.bullDisp = d.bull;
      z.bearDisp = d.bear;
      z.bullFVG = f.bull && f.fresh;
      z.bearFVG = f.bear && f.fresh;
      z.bullOB = ob.bull;
      z.bearOB = ob.bear;
      z.bullZoneTouch = false;
      z.bearZoneTouch = false;
      z.zoneLo = 0.0;
      z.zoneHi = 0.0;
      z.score = d.score + f.score + ob.score;
      z.note = "zones";

      if(f.bull || f.bear)
        {
         z.zoneLo = f.lo;
         z.zoneHi = f.hi;
         z.note = f.note;
        }
      else if(ob.bull || ob.bear)
        {
         z.zoneLo = ob.lo;
         z.zoneHi = ob.hi;
         z.note = ob.note;
        }
      else if(d.bull || d.bear)
         z.note = d.note;
      else
         z.note = "awaiting zone";

      if(z.zoneHi > z.zoneLo)
        {
         const double h = z.zoneHi - z.zoneLo;
         const double pad = MathMax(h * 0.50, h * 0.10);
         if(bid <= z.zoneHi + pad && bid >= z.zoneLo - pad)
           {
            if(z.bullFVG || z.bullOB || z.bullDisp) z.bullZoneTouch = true;
            if(z.bearFVG || z.bearOB || z.bearDisp) z.bearZoneTouch = true;
           }
        }
      return z;
     }
  };

//==================================================================
// VOLATILITY / REGIME ENGINE
//==================================================================
class CSaVolatilityEngine
  {
public:
   ENUM_SA_MKT Regime(const double atr, const double atrAvg)
     {
      if(atrAvg <= 0.0) return SA_MKT_NORMAL;
      if(atr >= atrAvg * InpExtremeVolAtrMult) return SA_MKT_EXTREME;
      if(atr >= atrAvg * InpHighVolAtrMult) return SA_MKT_HIGH;
      if(atr <= atrAvg * 0.55) return SA_MKT_LOW;
      return SA_MKT_NORMAL;
     }

   int ScoreRequirement(const ENUM_SA_MKT mkt, const double spreadPts, const double atr, const double point)
     {
      int need = InpMinScore;
      if(mkt == SA_MKT_HIGH) need += 1;
      if(mkt == SA_MKT_EXTREME) need += 3;
      // Adapt to wide spread — raise bar, never hard-block
      if(atr > 0.0 && point > 0.0)
        {
         const double spreadPrice = spreadPts * point;
         if(spreadPrice >= atr * InpWideSpreadAtrFrac)
            need += 2;
        }
      return need;
     }

   double SLBoost(const ENUM_SA_MKT mkt)
     {
      if(mkt == SA_MKT_EXTREME) return InpVolSLBoostExtreme;
      if(mkt == SA_MKT_HIGH) return InpVolSLBoostHigh;
      return 1.0;
     }
  };

//==================================================================
// ENTRY ENGINE (M5 confirmation)
//==================================================================
class CSaEntryEngine
  {
public:
   bool M5Buy(const MqlRates &m5[], const int n)
     {
      if(n < 4) return false;
      const double body = m5[1].close - m5[1].open;
      const double range = m5[1].high - m5[1].low;
      if(range <= 0.0 || body <= 0.0) return false;
      const bool bull = (m5[1].close > m5[1].open);
      const bool up = (m5[1].close > m5[2].close);
      const bool strongBody = (body >= range * 0.45);
      const bool closesStrong = (m5[1].close >= m5[1].low + range * 0.60);
      const bool breaksMicro = (m5[1].close > m5[2].high || m5[1].close > m5[2].close);
      return (bull && strongBody && closesStrong && up && breaksMicro);
     }

   bool M5Sell(const MqlRates &m5[], const int n)
     {
      if(n < 4) return false;
      const double body = m5[1].open - m5[1].close;
      const double range = m5[1].high - m5[1].low;
      if(range <= 0.0 || body <= 0.0) return false;
      const bool bear = (m5[1].close < m5[1].open);
      const bool dn = (m5[1].close < m5[2].close);
      const bool strongBody = (body >= range * 0.45);
      const bool closesStrong = (m5[1].close <= m5[1].high - range * 0.60);
      const bool breaksMicro = (m5[1].close < m5[2].low || m5[1].close < m5[2].close);
      return (bear && strongBody && closesStrong && dn && breaksMicro);
     }
  };

//==================================================================
// CONFLUENCE + TRADE DECISION ENGINE
//==================================================================
class CSaDecisionEngine
  {
private:
   CSaStructureEngine    m_structure;
   CSaLiquidityEngine    m_liquidity;
   CSaDisplacementEngine m_disp;
   CSaFVGEngine          m_fvg;
   CSaOBEngine           m_ob;
   CSaZoneCompositor     m_zones;
   CSaVolatilityEngine   m_vol;
   CSaEntryEngine        m_entry;

public:
   void SetSwingStrength(const int s) { m_structure.SetStrength(s); }

   SaSetup Evaluate(CSaMarketData &data, CSaSymbolManager &sym, const double bid, const double ask)
     {
      SaSetup s;
      s.side = SA_SIDE_NONE;
      s.path = SA_PATH_NONE;
      s.bias = SA_BIAS_FLAT;
      s.mkt = SA_MKT_NORMAL;
      s.score = 0;
      s.confluence = 0;
      s.reason = "scanning";
      s.atrH1 = data.Atr();
      s.spreadPts = (sym.point > 0.0 ? (ask - bid) / sym.point : 0.0);
      s.mkt = m_vol.Regime(data.Atr(), data.AtrAvg());

      MqlRates h4[], h1[], m5[];
      if(!data.H4(h4) || !data.H1(h1) || !data.M5(m5))
        {
         s.reason = "rates unavailable";
         return s;
        }
      const int h4n = ArraySize(h4);
      const int h1n = ArraySize(h1);
      const int m5n = ArraySize(m5);

      const SaStructure st = m_structure.Evaluate(h4, h4n, h1, h1n);
      const SaLiquidity liq = m_liquidity.Evaluate(h1, h1n, sym.Pip(), data.Atr());
      const SaDisplacement disp = m_disp.Evaluate(h1, h1n);
      const SaFVG fvg = m_fvg.Evaluate(h1, h1n);
      const SaOB ob = m_ob.Evaluate(h1, h1n, disp);
      const SaZones zone = m_zones.Compose(disp, fvg, ob, bid);

      s.bias = st.biasH4;
      int score = liq.score + zone.score;
      if(st.bosBull || st.bosBear) score += 3;
      if(st.chochBull || st.chochBear) score += 3;
      if(st.biasH4 != SA_BIAS_FLAT) score += 2;

      const int needScore = m_vol.ScoreRequirement(s.mkt, s.spreadPts, data.Atr(), sym.point);

      // Path A — Continuation:
      // H4 bias + recent H1 BOS + zone from recent displacement (OB/FVG) + location + M5
      // Displacement is the SETUP creator (lookback), not required on the entry bar.
      // Path A — strategy lock: H4 bias + H1 BOS + (OB/FVG/Disp) + liquidity + M5 → instant
      if(InpAllowContinuation && st.biasH4 == SA_BIAS_BULL)
        {
         const bool m5ok = m_entry.M5Buy(m5, m5n);
         const bool zoneOk = (zone.bullFVG || zone.bullOB || zone.bullDisp);
         const bool locOk = (!InpRequireZoneTouch || zone.bullZoneTouch || zoneOk);
         const bool liqOk = (liq.sellSideSweep || liq.equalLows || st.bosBull);
         int conf = 0;
         if(st.biasH4 == SA_BIAS_BULL) conf++;
         if(st.bosBull) conf++;
         if(zoneOk) conf++;
         if(locOk) conf++;
         if(liqOk) conf++;
         if(m5ok) conf++;

         if(st.bosBull && zoneOk && locOk && liqOk && m5ok && conf >= InpMinConfluence)
           {
            s.side = SA_SIDE_BUY;
            s.path = SA_PATH_CONTINUATION;
            s.confluence = conf;
            s.score = score + 8 + conf;
            if(s.score < needScore)
               s.score = needScore; // valid kill-chain must be executable
            s.reason = "CONT | " + st.note + " | " + zone.note;
            return s;
           }
         if(st.bosBull && m5ok)
            s.reason = "CONT wait zone/liq";
        }

      if(InpAllowContinuation && st.biasH4 == SA_BIAS_BEAR)
        {
         const bool m5ok = m_entry.M5Sell(m5, m5n);
         const bool zoneOk = (zone.bearFVG || zone.bearOB || zone.bearDisp);
         const bool locOk = (!InpRequireZoneTouch || zone.bearZoneTouch || zoneOk);
         const bool liqOk = (liq.buySideSweep || liq.equalHighs || st.bosBear);
         int conf = 0;
         if(st.biasH4 == SA_BIAS_BEAR) conf++;
         if(st.bosBear) conf++;
         if(zoneOk) conf++;
         if(locOk) conf++;
         if(liqOk) conf++;
         if(m5ok) conf++;

         if(st.bosBear && zoneOk && locOk && liqOk && m5ok && conf >= InpMinConfluence)
           {
            s.side = SA_SIDE_SELL;
            s.path = SA_PATH_CONTINUATION;
            s.confluence = conf;
            s.score = score + 8 + conf;
            if(s.score < needScore)
               s.score = needScore;
            s.reason = "CONT | " + st.note + " | " + zone.note;
            return s;
           }
         if(st.bosBear && m5ok)
            s.reason = "CONT wait zone/liq";
        }

      // Path B — Reversal (sweep + CHoCH + zone + M5)
      if(InpAllowReversal && liq.sellSideSweep && st.chochBull &&
         (zone.bullDisp || zone.bullFVG || zone.bullOB) && m_entry.M5Buy(m5, m5n))
        {
         int conf = 4;
         if(zone.bullZoneTouch || zone.bullFVG) conf++;
         if(zone.bullDisp) conf++;
         s.side = SA_SIDE_BUY;
         s.path = SA_PATH_REVERSAL;
         s.confluence = conf;
         s.score = score + 10 + conf;
         if(conf >= InpMinConfluence)
           {
            if(s.score < needScore)
               s.score = needScore;
            s.reason = "REV | sell-side sweep | " + st.note;
            return s;
           }
         s.side = SA_SIDE_NONE;
         s.path = SA_PATH_NONE;
        }

      if(InpAllowReversal && liq.buySideSweep && st.chochBear &&
         (zone.bearDisp || zone.bearFVG || zone.bearOB) && m_entry.M5Sell(m5, m5n))
        {
         int conf = 4;
         if(zone.bearZoneTouch || zone.bearFVG) conf++;
         if(zone.bearDisp) conf++;
         s.side = SA_SIDE_SELL;
         s.path = SA_PATH_REVERSAL;
         s.confluence = conf;
         s.score = score + 10 + conf;
         if(conf >= InpMinConfluence)
           {
            if(s.score < needScore)
               s.score = needScore;
            s.reason = "REV | buy-side sweep | " + st.note;
            return s;
           }
         s.side = SA_SIDE_NONE;
         s.path = SA_PATH_NONE;
        }

      s.score = score;
      s.reason = st.note + " | " + liq.note + " | " + zone.note;
      return s;
     }
  };

//==================================================================
// MONEY MANAGER
//==================================================================
class CSaMoneyManager
  {
public:
   double Lots(CSaSymbolManager &sym)
     {
      return sym.NormVol(InpLot);
     }

   bool MarginOK(const string symbol, const ENUM_SA_SIDE side, const double lots, string &why)
     {
      double margin = 0.0;
      const ENUM_ORDER_TYPE ot = (side == SA_SIDE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      const double price = (side == SA_SIDE_BUY ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID));
      if(price <= 0.0)
        { why = "invalid price"; return false; }
      if(!OrderCalcMargin(ot, symbol, lots, price, margin))
        { why = "margin calc fail"; return false; }
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        { why = "insufficient margin"; return false; }
      why = "ok";
      return true;
     }
  };

//==================================================================
// RISK MANAGER
//==================================================================
class CSaRiskManager
  {
private:
   long     m_magic;
   double   m_dayStartEquity;
   datetime m_dayStamp;
   int      m_consecLoss;
   CSaVolatilityEngine m_vol;

   void RollDay()
     {
      MqlDateTime dt;
      TimeToStruct(TimeTradeServer(), dt);
      const datetime day = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
      if(day != m_dayStamp)
        {
         m_dayStamp = day;
         m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        }
     }

public:
                     CSaRiskManager(void): m_magic(0), m_dayStartEquity(0.0), m_dayStamp(0), m_consecLoss(0) {}

   void Init(const long magic)
     {
      m_magic = magic;
      m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStamp = 0;
      m_consecLoss = 0;
      RollDay();
     }

   int CountPositions(const string symbolFilter = "")
     {
      int c = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         if(symbolFilter != "" && PositionGetString(POSITION_SYMBOL) != symbolFilter)
            continue;
         c++;
        }
      return c;
     }

   double FloatingPnL()
     {
      double p = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      return p;
     }

   bool CanOpen(CSaSymbolManager &sym, string &why)
     {
      RollDay();
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
        { why = "trading disabled"; return false; }
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        { why = "no connection"; return false; }
      if(!sym.TradeAllowed(why))
         return false;
      if(CountPositions() >= InpMaxTrades)
        { why = "max trades"; return false; }
      if(CountPositions(sym.symbol) >= InpMaxTrades)
        { why = "max symbol trades"; return false; }

      if(InpMaxDailyDDPercent > 0.0 && m_dayStartEquity > 0.0)
        {
         const double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         const double dd = (m_dayStartEquity - eq) / m_dayStartEquity * 100.0;
         if(dd >= InpMaxDailyDDPercent)
           { why = "daily DD limit"; return false; }
        }
      if(InpMaxConsecutiveLoss > 0 && m_consecLoss >= InpMaxConsecutiveLoss)
        { why = "consec loss limit"; return false; }

      why = "ok";
      return true;
     }

   bool BuildStops(CSaSymbolManager &sym, const ENUM_SA_SIDE side, const ENUM_SA_MKT mkt,
                   const double atr, double &entry, double &sl, double &tp, string &why)
     {
      if(atr <= 0.0)
        { why = "atr invalid"; return false; }

      sym.RefreshSpecs();
      const double boost = m_vol.SLBoost(mkt);
      double stopDist = atr * InpAtrMultSL * boost;
      const double minDist = MathMax((double)MathMax(sym.stopsLevel, sym.freezeLevel) * sym.point,
                                     sym.Pip() * 3.0);
      if(stopDist < minDist)
         stopDist = minDist;

      if(side == SA_SIDE_BUY)
        {
         entry = SymbolInfoDouble(sym.symbol, SYMBOL_ASK);
         if(entry <= 0.0) { why = "invalid ask"; return false; }
         sl = sym.NormPrice(entry - stopDist);
         tp = sym.NormPrice(entry + stopDist * InpRewardRatio);
         if(sl >= entry || tp <= entry)
           { why = "invalid buy stops"; return false; }
         if(entry - sl < minDist) sl = sym.NormPrice(entry - minDist);
         if(tp - entry < minDist) tp = sym.NormPrice(entry + minDist);
        }
      else if(side == SA_SIDE_SELL)
        {
         entry = SymbolInfoDouble(sym.symbol, SYMBOL_BID);
         if(entry <= 0.0) { why = "invalid bid"; return false; }
         sl = sym.NormPrice(entry + stopDist);
         tp = sym.NormPrice(entry - stopDist * InpRewardRatio);
         if(sl <= entry || tp >= entry)
           { why = "invalid sell stops"; return false; }
         if(sl - entry < minDist) sl = sym.NormPrice(entry + minDist);
         if(entry - tp < minDist) tp = sym.NormPrice(entry - minDist);
        }
      else
        { why = "no side"; return false; }

      why = "ok";
      return true;
     }

   void OnDealClosedLoss(const bool isLoss)
     {
      if(isLoss) m_consecLoss++;
      else m_consecLoss = 0;
     }

   int ConsecLoss() { return m_consecLoss; }
  };

//==================================================================
// POSITION MANAGER (exit / BE / optional trail)
//==================================================================
class CSaPositionManager
  {
   double InitialRisk(const long type, const double open, const double sl, const double tp, const double point)
     {
      double risk = (type == POSITION_TYPE_BUY ? open - sl : sl - open);
      if(risk > point)
         return risk;
      // After BE, recover R from TP distance / reward ratio
      if(tp > 0.0 && InpRewardRatio > 0.0)
        {
         const double toTP = MathAbs(tp - open);
         if(toTP > point)
            return toTP / InpRewardRatio;
        }
      return 0.0;
     }

public:
   void Manage(CTrade &trade, const long magic)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;

         const string symbol = PositionGetString(POSITION_SYMBOL);
         const double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         const double tp = PositionGetDouble(POSITION_TP);
         const long type = PositionGetInteger(POSITION_TYPE);
         const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         if(point <= 0.0)
            continue;

         const double risk = InitialRisk(type, open, sl, tp, point);
         if(risk <= 0.0)
            continue;

         bool beHit = false;
         if(type == POSITION_TYPE_BUY && bid >= open + risk * InpBreakEvenR)
            beHit = true;
         if(type == POSITION_TYPE_SELL && ask <= open - risk * InpBreakEvenR)
            beHit = true;

         if(beHit)
           {
            const bool alreadyBE = (type == POSITION_TYPE_BUY && sl >= open - point) ||
                                   (type == POSITION_TYPE_SELL && sl > 0.0 && sl <= open + point);
            if(!alreadyBE)
              {
               const double newSL = NormalizeDouble(open, digits);
               if(trade.PositionModify(ticket, newSL, tp))
                  sl = newSL;
              }
           }

         if(!InpUseTrailing)
            continue;

         bool trailArmed = false;
         if(type == POSITION_TYPE_BUY && bid >= open + risk * InpTrailStartR) trailArmed = true;
         if(type == POSITION_TYPE_SELL && ask <= open - risk * InpTrailStartR) trailArmed = true;
         if(!trailArmed)
            continue;

         const double step = risk * InpTrailStepR;
         if(type == POSITION_TYPE_BUY)
           {
            const double nsl = NormalizeDouble(bid - step, digits);
            if(nsl > sl + point)
               trade.PositionModify(ticket, nsl, tp);
           }
         else
           {
            const double nsl = NormalizeDouble(ask + step, digits);
            if(sl == 0.0 || nsl < sl - point)
               trade.PositionModify(ticket, nsl, tp);
           }
        }
     }
  };

//==================================================================
// EXECUTION ENGINE
//==================================================================
class CSaExecutionEngine
  {
private:
   CTrade              m_trade;
   long                m_magic;
   int                 m_slippage;
   string              m_lastStatus;
   CSaPositionManager  m_positions;

public:
                     CSaExecutionEngine(void): m_magic(0), m_slippage(30), m_lastStatus("idle") {}

   void Init(const long magic, const int slippage)
     {
      m_magic = magic;
      m_slippage = slippage;
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetAsyncMode(false);
      m_lastStatus = "armed";
     }

   string LastStatus() { return m_lastStatus; }

   void ManagePositions()
     {
      m_positions.Manage(m_trade, m_magic);
     }

   bool Send(const string symbol, const ENUM_SA_SIDE side, const double lots,
             double sl, double tp, string &why)
     {
      if(side == SA_SIDE_NONE || lots <= 0.0)
        { why = "invalid order params"; m_lastStatus = why; return false; }
      if(sl <= 0.0 || tp <= 0.0)
        { why = "invalid stops"; m_lastStatus = why; return false; }

      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFillingBySymbol(symbol);

      for(int attempt = 1; attempt <= InpMaxRetries; attempt++)
        {
         ResetLastError();
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         if(bid <= 0.0 || ask <= 0.0)
           {
            why = "no quotes";
            m_lastStatus = why;
            if(attempt < InpMaxRetries) { Sleep(120 * attempt); continue; }
            return false;
           }

         // Re-validate stop distance vs live quote each attempt
         const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         const int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
         const double minDist = stops * point;
         if(side == SA_SIDE_BUY)
           {
            if(minDist > 0.0 && (ask - sl) < minDist)
               sl = NormalizeDouble(ask - minDist, digits);
            if(minDist > 0.0 && (tp - ask) < minDist)
               tp = NormalizeDouble(ask + minDist, digits);
           }
         else
           {
            if(minDist > 0.0 && (sl - bid) < minDist)
               sl = NormalizeDouble(bid + minDist, digits);
            if(minDist > 0.0 && (bid - tp) < minDist)
               tp = NormalizeDouble(bid - minDist, digits);
           }

         bool ok = false;
         // price 0.0 = market execution (broker fills at available price)
         if(side == SA_SIDE_BUY)
            ok = m_trade.Buy(lots, symbol, 0.0, sl, tp, SA_COMMENT);
         else
            ok = m_trade.Sell(lots, symbol, 0.0, sl, tp, SA_COMMENT);

         if(ok)
           {
            why = "filled";
            m_lastStatus = "FILLED";
            return true;
           }

         const int rc = (int)m_trade.ResultRetcode();
         why = StringFormat("retcode=%d %s", rc, m_trade.ResultRetcodeDescription());
         m_lastStatus = why;

         // Portable retry loop (no build-specific retcode enums)
         if(attempt < InpMaxRetries)
           {
            Sleep(150 * attempt);
            continue;
           }
         break;
        }
      return false;
     }
  };

//==================================================================
// STATISTICS ENGINE
//==================================================================
class CSaStatistics
  {
private:
   int m_entries;
   int m_fills;
   int m_fails;

public:
                     CSaStatistics(void): m_entries(0), m_fills(0), m_fails(0) {}
   void OnAttempt() { m_entries++; }
   void OnFill() { m_fills++; }
   void OnFail() { m_fails++; }
   int  Entries() { return m_entries; }
   int  Fills() { return m_fills; }
   int  Fails() { return m_fails; }
  };

//==================================================================
// SYSTEM CORE / STATE PIPELINE
//==================================================================
CSaConfig           g_cfg;
CSaSymbolManager    g_sym;
CSaMarketData       g_data;
CSaDecisionEngine   g_decision;
CSaRiskManager      g_risk;
CSaMoneyManager     g_money;
CSaExecutionEngine  g_exec;
CSaStatistics       g_stats;

ENUM_SA_STAGE g_stage = SA_STAGE_INIT;
datetime      g_lastM5 = 0;
datetime      g_lastEntryM5 = 0;
string        g_lastAction = "boot";
string        g_eaStatus = "init";
SaSetup       g_setup;
int           g_tick = 0;
string        g_broker = "";

bool SaFire(const SaSetup &setup)
  {
   g_stage = SA_STAGE_RISK;
   if(setup.side == SA_SIDE_NONE)
     {
      g_eaStatus = "scanning";
      if(StringLen(setup.reason) > 0)
         g_lastAction = setup.reason;
      return false;
     }
   if(setup.score < InpMinScore)
     {
      g_lastAction = StringFormat("score %d < min %d", setup.score, InpMinScore);
      g_eaStatus = "score gate";
      return false;
     }

   string why;
   if(!g_risk.CanOpen(g_sym, why))
     {
      g_lastAction = why;
      g_eaStatus = "blocked";
      SaLog("blocked: " + why);
      return false;
     }

   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!g_risk.BuildStops(g_sym, setup.side, setup.mkt, setup.atrH1, entry, sl, tp, why))
     {
      g_lastAction = why;
      return false;
     }

   const double lots = g_money.Lots(g_sym);
   if(!g_money.MarginOK(_Symbol, setup.side, lots, why))
     {
      g_lastAction = why;
      return false;
     }

   g_stage = SA_STAGE_EXEC;
   g_stats.OnAttempt();
   if(!g_exec.Send(_Symbol, setup.side, lots, sl, tp, why))
     {
      g_stats.OnFail();
      g_lastAction = why;
      g_eaStatus = "exec fail";
      SaLog("order failed: " + why);
      return false;
     }

   g_stats.OnFill();
   g_lastEntryM5 = g_lastM5;
   g_lastAction = (setup.side == SA_SIDE_BUY ? "BUY filled" : "SELL filled");
   g_eaStatus = "in market";
   SaLog(g_lastAction + " comment=" + SA_COMMENT);
   return true;
  }


//==================================================================
// LIFECYCLE
//==================================================================
int OnInit()
  {
   string why;
   if(!g_cfg.Validate(why))
     {
      Print(SA_LOG_PREFIX, "invalid inputs: ", why);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!g_sym.Init(_Symbol))
     {
      Print(SA_LOG_PREFIX, "symbol init failed");
      return INIT_FAILED;
     }
   if(!g_data.Init(_Symbol))
     {
      Print(SA_LOG_PREFIX, "data/ATR init failed");
      return INIT_FAILED;
     }

   g_decision.SetSwingStrength(InpSwingStrength);
   g_risk.Init(InpMagic);
   g_exec.Init(InpMagic, InpMaxSlippagePoints);
   g_broker = AccountInfoString(ACCOUNT_COMPANY);

   g_setup.side = SA_SIDE_NONE;
   g_setup.path = SA_PATH_NONE;
   g_setup.bias = SA_BIAS_FLAT;
   g_setup.mkt = SA_MKT_NORMAL;
   g_setup.score = 0;
   g_setup.confluence = 0;
   g_setup.atrH1 = 0.0;
   g_setup.spreadPts = 0.0;
   g_setup.reason = "armed";
   g_eaStatus = "online";
   g_lastAction = "online 24/7";
   g_stage = SA_STAGE_SCAN;

   if(!g_data.Refresh())
      SaLog("initial refresh pending history");

   SaLog(StringFormat("ONLINE %s lot=%.2f max=%d", _Symbol, InpLot, InpMaxTrades));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_data.Release();
   Comment("");
   SaLog(StringFormat("stopped reason=%d fills=%d fails=%d", reason, g_stats.Fills(), g_stats.Fails()));
  }

void OnTick()
  {
   g_tick++;
   g_stage = SA_STAGE_MANAGE;
   g_exec.ManagePositions();

   g_stage = SA_STAGE_DATA;
   if(!g_data.Refresh())
     {
      g_eaStatus = "data wait";
      return;
     }

   if(!g_data.NewM5Bar(g_lastM5))
      return;

   double bid = 0.0, ask = 0.0;
   g_sym.Quotes(bid, ask);

   g_stage = SA_STAGE_ANALYSIS;
   g_setup = g_decision.Evaluate(g_data, g_sym, bid, ask);
   g_eaStatus = "scanning";
   g_stage = SA_STAGE_DECISION;

   if(!(InpOneEntryPerM5 && g_lastEntryM5 == g_lastM5))
     {
      if(!SaFire(g_setup) && g_setup.side == SA_SIDE_NONE)
         g_eaStatus = "scanning";
     }
   g_stage = SA_STAGE_SCAN;
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
     {
      HistorySelect(0, TimeCurrent());
      if(!HistoryDealSelect(trans.deal))
         return;
     }
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic)
      return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   const double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                         + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                         + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   g_risk.OnDealClosedLoss(profit < 0.0);
  }
//+------------------------------------------------------------------+
