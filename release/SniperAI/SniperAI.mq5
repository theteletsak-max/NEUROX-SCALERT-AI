//+------------------------------------------------------------------+
//| SniperAI.mq5                                                      |
//| SNIPER AI — SINGLE FILE delivery                                  |
//| Put this file + SniperAI_Watermark.bmp in MQL5/Experts/           |
//| Compile (F7) → attach to chart → enable Algo Trading              |
//+------------------------------------------------------------------+
#property copyright   "Sniper AI"
#property link        "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version     "1.00"
#property description "SNIPER AI — institutional sniper robot with instant execution"
#property description "Trades 24/7 including news/high volatility. No session filter."
#property strict

// Watermark must sit next to this .mq5 (same Experts folder)
#resource "SniperAI_Watermark.bmp"

#include <Trade/Trade.mqh>

//===== BEGIN SA_Util.mqh =====
//+------------------------------------------------------------------+
//| SA_Util.mqh — shared helpers                                       |
//+------------------------------------------------------------------+

enum ENUM_SA_BIAS
  {
   SA_BIAS_NONE = 0,
   SA_BIAS_BULL = 1,
   SA_BIAS_BEAR = -1
  };

enum ENUM_SA_SIGNAL
  {
   SA_SIG_NONE = 0,
   SA_SIG_BUY  = 1,
   SA_SIG_SELL = -1
  };

double SA_PipSize(const string symbol)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double SA_NormPrice(const string symbol, const double price)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double SA_NormLots(const string symbol, double lots)
  {
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      stepLot = 0.01;
   lots = MathFloor(lots / stepLot + 1e-12) * stepLot;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return NormalizeDouble(lots, (stepLot < 0.01 ? 3 : 2));
  }

bool SA_CopyOHLC(const string symbol, const ENUM_TIMEFRAMES tf, const int count,
                 MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   int got = CopyRates(symbol, tf, 0, count, rates);
   return (got >= count);
  }

double SA_ATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
  {
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE)
      return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, shift, 1, buf) < 1)
     {
      IndicatorRelease(h);
      return 0.0;
     }
   double v = buf[0];
   IndicatorRelease(h);
   return v;
  }

string SA_BiasText(const ENUM_SA_BIAS b)
  {
   if(b == SA_BIAS_BULL) return "BULLISH";
   if(b == SA_BIAS_BEAR) return "BEARISH";
   return "NEUTRAL";
  }

string SA_SigText(const ENUM_SA_SIGNAL s)
  {
   if(s == SA_SIG_BUY) return "BUY";
   if(s == SA_SIG_SELL) return "SELL";
   return "FLAT";
  }

//+------------------------------------------------------------------+
//===== END SA_Util.mqh =====

//===== BEGIN SA_Structure.mqh =====
//+------------------------------------------------------------------+
//| SA_Structure.mqh — swings, BOS, CHoCH, HTF bias                    |
//+------------------------------------------------------------------+


struct SAStructureState
  {
   ENUM_SA_BIAS bias;
   bool         bosBull;
   bool         bosBear;
   bool         chochBull;
   bool         chochBear;
   double       lastSwingHigh;
   double       lastSwingLow;
   string       note;
  };

class CSniperStructure
  {
private:
   int m_swingStrength;

   bool IsSwingHigh(const MqlRates &r[], const int i, const int strength)
     {
      for(int k = 1; k <= strength; k++)
        {
         if(r[i].high <= r[i - k].high || r[i].high <= r[i + k].high)
            return false;
        }
      return true;
     }

   bool IsSwingLow(const MqlRates &r[], const int i, const int strength)
     {
      for(int k = 1; k <= strength; k++)
        {
         if(r[i].low >= r[i - k].low || r[i].low >= r[i + k].low)
            return false;
        }
      return true;
     }

public:
                     CSniperStructure(void): m_swingStrength(2) {}
   void              SetStrength(const int s) { m_swingStrength = MathMax(1, s); }

   ENUM_SA_BIAS      BiasFromTF(const string symbol, const ENUM_TIMEFRAMES tf, const int bars = 120)
     {
      MqlRates r[];
      if(!SA_CopyOHLC(symbol, tf, bars, r))
         return SA_BIAS_NONE;

      double sh[], sl[];
      datetime th[], tl[];
      ArrayResize(sh, 0);
      ArrayResize(sl, 0);

      int strength = m_swingStrength;
      for(int i = bars - strength - 2; i >= strength + 1; i--)
        {
         if(IsSwingHigh(r, i, strength))
           {
            int n = ArraySize(sh);
            ArrayResize(sh, n + 1);
            ArrayResize(th, n + 1);
            sh[n] = r[i].high;
            th[n] = r[i].time;
           }
         if(IsSwingLow(r, i, strength))
           {
            int n = ArraySize(sl);
            ArrayResize(sl, n + 1);
            ArrayResize(tl, n + 1);
            sl[n] = r[i].low;
            tl[n] = r[i].time;
           }
        }

      if(ArraySize(sh) < 2 || ArraySize(sl) < 2)
         return SA_BIAS_NONE;

      // series arrays: index 0 is most recent swing found in loop order (oldest first) — fix to recent
      // We appended oldest->newest while scanning high i to low i, so last elements are most recent.
      int nhs = ArraySize(sh);
      int nls = ArraySize(sl);
      bool hh = sh[nhs - 1] > sh[nhs - 2];
      bool hl = sl[nls - 1] > sl[nls - 2];
      bool lh = sh[nhs - 1] < sh[nhs - 2];
      bool ll = sl[nls - 1] < sl[nls - 2];

      if(hh && hl) return SA_BIAS_BULL;
      if(lh && ll) return SA_BIAS_BEAR;
      if(hh || hl) return SA_BIAS_BULL;
      if(lh || ll) return SA_BIAS_BEAR;
      return SA_BIAS_NONE;
     }

   SAStructureState  Evaluate(const string symbol,
                              const ENUM_TIMEFRAMES biasTf,
                              const ENUM_TIMEFRAMES setupTf)
     {
      SAStructureState st;
      st.bias = BiasFromTF(symbol, biasTf);
      st.bosBull = st.bosBear = false;
      st.chochBull = st.chochBear = false;
      st.lastSwingHigh = 0;
      st.lastSwingLow = 0;
      st.note = "structure warm";

      MqlRates r[];
      const int bars = 150;
      if(!SA_CopyOHLC(symbol, setupTf, bars, r))
         return st;

      int strength = m_swingStrength;
      double recentHigh = 0, prevHigh = 0, recentLow = 0, prevLow = 0;
      int foundH = 0, foundL = 0;

      for(int i = strength + 1; i < bars - strength - 1; i++)
        {
         if(foundH < 2 && IsSwingHigh(r, i, strength))
           {
            if(foundH == 0) recentHigh = r[i].high;
            else prevHigh = r[i].high;
            foundH++;
           }
         if(foundL < 2 && IsSwingLow(r, i, strength))
           {
            if(foundL == 0) recentLow = r[i].low;
            else prevLow = r[i].low;
            foundL++;
           }
         if(foundH >= 2 && foundL >= 2)
            break;
        }

      st.lastSwingHigh = recentHigh;
      st.lastSwingLow  = recentLow;

      // Closed bar break of most recent swing = BOS / CHoCH candidate
      double close1 = r[1].close;
      if(recentHigh > 0.0 && close1 > recentHigh)
        {
         if(st.bias == SA_BIAS_BULL || st.bias == SA_BIAS_NONE)
            st.bosBull = true;
         if(st.bias == SA_BIAS_BEAR)
            st.chochBull = true;
        }
      if(recentLow > 0.0 && close1 < recentLow)
        {
         if(st.bias == SA_BIAS_BEAR || st.bias == SA_BIAS_NONE)
            st.bosBear = true;
         if(st.bias == SA_BIAS_BULL)
            st.chochBear = true;
        }

      if(st.bosBull) st.note = "BOS bullish";
      else if(st.bosBear) st.note = "BOS bearish";
      else if(st.chochBull) st.note = "CHoCH bullish";
      else if(st.chochBear) st.note = "CHoCH bearish";
      else st.note = "awaiting structure break";

      return st;
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Structure.mqh =====

//===== BEGIN SA_Liquidity.mqh =====
//+------------------------------------------------------------------+
//| SA_Liquidity.mqh — equal highs/lows, sweeps, stop hunts            |
//+------------------------------------------------------------------+


struct SALiquidityState
  {
   bool   buySideSwept;   // highs taken then rejected
   bool   sellSideSwept;  // lows taken then rejected
   bool   equalHighs;
   bool   equalLows;
   double poolHigh;
   double poolLow;
   string note;
   int    scoreBonus;
  };

class CSniperLiquidity
  {
public:
   SALiquidityState Evaluate(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback = 40)
     {
      SALiquidityState st;
      st.buySideSwept = st.sellSideSwept = false;
      st.equalHighs = st.equalLows = false;
      st.poolHigh = st.poolLow = 0;
      st.note = "liq map";
      st.scoreBonus = 0;

      MqlRates r[];
      if(!SA_CopyOHLC(symbol, tf, lookback + 5, r))
         return st;

      double pip = SA_PipSize(symbol);
      double tol = pip * 3.0;

      // Equal highs / lows among recent swings (bars 2..lookback)
      int eqH = 0, eqL = 0;
      double refH = r[2].high;
      double refL = r[2].low;
      for(int i = 3; i < lookback; i++)
        {
         if(MathAbs(r[i].high - refH) <= tol) eqH++;
         if(MathAbs(r[i].low - refL) <= tol) eqL++;
        }
      st.equalHighs = (eqH >= 1);
      st.equalLows  = (eqL >= 1);

      // Pool = recent extreme
      st.poolHigh = r[2].high;
      st.poolLow  = r[2].low;
      for(int i = 2; i < lookback; i++)
        {
         if(r[i].high > st.poolHigh) st.poolHigh = r[i].high;
         if(r[i].low < st.poolLow) st.poolLow = r[i].low;
        }

      // Sweep: wick beyond pool then close back inside (stop hunt)
      // Buy-side sweep = pierce above recent highs then close below
      double recentHigh = r[3].high;
      double recentLow  = r[3].low;
      for(int i = 3; i < MathMin(15, lookback); i++)
        {
         if(r[i].high > recentHigh) recentHigh = r[i].high;
         if(r[i].low < recentLow) recentLow = r[i].low;
        }

      if(r[1].high > recentHigh && r[1].close < recentHigh)
        {
         st.buySideSwept = true;
         st.scoreBonus += 2;
         st.note = "buy-side liquidity swept";
        }
      if(r[1].low < recentLow && r[1].close > recentLow)
        {
         st.sellSideSwept = true;
         st.scoreBonus += 2;
         st.note = "sell-side liquidity swept";
        }

      if(st.equalHighs) st.scoreBonus += 1;
      if(st.equalLows)  st.scoreBonus += 1;

      if(!st.buySideSwept && !st.sellSideSwept)
         st.note = st.equalHighs || st.equalLows ? "equal liquidity mapped" : "liquidity scanning";

      return st;
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Liquidity.mqh =====

//===== BEGIN SA_Zones.mqh =====
//+------------------------------------------------------------------+
//| SA_Zones.mqh — displacement, FVG, order blocks                     |
//+------------------------------------------------------------------+


struct SAZoneState
  {
   bool   bullDisplacement;
   bool   bearDisplacement;
   bool   bullFVG;
   bool   bearFVG;
   bool   bullOB;
   bool   bearOB;
   bool   priceInBullZone;
   bool   priceInBearZone;
   double zoneLow;
   double zoneHigh;
   string note;
   int    scoreBonus;
  };

class CSniperZones
  {
private:
   bool IsBullEngulf(const MqlRates &a, const MqlRates &b) // a=older,b=newer? use series: 2 then 1
     {
      return (b.close > b.open && b.close > a.open && b.close > a.close && b.open <= a.close);
     }
   bool IsBearEngulf(const MqlRates &a, const MqlRates &b)
     {
      return (b.close < b.open && b.close < a.open && b.close < a.close && b.open >= a.close);
     }

public:
   SAZoneState Evaluate(const string symbol, const ENUM_TIMEFRAMES tf)
     {
      SAZoneState z;
      z.bullDisplacement = z.bearDisplacement = false;
      z.bullFVG = z.bearFVG = false;
      z.bullOB = z.bearOB = false;
      z.priceInBullZone = z.priceInBearZone = false;
      z.zoneLow = z.zoneHigh = 0;
      z.note = "zones";
      z.scoreBonus = 0;

      MqlRates r[];
      if(!SA_CopyOHLC(symbol, tf, 30, r))
         return z;

      double body1 = MathAbs(r[1].close - r[1].open);
      double body2 = MathAbs(r[2].close - r[2].open);
      double body3 = MathAbs(r[3].close - r[3].open);
      double avgBody = (body2 + body3 + MathAbs(r[4].close - r[4].open)) / 3.0;
      if(avgBody <= 0) avgBody = SA_PipSize(symbol);

      // Displacement = impulsive candle
      if(r[1].close > r[1].open && body1 > avgBody * 1.6)
        {
         z.bullDisplacement = true;
         z.scoreBonus += 2;
        }
      if(r[1].close < r[1].open && body1 > avgBody * 1.6)
        {
         z.bearDisplacement = true;
         z.scoreBonus += 2;
        }

      // FVG: gap between candle 3 high and candle 1 low (bull) — using closed bars
      // Bullish FVG: r[3].high < r[1].low
      if(r[3].high < r[1].low)
        {
         z.bullFVG = true;
         z.zoneLow = r[3].high;
         z.zoneHigh = r[1].low;
         z.scoreBonus += 2;
        }
      if(r[3].low > r[1].high)
        {
         z.bearFVG = true;
         z.zoneLow = r[1].high;
         z.zoneHigh = r[3].low;
         z.scoreBonus += 2;
        }

      // Order block: last opposite candle before impulse (bar 2)
      if(z.bullDisplacement || (r[1].close > r[2].high))
        {
         if(r[2].close < r[2].open)
           {
            z.bullOB = true;
            if(z.zoneLow == 0)
              {
               z.zoneLow = r[2].low;
               z.zoneHigh = r[2].high;
              }
            z.scoreBonus += 1;
           }
        }
      if(z.bearDisplacement || (r[1].close < r[2].low))
        {
         if(r[2].close > r[2].open)
           {
            z.bearOB = true;
            if(z.zoneHigh == 0)
              {
               z.zoneLow = r[2].low;
               z.zoneHigh = r[2].high;
              }
            z.scoreBonus += 1;
           }
        }

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(z.zoneHigh > z.zoneLow)
        {
         if(bid >= z.zoneLow && bid <= z.zoneHigh)
           {
            if(z.bullFVG || z.bullOB) z.priceInBullZone = true;
            if(z.bearFVG || z.bearOB) z.priceInBearZone = true;
           }
         // Near zone (within 0.25 of zone height) counts for sniper pullback
         double h = z.zoneHigh - z.zoneLow;
         if(bid <= z.zoneHigh + h * 0.35 && bid >= z.zoneLow - h * 0.35)
           {
            if(z.bullFVG || z.bullOB) z.priceInBullZone = true;
            if(z.bearFVG || z.bearOB) z.priceInBearZone = true;
           }
        }

      // Candle confirmation helpers stored in note
      if(IsBullEngulf(r[2], r[1])) { z.scoreBonus += 1; z.note = "bull engulf + zones"; }
      else if(IsBearEngulf(r[2], r[1])) { z.scoreBonus += 1; z.note = "bear engulf + zones"; }
      else if(z.bullFVG || z.bearFVG) z.note = "FVG active";
      else if(z.bullOB || z.bearOB) z.note = "order block mapped";
      else if(z.bullDisplacement || z.bearDisplacement) z.note = "displacement";
      else z.note = "awaiting institutional zone";

      return z;
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Zones.mqh =====

//===== BEGIN SA_Signal.mqh =====
//+------------------------------------------------------------------+
//| SA_Signal.mqh — kill-chain + setup score + M5 confirmation         |
//+------------------------------------------------------------------+


struct SASetup
  {
   ENUM_SA_SIGNAL signal;
   int            score;
   string         path;      // CONTINUATION / REVERSAL
   string         reason;
   ENUM_SA_BIAS   bias;
  };

class CSniperSignal
  {
private:
   CSniperStructure m_structure;
   CSniperLiquidity m_liquidity;
   CSniperZones     m_zones;

   bool M5ConfirmBuy(const string symbol)
     {
      MqlRates r[];
      if(!SA_CopyOHLC(symbol, PERIOD_M5, 4, r))
         return false;
      // Closed bullish confirmation
      bool bull = r[1].close > r[1].open;
      bool rising = r[1].close > r[2].close;
      bool reject = (r[1].close - r[1].low) > (r[1].high - r[1].close); // close near high / upper half
      return (bull && (rising || reject));
     }

   bool M5ConfirmSell(const string symbol)
     {
      MqlRates r[];
      if(!SA_CopyOHLC(symbol, PERIOD_M5, 4, r))
         return false;
      bool bear = r[1].close < r[1].open;
      bool falling = r[1].close < r[2].close;
      bool reject = (r[1].high - r[1].close) > (r[1].close - r[1].low);
      return (bear && (falling || reject));
     }

public:
   SASetup Evaluate(const string symbol)
     {
      SASetup s;
      s.signal = SA_SIG_NONE;
      s.score = 0;
      s.path = "-";
      s.reason = "scanning";
      s.bias = SA_BIAS_NONE;

      SAStructureState st = m_structure.Evaluate(symbol, PERIOD_H4, PERIOD_H1);
      SALiquidityState liq = m_liquidity.Evaluate(symbol, PERIOD_H1);
      SAZoneState zone = m_zones.Evaluate(symbol, PERIOD_H1);
      s.bias = st.bias;

      int base = 0;
      base += liq.scoreBonus;
      base += zone.scoreBonus;
      if(st.bosBull || st.bosBear) base += 3;
      if(st.chochBull || st.chochBear) base += 3;
      if(st.bias != SA_BIAS_NONE) base += 1;

      // --- Path A: Trend continuation ---
      if(st.bias == SA_BIAS_BULL && (st.bosBull || zone.bullDisplacement || zone.bullFVG || zone.bullOB))
        {
         bool liqOk = true; // no blocking — events/high vol allowed
         bool zoneOk = (zone.bullFVG || zone.bullOB || zone.priceInBullZone || zone.bullDisplacement || st.bosBull);
         if(liqOk && zoneOk && M5ConfirmBuy(symbol))
           {
            s.signal = SA_SIG_BUY;
            s.path = "CONTINUATION";
            s.score = base + 5;
            s.reason = StringFormat("H4 bull | %s | %s | %s | M5 confirm", st.note, liq.note, zone.note);
            return s;
           }
        }

      if(st.bias == SA_BIAS_BEAR && (st.bosBear || zone.bearDisplacement || zone.bearFVG || zone.bearOB))
        {
         bool zoneOk = (zone.bearFVG || zone.bearOB || zone.priceInBearZone || zone.bearDisplacement || st.bosBear);
         if(zoneOk && M5ConfirmSell(symbol))
           {
            s.signal = SA_SIG_SELL;
            s.path = "CONTINUATION";
            s.score = base + 5;
            s.reason = StringFormat("H4 bear | %s | %s | %s | M5 confirm", st.note, liq.note, zone.note);
            return s;
           }
        }

      // --- Path B: Reversal (liquidity sweep + CHoCH) ---
      if(liq.sellSideSwept && (st.chochBull || st.bosBull || zone.bullDisplacement) && M5ConfirmBuy(symbol))
        {
         s.signal = SA_SIG_BUY;
         s.path = "REVERSAL";
         s.score = base + 6;
         s.reason = StringFormat("Sell-side sweep reverse | %s | %s | M5", st.note, zone.note);
         return s;
        }
      if(liq.buySideSwept && (st.chochBear || st.bosBear || zone.bearDisplacement) && M5ConfirmSell(symbol))
        {
         s.signal = SA_SIG_SELL;
         s.path = "REVERSAL";
         s.score = base + 6;
         s.reason = StringFormat("Buy-side sweep reverse | %s | %s | M5", st.note, zone.note);
         return s;
        }

      // Aggressive sniper fallback: strong displacement + M5 confirm aligned to H4
      if(st.bias == SA_BIAS_BULL && zone.bullDisplacement && M5ConfirmBuy(symbol))
        {
         s.signal = SA_SIG_BUY;
         s.path = "CONTINUATION";
         s.score = base + 3;
         s.reason = "H4 bull displacement sniper | M5";
         return s;
        }
      if(st.bias == SA_BIAS_BEAR && zone.bearDisplacement && M5ConfirmSell(symbol))
        {
         s.signal = SA_SIG_SELL;
         s.path = "CONTINUATION";
         s.score = base + 3;
         s.reason = "H4 bear displacement sniper | M5";
         return s;
        }

      s.score = base;
      s.reason = StringFormat("%s | %s | %s", st.note, liq.note, zone.note);
      return s;
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Signal.mqh =====

//===== BEGIN SA_Risk.mqh =====
//+------------------------------------------------------------------+
//| SA_Risk.mqh — sizing, SL/TP/BE, trade caps (no vol/session block)  |
//+------------------------------------------------------------------+


class CSniperRisk
  {
private:
   long   m_magic;
   double m_lot;
   double m_atrMult;
   double m_rr;
   double m_beR;
   int    m_maxTrades;

public:
                     CSniperRisk(void)
                        : m_magic(20260726), m_lot(0.01), m_atrMult(1.5),
                          m_rr(2.0), m_beR(1.0), m_maxTrades(3) {}

   void Configure(const long magic, const double lot, const double atrMult,
                  const double rr, const double beR, const int maxTrades)
     {
      m_magic = magic;
      m_lot = lot;
      m_atrMult = atrMult;
      m_rr = rr;
      m_beR = beR;
      m_maxTrades = maxTrades;
     }

   int CountMagicPositions(const string symbolFilter = "")
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
         if(symbolFilter != "" && PositionGetString(POSITION_SYMBOL) != symbolFilter) continue;
         count++;
        }
      return count;
     }

   bool CanOpen(const string symbol, string &reason)
     {
      // NO session filter, NO spread filter, NO volatility filter — trade 24/7 including events
      if(CountMagicPositions() >= m_maxTrades)
        {
         reason = "max account trades (3)";
         return false;
        }
      if(CountMagicPositions(symbol) >= m_maxTrades)
        {
         reason = "max symbol trades";
         return false;
        }
      reason = "ok";
      return true;
     }

   double Lots(const string symbol) const
     {
      return SA_NormLots(symbol, m_lot);
     }

   bool BuildSLTP(const string symbol, const ENUM_SA_SIGNAL side,
                  double &entry, double &sl, double &tp, string &reason)
     {
      double atr = SA_ATR(symbol, PERIOD_H1, 14, 1);
      // Even if ATR tiny/huge (news), still trade — floor to small pip distance only for broker stops
      double pip = SA_PipSize(symbol);
      double stopDist = atr * m_atrMult;
      if(stopDist < pip * 3.0)
         stopDist = pip * 3.0;

      long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = stopsLevel * SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(stopDist < minDist)
         stopDist = minDist;

      if(side == SA_SIG_BUY)
        {
         entry = SymbolInfoDouble(symbol, SYMBOL_ASK);
         sl = SA_NormPrice(symbol, entry - stopDist);
         tp = SA_NormPrice(symbol, entry + stopDist * m_rr);
        }
      else if(side == SA_SIG_SELL)
        {
         entry = SymbolInfoDouble(symbol, SYMBOL_BID);
         sl = SA_NormPrice(symbol, entry + stopDist);
         tp = SA_NormPrice(symbol, entry - stopDist * m_rr);
        }
      else
        {
         reason = "no side";
         return false;
        }
      reason = "ok";
      return true;
     }

   void ManageBreakEven()
     {
      CTrade trade;
      trade.SetExpertMagicNumber((ulong)m_magic);

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         string symbol = PositionGetString(POSITION_SYMBOL);
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         long type = PositionGetInteger(POSITION_TYPE);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

         double risk = 0.0;
         if(type == POSITION_TYPE_BUY)
            risk = open - sl;
         else
            risk = sl - open;
         if(risk <= 0.0)
            continue;

         // Already BE?
         if(type == POSITION_TYPE_BUY && sl >= open - point)
            continue;
         if(type == POSITION_TYPE_SELL && sl > 0.0 && sl <= open + point)
            continue;

         bool hit = false;
         if(type == POSITION_TYPE_BUY && bid >= open + risk * m_beR)
            hit = true;
         if(type == POSITION_TYPE_SELL && ask <= open - risk * m_beR)
            hit = true;

         if(hit)
           {
            double newSL = SA_NormPrice(symbol, open);
            trade.PositionModify(ticket, newSL, tp);
           }
        }
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Risk.mqh =====

//===== BEGIN SA_Trade.mqh =====
//+------------------------------------------------------------------+
//| SA_Trade.mqh — instant market execution                            |
//+------------------------------------------------------------------+


class CSniperTrade
  {
private:
   CTrade m_trade;
   long   m_magic;
   int    m_slippage;

public:
                     CSniperTrade(void): m_magic(20260726), m_slippage(50) {}

   void Configure(const long magic, const int slippage)
     {
      m_magic = magic;
      m_slippage = slippage;
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetAsyncMode(false);
     }

   CTrade *Trade() { return GetPointer(m_trade); }

   bool InstantBuy(const string symbol, const double lots, const double sl, const double tp,
                   const string comment, string &err)
     {
      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFillingBySymbol(symbol);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      // Instant market execution — no pending, no delay
      if(!m_trade.Buy(lots, symbol, ask, sl, tp, comment))
        {
         err = StringFormat("BUY fail %d %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
         return false;
        }
      err = "ok";
      return true;
     }

   bool InstantSell(const string symbol, const double lots, const double sl, const double tp,
                    const string comment, string &err)
     {
      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFillingBySymbol(symbol);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(!m_trade.Sell(lots, symbol, bid, sl, tp, comment))
        {
         err = StringFormat("SELL fail %d %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
         return false;
        }
      err = "ok";
      return true;
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Trade.mqh =====

//===== BEGIN SA_Watermark.mqh =====
//+------------------------------------------------------------------+
//| SA_Watermark.mqh — chart background watermark (candles on top)     |
//+------------------------------------------------------------------+

#define SA_WM_NAME "SniperAI_WM_Bitmap"
#define SA_WM_TITLE "SniperAI_WM_Title"

class CSniperWatermark
  {
private:
   bool m_enabled;

public:
                     CSniperWatermark(void): m_enabled(true) {}

   bool Create(const bool enabled = true)
     {
      m_enabled = enabled;
      Delete();
      if(!m_enabled)
         return true;

      // Bitmap behind candles — ALGO-NOVA style left watermark
      if(!ObjectCreate(0, SA_WM_NAME, OBJ_BITMAP_LABEL, 0, 0, 0))
        {
         Print("Sniper AI: watermark object create failed");
         return false;
        }

      ObjectSetString(0, SA_WM_NAME, OBJPROP_BMPFILE, "::SniperAI_Watermark.bmp");
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_XDISTANCE, 8);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_YDISTANCE, 8);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_XSIZE, 420);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_YSIZE, 630);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_BACK, true);      // CRITICAL: behind candles
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_ZORDER, 0);

      // Extra bold label (in case BMP font is soft on some builds)
      if(ObjectCreate(0, SA_WM_TITLE, OBJ_LABEL, 0, 0, 0))
        {
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_XDISTANCE, 90);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_YDISTANCE, 28);
         ObjectSetString(0, SA_WM_TITLE, OBJPROP_TEXT, "SNIPER AI");
         ObjectSetString(0, SA_WM_TITLE, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_FONTSIZE, 22);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_BACK, true);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_HIDDEN, true);
        }

      ChartRedraw(0);
      return true;
     }

   void Delete()
     {
      ObjectDelete(0, SA_WM_NAME);
      ObjectDelete(0, SA_WM_TITLE);
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Watermark.mqh =====

//===== BEGIN SA_Dashboard.mqh =====
//+------------------------------------------------------------------+
//| SA_Dashboard.mqh — premium right-corner HUD                        |
//+------------------------------------------------------------------+


#define SA_UI_PREFIX "SniperAI_UI_"

class CSniperDashboard
  {
private:
   int m_x;
   int m_y;
   int m_w;
   int m_h;

   void Rect(const string id, const int x, const int y, const int w, const int h,
             const color bg, const color border)
     {
      string name = SA_UI_PREFIX + id;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
     }

   void Label(const string id, const int x, const int y, const string text,
              const color clr, const int size = 9, const string font = "Consolas")
     {
      string name = SA_UI_PREFIX + id;
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
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 101);
     }

public:
                     CSniperDashboard(void): m_x(16), m_y(18), m_w(280), m_h(320) {}

   void Create()
     {
      // Panel shell
      Rect("bg", m_x, m_y, m_w, m_h, C'18,18,22', C'180,20,40');
      Rect("hdr", m_x, m_y, m_w, 42, C'140,10,30', C'220,40,60');
      Label("title", m_x + 14, m_y + 10, "SNIPER AI", clrWhite, 14, "Arial Bold");
      Label("sub", m_x + 14, m_y + 46, "24/7  |  INSTANT EXEC", C'220,180,180', 8, "Arial");
     }

   void Update(const string symbol,
               const SASetup &setup,
               const int openTrades,
               const double lot,
               const string lastAction,
               const double balance,
               const double equity)
     {
      Create();

      color sigClr = clrSilver;
      if(setup.signal == SA_SIG_BUY) sigClr = C'40,220,120';
      if(setup.signal == SA_SIG_SELL) sigClr = C'255,70,70';

      // XDISTANCE from right edge (panel padding)
      int x = m_x + 14;
      int y = m_y + 70;

      Label("sym", x, y, "SYMBOL   " + symbol, clrWhite, 10); y += 20;
      Label("bias", x, y, "H4 BIAS  " + SA_BiasText(setup.bias), clrAqua, 10); y += 20;
      Label("sig", x, y, "SIGNAL   " + SA_SigText(setup.signal), sigClr, 11, "Arial Bold"); y += 20;
      Label("path", x, y, "PATH     " + setup.path, clrGold, 10); y += 20;
      Label("score", x, y, StringFormat("SCORE    %d", setup.score), clrOrange, 10); y += 20;
      Label("open", x, y, StringFormat("OPEN     %d / 3", openTrades), clrWhite, 10); y += 20;
      Label("lot", x, y, StringFormat("LOT      %.2f", lot), clrWhite, 10); y += 20;
      Label("bal", x, y, StringFormat("BALANCE  %.2f", balance), C'180,220,255', 9); y += 18;
      Label("eq", x, y, StringFormat("EQUITY   %.2f", equity), C'180,220,255', 9); y += 22;

      Label("mode", x, y, "MODE     EVENTS ON | NO SESSION FILTER", C'160,255,160', 8); y += 18;
      Label("exec", x, y, "EXEC     MARKET INSTANT", C'255,120,120', 8); y += 20;

      string reason = setup.reason;
      if(StringLen(reason) > 42)
         reason = StringSubstr(reason, 0, 42) + "...";
      Label("why", x, y, "STATUS", clrSilver, 8); y += 14;
      Label("why2", x, y, reason, clrSilver, 8); y += 20;
      Label("last", x, y, "LAST     " + lastAction, clrGray, 8);

      ChartRedraw(0);
     }

   void Delete()
     {
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; --i)
        {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, SA_UI_PREFIX) == 0)
            ObjectDelete(0, name);
        }
     }
  };

//+------------------------------------------------------------------+
//===== END SA_Dashboard.mqh =====

//----------------------------- inputs --------------------------------
input group "=== SNIPER AI CORE ==="
input double   InpLot              = 0.01;      // Lot size (changeable)
input int      InpMaxTrades        = 3;         // Max open trades (account)
input long     InpMagic            = 20260726;  // Magic number
input int      InpSlippagePoints   = 50;        // Slippage (points) — wide for news

input group "=== RISK ==="
input double   InpAtrMultSL        = 1.5;       // SL = ATR(H1) * this
input double   InpRewardRatio      = 2.0;       // Take profit R multiple (2R)
input double   InpBreakEvenR       = 1.0;       // Move BE at +R

input group "=== ENGINE ==="
input bool     InpTradeOnChartOnly = true;      // Trade attached chart symbol
input bool     InpAllowContinuation= true;      // Path A continuation
input bool     InpAllowReversal    = true;      // Path B reversal
input int      InpMinScore         = 3;         // Minimum setup score to fire
input bool     InpOnePerBar        = true;      // One new entry per M5 bar

input group "=== UI ==="
input bool     InpShowWatermark    = false;     // Show SNIPER AI watermark (off for now)
input bool     InpShowDashboard    = true;      // Show right-corner dashboard
input bool     InpLogTrades        = true;      // Journal to Experts log

//----------------------------- state ---------------------------------
CSniperSignal    g_signal;
CSniperRisk      g_risk;
CSniperTrade     g_trade;
CSniperWatermark g_watermark;
CSniperDashboard g_dash;

datetime g_lastM5Bar   = 0;
datetime g_lastEntryBar= 0;
string   g_lastAction  = "booting";
SASetup  g_lastSetup;

//----------------------------- helpers -------------------------------
bool SA_IsNewM5Bar(const string symbol)
  {
   datetime t[];
   if(CopyTime(symbol, PERIOD_M5, 0, 1, t) != 1)
      return false;
   // For chart symbol we track global bar time; multi-symbol fires on chart M5
   if(symbol == _Symbol)
     {
      if(t[0] != g_lastM5Bar)
        {
         g_lastM5Bar = t[0];
         return true;
        }
      return false;
     }
   return true;
  }

bool SA_IsForexSymbol(const string symbol)
  {
   string path = SymbolInfoString(symbol, SYMBOL_PATH);
   StringToLower(path);
   if(StringFind(path, "forex") >= 0)
      return true;
   // Fallback: 6-letter FX names
   if(StringLen(symbol) >= 6)
     {
      string base = StringSubstr(symbol, 0, 6);
      // crude but effective for EURUSD / EURUSDm
      return (StringFind(base, "USD") >= 0 || StringFind(base, "EUR") >= 0 ||
              StringFind(base, "GBP") >= 0 || StringFind(base, "JPY") >= 0 ||
              StringFind(base, "AUD") >= 0 || StringFind(base, "NZD") >= 0 ||
              StringFind(base, "CAD") >= 0 || StringFind(base, "CHF") >= 0);
     }
   return false;
  }

void SA_RefreshUI()
  {
   if(InpShowDashboard)
      g_dash.Update(_Symbol,
                    g_lastSetup,
                    g_risk.CountMagicPositions(),
                    InpLot,
                    g_lastAction,
                    AccountInfoDouble(ACCOUNT_BALANCE),
                    AccountInfoDouble(ACCOUNT_EQUITY));
  }

bool SA_Fire(const string symbol, const SASetup &setup)
  {
   if(setup.signal == SA_SIG_NONE)
      return false;
   if(setup.score < InpMinScore)
     {
      g_lastAction = "score too low";
      return false;
     }
   if(setup.path == "CONTINUATION" && !InpAllowContinuation)
      return false;
   if(setup.path == "REVERSAL" && !InpAllowReversal)
      return false;

   string reason;
   if(!g_risk.CanOpen(symbol, reason))
     {
      g_lastAction = reason;
      return false;
     }

   double entry = 0, sl = 0, tp = 0;
   if(!g_risk.BuildSLTP(symbol, setup.signal, entry, sl, tp, reason))
     {
      g_lastAction = reason;
      return false;
     }

   double lots = g_risk.Lots(symbol);
   string comment = StringFormat("SNIPER|%s|%d", setup.path, setup.score);
   string err;
   bool ok = false;

   // INSTANT MARKET EXECUTION — no pending orders, no “wait out volatility”
   if(setup.signal == SA_SIG_BUY)
      ok = g_trade.InstantBuy(symbol, lots, sl, tp, comment, err);
   else
      ok = g_trade.InstantSell(symbol, lots, sl, tp, comment, err);

   if(ok)
     {
      g_lastEntryBar = g_lastM5Bar;
      g_lastAction = StringFormat("%s %s %s", symbol, SA_SigText(setup.signal), setup.path);
      if(InpLogTrades)
         PrintFormat("SNIPER AI KILL => %s %s | %s | score=%d | SL=%.5f TP=%.5f | %s",
                     symbol, SA_SigText(setup.signal), setup.path, setup.score, sl, tp, setup.reason);
      return true;
     }

   g_lastAction = err;
   Print("SNIPER AI order error: ", err);
   return false;
  }

void SA_HuntChartSymbol(const bool newBar)
  {
   g_lastSetup = g_signal.Evaluate(_Symbol);
   if(newBar && !(InpOnePerBar && g_lastEntryBar == g_lastM5Bar))
      SA_Fire(_Symbol, g_lastSetup);
  }

void SA_HuntAllForex(const bool newBar)
  {
   if(!newBar)
     {
      g_lastSetup = g_signal.Evaluate(_Symbol);
      return;
     }

   // Collect candidates, score-rank, fill remaining slots (A+B allocation)
   string syms[];
   int scores[];
   ENUM_SA_SIGNAL sigs[];
   SASetup setups[];
   ArrayResize(syms, 0);

   int total = SymbolsTotal(true);
   for(int i = 0; i < total; i++)
     {
      string sym = SymbolName(i, true);
      if(!SA_IsForexSymbol(sym))
         continue;
      if(!SymbolSelect(sym, true))
         continue;

      SASetup s = g_signal.Evaluate(sym);
      if(s.signal == SA_SIG_NONE || s.score < InpMinScore)
         continue;

      int n = ArraySize(syms);
      ArrayResize(syms, n + 1);
      ArrayResize(scores, n + 1);
      ArrayResize(sigs, n + 1);
      ArrayResize(setups, n + 1);
      syms[n] = sym;
      scores[n] = s.score;
      sigs[n] = s.signal;
      setups[n] = s;
     }

   // Also always refresh dashboard from chart symbol
   g_lastSetup = g_signal.Evaluate(_Symbol);

   // Sort by score descending (simple swap)
   int n = ArraySize(syms);
   for(int a = 0; a < n; a++)
      for(int b = a + 1; b < n; b++)
         if(scores[b] > scores[a])
           {
            int ts = scores[a]; scores[a] = scores[b]; scores[b] = ts;
            string tsy = syms[a]; syms[a] = syms[b]; syms[b] = tsy;
            SASetup tu = setups[a]; setups[a] = setups[b]; setups[b] = tu;
           }

   for(int k = 0; k < n; k++)
     {
      if(g_risk.CountMagicPositions() >= InpMaxTrades)
         break;
      SA_Fire(syms[k], setups[k]);
     }
  }

//----------------------------- lifecycle -----------------------------
int OnInit()
  {
   if(InpLot <= 0)
     {
      Print("SNIPER AI: invalid lot");
      return INIT_PARAMETERS_INCORRECT;
     }

   // Ensure chart symbol is ready for fast reads
   SymbolSelect(_Symbol, true);

   g_risk.Configure(InpMagic, InpLot, InpAtrMultSL, InpRewardRatio, InpBreakEvenR, InpMaxTrades);
   g_trade.Configure(InpMagic, InpSlippagePoints);

   // Includes resolve from MQL5/Include/SniperAI — copy folder on install
   // Watermark resource is compiled into the EX5 from Images\\ next to this EA

   g_watermark.Create(InpShowWatermark);
   g_lastSetup.signal = SA_SIG_NONE;
   g_lastSetup.score = 0;
   g_lastSetup.path = "-";
   g_lastSetup.reason = "armed — scanning " + _Symbol;
   g_lastSetup.bias = SA_BIAS_NONE;
   g_lastAction = "online 24/7";

   SA_RefreshUI();

   PrintFormat("SNIPER AI ONLINE | %s | lot=%.2f | max=%d | 24/7 events ON | instant market",
               _Symbol, InpLot, InpMaxTrades);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_watermark.Delete();
   g_dash.Delete();
   Comment("");
   Print("SNIPER AI stopped. reason=", reason);
  }

void OnTick()
  {
   // Always manage BE every tick — sniper protection
   g_risk.ManageBreakEven();

   // Fast structure read on each new M5 bar (entry timeframe)
   bool newBar = SA_IsNewM5Bar(_Symbol);

   // Refresh setup frequently for dashboard; fire only on new bar
   static int tickPulse = 0;
   tickPulse++;
   bool scanNow = newBar || (tickPulse % 25 == 0);

   if(scanNow)
     {
      if(InpTradeOnChartOnly)
         SA_HuntChartSymbol(newBar);
      else
         SA_HuntAllForex(newBar);
      SA_RefreshUI();
     }
  }

void OnTimer()
  {
   // reserved for multi-symbol expansion
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE && InpShowWatermark)
      g_watermark.Create(true);
  }
//+------------------------------------------------------------------+
