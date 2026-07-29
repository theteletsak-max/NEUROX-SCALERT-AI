#ifndef SNIPER_ULTRA_04_BOS_MQH
#define SNIPER_ULTRA_04_BOS_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 04_BOS                                          |
//| Proprietary · Strong/Weak · Confirmed/Failed · Quality/Strength   |
//+------------------------------------------------------------------+
void UltraEngBOS(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
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
   u.bos.strong = u.bos.weak = false;
   u.bos.confirmed = u.bos.failed = false;

   int lb = MathMax(UltraBOS_ConfirmBars, 5);
   bool brokeHi = false, brokeLo = false;
   bool closedBeyondHi = false, closedBeyondLo = false;
   for(int i = 1; i <= lb; i++)
   {
      double c = iClose(s, tf, i);
      double h = iHigh(s, tf, i);
      double l = iLow(s, tf, i);
      if(breakHi > 0 && h > breakHi) brokeHi = true;
      if(breakLo > 0 && l < breakLo) brokeLo = true;
      if(breakHi > 0 && c > breakHi) { u.bos.buy = true; closedBeyondHi = true; }
      if(breakLo > 0 && c < breakLo) { u.bos.sell = true; closedBeyondLo = true; }
   }

   // Soft structure BOS bias
   if(!u.bos.buy && u.st.hh && u.st.hl && (u.st.externalBull || u.st.internalBull))
      u.bos.buy = true;
   if(!u.bos.sell && u.st.lh && u.st.ll && (u.st.externalBear || u.st.internalBear))
      u.bos.sell = true;

   // Failed BOS: wicked beyond level but closed back inside
   if(brokeHi && !closedBeyondHi && breakHi > 0)
   {
      double c1 = iClose(s, tf, 1);
      if(c1 < breakHi) u.bos.failed = true;
   }
   if(brokeLo && !closedBeyondLo && breakLo > 0)
   {
      double c1 = iClose(s, tf, 1);
      if(c1 > breakLo) u.bos.failed = true;
   }

   u.bos.confirmation = 0;
   if(u.bos.buy || u.bos.sell)
   {
      double body = MathAbs(iClose(s, tf, 1) - iOpen(s, tf, 1));
      double rng = iHigh(s, tf, 1) - iLow(s, tf, 1);
      u.bos.confirmation = (rng > 0 && body / rng >= UltraDispBodyMin * 0.85) ? 80 : 55;
      u.bos.confirmed = (u.bos.confirmation >= 70 && !u.bos.failed);
   }

   u.bos.strength = u.bos.confirmation;
   if((u.bos.buy && u.st.externalBull) || (u.bos.sell && u.st.externalBear)) u.bos.strength += 15;
   if(u.vol.expansion) u.bos.strength += 8;
   if(u.bos.failed) u.bos.strength = MathMax(u.bos.strength - 25, 0);
   if(u.bos.strength > 100) u.bos.strength = 100;

   u.bos.strong = (u.bos.buy || u.bos.sell) && u.bos.strength >= 70 && u.bos.confirmed;
   u.bos.weak   = (u.bos.buy || u.bos.sell) && !u.bos.strong && !u.bos.failed;

   u.bos.quality = u.bos.strength;
   u.bos.reliability = (u.bos.confirmed && u.st.quality >= 50) ? 75 : (u.bos.failed ? 20 : 45);
   u.bos.score = (u.bos.strength + u.bos.quality + u.bos.reliability) / 3;
}

#endif // SNIPER_ULTRA_04_BOS_MQH
