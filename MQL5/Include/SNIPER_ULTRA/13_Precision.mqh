#ifndef SNIPER_ULTRA_13_PRECISION_MQH
#define SNIPER_ULTRA_13_PRECISION_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 13_PRECISION — Entry/Exit/Signal precision · False signal cut
//+------------------------------------------------------------------+

int UltraPrecisionScore(const UltraSnap &u)
{
   int prec = (u.st.quality + u.bos.reliability + u.fib.quality + u.liq.rejectionScore) / 4;
   if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) prec -= 8;
   if(u.ict.smConfluence) prec += 8;
   if(prec < 0) prec = 0; if(prec > 100) prec = 100;
   return prec;
}

#endif // SNIPER_ULTRA_13_PRECISION_MQH
