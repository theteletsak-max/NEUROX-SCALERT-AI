#ifndef HITMAN_ULTRA_HOLD_SCORE_MQH
#define HITMAN_ULTRA_HOLD_SCORE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 12 HOLD SCORE ENGINE                           |
//| Soft default: never EXIT on temporary score dips / UNKNOWN noise |
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

UltraHoldScore g_UltraHoldLast;

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
   if(corr.state == CORR_PULLBACK || corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST ||
      corr.state == CORR_CONTINUATION || corr.state == CORR_UNKNOWN)
   {
      if(h.thesis < 60) h.thesis = 60; // healthy / unknown noise → do not punish thesis
   }

   h.total = (h.trend + h.structure + h.momentum + h.liquidity + h.risk + h.thesis) / 6;

   if(!UltraUpgradeEnabled || !UltraHoldScoreEnabled)
   {
      h.action = HOLD_MANAGE;
      h.label = "MANAGE";
      g_UltraHoldLast = h;
      return h;
   }

   // Soft InstantQuality path: EXIT only on confirmed thesis death + reversal
   if(!UltraUpgradeStrict)
   {
      if(!thesisValid && corr.state == CORR_REVERSAL)
         h.action = HOLD_EXIT;
      else if(h.total >= 55 && corr.isHealthy)
         h.action = HOLD_HOLD;
      else
         h.action = HOLD_MANAGE; // low score / pullback → manage, never force-close
   }
   else
   {
      if((!thesisValid && corr.state == CORR_REVERSAL) || (corr.state == CORR_REVERSAL && h.total < 30))
         h.action = HOLD_EXIT;
      else if(h.total >= 65 && corr.isHealthy)
         h.action = HOLD_HOLD;
      else
         h.action = HOLD_MANAGE;
   }

   h.label = UltraHold_ActionName(h.action);
   g_UltraHoldLast = h;
   return h;
}

string UltraHold_Dashboard()
{
   string t = "HOLD: ";
   t += g_UltraHoldLast.label;
   t += " ";
   t += IntegerToString(g_UltraHoldLast.total);
   return t;
}

#endif
