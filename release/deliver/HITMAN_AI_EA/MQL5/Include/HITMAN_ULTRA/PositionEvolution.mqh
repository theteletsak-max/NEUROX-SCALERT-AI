#ifndef HITMAN_ULTRA_POSITION_EVOLUTION_MQH
#define HITMAN_ULTRA_POSITION_EVOLUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — INTELLIGENT POSITION EVOLUTION ENGINE                |
//| Evolve with the market — never panic, never random reverse       |
//| L1 KEEP HOLDING · L2 MANAGE · L3 INVALIDATION (+ optional replace)|
//| Decision authority remains Mission Control only                  |
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

   bool wantBuy = !wasBuy; // reverse direction candidate
   UltraSignal cand = UltraPickBest(u);
   // Prefer opposite of closed trade; if pickBest agrees, use it; else force direction check
   if(cand.buy || cand.sell)
   {
      if(wantBuy && !cand.buy) { /* keep wantBuy — checklist may still fail */ }
      if(!wantBuy && !cand.sell) { }
      // Align with best signal if it is opposite
      if(wantBuy && cand.sell && !cand.buy) return false;
      if(!wantBuy && cand.buy && !cand.sell) return false;
      if(cand.buy) wantBuy = true;
      if(cand.sell) wantBuy = false;
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
      g_UltraPosEvoLast = d;
      return d;
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
      g_UltraPosEvoLast = d;
      return d;
   }

   //======== LEVEL 3 candidate: multi-confirm invalidation ========//
   bool hardInvalid = v.allowClose; // Mission ValidateExit already multi-confirms
   bool softInvalid = (!d.thesisValid && !d.structureValid && d.trueReversal);
   if(v.masterTrendChanged && !d.thesisValid && d.trueReversal)
      softInvalid = true;

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

      if(d.l3Streak >= need && (hardInvalid || (softInvalid && v.allowClose)))
      {
         d.level = PEVO_INVALIDATE;
         d.command = SUP_EXIT;
         d.allowClose = true;
         d.exitReason = v.reason;
         if(StringLen(d.exitReason) == 0)
            d.exitReason = "thesis+structure+reversal confirmed";
         d.reason = "L3 INVALIDATION — " + d.exitReason;
         d.wantReplace = UltraPosEvoReplaceEnabled;
         if(d.wantReplace)
            d.replaceReason = "scan for validated opposite after close";
         g_UltraPosEvoLast = d;
         return d;
      }

      // Not enough confirm bars — manage, do not panic close
      d.level = PEVO_MANAGE;
      d.command = SUP_MANAGE;
      d.reason = StringFormat("L2 MANAGE — invalidation forming %d/%d bars (anti-whipsaw)",
                              d.l3Streak, need);
      g_UltraPosEvoLast = d;
      return d;
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
      g_UltraPosEvoLast = d;
      return d;
   }

   //======== LEVEL 1: keep holding ========//
   d.level = PEVO_HOLD;
   d.command = SUP_HOLD;
   d.reason = "L1 HOLD — thesis/structure/trend/confidence maintained";
   if(d.thesisValid && d.structureValid && d.masterTrendValid && d.confidenceOk)
      d.reason = "L1 HOLD — highest-probability path still intact";
   g_UltraPosEvoLast = d;
   return d;
}

string UltraPosEvo_Dashboard()
{
   string t = "POSEVO: ";
   t += UltraPosEvo_LevelName(g_UltraPosEvoLast.level);
   t += " ";
   t += g_UltraPosEvoLast.reason;
   if(g_UltraPosEvoReplace.pending)
   {
      t += " | REPLACE→";
      t += (g_UltraPosEvoReplace.wantBuy ? "BUY" : "SELL");
   }
   return t;
}

#endif // HITMAN_ULTRA_POSITION_EVOLUTION_MQH
