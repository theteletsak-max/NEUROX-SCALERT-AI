#ifndef HITMAN_ULTRA_RECOVERY_INTELLIGENCE_MQH
#define HITMAN_ULTRA_RECOVERY_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 15 · RECOVERY ENGINE             |
//| Detect · Classify · Recover · Verify · Continue (when safe)      |
//| NEVER changes proprietary strategy · NEVER creates signals       |
//| ONLY restores normal operation after recoverable problems        |
//| Thin facade over UltraZeroFailRecovery + 30_Recovery             |
//+------------------------------------------------------------------+

// Shell_B (assembled later)
int CountOpenTrades();

#define ULTRA_REC_SAFE_FAIL_THRESHOLD 5

enum ENUM_ULTRA_REC_CLASS
{
   UREC_CLASS_NONE = 0,
   UREC_CLASS_RECOVERABLE,
   UREC_CLASS_NON_RECOVERABLE
};

enum ENUM_ULTRA_REC_OUTCOME
{
   UREC_READY = 0,
   UREC_MONITORING,
   UREC_RECOVERING,
   UREC_VALIDATING,
   UREC_SUCCESS,
   UREC_FAILED,
   UREC_SAFE_MODE,
   UREC_RESUME
};

struct UltraRecoveryIntelState
{
   bool   booted;
   bool   safeMode;
   bool   positionsProtected;
   bool   execAvailable;
   bool   indicatorsValid;
   bool   syncOK;
   bool   dataCurrent;
   ENUM_ULTRA_REC_CLASS  failClass;
   ENUM_ULTRA_REC_OUTCOME outcome;
   string outcomeName;
   string failType;
   string affectedModule;
   string recoveryMethod;
   string lastResult;
   string detail;
   string status;
   int    openPositions;
   int    consecutiveFail;
   int    successCount;
   int    failCount;
   int    safeModeEnterCount;
   int    resumeCount;
   int    monitorCount;
   long   failStartMs;
   long   lastDurationMs;
   long   lastMs;
   long   lastZfrSuccess;
   long   lastZfrFail;
   int    lastProblemsFound;
   bool   incidentOpen;
};

UltraRecoveryIntelState g_UltraRecoveryIntel;

string UltraRecoveryIntel_OutcomeName(const ENUM_ULTRA_REC_OUTCOME o)
{
   switch(o)
   {
      case UREC_MONITORING: return "MONITORING";
      case UREC_RECOVERING: return "RECOVERING";
      case UREC_VALIDATING: return "VALIDATING";
      case UREC_SUCCESS:    return "RECOVERY_SUCCESS";
      case UREC_FAILED:     return "RECOVERY_FAILED";
      case UREC_SAFE_MODE:  return "SAFE_MODE";
      case UREC_RESUME:     return "RESUME_OPERATION";
      default:              return "READY";
   }
}

string UltraRecoveryIntel_ClassName(const ENUM_ULTRA_REC_CLASS c)
{
   if(c == UREC_CLASS_RECOVERABLE) return "RECOVERABLE";
   if(c == UREC_CLASS_NON_RECOVERABLE) return "NON_RECOVERABLE";
   return "NONE";
}

void UltraRecoveryIntel_SetOutcome(const ENUM_ULTRA_REC_OUTCOME o, const string detail)
{
   g_UltraRecoveryIntel.outcome = o;
   g_UltraRecoveryIntel.outcomeName = UltraRecoveryIntel_OutcomeName(o);
   g_UltraRecoveryIntel.detail = detail;
   g_UltraRecoveryIntel.lastMs = (long)GetTickCount();
   if(o == UREC_SAFE_MODE) g_UltraRecoveryIntel.status = "SAFE_MODE";
   else if(o == UREC_RECOVERING || o == UREC_VALIDATING) g_UltraRecoveryIntel.status = "RECOVERING";
   else if(o == UREC_FAILED) g_UltraRecoveryIntel.status = "FAILED";
   else g_UltraRecoveryIntel.status = "ACTIVE";
}

//--------------------------------------------------------------------//
// §2 HEALTH MONITOR — early abnormal-condition snapshot              //
//--------------------------------------------------------------------//
void UltraRecoveryIntel_HealthMonitor(const string s)
{
   g_UltraRecoveryIntel.monitorCount++;
   g_UltraRecoveryIntel.syncOK = (bool)TerminalInfoInteger(TERMINAL_CONNECTED) &&
                                 g_UltraCore.healthy;
   g_UltraRecoveryIntel.indicatorsValid = UltraZFR_ShellIndicatorsHealthy(s);
   g_UltraRecoveryIntel.dataCurrent = (Bars(s, UltraETF()) >= 30 &&
                                       iTime(s, UltraETF(), 0) > 0 &&
                                       SymbolInfoDouble(s, SYMBOL_BID) > 0.0);
   g_UltraRecoveryIntel.execAvailable = UltraBT_TradeAllowed() &&
                                        (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   g_UltraRecoveryIntel.openPositions = CountOpenTrades();
   g_UltraRecoveryIntel.positionsProtected = true; // verified below
}

//--------------------------------------------------------------------//
// §3 FAILURE CLASSIFICATION                                          //
//--------------------------------------------------------------------//
ENUM_ULTRA_REC_CLASS UltraRecoveryIntel_Classify(const string domain,
                                                 const uint code,
                                                 const string detail)
{
   // Non-recoverable — config / corruption / critical runtime
   if(StringFind(detail, "corrupt") >= 0 ||
      StringFind(detail, "invalid config") >= 0 ||
      StringFind(detail, "unsupported") >= 0 ||
      StringFind(domain, "CRITICAL") >= 0)
      return UREC_CLASS_NON_RECOVERABLE;

   if(code != 0)
   {
      if(UltraExecIntel_IsRecoverable(code))
         return UREC_CLASS_RECOVERABLE;
      // broker hard rejects / account issues
      if(code == TRADE_RETCODE_INVALID_ACCOUNT ||
         code == TRADE_RETCODE_TRADE_DISABLED ||
         code == TRADE_RETCODE_MARKET_CLOSED)
         return UREC_CLASS_NON_RECOVERABLE;
      return UREC_CLASS_RECOVERABLE; // transient unknown → try once
   }

   // Domain map — recoverable by ZFR design
   if(domain == "CONNECTION" || domain == "INDICATORS" || domain == "BUFFERS" ||
      domain == "SYMBOL" || domain == "TIMEFRAME" || domain == "EXECUTION" ||
      domain == "SESSION" || domain == "EVENT" || domain == "DASHBOARD" ||
      domain == "LOGGER" || domain == "MEMORY" || domain == "POSITION" ||
      domain == "CACHE")
      return UREC_CLASS_RECOVERABLE;

   if(StringLen(domain) == 0 || domain == "OK")
      return UREC_CLASS_NONE;

   return UREC_CLASS_RECOVERABLE;
}

//--------------------------------------------------------------------//
// §5 POSITION SAFETY — never abandon open positions                  //
//--------------------------------------------------------------------//
bool UltraRecoveryIntel_PositionSafetyOK(const string s, string &why)
{
   why = "";
   int matched = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      matched++;
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(vol <= 0.0)
      {
         why = "zero volume on #" + IntegerToString((int)ticket);
         g_UltraRecoveryIntel.positionsProtected = false;
         return false;
      }
      // SL missing is warned but not abandoned — Mission/PosEvo manage
      if(PositionGetDouble(POSITION_SL) <= 0.0)
         why = "SL unset on #" + IntegerToString((int)ticket);
   }
   g_UltraRecoveryIntel.openPositions = matched;
   g_UltraRecoveryIntel.positionsProtected = true;
   if(StringLen(why) == 0) why = "positions synchronized";
   return true;
}

//--------------------------------------------------------------------//
// §7 RECOVERY VALIDATION                                             //
//--------------------------------------------------------------------//
bool UltraRecoveryIntel_Validate(const string s, string &why)
{
   why = "";
   UltraRecoveryIntel_SetOutcome(UREC_VALIDATING, "post-recovery verify");
   UltraRecoveryIntel_HealthMonitor(s);

   if(!g_UltraRecoveryIntel.syncOK)
   { why = "sync/connection not restored"; return false; }
   if(!g_UltraRecoveryIntel.indicatorsValid)
   { why = "indicators invalid"; return false; }
   if(!g_UltraRecoveryIntel.dataCurrent)
   { why = "data not current"; return false; }
   if(!g_UltraRecoveryIntel.execAvailable && g_UltraRecoveryIntel.openPositions == 0)
   {
      // exec unavailable with no positions — soft warn, still fail new entries
      why = "execution unavailable";
      return false;
   }
   string posWhy = "";
   if(!UltraRecoveryIntel_PositionSafetyOK(s, posWhy))
   { why = posWhy; return false; }

   why = "module healthy · sync OK · indicators valid · data current";
   return true;
}

//--------------------------------------------------------------------//
// §8 SAFE MODE — suspend new trades · keep managing positions        //
//--------------------------------------------------------------------//
void UltraRecoveryIntel_EnterSafeMode(const string why)
{
   if(!g_UltraRecoveryIntel.safeMode)
      g_UltraRecoveryIntel.safeModeEnterCount++;
   g_UltraRecoveryIntel.safeMode = true;
   UltraRecoveryIntel_SetOutcome(UREC_SAFE_MODE, why);
   UltraLoggerIntel_LogRecovery("SAFE_MODE",
      "activated · " + why +
      " · positions monitored · new entries suspended");
}

void UltraRecoveryIntel_TryResume(const string s)
{
   if(!g_UltraRecoveryIntel.safeMode) return;
   string why = "";
   if(!UltraRecoveryIntel_Validate(s, why))
      return;
   if(g_UltraZFR.consecutiveFail > 0)
      return;
   g_UltraRecoveryIntel.safeMode = false;
   g_UltraRecoveryIntel.resumeCount++;
   UltraRecoveryIntel_SetOutcome(UREC_RESUME, why);
   UltraLoggerIntel_LogRecovery("RESUME", why);
}

bool UltraRecoveryIntel_InSafeMode()
{
   return g_UltraRecoveryIntel.safeMode;
}

bool UltraRecoveryIntel_AllowNewEntries()
{
   // Safe Mode / failed unverified recovery → no new decisions
   if(!g_UltraRecoveryIntel.booted) return true; // not yet — don't block init path
   if(g_UltraRecoveryIntel.safeMode) return false;
   if(g_UltraRecoveryIntel.outcome == UREC_FAILED &&
      g_UltraRecoveryIntel.failClass == UREC_CLASS_NON_RECOVERABLE)
      return false;
   return true;
}

//--------------------------------------------------------------------//
// §9 RECOVERY LOGGER helpers                                         //
//--------------------------------------------------------------------//
void UltraRecoveryIntel_NoteStart(const string domain, const string method, const string detail)
{
   g_UltraRecoveryIntel.failStartMs = (long)GetTickCount();
   g_UltraRecoveryIntel.affectedModule = domain;
   g_UltraRecoveryIntel.recoveryMethod = method;
   g_UltraRecoveryIntel.failType = detail;
   UltraRecoveryIntel_SetOutcome(UREC_RECOVERING, domain + " · " + method);
   UltraLoggerIntel_LogRecovery("START",
      "t=" + TimeToString(TimeCurrent(), TIME_SECONDS) +
      " type=" + detail +
      " module=" + domain +
      " method=" + method);
}

void UltraRecoveryIntel_NoteResult(const string domain, const bool success, const string detail)
{
   long now = (long)GetTickCount();
   if(g_UltraRecoveryIntel.failStartMs > 0)
      g_UltraRecoveryIntel.lastDurationMs = now - g_UltraRecoveryIntel.failStartMs;
   else
      g_UltraRecoveryIntel.lastDurationMs = 0;

   g_UltraRecoveryIntel.affectedModule = domain;
   g_UltraRecoveryIntel.lastResult = success ? "SUCCESS" : "FAILED";
   if(success)
   {
      g_UltraRecoveryIntel.successCount++;
      UltraRecoveryIntel_SetOutcome(UREC_SUCCESS, detail);
      UltraLoggerIntel_LogRecovery("SUCCESS",
         "module=" + domain +
         " method=" + g_UltraRecoveryIntel.recoveryMethod +
         " durMs=" + IntegerToString((int)g_UltraRecoveryIntel.lastDurationMs) +
         " | " + detail);
   }
   else
   {
      g_UltraRecoveryIntel.failCount++;
      UltraRecoveryIntel_SetOutcome(UREC_FAILED, detail);
      UltraLoggerIntel_LogRecovery("FAIL",
         "module=" + domain +
         " method=" + g_UltraRecoveryIntel.recoveryMethod +
         " durMs=" + IntegerToString((int)g_UltraRecoveryIntel.lastDurationMs) +
         " | " + detail);
   }
}

//--------------------------------------------------------------------//
// SYNC — mirror ZFR · classify real incidents · safe-mode policy     //
//--------------------------------------------------------------------//
void UltraRecoveryIntel_Sync(const string s)
{
   UltraRecoveryIntel_HealthMonitor(s);
   string posWhy = "";
   UltraRecoveryIntel_PositionSafetyOK(s, posWhy);
   g_UltraRecoveryIntel.consecutiveFail = g_UltraZFR.consecutiveFail;

   bool fixing = (StringFind(g_UltraZFR.summary, "FIX:") == 0);
   if(fixing)
   {
      g_UltraRecoveryIntel.affectedModule = StringSubstr(g_UltraZFR.summary, 4);
      g_UltraRecoveryIntel.failClass =
         UltraRecoveryIntel_Classify(g_UltraRecoveryIntel.affectedModule, 0, g_UltraZFR.lastProblem);
      if(!g_UltraRecoveryIntel.incidentOpen)
      {
         g_UltraRecoveryIntel.incidentOpen = true;
         UltraRecoveryIntel_NoteStart(g_UltraRecoveryIntel.affectedModule,
                                      "ZFR_" + g_UltraRecoveryIntel.affectedModule,
                                      g_UltraZFR.lastProblem);
      }
      else if(g_UltraZFR.recovering)
         UltraRecoveryIntel_SetOutcome(UREC_RECOVERING, g_UltraZFR.lastAction);
   }

   // Fail edge — always meaningful
   if(g_UltraZFR.recoverFail > g_UltraRecoveryIntel.lastZfrFail)
   {
      g_UltraRecoveryIntel.lastZfrFail = g_UltraZFR.recoverFail;
      string domain = g_UltraRecoveryIntel.affectedModule;
      if(StringLen(domain) == 0)
      {
         domain = g_UltraZFR.lastAction;
         int colon = StringFind(domain, ":");
         if(colon > 0) domain = StringSubstr(domain, 0, colon);
         if(StringLen(domain) == 0) domain = "ZFR";
      }
      g_UltraRecoveryIntel.failClass = UltraRecoveryIntel_Classify(domain, 0, g_UltraZFR.lastProblem);
      if(!g_UltraRecoveryIntel.incidentOpen)
         UltraRecoveryIntel_NoteStart(domain, "ZFR_" + domain, g_UltraZFR.lastProblem);
      UltraRecoveryIntel_NoteResult(domain, false, g_UltraZFR.lastProblem);
      g_UltraRecoveryIntel.incidentOpen = false;

      if(g_UltraRecoveryIntel.failClass == UREC_CLASS_NON_RECOVERABLE ||
         g_UltraRecoveryIntel.consecutiveFail >= ULTRA_REC_SAFE_FAIL_THRESHOLD)
         UltraRecoveryIntel_EnterSafeMode(g_UltraZFR.lastProblem);
   }

   // Success edge — only close a real FIX incident (skip routine POSITIONS/SESSION refresh)
   if(g_UltraZFR.recoverSuccess > g_UltraRecoveryIntel.lastZfrSuccess)
   {
      g_UltraRecoveryIntel.lastZfrSuccess = g_UltraZFR.recoverSuccess;
      if(g_UltraRecoveryIntel.incidentOpen || fixing)
      {
         string domain = g_UltraRecoveryIntel.affectedModule;
         if(StringLen(domain) == 0) domain = "ZFR";
         string why = "";
         bool ok = UltraRecoveryIntel_Validate(s, why);
         UltraRecoveryIntel_NoteResult(domain, ok, ok ? why : ("unverified · " + why));
         g_UltraRecoveryIntel.incidentOpen = false;
         if(!ok)
         {
            if(g_UltraRecoveryIntel.consecutiveFail >= ULTRA_REC_SAFE_FAIL_THRESHOLD ||
               g_UltraRecoveryIntel.failClass == UREC_CLASS_NON_RECOVERABLE)
               UltraRecoveryIntel_EnterSafeMode(why);
         }
         else
            UltraRecoveryIntel_TryResume(s);
      }
   }

   g_UltraRecoveryIntel.lastProblemsFound = g_UltraZFR.problemsFound;

   if(g_UltraRecoveryIntel.safeMode)
      UltraRecoveryIntel_SetOutcome(UREC_SAFE_MODE, g_UltraRecoveryIntel.detail);
   else if(g_UltraZFR.recovering || g_UltraRecoveryIntel.incidentOpen)
      UltraRecoveryIntel_SetOutcome(UREC_RECOVERING, g_UltraZFR.lastAction);
   else if(!fixing)
   {
      if(g_UltraRecoveryIntel.outcome != UREC_SUCCESS &&
         g_UltraRecoveryIntel.outcome != UREC_RESUME)
         UltraRecoveryIntel_SetOutcome(UREC_MONITORING, g_UltraZFR.summary);
      UltraRecoveryIntel_TryResume(s);
   }
}

//--------------------------------------------------------------------//
// §4 AUTOMATIC RECOVERY — orchestrate existing ZFR executor          //
//--------------------------------------------------------------------//
void UltraRecoveryIntel_OnTick(const string s)
{
   if(!g_UltraRecoveryIntel.booted) return;

   // Always run ZFR monitor/recover (executor) — facade never duplicates actions
   UltraZFR_OnTick(s);
   UltraRecoveryIntel_Sync(s);
}

bool UltraRecoveryIntel_PrepareExecRetry(const string s, const uint retcode, string &action)
{
   action = "";
   g_UltraRecoveryIntel.failClass = UltraRecoveryIntel_Classify("EXECUTION", retcode,
                                                               "retcode=" + IntegerToString((int)retcode));
   if(g_UltraRecoveryIntel.failClass == UREC_CLASS_NON_RECOVERABLE)
   {
      UltraRecoveryIntel_EnterSafeMode("non-recoverable exec retcode=" + IntegerToString((int)retcode));
      return false;
   }
   UltraRecoveryIntel_NoteStart("EXECUTION", "ZFR_EXEC_RETRY",
                                "retcode=" + IntegerToString((int)retcode));
   bool ok = UltraZFR_PrepareExecRetry(s, retcode, action);
   UltraRecoveryIntel_NoteResult("EXECUTION", ok,
                                 ok ? ("retry prepared · " + action) : "retry denied");
   return ok;
}

//--------------------------------------------------------------------//
void UltraRecoveryIntel_Boot()
{
   ZeroMemory(g_UltraRecoveryIntel);
   g_UltraRecoveryIntel.booted = true;
   g_UltraRecoveryIntel.safeMode = false;
   g_UltraRecoveryIntel.positionsProtected = true;
   g_UltraRecoveryIntel.failClass = UREC_CLASS_NONE;
   UltraRecoveryIntel_SetOutcome(UREC_READY, "boot — detect→recover→verify→continue");
   g_UltraRecoveryIntel.lastZfrSuccess = g_UltraZFR.recoverSuccess;
   g_UltraRecoveryIntel.lastZfrFail = g_UltraZFR.recoverFail;
   UltraLoggerIntel_LogRecovery("BOOT",
      "Ch15 Recovery Intelligence · ZFR executor · never changes strategy · never signals");
}

string UltraRecoveryIntel_Dashboard()
{
   string t = "REC15: ";
   if(!g_UltraRecoveryIntel.booted) { t += "INIT"; return t; }
   t += g_UltraRecoveryIntel.outcomeName;
   t += " class=";
   t += UltraRecoveryIntel_ClassName(g_UltraRecoveryIntel.failClass);
   if(g_UltraRecoveryIntel.safeMode) t += " SAFE";
   t += " ok=";
   t += IntegerToString(g_UltraRecoveryIntel.successCount);
   t += " fail=";
   t += IntegerToString(g_UltraRecoveryIntel.failCount);
   t += " pos=";
   t += IntegerToString(g_UltraRecoveryIntel.openPositions);
   if(StringLen(g_UltraRecoveryIntel.affectedModule) > 0)
   {
      t += " mod=";
      t += g_UltraRecoveryIntel.affectedModule;
   }
   return t;
}

#endif // HITMAN_ULTRA_RECOVERY_INTELLIGENCE_MQH
