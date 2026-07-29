#ifndef HITMAN_ULTRA_28_UTILITIES_MQH
#define HITMAN_ULTRA_28_UTILITIES_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 28_UTILITIES — Helpers · Math · Time · Price
//+------------------------------------------------------------------+
// Timeframe / ATR / SMA / Swing helpers
ENUM_TIMEFRAMES UltraETF()
{
   return (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
}
double UltraATR(const string s, const int period=14)
{
   int p = MathMax(period, 5);
   ENUM_TIMEFRAMES tf = UltraETF();
   if(Bars(s, tf) < p + 5) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= p; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), pc = iClose(s, tf, i + 1);
      sum += MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
   }
   return sum / p;
}
double UltraSMA(const string s, const ENUM_TIMEFRAMES tf, const int period, const int shift=1)
{
   if(Bars(s, tf) < period + shift + 2) return 0.0;
   double a = 0.0;
   for(int i = shift; i < shift + period; i++) a += iClose(s, tf, i);
   return a / period;
}
bool UltraSwingHighAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double h = iHigh(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iHigh(s, tf, bar - i) >= h || iHigh(s, tf, bar + i) >= h) return false;
   return true;
}
bool UltraSwingLowAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double l = iLow(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iLow(s, tf, bar - i) <= l || iLow(s, tf, bar + i) <= l) return false;
   return true;
}
bool UltraFindSwings(const string s, const ENUM_TIMEFRAMES tf, const int lb, const int strength,
                     int &iH1, int &iH2, int &iL1, int &iL2)
{
   iH1 = iH2 = iL1 = iL2 = 0;
   int sw = MathMax(strength, 1), look = MathMax(lb, 20);
   for(int i = sw + 1; i <= look; i++)
   {
      if(iH1 == 0 && UltraSwingHighAt(s, tf, i, sw)) iH1 = i;
      else if(iH1 > 0 && iH2 == 0 && UltraSwingHighAt(s, tf, i, sw)) iH2 = i;
      if(iL1 == 0 && UltraSwingLowAt(s, tf, i, sw)) iL1 = i;
      else if(iL1 > 0 && iL2 == 0 && UltraSwingLowAt(s, tf, i, sw)) iL2 = i;
      if(iH1 && iH2 && iL1 && iL2) break;
   }
   return (iH1 && iH2 && iL1 && iL2);
}

// MQL5-safe bool→text (never concatenate bare bool into strings / Print)
string UltraYN(const bool v)
{
   if(v) return "Y";
   return "N";
}

#endif // HITMAN_ULTRA_28_UTILITIES_MQH
