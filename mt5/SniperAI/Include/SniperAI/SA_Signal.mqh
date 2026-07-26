//+------------------------------------------------------------------+
//| SA_Signal.mqh — kill-chain + setup score + M5 confirmation         |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_SIGNAL_MQH
#define SNIPER_AI_SA_SIGNAL_MQH

#include "SA_Util.mqh"
#include "SA_Structure.mqh"
#include "SA_Liquidity.mqh"
#include "SA_Zones.mqh"

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

#endif
//+------------------------------------------------------------------+
