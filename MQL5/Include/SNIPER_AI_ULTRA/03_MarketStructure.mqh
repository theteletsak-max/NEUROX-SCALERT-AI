#ifndef SNIPER_AI_ULTRA_03_MARKETSTRUCTURE_MQH
#define SNIPER_AI_ULTRA_03_MARKETSTRUCTURE_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 03_MARKET_STRUCTURE — HH/HL/LH/LL · Swings · Internal/External
//+------------------------------------------------------------------+
void UltraEngStructure(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   int iH1, iH2, iL1, iL2;
   if(UltraFindSwings(s, tf, UltraStructLookback, UltraSwingStrength, iH1, iH2, iL1, iL2))
   {
      double h1 = iHigh(s, tf, iH1), h2 = iHigh(s, tf, iH2);
      double l1 = iLow(s, tf, iL1), l2 = iLow(s, tf, iL2);
      u.st.hh = (h1 > h2); u.st.hl = (l1 > l2); u.st.lh = (h1 < h2); u.st.ll = (l1 < l2);
      u.st.swingHigh = h1; u.st.swingLow = l1;
      u.st.swingHighOK = true; u.st.swingLowOK = true;
      u.st.externalBull = (u.st.hh && u.st.hl);
      u.st.externalBear = (u.st.lh && u.st.ll);
   }
   else
   {
      u.st.swingHigh = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, UltraStructLookback, 1));
      u.st.swingLow  = iLow(s, tf, iLowest(s, tf, MODE_LOW, UltraStructLookback, 1));
   }
   // Internal structure (shorter lookback)
   int jH1, jH2, jL1, jL2;
   if(UltraFindSwings(s, tf, MathMax(UltraStructLookback / 2, 16), UltraSwingStrength, jH1, jH2, jL1, jL2))
   {
      bool ihh = iHigh(s, tf, jH1) > iHigh(s, tf, jH2);
      bool ihl = iLow(s, tf, jL1) > iLow(s, tf, jL2);
      bool ilh = iHigh(s, tf, jH1) < iHigh(s, tf, jH2);
      bool ill = iLow(s, tf, jL1) < iLow(s, tf, jL2);
      u.st.internalBull = (ihh && ihl);
      u.st.internalBear = (ilh && ill);
   }
   u.st.continuation = (u.st.externalBull && u.st.internalBull) || (u.st.externalBear && u.st.internalBear);
   u.st.reversal = (u.st.externalBull && u.st.internalBear) || (u.st.externalBear && u.st.internalBull);
   u.st.strength = 40;
   if(u.st.externalBull || u.st.externalBear) u.st.strength += 20;
   if(u.st.internalBull || u.st.internalBear) u.st.strength += 15;
   if(u.st.continuation) u.st.strength += 15;
   if(u.st.reversal) u.st.strength += 10;
   if(u.st.strength > 100) u.st.strength = 100;
   u.st.quality = u.st.strength;
   if(u.st.swingHigh <= u.st.swingLow) u.st.quality = MathMax(u.st.quality - 20, 0);
}

#endif // SNIPER_AI_ULTRA_03_MARKETSTRUCTURE_MQH
