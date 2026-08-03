#ifndef HITMAN_ULTRA_NEWS_EXECUTION_MQH
#define HITMAN_ULTRA_NEWS_EXECUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — PHASE 23 ULTRA NEWS EXECUTION PROTOCOL ∞             |
//| CHAPTER 5 LOCK: News Intelligence NEVER trades / NEVER executes  |
//| This protocol assists Execution ONLY after Mission approval      |
//| Never disable trading because of news alone                      |
//| Never auto-reject on high spread — full analysis first           |
//| Never force a trade · Never reduce validation under volatility   |
//| Never override Mission Control or proprietary strategy           |
//+------------------------------------------------------------------+

// Forward — Adaptive Intelligence assembled after this module
int UltraAdaptive_MonitorMs(const int baseMs);

#define ULTRA_NEWS_VAL_TREND     0x001
#define ULTRA_NEWS_VAL_MKTINTEL  0x002
#define ULTRA_NEWS_VAL_STRUCT    0x004
#define ULTRA_NEWS_VAL_LIQ       0x008
#define ULTRA_NEWS_VAL_MOM       0x010
#define ULTRA_NEWS_VAL_MTF       0x020
#define ULTRA_NEWS_VAL_THESIS    0x040
#define ULTRA_NEWS_VAL_CONF      0x080
#define ULTRA_NEWS_VAL_RISK      0x100
#define ULTRA_NEWS_VAL_EXEC      0x200
#define ULTRA_NEWS_VAL_ALL       0x3FF

struct UltraNewsExecState
{
   bool   enabled;
   bool   newsMode;              // ULTRA News Mode active
   bool   forceRebuild;          // complete market re-analysis required
   bool   lastSignalValid;
   bool   lastTradeAllowed;
   string eventName;
   string phase;
   int    impact;
   int    passMask;
   int    failMask;
   long   lastMonitorMs;
   long   lastValidateMs;
   long   lastReanalyzeMs;
   long   lastExecMonMs;
   long   modeEnterMs;
   ulong  modeActivations;
   ulong  reanalyzeCount;
   ulong  eventFireCount;
   ulong  eventFlatCount;
   ulong  fillOkCount;
   ulong  execRecoverCount;
   ulong  highSpreadContinue;    // Phase 23 — elevated spread continued (never auto-reject)
   bool   execPriority;          // Phase 23 — elevated execution priority in News Mode
   double lastSpread;
   double lastSlip;
   int    lastExecQ;
   int    lastConf;
   string lastWhy;
   string lastFillDetail;
   string lastSpreadNote;
};

// ULTRA NEWS EXECUTION PROTOCOL — prepared order packet (exec path only)
struct UltraNewsExecPacket
{
   bool   armed;
   bool   buySide;
   string symbol;
   string eventName;
   string phase;
   string tag;
   int    passMask;
   int    conf;
   double spread;
   double bid;
   double ask;
   long   preparedMs;
   int    attempt;
   uint   lastRetcode;
   ulong  prepareCount;
   ulong  submitCount;
   ulong  retryCount;
   ulong  cancelCount;
   ulong  okCount;
   ulong  failCount;
   string lastResult;
   string lastDetail;
};

UltraNewsExecState g_UltraNewsExec;
UltraNewsExecPacket g_UltraNewsPacket;

// Protocol API — implemented below (forwards for AllowTrade arming)
bool UltraNewsExec_ProtocolPrepare(const string s, const UltraSnap &u, const bool buySide,
                                   const string tag, string &why);
bool UltraNewsExec_ProtocolSubmit(const string s, const bool buySide, string &why);
bool UltraNewsExec_RetryValidate(const string s, const uint retcode, const bool buySide,
                                 string &action);
void UltraNewsExec_ProtocolLog(const string result, const ulong ticket, const bool buySide,
                               const uint retcode, const string detail);
void UltraNewsExec_ProtocolDisarm(const string reason);

//--------------------------------------------------------------------//
bool UltraNewsExec_IsNewsMode()
{
   return (UltraNewsExecEnabled && g_UltraNewsExec.newsMode);
}

bool UltraNewsExec_ShouldForceRebuild()
{
   return (UltraNewsExecEnabled && g_UltraNewsExec.newsMode && g_UltraNewsExec.forceRebuild);
}

bool UltraNewsExec_InstantPath()
{
   // Phase 23 — News Mode raises execution priority (skip smart-tick short-circuit)
   if(!UltraNewsExec_IsNewsMode()) return false;
   if(UltraNewsExecInstantPath) return true;
   if(UltraNewsExecPhase23Boost && g_UltraNewsExec.execPriority) return true;
   return false;
}

// Phase 23 — elevated execution priority flag
bool UltraNewsExec_ExecPriority()
{
   return UltraNewsExec_InstantPath();
}

//--------------------------------------------------------------------//
// PHASE 23 HIGH SPREAD RULE                                          //
// High spread → DO NOT reject automatically → continue full analysis //
// → thesis valid? → risk acceptable? → Execute / Wait                //
//--------------------------------------------------------------------//
bool UltraNewsExec_HighSpreadRule(const UltraSnap &u, string &note)
{
   // ALWAYS returns true (continue analysis). Never an auto-reject gate.
   note = "";
   double spr = u.ctx.spreadPts;
   if(spr <= 0.0)
      spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   g_UltraNewsExec.lastSpread = spr;
   g_UltraNewsExec.lastSlip = u.ctx.slipProxy;

   bool elevated = (spr >= UltraEventSpreadWarnPts);
   if(elevated)
   {
      g_UltraNewsExec.highSpreadContinue++;
      note = "HIGH_SPREAD spr=" + DoubleToString(spr, 0) +
             " — continue full analysis (never auto-reject)";
      g_UltraNewsExec.lastSpreadNote = note;
      return true;
   }
   note = "spread ok spr=" + DoubleToString(spr, 0);
   g_UltraNewsExec.lastSpreadNote = note;
   return true;
}

//--------------------------------------------------------------------//
bool UltraNewsExec_DetectContext(const UltraSnap &u)
{
   if(!UltraNewsExecEnabled) return false;

   // PHASE 1 — Ultra Event Detection
   // upcoming/start/end · abnormal vol · spread expansion · liquidity changes
   bool majorClass =
      (u.ctx.eventClass == "NFP" || u.ctx.eventClass == "FOMC" ||
       u.ctx.eventClass == "CPI" || u.ctx.eventClass == "RATES" ||
       u.ctx.eventClass == "PMI" || u.ctx.eventClass == "MAJOR");

   bool phaseActive = (u.ctx.beforeNews || u.ctx.duringNews || u.ctx.afterNews);
   bool highVol = (u.vol.expansion && u.vol.relative >= UltraNewsExecHighVolRel);
   bool eventEngine = g_UltraEventLast.active;
   bool spreadExpand = (u.ctx.spreadPts >= UltraEventSpreadWarnPts) ||
                       g_UltraEventLast.spreadElevated;
   bool liqChange = g_UltraEventLast.liqThin ||
                    (g_UltraEventLast.liqScore > 0 && g_UltraEventLast.liqScore < 40);
   bool calendarHit = (UltraNewsExecUseCalendarContext && g_UltraCalInWindow &&
                       g_UltraCalUpdated > 0 &&
                       (TimeCurrent() - g_UltraCalUpdated) <= 120);

   if(calendarHit && (majorClass || phaseActive || highVol || u.ctx.eventImpact >= 2))
      return true;
   if(majorClass && (phaseActive || highVol || u.ctx.eventImpact >= 2))
      return true;
   if(eventEngine && (u.ctx.eventImpact >= 2 || highVol || spreadExpand || liqChange))
      return true;
   if(u.ctx.duringNews && u.ctx.eventImpact >= 2)
      return true;
   if(highVol && majorClass)
      return true;
   if(calendarHit && (spreadExpand || liqChange || highVol))
      return true;
   return false;
}

//--------------------------------------------------------------------//
// PHASE 2 — ULTRA MARKET STABILIZATION (before entry)                //
// Direction · Speed · Momentum · Volatility · Liquidity · Trend · Thesis
// Never fails on spread/news alone — combined instability only       //
//--------------------------------------------------------------------//
bool UltraNewsExec_StabilityOK(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   if(!UltraNewsExecRequireStability)
      return true;

   int score = 0;

   // Price direction / trend
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull)
                        : (u.trend.bear || u.trend.htfBear || u.trend.macroBear);
   if(trend) score += 18;

   // Market speed (tick speed proxy)
   double spd = g_UltraEventStats.tickSpeed;
   if(spd <= 0.0) spd = u.ctx.tickSpeed;
   if(spd >= 1.0) score += 12;
   else if(spd >= 0.3) score += 6;

   // Momentum
   bool mom = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
                      : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);
   if(mom) score += 18;

   // Volatility readable (abnormal alone never fails)
   if(u.vol.atr > 0.0) score += 10;
   if(u.vol.relative > 0.0 && u.vol.relative < UltraNewsExecHighVolRel * 2.5)
      score += 6;

   // Liquidity
   bool liq = UltraLiq_IsGenuine(u, buySide) ||
              (buySide ? (u.liq.confirmedBuy || u.bos.buy)
                       : (u.liq.confirmedSell || u.bos.sell));
   if(liq) score += 14;
   if(g_UltraEventLast.liqScore >= 40) score += 6;

   // Trade thesis shape
   bool thesis = buySide
      ? (u.bos.buy || u.choch.buy || UltraLiq_IsGenuine(u, true) ||
         (u.trend.bull && (u.ict.instZoneBuy || u.fib.atBuyZone)))
      : (u.bos.sell || u.choch.sell || UltraLiq_IsGenuine(u, false) ||
         (u.trend.bear && (u.ict.instZoneSell || u.fib.atSellZone)));
   if(thesis) score += 16;

   // Exec quality soft contribution
   int eq = g_UltraEventLast.execQuality;
   if(eq <= 0) eq = u.ctx.execQuality;
   if(eq >= UltraEventExecQualityMin) score += 10;
   else if(eq >= UltraEventExecQualityMin / 2) score += 4;

   int need = UltraNewsExecMinStabilityScore;
   if(need < 40) need = 40;
   if(need > 95) need = 95;

   if(score < need)
   {
      why = "NEWS_STABILITY fail score=" + IntegerToString(score) +
            "/" + IntegerToString(need);
      if(!trend) why += " trend";
      if(!mom) why += " momentum";
      if(!liq) why += " liquidity";
      if(!thesis) why += " thesis";
      if(eq < UltraEventExecQualityMin) why += " execQ";
      return false;
   }

   why = "NEWS_STABILITY PASS score=" + IntegerToString(score) +
         " dir=" + (buySide ? "BUY" : "SELL");
   return true;
}

void UltraNewsExec_EnterMode(const UltraSnap &u)
{
   bool was = g_UltraNewsExec.newsMode;
   g_UltraNewsExec.newsMode = true;
   g_UltraNewsExec.execPriority = true; // Phase 23 — Increase Execution Priority
   g_UltraNewsExec.eventName = u.ctx.eventClass;
   if(StringLen(g_UltraNewsExec.eventName) == 0 || g_UltraNewsExec.eventName == "NONE")
      g_UltraNewsExec.eventName = "MAJOR";
   g_UltraNewsExec.phase = u.ctx.newsPhase;
   g_UltraNewsExec.impact = u.ctx.eventImpact;
   g_UltraNewsExec.forceRebuild = true; // complete re-analysis before event trade
   g_UltraNewsExec.lastSpread = u.ctx.spreadPts;
   g_UltraNewsExec.lastSlip = u.ctx.slipProxy;
   g_UltraNewsExec.lastExecQ = (int)u.ctx.execQuality;
   g_UltraNewsExec.lastConf = u.score.confidence;

   // Phase 23 — high spread noted, never blocks mode activation
   string sprNote = "";
   UltraNewsExec_HighSpreadRule(u, sprNote);

   if(!was)
   {
      g_UltraNewsExec.modeEnterMs = (long)GetTickCount();
      g_UltraNewsExec.modeActivations++;
      if(UltraNewsExecLog)
      {
         UltraLog("PHASE23 NEWS_MODE ON event=" + g_UltraNewsExec.eventName +
                  " phase=" + g_UltraNewsExec.phase +
                  " impact=" + IntegerToString(g_UltraNewsExec.impact) +
                  " atrRel=" + DoubleToString(u.vol.relative, 2) +
                  " spr=" + DoubleToString(u.ctx.spreadPts, 0) +
                  " slip=" + DoubleToString(u.ctx.slipProxy, 1) +
                  " priority=Y | " + sprNote);
      }
   }
}

void UltraNewsExec_ExitMode(const string why)
{
   if(!g_UltraNewsExec.newsMode) return;
   if(UltraNewsExecLog)
      UltraLog("PHASE23 NEWS_MODE OFF event=" + g_UltraNewsExec.eventName + " why=" + why);
   g_UltraNewsExec.newsMode = false;
   g_UltraNewsExec.forceRebuild = false;
   g_UltraNewsExec.execPriority = false;
   g_UltraNewsExec.phase = "NONE";
}

//--------------------------------------------------------------------//
// HIGH-FREQUENCY MONITORING (News Mode)                              //
//--------------------------------------------------------------------//
void UltraNewsExec_OnTick(const string s)
{
   if(!UltraNewsExecEnabled) return;

   // Lightweight: use last snap context if available
   UltraSnap u = g_UltraLastSnap;
   bool ctx = false;
   if(u.vol.atr > 0.0)
      ctx = UltraNewsExec_DetectContext(u);
   else if(g_UltraEventLast.active)
      ctx = true;

   if(ctx)
      UltraNewsExec_EnterMode(u);
   else if(g_UltraNewsExec.newsMode)
   {
      // Leave mode when event context clears and vol normalizes
      if(!g_UltraEventLast.active &&
         !(u.ctx.beforeNews || u.ctx.duringNews) &&
         u.vol.relative < UltraNewsExecHighVolRel * 0.85)
         UltraNewsExec_ExitMode("context cleared");
   }

   if(!g_UltraNewsExec.newsMode) return;

   long now = (long)GetTickCount();
   // Phase 23 — Increase Market Monitoring (adaptive may tighten; never relax past input)
   int monMs = UltraAdaptive_MonitorMs(UltraNewsExecMonitorMs);
   if(UltraNewsExecPhase23Boost && monMs > UltraNewsExecMonitorMs)
      monMs = UltraNewsExecMonitorMs;
   if(monMs < 25) monMs = 25;

   if(g_UltraNewsExec.lastMonitorMs <= 0 || (now - g_UltraNewsExec.lastMonitorMs) >= monMs)
   {
      g_UltraNewsExec.lastMonitorMs = now;
      UltraMarketIntel_Validate(s);   // instant price / market re-analysis
      UltraData_Refresh(s);
      // High spread telemetry only — never blocks
      UltraSnap uMon = g_UltraLastSnap;
      uMon.ctx.spreadPts = UltraData_Spread(s);
      string sprNote = "";
      UltraNewsExec_HighSpreadRule(uMon, sprNote);
   }

   // Phase 23 — Increase Execution Monitoring / Recovery
   int exMs = UltraNewsExecExecMonMs;
   if(UltraNewsExecPhase23Boost && exMs > UltraNewsExecMonitorMs)
      exMs = UltraNewsExecMonitorMs;
   if(exMs < 25) exMs = 25;
   if(g_UltraNewsExec.lastExecMonMs <= 0 || (now - g_UltraNewsExec.lastExecMonMs) >= exMs)
   {
      g_UltraNewsExec.lastExecMonMs = now;
      g_UltraNewsExec.lastSpread = UltraData_Spread(s);
      string why = "";
      if(!UltraExecReady(s, why) && UltraNewsExecAutoRecover)
      {
         g_UltraNewsExec.execRecoverCount++;
         UltraRecover("PHASE23 NEWS_EXEC " + why);
      }
   }
}

//--------------------------------------------------------------------//
// PHASE 3/4 — ULTRA SIGNAL VALIDATION + FALSE SIGNAL REDUCTION       //
// Flow: side → thesis → trend → momentum → risk → market/struct…     //
// → Mission-ready. Never reduced under volatility.                   //
//--------------------------------------------------------------------//
bool UltraNewsExec_ValidateSignal(const string s, const UltraSnap &u,
                                  const bool buySide, string &why)
{
   why = "";
   g_UltraNewsExec.passMask = 0;
   g_UltraNewsExec.failMask = 0;
   g_UltraNewsExec.lastSignalValid = false;

   // PHASE 3 — Trade Thesis Valid?
   bool thesis = false;
   if(buySide)
      thesis = (u.bos.buy || u.choch.buy || UltraLiq_IsGenuine(u, true) ||
                (u.trend.bull && (u.ict.instZoneBuy || u.fib.atBuyZone || u.ict.inDiscount)));
   else
      thesis = (u.bos.sell || u.choch.sell || UltraLiq_IsGenuine(u, false) ||
                (u.trend.bear && (u.ict.instZoneSell || u.fib.atSellZone || u.ict.inPremium)));
   if(thesis) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_THESIS;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_THESIS;

   // PHASE 3 — Trend Supports?
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.continuation)
                        : (u.trend.bear || u.trend.htfBear || u.trend.continuation);
   if(trend) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_TREND;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_TREND;

   // PHASE 3 — Momentum Supports?
   bool mom = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
                      : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);
   if(mom) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_MOM;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_MOM;

   // PHASE 3 — Risk Acceptable?
   string capWhy = "";
   bool riskOK = UltraCapitalOK(capWhy);
   if(MaxOpenTrades > 0 && UltraExec_OpenCountMagic() >= MaxOpenTrades)
   {
      riskOK = false;
      capWhy = "max open reached";
   }
   if(riskOK) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_RISK;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_RISK;

   // Market Intelligence
   bool mkt = true;
   if(UltraMarketIntelEnabled)
      mkt = UltraMarketIntel_Approved();
   if(mkt) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_MKTINTEL;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_MKTINTEL;

   // Structure
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.bos.buy || u.choch.buy)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.bos.sell || u.choch.sell);
   if(structure) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_STRUCT;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_STRUCT;

   // Liquidity — genuine / confirmed / strong BOS (fake alone fails)
   bool bosStrong = buySide
      ? (u.bos.buy && (u.bos.confirmed || u.bos.strong))
      : (u.bos.sell && (u.bos.confirmed || u.bos.strong));
   if(UltraLiq_IsFakeSweep(u, buySide) && !UltraLiq_IsGenuine(u, buySide) && !bosStrong)
   {
      g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_LIQ;
   }
   else
   {
      bool liq = UltraLiq_IsGenuine(u, buySide) || bosStrong ||
                 (buySide ? (u.liq.confirmedBuy || u.liq.equalLows)
                          : (u.liq.confirmedSell || u.liq.equalHighs));
      if(liq) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_LIQ;
      else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_LIQ;
   }

   // Multi-Timeframe — conflicting master = reject
   string mtfWhy = "";
   bool mtf = UltraMTF_NoConflict(s, buySide, mtfWhy);
   int master = UltraMTF_MasterDir(s);
   if(buySide && master < 0) mtf = false;
   if(!buySide && master > 0) mtf = false;
   if(mtf) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_MTF;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_MTF;

   // PHASE 4 — Low Confidence reject (never lowered for news/vol)
   int confFloor = UltraNewsExecMinConf;
   if(confFloor < UltraEventMinConf) confFloor = UltraEventMinConf;
   bool confOK = (u.score.confidence >= confFloor);
   if(confOK) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_CONF;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_CONF;

   // Execution Validation — elevated spread NEVER sole-fails
   string exWhy = "";
   bool execOK = UltraExecReady(s, exWhy);
   string sprNote = "";
   UltraNewsExec_HighSpreadRule(u, sprNote);
   if(execOK) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_EXEC;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_EXEC;

   // Mission-ready Validation Chain during news
   if(UltraNewsExecRequireVChain && UltraVChainEnabled)
   {
      string vWhy = "";
      UltraVChain_EvaluateForMission(s, u, vWhy);
      if(!UltraVChain_MissionReady())
      {
         why = "NEWS_VAL: VCHAIN not ready — " + vWhy;
         g_UltraNewsExec.lastWhy = why;
         return false;
      }
   }

   bool all = ((g_UltraNewsExec.passMask & ULTRA_NEWS_VAL_ALL) == ULTRA_NEWS_VAL_ALL);
   if(!all)
   {
      // PHASE 4 — false signal reduction reasons (thesis-first wording)
      why = "NEWS_VAL REJECT mask=" + IntegerToString(g_UltraNewsExec.passMask) +
            "/" + IntegerToString(ULTRA_NEWS_VAL_ALL);
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_THESIS) != 0) why += " | incomplete thesis";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_TREND) != 0) why += " | weak trend";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_MOM) != 0) why += " | weak momentum";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_RISK) != 0) why += " | poor risk";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_CONF) != 0) why += " | low confidence";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_MTF) != 0) why += " | conflicting signals";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_MKTINTEL) != 0) why += " | market";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_STRUCT) != 0) why += " | structure";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_LIQ) != 0) why += " | liquidity";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_EXEC) != 0) why += " | exec";
      g_UltraNewsExec.lastWhy = why;
      g_UltraNewsExec.lastSignalValid = false;
      return false;
   }

   why = "NEWS_VAL PASS event=" + g_UltraNewsExec.eventName +
         " phase=" + g_UltraNewsExec.phase +
         " conf=" + IntegerToString(u.score.confidence) +
         " spr=" + DoubleToString(g_UltraNewsExec.lastSpread, 0) +
         " slip=" + DoubleToString(g_UltraNewsExec.lastSlip, 1);
   if(StringLen(g_UltraNewsExec.lastSpreadNote) > 0)
      why += " | " + g_UltraNewsExec.lastSpreadNote;
   g_UltraNewsExec.lastWhy = why;
   g_UltraNewsExec.lastSignalValid = true;
   g_UltraNewsExec.lastConf = u.score.confidence;
   return true;
}

//--------------------------------------------------------------------//
// ALLOW TRADE — full re-analysis gate + event engine + 10-point val  //
//--------------------------------------------------------------------//
bool UltraNewsExec_AllowTrade(const string s, UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   g_UltraNewsExec.lastTradeAllowed = true;

   if(!UltraNewsExecEnabled)
      return UltraEvent_AllowTrade(s, u, buySide, why);

   bool ctx = UltraNewsExec_DetectContext(u);
   if(!ctx)
   {
      // Outside news — normal event engine path (pass-through when idle)
      return UltraEvent_AllowTrade(s, u, buySide, why);
   }

   UltraNewsExec_EnterMode(u);

   // Phase 23 HIGH SPREAD RULE — note + continue (never auto-reject here)
   {
      string sprNote = "";
      UltraNewsExec_HighSpreadRule(u, sprNote);
   }

   // Complete market re-analysis before every event trade
   long now = (long)GetTickCount();
   int reMs = UltraNewsExecReanalyzeMs;
   if(reMs < 0) reMs = 0;
   bool needRebuild = g_UltraNewsExec.forceRebuild ||
                      (g_UltraNewsExec.lastReanalyzeMs <= 0) ||
                      ((now - g_UltraNewsExec.lastReanalyzeMs) >= reMs);
   if(needRebuild && UltraNewsExecForceReanalyze)
   {
      UltraSnap fresh;
      if(!UltraBuildSnapshot(s, fresh))
      {
         why = "NEWS_EXEC: re-analysis failed — " + g_UltraCore.lastError;
         g_UltraNewsExec.lastTradeAllowed = false;
         g_UltraNewsExec.eventFlatCount++;
         g_UltraNewsExec.lastWhy = why;
         UltraEvent_Note(UEV_EVENT_FLAT);
         return false;
      }
      u = fresh;
      g_UltraLastSnap = fresh;
      g_UltraNewsExec.lastReanalyzeMs = now;
      g_UltraNewsExec.reanalyzeCount++;
      g_UltraNewsExec.forceRebuild = false;
      // Re-enter with fresh context
      if(UltraNewsExec_DetectContext(u))
         UltraNewsExec_EnterMode(u);
   }

   // Event engine first (never news/spread-only reject; never force)
   string evWhy = "";
   if(!UltraEvent_AllowTrade(s, u, buySide, evWhy))
   {
      why = evWhy;
      g_UltraNewsExec.lastTradeAllowed = false;
      g_UltraNewsExec.eventFlatCount++;
      g_UltraNewsExec.lastWhy = why;
      return false;
   }

   // Increase Signal Validation Frequency — full 10-point checklist
   int valMs = UltraNewsExecValidateMs;
   if(valMs < 25) valMs = 25;
   g_UltraNewsExec.lastValidateMs = now;

   // PHASE 2 — Market Stabilization before entry
   string stWhy = "";
   if(!UltraNewsExec_StabilityOK(u, buySide, stWhy))
   {
      why = stWhy;
      g_UltraNewsExec.lastTradeAllowed = false;
      g_UltraNewsExec.eventFlatCount++;
      g_UltraNewsExec.lastWhy = why;
      UltraEvent_Note(UEV_EVENT_FLAT);
      if(UltraNewsExecLog)
         UltraLogDecision("EVENT_FLAT", 0, buySide ? "BUY" : "SELL",
                          g_UltraNewsExec.eventName, u.score.confidence,
                          u.ctx.eventConfidence, g_UltraNewsExec.phase,
                          g_UltraNewsExec.phase, u.ctx.spreadPts, u.ctx.slipProxy, why);
      return false;
   }

   // PHASE 3/4 — Signal Validation + False Signal Reduction
   string vWhy = "";
   if(!UltraNewsExec_ValidateSignal(s, u, buySide, vWhy))
   {
      why = vWhy;
      g_UltraNewsExec.lastTradeAllowed = false;
      g_UltraNewsExec.eventFlatCount++;
      UltraEvent_Note(UEV_EVENT_FLAT);
      if(UltraNewsExecLog)
      {
         UltraLogDecision("EVENT_FLAT", 0, buySide ? "BUY" : "SELL",
                          g_UltraNewsExec.eventName, u.score.confidence,
                          u.ctx.eventConfidence, g_UltraNewsExec.phase,
                          g_UltraNewsExec.phase, u.ctx.spreadPts, u.ctx.slipProxy, why);
      }
      return false;
   }

   // Proprietary strategy remains fully validated — allow → Mission Control next
   why = "NEWS_EXEC READY event=" + g_UltraNewsExec.eventName +
         " | " + stWhy + " | " + vWhy + " | " + evWhy;
   g_UltraNewsExec.lastTradeAllowed = true;
   g_UltraNewsExec.lastWhy = why;
   g_UltraNewsExec.lastSpread = u.ctx.spreadPts;
   g_UltraNewsExec.lastSlip = u.ctx.slipProxy;
   g_UltraNewsExec.lastExecQ = g_UltraEventLast.execQuality;

   // PROTOCOL — prepare order packet before final trigger / submit
   {
      string pWhy = "";
      UltraNewsExec_ProtocolPrepare(s, u, buySide, "", pWhy);
   }
   return true;
}

//--------------------------------------------------------------------//
// EXECUTION LOG / FILL / POSITION / RECOVERY                         //
//--------------------------------------------------------------------//
void UltraNewsExec_NoteFire(const string s, const bool buySide, const string tag,
                            const UltraSnap &u)
{
   if(!UltraNewsExecEnabled || !g_UltraNewsExec.newsMode) return;
   g_UltraNewsExec.eventFireCount++;
   string side = buySide ? "BUY" : "SELL";
   string detail = "NEWS_FIRE event=" + g_UltraNewsExec.eventName +
                   " phase=" + g_UltraNewsExec.phase +
                   " tag=" + tag +
                   " conf=" + IntegerToString(u.score.confidence) +
                   " spr=" + DoubleToString(u.ctx.spreadPts, 0) +
                   " slip=" + DoubleToString(u.ctx.slipProxy, 1) +
                   " execQ=" + IntegerToString(g_UltraEventLast.execQuality) +
                   " spd=" + DoubleToString(g_UltraEventStats.tickSpeed, 1) +
                   " mask=" + IntegerToString(g_UltraNewsExec.passMask);
   UltraLogDecision("EVENT_TRADE", 0, side, g_UltraNewsExec.eventName,
                    u.score.confidence, u.ctx.eventConfidence,
                    g_UltraNewsExec.phase, tag, u.ctx.spreadPts, u.ctx.slipProxy, detail);
   if(UltraNewsExecLog)
      UltraLog(detail + " on " + s);

   // PROTOCOL — refresh armed packet at fire (final trigger confirmation)
   string pWhy = "";
   UltraNewsExec_ProtocolPrepare(s, u, buySide, tag, pWhy);
}

void UltraNewsExec_NoteFill(const ulong ticket, const string s, const bool buySide,
                            const string detail)
{
   if(!UltraNewsExecEnabled) return;
   if(!g_UltraNewsExec.newsMode && g_UltraNewsExec.eventFireCount == 0 &&
      !g_UltraNewsPacket.armed) return;
   g_UltraNewsExec.fillOkCount++;
   g_UltraNewsExec.lastFillDetail = detail;
   string side = buySide ? "BUY" : "SELL";

   // PHASE 5 — actual fill slippage vs prepared quote (when available)
   double actSlip = g_UltraNewsExec.lastSlip;
   if(UltraNewsExecLogActualSlippage && ticket > 0 && PositionSelectByTicket(ticket))
   {
      double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
      double expected = buySide ? g_UltraNewsPacket.ask : g_UltraNewsPacket.bid;
      double point = SymbolInfoDouble(s, SYMBOL_POINT);
      if(expected > 0.0 && openPx > 0.0 && point > 0.0)
      {
         actSlip = buySide ? ((openPx - expected) / point)
                           : ((expected - openPx) / point);
         g_UltraNewsExec.lastSlip = actSlip;
      }
   }

   string msg = "NEWS_FILL event=" + g_UltraNewsExec.eventName +
                " ticket=" + IntegerToString((int)ticket) +
                " " + side + " " + detail +
                " spr=" + DoubleToString(g_UltraNewsExec.lastSpread, 0) +
                " slip=" + DoubleToString(actSlip, 1);
   UltraLogDecision("EVENT_FILL", ticket, side, g_UltraNewsExec.eventName,
                    g_UltraNewsExec.lastConf, g_UltraNewsExec.impact,
                    g_UltraNewsExec.phase, "FILL", g_UltraNewsExec.lastSpread,
                    actSlip, msg);
   if(UltraNewsExecLog)
      UltraLog(msg + " on " + s);

   // PROTOCOL — verify broker response logged as OK
   UltraNewsExec_ProtocolLog("OK", ticket, buySide, 0, detail);
   UltraNewsExec_ProtocolDisarm("fill_ok");

   // Instant position verification + activate monitoring
   if(ticket > 0)
   {
      if(!PositionSelectByTicket(ticket))
      {
         g_UltraNewsExec.execRecoverCount++;
         if(UltraNewsExecAutoRecover)
            UltraRecover("NEWS_FILL position missing ticket=" + IntegerToString((int)ticket));
      }
   }
}

void UltraNewsExec_MarkRebuildDone()
{
   g_UltraNewsExec.forceRebuild = false;
   g_UltraNewsExec.lastReanalyzeMs = (long)GetTickCount();
   g_UltraNewsExec.reanalyzeCount++;
}

//--------------------------------------------------------------------//
// ULTRA NEWS EXECUTION PROTOCOL                                      //
// Pre-validate · Prepare · Minimize latency · Submit · Verify        //
// Retry recoverable only · Re-analyze before retry · Cancel if dead  //
// Log every execution result                                         //
//--------------------------------------------------------------------//
void UltraNewsExec_ProtocolDisarm(const string reason)
{
   g_UltraNewsPacket.armed = false;
   g_UltraNewsPacket.lastDetail = reason;
}

void UltraNewsExec_ProtocolLog(const string result, const ulong ticket, const bool buySide,
                               const uint retcode, const string detail)
{
   g_UltraNewsPacket.lastResult = result;
   g_UltraNewsPacket.lastDetail = detail;
   g_UltraNewsPacket.lastRetcode = retcode;

   if(result == "OK") g_UltraNewsPacket.okCount++;
   else if(result == "RETRY") g_UltraNewsPacket.retryCount++;
   else if(result == "CANCEL") g_UltraNewsPacket.cancelCount++;
   else if(result == "FAIL") g_UltraNewsPacket.failCount++;

   string side = buySide ? "BUY" : "SELL";
   string msg = "PHASE23 NEWS_PROTO " + result +
                " event=" + g_UltraNewsPacket.eventName +
                " phase=" + g_UltraNewsPacket.phase +
                " att=" + IntegerToString(g_UltraNewsPacket.attempt) +
                " spr=" + DoubleToString(g_UltraNewsPacket.spread, 0) +
                " slip=" + DoubleToString(g_UltraNewsExec.lastSlip, 1) +
                " rc=" + IntegerToString((int)retcode) +
                " " + detail;

   // Always persist: event name, spread, slippage, execution result
   UltraLogDecision("NEWS_" + result, ticket, side,
                    (StringLen(g_UltraNewsPacket.tag) > 0 ? g_UltraNewsPacket.tag : g_UltraNewsPacket.eventName),
                    g_UltraNewsPacket.conf, g_UltraNewsPacket.passMask,
                    g_UltraNewsPacket.phase, result,
                    g_UltraNewsPacket.spread, g_UltraNewsExec.lastSlip, msg);

   if(UltraNewsExecLog)
      UltraLog(msg + " on " + g_UltraNewsPacket.symbol);
}

bool UltraNewsExec_ProtocolPrepare(const string s, const UltraSnap &u, const bool buySide,
                                   const string tag, string &why)
{
   why = "";
   if(!UltraNewsExecEnabled || !UltraNewsExecProtocolEnabled)
   {
      why = "protocol off";
      return true; // pass-through
   }
   if(!g_UltraNewsExec.newsMode)
   {
      why = "not news mode";
      return true;
   }

   // Pre-validate order parameters (exec readiness — never force trade)
   string execWhy = "";
   if(!UltraExecReady(s, execWhy))
   {
      why = "PREPARE blocked: " + execWhy;
      g_UltraNewsPacket.armed = false;
      UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, 0, why);
      return false;
   }

   g_UltraNewsPacket.armed = true;
   g_UltraNewsPacket.buySide = buySide;
   g_UltraNewsPacket.symbol = s;
   g_UltraNewsPacket.eventName = g_UltraNewsExec.eventName;
   g_UltraNewsPacket.phase = g_UltraNewsExec.phase;
   g_UltraNewsPacket.tag = tag;
   g_UltraNewsPacket.passMask = g_UltraNewsExec.passMask;
   g_UltraNewsPacket.conf = u.score.confidence;
   g_UltraNewsPacket.spread = u.ctx.spreadPts;
   g_UltraNewsPacket.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraNewsPacket.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   g_UltraNewsPacket.preparedMs = (long)GetTickCount();
   g_UltraNewsPacket.attempt = 0;
   g_UltraNewsPacket.lastRetcode = 0;
   g_UltraNewsPacket.prepareCount++;
   why = "PREPARED event=" + g_UltraNewsPacket.eventName +
         " conf=" + IntegerToString(g_UltraNewsPacket.conf) +
         " mask=" + IntegerToString(g_UltraNewsPacket.passMask);
   g_UltraNewsPacket.lastDetail = why;
   return true;
}

bool UltraNewsExec_ProtocolSubmit(const string s, const bool buySide, string &why)
{
   why = "";
   if(!UltraNewsExecEnabled || !UltraNewsExecProtocolEnabled)
      return true; // pass-through outside protocol

   // Outside news / not armed — allow normal execution path
   if(!g_UltraNewsExec.newsMode && !g_UltraNewsPacket.armed)
      return true;

   if(g_UltraNewsPacket.armed)
   {
      if(g_UltraNewsPacket.symbol != s || g_UltraNewsPacket.buySide != buySide)
      {
         why = "packet mismatch symbol/side";
         UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, 0, why);
         UltraNewsExec_ProtocolDisarm(why);
         return false;
      }

      // PHASE 5 — prepared packet freshness (fast news market)
      if(UltraNewsExecMaxPacketAgeMs > 0 && g_UltraNewsPacket.preparedMs > 0)
      {
         long age = (long)GetTickCount() - g_UltraNewsPacket.preparedMs;
         if(age < 0) age = 0;
         if(age > UltraNewsExecMaxPacketAgeMs)
         {
            if(g_UltraNewsExec.lastSignalValid)
            {
               g_UltraNewsPacket.bid = SymbolInfoDouble(s, SYMBOL_BID);
               g_UltraNewsPacket.ask = SymbolInfoDouble(s, SYMBOL_ASK);
               g_UltraNewsPacket.preparedMs = (long)GetTickCount();
               if(UltraNewsExecLog)
                  UltraLog("NEWS_PACKET refresh stale age=" + IntegerToString((int)age) +
                           "ms on " + s);
            }
            else
            {
               why = "packet stale age=" + IntegerToString((int)age) + "ms";
               UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, 0, why);
               UltraNewsExec_ProtocolDisarm(why);
               return false;
            }
         }
      }
   }

   // PHASE 5 — Submit Immediately after confirm
   string execWhy = "";
   if(!UltraExecReady(s, execWhy))
   {
      why = "SUBMIT blocked: " + execWhy;
      UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, 0, why);
      UltraNewsExec_ProtocolDisarm(why);
      return false;
   }

   g_UltraNewsPacket.attempt++;
   g_UltraNewsPacket.submitCount++;
   g_UltraNewsPacket.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraNewsPacket.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   why = "SUBMIT att=" + IntegerToString(g_UltraNewsPacket.attempt);
   return true;
}

bool UltraNewsExec_RetryValidate(const string s, const uint retcode, const bool buySide,
                                 string &action)
{
   action = "pass";
   if(!UltraNewsExecEnabled || !UltraNewsExecProtocolEnabled)
      return true; // Shell uses existing retry

   // Protocol active only in news mode or when packet armed from news fire
   if(!g_UltraNewsExec.newsMode && !g_UltraNewsPacket.armed)
      return true;

   // Fatal — never retry
   if(retcode == TRADE_RETCODE_NO_MONEY ||
      retcode == TRADE_RETCODE_MARKET_CLOSED ||
      retcode == TRADE_RETCODE_TRADE_DISABLED ||
      retcode == TRADE_RETCODE_INVALID_VOLUME ||
      retcode == TRADE_RETCODE_CLIENT_DISABLES_AT ||
      retcode == TRADE_RETCODE_SERVER_DISABLES_AT)
   {
      action = "fatal";
      UltraNewsExec_ProtocolLog("FAIL", 0, buySide, retcode, "fatal retcode — no retry");
      UltraNewsExec_ProtocolDisarm("fatal");
      return false;
   }

   // Recoverable only
   bool recoverable =
      (retcode == TRADE_RETCODE_REQUOTE ||
       retcode == TRADE_RETCODE_PRICE_OFF ||
       retcode == TRADE_RETCODE_PRICE_CHANGED ||
       retcode == TRADE_RETCODE_TIMEOUT ||
       retcode == TRADE_RETCODE_CONNECTION ||
       retcode == TRADE_RETCODE_INVALID_FILL ||
       retcode == TRADE_RETCODE_INVALID_PRICE);
   if(!recoverable)
   {
      action = "cancel";
      UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, retcode, "non-recoverable — cancel retry");
      UltraNewsExec_ProtocolDisarm("non-recoverable");
      return false;
   }

   UltraNewsExec_ProtocolLog("RETRY", 0, buySide, retcode, "recoverable — re-analyze");

   // Re-analyze before every retry
   UltraSnap fresh;
   if(!UltraBuildSnapshot(s, fresh))
   {
      action = "cancel";
      UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, retcode,
                                "re-analysis failed — " + g_UltraCore.lastError);
      UltraNewsExec_ProtocolDisarm("reanalyze fail");
      return false;
   }
   g_UltraLastSnap = fresh;
   g_UltraNewsExec.reanalyzeCount++;

   // Cancel retry if original setup no longer valid
   if(!UltraNewsExec_DetectContext(fresh) && g_UltraNewsExec.newsMode)
   {
      // Context may still be news via packet — require signal still valid
   }

   string vWhy = "";
   if(!UltraNewsExec_ValidateSignal(s, fresh, buySide, vWhy))
   {
      action = "cancel";
      UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, retcode,
                                "setup invalid after re-analysis — " + vWhy);
      UltraNewsExec_ProtocolDisarm(vWhy);
      g_UltraNewsExec.eventFlatCount++;
      return false;
   }

   string execWhy = "";
   if(!UltraExecReady(s, execWhy))
   {
      action = "cancel";
      UltraNewsExec_ProtocolLog("CANCEL", 0, buySide, retcode, "exec not ready — " + execWhy);
      UltraNewsExec_ProtocolDisarm(execWhy);
      return false;
   }

   // Refresh armed packet with fresh analysis
   g_UltraNewsPacket.conf = fresh.score.confidence;
   g_UltraNewsPacket.passMask = g_UltraNewsExec.passMask;
   g_UltraNewsPacket.spread = fresh.ctx.spreadPts;
   g_UltraNewsPacket.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraNewsPacket.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   g_UltraNewsPacket.armed = true;
   g_UltraNewsPacket.buySide = buySide;
   g_UltraNewsPacket.symbol = s;

   action = "retry";
   return true;
}

bool UltraNewsExec_ProtocolShouldFastRetry()
{
   if(!UltraNewsExecProtocolEnabled || !UltraNewsExecProtocolFastRetry)
      return false;
   return (UltraNewsExec_InstantPath() || g_UltraNewsPacket.armed || g_UltraNewsExec.newsMode);
}

int UltraNewsExec_ProtocolRetryPauseMs()
{
   if(UltraNewsExec_ProtocolShouldFastRetry())
      return UltraNewsExecProtocolRetryMs; // default 20; 0 = none
   return 200; // legacy pause outside news protocol
}

//--------------------------------------------------------------------//
void UltraNewsExec_Boot()
{
   g_UltraNewsExec.enabled = UltraNewsExecEnabled;
   g_UltraNewsExec.newsMode = false;
   g_UltraNewsExec.forceRebuild = false;
   g_UltraNewsExec.lastSignalValid = false;
   g_UltraNewsExec.lastTradeAllowed = true;
   g_UltraNewsExec.eventName = "NONE";
   g_UltraNewsExec.phase = "NONE";
   g_UltraNewsExec.impact = 0;
   g_UltraNewsExec.passMask = 0;
   g_UltraNewsExec.failMask = 0;
   g_UltraNewsExec.lastMonitorMs = 0;
   g_UltraNewsExec.lastValidateMs = 0;
   g_UltraNewsExec.lastReanalyzeMs = 0;
   g_UltraNewsExec.lastExecMonMs = 0;
   g_UltraNewsExec.modeEnterMs = 0;
   g_UltraNewsExec.modeActivations = 0;
   g_UltraNewsExec.reanalyzeCount = 0;
   g_UltraNewsExec.eventFireCount = 0;
   g_UltraNewsExec.eventFlatCount = 0;
   g_UltraNewsExec.fillOkCount = 0;
   g_UltraNewsExec.execRecoverCount = 0;
   g_UltraNewsExec.highSpreadContinue = 0;
   g_UltraNewsExec.execPriority = false;
   g_UltraNewsExec.lastSpread = 0;
   g_UltraNewsExec.lastSlip = 0;
   g_UltraNewsExec.lastExecQ = 100;
   g_UltraNewsExec.lastConf = 0;
   g_UltraNewsExec.lastWhy = "boot";
   g_UltraNewsExec.lastFillDetail = "";
   g_UltraNewsExec.lastSpreadNote = "";

   ZeroMemory(g_UltraNewsPacket);
   g_UltraNewsPacket.eventName = "NONE";
   g_UltraNewsPacket.phase = "NONE";
   g_UltraNewsPacket.lastResult = "boot";

   if(UltraNewsExecLog)
   {
      UltraLog("PHASE23 NEWS_EXEC ∞ boot Enabled=" + (UltraNewsExecEnabled ? "Y" : "N") +
               " InstantPath=" + (UltraNewsExecInstantPath ? "Y" : "N") +
               " ForceReanalyze=" + (UltraNewsExecForceReanalyze ? "Y" : "N") +
               " Protocol=" + (UltraNewsExecProtocolEnabled ? "Y" : "N") +
               " FastRetry=" + (UltraNewsExecProtocolFastRetry ? "Y" : "N") +
               " Phase23Boost=" + (UltraNewsExecPhase23Boost ? "Y" : "N") +
               " HighSpread=NEVER_AUTO_REJECT BUILD=HA_ULTRA_93");
   }
}

string UltraNewsExec_Dashboard()
{
   string t = "P23 NEWS: ";
   if(!UltraNewsExecEnabled) { t += "OFF"; return t; }
   if(g_UltraNewsExec.newsMode) t += "MODE_ON ";
   else t += "idle ";
   t += g_UltraNewsExec.eventName;
   t += " ";
   t += g_UltraNewsExec.phase;
   t += " | fire=";
   t += IntegerToString((int)g_UltraNewsExec.eventFireCount);
   t += " flat=";
   t += IntegerToString((int)g_UltraNewsExec.eventFlatCount);
   t += " rebuild=";
   t += IntegerToString((int)g_UltraNewsExec.reanalyzeCount);
   t += " fillV=";
   t += IntegerToString((int)g_UltraNewsExec.fillOkCount);
   t += " hiSpr=";
   t += IntegerToString((int)g_UltraNewsExec.highSpreadContinue);
   if(g_UltraNewsExec.execPriority) t += " PRI";
   if(UltraNewsExecProtocolEnabled)
   {
      t += " proto=";
      t += g_UltraNewsPacket.armed ? "ARMED" : "—";
      t += " ok=";
      t += IntegerToString((int)g_UltraNewsPacket.okCount);
      t += " cancel=";
      t += IntegerToString((int)g_UltraNewsPacket.cancelCount);
   }
   if(g_UltraNewsExec.newsMode)
   {
      t += " mask=";
      t += IntegerToString(g_UltraNewsExec.passMask);
      t += "/";
      t += IntegerToString(ULTRA_NEWS_VAL_ALL);
      t += " spr=";
      t += DoubleToString(g_UltraNewsExec.lastSpread, 0);
   }
   return t;
}

#endif // HITMAN_ULTRA_NEWS_EXECUTION_MQH
