//+------------------------------------------------------------------+
//| SA_Zones.mqh — displacement, FVG, order blocks                     |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_ZONES_MQH
#define SNIPER_AI_SA_ZONES_MQH

#include "SA_Util.mqh"

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

#endif
//+------------------------------------------------------------------+
