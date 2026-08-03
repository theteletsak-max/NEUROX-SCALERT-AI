#ifndef HITMAN_ULTRA_POSITION_EVOLUTION_MQH
#define HITMAN_ULTRA_POSITION_EVOLUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 10 · POSITION EVOLUTION ENGINE   |
//| Continuous manage: market · thesis · trend · mom · SL · targets  |
//| L1 HOLD · L2 MANAGE · L3 INVALIDATE (+ optional replace)         |
//| Mission sole close · never widen SL · never unmanaged            |
//+------------------------------------------------------------------+

enum ENUM_POS_EVO_LEVEL
{
   PEVO_HOLD = 1,
   PEVO_MANAGE = 2,
   PEVO_INVALIDATE = 3
};

struct UltraPosEvoDecision
{
   ENUM_POS_EVO_LEVEL level;
   ENUM_SUPREME_DECISION command; // HOLD / MANAGE / EXIT
   string reason;
   string exitReason;
   string replaceReason;
   bool   thesisValid;
   bool   structureValid;
   bool   liquidityOk;
   bool   masterTrendValid;
   bool   confidenceOk;
   bool   healthyNoise;
   bool   trueReversal;
   bool   allowClose;
   bool   wantReplace;
   int    confidence;
   int    holdScore;
   int    l3Streak;
};

struct UltraPosEvoReplace
{
   bool     pending;
   string   symbol;
   bool     wantBuy;          // new direction after invalidation
   string   reason;
   string   exitReason;
   datetime armBar;
   datetime armTime;
   int      minConf;
};

UltraPosEvoDecision g_UltraPosEvoLast;
UltraPosEvoReplace  g_UltraPosEvoReplace;
int                 g_UltraPosEvoL3Streak = 0;
datetime            g_UltraPosEvoL3Bar = 0;
ulong               g_UltraPosEvoL3Ticket = 0;

// Chapter 10 facade (definitions below)
void UltraPosEvoIntel_Boot();
void UltraPosEvoIntel_SyncFromDecision(const UltraPosEvoDecision &d);
void UltraPosEvoIntel_Log(const string verb);
string UltraPosEvoIntel_Dashboard();
UltraPosEvoDecision UltraPosEvo_Finish(const UltraPosEvoDecision &d);

//--------------------------------------------------------------------//
void UltraPosEvo_Init()
{
   g_UltraPosEvoLast.level = PEVO_HOLD;
   g_UltraPosEvoLast.command = SUP_HOLD;
   g_UltraPosEvoLast.reason = "INIT";
   g_UltraPosEvoLast.exitReason = "";
   g_UltraPosEvoLast.replaceReason = "";
   g_UltraPosEvoLast.thesisValid = true;
   g_UltraPosEvoLast.structureValid = true;
   g_UltraPosEvoLast.liquidityOk = true;
   g_UltraPosEvoLast.masterTrendValid = true;
   g_UltraPosEvoLast.confidenceOk = true;
   g_UltraPosEvoLast.healthyNoise = false;
   g_UltraPosEvoLast.trueReversal = false;
   g_UltraPosEvoLast.allowClose = false;
   g_UltraPosEvoLast.wantReplace = false;
   g_UltraPosEvoLast.confidence = 0;
   g_UltraPosEvoLast.holdScore = 0;
   g_UltraPosEvoLast.l3Streak = 0;

   g_UltraPosEvoReplace.pending = false;
   g_UltraPosEvoReplace.symbol = "";
   g_UltraPosEvoReplace.wantBuy = false;
   g_UltraPosEvoReplace.reason = "";
   g_UltraPosEvoReplace.exitReason = "";
   g_UltraPosEvoReplace.armBar = 0;
   g_UltraPosEvoReplace.armTime = 0;
   g_UltraPosEvoReplace.minConf = 0;

   g_UltraPosEvoL3Streak = 0;
   g_UltraPosEvoL3Bar = 0;
   g_UltraPosEvoL3Ticket = 0;
   UltraPosEvoIntel_Boot();
}

string UltraPosEvo_LevelName(const ENUM_POS_EVO_LEVEL lv)
{
   if(lv == PEVO_HOLD) return "L1 HOLD";
   if(lv == PEVO_MANAGE) return "L2 MANAGE";
   return "L3 INVALIDATE";
}

void UltraPosEvo_ClearReplace()
{
   g_UltraPosEvoReplace.pending = false;
   g_UltraPosEvoReplace.symbol = "";
   g_UltraPosEvoReplace.wantBuy = false;
   g_UltraPosEvoReplace.reason = "";
   g_UltraPosEvoReplace.exitReason = "";
   g_UltraPosEvoReplace.armBar = 0;
   g_UltraPosEvoReplace.armTime = 0;
   g_UltraPosEvoReplace.minConf = 0;
}

bool UltraPosEvo_ReplacePending(const string s)
{
   if(!g_UltraPosEvoReplace.pending) return false;
   if(StringLen(s) > 0 && g_UltraPosEvoReplace.symbol != s) return false;
   return true;
}

bool UltraPosEvo_ReplaceAllowsEntry(const string s, const bool wantBuy, string &why)
{
   why = "";
   if(!UltraPosEvoEnabled || !UltraPosEvoReplaceEnabled) return false;
   if(!UltraPosEvo_ReplacePending(s)) return false;
   if(g_UltraPosEvoReplace.wantBuy != wantBuy)
   {
      why = "REPLACE: direction mismatch";
      return false;
   }

   datetime bar = iTime(s, UltraETF(), 0);
   if(UltraPosEvoReplaceNextBarOnly)
   {
      if(bar <= 0 || g_UltraPosEvoReplace.armBar <= 0 || bar <= g_UltraPosEvoReplace.armBar)
      {
         why = "REPLACE: wait next bar (anti-whipsaw)";
         return false;
      }
   }

   // Expire stale replace arms
   int maxAge = UltraPosEvoReplaceMaxBars;
   if(maxAge < 1) maxAge = 1;
   if(bar > 0 && g_UltraPosEvoReplace.armBar > 0)
   {
      // approximate age: if arm was N bars ago beyond max → expire
      // use time delta as robust fallback
      int ageSec = (int)(TimeCurrent() - g_UltraPosEvoReplace.armTime);
      int barSec = PeriodSeconds(UltraETF());
      if(barSec <= 0) barSec = 60;
      int ageBars = ageSec / barSec;
      if(ageBars > maxAge)
      {
         UltraPosEvo_ClearReplace();
         why = "REPLACE: arm expired";
         return false;
      }
   }

   why = g_UltraPosEvoReplace.reason;
   return true;
}

//--------------------------------------------------------------------//
// Structure / liquidity / master / confidence helpers
//--------------------------------------------------------------------//
bool UltraPosEvo_StructureValid(const UltraSnap &u, const bool isBuy)
{
   // Valid if structure still supports position (not strongly against)
   bool against = isBuy
      ? ((u.bos.sell && u.bos.confirmed && u.bos.strong) || (u.choch.sell && u.choch.majorC) || u.st.externalBear)
      : ((u.bos.buy && u.bos.confirmed && u.bos.strong) || (u.choch.buy && u.choch.majorC) || u.st.externalBull);
   if(against) return false;

   bool with = isBuy
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation || u.bos.buy || u.choch.buy)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation || u.bos.sell || u.choch.sell);
   return with || !against;
}

bool UltraPosEvo_LiquidityHostile(const UltraSnap &u, const bool isBuy)
{
   // Major adverse sweep/hunt against us — soft unless combined with structure death
   return isBuy
      ? (u.liq.sweepSell && u.liq.stopHuntSell)
      : (u.liq.sweepBuy && u.liq.stopHuntBuy);
}

bool UltraPosEvo_MasterValid(const string s, const bool isBuy)
{
   int master = UltraMTF_MasterDir(s);
   if(master == 0) return true; // flat = do not invalidate alone
   return isBuy ? (master > 0) : (master < 0);
}

bool UltraPosEvo_TempNoise(const UltraSnap &u, const UltraCorrection &corr)
{
   if(corr.isHealthy &&
      (corr.state == CORR_PULLBACK || corr.state == CORR_CONTINUATION ||
       corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST || corr.state == CORR_UNKNOWN))
      return true;
   if(u.vol.compression) return true; // temporary compression ≠ invalidation
   return false;
}

//--------------------------------------------------------------------//
// Replacement checklist (opposite setup must fully validate)
//--------------------------------------------------------------------//
bool UltraPosEvo_ReplacementChecklist(const string s, const UltraSnap &u, const bool wantBuy,
                                      string &detail, int &confOut)
{
   detail = "";
   confOut = u.score.confidence;

   int floor = UltraPosEvoReplaceMinConf;
   if(floor < UltraFireFloor()) floor = UltraFireFloor();
   if(u.score.confidence < floor)
   {
      detail = "confidence below replace floor";
      return false;
   }
   if(u.score.precision < UltraMinPrecision && u.score.confidence < floor)
   {
      detail = "precision weak for replace";
      return false;
   }
   if(u.score.probability < UltraMinProbability && u.score.confidence < floor)
   {
      detail = "probability weak for replace";
      return false;
   }

   int master = UltraMTF_MasterDir(s);
   if(master != 0)
   {
      if(wantBuy && master < 0){ detail = "master trend against BUY replace"; return false; }
      if(!wantBuy && master > 0){ detail = "master trend against SELL replace"; return false; }
   }

   bool structure = wantBuy
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   bool bos = wantBuy ? (u.bos.buy || (u.bos.buy && u.bos.confirmed)) : (u.bos.sell || (u.bos.sell && u.bos.confirmed));
   bool choch = wantBuy ? u.choch.buy : u.choch.sell;
   bool liq = wantBuy
      ? (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.grabBuy || u.liq.equalLows)
      : (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.grabSell || u.liq.equalHighs);
   bool zone = wantBuy
      ? (u.ict.obBuy || u.ict.fvgBuy || u.fib.atBuyZone || u.ict.institutionalLiqBuy)
      : (u.ict.obSell || u.ict.fvgSell || u.fib.atSellZone || u.ict.institutionalLiqSell);
   bool mom = wantBuy
      ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
      : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);

   int hits = (structure?1:0) + ((bos||choch)?1:0) + (liq?1:0) + (zone?1:0) + (mom?1:0);
   int need = UltraPosEvoReplaceMinHits;
   if(need < 3) need = 3;
   if(hits < need)
   {
      detail = StringFormat("replace stack %d/%d (need structure/BOS-CHoCH/liq/zone/mom)", hits, need);
      return false;
   }

   // Risk / exec readiness (lightweight — full path still runs UltraAIDecide)
   if(u.score.riskProb >= 85)
   {
      detail = "risk too high for replace";
      return false;
   }
   string exWhy = "";
   if(!UltraExecReady(s, exWhy))
   {
      detail = "exec: " + exWhy;
      return false;
   }

   detail = StringFormat("replace OK hits=%d conf=%d master=%d", hits, u.score.confidence, master);
   return true;
}

bool UltraPosEvo_TryArmReplace(const string s, const bool wasBuy, const UltraSnap &u,
                               const string exitReason)
{
   if(!UltraPosEvoEnabled || !UltraPosEvoReplaceEnabled)
      return false;

   // ROADMAP P17 — force opposite of closed trade; never re-arm same side
   bool wantBuy = !wasBuy;
   UltraSignal cand = UltraPickBest(u);
   if(cand.buy || cand.sell)
   {
      // Reject if best signal is still the closed direction
      if(wantBuy && cand.sell && !cand.buy) return false;
      if(!wantBuy && cand.buy && !cand.sell) return false;
      // Keep forced opposite — do not let PickBest flip wantBuy back
   }

   string detail = "";
   int conf = 0;
   if(!UltraPosEvo_ReplacementChecklist(s, u, wantBuy, detail, conf))
   {
      if(UltraUpgradeLog || EnableVerboseLogging)
         Print("POSEVO REPLACE WAIT: ", detail, " on ", s, " | exit=", exitReason);
      UltraPosEvo_ClearReplace();
      return false;
   }

   g_UltraPosEvoReplace.pending = true;
   g_UltraPosEvoReplace.symbol = s;
   g_UltraPosEvoReplace.wantBuy = wantBuy;
   g_UltraPosEvoReplace.exitReason = exitReason;
   g_UltraPosEvoReplace.reason = StringFormat("REPLACE after invalidation → %s | %s",
                                             (wantBuy ? "BUY" : "SELL"), detail);
   g_UltraPosEvoReplace.armBar = iTime(s, UltraETF(), 0);
   g_UltraPosEvoReplace.armTime = TimeCurrent();
   g_UltraPosEvoReplace.minConf = UltraPosEvoReplaceMinConf;
   // UFSE unlock is performed by Shell after assemble (UFSE lives after Mission)

   UltraLogTrade("POSEVO " + g_UltraPosEvoReplace.reason);
   if(UltraUpgradeLog || EnableVerboseLogging)
      Print("POSEVO ARM REPLACE: ", g_UltraPosEvoReplace.reason, " on ", s);
   return true;
}

void UltraPosEvo_NoteReplacementFilled(const string s, const bool isBuy, const string tag)
{
   if(!UltraPosEvo_ReplacePending(s)) return;
   string msg = "REPLACEMENT FILLED ";
   msg += (isBuy ? "BUY" : "SELL");
   msg += " [";
   msg += tag;
   msg += "] | ";
   msg += g_UltraPosEvoReplace.reason;
   msg += " | prior exit: ";
   msg += g_UltraPosEvoReplace.exitReason;
   UltraLogTrade(msg);
   if(UltraUpgradeLog || EnableVerboseLogging)
      Print("POSEVO ", msg, " on ", s);
   UltraPosEvo_ClearReplace();
}

//--------------------------------------------------------------------//
// CORE EVALUATE — Market → Thesis → Structure → Liq → Master → AI
//--------------------------------------------------------------------//
UltraPosEvoDecision UltraPosEvo_Evaluate(const ulong ticket, const string s, const bool isBuy,
                                         const UltraSnap &u, const UltraExitValidation &v,
                                         const UltraHoldScore &hold, const UltraCorrection &corr)
{
   UltraPosEvoDecision d;
   d.level = PEVO_HOLD;
   d.command = SUP_HOLD;
   d.reason = "";
   d.exitReason = "";
   d.replaceReason = "";
   d.thesisValid = !v.thesisBroken;
   d.structureValid = !v.structureChanged && UltraPosEvo_StructureValid(u, isBuy);
   d.liquidityOk = !UltraPosEvo_LiquidityHostile(u, isBuy);
   d.masterTrendValid = UltraPosEvo_MasterValid(s, isBuy) && !v.masterTrendChanged;
   d.confidenceOk = (u.score.confidence >= UltraPosEvoMinHoldConf) || (hold.total >= 50);
   d.healthyNoise = UltraPosEvo_TempNoise(u, corr) || v.healthyCorrection;
   d.trueReversal = v.trueReversal || (corr.state == CORR_REVERSAL);
   d.allowClose = false;
   d.wantReplace = false;
   d.confidence = u.score.confidence;
   d.holdScore = hold.total;
   d.l3Streak = 0;

   if(!UltraUpgradeEnabled || !UltraPosEvoEnabled)
   {
      d.level = PEVO_HOLD;
      d.command = SUP_HOLD;
      d.reason = "PosEvo off — defer";
      return UltraPosEvo_Finish(d);
   }

   //======== ANTI-WHIPSAW: never invalidate on noise ========//
   // Never reverse because of one candle / indicator flip / small correction /
   // temp volatility / temp spread / minor liquidity sweep alone.
   if(d.healthyNoise && !v.riskRule)
   {
      d.level = (hold.action == HOLD_MANAGE || !d.confidenceOk) ? PEVO_MANAGE : PEVO_HOLD;
      d.command = (d.level == PEVO_MANAGE) ? SUP_MANAGE : SUP_HOLD;
      d.reason = (d.level == PEVO_MANAGE)
         ? "L2 MANAGE — healthy pullback / temporary noise"
         : "L1 HOLD — thesis valid through healthy correction";
      // reset L3 streak on healthy noise
      if(g_UltraPosEvoL3Ticket == ticket)
      {
         g_UltraPosEvoL3Streak = 0;
         g_UltraPosEvoL3Bar = 0;
      }
      return UltraPosEvo_Finish(d);
   }

   //======== LEVEL 3 candidate: multi-confirm invalidation ========//
   bool hardInvalid = v.allowClose; // Mission ValidateExit already multi-confirms
   // LEVEL 4 — soft invalidation requires structure break + master soften + reversal
   bool softInvalid = (!d.thesisValid && !d.structureValid && d.trueReversal &&
                       (v.masterTrendChanged || !d.masterTrendValid));

   if(hardInvalid || softInvalid)
   {
      datetime bar = iTime(s, UltraETF(), 0);
      if(g_UltraPosEvoL3Ticket != ticket)
      {
         g_UltraPosEvoL3Ticket = ticket;
         g_UltraPosEvoL3Streak = 0;
         g_UltraPosEvoL3Bar = 0;
      }
      if(bar > 0 && bar != g_UltraPosEvoL3Bar)
      {
         g_UltraPosEvoL3Streak++;
         g_UltraPosEvoL3Bar = bar;
      }
      else if(g_UltraPosEvoL3Streak == 0)
         g_UltraPosEvoL3Streak = 1;

      d.l3Streak = g_UltraPosEvoL3Streak;
      int need = UltraPosEvoL3ConfirmBars;
      if(need < 1) need = 1;

      // ROADMAP P17 — softInvalid may escalate after confirm bars (rebuild → replace)
      if(d.l3Streak >= need && (hardInvalid || softInvalid))
      {
         d.level = PEVO_INVALIDATE;
         d.command = SUP_EXIT;
         d.allowClose = true;
         d.exitReason = v.reason;
         if(StringLen(d.exitReason) == 0)
            d.exitReason = softInvalid
               ? "soft invalidation confirmed across bars"
               : "thesis+structure+reversal confirmed";
         d.reason = "L3 INVALIDATION — " + d.exitReason;
         d.wantReplace = UltraPosEvoReplaceEnabled;
         if(d.wantReplace)
            d.replaceReason = "rebuild analysis → score → Mission REPLACE opposite";
         return UltraPosEvo_Finish(d);
      }

      // Not enough confirm bars — manage, do not panic close
      d.level = PEVO_MANAGE;
      d.command = SUP_MANAGE;
      d.reason = StringFormat("L2 MANAGE — invalidation forming %d/%d bars (anti-whipsaw)",
                              d.l3Streak, need);
      return UltraPosEvo_Finish(d);
   }

   // Reset streak when not invalidating
   if(g_UltraPosEvoL3Ticket == ticket)
   {
      g_UltraPosEvoL3Streak = 0;
      g_UltraPosEvoL3Bar = 0;
   }

   //======== LEVEL 2: manage / protect ========//
   bool manage = (!d.confidenceOk) || (!d.liquidityOk && d.thesisValid) ||
                 (hold.action == HOLD_MANAGE) || (!d.masterTrendValid && d.thesisValid) ||
                 (u.vol.expansion && hold.total < 60);

   if(manage)
   {
      d.level = PEVO_MANAGE;
      d.command = SUP_MANAGE;
      d.reason = "L2 MANAGE — protect through pullback/volatility (thesis still alive)";
      if(!d.masterTrendValid) d.reason = "L2 MANAGE — master softening, protect profit";
      if(!d.confidenceOk) d.reason = "L2 MANAGE — confidence soft, hold with protection";
      return UltraPosEvo_Finish(d);
   }

   //======== LEVEL 1: keep holding ========//
   d.level = PEVO_HOLD;
   d.command = SUP_HOLD;
   d.reason = "L1 HOLD — thesis/structure/trend/confidence maintained";
   if(d.thesisValid && d.structureValid && d.masterTrendValid && d.confidenceOk)
      d.reason = "L1 HOLD — highest-probability path still intact";
   return UltraPosEvo_Finish(d);
}

string UltraPosEvo_Dashboard()
{
   return UltraPosEvoIntel_Dashboard();
}

UltraPosEvoDecision UltraPosEvo_Finish(const UltraPosEvoDecision &d)
{
   g_UltraPosEvoLast = d;
   UltraPosEvoIntel_SyncFromDecision(d);
   return d;
}

//====================================================================//
// CHAPTER 10 FACADE — UltraPosEvoIntel_* (one engine · Mission close) //
//====================================================================//
enum ENUM_ULTRA_POSEVO_OUT
{
   UPOSEVO_CONTINUE = 0,
   UPOSEVO_MODIFY_SL,
   UPOSEVO_MODIFY_TARGETS,
   UPOSEVO_PROTECT_PROFIT,
   UPOSEVO_PREPARE_EXIT
};

struct UltraPosEvoIntelState
{
   bool   booted;
   ENUM_POS_EVO_LEVEL level;
   ENUM_SUPREME_DECISION command;
   ENUM_ULTRA_POSEVO_OUT output;
   string outputName;
   string levelName;
   string detail;
   string symbol;
   ulong  ticket;
   bool   isBuy;
   bool   thesisValid;
   bool   trendValid;
   bool   momentumOk;
   bool   liquidityOk;
   bool   structureValid;
   bool   newsMode;
   bool   continuePos;
   bool   modifySL;
   bool   modifyTargets;
   bool   protectProfit;
   bool   prepareExit;
   int    confidence;
   int    holdScore;
   int    quality;             // 0..100 position quality
   int    l3Streak;
   ulong  cycleCount;
   ulong  exitPrepCount;
   long   lastMs;
};

UltraPosEvoIntelState g_UltraPosEvoIntel;

string UltraPosEvoIntel_OutputName(const ENUM_ULTRA_POSEVO_OUT o)
{
   switch(o)
   {
      case UPOSEVO_MODIFY_SL:       return "MODIFY_STOP_LOSS";
      case UPOSEVO_MODIFY_TARGETS:  return "MODIFY_TARGETS";
      case UPOSEVO_PROTECT_PROFIT:  return "PROTECT_PROFIT";
      case UPOSEVO_PREPARE_EXIT:    return "PREPARE_EXIT";
      default:                      return "CONTINUE_POSITION";
   }
}

void UltraPosEvoIntel_Boot()
{
   g_UltraPosEvoIntel.booted = true;
   g_UltraPosEvoIntel.level = PEVO_HOLD;
   g_UltraPosEvoIntel.command = SUP_HOLD;
   g_UltraPosEvoIntel.output = UPOSEVO_CONTINUE;
   g_UltraPosEvoIntel.outputName = "CONTINUE_POSITION";
   g_UltraPosEvoIntel.levelName = "L1 HOLD";
   g_UltraPosEvoIntel.detail = "boot — continuous manage · Mission sole close";
   g_UltraPosEvoIntel.symbol = "";
   g_UltraPosEvoIntel.ticket = 0;
   g_UltraPosEvoIntel.isBuy = true;
   g_UltraPosEvoIntel.thesisValid = true;
   g_UltraPosEvoIntel.trendValid = true;
   g_UltraPosEvoIntel.momentumOk = true;
   g_UltraPosEvoIntel.liquidityOk = true;
   g_UltraPosEvoIntel.structureValid = true;
   g_UltraPosEvoIntel.newsMode = false;
   g_UltraPosEvoIntel.continuePos = true;
   g_UltraPosEvoIntel.modifySL = false;
   g_UltraPosEvoIntel.modifyTargets = false;
   g_UltraPosEvoIntel.protectProfit = false;
   g_UltraPosEvoIntel.prepareExit = false;
   g_UltraPosEvoIntel.confidence = 0;
   g_UltraPosEvoIntel.holdScore = 0;
   g_UltraPosEvoIntel.quality = 50;
   g_UltraPosEvoIntel.l3Streak = 0;
   g_UltraPosEvoIntel.cycleCount = 0;
   g_UltraPosEvoIntel.exitPrepCount = 0;
   g_UltraPosEvoIntel.lastMs = 0;
}

void UltraPosEvoIntel_Log(const string verb)
{
   string line = "POSEVO_INTEL ";
   line += verb;
   line += " ";
   line += g_UltraPosEvoIntel.outputName;
   line += " ";
   line += g_UltraPosEvoIntel.levelName;
   line += " Q=";
   line += IntegerToString(g_UltraPosEvoIntel.quality);
   line += " conf=";
   line += IntegerToString(g_UltraPosEvoIntel.confidence);
   line += " ticket=";
   line += IntegerToString((int)g_UltraPosEvoIntel.ticket);
   line += " | ";
   line += g_UltraPosEvoIntel.detail;
   UltraLog(line);
}

void UltraPosEvoIntel_SyncFromDecision(const UltraPosEvoDecision &d)
{
   g_UltraPosEvoIntel.level = d.level;
   g_UltraPosEvoIntel.command = d.command;
   g_UltraPosEvoIntel.levelName = UltraPosEvo_LevelName(d.level);
   g_UltraPosEvoIntel.thesisValid = d.thesisValid;
   g_UltraPosEvoIntel.trendValid = d.masterTrendValid;
   g_UltraPosEvoIntel.liquidityOk = d.liquidityOk;
   g_UltraPosEvoIntel.structureValid = d.structureValid;
   g_UltraPosEvoIntel.confidence = d.confidence;
   g_UltraPosEvoIntel.holdScore = d.holdScore;
   g_UltraPosEvoIntel.l3Streak = d.l3Streak;
   g_UltraPosEvoIntel.detail = d.reason;
   g_UltraPosEvoIntel.lastMs = (long)GetTickCount();

   // Primary output from thesis/command (cycle publish may refine)
   g_UltraPosEvoIntel.continuePos = (d.command == SUP_HOLD);
   g_UltraPosEvoIntel.prepareExit = (d.command == SUP_EXIT || d.allowClose);
   g_UltraPosEvoIntel.modifySL = (d.command == SUP_MANAGE);
   g_UltraPosEvoIntel.protectProfit = (d.command == SUP_MANAGE && d.thesisValid);
   g_UltraPosEvoIntel.modifyTargets = false;

   if(g_UltraPosEvoIntel.prepareExit)
      g_UltraPosEvoIntel.output = UPOSEVO_PREPARE_EXIT;
   else if(g_UltraPosEvoIntel.protectProfit)
      g_UltraPosEvoIntel.output = UPOSEVO_PROTECT_PROFIT;
   else if(g_UltraPosEvoIntel.modifySL)
      g_UltraPosEvoIntel.output = UPOSEVO_MODIFY_SL;
   else
      g_UltraPosEvoIntel.output = UPOSEVO_CONTINUE;
   g_UltraPosEvoIntel.outputName = UltraPosEvoIntel_OutputName(g_UltraPosEvoIntel.output);

   // Position quality 0..100
   int q = 40;
   if(d.thesisValid) q += 15;
   if(d.structureValid) q += 10;
   if(d.masterTrendValid) q += 10;
   if(d.liquidityOk) q += 5;
   if(d.confidenceOk) q += 10;
   if(d.holdScore >= 60) q += 10;
   if(d.healthyNoise) q -= 5;
   if(d.trueReversal) q -= 20;
   if(d.command == SUP_EXIT) q = MathMin(q, 25);
   if(q < 0) q = 0;
   if(q > 100) q = 100;
   g_UltraPosEvoIntel.quality = q;
}

// Publish after StopEvo + TargetIntel in ManageOpenTrades (params avoid assemble-order deps)
void UltraPosEvoIntel_PublishCycle(const ulong ticket, const string s, const bool isBuy,
                                   const ENUM_SUPREME_DECISION cmd,
                                   const bool stopEvoModified,
                                   const bool targetProtectReady,
                                   const bool targetAdjustAdvisory,
                                   const bool newsMode,
                                   const UltraSnap &u)
{
   g_UltraPosEvoIntel.ticket = ticket;
   g_UltraPosEvoIntel.symbol = s;
   g_UltraPosEvoIntel.isBuy = isBuy;
   g_UltraPosEvoIntel.newsMode = newsMode;
   g_UltraPosEvoIntel.cycleCount++;
   g_UltraPosEvoIntel.command = cmd;
   g_UltraPosEvoIntel.momentumOk = isBuy ? (u.mom.momBuy || u.mom.impulse || !u.mom.momSell)
                                         : (u.mom.momSell || u.mom.impulse || !u.mom.momBuy);
   if(u.trend.bull || u.trend.bear)
      g_UltraPosEvoIntel.trendValid = isBuy ? u.trend.bull : u.trend.bear;

   // News alone never forces exit (Chapter 10 §9)
   if(newsMode && cmd != SUP_EXIT)
      g_UltraPosEvoIntel.detail = g_UltraPosEvoLast.reason + " | news monitor (no force exit)";

   g_UltraPosEvoIntel.modifySL = stopEvoModified || (cmd == SUP_MANAGE);
   g_UltraPosEvoIntel.protectProfit = targetProtectReady ||
                                      (cmd == SUP_MANAGE && g_UltraPosEvoLast.thesisValid);
   g_UltraPosEvoIntel.modifyTargets = targetAdjustAdvisory;
   g_UltraPosEvoIntel.prepareExit = (cmd == SUP_EXIT);
   g_UltraPosEvoIntel.continuePos = (cmd == SUP_HOLD || cmd == SUP_MANAGE);

   if(g_UltraPosEvoIntel.prepareExit)
   {
      g_UltraPosEvoIntel.output = UPOSEVO_PREPARE_EXIT;
      g_UltraPosEvoIntel.exitPrepCount++;
   }
   else if(g_UltraPosEvoIntel.modifyTargets && !g_UltraPosEvoIntel.protectProfit)
      g_UltraPosEvoIntel.output = UPOSEVO_MODIFY_TARGETS;
   else if(g_UltraPosEvoIntel.protectProfit)
      g_UltraPosEvoIntel.output = UPOSEVO_PROTECT_PROFIT;
   else if(g_UltraPosEvoIntel.modifySL)
      g_UltraPosEvoIntel.output = UPOSEVO_MODIFY_SL;
   else
      g_UltraPosEvoIntel.output = UPOSEVO_CONTINUE;
   g_UltraPosEvoIntel.outputName = UltraPosEvoIntel_OutputName(g_UltraPosEvoIntel.output);
   g_UltraPosEvoIntel.lastMs = (long)GetTickCount();

   if(UltraUpgradeLog && (g_UltraPosEvoIntel.prepareExit || stopEvoModified || targetAdjustAdvisory))
      UltraPosEvoIntel_Log("CYCLE");
}

string UltraPosEvoIntel_Dashboard()
{
   string t = "POSEVO: ";
   if(!g_UltraPosEvoIntel.booted) { t += "INIT"; return t; }
   t += g_UltraPosEvoIntel.levelName;
   t += " → ";
   t += g_UltraPosEvoIntel.outputName;
   t += " Q=";
   t += IntegerToString(g_UltraPosEvoIntel.quality);
   if(StringLen(g_UltraPosEvoLast.reason) > 0)
   {
      t += " ";
      t += g_UltraPosEvoLast.reason;
   }
   if(g_UltraPosEvoReplace.pending)
   {
      t += " | REPLACE→";
      t += (g_UltraPosEvoReplace.wantBuy ? "BUY" : "SELL");
   }
   if(g_UltraPosEvoIntel.newsMode)
      t += " | NEWS";
   return t;
}

#endif // HITMAN_ULTRA_POSITION_EVOLUTION_MQH
