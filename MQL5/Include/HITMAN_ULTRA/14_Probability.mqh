#ifndef HITMAN_ULTRA_14_PROBABILITY_MQH
#define HITMAN_ULTRA_14_PROBABILITY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 14_PROBABILITY                                  |
//| Probability Score · Confidence Score · Success Estimation         |
//+------------------------------------------------------------------+

int UltraConfidenceScore(const UltraSnap &u, const int confluence)
{
   int c = confluence;
   if(u.trend.mtfVotesBuy >= 3 || u.trend.mtfVotesSell >= 3) c += 4;
   if(u.ctx.sessionLiquidity) c += 2;
   if(c < 0) c = 0; if(c > 100) c = 100;
   return c;
}

int UltraSuccessEstimation(const UltraSnap &u, const int confidence, const int precision)
{
   int base = (confidence + precision) / 2;
   int smiBoost = (int)MathRound(MathAbs(u.ind.smi) * 0.25);
   int memBoost = 0;
   if(g_UltraMem.trades >= 10 && g_UltraMem.winRate >= 55.0) memBoost = 4;
   int succ = base + smiBoost + memBoost;
   if(u.regime == UREG_EXHAUSTION || u.regime == UREG_REVERSAL) succ -= 4;
   if(succ < 0) succ = 0; if(succ > 100) succ = 100;
   return succ;
}

int UltraProbabilityScore(const UltraSnap &u, const int confidence, const int precision)
{
   return UltraSuccessEstimation(u, UltraConfidenceScore(u, confidence), precision);
}

int UltraRiskProbability(const int successProb)
{
   int r = 100 - successProb;
   if(r < 0) r = 0; if(r > 100) r = 100;
   return r;
}

#endif // HITMAN_ULTRA_14_PROBABILITY_MQH
