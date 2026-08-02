#ifndef HITMAN_ULTRA_12_MARKETREGIME_MQH
#define HITMAN_ULTRA_12_MARKETREGIME_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 12_MARKET_REGIME                                |
//| Strong/Weak Trend · Range · Breakout · Reversal · Acc/Dist        |
//+------------------------------------------------------------------+
void UltraEngRegime(UltraSnap &u)
{
   u.trend.exhaustion = (u.mom.acceleration <= 30 && u.vol.expansion && u.trend.strength >= 55);

   if(u.vol.compression && !(u.trend.bull || u.trend.bear)) u.regime = UREG_COMPRESSION;
   else if(u.vol.expansion && (u.bos.buy || u.bos.sell) && u.bos.strong)
      u.regime = UREG_BREAKOUT;
   else if(u.vol.expansion && (u.choch.buy || u.choch.sell)) u.regime = UREG_REVERSAL;
   else if(u.vol.expansion && u.trend.strength >= 70) u.regime = UREG_EXPANSION;
   else if(u.trend.exhaustion) u.regime = UREG_EXHAUSTION;
   else if(u.trend.strength >= 75 && u.trend.continuation) u.regime = UREG_STRONG_TREND;
   else if(u.trend.strength >= 55 && u.trend.continuation) u.regime = UREG_HEALTHY_TREND;
   else if(u.trend.strength >= 40 && (u.trend.bull || u.trend.bear)) u.regime = UREG_WEAK_TREND;
   else if(u.liq.sweepBuy && u.ict.inDiscount && !u.trend.htfBear) u.regime = UREG_ACCUMULATION;
   else if(u.liq.sweepSell && u.ict.inPremium && !u.trend.htfBull) u.regime = UREG_DISTRIBUTION;
   else if(u.mom.acceleration <= 30 && u.vol.expansion) u.regime = UREG_EXHAUSTION;
   else u.regime = UREG_RANGE;
}
string UltraRegimeName(const ENUM_ULTRA_REGIME r)
{
   switch(r)
   {
      case UREG_STRONG_TREND: return "STRONG_TREND";
      case UREG_WEAK_TREND: return "WEAK_TREND";
      case UREG_HEALTHY_TREND: return "HEALTHY_TREND";
      case UREG_RANGE: return "RANGE";
      case UREG_COMPRESSION: return "COMPRESSION";
      case UREG_EXPANSION: return "EXPANSION";
      case UREG_BREAKOUT: return "BREAKOUT";
      case UREG_REVERSAL: return "REVERSAL";
      case UREG_ACCUMULATION: return "ACCUMULATION";
      case UREG_DISTRIBUTION: return "DISTRIBUTION";
      case UREG_EXHAUSTION: return "EXHAUSTION";
   }
   return "RANGE";
}

#endif // HITMAN_ULTRA_12_MARKETREGIME_MQH
