#ifndef SNIPER_ULTRA_04_BOS_MQH
#define SNIPER_ULTRA_04_BOS_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 04_BOS — Proprietary Break Of Structure
//+------------------------------------------------------------------+
void UltraEngBOS(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   // Prefer PRIOR swing (iH2/iL2) as break level — most-recent tip rarely stays "broken"
   int iH1, iH2, iL1, iL2;
   double breakHi = u.st.swingHigh;
   double breakLo = u.st.swingLow;
   if(UltraFindSwings(s, tf, UltraStructLookback, UltraSwingStrength, iH1, iH2, iL1, iL2))
   {
      if(iH2 > 0) breakHi = iHigh(s, tf, iH2);
      if(iL2 > 0) breakLo = iLow(s, tf, iL2);
   }

   u.bos.buy = false;
   u.bos.sell = false;
   int lb = MathMax(UltraBOS_ConfirmBars, 5);
   for(int i = 1; i <= lb; i++)
   {
      double c = iClose(s, tf, i);
      double h = iHigh(s, tf, i);
      double l = iLow(s, tf, i);
      if(breakHi > 0 && (c > breakHi || h > breakHi)) u.bos.buy = true;
      if(breakLo > 0 && (c < breakLo || l < breakLo)) u.bos.sell = true;
   }

   // Soft structure BOS: HH/HL continuation counts as bullish structure break bias
   if(!u.bos.buy && u.st.hh && u.st.hl && (u.st.externalBull || u.st.internalBull))
      u.bos.buy = true;
   if(!u.bos.sell && u.st.lh && u.st.ll && (u.st.externalBear || u.st.internalBear))
      u.bos.sell = true;

   u.bos.confirmation = 0;
   if(u.bos.buy || u.bos.sell)
   {
      double body = MathAbs(iClose(s, tf, 1) - iOpen(s, tf, 1));
      double rng = iHigh(s, tf, 1) - iLow(s, tf, 1);
      u.bos.confirmation = (rng > 0 && body / rng >= UltraDispBodyMin * 0.85) ? 80 : 55;
   }
   u.bos.strength = u.bos.confirmation;
   if((u.bos.buy && u.st.externalBull) || (u.bos.sell && u.st.externalBear)) u.bos.strength += 15;
   if(u.bos.strength > 100) u.bos.strength = 100;
   u.bos.quality = u.bos.strength;
   u.bos.reliability = (u.bos.confirmation >= 70 && u.st.quality >= 50) ? 75 : 45;
   u.bos.score = (u.bos.strength + u.bos.quality + u.bos.reliability) / 3;
}

#endif // SNIPER_ULTRA_04_BOS_MQH
