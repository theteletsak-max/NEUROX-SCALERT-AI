#ifndef HITMAN_ULTRA_NEWS_EXECUTION_MQH
#define HITMAN_ULTRA_NEWS_EXECUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA NEWS EXECUTION INTELLIGENCE ENGINE ∞           |
//| Extreme conditions · Full validation · Fast execution            |
//| Never reduce validation. Never news/spread-only reject.          |
//| Never force a trade. Complete re-analysis before every event trade.|
//+------------------------------------------------------------------+

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
   double lastSpread;
   double lastSlip;
   int    lastExecQ;
   int    lastConf;
   string lastWhy;
   string lastFillDetail;
};

UltraNewsExecState g_UltraNewsExec;

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
   // During news mode: skip unchanged-tick short-circuit for instant reaction
   return UltraNewsExec_IsNewsMode() && UltraNewsExecInstantPath;
}

//--------------------------------------------------------------------//
bool UltraNewsExec_DetectContext(const UltraSnap &u)
{
   if(!UltraNewsExecEnabled) return false;

   // Major calendar / volatility event context from News + Event engines
   bool majorClass =
      (u.ctx.eventClass == "NFP" || u.ctx.eventClass == "FOMC" ||
       u.ctx.eventClass == "CPI" || u.ctx.eventClass == "RATES" ||
       u.ctx.eventClass == "PMI" || u.ctx.eventClass == "MAJOR");

   bool phaseActive = (u.ctx.beforeNews || u.ctx.duringNews || u.ctx.afterNews);
   bool highVol = (u.vol.expansion && u.vol.relative >= UltraNewsExecHighVolRel);
   bool eventEngine = g_UltraEventLast.active;

   if(majorClass && (phaseActive || highVol || u.ctx.eventImpact >= 2))
      return true;
   if(eventEngine && (u.ctx.eventImpact >= 2 || highVol))
      return true;
   if(u.ctx.duringNews && u.ctx.eventImpact >= 2)
      return true;
   if(highVol && majorClass)
      return true;
   return false;
}

void UltraNewsExec_EnterMode(const UltraSnap &u)
{
   bool was = g_UltraNewsExec.newsMode;
   g_UltraNewsExec.newsMode = true;
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
   if(!was)
   {
      g_UltraNewsExec.modeEnterMs = (long)GetTickCount();
      g_UltraNewsExec.modeActivations++;
      if(UltraNewsExecLog)
      {
         UltraLog("NEWS_MODE ON event=" + g_UltraNewsExec.eventName +
                  " phase=" + g_UltraNewsExec.phase +
                  " impact=" + IntegerToString(g_UltraNewsExec.impact) +
                  " atrRel=" + DoubleToString(u.vol.relative, 2) +
                  " spr=" + DoubleToString(u.ctx.spreadPts, 0));
      }
   }
}

void UltraNewsExec_ExitMode(const string why)
{
   if(!g_UltraNewsExec.newsMode) return;
   if(UltraNewsExecLog)
      UltraLog("NEWS_MODE OFF event=" + g_UltraNewsExec.eventName + " why=" + why);
   g_UltraNewsExec.newsMode = false;
   g_UltraNewsExec.forceRebuild = false;
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
   int monMs = UltraNewsExecMonitorMs;
   if(monMs < 25) monMs = 25;

   // Increase Market Monitoring Frequency
   if(g_UltraNewsExec.lastMonitorMs <= 0 || (now - g_UltraNewsExec.lastMonitorMs) >= monMs)
   {
      g_UltraNewsExec.lastMonitorMs = now;
      UltraMarketIntel_Validate(s);
      UltraData_Refresh(s);
   }

   // Increase Execution Monitoring
   int exMs = UltraNewsExecExecMonMs;
   if(exMs < 25) exMs = 25;
   if(g_UltraNewsExec.lastExecMonMs <= 0 || (now - g_UltraNewsExec.lastExecMonMs) >= exMs)
   {
      g_UltraNewsExec.lastExecMonMs = now;
      g_UltraNewsExec.lastSpread = UltraData_Spread(s);
      string why = "";
      if(!UltraExecReady(s, why) && UltraNewsExecAutoRecover)
      {
         g_UltraNewsExec.execRecoverCount++;
         UltraRecover("NEWS_EXEC " + why);
      }
   }
}

//--------------------------------------------------------------------//
// 10-POINT NEWS SIGNAL VALIDATION — never reduced under volatility   //
//--------------------------------------------------------------------//
bool UltraNewsExec_ValidateSignal(const string s, const UltraSnap &u,
                                  const bool buySide, string &why)
{
   why = "";
   g_UltraNewsExec.passMask = 0;
   g_UltraNewsExec.failMask = 0;
   g_UltraNewsExec.lastSignalValid = false;

   // 1) Trend Validation
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.continuation)
                        : (u.trend.bear || u.trend.htfBear || u.trend.continuation);
   if(trend) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_TREND;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_TREND;

   // 2) Market Intelligence Validation
   bool mkt = true;
   if(UltraMarketIntelEnabled)
      mkt = UltraMarketIntel_Approved();
   if(mkt) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_MKTINTEL;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_MKTINTEL;

   // 3) Structure Validation
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.bos.buy || u.choch.buy)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.bos.sell || u.choch.sell);
   if(structure) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_STRUCT;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_STRUCT;

   // 4) Liquidity Validation — genuine / confirmed / strong BOS (fake alone fails)
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

   // 5) Momentum Validation
   bool mom = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
                      : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);
   if(mom) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_MOM;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_MOM;

   // 6) Multi-Timeframe Validation
   string mtfWhy = "";
   bool mtf = UltraMTF_NoConflict(s, buySide, mtfWhy);
   int master = UltraMTF_MasterDir(s);
   if(buySide && master < 0) mtf = false;
   if(!buySide && master > 0) mtf = false;
   if(mtf) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_MTF;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_MTF;

   // 7) Trade Thesis Validation — clear directional thesis shape (pre-fill)
   bool thesis = false;
   if(buySide)
      thesis = (u.bos.buy || u.choch.buy || UltraLiq_IsGenuine(u, true) ||
                (u.trend.bull && (u.ict.instZoneBuy || u.fib.atBuyZone || u.ict.inDiscount)));
   else
      thesis = (u.bos.sell || u.choch.sell || UltraLiq_IsGenuine(u, false) ||
                (u.trend.bear && (u.ict.instZoneSell || u.fib.atSellZone || u.ict.inPremium)));
   if(thesis) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_THESIS;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_THESIS;

   // 8) Confidence Validation — never lowered for news/vol
   int confFloor = UltraNewsExecMinConf;
   if(confFloor < UltraEventMinConf) confFloor = UltraEventMinConf;
   bool confOK = (u.score.confidence >= confFloor);
   if(confOK) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_CONF;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_CONF;

   // 9) Risk Validation
   string capWhy = "";
   bool riskOK = UltraCapitalOK(capWhy);
   if(MaxOpenTrades > 0 && UltraExec_OpenCountMagic() >= MaxOpenTrades)
   {
      riskOK = false;
      capWhy = "max open reached";
   }
   if(riskOK) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_RISK;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_RISK;

   // 10) Execution Validation
   string exWhy = "";
   bool execOK = UltraExecReady(s, exWhy);
   // Elevated spread NEVER sole-fails exec (product lock) — still require trade mode
   if(execOK) g_UltraNewsExec.passMask |= ULTRA_NEWS_VAL_EXEC;
   else g_UltraNewsExec.failMask |= ULTRA_NEWS_VAL_EXEC;

   // Optional: Validation Chain must be Mission-ready during news
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
      why = "NEWS_VAL incomplete mask=" + IntegerToString(g_UltraNewsExec.passMask) +
            "/" + IntegerToString(ULTRA_NEWS_VAL_ALL) +
            " fail=" + IntegerToString(g_UltraNewsExec.failMask);
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_TREND) != 0) why += " trend";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_MKTINTEL) != 0) why += " market";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_STRUCT) != 0) why += " structure";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_LIQ) != 0) why += " liquidity";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_MOM) != 0) why += " momentum";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_MTF) != 0) why += " mtf";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_THESIS) != 0) why += " thesis";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_CONF) != 0) why += " confidence";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_RISK) != 0) why += " risk";
      if((g_UltraNewsExec.failMask & ULTRA_NEWS_VAL_EXEC) != 0) why += " exec";
      g_UltraNewsExec.lastWhy = why;
      g_UltraNewsExec.lastSignalValid = false;
      return false;
   }

   why = "NEWS_VAL PASS event=" + g_UltraNewsExec.eventName +
         " phase=" + g_UltraNewsExec.phase +
         " conf=" + IntegerToString(u.score.confidence);
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

   // Proprietary strategy remains fully validated — allow
   why = "NEWS_EXEC READY event=" + g_UltraNewsExec.eventName +
         " | " + vWhy + " | " + evWhy;
   g_UltraNewsExec.lastTradeAllowed = true;
   g_UltraNewsExec.lastWhy = why;
   g_UltraNewsExec.lastSpread = u.ctx.spreadPts;
   g_UltraNewsExec.lastSlip = u.ctx.slipProxy;
   g_UltraNewsExec.lastExecQ = g_UltraEventLast.execQuality;
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
}

void UltraNewsExec_NoteFill(const ulong ticket, const string s, const bool buySide,
                            const string detail)
{
   if(!UltraNewsExecEnabled) return;
   if(!g_UltraNewsExec.newsMode && g_UltraNewsExec.eventFireCount == 0) return;
   g_UltraNewsExec.fillOkCount++;
   g_UltraNewsExec.lastFillDetail = detail;
   string side = buySide ? "BUY" : "SELL";
   string msg = "NEWS_FILL event=" + g_UltraNewsExec.eventName +
                " ticket=" + IntegerToString((int)ticket) +
                " " + side + " " + detail +
                " spr=" + DoubleToString(g_UltraNewsExec.lastSpread, 0) +
                " slip=" + DoubleToString(g_UltraNewsExec.lastSlip, 1);
   UltraLogDecision("EVENT_FILL", ticket, side, g_UltraNewsExec.eventName,
                    g_UltraNewsExec.lastConf, g_UltraNewsExec.impact,
                    g_UltraNewsExec.phase, "FILL", g_UltraNewsExec.lastSpread,
                    g_UltraNewsExec.lastSlip, msg);
   if(UltraNewsExecLog)
      UltraLog(msg + " on " + s);

   // Instant position verification
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
   g_UltraNewsExec.lastSpread = 0;
   g_UltraNewsExec.lastSlip = 0;
   g_UltraNewsExec.lastExecQ = 100;
   g_UltraNewsExec.lastConf = 0;
   g_UltraNewsExec.lastWhy = "boot";
   g_UltraNewsExec.lastFillDetail = "";
   if(UltraNewsExecLog)
   {
      UltraLog("NEWS_EXEC ∞ boot Enabled=" + (UltraNewsExecEnabled ? "Y" : "N") +
               " InstantPath=" + (UltraNewsExecInstantPath ? "Y" : "N") +
               " ForceReanalyze=" + (UltraNewsExecForceReanalyze ? "Y" : "N") +
               " BUILD=HA_ULTRA_93");
   }
}

string UltraNewsExec_Dashboard()
{
   string t = "NEWS_EXEC: ";
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
   if(g_UltraNewsExec.newsMode)
   {
      t += " mask=";
      t += IntegerToString(g_UltraNewsExec.passMask);
      t += "/";
      t += IntegerToString(ULTRA_NEWS_VAL_ALL);
   }
   return t;
}

#endif // HITMAN_ULTRA_NEWS_EXECUTION_MQH
