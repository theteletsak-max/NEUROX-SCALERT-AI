#ifndef HITMAN_ULTRA_39_EVENTS_MQH
#define HITMAN_ULTRA_39_EVENTS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 39_ULTRA EVENT TRADING ENGINE ∞ (Phase 16)           |
//| Always active · No news shutdown · No spread-only reject         |
//| Full re-analysis → Mission Control → Execute or Remain Flat      |
//+------------------------------------------------------------------+

enum ENUM_ULTRA_EVENT
{
   UEV_INIT = 0,
   UEV_TICK,
   UEV_TIMER,
   UEV_TRADE_TX,
   UEV_CHART,
   UEV_DEINIT,
   UEV_BOS,
   UEV_CHOCH,
   UEV_SWEEP,
   UEV_FIRE,
   UEV_WAIT,
   UEV_EVENT_TRADE,
   UEV_EVENT_FLAT
};

struct UltraEventStats
{
   ulong initCount;
   ulong tickCount;
   ulong timerCount;
   ulong tradeTxCount;
   ulong chartCount;
   ulong deinitCount;
   ulong bosCount;
   ulong chochCount;
   ulong sweepCount;
   ulong fireCount;
   ulong waitCount;
   ulong eventTradeCount;
   ulong eventFlatCount;
   datetime lastMarketEvent;
   datetime lastTickTs;
   long   tickWindowStartMs;
   int    ticksInWindow;
   double tickSpeed;
   string lastMarketTag;
   string lastEventClass;
   string lastDecision;
};

struct UltraEventAssessment
{
   bool   active;            // BEFORE/DURING/AFTER event context
   string phase;
   string eventClass;
   int    impact;
   double spreadPts;
   double slipProxy;
   double tickSpeed;
   double atrRel;
   int    liqScore;
   int    volScore;
   int    execQuality;
   int    eventConfidence;
   bool   spreadElevated;
   bool   volElevated;
   bool   liqThin;
   bool   execAcceptable;
   bool   setupValid;
   bool   allowTrade;        // false only if complete strategy fails (never news/spread alone)
   string reason;
};

UltraEventStats      g_UltraEventStats;
UltraEventAssessment g_UltraEventLast;

void UltraEvent_Note(const ENUM_ULTRA_EVENT e)
{
   switch(e)
   {
      case UEV_INIT:        g_UltraEventStats.initCount++; break;
      case UEV_TICK:        g_UltraEventStats.tickCount++; break;
      case UEV_TIMER:       g_UltraEventStats.timerCount++; break;
      case UEV_TRADE_TX:    g_UltraEventStats.tradeTxCount++; break;
      case UEV_CHART:       g_UltraEventStats.chartCount++; break;
      case UEV_DEINIT:      g_UltraEventStats.deinitCount++; break;
      case UEV_BOS:         g_UltraEventStats.bosCount++; break;
      case UEV_CHOCH:       g_UltraEventStats.chochCount++; break;
      case UEV_SWEEP:       g_UltraEventStats.sweepCount++; break;
      case UEV_FIRE:        g_UltraEventStats.fireCount++; break;
      case UEV_WAIT:        g_UltraEventStats.waitCount++; break;
      case UEV_EVENT_TRADE: g_UltraEventStats.eventTradeCount++; break;
      case UEV_EVENT_FLAT:  g_UltraEventStats.eventFlatCount++; break;
   }
}

void UltraEvent_OnTickPulse()
{
   UltraEvent_Note(UEV_TICK);
   long now = (long)GetTickCount();
   if(g_UltraEventStats.tickWindowStartMs <= 0)
   {
      g_UltraEventStats.tickWindowStartMs = now;
      g_UltraEventStats.ticksInWindow = 1;
      return;
   }
   g_UltraEventStats.ticksInWindow++;
   long elapsed = now - g_UltraEventStats.tickWindowStartMs;
   if(elapsed >= 1000)
   {
      g_UltraEventStats.tickSpeed = (double)g_UltraEventStats.ticksInWindow * 1000.0 / (double)elapsed;
      g_UltraEventStats.tickWindowStartMs = now;
      g_UltraEventStats.ticksInWindow = 0;
   }
   g_UltraEventStats.lastTickTs = TimeCurrent();
}

void UltraEvent_NoteMarket(const UltraSnap &u)
{
   bool edged = false;
   if(u.bos.buy || u.bos.sell)
   {
      UltraEvent_Note(UEV_BOS);
      g_UltraEventStats.lastMarketTag = "BOS";
      edged = true;
   }
   if(u.choch.buy || u.choch.sell)
   {
      UltraEvent_Note(UEV_CHOCH);
      g_UltraEventStats.lastMarketTag = "CHoCH";
      edged = true;
   }
   if(u.liq.sweepBuy || u.liq.sweepSell || u.liq.stopHuntBuy || u.liq.stopHuntSell)
   {
      UltraEvent_Note(UEV_SWEEP);
      g_UltraEventStats.lastMarketTag = "SWEEP";
      edged = true;
   }
   if(edged)
      g_UltraEventStats.lastMarketEvent = TimeCurrent();

   // Propagate tick/exec into snap context for logger/dashboard
   // (caller holds non-const in BuildSnapshot path via separate assign)
}

//--------------------------------------------------------------------//
// Dynamic intelligence: spread · slippage · liquidity · volatility   //
//--------------------------------------------------------------------//
void UltraEvent_AssessMarket(const string s, const UltraSnap &u, UltraEventAssessment &a)
{
   a.phase = u.ctx.newsPhase;
   a.eventClass = u.ctx.eventClass;
   a.impact = u.ctx.eventImpact;
   a.spreadPts = u.ctx.spreadPts;
   a.slipProxy = u.ctx.slipProxy;
   a.tickSpeed = g_UltraEventStats.tickSpeed;
   a.atrRel = u.vol.relative;
   a.eventConfidence = u.ctx.eventConfidence;
   a.active = (u.ctx.beforeNews || u.ctx.duringNews || u.ctx.afterNews ||
               (StringLen(u.ctx.eventClass) > 0 && u.ctx.eventClass != "NONE"));

   a.spreadElevated = (a.spreadPts >= UltraEventSpreadWarnPts);
   a.volElevated = (u.vol.expansion && u.vol.relative >= 1.45);
   a.liqThin = (u.liq.quality < 35 && !u.liq.genuineBuy && !u.liq.genuineSell);

   // Liquidity score
   int lq = (int)MathRound(u.liq.quality);
   if(u.liq.genuineBuy || u.liq.genuineSell) lq = MathMax(lq, 70);
   if(u.liq.fakeBuy || u.liq.fakeSell) lq = MathMin(lq, 35);
   a.liqScore = MathMax(0, MathMin(100, lq));

   // Volatility score
   int vs = 40;
   if(u.vol.expansion) vs += 25;
   if(u.vol.relative >= 1.8) vs += 20;
   else if(u.vol.relative >= 1.45) vs += 10;
   if(u.vol.compression) vs -= 15;
   a.volScore = MathMax(0, MathMin(100, vs));

   // Execution quality — terminal/broker/tick/spread context (never sole reject)
   // Note: no call into Defense module (assembled later)
   int eq = 70;
   if((bool)TerminalInfoInteger(TERMINAL_CONNECTED) &&
      (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
      (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0))
      eq += 15;
   else
      eq -= 30;
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) || tm == 0) eq -= 20;
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0) eq -= 25;
   if(a.tickSpeed >= 2.0) eq += 10;
   else if(a.tickSpeed > 0.0 && a.tickSpeed < 0.3) eq -= 15;
   if(a.spreadElevated) eq -= 8; // soft only — never sole reject
   if(a.liqThin) eq -= 10;
   a.execQuality = MathMax(0, MathMin(100, eq));
   a.execAcceptable = (a.execQuality >= UltraEventExecQualityMin) || !a.active;
}

//--------------------------------------------------------------------//
// Complete proprietary strategy validation during events             //
//--------------------------------------------------------------------//
bool UltraEvent_ValidateSetup(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   // Trend
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull)
                        : (u.trend.bear || u.trend.htfBear || u.trend.macroBear);
   // Structure
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   // BOS / CHoCH
   bool bosCh = buySide ? (u.bos.buy || u.choch.buy) : (u.bos.sell || u.choch.sell);
   bool bosStrong = buySide
      ? ((u.bos.buy && (u.bos.confirmed || u.bos.strong)) || (u.choch.buy && u.choch.majorC))
      : ((u.bos.sell && (u.bos.confirmed || u.bos.strong)) || (u.choch.sell && u.choch.majorC));
   // Liquidity — genuine preferred; fake alone fails
   if(UltraLiq_IsFakeSweep(u, buySide) && !UltraLiq_IsGenuine(u, buySide) && !bosStrong)
   {
      why = "EVENT: fake sweep / no strong BOS";
      return false;
   }
   bool liqOK = UltraLiq_IsGenuine(u, buySide) ||
                (buySide ? (u.liq.confirmedBuy || u.liq.equalLows) : (u.liq.confirmedSell || u.liq.equalHighs)) ||
                bosStrong;
   // OB / FVG — reject weak-only
   bool instOK = UltraICT_StrongOB(u, buySide) ||
                 (buySide ? (u.ict.fvgBuy && !u.ict.weakFVGBuy) : (u.ict.fvgSell && !u.ict.weakFVGSell)) ||
                 (buySide ? u.ict.instZoneBuy : u.ict.instZoneSell) ||
                 bosStrong || UltraLiq_IsGenuine(u, buySide);
   // Fib / zone
   bool fibOK = buySide ? (u.fib.atBuyZone || u.ict.inDiscount) : (u.fib.atSellZone || u.ict.inPremium);
   // Momentum
   bool momOK = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
                        : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);
   // MTF — higher TF must not be strongly against (snap flags; MTF module assembled later)
   bool mtfOK = buySide ? !(u.trend.htfBear && u.trend.macroBear)
                        : !(u.trend.htfBull && u.trend.macroBull);

   int hits = (trend?1:0)+(structure?1:0)+(bosCh?1:0)+(liqOK?1:0)+(instOK?1:0)+(fibOK?1:0)+(momOK?1:0)+(mtfOK?1:0);
   int need = u.ctx.duringNews ? 5 : 4;
   if(hits < need)
   {
      why = "EVENT: incomplete strategy " + IntegerToString(hits) + "/" + IntegerToString(need);
      return false;
   }
   if(u.score.confidence < UltraEventMinConf && u.ctx.duringNews)
   {
      why = "EVENT: confidence below event floor";
      return false;
   }
   return true;
}

//--------------------------------------------------------------------//
// Decision: assess → validate → allow / remain flat                  //
// RULES: never reject solely for news OR solely for elevated spread  //
//        never force a trade because of a news event                 //
//--------------------------------------------------------------------//
bool UltraEvent_AllowTrade(const string s, const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   UltraEventAssessment a;
   a.active = false;
   a.phase = "NONE";
   a.eventClass = "NONE";
   a.impact = 0;
   a.spreadPts = 0; a.slipProxy = 0; a.tickSpeed = 0; a.atrRel = 0;
   a.liqScore = 0; a.volScore = 0; a.execQuality = 100; a.eventConfidence = 0;
   a.spreadElevated = a.volElevated = a.liqThin = false;
   a.execAcceptable = true;
   a.setupValid = false;
   a.allowTrade = true;
   a.reason = "event engine idle";

   if(!UltraEventEngineEnabled)
   {
      g_UltraEventLast = a;
      return true; // engine off — do not interfere
   }

   UltraEvent_AssessMarket(s, u, a);
   // Propagate into mutable context mirrors via global last assessment
   g_UltraEventStats.lastEventClass = a.eventClass;

   // Always active — never automatic news/spread shutdown
   if(UltraEventAlwaysActive)
   {
      // informational only
   }

   // RULE: never reject solely because news is occurring
   if(UltraEventNeverNewsBlock && a.active && !a.setupValid)
   {
      // continue to full validation — news alone is not a reject
   }

   // RULE: never reject solely because spread is elevated
   if(UltraEventNeverSpreadBlock && a.spreadElevated)
   {
      // log later; do not return false here
   }

   // Outside event context — pass through (normal path continues)
   if(!a.active)
   {
      a.allowTrade = true;
      a.reason = "no active event context";
      g_UltraEventLast = a;
      return true;
   }

   // During event: require complete proprietary strategy (re-analysis)
   string vWhy = "";
   a.setupValid = UltraEvent_ValidateSetup(u, buySide, vWhy);

   // Execution quality: never sole-reject on spread; weak exec needs stronger setup
   if(a.setupValid)
   {
      a.allowTrade = true;
      a.reason = "EVENT VALID — full strategy + Mission path";
      if(a.spreadElevated) a.reason += " | spread elevated (allowed)";
      if(!a.execAcceptable)
      {
         if(UltraNewsExecStrongerOnWeakExec)
         {
            bool strong = (u.score.confidence >= UltraEventMinConf + 10) &&
                          (buySide
                           ? ((u.bos.buy && (u.bos.confirmed || u.bos.strong)) ||
                              UltraLiq_IsGenuine(u, true))
                           : ((u.bos.sell && (u.bos.confirmed || u.bos.strong)) ||
                              UltraLiq_IsGenuine(u, false)));
            bool momOK = buySide ? (u.mom.momBuy || u.mom.impulse)
                                 : (u.mom.momSell || u.mom.impulse);
            if(!(strong && momOK))
            {
               a.allowTrade = false;
               a.reason = "EVENT: exec quality weak — need stronger confirmed setup";
               UltraEvent_Note(UEV_EVENT_FLAT);
               g_UltraEventStats.lastDecision = "FLAT";
               g_UltraEventLast = a;
               why = a.reason;
               return false;
            }
            a.reason += " | exec weak but strong setup OK";
         }
         else
            a.reason += " | exec soft (setup still valid)";
      }
      UltraEvent_Note(UEV_EVENT_TRADE);
      g_UltraEventStats.lastDecision = "TRADE";
   }
   else
   {
      a.allowTrade = false;
      a.reason = (StringLen(vWhy) > 0) ? vWhy : "EVENT: remain flat — setup incomplete";
      UltraEvent_Note(UEV_EVENT_FLAT);
      g_UltraEventStats.lastDecision = "FLAT";
   }

   // RULE: never force a trade because of news
   if(UltraEventForceTrade)
   {
      // Force flag ignored for safety — still require setupValid
      if(!a.setupValid)
      {
         a.allowTrade = false;
         a.reason = "EVENT: force disabled — setup incomplete";
      }
   }

   g_UltraEventLast = a;

   if(UltraEventLogDecisions)
   {
      UltraLogDecision(a.allowTrade ? "EVENT_TRADE" : "EVENT_FLAT",
                       0,
                       buySide ? "BUY" : "SELL",
                       a.eventClass,
                       u.score.confidence,
                       a.eventConfidence,
                       a.phase,
                       a.phase,
                       a.spreadPts,
                       a.slipProxy,
                       a.reason);
   }

   if(!a.allowTrade)
   {
      why = a.reason;
      return false;
   }
   why = a.reason;
   return true;
}

void UltraEvent_OnBoot()
{
   UltraEvent_Note(UEV_INIT);
   g_UltraEventStats.tickSpeed = 0;
   g_UltraEventStats.tickWindowStartMs = 0;
   g_UltraEventStats.ticksInWindow = 0;
   g_UltraEventStats.lastDecision = "INIT";
   g_UltraEventStats.lastEventClass = "NONE";
   UltraLog("EVENT ENGINE ∞ boot — always active | no news shutdown | no spread-only block | BUILD=HA_ULTRA_93");
}

string UltraEvent_Summary()
{
   string t = "ticks=";
   t += IntegerToString((int)g_UltraEventStats.tickCount);
   t += " bos=";
   t += IntegerToString((int)g_UltraEventStats.bosCount);
   t += " choch=";
   t += IntegerToString((int)g_UltraEventStats.chochCount);
   t += " sweep=";
   t += IntegerToString((int)g_UltraEventStats.sweepCount);
   t += " fire=";
   t += IntegerToString((int)g_UltraEventStats.fireCount);
   t += " evtT=";
   t += IntegerToString((int)g_UltraEventStats.eventTradeCount);
   t += " evtF=";
   t += IntegerToString((int)g_UltraEventStats.eventFlatCount);
   return t;
}

string UltraEvent_Dashboard()
{
   string t = "EVENT: ";
   t += g_UltraEventLast.phase;
   t += " ";
   t += g_UltraEventLast.eventClass;
   t += " | spread=";
   t += DoubleToString(g_UltraEventLast.spreadPts, 0);
   t += " slip=";
   t += DoubleToString(g_UltraEventLast.slipProxy, 1);
   t += " execQ=";
   t += IntegerToString(g_UltraEventLast.execQuality);
   t += " spd=";
   t += DoubleToString(g_UltraEventStats.tickSpeed, 1);
   t += " | ";
   t += g_UltraEventStats.lastDecision;
   if(StringLen(g_UltraEventLast.reason) > 0)
   {
      t += "\nEVENT WHY: ";
      t += g_UltraEventLast.reason;
   }
   return t;
}

#endif
