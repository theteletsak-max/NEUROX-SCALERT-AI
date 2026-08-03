#ifndef HITMAN_ULTRA_MISSION_CONTROL_MQH
#define HITMAN_ULTRA_MISSION_CONTROL_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 8 MISSION CONTROL                              |
//| PHASE A: SOLE FINAL DECISION AUTHORITY for BUY · SELL · WAIT     |
//| EXIT & HOLD FIX LIST — only this module may close trades         |
//| Nothing AFTER Mission may flip BUY/SELL → WAIT (Phase A lock)    |
//+------------------------------------------------------------------+

// Forward — Bug Elimination / Maintenance assembled after Mission Control
// (must match early UltraBacktestCompat forward; defaults only on definition)
void UltraBug_Explain(const string action, const string module, const string func,
                      const string reason, const string side, const ulong ticket);

#define ULTRA_POSLOCK_MAX 64

struct UltraMissionState
{
   ENUM_SUPREME_DECISION command;
   string reason;
   int confidence;
   int tradeScore;
   string grade;
   string thesis;
   ulong ticket;
   datetime ts;
};

struct UltraPosLock
{
   ulong    ticket;
   string   symbol;
   bool     isBuy;
   bool     active;
   string   status;      // HOLD / MANAGE / EXIT
   int      holdScore;
   string   thesisTag;
   datetime openTime;
   datetime lastEvalBar;
   bool     decidedThisCycle; // one decision per evaluation
};

// UltraExitValidation lives in 00_Types.mqh (needed by PositionEvolution before Mission)

UltraMissionState g_UltraMissionLast;
UltraPosLock      g_UltraPosLock[ULTRA_POSLOCK_MAX];
int               g_UltraPosLockN = 0;
datetime          g_UltraMissionCycleBar = 0;
bool              g_UltraMissionClosedThisCycle = false;
bool              g_UltraMissionOpenedThisCycle = false;
// Sticky entry approval — survives PositionCommand overwriting g_UltraMissionLast
bool              g_UltraMissionEntryOK = false;
bool              g_UltraMissionEntryBuy = false;
string            g_UltraMissionEntryTag = "";
datetime          g_UltraMissionEntryTs = 0;

// PHASE A — Mission already issued final BUY/SELL (post-Mission gates must not flip)
bool UltraMission_HasFinalEntry(const bool isBuy)
{
   if(!g_UltraMissionEntryOK) return false;
   if(g_UltraMissionEntryBuy != isBuy) return false;
   if(g_UltraMissionEntryTs > 0 && (TimeCurrent() - g_UltraMissionEntryTs) > 120)
      return false;
   return true;
}

// PHASE A — SOLE decision-level WAIT emitter (BUY/SELL/WAIT surface)
// Soft pre-filters may still abort candidates, but WAIT is recorded only here.
void UltraMission_EmitWait(const string why, const int conf)
{
   // de-dupe same-second identical WAIT (ApproveEntry + EvaluateStrategySignals)
   if(g_UltraMissionLast.command == SUP_WAIT &&
      g_UltraMissionLast.reason == why &&
      g_UltraMissionLast.ts == TimeCurrent())
      return;

   UltraMission_Set(SUP_WAIT, why, conf, conf, "WAIT", "", 0);
   g_UltraMissionEntryOK = false;
   UltraMission_Log("WAIT", 0, why);
   UltraBug_Explain("WAIT", "MissionControl", "UltraMission_EmitWait", why, "-", 0);
}

//--------------------------------------------------------------------//
void UltraMission_Init()
{
   g_UltraMissionLast.command = SUP_WAIT;
   g_UltraMissionLast.reason = "INIT";
   g_UltraMissionLast.confidence = 0;
   g_UltraMissionLast.tradeScore = 0;
   g_UltraMissionLast.grade = "";
   g_UltraMissionLast.thesis = "";
   g_UltraMissionLast.ticket = 0;
   g_UltraMissionLast.ts = 0;
   g_UltraPosLockN = 0;
   g_UltraMissionCycleBar = 0;
   g_UltraMissionClosedThisCycle = false;
   g_UltraMissionOpenedThisCycle = false;
   g_UltraMissionEntryOK = false;
   g_UltraMissionEntryBuy = false;
   g_UltraMissionEntryTag = "";
   g_UltraMissionEntryTs = 0;
}

void UltraMission_NewCycle(const string s)
{
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar != g_UltraMissionCycleBar)
   {
      g_UltraMissionCycleBar = bar;
      g_UltraMissionClosedThisCycle = false;
      g_UltraMissionOpenedThisCycle = false;
      for(int i = 0; i < g_UltraPosLockN; i++)
         g_UltraPosLock[i].decidedThisCycle = false;
   }
}

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

void UltraMission_Log(const string action, const ulong ticket, const string why)
{
   string t = "MISSION ";
   t += action;
   t += " ticket=";
   t += IntegerToString((int)ticket);
   t += " | ";
   t += why;
   UltraLogTrade(t);
   // ROADMAP P20 — structured fields
   string side = "-";
   if(action == "OPEN" || action == "BUY") side = "BUY";
   else if(action == "SELL") side = "SELL";
   else if(ticket > 0 && PositionSelectByTicket(ticket))
      side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   UltraLogDecisionFromSnap(action, ticket, side, g_UltraMissionLast.grade,
                            g_UltraLastSnap, why);
   if(UltraUpgradeLog || EnableVerboseLogging)
      Print(t);
}

//--------------------------------------------------------------------//
// POSITION LOCK — one thesis / hold status per ticket
//--------------------------------------------------------------------//
int UltraPosLock_Find(const ulong ticket)
{
   for(int i = 0; i < g_UltraPosLockN; i++)
      if(g_UltraPosLock[i].active && g_UltraPosLock[i].ticket == ticket) return i;
   return -1;
}

int UltraPosLock_Alloc()
{
   for(int i = 0; i < g_UltraPosLockN; i++)
      if(!g_UltraPosLock[i].active) return i;
   if(g_UltraPosLockN >= ULTRA_POSLOCK_MAX) return 0;
   return g_UltraPosLockN++;
}

void UltraPosLock_Register(const ulong ticket, const string s, const bool isBuy, const string tag)
{
   if(ticket == 0) return;
   int idx = UltraPosLock_Find(ticket);
   if(idx < 0) idx = UltraPosLock_Alloc();
   g_UltraPosLock[idx].ticket = ticket;
   g_UltraPosLock[idx].symbol = s;
   g_UltraPosLock[idx].isBuy = isBuy;
   g_UltraPosLock[idx].active = true;
   g_UltraPosLock[idx].status = "HOLD";
   g_UltraPosLock[idx].holdScore = 0;
   g_UltraPosLock[idx].thesisTag = tag;
   g_UltraPosLock[idx].openTime = TimeCurrent();
   g_UltraPosLock[idx].lastEvalBar = 0;
   g_UltraPosLock[idx].decidedThisCycle = false;
   UltraMission_Log("LOCK", ticket, tag);
}

void UltraPosLock_Clear(const ulong ticket)
{
   int idx = UltraPosLock_Find(ticket);
   if(idx < 0) return;
   g_UltraPosLock[idx].active = false;
   g_UltraPosLock[idx].status = "CLOSED";
}

void UltraPosLock_Update(const ulong ticket, const string status, const int holdScore)
{
   int idx = UltraPosLock_Find(ticket);
   if(idx < 0) return;
   g_UltraPosLock[idx].status = status;
   g_UltraPosLock[idx].holdScore = holdScore;
}

//--------------------------------------------------------------------//
// EXIT VALIDATION ENGINE — multi-confirm before close
//--------------------------------------------------------------------//
UltraExitValidation UltraMission_ValidateExit(const ulong ticket, const string s,
                                              const bool isBuy, const UltraSnap &u,
                                              const bool riskForced)
{
   UltraExitValidation v;
   v.thesisBroken = false;
   v.structureChanged = false;
   v.masterTrendChanged = false;
   v.riskRule = riskForced;
   v.healthyCorrection = false;
   v.trueReversal = false;
   v.allowClose = false;
   v.reason = "";

   string tw = "";
   bool thesisOK = UltraThesis_Revalidate(ticket, u, tw);
   v.thesisBroken = !thesisOK;

   UltraCorrection corr = UltraCorr_Detect(u, isBuy);
   v.healthyCorrection = corr.isHealthy &&
      (corr.state == CORR_PULLBACK || corr.state == CORR_CONTINUATION ||
       corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST || corr.state == CORR_UNKNOWN);
   v.trueReversal = (corr.state == CORR_REVERSAL);

   // Structure changed against position
   v.structureChanged = isBuy
      ? ((u.bos.sell && u.bos.confirmed && u.bos.strong) || (u.choch.sell && u.choch.majorC) || u.st.externalBear)
      : ((u.bos.buy && u.bos.confirmed && u.bos.strong) || (u.choch.buy && u.choch.majorC) || u.st.externalBull);

   // Master trend changed (H4 bias)
   int master = UltraMTF_MasterDir(s);
   v.masterTrendChanged = isBuy ? (master < 0) : (master > 0);

   // IGNORE noise — healthy correction never allows close
   if(v.healthyCorrection && !v.riskRule)
   {
      v.allowClose = false;
      v.reason = "KEEP HOLDING — healthy correction / market noise";
      return v;
   }

   if(v.riskRule)
   {
      v.allowClose = true;
      v.reason = "RISK RULE requires exit";
      return v;
   }

   // ROADMAP P19 — Exit ONLY if:
   //   thesis invalidated OR risk (handled) OR confirmed structural invalidation
   // Never exit on one candle / one indicator / temp spread / temp vol / news alone.

   // Confirmed structural invalidation (BOS/CHoCH + reversal + master flip)
   if(v.structureChanged && v.trueReversal && v.masterTrendChanged)
   {
      v.allowClose = true;
      v.reason = "EXIT CONFIRMED — structural invalidation + reversal + master";
      return v;
   }

   // Thesis invalidated with structure or master confirmation
   if(v.thesisBroken && v.structureChanged && (v.trueReversal || v.masterTrendChanged))
   {
      v.allowClose = true;
      v.reason = "EXIT CONFIRMED — thesis invalid + structure confirm";
      return v;
   }

   if(v.thesisBroken && v.trueReversal && v.masterTrendChanged)
   {
      v.allowClose = true;
      v.reason = "EXIT CONFIRMED — thesis invalid + master + reversal";
      return v;
   }

   // LEVEL 5 — no soft InstantQuality exit shortcut
   // Soft multi-bar invalidation belongs to PosEvo L3 streak only.

   v.allowClose = false;
   v.reason = "KEEP HOLDING — thesis still valid or noise";
   return v;
}

//--------------------------------------------------------------------//
// SOLE CLOSE AUTHORITY
//--------------------------------------------------------------------//
bool UltraMission_ClosePosition(const ulong ticket, const string whyIn, const bool riskForced)
{
   if(ticket == 0) return false;
   if(!PositionSelectByTicket(ticket)) return false;

   string s = PositionGetString(POSITION_SYMBOL);
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   UltraMission_NewCycle(s);

   // One decision per evaluation — block close→open flip-flop same cycle
   int lk = UltraPosLock_Find(ticket);
   if(lk >= 0 && g_UltraPosLock[lk].decidedThisCycle && !riskForced)
   {
      UltraMission_Log("HOLD", ticket, "one decision per cycle — close blocked");
      return false;
   }

   UltraSnap u = g_UltraLastSnap;
   // Use core snapshot only (UFSE is assembled after Mission Control)
   UltraBuildSnapshot(s, u);

   UltraExitValidation v = UltraMission_ValidateExit(ticket, s, isBuy, u, riskForced);
   // ROADMAP P17 — honor PosEvo L3 multi-bar soft invalidation confirmed for this ticket
   if(!v.allowClose && !riskForced && UltraPosEvoEnabled && UltraPosEvoCloseOnL3 &&
      g_UltraPosEvoLast.allowClose && g_UltraPosEvoLast.command == SUP_EXIT &&
      g_UltraPosEvoL3Ticket == ticket)
   {
      v.allowClose = true;
      if(StringLen(g_UltraPosEvoLast.exitReason) > 0)
         v.reason = g_UltraPosEvoLast.exitReason;
      else
         v.reason = "POSEVO L3 soft invalidation confirmed";
   }
   if(!v.allowClose)
   {
      // LEVEL 5 — structured HOLD audit (why close was denied)
      string holdWhy = v.reason;
      holdWhy += " thesisBroken=";
      holdWhy += (v.thesisBroken ? "Y" : "N");
      holdWhy += " struct=";
      holdWhy += (v.structureChanged ? "Y" : "N");
      holdWhy += " master=";
      holdWhy += (v.masterTrendChanged ? "Y" : "N");
      holdWhy += " reversal=";
      holdWhy += (v.trueReversal ? "Y" : "N");
      UltraMission_Set(SUP_HOLD, holdWhy, u.score.confidence, g_UltraHoldLast.total, "HOLD", "", ticket);
      UltraPosLock_Update(ticket, "HOLD", g_UltraHoldLast.total);
      UltraMission_Log("HOLD", ticket, holdWhy);
      if(lk >= 0) g_UltraPosLock[lk].decidedThisCycle = true;
      return false;
   }

   string why = whyIn;
   if(StringLen(why) == 0) why = v.reason;
   else
   {
      why += " | ";
      why += v.reason;
   }

   UltraMission_Set(SUP_EXIT, why, u.score.confidence, g_UltraHoldLast.total, "EXIT", "", ticket);
   UltraMission_Log("CLOSE", ticket, why);

   bool ok = g_Trade.PositionClose(ticket);
   if(ok)
   {
      g_UltraMissionClosedThisCycle = true;
      UltraThesis_Clear(ticket);
      UltraPosLock_Clear(ticket);
      if(lk >= 0) g_UltraPosLock[lk].decidedThisCycle = true;
   }
   else
   {
      UltraMission_Log("CLOSE_FAIL", ticket, g_Trade.ResultRetcodeDescription());
   }
   return ok;
}

bool UltraMission_ClosePartial(const ulong ticket, const double volume, const string why)
{
   if(ticket == 0 || volume <= 0.0) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   UltraMission_Log("PARTIAL", ticket, why);
   UltraMission_Set(SUP_MANAGE, why, 0, 0, "PARTIAL", "", ticket);
   return g_Trade.PositionClosePartial(ticket, volume);
}

// Mark that an entry filled this cycle (blocks immediate reopen after close)
void UltraMission_NoteOpen(const ulong ticket, const string s, const bool isBuy, const string tag)
{
   UltraMission_NewCycle(s);
   g_UltraMissionOpenedThisCycle = true;
   UltraPosLock_Register(ticket, s, isBuy, tag);
   UltraMission_Log("OPEN", ticket, tag);
   // PHASE 17 — analytics open record (strategy unchanged)
   UltraAdaptive_RecordOpen(ticket, s, isBuy, tag);
}

// Block new entries if we already closed this cycle (anti flip-flop)
// Exception: Position Evolution replace arm may open on a later bar only.
bool UltraMission_AllowNewEntry(const string s)
{
   UltraMission_NewCycle(s);

   // Armed replacement: allow only when next-bar / checklist gate passes
   if(UltraPosEvoEnabled && UltraPosEvoReplaceEnabled && UltraPosEvo_ReplacePending(s))
   {
      string rWhy = "";
      // Direction checked later in UltraAIDecide; here only bar/expiry gate
      if(UltraPosEvo_ReplaceAllowsEntry(s, g_UltraPosEvoReplace.wantBuy, rWhy))
      {
         UltraMission_Log("REPLACE_READY", 0, rWhy);
         return true;
      }
      // Still waiting next bar — block impulsive same-cycle reopen
      if(g_UltraMissionClosedThisCycle)
      {
         UltraMission_Log("WAIT", 0, rWhy);
         return false;
      }
   }

   if(g_UltraMissionClosedThisCycle && !UltraUpgradeStrict)
   {
      UltraMission_Log("WAIT", 0, "one decision per cycle — open blocked after close");
      return false;
   }

   // PERF — one open decision per cycle (REPLACE arm may still reopen)
   if(g_UltraMissionOpenedThisCycle &&
      !(UltraPosEvoEnabled && UltraPosEvoReplaceEnabled && UltraPosEvo_ReplacePending(s)))
   {
      UltraMission_Log("WAIT", 0, "one decision per cycle — already opened");
      return false;
   }
   return true;
}

//--------------------------------------------------------------------//
bool UltraMission_ApproveEntry(const string s, UltraSnap &u, UltraSignal &sig, string &why)
{
   if(!UltraMission_AllowNewEntry(s))
   {
      why = "MISSION: one decision per cycle";
      UltraMission_EmitWait(why, u.score.confidence);
      return false;
   }

   // ULTRA VALIDATION CHAIN — Mission Control receives ONLY validated outputs
   if(UltraVChainEnabled)
   {
      string vWhy = "";
      ENUM_ULTRA_VSTATE vst = UltraVChain_EvaluateForMission(s, u, vWhy);
      if(!UltraVChain_MissionReady())
      {
         why = "VCHAIN ";
         why += UltraV_Name(vst);
         why += ": ";
         why += vWhy;
         UltraMission_EmitWait(why, u.score.confidence);
         return false;
      }
   }

   bool ok = UltraSupreme_FinalizeEntry(s, u, sig, why);
   if(ok)
   {
      ENUM_SUPREME_DECISION c = sig.buy ? SUP_BUY : SUP_SELL;
      // REPLACE is first-class Mission surface when PosEvo arm is live
      bool isReplace = (UltraPosEvoEnabled && UltraPosEvoReplaceEnabled &&
                        UltraPosEvo_ReplacePending(s));
      UltraMission_Set(c, g_UltraSupremeLast.reason, g_UltraSupremeLast.confidence,
                       g_UltraSupremeLast.tradeScore, g_UltraSupremeLast.grade,
                       g_UltraSupremeLast.thesis, 0);
      if(isReplace)
         UltraMission_Log("REPLACE", 0, g_UltraSupremeLast.reason);
      else
         UltraMission_Log(UltraMission_Name(c), 0, g_UltraSupremeLast.reason);
      g_UltraMissionEntryOK = true;
      g_UltraMissionEntryBuy = sig.buy;
      g_UltraMissionEntryTag = sig.tag;
      g_UltraMissionEntryTs = TimeCurrent();
   }
   else
   {
      // PHASE A — sole WAIT authority (Supreme deny → Mission WAIT)
      if(StringLen(why) == 0) why = "MISSION WAIT";
      UltraMission_EmitWait(why, u.score.confidence);
   }
   return ok;
}

// Open-position command — never closes here; Shell must call UltraMission_ClosePosition
// Position Evolution Engine drives L1 HOLD / L2 MANAGE / L3 INVALIDATE.
ENUM_SUPREME_DECISION UltraMission_PositionCommand(const ulong ticket, const string s,
                                                   const bool isBuy, const UltraSnap &u,
                                                   string &why)
{
   why = "";
   UltraMission_NewCycle(s);

   UltraExitValidation v = UltraMission_ValidateExit(ticket, s, isBuy, u, false);
   UltraCorrection corr = UltraCorr_Detect(u, isBuy);
   UltraHoldScore hold = UltraHold_Evaluate(u, isBuy, !v.thesisBroken, corr);
   // PHASE 18 — soft position/exit intelligence (never forces Mission EXIT alone)
   UltraAdaptive_ApplyPositionIntel(ticket, s, isBuy, u, hold);
   UltraSmartExit sx = UltraSmartExit_Decide(hold, corr, !v.thesisBroken, false);

   ENUM_SUPREME_DECISION cmd = SUP_HOLD;

   if(UltraPosEvoEnabled)
   {
      UltraPosEvoDecision evo;
      evo = UltraPosEvo_Evaluate(ticket, s, isBuy, u, v, hold, corr);
      cmd = evo.command;
      why = evo.reason;

      // ROADMAP P17 — L3 EXIT when ValidateExit OR PosEvo multi-bar soft invalidation confirms
      if(cmd == SUP_EXIT)
      {
         if(!UltraPosEvoCloseOnL3 || !(v.allowClose || evo.allowClose))
         {
            cmd = SUP_MANAGE;
            why = "L2 MANAGE — invalidation not fully confirmed for Mission close";
         }
         else if(StringLen(evo.exitReason) > 0)
         {
            why = "EXIT: " + evo.exitReason;
            if(evo.wantReplace)
               why += " | REPLACE armed if checklist passes";
            UltraLogDecisionFromSnap(evo.wantReplace ? "REPLACE" : "EXIT", ticket,
                                     isBuy ? "BUY" : "SELL", "POSEVO", u, why);
            // Phase 19 — structured explain for exit/replace (no silent path)
            UltraBug_Explain(evo.wantReplace ? "REPLACE" : "EXIT",
                             "MissionControl", "UltraMission_PositionCommand", why,
                             isBuy ? "BUY" : "SELL", ticket);
         }
      }
      else if(cmd == SUP_MANAGE && StringLen(why) == 0)
         why = "L2 MANAGE";
      else if(cmd == SUP_HOLD && StringLen(why) == 0)
         why = "L1 HOLD";
   }
   else
   {
      // Legacy SmartExit path when PosEvo disabled
      if(v.allowClose && sx.action == SX_CLOSE)
      {
         cmd = SUP_EXIT;
         why = v.reason;
      }
      else if(v.healthyCorrection || sx.action == SX_BE || sx.action == SX_TIGHTEN || hold.action == HOLD_MANAGE)
      {
         cmd = SUP_MANAGE;
         why = v.healthyCorrection ? "healthy correction — manage/protect" : sx.reason;
         if(StringLen(why) == 0) why = "MANAGE";
      }
      else
      {
         cmd = SUP_HOLD;
         why = "ULTRA HOLD — thesis/structure/trend valid";
      }
   }

   UltraMission_Set(cmd, why, u.score.confidence, hold.total, hold.label, "", ticket);
   UltraPosLock_Update(ticket, UltraMission_Name(cmd), hold.total);
   UltraMission_Log(UltraMission_Name(cmd), ticket, why);
   return cmd;
}

ENUM_SMART_EXIT UltraMission_ToSmartExit(const ENUM_SUPREME_DECISION cmd)
{
   if(cmd == SUP_EXIT) return SX_CLOSE;
   if(cmd == SUP_MANAGE) return SX_BE;
   return SX_NONE;
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
