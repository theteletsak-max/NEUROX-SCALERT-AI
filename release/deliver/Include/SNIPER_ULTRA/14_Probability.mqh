#ifndef SNIPER_ULTRA_14_PROBABILITY_MQH
#define SNIPER_ULTRA_14_PROBABILITY_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 14_PROBABILITY — Success · Confidence · Risk probability
//+------------------------------------------------------------------+

int UltraProbabilityScore(const UltraSnap &u, const int confidence, const int precision)
{
   int succ = (confidence + precision + (int)MathRound(MathAbs(u.ind.smi))) / 3;
   if(succ > 100) succ = 100;
   return succ;
}

int UltraRiskProbability(const int successProb)
{
   return 100 - successProb;
}

#endif // SNIPER_ULTRA_14_PROBABILITY_MQH
