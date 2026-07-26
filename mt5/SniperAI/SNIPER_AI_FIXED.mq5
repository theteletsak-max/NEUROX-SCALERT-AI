//+------------------------------------------------------------------+
//| SNIPER_AI_FIXED.mq5                                               |
//| BUILD_ID: SA_COMPILE_OK_8                                         |
//| SNIPER AI                                                         |
//| DELETE old SniperAI.mq5 from Experts before compiling this file.  |
//+------------------------------------------------------------------+
#property copyright   "SNIPER AI"
#property link        "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version     "1.00"
#property description "SNIPER AI — institutional sniper EA (H4/H1/M5)"
#property description "High-precision 24/7 adaptive execution. No session/news blocks."

#include <Trade/Trade.mqh>

#define SA_COMMENT        "SNIPER AI"
#define SA_UI_PREFIX      "SA_UI_"
#define SA_LOG_PREFIX     "SNIPER AI | "

//==================================================================
// 1) TYPES
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

struct SaSwing
  {
   datetime time;
   double   price;
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
   string       reason;
   double       atrH1;
   double       spreadPts;
  };

//==================================================================
// 2) INPUTS
//==================================================================

input double InpLot                 = 0.01;       // Lot size
input int    InpMaxTrades           = 3;          // Max open trades (account)
input long   InpMagic               = 20260726;   // Magic number
input int    InpMaxSlippagePoints   = 80;         // Max slippage (points)
input int    InpMaxRetries          = 3;          // Execution retries

input int    InpSwingStrength       = 2;          // Swing fractal strength
input int    InpMinScore            = 14;         // Minimum setup score (strict)
input int    InpMinConfluence       = 4;          // Min confluence factors required
input bool   InpAllowContinuation   = true;       // Allow continuation
input bool   InpAllowReversal       = true;       // Allow reversal
input bool   InpRequireZoneTouch    = true;       // Require price at OB/FVG zone
input bool   InpOneEntryPerM5       = true;       // One entry per M5 bar
input bool   InpTradeChartOnly      = true;       // Trade attached chart only

input double InpAtrMultSL           = 1.5;        // SL = ATR(H1) * mult
input double InpRewardRatio         = 2.0;        // TP = R multiple
input double InpBreakEvenR          = 1.0;        // BE trigger (+R)
input bool   InpUseTrailing         = false;      // Trailing stop (optional)
input double InpTrailStartR         = 1.5;        // Trail start (+R)
input double InpTrailStepR          = 0.5;        // Trail step (R)
input double InpMaxDailyDDPercent   = 0.0;        // Max daily DD % (0=off)
input int    InpMaxConsecutiveLoss  = 0;          // Max consecutive losses (0=off)

input double InpHighVolAtrMult      = 1.8;        // ATR regime: high if > avg*this
input double InpExtremeVolAtrMult   = 2.5;        // ATR regime: extreme
input double InpVolSLBoostHigh      = 1.15;       // SL boost in high vol
input double InpVolSLBoostExtreme   = 1.35;      // SL boost in extreme vol

input bool   InpShowDashboard       = true;       // Show premium dashboard
input bool   InpLogEvents           = true;       // Log important events
input int    InpDashRefreshTicks    = 8;          // Dashboard refresh throttle

//==================================================================
// 3) SYMBOL + MARKET DATA CACHE
//==================================================================
class CSaSymbolCache
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
   ENUM_SYMBOL_TRADE_EXECUTION execMode;

   bool Init(const string sym)
     {
      symbol = sym;
      if(!SymbolSelect(symbol, true))
         return false;
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
      execMode    = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
      if(volStep <= 0.0) volStep = 0.01;
      if(point <= 0.0) return false;
      return true;
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
  };

class CSaDataCache
  {
private:
   string          m_symbol;
   int             m_atrHandle;
   datetime        m_h4Bar;
   datetime        m_h1Bar;
   datetime        m_m5Bar;
   MqlRates        m_h4[];
   MqlRates        m_h1[];
   MqlRates        m_m5[];
   double          m_atrBuf[];
   double          m_atrValue;
   double          m_atrAvg;

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

public:
                     CSaDataCache(void): m_atrHandle(INVALID_HANDLE), m_h4Bar(0), m_h1Bar(0),
                                         m_m5Bar(0), m_atrValue(0.0), m_atrAvg(0.0) {}
                    ~CSaDataCache(void) { Release(); }

   bool Init(const string symbol)
     {
      Release();
      m_symbol = symbol;
      m_atrHandle = iATR(m_symbol, PERIOD_H1, 14);
      return (m_atrHandle != INVALID_HANDLE);
     }

   void Release()
     {
      if(m_atrHandle != INVALID_HANDLE)
        {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
        }
     }

   bool Refresh(const int h4Bars = 160, const int h1Bars = 160, const int m5Bars = 40)
     {
      if(!CopyTF(PERIOD_H4, h4Bars, m_h4, m_h4Bar)) return false;
      if(!CopyTF(PERIOD_H1, h1Bars, m_h1, m_h1Bar)) return false;
      if(!CopyTF(PERIOD_M5, m5Bars, m_m5, m_m5Bar)) return false;

      ArraySetAsSeries(m_atrBuf, true);
      if(CopyBuffer(m_atrHandle, 0, 1, 40, m_atrBuf) < 40)
         return false;
      m_atrValue = m_atrBuf[0];
      double sum = 0.0;
      for(int i = 0; i < 40; i++)
         sum += m_atrBuf[i];
      m_atrAvg = sum / 40.0;
      return (m_atrValue > 0.0);
     }

   bool NewM5Bar(datetime &last)
     {
      if(ArraySize(m_m5) < 2)
         return false;
      datetime t = m_m5[0].time;
      if(t != last)
        {
         last = t;
         return true;
        }
      return false;
     }

   bool GetH4(MqlRates &out[])
     {
      const int n = ArraySize(m_h4);
      ArraySetAsSeries(out, true);
      ArrayResize(out, n);
      for(int i = 0; i < n; i++)
         out[i] = m_h4[i];
      return (n > 0);
     }
   bool GetH1(MqlRates &out[])
     {
      const int n = ArraySize(m_h1);
      ArraySetAsSeries(out, true);
      ArrayResize(out, n);
      for(int i = 0; i < n; i++)
         out[i] = m_h1[i];
      return (n > 0);
     }
   bool GetM5(MqlRates &out[])
     {
      const int n = ArraySize(m_m5);
      ArraySetAsSeries(out, true);
      ArrayResize(out, n);
      for(int i = 0; i < n; i++)
         out[i] = m_m5[i];
      return (n > 0);
     }
   double Atr() { return m_atrValue; }
   double AtrAvg() { return m_atrAvg; }
  };

//==================================================================
// 4) STRUCTURE ENGINE
//==================================================================
class CSaStructureEngine
  {
private:
   int m_strength;

   // Collect confirmed swings using closed bars only (non-repainting)
   void CollectSwings(const MqlRates &r[], const int n, SaSwing &swings[], const int maxKeep)
     {
      ArrayResize(swings, 0);
      // series: index 0 = forming. Require right-side bars fully closed => i >= strength+1
      for(int i = m_strength + 1; i < n - m_strength; i++)
        {
         bool hi = true, lo = true;
         for(int k = 1; k <= m_strength; k++)
           {
            if(r[i].high < r[i - k].high || r[i].high < r[i + k].high) hi = false;
            if(r[i].low > r[i - k].low || r[i].low > r[i + k].low) lo = false;
           }
         if(hi)
           {
            const int sz = ArraySize(swings);
            ArrayResize(swings, sz + 1);
            swings[sz].time = r[i].time;
            swings[sz].price = r[i].high;
            swings[sz].isHigh = true;
           }
         if(lo)
           {
            const int sz = ArraySize(swings);
            ArrayResize(swings, sz + 1);
            swings[sz].time = r[i].time;
            swings[sz].price = r[i].low;
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
      // swings are newest-first because we scanned from low i
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

      bool hh = (h1 > h2);
      bool hl = (l1 > l2);
      bool lh = (h1 < h2);
      bool ll = (l1 < l2);

      if(hh && hl) return SA_BIAS_BULL;
      if(lh && ll) return SA_BIAS_BEAR;
      if(hh && !ll) return SA_BIAS_BULL;
      if(ll && !hh) return SA_BIAS_BEAR;
      return SA_BIAS_FLAT;
     }

public:
                     CSaStructureEngine(void): m_strength(2) {}
   void              SetStrength(const int s) { m_strength = MathMax(1, MathMin(5, s)); }

   SaStructure Evaluate(const MqlRates &h4[], const int h4n,
                        const MqlRates &h1[], const int h1n)
     {
      SaStructure st;
      st.biasH4 = SA_BIAS_FLAT;
      st.bosBull = st.bosBear = false;
      st.chochBull = st.chochBear = false;
      st.swingHigh = st.swingLow = 0.0;
      st.note = "structure";

      SaSwing sw4[];
      CollectSwings(h4, h4n, sw4, 40);
      st.biasH4 = BiasFromSwings(sw4);

      SaSwing sw1[];
      CollectSwings(h1, h1n, sw1, 40);

      // most recent swing high/low on H1
      for(int i = 0; i < ArraySize(sw1); i++)
        {
         if(sw1[i].isHigh && st.swingHigh == 0.0)
            st.swingHigh = sw1[i].price;
         if(!sw1[i].isHigh && st.swingLow == 0.0)
            st.swingLow = sw1[i].price;
         if(st.swingHigh > 0.0 && st.swingLow > 0.0)
            break;
        }

      if(h1n < 3)
         return st;

      // Non-repainting break: closed bar [1]
      const double c1 = h1[1].close;
      if(st.swingHigh > 0.0 && c1 > st.swingHigh)
        {
         if(st.biasH4 == SA_BIAS_BULL || st.biasH4 == SA_BIAS_FLAT)
            st.bosBull = true;
         if(st.biasH4 == SA_BIAS_BEAR)
            st.chochBull = true;
        }
      if(st.swingLow > 0.0 && c1 < st.swingLow)
        {
         if(st.biasH4 == SA_BIAS_BEAR || st.biasH4 == SA_BIAS_FLAT)
            st.bosBear = true;
         if(st.biasH4 == SA_BIAS_BULL)
            st.chochBear = true;
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
// 5) LIQUIDITY ENGINE
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
      if(n < 20 || pip <= 0.0)
         return liq;

      const double tol = MathMax(pip * 2.0, atr * 0.05);

      // pools from closed bars [2..N]
      liq.poolHigh = r[2].high;
      liq.poolLow  = r[2].low;
      for(int i = 2; i < MathMin(n, 50); i++)
        {
         if(r[i].high > liq.poolHigh) liq.poolHigh = r[i].high;
         if(r[i].low < liq.poolLow) liq.poolLow = r[i].low;
        }

      // equal highs/lows vs recent pivot cluster
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

      // opposing liquidity for sweeps: recent extremes excluding bar1
      double rh = r[3].high, rl = r[3].low;
      for(int i = 3; i < MathMin(n, 16); i++)
        {
         if(r[i].high > rh) rh = r[i].high;
         if(r[i].low < rl) rl = r[i].low;
        }

      // Sweep = pierce pool then reclaim (close back inside) on closed bar
      if(r[1].high > rh + tol * 0.25 && r[1].close < rh)
        {
         liq.buySideSweep = true;
         liq.score += 3;
         liq.note = "buy-side sweep";
        }
      if(r[1].low < rl - tol * 0.25 && r[1].close > rl)
        {
         liq.sellSideSweep = true;
         liq.score += 3;
         liq.note = "sell-side sweep";
        }
      if(!liq.buySideSweep && !liq.sellSideSweep)
         liq.note = (liq.equalHighs || liq.equalLows) ? "eq liquidity" : "mapping";
      return liq;
     }
  };

//==================================================================
// 6) ZONE ENGINE (Displacement / OB / FVG)
//==================================================================
class CSaZoneEngine
  {
public:
   SaZones Evaluate(const MqlRates &r[], const int n, const double bid)
     {
      SaZones z;
      z.bullDisp = z.bearDisp = false;
      z.bullFVG = z.bearFVG = false;
      z.bullOB = z.bearOB = false;
      z.bullZoneTouch = z.bearZoneTouch = false;
      z.zoneLo = z.zoneHi = 0.0;
      z.score = 0;
      z.note = "zones";
      if(n < 8)
         return z;

      const double b1 = MathAbs(r[1].close - r[1].open);
      const double b2 = MathAbs(r[2].close - r[2].open);
      const double b3 = MathAbs(r[3].close - r[3].open);
      const double b4 = MathAbs(r[4].close - r[4].open);
      double avg = (b2 + b3 + b4) / 3.0;
      if(avg <= 0.0) avg = b1;

      // Displacement on closed bar
      if(r[1].close > r[1].open && b1 >= avg * 1.7)
        { z.bullDisp = true; z.score += 2; }
      if(r[1].close < r[1].open && b1 >= avg * 1.7)
        { z.bearDisp = true; z.score += 2; }

      // Classic 3-candle FVG using [3],[2],[1] closed
      if(r[3].high < r[1].low)
        {
         z.bullFVG = true;
         z.zoneLo = r[3].high;
         z.zoneHi = r[1].low;
         // untested if bar[0] and [1] body didn't fully fill (bar1 created it)
         z.score += 3;
        }
      if(r[3].low > r[1].high)
        {
         z.bearFVG = true;
         z.zoneLo = r[1].high;
         z.zoneHi = r[3].low;
         z.score += 3;
        }

      // Order block = last opposing candle before impulse (bar 2 if impulsive bar1)
      if(z.bullDisp && r[2].close < r[2].open)
        {
         z.bullOB = true;
         if(!(z.zoneHi > z.zoneLo))
           { z.zoneLo = r[2].low; z.zoneHi = r[2].high; }
         z.score += 2;
        }
      if(z.bearDisp && r[2].close > r[2].open)
        {
         z.bearOB = true;
         if(!(z.zoneHi > z.zoneLo))
           { z.zoneLo = r[2].low; z.zoneHi = r[2].high; }
         z.score += 2;
        }

      if(z.zoneHi > z.zoneLo)
        {
         const double h = z.zoneHi - z.zoneLo;
         const double pad = h * 0.35;
         if(bid <= z.zoneHi + pad && bid >= z.zoneLo - pad)
           {
            if(z.bullFVG || z.bullOB || z.bullDisp) z.bullZoneTouch = true;
            if(z.bearFVG || z.bearOB || z.bearDisp) z.bearZoneTouch = true;
           }
        }

      if(z.bullFVG || z.bearFVG) z.note = "FVG";
      else if(z.bullOB || z.bearOB) z.note = "order block";
      else if(z.bullDisp || z.bearDisp) z.note = "displacement";
      else z.note = "awaiting zone";
      return z;
     }
  };

//==================================================================
// 7) STRATEGY / ENTRY ENGINE
//==================================================================
class CSaStrategyEngine
  {
private:
   CSaStructureEngine m_structure;
   CSaLiquidityEngine m_liquidity;
   CSaZoneEngine      m_zones;

   // Strict M5 confirmation — reduces false breaks (precision focus)
   bool M5Buy(const MqlRates &m5[], const int n)
     {
      if(n < 4) return false;
      const double body = m5[1].close - m5[1].open;
      const double range = m5[1].high - m5[1].low;
      if(range <= 0.0 || body <= 0.0) return false;
      const bool bull = (m5[1].close > m5[1].open);
      const bool up = (m5[1].close > m5[2].close && m5[2].close >= m5[3].close);
      const bool strongBody = (body >= range * 0.55);          // close in upper half decisively
      const bool breaksMicro = (m5[1].close > m5[2].high);    // micro BOS on M5
      return (bull && strongBody && up && breaksMicro);
     }

   bool M5Sell(const MqlRates &m5[], const int n)
     {
      if(n < 4) return false;
      const double body = m5[1].open - m5[1].close;
      const double range = m5[1].high - m5[1].low;
      if(range <= 0.0 || body <= 0.0) return false;
      const bool bear = (m5[1].close < m5[1].open);
      const bool dn = (m5[1].close < m5[2].close && m5[2].close <= m5[3].close);
      const bool strongBody = (body >= range * 0.55);
      const bool breaksMicro = (m5[1].close < m5[2].low);
      return (bear && strongBody && dn && breaksMicro);
     }

   ENUM_SA_MKT Regime(const double atr, const double atrAvg)
     {
      if(atrAvg <= 0.0) return SA_MKT_NORMAL;
      if(atr >= atrAvg * InpExtremeVolAtrMult) return SA_MKT_EXTREME;
      if(atr >= atrAvg * InpHighVolAtrMult) return SA_MKT_HIGH;
      if(atr <= atrAvg * 0.55) return SA_MKT_LOW;
      return SA_MKT_NORMAL;
     }

public:
   void SetSwingStrength(const int s) { m_structure.SetStrength(s); }

   SaSetup Evaluate(CSaDataCache &data, const CSaSymbolCache &sym, const double bid, const double ask)
     {
      SaSetup s;
      s.side = SA_SIDE_NONE;
      s.path = SA_PATH_NONE;
      s.bias = SA_BIAS_FLAT;
      s.mkt = SA_MKT_NORMAL;
      s.score = 0;
      s.reason = "scanning";
      s.atrH1 = data.Atr();
      s.spreadPts = (sym.point > 0.0 ? (ask - bid) / sym.point : 0.0);
      s.mkt = Regime(data.Atr(), data.AtrAvg());

      MqlRates h4[], h1[], m5[];
      if(!data.GetH4(h4) || !data.GetH1(h1) || !data.GetM5(m5))
        {
         s.reason = "rates unavailable";
         return s;
        }
      const int h4n = ArraySize(h4);
      const int h1n = ArraySize(h1);
      const int m5n = ArraySize(m5);

      SaStructure st = m_structure.Evaluate(h4, h4n, h1, h1n);
      SaLiquidity liq = m_liquidity.Evaluate(h1, h1n, sym.Pip(), data.Atr());
      SaZones zone = m_zones.Evaluate(h1, h1n, bid);

      s.bias = st.biasH4;
      int score = liq.score + zone.score;
      if(st.bosBull || st.bosBear) score += 3;
      if(st.chochBull || st.chochBear) score += 3;
      if(st.biasH4 != SA_BIAS_FLAT) score += 2;

      // Higher bar in extreme vol (still allowed — precision, not block)
      const int needScore = (s.mkt == SA_MKT_EXTREME ? InpMinScore + 3 :
                             s.mkt == SA_MKT_HIGH     ? InpMinScore + 1 : InpMinScore);

      // Path A — continuation (strict confluence for ~70% precision target)
      if(InpAllowContinuation && st.biasH4 == SA_BIAS_BULL)
        {
         const bool m5ok = M5Buy(m5, m5n);
         int conf = 0;
         if(st.biasH4 == SA_BIAS_BULL) conf++;
         if(st.bosBull) conf++;
         if(zone.bullDisp) conf++;
         if(zone.bullFVG || zone.bullOB) conf++;
         if(zone.bullZoneTouch || !InpRequireZoneTouch) conf++;
         if(liq.sellSideSweep || liq.equalLows) conf++; // opposing liq taken / demand
         if(m5ok) conf++;

         const bool institutional = (st.bosBull && (zone.bullFVG || zone.bullOB) && zone.bullDisp);
         const bool locationOk = (!InpRequireZoneTouch || zone.bullZoneTouch || zone.bullFVG || zone.bullOB);
         if(institutional && locationOk && m5ok && conf >= InpMinConfluence)
           {
            s.side = SA_SIDE_BUY;
            s.path = SA_PATH_CONTINUATION;
            s.score = score + 8 + conf;
            if(s.score >= needScore)
              {
               s.reason = "CONT precision | " + st.note + " | " + zone.note;
               return s;
              }
           }
        }
      if(InpAllowContinuation && st.biasH4 == SA_BIAS_BEAR)
        {
         const bool m5ok = M5Sell(m5, m5n);
         int conf = 0;
         if(st.biasH4 == SA_BIAS_BEAR) conf++;
         if(st.bosBear) conf++;
         if(zone.bearDisp) conf++;
         if(zone.bearFVG || zone.bearOB) conf++;
         if(zone.bearZoneTouch || !InpRequireZoneTouch) conf++;
         if(liq.buySideSweep || liq.equalHighs) conf++;
         if(m5ok) conf++;

         const bool institutional = (st.bosBear && (zone.bearFVG || zone.bearOB) && zone.bearDisp);
         const bool locationOk = (!InpRequireZoneTouch || zone.bearZoneTouch || zone.bearFVG || zone.bearOB);
         if(institutional && locationOk && m5ok && conf >= InpMinConfluence)
           {
            s.side = SA_SIDE_SELL;
            s.path = SA_PATH_CONTINUATION;
            s.score = score + 8 + conf;
            if(s.score >= needScore)
              {
               s.reason = "CONT precision | " + st.note + " | " + zone.note;
               return s;
              }
           }
        }

      // Path B — reversal: sweep + CHoCH + zone + strict M5 (no weak BOS-only reverses)
      if(InpAllowReversal && liq.sellSideSweep && st.chochBull && (zone.bullDisp || zone.bullFVG || zone.bullOB) && M5Buy(m5, m5n))
        {
         int conf = 4; // sweep, choch, zone family, m5
         if(zone.bullZoneTouch || zone.bullFVG) conf++;
         if(zone.bullDisp) conf++;
         s.side = SA_SIDE_BUY;
         s.path = SA_PATH_REVERSAL;
         s.score = score + 10 + conf;
         if(conf >= InpMinConfluence && s.score >= needScore)
           {
            s.reason = "REV precision | sell-side sweep | " + st.note;
            return s;
           }
         s.side = SA_SIDE_NONE;
         s.path = SA_PATH_NONE;
        }
      if(InpAllowReversal && liq.buySideSweep && st.chochBear && (zone.bearDisp || zone.bearFVG || zone.bearOB) && M5Sell(m5, m5n))
        {
         int conf = 4;
         if(zone.bearZoneTouch || zone.bearFVG) conf++;
         if(zone.bearDisp) conf++;
         s.side = SA_SIDE_SELL;
         s.path = SA_PATH_REVERSAL;
         s.score = score + 10 + conf;
         if(conf >= InpMinConfluence && s.score >= needScore)
           {
            s.reason = "REV precision | buy-side sweep | " + st.note;
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
// 8) RISK + POSITION MANAGER
//==================================================================
class CSaRiskManager
  {
private:
   long     m_magic;
   double   m_dayStartEquity;
   datetime m_dayStamp;
   int      m_consecLoss;

   void RollDay()
     {
      MqlDateTime dt;
      TimeToStruct(TimeTradeServer(), dt);
      datetime day = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
      if(day != m_dayStamp)
        {
         m_dayStamp = day;
         m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        }
     }

public:
                     CSaRiskManager(void): m_magic(0), m_dayStartEquity(0), m_dayStamp(0), m_consecLoss(0) {}
   void              Init(const long magic)
     {
      m_magic = magic;
      m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStamp = 0;
      RollDay();
     }

   int CountPositions(const string symbolFilter = "")
     {
      int c = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         if(!PositionSelectByTicket(PositionGetTicket(i)))
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
         if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      return p;
     }

   bool CanOpen(const string symbol, string &why)
     {
      RollDay();
      if(CountPositions() >= InpMaxTrades)
        { why = "max trades"; return false; }
      if(CountPositions(symbol) >= InpMaxTrades)
        { why = "max symbol trades"; return false; }

      if(InpMaxDailyDDPercent > 0.0 && m_dayStartEquity > 0.0)
        {
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         double dd = (m_dayStartEquity - eq) / m_dayStartEquity * 100.0;
         if(dd >= InpMaxDailyDDPercent)
           { why = "daily DD limit"; return false; }
        }
      if(InpMaxConsecutiveLoss > 0 && m_consecLoss >= InpMaxConsecutiveLoss)
        { why = "consec loss limit"; return false; }

      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
        { why = "trading disabled"; return false; }

      why = "ok";
      return true;
     }

   bool BuildStops(const CSaSymbolCache &sym, const ENUM_SA_SIDE side, const ENUM_SA_MKT mkt,
                   const double atr, double &entry, double &sl, double &tp, string &why)
     {
      double boost = 1.0;
      if(mkt == SA_MKT_HIGH) boost = InpVolSLBoostHigh;
      if(mkt == SA_MKT_EXTREME) boost = InpVolSLBoostExtreme;

      double stopDist = atr * InpAtrMultSL * boost;
      const double minDist = MathMax(sym.stopsLevel, sym.freezeLevel) * sym.point;
      if(stopDist < MathMax(minDist, sym.Pip() * 3.0))
         stopDist = MathMax(minDist, sym.Pip() * 3.0);

      if(side == SA_SIDE_BUY)
        {
         entry = SymbolInfoDouble(sym.symbol, SYMBOL_ASK);
         sl = sym.NormPrice(entry - stopDist);
         tp = sym.NormPrice(entry + stopDist * InpRewardRatio);
         if(sl >= entry || tp <= entry)
           { why = "invalid buy stops"; return false; }
        }
      else if(side == SA_SIDE_SELL)
        {
         entry = SymbolInfoDouble(sym.symbol, SYMBOL_BID);
         sl = sym.NormPrice(entry + stopDist);
         tp = sym.NormPrice(entry - stopDist * InpRewardRatio);
         if(sl <= entry || tp >= entry)
           { why = "invalid sell stops"; return false; }
        }
      else
        { why = "no side"; return false; }

      // broker distance validation vs current price
      if(side == SA_SIDE_BUY)
        {
         if(entry - sl < minDist) sl = sym.NormPrice(entry - minDist);
         if(tp - entry < minDist) tp = sym.NormPrice(entry + minDist);
        }
      else
        {
         if(sl - entry < minDist) sl = sym.NormPrice(entry + minDist);
         if(entry - tp < minDist) tp = sym.NormPrice(entry - minDist);
        }

      why = "ok";
      return true;
     }

   bool MarginOK(const string symbol, const ENUM_SA_SIDE side, const double lots, string &why)
     {
      double margin = 0.0;
      ENUM_ORDER_TYPE ot = (side == SA_SIDE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double price = (side == SA_SIDE_BUY ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(symbol, SYMBOL_BID));
      if(!OrderCalcMargin(ot, symbol, lots, price, margin))
        { why = "margin calc fail"; return false; }
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        { why = "insufficient margin"; return false; }
      why = "ok";
      return true;
     }

   void OnDealClosedLoss(const bool isLoss)
     {
      if(isLoss) m_consecLoss++;
      else m_consecLoss = 0;
     }

   void ManageOpenPositions(CTrade &trade, const long magic)
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
         if(point <= 0.0)
            continue;

         double risk = (type == POSITION_TYPE_BUY ? open - sl : sl - open);
         if(risk <= 0.0)
            continue;

         // Break-even
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
               const double newSL = NormalizeDouble(open, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
               trade.PositionModify(ticket, newSL, tp);
               sl = newSL;
              }
           }

         // Optional trailing
         if(InpUseTrailing)
           {
            bool trailArmed = false;
            if(type == POSITION_TYPE_BUY && bid >= open + risk * InpTrailStartR) trailArmed = true;
            if(type == POSITION_TYPE_SELL && ask <= open - risk * InpTrailStartR) trailArmed = true;
            if(trailArmed)
              {
               const double step = risk * InpTrailStepR;
               if(type == POSITION_TYPE_BUY)
                 {
                  double nsl = NormalizeDouble(bid - step, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  if(nsl > sl + point)
                     trade.PositionModify(ticket, nsl, tp);
                 }
               else
                 {
                  double nsl = NormalizeDouble(ask + step, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  if(sl == 0.0 || nsl < sl - point)
                     trade.PositionModify(ticket, nsl, tp);
                 }
              }
           }
        }
     }
  };

//==================================================================
// 9) EXECUTION ENGINE
//==================================================================
class CSaExecutionEngine
  {
private:
   CTrade  m_trade;
   long    m_magic;
   int     m_slippage;
   string  m_lastStatus;

public:
                     CSaExecutionEngine(void): m_magic(0), m_slippage(30), m_lastStatus("idle") {}

   void Init(const long magic, const int slippage)
     {
      m_magic = magic;
      m_slippage = slippage;
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetAsyncMode(false);
     }

   void ManagePositions(CSaRiskManager &risk)
     {
      risk.ManageOpenPositions(m_trade, m_magic);
     }
   string LastStatus() { return m_lastStatus; }

   bool Send(const string symbol, const ENUM_SA_SIDE side, const double lots,
             const double sl, const double tp, string &why)
     {
      if(side == SA_SIDE_NONE || lots <= 0.0)
        { why = "invalid order params"; m_lastStatus = why; return false; }

      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFillingBySymbol(symbol);

      for(int attempt = 1; attempt <= InpMaxRetries; attempt++)
        {
         ResetLastError();
         bool ok = false;
         if(side == SA_SIDE_BUY)
           {
            const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            ok = m_trade.Buy(lots, symbol, ask, sl, tp, SA_COMMENT);
           }
         else
           {
            const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            ok = m_trade.Sell(lots, symbol, bid, sl, tp, SA_COMMENT);
           }

         if(ok)
           {
            why = "filled";
            m_lastStatus = "FILLED";
            return true;
           }

         const int rc = (int)m_trade.ResultRetcode();
         why = StringFormat("retcode=%d %s", rc, m_trade.ResultRetcodeDescription());
         m_lastStatus = why;
         // Retry a few times on any failure (portable retry loop)
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
// 10) DASHBOARD
//==================================================================
class CSaDashboard
  {
private:
   int m_x, m_y, m_w, m_h;

   void Box(const string id, const int x, const int y, const int w, const int h,
            const color bg, const color border)
     {
      const string name = SA_UI_PREFIX + id;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 200);
     }

   void Lbl(const string id, const int x, const int y, const string text,
            const color clr, const int size = 9, const string font = "Consolas")
     {
      const string name = SA_UI_PREFIX + id;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 201);
     }

   string BiasTxt(const ENUM_SA_BIAS b)
     {
      if(b == SA_BIAS_BULL) return "BULLISH";
      if(b == SA_BIAS_BEAR) return "BEARISH";
      return "NEUTRAL";
     }
   string SideTxt(const ENUM_SA_SIDE s)
     {
      if(s == SA_SIDE_BUY) return "BUY";
      if(s == SA_SIDE_SELL) return "SELL";
      return "FLAT";
     }
   string PathTxt(const ENUM_SA_PATH p)
     {
      if(p == SA_PATH_CONTINUATION) return "CONTINUATION";
      if(p == SA_PATH_REVERSAL) return "REVERSAL";
      return "-";
     }
   string MktTxt(const ENUM_SA_MKT m)
     {
      if(m == SA_MKT_LOW) return "LOW VOL";
      if(m == SA_MKT_HIGH) return "HIGH VOL";
      if(m == SA_MKT_EXTREME) return "EXTREME VOL";
      return "NORMAL";
     }

public:
                     CSaDashboard(void): m_x(14), m_y(16), m_w(300), m_h(430) {}

   void Destroy()
     {
      const int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; --i)
        {
         const string name = ObjectName(0, i);
         if(StringFind(name, SA_UI_PREFIX) == 0)
            ObjectDelete(0, name);
        }
     }

   void Render(const string symbol,
               const SaSetup &setup,
               const int openTrades,
               const double lot,
               const double balance,
               const double equity,
               const double floating,
               const string lastAction,
               const string eaStatus,
               const string execStatus,
               const string broker)
     {
      Box("bg", m_x, m_y, m_w, m_h, C'16,16,20', C'190,25,45');
      Box("hdr", m_x, m_y, m_w, 44, C'130,8,28', C'230,45,65');

      const int x = m_x + 12;
      int y = m_y + 10;
      Lbl("t", x, y, "SNIPER AI", clrWhite, 14, "Arial Bold");
      y = m_y + 48;
      Lbl("sub", x, y, "24/7  |  HIGH PRECISION SNIPER", C'230,190,190', 8, "Arial");

      color sigClr = clrSilver;
      if(setup.side == SA_SIDE_BUY) sigClr = C'45,230,130';
      if(setup.side == SA_SIDE_SELL) sigClr = C'255,75,75';

      y = m_y + 72;
      Lbl("sym", x, y, "SYMBOL      " + symbol, clrWhite, 10); y += 17;
      Lbl("tf", x, y, "STACK       H4 / H1 / M5", C'180,200,220', 9); y += 17;
      Lbl("bias", x, y, "BIAS        " + BiasTxt(setup.bias), clrAqua, 10); y += 17;
      Lbl("trend", x, y, "TREND       " + BiasTxt(setup.bias), C'160,220,255', 9); y += 17;
      Lbl("sig", x, y, "SIGNAL      " + SideTxt(setup.side), sigClr, 11, "Arial Bold"); y += 17;
      Lbl("path", x, y, "ENTRY TYPE  " + PathTxt(setup.path), clrGold, 10); y += 17;
      Lbl("score", x, y, StringFormat("SETUP SCORE %d", setup.score), clrOrange, 10); y += 17;
      Lbl("open", x, y, StringFormat("OPEN        %d / %d", openTrades, InpMaxTrades), clrWhite, 10); y += 17;
      Lbl("lot", x, y, StringFormat("LOT         %.2f", lot), clrWhite, 10); y += 17;
      Lbl("bal", x, y, StringFormat("BALANCE     %.2f", balance), C'180,220,255', 9); y += 16;
      Lbl("eq", x, y, StringFormat("EQUITY      %.2f", equity), C'180,220,255', 9); y += 16;
      color fltClr = C'255,100,100';
      if(floating >= 0.0) fltClr = C'80,220,140';
      Lbl("flt", x, y, StringFormat("FLOATING    %.2f", floating), fltClr, 9); y += 16;
      Lbl("spr", x, y, StringFormat("SPREAD      %.1f pts", setup.spreadPts), clrSilver, 9); y += 16;
      Lbl("atr", x, y, StringFormat("ATR(H1)     %.5f", setup.atrH1), clrSilver, 9); y += 16;
      Lbl("mkt", x, y, "MARKET      " + MktTxt(setup.mkt), C'160,255,170', 9); y += 16;
      Lbl("exec", x, y, "EXECUTION   " + execStatus, C'255,140,140', 8); y += 15;
      Lbl("ea", x, y, "EA STATUS   " + eaStatus, C'200,200,210', 8); y += 15;
      Lbl("br", x, y, "BROKER      " + broker, C'160,160,170', 8); y += 15;
      Lbl("srv", x, y, "SERVER      " + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS), C'140,140,150', 8); y += 16;

      string reason = setup.reason;
      if(StringLen(reason) > 44)
         reason = StringSubstr(reason, 0, 44) + "...";
      Lbl("st", x, y, "TRADE STATUS", clrSilver, 8); y += 14;
      Lbl("st2", x, y, reason, clrSilver, 8); y += 16;
      Lbl("last", x, y, "LAST  " + lastAction, clrGray, 8);

      ChartRedraw(0);
     }
  };

//==================================================================
// 11) CORE STATE
//==================================================================
CSaSymbolCache      g_sym;
CSaDataCache        g_data;
CSaStrategyEngine   g_strategy;
CSaRiskManager      g_risk;
CSaExecutionEngine  g_exec;
CSaDashboard        g_dash;

datetime g_lastM5 = 0;
datetime g_lastEntryM5 = 0;
string   g_lastAction = "boot";
string   g_eaStatus = "init";
SaSetup  g_setup;
int      g_tick = 0;

void SaLog(const string msg)
  {
   if(InpLogEvents)
      Print(SA_LOG_PREFIX, msg);
  }

bool SaValidateInputs()
  {
   if(InpLot <= 0.0) return false;
   if(InpMaxTrades < 1) return false;
   if(InpAtrMultSL <= 0.0 || InpRewardRatio <= 0.0) return false;
   if(InpMinScore < 0) return false;
   return true;
  }

bool SaFire(const SaSetup &setup)
  {
   if(setup.side == SA_SIDE_NONE || setup.score < InpMinScore)
      return false;

   string why;
   if(!g_risk.CanOpen(_Symbol, why))
     {
      g_lastAction = why;
      g_eaStatus = "blocked";
      return false;
     }

   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!g_risk.BuildStops(g_sym, setup.side, setup.mkt, setup.atrH1, entry, sl, tp, why))
     {
      g_lastAction = why;
      return false;
     }

   const double lots = g_sym.NormVol(InpLot);
   if(!g_risk.MarginOK(_Symbol, setup.side, lots, why))
     {
      g_lastAction = why;
      return false;
     }

   if(!g_exec.Send(_Symbol, setup.side, lots, sl, tp, why))
     {
      g_lastAction = why;
      g_eaStatus = "exec fail";
      SaLog("order failed: " + why);
      return false;
     }

   g_lastEntryM5 = g_lastM5;
   g_lastAction = (setup.side == SA_SIDE_BUY ? "BUY filled" : "SELL filled");
   g_eaStatus = "in market";
   SaLog(g_lastAction + " comment=" + SA_COMMENT);
   return true;
  }

void SaRefreshDashboard()
  {
   if(!InpShowDashboard)
      return;
   g_dash.Render(_Symbol,
                 g_setup,
                 g_risk.CountPositions(),
                 InpLot,
                 AccountInfoDouble(ACCOUNT_BALANCE),
                 AccountInfoDouble(ACCOUNT_EQUITY),
                 g_risk.FloatingPnL(),
                 g_lastAction,
                 g_eaStatus,
                 g_exec.LastStatus(),
                 AccountInfoString(ACCOUNT_COMPANY));
  }

//==================================================================
// 12) LIFECYCLE
//==================================================================
int OnInit()
  {
   if(!SaValidateInputs())
     {
      Print(SA_LOG_PREFIX, "invalid inputs");
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

   g_strategy.SetSwingStrength(InpSwingStrength);
   g_risk.Init(InpMagic);
   g_exec.Init(InpMagic, InpMaxSlippagePoints);

   g_setup.side = SA_SIDE_NONE;
   g_setup.path = SA_PATH_NONE;
   g_setup.bias = SA_BIAS_FLAT;
   g_setup.mkt = SA_MKT_NORMAL;
   g_setup.score = 0;
   g_setup.atrH1 = 0.0;
   g_setup.spreadPts = 0.0;
   g_setup.reason = "armed";
   g_eaStatus = "online";
   g_lastAction = "online 24/7";

   if(!g_data.Refresh())
      SaLog("initial refresh pending history");

   SaRefreshDashboard();
   SaLog(StringFormat("ONLINE %s lot=%.2f max=%d", _Symbol, InpLot, InpMaxTrades));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_data.Release();
   g_dash.Destroy();
   Comment("");
   SaLog(StringFormat("stopped reason=%d", reason));
  }

void OnTick()
  {
   g_tick++;

   // Position management every tick (BE / optional trail)
   g_exec.ManagePositions(g_risk);

   if(!g_data.Refresh())
     {
      g_eaStatus = "data wait";
      if(g_tick % InpDashRefreshTicks == 0)
         SaRefreshDashboard();
      return;
     }

   const bool newM5 = g_data.NewM5Bar(g_lastM5);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Evaluate on new M5 or throttled for dashboard accuracy
   if(newM5 || (g_tick % InpDashRefreshTicks == 0))
     {
      g_setup = g_strategy.Evaluate(g_data, g_sym, bid, ask);
      g_eaStatus = "scanning";

      if(newM5 && InpTradeChartOnly)
        {
         if(!(InpOneEntryPerM5 && g_lastEntryM5 == g_lastM5))
            SaFire(g_setup);
        }
      SaRefreshDashboard();
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // Track consecutive losses from closed deals of this EA
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   HistorySelect(0, TimeCurrent());
   if(!HistoryDealSelect(trans.deal))
      return;
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
