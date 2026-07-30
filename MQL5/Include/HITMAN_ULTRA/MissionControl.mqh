#ifndef HITMAN_ULTRA_MISSION_CONTROL_MQH
#define HITMAN_ULTRA_MISSION_CONTROL_MQH
//+------------------------------------------------------------------+
//| HITMAN AI ULTRA X — LEVEL 8 ULTRA MISSION CONTROL                |
//| Single authority — no other module may override                  |
//| Approves: BUY · SELL · WAIT · HOLD · MANAGE · EXIT               |
//+------------------------------------------------------------------+

struct UltraMissionState
{
   ENUM_SUPREME_DECISION command;
   string reason;
   int confidence;
   int tradeScore;
   string grade;
   string thesis;
   ulong ticket;   // for manage path
   datetime ts;
};

UltraMissionState g_UltraMissionLast;

string UltraMission_Name(const ENUM_SUPREME_DECISION c)
{
   if(c == SUP_BUY) return "BUY";
   if(c == SUP_SELL) return "SELL";
   if(c == SUP_WAIT) return "WAIT";
   if(c == SUP_HOLD) return "HOLD";
   if(c == SUP_MANAGE) return "MANAGE";
   if(c == SUP_EXIT) return "EXIT";
   return "WAIT";
}

void UltraMission_Set(const ENUM_SUPREME_DECISION c, const string reason,
                      const int conf, const int score, const string grade,
                      const string thesis, const ulong ticket)
{
   g_UltraMissionLast.command = c;
   g_UltraMissionLast.reason = reason;
   g_UltraMissionLast.confidence = conf;
   g_UltraMissionLast.tradeScore = score;
   g_UltraMissionLast.grade = grade;
   g_UltraMissionLast.thesis = thesis;
   g_UltraMissionLast.ticket = ticket;
   g_UltraMissionLast.ts = TimeCurrent();
}

// Entry path — sole approval authority for BUY/SELL/WAIT
bool UltraMission_ApproveEntry(const string s, UltraSnap &u, UltraSignal &sig, string &why)
{
   bool ok = UltraSupreme_FinalizeEntry(s, u, sig, why);
   if(ok)
   {
      ENUM_SUPREME_DECISION c = sig.buy ? SUP_BUY : SUP_SELL;
      UltraMission_Set(c, g_UltraSupremeLast.reason, g_UltraSupremeLast.confidence,
                       g_UltraSupremeLast.tradeScore, g_UltraSupremeLast.grade,
                       g_UltraSupremeLast.thesis, 0);
   }
   else
   {
      UltraMission_Set(SUP_WAIT, why, u.score.confidence, u.score.confidence, "IGNORE", "", 0);
   }
   return ok;
}

// Open-position path — sole authority for HOLD/MANAGE/EXIT
ENUM_SUPREME_DECISION UltraMission_PositionCommand(const ulong ticket, const string s,
                                                   const bool isBuy, const UltraSnap &u,
                                                   string &why)
{
   why = "";
   ENUM_SMART_EXIT sx = UltraSupreme_ManagePosition(ticket, s, isBuy, u, why);
   ENUM_SUPREME_DECISION cmd = SUP_MANAGE;
   if(sx == SX_CLOSE) cmd = SUP_EXIT;
   else if(sx == SX_NONE && g_UltraHoldLast.action == HOLD_HOLD) cmd = SUP_HOLD;
   else if(sx == SX_BE || sx == SX_TIGHTEN) cmd = SUP_MANAGE;
   else if(g_UltraHoldLast.action == HOLD_EXIT) cmd = SUP_EXIT;
   else if(g_UltraHoldLast.action == HOLD_HOLD) cmd = SUP_HOLD;
   else cmd = SUP_MANAGE;

   UltraMission_Set(cmd, why, u.score.confidence, g_UltraHoldLast.total,
                    g_UltraHoldLast.label, g_UltraBrainLast.thesis, ticket);
   return cmd;
}

// Map mission EXIT/MANAGE/HOLD → smart-exit actions for Shell
ENUM_SMART_EXIT UltraMission_ToSmartExit(const ENUM_SUPREME_DECISION cmd)
{
   if(cmd == SUP_EXIT) return SX_CLOSE;
   if(cmd == SUP_MANAGE) return SX_BE;
   return SX_NONE; // HOLD
}

string UltraMission_Dashboard()
{
   string t = "MISSION: ";
   t += UltraMission_Name(g_UltraMissionLast.command);
   t += " ";
   t += g_UltraMissionLast.reason;
   return t;
}

#endif
