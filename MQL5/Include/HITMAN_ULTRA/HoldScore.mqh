#ifndef HITMAN_ULTRA_HOLD_SCORE_MQH
#define HITMAN_ULTRA_HOLD_SCORE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 12 HOLD SCORE ENGINE                           |
//| Trend · Structure · Momentum · Liquidity · Risk · Thesis → action|
//+------------------------------------------------------------------+

enum ENUM_HOLD_ACTION
{
   HOLD_HOLD = 0,
   HOLD_MANAGE,
   HOLD_EXIT
};

struct UltraHoldScore
{
   int trend, structure, momentum, liquidity, risk, thesis;
   int total;
   ENUM_HOLD_ACTION action;
   string label;
};

string UltraHold_ActionName(const ENUM_HOLD_ACTION a)
{
   if(a == HOLD_HOLD) return "HOLD";
   if(a == HOLD_MANAGE) return "MANAGE";
   return "EXIT";
}

UltraHoldScore UltraHold_Evaluate(const UltraSnap &u, const bool isBuy, const bool thesisValid,
                                  const UltraCorrection &corr)
{
   UltraHoldScore h;
   h.trend = UltraUSM2_ComponentTrend(u, isBuy);
   h.structure = UltraUSM2_ComponentStructure(u, isBuy);
   h.momentum = UltraUSM2_ComponentMom(u, isBuy);
   h.liquidity = UltraUSM2_ComponentLiquidity(u, isBuy);
   h.risk = UltraUSM2_ComponentRisk(u);
   h.thesis = thesisValid ? 80 : 20;
   if(corr.state == CORR_REVERSAL) h.thesis = 10;
   if(corr.state == CORR_PULLBACK || corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST) h.thesis = MathMax(h.thesis, 60);

   h.total = (h.trend + h.structure + h.momentum + h.liquidity + h.risk + h.thesis) / 6;

   if(!UltraUpgradeEnabled || !UltraHoldScoreEnabled)
   {
      h.action = HOLD_MANAGE;
      h.label = "MANAGE";
      return h;
   }

   if(!thesisValid || corr.state == CORR_REVERSAL || h.total < 35)
      h.action = HOLD_EXIT;
   else if(h.total >= 65 && corr.isHealthy)
      h.action = HOLD_HOLD;
   else
      h.action = HOLD_MANAGE;

   // Soft: never EXIT on UNKNOWN correction alone
   if(!UltraUpgradeStrict && corr.state == CORR_UNKNOWN && thesisValid && h.action == HOLD_EXIT)
      h.action = HOLD_MANAGE;

   h.label = UltraHold_ActionName(h.action);
   return h;
}

#endif
