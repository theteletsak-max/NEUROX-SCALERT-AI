#ifndef HITMAN_ULTRA_BUG_ELIMINATION_MQH
#define HITMAN_ULTRA_BUG_ELIMINATION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA BUG ELIMINATION ENGINE ∞                       |
//| Final Module Order: Phase 17 MAINTENANCE (core detector)         |
//| Historical design note: Phase 19                                 |
//| Stability · reliability · no silent failures · explain every path|
//| NOT a new strategy — audit + structured logging only             |
//+------------------------------------------------------------------+

struct UltraBugAudit
{
   bool   initOK;
   bool   deinitOK;
   bool   timerOK;
   bool   memoryOK;
   bool   indicatorsOK;
   bool   objectsOK;
   bool   handlesOK;
   bool   brokerOK;
   bool   symbolOK;
   bool   backtestOK;
   int    criticalCount;
   int    warnCount;
   int    explainCount;
   int    waitCount;
   int    rejectCount;
   int    execFailCount;
   int    signalWarnCount;
   int    positionWarnCount;
   long   lastTickMs;
   long   lastPerfMs;
   long   maxTickMs;
   string lastAction;
   string lastModule;
   string lastFunction;
   string lastReason;
   string summary;
   datetime ts;
};

UltraBugAudit g_UltraBug;

string   g_UltraBug_LastKey = "";
datetime g_UltraBug_LastBar = 0;

//--------------------------------------------------------------------//
int UltraBug_ClampI(const int v, const int lo, const int hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

bool UltraBug_ShouldPrint(const string key)
{
   datetime bar = iTime(_Symbol, UltraETF(), 0);
   if(bar > 0 && bar == g_UltraBug_LastBar && key == g_UltraBug_LastKey)
      return false;
   g_UltraBug_LastBar = bar;
   g_UltraBug_LastKey = key;
   return true;
}

//--------------------------------------------------------------------//
// STRUCTURED EXPLAIN — every WAIT / REJECT / TRADE / EXIT / REPLACE   //
//--------------------------------------------------------------------//
void UltraBug_Explain(const string action,
                      const string module,
                      const string func,
                      const string reason,
                      const string side,
                      const ulong ticket)
{
   if(!UltraBugEnabled) return;

   g_UltraBug.explainCount++;
   g_UltraBug.lastAction = action;
   g_UltraBug.lastModule = module;
   g_UltraBug.lastFunction = func;
   g_UltraBug.lastReason = reason;
   g_UltraBug.ts = TimeCurrent();

   if(action == "WAIT") g_UltraBug.waitCount++;
   else if(action == "REJECT" || action == "TRADE_REJECTED" || action == "NO_TRADE")
      g_UltraBug.rejectCount++;
   else if(action == "EXEC_FAIL") g_UltraBug.execFailCount++;

   string key = action + "|" + module + "|" + func + "|" + reason;
   bool doPrint = UltraBug_ShouldPrint(key);

   UltraSnap u = g_UltraLastSnap;
   long spr = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spr);
   if(u.ctx.spreadPts > 0.0) spr = (long)u.ctx.spreadPts;

   string trend = "FLAT";
   if(u.trend.bull && !u.trend.bear) trend = "BULL";
   else if(u.trend.bear && !u.trend.bull) trend = "BEAR";

   string news = u.ctx.eventClass;
   if(StringLen(news) == 0) news = "NONE";

   // Always persist structured decision (logger may filter Print)
   UltraLogDecision(action, ticket, side, module, u.score.confidence, u.score.confluence,
                    func, news, (double)spr, u.ctx.slipProxy, reason);

   if(!doPrint) return;
   if(!(UltraBugLogExplain || UltraLoggingEnabled || EnableVerboseLogging))
      return;

   string t = "";
   t += "══════════════════════════════════\n";
   t += "ULTRA EXPLAIN\n";
   t += "Action: "; t += action; t += "\n";
   t += "Module: "; t += module; t += "\n";
   t += "Function: "; t += func; t += "\n";
   t += "Reason: "; t += reason; t += "\n";
   t += "Side: "; t += side; t += "\n";
   t += "Ticket: "; t += IntegerToString((int)ticket); t += "\n";
   t += "Confidence: "; t += IntegerToString(u.score.confidence); t += "%\n";
   t += "Spread: "; t += IntegerToString((int)spr); t += "\n";
   t += "Trend: "; t += trend; t += "\n";
   t += "Session: "; t += (StringLen(u.ctx.session) > 0 ? u.ctx.session : "-"); t += "\n";
   t += "News/Event: "; t += news; t += " / "; t += u.ctx.newsPhase; t += "\n";
   t += "Mode: "; t += UltraBT_ModeName(); t += "\n";
   t += "══════════════════════════════════";
   Print(t);
}

//--------------------------------------------------------------------//
// SIGNAL AUDIT                                                        //
//--------------------------------------------------------------------//
bool UltraBug_AuditSignal(const string s, const UltraSignal &sig, string &why)
{
   why = "";
   if(!UltraBugEnabled || !UltraBugSignalAudit) return true;

   if(sig.buy && sig.sell)
   {
      why = "conflicting BUY+SELL signal";
      g_UltraBug.signalWarnCount++;
      g_UltraBug.warnCount++;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditSignal", why, "BOTH");
      return false;
   }
   if(!sig.buy && !sig.sell)
   {
      why = "missing directional signal";
      g_UltraBug.signalWarnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditSignal", why);
      return false;
   }
   if(StringLen(sig.tag) == 0 || sig.tag == "NONE")
   {
      why = "invalid/empty strategy tag";
      g_UltraBug.signalWarnCount++;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditSignal", why,
                       sig.buy ? "BUY" : "SELL");
      return false;
   }

   int conf = g_UltraLastSnap.score.confidence;
   if(conf < 0 || conf > 100)
   {
      why = "invalid confidence ";
      why += IntegerToString(conf);
      g_UltraBug.signalWarnCount++;
      g_UltraBug.criticalCount++;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditSignal", why,
                       sig.buy ? "BUY" : "SELL");
      return false;
   }

   // Duplicate fire same bar + same direction (soft warn — UFSE lock is authority)
   static string lastSym = "";
   static datetime lastBar = 0;
   static bool lastBuy = false;
   static string lastTag = "";
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar > 0 && bar == lastBar && s == lastSym && sig.buy == lastBuy && sig.tag == lastTag)
   {
      // Not a hard reject — SignalLock owns duplicates; log once
      g_UltraBug.signalWarnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditSignal",
                       "duplicate signal same bar (lock should gate)",
                       sig.buy ? "BUY" : "SELL");
   }
   lastSym = s; lastBar = bar; lastBuy = sig.buy; lastTag = sig.tag;
   return true;
}

//--------------------------------------------------------------------//
// EXECUTION AUDIT                                                     //
//--------------------------------------------------------------------//
void UltraBug_ExplainExecFail(const string func, const string side,
                              const uint retcode, const string detail)
{
   if(!UltraBugEnabled || !UltraBugExecAudit) return;
   string why = "retcode=";
   why += IntegerToString((int)retcode);
   why += " ";
   why += detail;
   if(retcode == TRADE_RETCODE_INVALID_VOLUME) why += " | invalid volume";
   else if(retcode == TRADE_RETCODE_INVALID_STOPS) why += " | invalid stops";
   else if(retcode == TRADE_RETCODE_INVALID_FILL) why += " | invalid fill";
   else if(retcode == TRADE_RETCODE_REQUOTE) why += " | requote";
   else if(retcode == TRADE_RETCODE_REJECT) why += " | broker reject";
   else if(retcode == TRADE_RETCODE_NO_MONEY) why += " | no money";
   else if(retcode == TRADE_RETCODE_MARKET_CLOSED) why += " | market closed";
   else if(retcode == TRADE_RETCODE_PRICE_OFF) why += " | price off";
   g_UltraBug.execFailCount++;
   UltraBug_Explain("EXEC_FAIL", "Shell_B", func, why, side);
}

bool UltraBug_AuditStops(const string s, const bool isBuy, const double entry,
                         const double sl, const double tp, string &why)
{
   why = "";
   if(!UltraBugEnabled || !UltraBugExecAudit) return true;
   long stopLevel = 0, freezeLevel = 0, digits = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL, stopLevel);
   SymbolInfoInteger(s, SYMBOL_TRADE_FREEZE_LEVEL, freezeLevel);
   SymbolInfoInteger(s, SYMBOL_DIGITS, digits);
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   double minDist = (double)stopLevel * point;
   double freeze = (double)freezeLevel * point;

   if(sl <= 0.0)
   {
      why = "SL missing";
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditStops", why, isBuy ? "BUY" : "SELL");
      return false;
   }
   double slDist = MathAbs(entry - sl);
   if(minDist > 0.0 && slDist + point * 0.1 < minDist)
   {
      why = "SL inside stop level";
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditStops", why, isBuy ? "BUY" : "SELL");
      return false;
   }
   if(tp > 0.0)
   {
      double tpDist = MathAbs(tp - entry);
      if(minDist > 0.0 && tpDist + point * 0.1 < minDist)
      {
         why = "TP inside stop level";
         UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditStops", why, isBuy ? "BUY" : "SELL");
         return false;
      }
   }
   if(freeze > 0.0 && slDist < freeze)
   {
      // Soft warn — freeze can block modify; not always entry-blocking
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditStops",
                       "SL near freeze level", isBuy ? "BUY" : "SELL");
   }
   if(isBuy && !(sl < entry))
   {
      why = "BUY SL must be below entry";
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditStops", why, "BUY");
      return false;
   }
   if(!isBuy && !(sl > entry))
   {
      why = "SELL SL must be above entry";
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditStops", why, "SELL");
      return false;
   }
   return true;
}

//--------------------------------------------------------------------//
// POSITION AUDIT                                                      //
//--------------------------------------------------------------------//
void UltraBug_AuditPositions(const string s)
{
   if(!UltraBugEnabled || !UltraBugPositionAudit) return;

   int eaPos = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      eaPos++;

      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(sl <= 0.0)
      {
         g_UltraBug.positionWarnCount++;
         g_UltraBug.warnCount++;
         UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditPositions",
                          "position missing SL", 
                          PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL",
                          ticket);
      }
      // Sync lock presence
      if(UltraPosLock_Find(ticket) < 0)
      {
         g_UltraBug.positionWarnCount++;
         UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditPositions",
                          "position not in Mission lock — re-register soft",
                          PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL",
                          ticket);
         UltraPosLock_Register(ticket, s,
                               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY,
                               "BUG_SYNC");
      }
   }
}

//--------------------------------------------------------------------//
// BROKER / SYMBOL AUDIT                                               //
//--------------------------------------------------------------------//
bool UltraBug_AuditBroker(const string s, string &why)
{
   why = "";
   if(!UltraBugEnabled || !UltraBugBrokerAudit) return true;

   long digits = 0;
   SymbolInfoInteger(s, SYMBOL_DIGITS, digits);
   double tickSize = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   double minLot = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   long fillMode = 0;
   SymbolInfoInteger(s, SYMBOL_FILLING_MODE, fillMode);
   ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(s, SYMBOL_TRADE_MODE);
   long accountMarginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);

   g_UltraBug.symbolOK = (digits >= 0 && tickSize > 0.0 && point > 0.0 && minLot > 0.0 && lotStep > 0.0);
   g_UltraBug.brokerOK = (tradeMode != SYMBOL_TRADE_MODE_DISABLED);

   if(!g_UltraBug.symbolOK)
   {
      why = "symbol specs invalid (digits/tick/point/lot)";
      g_UltraBug.criticalCount++;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditBroker", why);
      return false;
   }
   if(!g_UltraBug.brokerOK)
   {
      why = "symbol trade mode disabled";
      g_UltraBug.criticalCount++;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditBroker", why);
      return false;
   }

   // Hedging vs netting — informational (never blocks)
   if(UltraBugLogExplain && UltraBugLogBoot)
   {
      string am = "NETTING";
      if(accountMarginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) am = "HEDGING";
      else if(accountMarginMode == ACCOUNT_MARGIN_MODE_EXCHANGE) am = "EXCHANGE";
      UltraLog("BUG AUDIT broker account=" + am +
               " digits=" + IntegerToString((int)digits) +
               " tick=" + DoubleToString(tickSize, (int)digits) +
               " fillMode=" + IntegerToString((int)fillMode));
   }
   return true;
}

//--------------------------------------------------------------------//
// INIT / DEINIT / HANDLES / TIMER / MEMORY                            //
// Handle counts are reported from Shell_B (arrays live there).        //
//--------------------------------------------------------------------//
void UltraBug_NoteHandles(const int badCount, const int totalChecked)
{
   g_UltraBug.handlesOK = (badCount == 0);
   g_UltraBug.indicatorsOK = g_UltraBug.handlesOK;
   if(badCount > 0)
   {
      g_UltraBug.criticalCount++;
      string why = "invalid indicator handles=";
      why += IntegerToString(badCount);
      why += "/";
      why += IntegerToString(totalChecked);
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_NoteHandles", why);
   }
}

bool UltraBug_AuditInit(const string s)
{
   // Preserve handle notes already set by Shell_B InitializeIndicators
   bool handlesWasOK = g_UltraBug.handlesOK;
   int crit = g_UltraBug.criticalCount;
   int warn = g_UltraBug.warnCount;
   int expl = g_UltraBug.explainCount;

   ZeroMemory(g_UltraBug);
   g_UltraBug.handlesOK = handlesWasOK;
   g_UltraBug.indicatorsOK = handlesWasOK;
   g_UltraBug.criticalCount = crit;
   g_UltraBug.warnCount = warn;
   g_UltraBug.explainCount = expl;
   g_UltraBug.initOK = true;
   g_UltraBug.deinitOK = true;
   g_UltraBug.timerOK = true;
   g_UltraBug.memoryOK = true;
   g_UltraBug.objectsOK = true;
   g_UltraBug.backtestOK = true;
   g_UltraBug.summary = "INIT";
   g_UltraBug.ts = TimeCurrent();

   if(!UltraBugEnabled) return true;

   // TradeComment lock
   if(StringCompare(TradeComment, "HITMAN AI") != 0)
   {
      g_UltraBug.initOK = false;
      g_UltraBug.criticalCount++;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditInit",
                       "TradeComment must be exactly HITMAN AI");
   }

   // Timer
   if(EnableMultiSymbolTrading)
   {
      g_UltraBug.timerOK = (MultiSymbolTimerSeconds > 0);
      if(!g_UltraBug.timerOK)
      {
         g_UltraBug.initOK = false;
         g_UltraBug.criticalCount++;
         UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditInit",
                          "invalid MultiSymbolTimerSeconds");
      }
   }

   // Handles / indicators (reported earlier via UltraBug_NoteHandles)
   if(!g_UltraBug.handlesOK)
   {
      g_UltraBug.initOK = false;
      UltraBug_Explain("REJECT", "UltraBugElimination", "UltraBug_AuditInit",
                       "invalid indicator handles detected");
   }

   // Chart object (watermark)
   if(ObjectFind(0, BG_OBJECT_NAME) < 0)
   {
      g_UltraBug.objectsOK = false;
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditInit",
                       "chart background object missing (non-fatal)");
   }

   // Memory soft check
   if(UltraMemoryEngineEnabled && g_UltraMem.trades > 100000)
   {
      g_UltraBug.memoryOK = false;
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditInit",
                       "memory trade counter overflow risk");
   }

   string bWhy = "";
   if(!UltraBug_AuditBroker(s, bWhy))
      g_UltraBug.initOK = false;

   // Backtest compat presence
   g_UltraBug.backtestOK = UltraBacktestCompatEnabled;
   if(MQLInfoInteger(MQL_TESTER) && !UltraBacktestCompatEnabled)
   {
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditInit",
                       "tester without backtest compat enabled");
   }

   g_UltraBug.summary = g_UltraBug.initOK ? "INIT_OK" : "INIT_ISSUES";
   if(UltraBugLogBoot)
      UltraLog("BUG ELIMINATION ∞ " + g_UltraBug.summary +
               " crit=" + IntegerToString(g_UltraBug.criticalCount) +
               " warn=" + IntegerToString(g_UltraBug.warnCount) +
               " handles=" + (g_UltraBug.handlesOK ? "OK" : "BAD") +
               " broker=" + (g_UltraBug.brokerOK ? "OK" : "BAD") +
               " BUILD=HA_ULTRA_93");

   return g_UltraBug.initOK;
}

void UltraBug_AuditDeinit(const int reason)
{
   if(!UltraBugEnabled) return;
   g_UltraBug.deinitOK = true;

   // Ensure timer killed
   if(EnableMultiSymbolTrading)
      EventKillTimer();

   // Object cleanup verify
   if(ObjectFind(0, BG_OBJECT_NAME) >= 0)
   {
      ObjectDelete(0, BG_OBJECT_NAME);
      if(ObjectFind(0, BG_OBJECT_NAME) >= 0)
      {
         g_UltraBug.deinitOK = false;
         g_UltraBug.warnCount++;
         UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditDeinit",
                          "chart object delete failed");
      }
   }

   string why = "deinit reason=";
   why += IntegerToString(reason);
   why += " explains=";
   why += IntegerToString(g_UltraBug.explainCount);
   why += " rejects=";
   why += IntegerToString(g_UltraBug.rejectCount);
   why += " waits=";
   why += IntegerToString(g_UltraBug.waitCount);
   why += " execFail=";
   why += IntegerToString(g_UltraBug.execFailCount);
   if(UltraBugLogBoot)
      UltraLog("BUG ELIMINATION ∞ DEINIT " + why +
               " ok=" + (g_UltraBug.deinitOK ? "Y" : "N"));
}

//--------------------------------------------------------------------//
// PERFORMANCE AUDIT (lightweight tick latency)                        //
//--------------------------------------------------------------------//
void UltraBug_PerfBegin()
{
   if(!UltraBugEnabled || !UltraBugPerfAudit) return;
   g_UltraBug.lastPerfMs = (long)GetTickCount();
}

void UltraBug_PerfEnd(const string s)
{
   if(!UltraBugEnabled || !UltraBugPerfAudit) return;
   long now = (long)GetTickCount();
   long dt = now - g_UltraBug.lastPerfMs;
   if(dt < 0) dt = 0;
   g_UltraBug.lastTickMs = dt;
   if(dt > g_UltraBug.maxTickMs) g_UltraBug.maxTickMs = dt;
   if(dt >= UltraBugPerfWarnMs)
   {
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_PerfEnd",
                       "tick latency high ms=" + IntegerToString((int)dt) + " on " + s);
   }
}

//--------------------------------------------------------------------//
// EVENT AUDIT (soft — never blocks)                                   //
//--------------------------------------------------------------------//
void UltraBug_AuditEvent(const UltraSnap &u)
{
   if(!UltraBugEnabled || !UltraBugEventAudit) return;
   // Ensure news/session fields are populated when engines claim activity
   if(UltraNewsExec_IsNewsMode() && StringLen(u.ctx.eventClass) == 0)
   {
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditEvent",
                       "news mode on but eventClass empty");
   }
   if(UltraSessionEngineEnabled && StringLen(u.ctx.session) == 0)
   {
      g_UltraBug.warnCount++;
      UltraBug_Explain("WAIT", "UltraBugElimination", "UltraBug_AuditEvent",
                       "session engine on but session empty");
   }
}

//--------------------------------------------------------------------//
void UltraBug_Boot()
{
   ZeroMemory(g_UltraBug);
   g_UltraBug.initOK = true;
   g_UltraBug.deinitOK = true;
   g_UltraBug.handlesOK = true;
   g_UltraBug.indicatorsOK = true;
   g_UltraBug.summary = "BOOT";
   if(UltraBugLogBoot)
      UltraLog("BUG ELIMINATION ∞ boot Enabled=" + (UltraBugEnabled ? "Y" : "N") +
               " Signal=" + (UltraBugSignalAudit ? "Y" : "N") +
               " Exec=" + (UltraBugExecAudit ? "Y" : "N") +
               " Pos=" + (UltraBugPositionAudit ? "Y" : "N") +
               " Broker=" + (UltraBugBrokerAudit ? "Y" : "N") +
               " Perf=" + (UltraBugPerfAudit ? "Y" : "N") +
               " Explain=ALWAYS BUILD=HA_ULTRA_93");
}

void UltraBug_OnTick(const string s)
{
   if(!UltraBugEnabled) return;
   static long lastPosAudit = 0;
   long now = (long)GetTickCount();
   if(UltraBugPositionAudit && (lastPosAudit <= 0 || (now - lastPosAudit) >= UltraBugPositionAuditMs))
   {
      lastPosAudit = now;
      UltraBug_AuditPositions(s);
   }
}

string UltraBug_Dashboard()
{
   string t = "BUG: ";
   if(!UltraBugEnabled) { t += "OFF"; return t; }
   t += g_UltraBug.initOK ? "OK" : "INIT!";
   t += " expl=";
   t += IntegerToString(g_UltraBug.explainCount);
   t += " rej=";
   t += IntegerToString(g_UltraBug.rejectCount);
   t += " wait=";
   t += IntegerToString(g_UltraBug.waitCount);
   t += " execFail=";
   t += IntegerToString(g_UltraBug.execFailCount);
   t += " crit=";
   t += IntegerToString(g_UltraBug.criticalCount);
   if(g_UltraBug.lastTickMs > 0)
   {
      t += " tickMs=";
      t += IntegerToString((int)g_UltraBug.lastTickMs);
   }
   if(StringLen(g_UltraBug.lastAction) > 0)
   {
      t += " | ";
      t += g_UltraBug.lastAction;
   }
   return t;
}

#endif // HITMAN_ULTRA_BUG_ELIMINATION_MQH
