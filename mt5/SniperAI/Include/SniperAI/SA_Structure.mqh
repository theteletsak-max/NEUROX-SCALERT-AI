//+------------------------------------------------------------------+
//| SA_Structure.mqh — swings, BOS, CHoCH, HTF bias                    |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_STRUCTURE_MQH
#define SNIPER_AI_SA_STRUCTURE_MQH

#include "SA_Util.mqh"

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

#endif
//+------------------------------------------------------------------+
