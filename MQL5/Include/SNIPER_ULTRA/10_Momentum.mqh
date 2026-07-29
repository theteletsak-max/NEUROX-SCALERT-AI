#ifndef SNIPER_ULTRA_10_MOMENTUM_MQH
#define SNIPER_ULTRA_10_MOMENTUM_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 10_MOMENTUM — SMI · Strength · Acceleration · Quality
//+------------------------------------------------------------------+
void UltraEngMomentum(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   int up = 0, dn = 0;
   double bodySum = 0, prevBody = 0;
   for(int i = 1; i <= MathMax(UltraMomentumBars, 3); i++)
   {
      double o = iOpen(s, tf, i), c = iClose(s, tf, i);
      double b = MathAbs(c - o);
      if(c > o) up++; if(c < o) dn++;
      if(i == 1) prevBody = b; else bodySum += b;
   }
   u.mom.momBuy = (up >= 2); u.mom.momSell = (dn >= 2);
   u.mom.direction = (up > dn) ? 1 : (dn > up ? -1 : 0);
   u.mom.strength = MathMin(100, (int)MathRound(100.0 * MathMax(up, dn) / MathMax(UltraMomentumBars, 3)));
   double avgPrev = bodySum / MathMax(UltraMomentumBars - 1, 1);
   u.mom.acceleration = (avgPrev > 0 && prevBody > avgPrev * 1.25) ? 80 : ((avgPrev > 0 && prevBody < avgPrev * 0.75) ? 30 : 55);
   u.mom.quality = (u.mom.strength + u.mom.acceleration) / 2;
   u.mom.confirmation = (u.mom.momBuy && u.ict.dispBuy) || (u.mom.momSell && u.ict.dispSell) ? 80 : 45;
   u.mom.weakness = (u.mom.acceleration <= 35 || u.mom.strength <= 40);
   u.mom.impulse  = (u.mom.acceleration >= 70 && u.mom.strength >= 60) ||
                    ((u.mom.momBuy && u.ict.dispBuy) || (u.mom.momSell && u.ict.dispSell));
}
void UltraEngIndicators(const string s, UltraSnap &u)
{
   // SMI: direction * momentum * acceleration scaled -100..100
   double dir = (double)u.mom.direction;
   double smi = dir * (0.45 * u.mom.strength + 0.35 * u.mom.acceleration + 0.20 * u.mom.confirmation);
   if(smi > 100) smi = 100; if(smi < -100) smi = -100;
   u.ind.smi = smi;

   // MEO: market energy / participation / trend energy 0..100
   double energy = 0.35 * (u.vol.relative * 40.0) + 0.35 * u.trend.strength + 0.30 * u.liq.quality;
   if(energy < 0) energy = 0; if(energy > 100) energy = 100;
   u.ind.meo = energy;

   // IFI: institutional footprint from sweep+disp+OB/FVG+vol expand
   double ifi = 0;
   if(u.liq.sweepBuy || u.ict.dispBuy || u.ict.obBuy || u.ict.fvgBuy) ifi += 25;
   if(u.liq.sweepSell || u.ict.dispSell || u.ict.obSell || u.ict.fvgSell) ifi -= 25;
   if(u.ict.smConfluence) ifi += (u.ict.dispBuy ? 20 : -20);
   if(u.vol.expansion) ifi += (ifi >= 0 ? 15 : -15);
   if(ifi > 100) ifi = 100; if(ifi < -100) ifi = -100;
   u.ind.ifi = ifi;
}

#endif // SNIPER_ULTRA_10_MOMENTUM_MQH
