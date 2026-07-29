#ifndef HITMAN_ULTRA_11_VOLATILITY_MQH
#define HITMAN_ULTRA_11_VOLATILITY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 11_VOLATILITY — ATR Expand/Compress · Classification
//+------------------------------------------------------------------+
void UltraEngVolatility(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   u.vol.atr = UltraATR(s, ATR_Period);
   if(u.vol.atr <= 0) return;
   double avg = 0.0;
   for(int i = 2; i <= 21; i++) avg += (iHigh(s, tf, i) - iLow(s, tf, i));
   avg /= 20.0;
   double r1 = iHigh(s, tf, 1) - iLow(s, tf, 1);
   u.vol.relative = (avg > 0) ? (r1 / avg) : 1.0;
   u.vol.expansion = (u.vol.relative >= 1.35);
   u.vol.compression = (u.vol.relative <= 0.70);
   if(u.vol.expansion) u.vol.classification = 1;
   else if(u.vol.compression) u.vol.classification = -1;
   else u.vol.classification = 0;
}

#endif // HITMAN_ULTRA_11_VOLATILITY_MQH
