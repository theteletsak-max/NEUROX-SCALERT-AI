#ifndef HITMAN_ULTRA_LOGGER_INTELLIGENCE_MQH
#define HITMAN_ULTRA_LOGGER_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 13 · LOGGER & DIAGNOSTICS        |
//| Record absolutely everything · nothing without a trace           |
//| NEVER trades · NEVER executes · ONLY records                     |
//+------------------------------------------------------------------+

#define ULTRA_LOG_HIST_MAX 64

enum ENUM_ULTRA_LOG_CAT
{
   ULOG_SYSTEM = 0,
   ULOG_MARKET,
   ULOG_STRATEGY,
   ULOG_EXEC,
   ULOG_POSITION,
   ULOG_ERROR,
   ULOG_RECOVERY,
   ULOG_PERF,
   ULOG_DIAG,
   ULOG_DECISION
};

struct UltraLogHistEntry
{
   datetime ts;
   ENUM_ULTRA_LOG_CAT cat;
   string   catName;
   string   verb;
   string   detail;
   ulong    ticket;
};

struct UltraLoggerIntelState
{
   bool   booted;
   string status;              // READY | ACTIVE | OFF
   string detail;
   string lastCat;
   string lastVerb;
   string lastDetail;
   string diagHealth;          // OK | DEGRADED | UNKNOWN
   bool   tickOK;
   bool   brokerOK;
   bool   connectionOK;
   bool   indicatorOK;
   bool   memoryOK;
   bool   syncOK;
   long   lastLatencyMs;
   // Counters
   ulong  systemCount;
   ulong  marketCount;
   ulong  strategyCount;
   ulong  execCount;
   ulong  positionCount;
   ulong  errorCount;
   ulong  recoveryCount;
   ulong  perfCount;
   ulong  diagCount;
   ulong  decisionCount;
   ulong  warnCount;
   ulong  totalEvents;
   int    histN;
   int    histHead;
   UltraLogHistEntry hist[ULTRA_LOG_HIST_MAX];
   long   lastMs;
};

UltraLoggerIntelState g_UltraLoggerIntel;

string UltraLoggerIntel_CatName(const ENUM_ULTRA_LOG_CAT c)
{
   switch(c)
   {
      case ULOG_MARKET:    return "MARKET";
      case ULOG_STRATEGY:  return "STRATEGY";
      case ULOG_EXEC:      return "EXEC";
      case ULOG_POSITION:  return "POSITION";
      case ULOG_ERROR:     return "ERROR";
      case ULOG_RECOVERY:  return "RECOVERY";
      case ULOG_PERF:      return "PERF";
      case ULOG_DIAG:      return "DIAG";
      case ULOG_DECISION:  return "DECISION";
      default:             return "SYSTEM";
   }
}

void UltraLoggerIntel_Boot()
{
   ZeroMemory(g_UltraLoggerIntel);
   g_UltraLoggerIntel.booted = true;
   g_UltraLoggerIntel.status = UltraLoggingEnabled ? "READY" : "OFF";
   g_UltraLoggerIntel.detail = "boot — record only · never trades · never executes";
   g_UltraLoggerIntel.diagHealth = "UNKNOWN";
   g_UltraLoggerIntel.syncOK = true;
   UltraLog("LOGGER_INTEL Ch13 boot Logging=" + (UltraLoggingEnabled ? "Y" : "N") +
            " ErrorHandling=" + (UltraErrorHandlingEnabled ? "Y" : "N") +
            " Diagnostics=" + (UltraDiagnosticsEnabled ? "Y" : "N") +
            " BUILD=HA_ULTRA_93 NEVER_TRADES");
   g_UltraLoggerIntel.systemCount++;
   g_UltraLoggerIntel.totalEvents++;
   g_UltraLoggerIntel.lastCat = "SYSTEM";
   g_UltraLoggerIntel.lastVerb = "BOOT";
   g_UltraLoggerIntel.lastDetail = g_UltraLoggerIntel.detail;
   g_UltraLoggerIntel.status = UltraLoggingEnabled ? "ACTIVE" : "OFF";
}

void UltraLoggerIntel_PushHist(const ENUM_ULTRA_LOG_CAT cat, const string verb, const string detail,
                               const ulong ticket)
{
   int idx = g_UltraLoggerIntel.histHead % ULTRA_LOG_HIST_MAX;
   g_UltraLoggerIntel.hist[idx].ts = TimeCurrent();
   g_UltraLoggerIntel.hist[idx].cat = cat;
   g_UltraLoggerIntel.hist[idx].catName = UltraLoggerIntel_CatName(cat);
   g_UltraLoggerIntel.hist[idx].verb = verb;
   g_UltraLoggerIntel.hist[idx].detail = detail;
   g_UltraLoggerIntel.hist[idx].ticket = ticket;
   g_UltraLoggerIntel.histHead++;
   if(g_UltraLoggerIntel.histN < ULTRA_LOG_HIST_MAX)
      g_UltraLoggerIntel.histN++;
}

void UltraLoggerIntel_Bump(const ENUM_ULTRA_LOG_CAT cat)
{
   switch(cat)
   {
      case ULOG_MARKET:   g_UltraLoggerIntel.marketCount++; break;
      case ULOG_STRATEGY: g_UltraLoggerIntel.strategyCount++; break;
      case ULOG_EXEC:     g_UltraLoggerIntel.execCount++; break;
      case ULOG_POSITION: g_UltraLoggerIntel.positionCount++; break;
      case ULOG_ERROR:    g_UltraLoggerIntel.errorCount++; break;
      case ULOG_RECOVERY: g_UltraLoggerIntel.recoveryCount++; break;
      case ULOG_PERF:     g_UltraLoggerIntel.perfCount++; break;
      case ULOG_DIAG:     g_UltraLoggerIntel.diagCount++; break;
      case ULOG_DECISION: g_UltraLoggerIntel.decisionCount++; break;
      default:            g_UltraLoggerIntel.systemCount++; break;
   }
   g_UltraLoggerIntel.totalEvents++;
}

//--------------------------------------------------------------------//
// CORE — categorize → UltraLog (one logger · one source of truth)    //
//--------------------------------------------------------------------//
void UltraLoggerIntel_LogEvent(const ENUM_ULTRA_LOG_CAT cat, const string verb,
                               const string detail, const ulong ticket = 0)
{
   string catName = UltraLoggerIntel_CatName(cat);
   g_UltraLoggerIntel.lastCat = catName;
   g_UltraLoggerIntel.lastVerb = verb;
   g_UltraLoggerIntel.lastDetail = detail;
   g_UltraLoggerIntel.lastMs = (long)GetTickCount();
   UltraLoggerIntel_Bump(cat);
   UltraLoggerIntel_PushHist(cat, verb, detail, ticket);

   string line = "LOG13 ";
   line += catName;
   line += " ";
   line += verb;
   if(ticket > 0)
   {
      line += " ticket=";
      line += IntegerToString((int)ticket);
   }
   line += " | ";
   line += detail;

   if(cat == ULOG_ERROR)
   {
      UltraSetError(detail);
      UltraLog(line);
   }
   else if(cat == ULOG_EXEC)
      UltraLogExec(line);
   else if(cat == ULOG_PERF)
      UltraLogPerf(line);
   else if(cat == ULOG_POSITION || cat == ULOG_STRATEGY)
      UltraLogTrade(line);
   else
      UltraLog(line);
}

void UltraLoggerIntel_LogSystem(const string verb, const string detail)
{ UltraLoggerIntel_LogEvent(ULOG_SYSTEM, verb, detail); }

void UltraLoggerIntel_LogMarket(const string verb, const string detail)
{ UltraLoggerIntel_LogEvent(ULOG_MARKET, verb, detail); }

void UltraLoggerIntel_LogStrategy(const string verb, const string detail, const ulong ticket = 0)
{ UltraLoggerIntel_LogEvent(ULOG_STRATEGY, verb, detail, ticket); }

void UltraLoggerIntel_LogExec(const string verb, const string detail, const ulong ticket = 0)
{ UltraLoggerIntel_LogEvent(ULOG_EXEC, verb, detail, ticket); }

void UltraLoggerIntel_LogPosition(const string verb, const string detail, const ulong ticket = 0)
{ UltraLoggerIntel_LogEvent(ULOG_POSITION, verb, detail, ticket); }

void UltraLoggerIntel_LogError(const string verb, const string detail, const ulong ticket = 0)
{ UltraLoggerIntel_LogEvent(ULOG_ERROR, verb, detail, ticket); }

void UltraLoggerIntel_LogRecovery(const string verb, const string detail)
{ UltraLoggerIntel_LogEvent(ULOG_RECOVERY, verb, detail); }

void UltraLoggerIntel_LogPerf(const string verb, const string detail)
{ UltraLoggerIntel_LogEvent(ULOG_PERF, verb, detail); }

void UltraLoggerIntel_LogDecision(const string action, const ulong ticket, const string side,
                                  const string tag, const int conf, const int score,
                                  const string thesis, const string newsPhase,
                                  const double spread, const double slip, const string why)
{
   UltraLoggerIntel_Bump(ULOG_DECISION);
   UltraLoggerIntel_PushHist(ULOG_DECISION, action, why, ticket);
   g_UltraLoggerIntel.lastCat = "DECISION";
   g_UltraLoggerIntel.lastVerb = action;
   g_UltraLoggerIntel.lastDetail = why;
   UltraLogDecision(action, ticket, side, tag, conf, score, thesis, newsPhase, spread, slip, why);
}

//--------------------------------------------------------------------//
// DIAGNOSTICS — mirror snap diag + sibling engine health             //
//--------------------------------------------------------------------//
void UltraLoggerIntel_NoteDiagnostics(const UltraSnap &u)
{
   if(!g_UltraLoggerIntel.booted) return;
   g_UltraLoggerIntel.tickOK = u.diag.tickOK;
   g_UltraLoggerIntel.brokerOK = u.diag.brokerOK;
   g_UltraLoggerIntel.connectionOK = u.diag.connectionOK;
   g_UltraLoggerIntel.indicatorOK = u.diag.indicatorOK;
   g_UltraLoggerIntel.memoryOK = u.diag.memoryOK;
   g_UltraLoggerIntel.lastLatencyMs = u.diag.processSpeedMs;
   g_UltraLoggerIntel.diagHealth = u.diag.health;
   g_UltraLoggerIntel.syncOK = (g_UltraCore.healthy);
   g_UltraLoggerIntel.diagCount++;
   g_UltraLoggerIntel.totalEvents++;
   if(u.diag.health != "OK")
   {
      g_UltraLoggerIntel.warnCount++;
      UltraLoggerIntel_PushHist(ULOG_DIAG, "HEALTH", u.diag.health, 0);
   }
}

void UltraLoggerIntel_Sync()
{
   if(!g_UltraLoggerIntel.booted) return;
   // Mirror sibling counters (read-only — never trades)
   ulong bugWarn = (ulong)g_UltraBug.warnCount;
   if(bugWarn > g_UltraLoggerIntel.warnCount) g_UltraLoggerIntel.warnCount = bugWarn;
   ulong errN = (ulong)g_UltraCore.errorCount + (ulong)g_UltraBug.execFailCount;
   if(errN > g_UltraLoggerIntel.errorCount) g_UltraLoggerIntel.errorCount = errN;
   ulong recN = (ulong)g_UltraZFR.recoverSuccess + (ulong)g_UltraZFR.recoverFail;
   if(recN > g_UltraLoggerIntel.recoveryCount) g_UltraLoggerIntel.recoveryCount = recN;
   if(g_UltraExecIntel.submitCount > g_UltraLoggerIntel.execCount)
      g_UltraLoggerIntel.execCount = g_UltraExecIntel.submitCount;
   if(g_UltraBug.explainCount > (int)g_UltraLoggerIntel.decisionCount)
      g_UltraLoggerIntel.decisionCount = (ulong)g_UltraBug.explainCount;
   g_UltraLoggerIntel.lastLatencyMs = g_UltraCore.lastLatencyMs;
   g_UltraLoggerIntel.status = UltraLoggingEnabled ? "ACTIVE" : "OFF";
   g_UltraLoggerIntel.detail = "synced · hist=";
   g_UltraLoggerIntel.detail += IntegerToString(g_UltraLoggerIntel.histN);
   g_UltraLoggerIntel.detail += " events=";
   g_UltraLoggerIntel.detail += IntegerToString((int)g_UltraLoggerIntel.totalEvents);
   g_UltraLoggerIntel.lastMs = (long)GetTickCount();
}

string UltraLoggerIntel_Dashboard()
{
   UltraLoggerIntel_Sync();
   string t = "LOG13: ";
   if(!g_UltraLoggerIntel.booted) { t += "INIT"; return t; }
   t += g_UltraLoggerIntel.status;
   t += " evt=";
   t += IntegerToString((int)g_UltraLoggerIntel.totalEvents);
   t += " err=";
   t += IntegerToString((int)g_UltraLoggerIntel.errorCount);
   t += " rec=";
   t += IntegerToString((int)g_UltraLoggerIntel.recoveryCount);
   t += " dec=";
   t += IntegerToString((int)g_UltraLoggerIntel.decisionCount);
   t += " diag=";
   t += g_UltraLoggerIntel.diagHealth;
   if(StringLen(g_UltraLoggerIntel.lastVerb) > 0)
   {
      t += " | ";
      t += g_UltraLoggerIntel.lastCat;
      t += ":";
      t += g_UltraLoggerIntel.lastVerb;
   }
   return t;
}

string UltraLoggerIntel_LastHistoryLine()
{
   if(g_UltraLoggerIntel.histN <= 0) return "HIST: —";
   int idx = (g_UltraLoggerIntel.histHead - 1 + ULTRA_LOG_HIST_MAX) % ULTRA_LOG_HIST_MAX;
   string t = "HIST: ";
   t += g_UltraLoggerIntel.hist[idx].catName;
   t += " ";
   t += g_UltraLoggerIntel.hist[idx].verb;
   t += " | ";
   t += g_UltraLoggerIntel.hist[idx].detail;
   return t;
}

#endif // HITMAN_ULTRA_LOGGER_INTELLIGENCE_MQH
