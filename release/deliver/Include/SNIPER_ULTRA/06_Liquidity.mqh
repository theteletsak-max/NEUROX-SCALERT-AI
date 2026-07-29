#ifndef SNIPER_ULTRA_06_LIQUIDITY_MQH
#define SNIPER_ULTRA_06_LIQUIDITY_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 06_LIQUIDITY — Sweeps · Pools · Stop Hunts
//+------------------------------------------------------------------+
void UltraEngLiquidity(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   if(u.vol.atr <= 0) return;
   double tol = u.vol.atr * UltraEqualTolATR;
   int lb = MathMax(UltraStructLookback / 2, 12);
   double lo = iLow(s, tf, iLowest(s, tf, MODE_LOW, lb, 1));
   double hi = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, lb, 1));
   int nL = 0, nH = 0;
   for(int i = 1; i <= lb; i++)
   {
      if(MathAbs(iLow(s, tf, i) - lo) <= tol) nL++;
      if(MathAbs(iHigh(s, tf, i) - hi) <= tol) nH++;
   }
   u.liq.poolBuy = (nL >= 2);  // equal lows = sell-side pool / buy grab target
   u.liq.poolSell = (nH >= 2);
   u.liq.sellSideLiq = u.liq.poolBuy || (u.st.swingLow > 0);
   u.liq.buySideLiq  = u.liq.poolSell || (u.st.swingHigh > 0);
   u.liq.poolLow = u.liq.poolBuy ? lo : u.st.swingLow;
   u.liq.poolHigh = u.liq.poolSell ? hi : u.st.swingHigh;

   double minD = u.vol.atr * UltraSweepDepthATR;
   int swlb = MathMax(UltraSweepLookback, 5);
   double bestDepth = 0;
   for(int i = 1; i <= swlb; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), c = iClose(s, tf, i), o = iOpen(s, tf, i);
      double rng = h - l; if(rng <= 0) continue;
      if(!u.liq.sweepBuy && u.liq.poolLow > 0 && l < u.liq.poolLow - minD && c > u.liq.poolLow)
      {
         double wick = (MathMin(c, u.liq.poolLow) - l) / rng;
         if(wick >= UltraSweepWickMin)
         {
            u.liq.sweepBuy = true; u.liq.grabBuy = true; u.liq.sweepExtBuy = l;
            bestDepth = MathMax(bestDepth, (u.liq.poolLow - l) / u.vol.atr);
            u.liq.confirmedBuy = (c > o);
         }
      }
      if(!u.liq.sweepSell && u.liq.poolHigh > 0 && h > u.liq.poolHigh + minD && c < u.liq.poolHigh)
      {
         double wick = (h - MathMax(c, u.liq.poolHigh)) / rng;
         if(wick >= UltraSweepWickMin)
         {
            u.liq.sweepSell = true; u.liq.grabSell = true; u.liq.sweepExtSell = h;
            bestDepth = MathMax(bestDepth, (h - u.liq.poolHigh) / u.vol.atr);
            u.liq.confirmedSell = (c < o);
         }
      }
      double upper = h - MathMax(c, o);
      double lower = MathMin(c, o) - l;
      if(lower / rng >= 0.45 && c > o) u.liq.stopHuntBuy = true;
      if(upper / rng >= 0.45 && c < o) u.liq.stopHuntSell = true;
   }
   u.liq.depthATR = bestDepth;
   u.liq.speed = (u.liq.sweepBuy || u.liq.sweepSell) ? MathMin(100.0, 40.0 + bestDepth * 40.0) : 0;
   u.liq.strength = u.liq.speed;
   u.liq.quality = 40;
   if(u.liq.confirmedBuy || u.liq.confirmedSell) u.liq.quality += 25;
   if(u.liq.stopHuntBuy || u.liq.stopHuntSell) u.liq.quality += 15;
   if(u.liq.poolBuy || u.liq.poolSell) u.liq.quality += 10;
   if(u.liq.quality > 100) u.liq.quality = 100;
   u.liq.rejectionScore = (int)MathRound(u.liq.quality);
}

#endif // SNIPER_ULTRA_06_LIQUIDITY_MQH
