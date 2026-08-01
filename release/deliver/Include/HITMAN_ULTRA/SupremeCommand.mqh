#ifndef HITMAN_ULTRA_SUPREME_COMMAND_MQH
#define HITMAN_ULTRA_SUPREME_COMMAND_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 1 / 20 SUPREME COMMAND + FINAL AI DECISION     |
//| Global coordinator · mission manager · trade approval authority  |
//+------------------------------------------------------------------+

struct UltraSupremeDecision
{
   ENUM_SUPREME_DECISION decision;
   int confidence;
   int tradeScore;
   string grade;
   string thesis;
   string evo;
   string reason;
   bool approved;
};

UltraSupremeDecision g_UltraSupremeLast;

string UltraSupreme_Name(const ENUM_SUPREME_DECISION d)
{
   if(d == SUP_BUY) return "BUY";
   if(d == SUP_SELL) return "SELL";
   if(d == SUP_HOLD) return "HOLD";
   if(d == SUP_MANAGE) return "MANAGE";
   if(d == SUP_EXIT) return "EXIT";
   return "WAIT";
}

// Final approval authority — consumes existing gates; does not re-stack them.
bool UltraSupreme_FinalizeEntry(const string s, UltraSnap &u, UltraSignal &sig, string &why)
{
   why = "";
   UltraSupremeDecision d;
   d.decision = SUP_WAIT;
   d.confidence = u.score.confidence;
   d.tradeScore = u.score.confidence;
   d.grade = "IGNORE";
   d.thesis = "";
   d.evo = "STABLE";
   d.reason = "";
   d.approved = false;

   if(!UltraUpgradeEnabled || !UltraSupremeEnabled)
   {
      d.approved = (sig.buy || sig.sell);
      if(sig.buy) d.decision = SUP_BUY;
      else if(sig.sell) d.decision = SUP_SELL;
      d.reason = "supreme off — pass-through";
      g_UltraSupremeLast = d;
      UltraBrain_Publish(d.approved, sig.buy, u, "", d.reason);
      return d.approved;
   }

   // System health hard gate (RED only)
   if(!UltraSystemHealth_Update(s))
   {
      why = "SUPREME: health RED ";
      why += g_UltraSysHealth.detail;
      d.reason = why;
      g_UltraSupremeLast = d;
      UltraBrain_Publish(false, false, u, "", why);
      return false;
   }

   if(!(sig.buy || sig.sell) || sig.tag == "NONE")
   {
      why = "SUPREME: no candidate";
      d.reason = why;
      g_UltraSupremeLast = d;
      UltraBrain_Publish(false, false, u, "", why);
      return false;
   }

   bool buySide = sig.buy;

   // One trade = one thesis (same symbol + same direction only; MaxOpen may allow more)
   if(UltraThesisEnabled)
   {
      for(int ti = 0; ti < g_ThesisN; ti++)
      {
         if(!g_Thesis[ti].valid) continue;
         if(g_Thesis[ti].symbol != s) continue;
         if(g_Thesis[ti].isBuy != buySide) continue;
         why = "SUPREME: thesis already active same direction";
         d.reason = why;
         g_UltraSupremeLast = d;
         UltraBrain_Publish(false, buySide, u, "", why);
         return false;
      }
   }

   // LEVEL 2 — One Confidence Engine: reuse USM2 from UltraAIDecide (no re-score)
   if(UltraUSM2Enabled && g_UltraUSM2Last.tradeScore > 0)
   {
      d.confidence = u.score.confidence > 0 ? u.score.confidence : g_UltraUSM2Last.confidence;
      d.tradeScore = g_UltraUSM2Last.tradeScore;
      d.grade = g_UltraUSM2Last.grade;
   }
   else if(UltraUSM2Enabled)
   {
      UltraUSM2Scores usm;
      UltraUSM2_Score(s, u, buySide, usm);
      g_UltraUSM2Last = usm;
      d.confidence = usm.confidence;
      d.tradeScore = usm.tradeScore;
      d.grade = usm.grade;
   }
   else
   {
      d.confidence = u.score.confidence;
      d.tradeScore = u.score.confidence;
      d.grade = UltraUSM2_Grade((double)d.tradeScore);
   }

   // Signal evolution (Level 3)
   UltraSignalEvo evo = UltraEvo_Evaluate(s, u, buySide);
   d.evo = evo.label;
   if(evo.state == SEVO_REVERSAL)
   {
      why = "SUPREME: signal evolution REVERSAL";
      d.reason = why;
      g_UltraSupremeLast = d;
      UltraBrain_Publish(false, buySide, u, "", why);
      return false;
   }

   // Floor already applied in UltraAIDecide — soft verify only
   int floor = UltraFireFloor();
   if(d.tradeScore < floor && d.confidence < UltraInstantFireConf)
   {
      why = "SUPREME: trade score low ";
      why += IntegerToString(d.tradeScore);
      d.reason = why;
      g_UltraSupremeLast = d;
      UltraBrain_Publish(false, buySide, u, "", why);
      return false;
   }

   // Ignore grade only in strict mode
   if(UltraUpgradeStrict && d.grade == "IGNORE")
   {
      why = "SUPREME: grade IGNORE";
      d.reason = why;
      g_UltraSupremeLast = d;
      UltraBrain_Publish(false, buySide, u, "", why);
      return false;
   }

   // Build / attach thesis text (Level 11 entry side)
   // Memory note is recorded once on fill via UltraThesis_Store (avoid duplicate notes).
   string thesis = UltraDisc_BuildThesis(u, buySide, sig.tag);
   d.thesis = thesis;

   d.decision = buySide ? SUP_BUY : SUP_SELL;
   d.approved = true;
   d.reason = "APPROVED";
   g_UltraSupremeLast = d;
   UltraBrain_Publish(true, buySide, u, thesis, "APPROVED");

   if(UltraUpgradeLog)
   {
      string t = "SUPREME ";
      t += UltraSupreme_Name(d.decision);
      t += " conf="; t += IntegerToString(d.confidence);
      t += " score="; t += IntegerToString(d.tradeScore);
      t += " grade="; t += d.grade;
      t += " evo="; t += d.evo;
      UltraLogAI(t);
   }
   return true;
}

// Open-position command: HOLD / MANAGE / EXIT via hold+correction+smart exit
ENUM_SMART_EXIT UltraSupreme_ManagePosition(const ulong ticket, const string s, const bool isBuy,
                                            const UltraSnap &u, string &why)
{
   why = "";
   if(!UltraUpgradeEnabled) return SX_NONE;

   string tw = "";
   bool thesisOK = UltraThesis_Revalidate(ticket, u, tw);
   UltraCorrection corr = UltraCorr_Detect(u, isBuy);
   UltraHoldScore hold = UltraHold_Evaluate(u, isBuy, thesisOK, corr);
   UltraSmartExit sx = UltraSmartExit_Decide(hold, corr, thesisOK, false);
   why = sx.reason;
   if(StringLen(why) == 0)
   {
      why = "hold=";
      why += hold.label;
      why += " corr=";
      why += corr.label;
   }
   return sx.action;
}

string UltraSupreme_Dashboard()
{
   string t = "SUPREME: ";
   t += UltraSupreme_Name(g_UltraSupremeLast.decision);
   t += " ";
   t += g_UltraSupremeLast.grade;
   t += " conf=";
   t += IntegerToString(g_UltraSupremeLast.confidence);
   return t;
}

#endif
