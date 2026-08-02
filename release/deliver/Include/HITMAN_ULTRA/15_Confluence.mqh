#ifndef HITMAN_ULTRA_15_CONFLUENCE_MQH
#define HITMAN_ULTRA_15_CONFLUENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 15_CONFLUENCE — Combines all engines → AI Confidence
//+------------------------------------------------------------------+
int UltraConfluenceBuy(const UltraSnap &u)
{
   // Base so live charts are never stuck at conf=0 when structure exists
   int sc = 18;
   if(u.st.quality >= 40) sc += 6;
   if(u.st.continuation || u.st.externalBull || u.st.internalBull) sc += 6;

   if(u.trend.htfBull) sc += 10; if(u.trend.macroBull) sc += 6; if(u.trend.bull) sc += 8;
   if(u.bos.buy) sc += 10; if(u.choch.buy) sc += 8;
   if(u.liq.sweepBuy) sc += 14; if(u.liq.stopHuntBuy) sc += 5;
   if(u.ict.dispBuy) sc += 10; if(u.ict.fvgBuy) sc += 6; if(u.ict.obBuy) sc += 6;
   if(u.ict.breakerBuy) sc += 4; if(u.ict.instZoneBuy) sc += 6;
   if(u.fib.atBuyZone) sc += 8; if(u.ict.inDiscount) sc += 5;
   if(u.mom.momBuy) sc += 4; if(u.ind.smi > 20) sc += 4; if(u.ind.ifi > 15) sc += 4;
   if(u.ind.meo >= 55) sc += 3;
   if(u.vol.expansion) sc += 3;
   if(UltraBoostKillZone && u.ctx.killZone) sc += 3;
   if(UltraBoostNewsVol && u.ctx.newsVol && u.ict.dispBuy) sc += 4;
   if(UltraSoftPreferFib && !u.fib.atBuyZone && !u.ict.inDiscount) sc -= 2;
   if(u.trend.mtfVotesBuy >= 3) sc += 5;
   if(sc < 0) sc = 0; if(sc > 100) sc = 100;
   return sc;
}
int UltraConfluenceSell(const UltraSnap &u)
{
   int sc = 18;
   if(u.st.quality >= 40) sc += 6;
   if(u.st.continuation || u.st.externalBear || u.st.internalBear) sc += 6;

   if(u.trend.htfBear) sc += 10; if(u.trend.macroBear) sc += 6; if(u.trend.bear) sc += 8;
   if(u.bos.sell) sc += 10; if(u.choch.sell) sc += 8;
   if(u.liq.sweepSell) sc += 14; if(u.liq.stopHuntSell) sc += 5;
   if(u.ict.dispSell) sc += 10; if(u.ict.fvgSell) sc += 6; if(u.ict.obSell) sc += 6;
   if(u.ict.breakerSell) sc += 4; if(u.ict.instZoneSell) sc += 6;
   if(u.fib.atSellZone) sc += 8; if(u.ict.inPremium) sc += 5;
   if(u.mom.momSell) sc += 4; if(u.ind.smi < -20) sc += 4; if(u.ind.ifi < -15) sc += 4;
   if(u.ind.meo >= 55) sc += 3;
   if(u.vol.expansion) sc += 3;
   if(UltraBoostKillZone && u.ctx.killZone) sc += 3;
   if(UltraBoostNewsVol && u.ctx.newsVol && u.ict.dispSell) sc += 4;
   if(UltraSoftPreferFib && !u.fib.atSellZone && !u.ict.inPremium) sc -= 2;
   if(u.trend.mtfVotesSell >= 3) sc += 5;
   if(sc < 0) sc = 0; if(sc > 100) sc = 100;
   return sc;
}

#endif // HITMAN_ULTRA_15_CONFLUENCE_MQH
