#ifndef SNIPER_AI_ULTRA_07_FIBONACCI_MQH
#define SNIPER_AI_ULTRA_07_FIBONACCI_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 07_FIBONACCI — Proprietary Fib Intelligence (UFIE)
//+------------------------------------------------------------------+
void UltraEngFib(const string s, UltraSnap &u)
{
   // Proprietary swing selection = structure swings; impulse = external structure move
   u.fib.f100 = u.st.swingHigh; u.fib.f0 = u.st.swingLow;
   double rng = u.fib.f100 - u.fib.f0;
   if(rng <= 0) return;
   u.fib.impulseOK = (u.vol.atr > 0 && rng >= u.vol.atr * 1.2);
   u.fib.f382 = u.fib.f0 + rng * 0.382;
   u.fib.f500 = u.fib.f0 + rng * 0.500;
   u.fib.f618 = u.fib.f0 + rng * 0.618;
   u.fib.f786 = u.fib.f0 + rng * 0.786;
   u.fib.ext127 = u.fib.f100 + rng * (UltraFibExt127 - 1.0);
   u.fib.ext161 = u.fib.f100 + rng * (UltraFibExt161 - 1.0);
   // For bear impulse, extensions below f0
   if(u.st.externalBear)
   {
      u.fib.ext127 = u.fib.f0 - rng * (UltraFibExt127 - 1.0);
      u.fib.ext161 = u.fib.f0 - rng * (UltraFibExt161 - 1.0);
   }
   double px = SymbolInfoDouble(s, SYMBOL_BID);
   u.fib.retracePos = (px - u.fib.f0) / rng;
   u.fib.atBuyZone  = (u.fib.retracePos >= UltraFibBuyLow && u.fib.retracePos <= UltraFibBuyHigh);
   u.fib.atSellZone = (u.fib.retracePos >= UltraFibSellLow && u.fib.retracePos <= UltraFibSellHigh);
   // Zone ranking: 0.618 best, then 0.5, 0.786, 0.382
   u.fib.zoneRank = 0;
   if(MathAbs(u.fib.retracePos - 0.618) < 0.05) u.fib.zoneRank = 100;
   else if(MathAbs(u.fib.retracePos - 0.500) < 0.05) u.fib.zoneRank = 85;
   else if(MathAbs(u.fib.retracePos - 0.786) < 0.05) u.fib.zoneRank = 75;
   else if(MathAbs(u.fib.retracePos - 0.382) < 0.05) u.fib.zoneRank = 65;
   else if(u.fib.atBuyZone || u.fib.atSellZone) u.fib.zoneRank = 55;
   u.fib.confluence = u.fib.zoneRank;
   if(u.fib.impulseOK) u.fib.confluence += 10;
   if((u.fib.atBuyZone && u.liq.sweepBuy) || (u.fib.atSellZone && u.liq.sweepSell)) u.fib.confluence += 15;
   if(u.fib.confluence > 100) u.fib.confluence = 100;
   u.fib.quality = u.fib.confluence;
   u.fib.confidence = u.fib.quality;
}

#endif // SNIPER_AI_ULTRA_07_FIBONACCI_MQH
