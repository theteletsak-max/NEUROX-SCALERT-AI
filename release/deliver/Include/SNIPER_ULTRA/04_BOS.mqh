#ifndef SNIPER_ULTRA_04_BOS_MQH
#define SNIPER_ULTRA_04_BOS_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 04_BOS — Proprietary Break Of Structure
//+------------------------------------------------------------------+
void UltraEngBOS(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double c1 = iClose(s, tf, 1);
   u.bos.buy = (u.st.swingHigh > 0 && c1 > u.st.swingHigh);
   u.bos.sell = (u.st.swingLow > 0 && c1 < u.st.swingLow);
   for(int i = 1; i <= UltraBOS_ConfirmBars; i++)
   {
      double c = iClose(s, tf, i);
      if(c > u.st.swingHigh) u.bos.buy = true;
      if(c < u.st.swingLow)  u.bos.sell = true;
   }
   u.bos.confirmation = 0;
   if(u.bos.buy || u.bos.sell)
   {
      double body = MathAbs(iClose(s, tf, 1) - iOpen(s, tf, 1));
      double rng = iHigh(s, tf, 1) - iLow(s, tf, 1);
      u.bos.confirmation = (rng > 0 && body / rng >= UltraDispBodyMin) ? 80 : 55;
   }
   u.bos.strength = u.bos.confirmation;
   if((u.bos.buy && u.st.externalBull) || (u.bos.sell && u.st.externalBear)) u.bos.strength += 15;
   if(u.bos.strength > 100) u.bos.strength = 100;
   u.bos.quality = u.bos.strength;
   u.bos.reliability = (u.bos.confirmation >= 70 && u.st.quality >= 50) ? 75 : 45;
   u.bos.score = (u.bos.strength + u.bos.quality + u.bos.reliability) / 3;
}

#endif // SNIPER_ULTRA_04_BOS_MQH
