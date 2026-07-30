#ifndef HITMAN_ULTRA_MASTER_AI_BRAIN_MQH
#define HITMAN_ULTRA_MASTER_AI_BRAIN_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER AI BRAIN                                      |
//| Final decision surface: BUY · SELL · WAIT only                   |
//+------------------------------------------------------------------+

struct UltraBrainDecision
{
   ENUM_SUPREME_DECISION decision;
   int confidence;
   int tradeScore;
   string grade;
   string thesis;
   string reason;
   bool explainable;
   bool consistent;
};

UltraBrainDecision g_UltraBrainLast;

void UltraBrain_Clear()
{
   g_UltraBrainLast.decision = SUP_WAIT;
   g_UltraBrainLast.confidence = 0;
   g_UltraBrainLast.tradeScore = 0;
   g_UltraBrainLast.grade = "IGNORE";
   g_UltraBrainLast.thesis = "";
   g_UltraBrainLast.reason = "WAIT";
   g_UltraBrainLast.explainable = false;
   g_UltraBrainLast.consistent = true;
}

void UltraBrain_Publish(const bool approved, const bool buySide, const UltraSnap &u,
                        const string thesis, const string why)
{
   UltraBrain_Clear();
   g_UltraBrainLast.confidence = u.score.confidence;
   g_UltraBrainLast.tradeScore = g_UltraUSM2Last.tradeScore > 0 ? g_UltraUSM2Last.tradeScore : u.score.confidence;
   g_UltraBrainLast.grade = g_UltraUSM2Last.grade;
   g_UltraBrainLast.thesis = thesis;
   g_UltraBrainLast.explainable = (StringLen(thesis) > 0 || StringLen(why) > 0);
   g_UltraBrainLast.consistent = true;

   if(!approved)
   {
      g_UltraBrainLast.decision = SUP_WAIT;
      g_UltraBrainLast.reason = why;
      if(StringLen(g_UltraBrainLast.reason) == 0) g_UltraBrainLast.reason = "WAIT";
      return;
   }

   g_UltraBrainLast.decision = buySide ? SUP_BUY : SUP_SELL;
   g_UltraBrainLast.reason = "APPROVED";
}

string UltraBrain_Name()
{
   if(g_UltraBrainLast.decision == SUP_BUY) return "BUY";
   if(g_UltraBrainLast.decision == SUP_SELL) return "SELL";
   if(g_UltraBrainLast.decision == SUP_HOLD) return "HOLD";
   if(g_UltraBrainLast.decision == SUP_MANAGE) return "MANAGE";
   if(g_UltraBrainLast.decision == SUP_EXIT) return "EXIT";
   return "WAIT";
}

string UltraBrain_Dashboard()
{
   string t = "BRAIN: ";
   t += UltraBrain_Name();
   t += " conf=";
   t += IntegerToString(g_UltraBrainLast.confidence);
   t += " score=";
   t += IntegerToString(g_UltraBrainLast.tradeScore);
   if(StringLen(g_UltraBrainLast.grade) > 0)
   {
      t += " ";
      t += g_UltraBrainLast.grade;
   }
   return t;
}

#endif
