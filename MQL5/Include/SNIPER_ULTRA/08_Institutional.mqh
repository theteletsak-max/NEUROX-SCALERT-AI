#ifndef SNIPER_ULTRA_08_INSTITUTIONAL_MQH
#define SNIPER_ULTRA_08_INSTITUTIONAL_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 08_INSTITUTIONAL — OB · Breaker · FVG · Smart Money
//+------------------------------------------------------------------+
void UltraEngInstitutional(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double o1 = iOpen(s, tf, 1), c1 = iClose(s, tf, 1), h1 = iHigh(s, tf, 1), l1 = iLow(s, tf, 1);
   double r1 = h1 - l1;
   if(r1 > 0)
   {
      double br = MathAbs(c1 - o1) / r1;
      bool atrOK = (u.vol.atr <= 0) || (r1 >= u.vol.atr * UltraDispATRMin);
      if(br >= UltraDispBodyMin && atrOK){ u.ict.dispBuy = (c1 > o1); u.ict.dispSell = (c1 < o1); }
   }
   double gapB = iLow(s, tf, 1) - iHigh(s, tf, 3);
   double gapS = iLow(s, tf, 3) - iHigh(s, tf, 1);
   if(gapB > 0 && (u.vol.atr <= 0 || gapB >= u.vol.atr * UltraFVG_MinATR)) u.ict.fvgBuy = true;
   if(gapS > 0 && (u.vol.atr <= 0 || gapS >= u.vol.atr * UltraFVG_MinATR)) u.ict.fvgSell = true;
   double o2 = iOpen(s, tf, 2), c2 = iClose(s, tf, 2);
   if(u.ict.dispBuy && c2 < o2) u.ict.obBuy = true;
   if(u.ict.dispSell && c2 > o2) u.ict.obSell = true;
   // Breaker: prior OB invalidated then reclaim
   if(u.bos.buy && u.ict.obSell) u.ict.breakerBuy = true;
   if(u.bos.sell && u.ict.obBuy) u.ict.breakerSell = true;
   // Mitigation: price returned into OB/FVG
   double px = SymbolInfoDouble(s, SYMBOL_BID);
   if(u.ict.obBuy && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationBuy = true;
   if(u.ict.obSell && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationSell = true;
   if(u.st.swingHigh > u.st.swingLow)
   {
      double mid = (u.st.swingHigh + u.st.swingLow) * 0.5;
      u.ict.inDiscount = (px <= mid); u.ict.inPremium = (px >= mid);
   }
   u.ict.instZoneBuy = (u.ict.obBuy || u.ict.fvgBuy || u.ict.breakerBuy) && u.ict.inDiscount;
   u.ict.instZoneSell = (u.ict.obSell || u.ict.fvgSell || u.ict.breakerSell) && u.ict.inPremium;
   u.ict.rejectZoneBuy = u.liq.stopHuntBuy && u.ict.inDiscount;
   u.ict.rejectZoneSell = u.liq.stopHuntSell && u.ict.inPremium;
   u.ict.smConfluence = ((u.ict.obBuy || u.ict.fvgBuy) && u.liq.sweepBuy && u.ict.dispBuy) ||
                        ((u.ict.obSell || u.ict.fvgSell) && u.liq.sweepSell && u.ict.dispSell);
}

#endif // SNIPER_ULTRA_08_INSTITUTIONAL_MQH
