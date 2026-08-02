#ifndef HITMAN_ULTRA_ZERO_FAIL_RECOVERY_MQH
#define HITMAN_ULTRA_ZERO_FAIL_RECOVERY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA ZERO-FAIL RECOVERY ENGINE ∞ (Phase 20)         |
//| Never stop operating because of a recoverable problem.           |
//| Monitor → Detect → Recover → Retry → Continue (never hang)       |
//| NOT a new strategy — stability recovery under Final Dev Rule     |
//+------------------------------------------------------------------+

// Shell_B implements these (indicator arrays / chart / filling live there)
bool   UltraZFR_ShellIndicatorsHealthy(const string s);
bool   UltraZFR_ShellRecoverIndicators(const string s);
bool   UltraZFR_ShellRecoverBuffers(const string s);
void   UltraZFR_ShellInvalidateIndicatorCache(const string s);
void   UltraZFR_ShellRecoverExecution(const string s);
string UltraZFR_ShellRecoverSymbol(const string s);
void   UltraZFR_ShellRecoverDashboard();

// UFSE — assembled after this module
void UltraUFSE_Invalidate(const string s);

// Dashboard text refresh — assembled later
void CreateDashboard();

struct UltraZFRState
{
   bool   booted;
   bool   lastConnected;
   bool   recovering;
   int    problemsFound;
   int    recoverAttempts;
   int    recoverSuccess;
   int    recoverFail;
   int    indicatorRecoveries;
   int    bufferRecoveries;
   int    memoryRecoveries;
   int    tradeRecoveries;
   int    positionRecoveries;
   int    execRecoveries;
   int    connectionRecoveries;
   int    symbolRecoveries;
   int    timeframeRecoveries;
   int    sessionRecoveries;
   int    eventRecoveries;
   int    dashboardRecoveries;
   int    loggerRecoveries;
   int    consecutiveFail;
   long   lastMonitorMs;
   long   lastRecoverMs;
   string lastProblem;
   string lastAction;
   string summary;
};

UltraZFRState g_UltraZFR;

//--------------------------------------------------------------------//
void UltraZFR_Log(const string msg)
{
   if(UltraZFRLog)
      UltraLog("ZFR ∞ " + msg);
}

void UltraZFR_NoteSuccess(const string domain)
{
   g_UltraZFR.recoverSuccess++;
   g_UltraZFR.consecutiveFail = 0;
   g_UltraZFR.lastAction = domain + ":OK";
   g_UltraZFR.recovering = false;
}

void UltraZFR_NoteFail(const string domain, const string why)
{
   g_UltraZFR.recoverFail++;
   g_UltraZFR.consecutiveFail++;
   g_UltraZFR.lastAction = domain + ":FAIL";
   g_UltraZFR.lastProblem = why;
   g_UltraZFR.recovering = false;
   UltraZFR_Log("FAIL " + domain + " | " + why + " | will retry — never stop");
   if(UltraBugEnabled)
      UltraBug_Explain("RECOVER", "UltraZeroFailRecovery", domain, why);
}

//--------------------------------------------------------------------//
bool UltraZFR_RecoverConnection(const string s)
{
   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   if(connected && g_UltraZFR.lastConnected)
      return true;

   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = connected ? "reconnect edge" : "connection loss";
   UltraRecover(g_UltraZFR.lastProblem);
   g_UltraZFR.connectionRecoveries++;

   MqlTick tick;
   bool tickOK = SymbolInfoTick(s, tick) && tick.bid > 0.0;
   g_UltraZFR.lastConnected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   if(g_UltraZFR.lastConnected && tickOK)
   {
      UltraZFR_NoteSuccess("CONNECTION");
      UltraZFR_Log("connection recovered tickOK on " + s);
      return true;
   }
   UltraZFR_NoteFail("CONNECTION", g_UltraZFR.lastProblem);
   return false;
}

bool UltraZFR_RecoverIndicators(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = "indicator handle/data";
   bool ok = UltraZFR_ShellRecoverIndicators(s);
   if(ok)
   {
      g_UltraZFR.indicatorRecoveries++;
      UltraZFR_NoteSuccess("INDICATORS");
      UltraZFR_Log("indicators recovered on " + s);
      return true;
   }
   UltraZFR_NoteFail("INDICATORS", "recreate failed on " + s);
   return false;
}

bool UltraZFR_RecoverBuffers(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = "buffer/copy";
   UltraZFR_ShellInvalidateIndicatorCache(s);
   UltraUFSE_Invalidate(s);
   bool ok = UltraZFR_ShellRecoverBuffers(s);
   if(ok)
   {
      g_UltraZFR.bufferRecoveries++;
      UltraZFR_NoteSuccess("BUFFERS");
      UltraZFR_Log("buffers recovered on " + s);
      return true;
   }
   UltraZFR_NoteFail("BUFFERS", "reload failed on " + s);
   return false;
}

bool UltraZFR_RecoverMemory()
{
   if(!UltraMemoryEngineEnabled) return true;
   if(g_UltraMem.trades > 100000 || g_UltraMem.trades < 0)
   {
      g_UltraZFR.recoverAttempts++;
      g_UltraZFR.recovering = true;
      g_UltraZFR.lastProblem = "memory counter overflow";
      g_UltraMem.trades = (int)MathMax(0, g_UltraMem.trades % 50000);
      g_UltraMem.lastSave = (long)TimeCurrent();
      g_UltraCore.memoryOK = true;
      g_UltraZFR.memoryRecoveries++;
      UltraZFR_NoteSuccess("MEMORY");
      UltraZFR_Log("memory soft-clamped");
      return true;
   }
   return true;
}

bool UltraZFR_RecoverPositions(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = "position sync";

   int synced = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      if(UltraPosLock_Find(ticket) < 0)
      {
         bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         UltraPosLock_Register(ticket, s, isBuy, "ZFR_SYNC");
         synced++;
      }
   }
   HistorySelect(TimeCurrent() - 86400, TimeCurrent() + 60);
   g_UltraZFR.positionRecoveries++;
   UltraZFR_NoteSuccess("POSITIONS");
   if(synced > 0)
      UltraZFR_Log("positions re-synced n=" + IntegerToString(synced) + " on " + s);
   return true;
}

bool UltraZFR_RecoverExecution(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = "execution context";
   UltraZFR_ShellRecoverExecution(s);
   g_UltraZFR.execRecoveries++;
   bool tradeOK = UltraBT_TradeAllowed();
   bool connOK = UltraBT_ConnectedOK();
   if(tradeOK && connOK)
   {
      UltraZFR_NoteSuccess("EXECUTION");
      UltraZFR_Log("execution context refreshed on " + s);
      return true;
   }
   UltraZFR_NoteFail("EXECUTION", tradeOK ? "connection" : "trade not allowed");
   return false;
}

bool UltraZFR_RecoverSymbol(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = "symbol";
   string det = UltraZFR_ShellRecoverSymbol(s);
   bool ok = (StringLen(det) > 0);
   if(ok)
   {
      g_UltraZFR.symbolRecoveries++;
      UltraZFR_NoteSuccess("SYMBOL");
      UltraZFR_Log("symbol OK " + det);
      return true;
   }
   UltraZFR_NoteFail("SYMBOL", "trade mode/bid invalid for " + s);
   return false;
}

bool UltraZFR_RecoverTimeframe(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   g_UltraZFR.lastProblem = "timeframe/history";
   ENUM_TIMEFRAMES tf = UltraETF();
   int bars = Bars(s, tf);
   datetime t0 = iTime(s, tf, 0);
   // Soft continue threshold — never stop scanning
   bool ok = (bars >= 30 && t0 > 0);
   g_UltraZFR.timeframeRecoveries++;
   if(ok)
   {
      UltraZFR_NoteSuccess("TIMEFRAME");
      return true;
   }
   UltraZFR_NoteFail("TIMEFRAME", "thin history bars=" + IntegerToString(bars));
   return false;
}

bool UltraZFR_RecoverSession(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   UltraSnap u = g_UltraLastSnap;
   UltraEngSession(s, u);
   g_UltraLastSnap.ctx = u.ctx;
   g_UltraZFR.sessionRecoveries++;
   UltraZFR_NoteSuccess("SESSION");
   UltraZFR_Log("session refreshed " + u.ctx.session);
   return true;
}

bool UltraZFR_RecoverEvent(const string s)
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   UltraNewsExec_OnTick(s);
   UltraMarketIntel_Validate(s);
   g_UltraZFR.eventRecoveries++;
   UltraZFR_NoteSuccess("EVENT");
   UltraZFR_Log("event/news context refreshed");
   return true;
}

bool UltraZFR_RecoverDashboard()
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   UltraZFR_ShellRecoverDashboard();
   CreateDashboard();
   g_UltraZFR.dashboardRecoveries++;
   UltraZFR_NoteSuccess("DASHBOARD");
   return true;
}

bool UltraZFR_RecoverLogger()
{
   g_UltraZFR.recoverAttempts++;
   g_UltraZFR.recovering = true;
   if(StringLen(g_UltraCore.lastError) > 200)
      g_UltraCore.lastError = "ZFR_trimmed";
   g_UltraZFR.loggerRecoveries++;
   UltraZFR_NoteSuccess("LOGGER");
   UltraLog("ZFR ∞ logger path verified");
   return true;
}

bool UltraZFR_RecoverTradeContext(const string s)
{
   g_UltraZFR.tradeRecoveries++;
   UltraRecover("trade context");
   return UltraZFR_RecoverExecution(s);
}

//--------------------------------------------------------------------//
// EXECUTION RETRY PREP — broker reject → analyse → correct → retry   //
//--------------------------------------------------------------------//
bool UltraZFR_PrepareExecRetry(const string s, const uint retcode, string &action)
{
   action = "";
   if(!UltraZFREnabled || !UltraZFRExecRecovery) return false;

   g_UltraZFR.problemsFound++;
   g_UltraZFR.lastProblem = "exec retcode=" + IntegerToString((int)retcode);

   if(retcode == TRADE_RETCODE_REQUOTE ||
      retcode == TRADE_RETCODE_PRICE_OFF ||
      retcode == TRADE_RETCODE_PRICE_CHANGED ||
      retcode == TRADE_RETCODE_TIMEOUT ||
      retcode == TRADE_RETCODE_CONNECTION ||
      retcode == TRADE_RETCODE_INVALID_FILL)
   {
      UltraZFR_ShellRecoverExecution(s);
      action = "refill+slip";
      g_UltraZFR.execRecoveries++;
      UltraZFR_Log("exec retry prep " + action + " ret=" + IntegerToString((int)retcode));
      return true;
   }
   if(retcode == TRADE_RETCODE_INVALID_STOPS)
   {
      action = "stops-fallback";
      g_UltraZFR.execRecoveries++;
      return true;
   }
   if(retcode == TRADE_RETCODE_LIMIT_VOLUME || retcode == TRADE_RETCODE_INVALID_VOLUME)
   {
      action = "volume-reject";
      UltraZFR_Log("volume reject — not auto-mutating lots (safety)");
      return false;
   }
   return false;
}

//--------------------------------------------------------------------//
// MONITOR — every tick verify → recover → continue (never stop)       //
//--------------------------------------------------------------------//
void UltraZFR_OnTick(const string s)
{
   if(!UltraZFREnabled) return;

   long now = (long)GetTickCount();
   int every = UltraZFRMonitorMs;
   if(every < 50) every = 50;
   if(g_UltraZFR.lastMonitorMs > 0 && (now - g_UltraZFR.lastMonitorMs) < every)
      return;
   g_UltraZFR.lastMonitorMs = now;

   if(g_UltraZFR.consecutiveFail > 0)
   {
      int backoff = UltraZFRRetryBackoffMs * MathMin(g_UltraZFR.consecutiveFail, 8);
      if(g_UltraZFR.lastRecoverMs > 0 && (now - g_UltraZFR.lastRecoverMs) < backoff)
         return;
   }

   bool need = false;
   string domain = "OK";

   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   if(UltraZFRConnectionRecovery && (!connected || (!g_UltraZFR.lastConnected && connected)))
   {
      need = true; domain = "CONNECTION";
      g_UltraZFR.problemsFound++;
      g_UltraZFR.lastRecoverMs = now;
      UltraZFR_RecoverConnection(s);
   }
   g_UltraZFR.lastConnected = connected;

   long tm = 0;
   bool modeOK = SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm);
   if(UltraZFRSymbolRecovery && (!modeOK || tm == 0 || SymbolInfoDouble(s, SYMBOL_BID) <= 0.0))
   {
      need = true; domain = "SYMBOL";
      g_UltraZFR.problemsFound++;
      g_UltraZFR.lastRecoverMs = now;
      UltraZFR_RecoverSymbol(s);
   }

   if(UltraZFRTimeframeRecovery && (Bars(s, UltraETF()) < 30 || iTime(s, UltraETF(), 0) <= 0))
   {
      need = true; domain = "TIMEFRAME";
      g_UltraZFR.problemsFound++;
      g_UltraZFR.lastRecoverMs = now;
      UltraZFR_RecoverTimeframe(s);
   }

   if((UltraZFRIndicatorRecovery || UltraZFRBufferRecovery) &&
      !UltraZFR_ShellIndicatorsHealthy(s))
   {
      need = true; domain = "INDICATORS";
      g_UltraZFR.problemsFound++;
      g_UltraZFR.lastRecoverMs = now;
      if(UltraZFRIndicatorRecovery) UltraZFR_RecoverIndicators(s);
      if(UltraZFRBufferRecovery) UltraZFR_RecoverBuffers(s);
   }

   if(UltraZFRMemoryRecovery)
      UltraZFR_RecoverMemory();

   static long lastPos = 0;
   if(UltraZFRPositionRecovery && (lastPos <= 0 || (now - lastPos) >= UltraZFRPositionMs))
   {
      lastPos = now;
      UltraZFR_RecoverPositions(s);
   }

   if(UltraZFRExecRecovery && connected && !UltraBT_TradeAllowed())
   {
      need = true; domain = "EXECUTION";
      g_UltraZFR.problemsFound++;
      g_UltraZFR.lastRecoverMs = now;
      UltraZFR_RecoverTradeContext(s);
   }

   if(UltraZFRSessionRecovery && UltraSessionEngineEnabled &&
      StringLen(g_UltraLastSnap.ctx.session) == 0)
   {
      g_UltraZFR.problemsFound++;
      UltraZFR_RecoverSession(s);
   }
   if(UltraZFREventRecovery && UltraNewsExec_IsNewsMode() &&
      StringLen(g_UltraLastSnap.ctx.eventClass) == 0)
   {
      g_UltraZFR.problemsFound++;
      UltraZFR_RecoverEvent(s);
   }

   static long lastDash = 0;
   if(UltraZFRDashboardRecovery && (lastDash <= 0 || (now - lastDash) >= UltraZFRDashboardMs))
   {
      lastDash = now;
      if((EnableDashboard || UltraDashboardEnabled) && ObjectFind(0, BG_OBJECT_NAME) < 0)
         UltraZFR_RecoverDashboard();
   }
   if(UltraZFRLoggerRecovery && StringLen(g_UltraCore.lastError) > 200)
      UltraZFR_RecoverLogger();

   g_UltraZFR.summary = need ? ("FIX:" + domain) : "MONITOR_OK";
   // NEVER abort trading cycle — always return
}

//--------------------------------------------------------------------//
void UltraZFR_Boot()
{
   ZeroMemory(g_UltraZFR);
   g_UltraZFR.lastConnected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   g_UltraZFR.summary = "BOOT";
   g_UltraZFR.booted = true;
   if(UltraZFRLog || UltraFoundationLogBoot)
      UltraLog("ZERO-FAIL RECOVERY ∞ boot Enabled=" + (UltraZFREnabled ? "Y" : "N") +
               " MonitorMs=" + IntegerToString(UltraZFRMonitorMs) +
               " NeverStop=Y BUILD=HA_ULTRA_93");
}

string UltraZFR_Dashboard()
{
   string t = "ZFR: ";
   if(!UltraZFREnabled) { t += "OFF"; return t; }
   t += g_UltraZFR.summary;
   t += " ok=";
   t += IntegerToString(g_UltraZFR.recoverSuccess);
   t += " fail=";
   t += IntegerToString(g_UltraZFR.recoverFail);
   t += " ind=";
   t += IntegerToString(g_UltraZFR.indicatorRecoveries);
   t += " pos=";
   t += IntegerToString(g_UltraZFR.positionRecoveries);
   t += " conn=";
   t += IntegerToString(g_UltraZFR.connectionRecoveries);
   return t;
}

#endif // HITMAN_ULTRA_ZERO_FAIL_RECOVERY_MQH
