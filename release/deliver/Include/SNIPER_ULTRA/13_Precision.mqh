#ifndef SNIPER_ULTRA_13_PRECISION_MQH
#define SNIPER_ULTRA_13_PRECISION_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 13_PRECISION                                    |
//| Entry Precision · Exit Precision · Signal Validation ·            |
//| Trade Quality · Precision Score                                   |
//+------------------------------------------------------------------+

int UltraEntryPrecision(const UltraSnap &u)
{
   int e = 40;
   if(u.bos.confirmation >= 60) e += 12;
   if(u.liq.confirmedBuy || u.liq.confirmedSell) e += 12;
   if(u.fib.atBuyZone || u.fib.atSellZone) e += 10;
   if(u.ict.dispBuy || u.ict.dispSell) e += 10;
   if(u.ict.smConfluence) e += 8;
   if(u.mom.confirmation >= 50) e += 8;
   if(e > 100) e = 100;
   return e;
}

int UltraExitPrecision(const UltraSnap &u)
{
   int x = 45;
   if(u.vol.expansion) x += 10;
   if(u.fib.ext127 > 0.0 || u.fib.ext161 > 0.0) x += 10;
   if(u.trend.quality >= 60) x += 10;
   if(u.regime == UREG_STRONG_TREND || u.regime == UREG_EXPANSION) x += 10;
   if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) x -= 8;
   if(x < 0) x = 0; if(x > 100) x = 100;
   return x;
}

bool UltraSignalValidation(const UltraSnap &u, const bool buySide)
{
   if(buySide)
      return (u.bos.buy || u.choch.buy || u.liq.sweepBuy || u.fib.atBuyZone || u.ict.instZoneBuy);
   return (u.bos.sell || u.choch.sell || u.liq.sweepSell || u.fib.atSellZone || u.ict.instZoneSell);
}

int UltraTradeQuality(const UltraSnap &u)
{
   int q = (u.st.quality + u.bos.quality + u.fib.quality + u.trend.quality) / 4;
   if(u.ict.smConfluence) q += 8;
   if(u.liq.rejectionScore >= 60) q += 6;
   if(q > 100) q = 100;
   return q;
}

int UltraPrecisionScore(const UltraSnap &u)
{
   int entry = UltraEntryPrecision(u);
   int exitp = UltraExitPrecision(u);
   int tq    = UltraTradeQuality(u);
   int prec  = (entry + exitp + tq + u.bos.reliability + u.liq.rejectionScore) / 5;
   if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) prec -= 8;
   if(u.ict.smConfluence) prec += 6;
   if(prec < 0) prec = 0; if(prec > 100) prec = 100;
   return prec;
}

#endif // SNIPER_ULTRA_13_PRECISION_MQH
