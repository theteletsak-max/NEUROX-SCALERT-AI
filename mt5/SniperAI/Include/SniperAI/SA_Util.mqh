//+------------------------------------------------------------------+
//| SA_Util.mqh — shared helpers                                       |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_UTIL_MQH
#define SNIPER_AI_SA_UTIL_MQH

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

#endif
//+------------------------------------------------------------------+
