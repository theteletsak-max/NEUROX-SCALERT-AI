#ifndef HITMAN_ULTRA_08_INSTITUTIONAL_MQH
#define HITMAN_ULTRA_08_INSTITUTIONAL_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 08_INSTITUTIONAL — OB · Breaker · FVG · Smart Money
//+------------------------------------------------------------------+
void UltraEngInstitutional(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();

   // Displacement: any strong body in last 3 closed bars
   for(int i = 1; i <= 3; i++)
   {
      double o = iOpen(s, tf, i), c = iClose(s, tf, i);
      double h = iHigh(s, tf, i), l = iLow(s, tf, i);
      double r = h - l;
      if(r <= 0) continue;
      double br = MathAbs(c - o) / r;
      bool atrOK = (u.vol.atr <= 0) || (r >= u.vol.atr * UltraDispATRMin * 0.85);
      if(br >= UltraDispBodyMin * 0.90 && atrOK)
      {
         if(c > o) u.ict.dispBuy = true;
         if(c < o) u.ict.dispSell = true;
      }
   }

   // FVG + raw imbalance lookback across recent bars
   for(int g = 1; g <= 5; g++)
   {
      double gapB = iLow(s, tf, g) - iHigh(s, tf, g + 2);
      double gapS = iLow(s, tf, g + 2) - iHigh(s, tf, g);
      if(gapB > 0)
      {
         u.ict.imbalanceBuy = true;
         if(u.vol.atr <= 0 || gapB >= u.vol.atr * UltraFVG_MinATR * 0.8)
            u.ict.fvgBuy = true;
      }
      if(gapS > 0)
      {
         u.ict.imbalanceSell = true;
         if(u.vol.atr <= 0 || gapS >= u.vol.atr * UltraFVG_MinATR * 0.8)
            u.ict.fvgSell = true;
      }
   }

   double o2 = iOpen(s, tf, 2), c2 = iClose(s, tf, 2);
   if(u.ict.dispBuy && c2 < o2) u.ict.obBuy = true;
   if(u.ict.dispSell && c2 > o2) u.ict.obSell = true;
   // Soft OB: opposite candle before displacement in last 4 bars
   if(!u.ict.obBuy && u.ict.dispBuy)
   {
      for(int i = 2; i <= 4; i++)
         if(iClose(s, tf, i) < iOpen(s, tf, i)) { u.ict.obBuy = true; break; }
   }
   if(!u.ict.obSell && u.ict.dispSell)
   {
      for(int i = 2; i <= 4; i++)
         if(iClose(s, tf, i) > iOpen(s, tf, i)) { u.ict.obSell = true; break; }
   }

   if(u.bos.buy && u.ict.obSell) u.ict.breakerBuy = true;
   if(u.bos.sell && u.ict.obBuy) u.ict.breakerSell = true;

   double px = SymbolInfoDouble(s, SYMBOL_BID);
   if(u.ict.obBuy && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationBuy = true;
   if(u.ict.obSell && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationSell = true;
   if(u.st.swingHigh > u.st.swingLow)
   {
      double mid = (u.st.swingHigh + u.st.swingLow) * 0.5;
      u.ict.inDiscount = (px <= mid); u.ict.inPremium = (px >= mid);
   }
   u.ict.instZoneBuy = (u.ict.obBuy || u.ict.fvgBuy || u.ict.breakerBuy) && (u.ict.inDiscount || u.fib.atBuyZone);
   u.ict.instZoneSell = (u.ict.obSell || u.ict.fvgSell || u.ict.breakerSell) && (u.ict.inPremium || u.fib.atSellZone);
   u.ict.rejectZoneBuy = u.liq.stopHuntBuy && u.ict.inDiscount;
   u.ict.rejectZoneSell = u.liq.stopHuntSell && u.ict.inPremium;
   // Institutional liquidity = pools / equal HL + displacement / OB confluence
   u.ict.institutionalLiqBuy =
      (u.liq.poolBuy || u.liq.equalLows || u.liq.sweepBuy) &&
      (u.ict.obBuy || u.ict.fvgBuy || u.ict.dispBuy || u.ict.imbalanceBuy);
   u.ict.institutionalLiqSell =
      (u.liq.poolSell || u.liq.equalHighs || u.liq.sweepSell) &&
      (u.ict.obSell || u.ict.fvgSell || u.ict.dispSell || u.ict.imbalanceSell);

   u.ict.smConfluence = ((u.ict.obBuy || u.ict.fvgBuy) && (u.liq.sweepBuy || u.ict.dispBuy)) ||
                        ((u.ict.obSell || u.ict.fvgSell) && (u.liq.sweepSell || u.ict.dispSell)) ||
                        u.ict.institutionalLiqBuy || u.ict.institutionalLiqSell;
}

#endif // HITMAN_ULTRA_08_INSTITUTIONAL_MQH
