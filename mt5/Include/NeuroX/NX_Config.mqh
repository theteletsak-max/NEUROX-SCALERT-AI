//+------------------------------------------------------------------+
//| NX_Config.mqh                                                     |
//| NEUROX Scalper AI — shared enums and helpers                      |
//+------------------------------------------------------------------+
#property copyright "NEUROX"
#property strict

#ifndef NEUROX_NX_CONFIG_MQH
#define NEUROX_NX_CONFIG_MQH

enum ENUM_NX_SIGNAL
  {
   NX_SIGNAL_NONE = 0,
   NX_SIGNAL_BUY  = 1,
   NX_SIGNAL_SELL = -1
  };

// Convert points <-> price for 3/5-digit brokers
double NX_PipSize()
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return _Point * 10.0;
   return _Point;
  }

double NX_PointsToPrice(const double points)
  {
   return points * _Point;
  }

double NX_NormalizePrice(const double price)
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double NX_NormalizeLots(const double lots)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      stepLot = 0.01;

   double normalized = MathFloor(lots / stepLot + 1e-12) * stepLot;
   if(normalized < minLot)
      normalized = minLot;
   if(normalized > maxLot)
      normalized = maxLot;
   int lotDigits = 2;
   if(stepLot < 0.01)
      lotDigits = 3;
   return NormalizeDouble(normalized, lotDigits);
  }

#endif
//+------------------------------------------------------------------+
