//+------------------------------------------------------------------+
//| SA_Liquidity.mqh — equal highs/lows, sweeps, stop hunts            |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_LIQUIDITY_MQH
#define SNIPER_AI_SA_LIQUIDITY_MQH

#include "SA_Util.mqh"

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

#endif
//+------------------------------------------------------------------+
