#ifndef SNIPER_AI_ULTRA_05_CHOCH_MQH
#define SNIPER_AI_ULTRA_05_CHOCH_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 05_CHOCH — Proprietary Change Of Character
//+------------------------------------------------------------------+
void UltraEngCHoCH(const string s, UltraSnap &u)
{
   u.choch.buy  = u.bos.buy  && (u.st.ll || u.st.externalBear || u.st.internalBear);
   u.choch.sell = u.bos.sell && (u.st.hh || u.st.externalBull || u.st.internalBull);
   u.choch.internalC = (u.choch.buy || u.choch.sell) && (u.st.internalBull || u.st.internalBear);
   u.choch.externalC = (u.choch.buy || u.choch.sell) && (u.st.externalBull || u.st.externalBear);
   u.choch.majorC = u.choch.externalC && u.bos.score >= 65;
   u.choch.minorC = (u.choch.buy || u.choch.sell) && !u.choch.majorC;
   u.choch.strength = 0;
   if(u.choch.buy || u.choch.sell) u.choch.strength = 50 + (u.choch.majorC ? 30 : 10) + (u.choch.internalC ? 10 : 0);
   if(u.choch.strength > 100) u.choch.strength = 100;
   u.choch.confidence = u.choch.strength;
}

#endif // SNIPER_AI_ULTRA_05_CHOCH_MQH
