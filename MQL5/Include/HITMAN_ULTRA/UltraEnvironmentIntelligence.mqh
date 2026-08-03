#ifndef HITMAN_ULTRA_ENVIRONMENT_INTELLIGENCE_MQH
#define HITMAN_ULTRA_ENVIRONMENT_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 16 · ENVIRONMENT COMPATIBILITY   |
//| Consistent behaviour: Strategy Tester · Demo · Live              |
//| NEVER changes Strategy · Risk · Thesis · Mission Control         |
//| ONLY adapts execution environment / broker mechanics             |
//| Thin facade over UltraBacktestCompat + BrokerCompatibility       |
//+------------------------------------------------------------------+

enum ENUM_ULTRA_ENV_MODE
{
   UENV_UNKNOWN = 0,
   UENV_TESTER,
   UENV_TESTER_VISUAL,
   UENV_OPTIMIZATION,
   UENV_DEMO,
   UENV_CONTEST,
   UENV_LIVE
};

enum ENUM_ULTRA_ENV_READY
{
   UENV_INIT = 0,
   UENV_READY,
   UENV_DEGRADED,
   UENV_BLOCKED
};

struct UltraEnvBrokerSpec
{
   string symbol;
   string company;
   long   login;
   int    stopsLevel;
   int    freezeLevel;
   int    fillingMode;
   int    execMode;          // SYMBOL_TRADE_EXEMODE
   int    digits;
   double point;
   double tickSize;
   double tickValue;
   double contractSize;
   double volumeMin;
   double volumeMax;
   double volumeStep;
   double marginInitial;
   bool   fillFOK;
   bool   fillIOC;
   bool   tradeAllowed;
   bool   valid;
   string fillingName;
   string execModeName;
};

struct UltraEnvironmentIntelState
{
   bool   booted;
   bool   strategyLocked;       // invariant — one strategy
   bool   riskLocked;           // invariant — one risk engine
   bool   thesisLocked;         // invariant — one thesis
   bool   missionLocked;        // invariant — one Mission Control
   bool   executionAdaptationOnly;

   bool   structuralOK;
   bool   dataOK;
   bool   brokerOK;
   bool   syncOK;
   bool   envReady;
   bool   indicatorsReady;
   bool   strategyReady;

   ENUM_ULTRA_ENV_MODE  mode;
   ENUM_ULTRA_ENV_READY readiness;
   string modeName;
   string status;
   string detail;
   string syncStatus;
   string compatStatus;

   UltraEnvBrokerSpec broker;

   int    openOrders;
   int    openPositions;
   double accountEquity;
   double accountBalance;
   double freeMargin;

   ulong  syncCount;
   ulong  readyCount;
   ulong  rejectCount;
   long   lastSyncMs;
   long   lastMs;
};

UltraEnvironmentIntelState g_UltraEnvIntel;

string UltraEnvIntel_ModeNameFromEnum(const ENUM_ULTRA_ENV_MODE m)
{
   switch(m)
   {
      case UENV_TESTER:        return "TESTER";
      case UENV_TESTER_VISUAL: return "TESTER_VISUAL";
      case UENV_OPTIMIZATION:  return "OPTIMIZATION";
      case UENV_DEMO:          return "DEMO";
      case UENV_CONTEST:       return "CONTEST";
      case UENV_LIVE:          return "LIVE";
      default:                 return "UNKNOWN";
   }
}

string UltraEnvIntel_ReadyName(const ENUM_ULTRA_ENV_READY r)
{
   switch(r)
   {
      case UENV_READY:    return "READY";
      case UENV_DEGRADED: return "DEGRADED";
      case UENV_BLOCKED:  return "BLOCKED";
      default:            return "INIT";
   }
}

string UltraEnvIntel_ExecModeName(const int exe)
{
   // SYMBOL_TRADE_EXECUTION_* 
   if(ex == SYMBOL_TRADE_EXECUTION_INSTANT) return "INSTANT";
   if(ex == SYMBOL_TRADE_EXECUTION_REQUEST) return "REQUEST";
   if(ex == SYMBOL_TRADE_EXECUTION_MARKET)  return "MARKET";
   if(ex == SYMBOL_TRADE_EXECUTION_EXCHANGE) return "EXCHANGE";
   return "UNKNOWN";
}

string UltraEnvIntel_FillingName(const bool fok, const bool ioc)
{
   if(fok) return "FOK";
   if(ioc) return "IOC";
   return "RETURN";
}

//--------------------------------------------------------------------//
// §1 ENVIRONMENT DETECTION — automatic · no manual switch            //
//--------------------------------------------------------------------//
ENUM_ULTRA_ENV_MODE UltraEnvIntel_DetectMode()
{
   if(UltraBT_IsOptimization()) return UENV_OPTIMIZATION;
   if(UltraBT_IsTester())
   {
      if(UltraBT_IsVisual()) return UENV_TESTER_VISUAL;
      return UENV_TESTER;
   }
   ENUM_ACCOUNT_TRADE_MODE am = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(am == ACCOUNT_TRADE_MODE_DEMO) return UENV_DEMO;
   if(am == ACCOUNT_TRADE_MODE_CONTEST) return UENV_CONTEST;
   if(am == ACCOUNT_TRADE_MODE_REAL) return UENV_LIVE;
   return UENV_UNKNOWN;
}

//--------------------------------------------------------------------//
// §7 BROKER COMPATIBILITY — read specs (execution layer only)        //
//--------------------------------------------------------------------//
bool UltraEnvIntel_RefreshBroker(const string s, string &why)
{
   why = "";
   UltraEnvBrokerSpec b;
   b.symbol = s;
   b.company = AccountInfoString(ACCOUNT_COMPANY);
   b.login = AccountInfoInteger(ACCOUNT_LOGIN);

   long stops = 0, freeze = 0, fill = 0, ex = 0, dig = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL, stops);
   SymbolInfoInteger(s, SYMBOL_TRADE_FREEZE_LEVEL, freeze);
   SymbolInfoInteger(s, SYMBOL_FILLING_MODE, fill);
   SymbolInfoInteger(s, SYMBOL_TRADE_EXEMODE, ex);
   SymbolInfoInteger(s, SYMBOL_DIGITS, dig);

   b.stopsLevel = (int)stops;
   b.freezeLevel = (int)freeze;
   b.fillingMode = (int)fill;
   b.execMode = (int)ex;
   b.digits = (int)dig;
   b.point = SymbolInfoDouble(s, SYMBOL_POINT);
   b.tickSize = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   b.tickValue = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
   b.contractSize = SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE);
   b.volumeMin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   b.volumeMax = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   b.volumeStep = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   b.marginInitial = SymbolInfoDouble(s, SYMBOL_MARGIN_INITIAL);
   b.fillFOK = ((b.fillingMode & SYMBOL_FILLING_FOK) != 0);
   b.fillIOC = ((b.fillingMode & SYMBOL_FILLING_IOC) != 0);
   b.fillingName = UltraEnvIntel_FillingName(b.fillFOK, b.fillIOC);
   b.execModeName = UltraEnvIntel_ExecModeName(b.execMode);

   long tm = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm);
   b.tradeAllowed = (tm != 0) || (UltraBT_CompatMode() && SymbolInfoDouble(s, SYMBOL_BID) > 0.0);
   b.valid = (b.volumeMin > 0.0 && b.volumeMax >= b.volumeMin &&
              b.volumeStep > 0.0 && b.point > 0.0 &&
              SymbolInfoDouble(s, SYMBOL_BID) > 0.0);

   // Keep legacy broker caps in sync (execution adaptation source)
   UltraBrokerCaps caps;
   UltraBroker_Detect(s, caps);

   g_UltraEnvIntel.broker = b;
   g_UltraEnvIntel.brokerOK = b.valid && b.tradeAllowed;
   if(!b.valid)
   {
      why = "broker specs incomplete";
      return false;
   }
   return true;
}

//--------------------------------------------------------------------//
// §8 SYNCHRONIZATION — orders · positions · account · broker         //
//--------------------------------------------------------------------//
void UltraEnvIntel_Synchronize(const string s)
{
   g_UltraEnvIntel.openOrders = OrdersTotal();
   g_UltraEnvIntel.openPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      g_UltraEnvIntel.openPositions++;
   }
   g_UltraEnvIntel.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_UltraEnvIntel.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_UltraEnvIntel.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_UltraEnvIntel.syncOK = UltraBT_ConnectedOK();
   g_UltraEnvIntel.syncStatus = g_UltraEnvIntel.syncOK ? "SYNCED" : "DESYNC";
   g_UltraEnvIntel.syncCount++;
   g_UltraEnvIntel.lastSyncMs = (long)GetTickCount();

   // Tester-aware broker health mirror
   UltraHealth_Update(s);
}

//--------------------------------------------------------------------//
// §4 / §9 DATA + READINESS VALIDATION                                //
//--------------------------------------------------------------------//
bool UltraEnvIntel_ValidateData(const string s, string &why)
{
   why = "";
   string w = "";
   if(!UltraBT_ValidateSymbolTF(s, w)) { why = w; return false; }
   if(!UltraBT_ValidateHistory(s, w))  { why = w; return false; }
   if(!UltraBT_ValidateBuffers(s, w))  { why = w; return false; }
   if(!UltraBT_ValidateTick(s, w))     { why = w; return false; }
   g_UltraEnvIntel.dataOK = true;
   return true;
}

bool UltraEnvIntel_ValidateLocks(string &why)
{
   why = "";
   // Hard invariants — never allow env layer to claim strategy forks
   if(!g_UltraEnvIntel.strategyLocked || !g_UltraEnvIntel.riskLocked ||
      !g_UltraEnvIntel.thesisLocked || !g_UltraEnvIntel.missionLocked ||
      !g_UltraEnvIntel.executionAdaptationOnly)
   {
      why = "environment lock invariant broken";
      return false;
   }
   g_UltraEnvIntel.strategyReady = true;
   return true;
}

bool UltraEnvIntel_ValidateReadiness(const string s, string &why)
{
   why = "";
   g_UltraEnvIntel.envReady = false;
   g_UltraEnvIntel.dataOK = false;
   g_UltraEnvIntel.indicatorsReady = false;

   if(!UltraEnvIntel_ValidateLocks(why))
   {
      g_UltraEnvIntel.readiness = UENV_BLOCKED;
      return false;
   }

   string w = "";
   if(!UltraEnvIntel_ValidateData(s, w))
   {
      why = w;
      g_UltraEnvIntel.readiness = UENV_BLOCKED;
      g_UltraEnvIntel.detail = w;
      return false;
   }

   if(!UltraBT_ValidateHandles(w))
   {
      why = w;
      g_UltraEnvIntel.indicatorsReady = false;
      g_UltraEnvIntel.readiness = UENV_BLOCKED;
      g_UltraEnvIntel.detail = w;
      return false;
   }
   g_UltraEnvIntel.indicatorsReady = true;

   if(!UltraEnvIntel_RefreshBroker(s, w))
   {
      why = w;
      g_UltraEnvIntel.readiness = UENV_BLOCKED;
      g_UltraEnvIntel.detail = w;
      return false;
   }

   if(!UltraBT_TradeAllowed())
   {
      why = "trade not allowed in environment";
      g_UltraEnvIntel.readiness = UENV_BLOCKED;
      g_UltraEnvIntel.detail = why;
      return false;
   }

   if(!UltraBT_ConnectedOK())
   {
      why = "environment not connected/synced";
      g_UltraEnvIntel.readiness = UENV_DEGRADED;
      g_UltraEnvIntel.detail = why;
      return false;
   }

   // Recovery Safe Mode — env ready structurally but new entries blocked upstream
   if(g_UltraRecoveryIntel.booted && g_UltraRecoveryIntel.safeMode)
   {
      g_UltraEnvIntel.readiness = UENV_DEGRADED;
      g_UltraEnvIntel.envReady = true;
      g_UltraEnvIntel.detail = "env OK · recovery safe mode";
      g_UltraEnvIntel.compatStatus = "DEGRADED_SAFE";
      why = g_UltraEnvIntel.detail;
      return true; // environment itself OK — gate is Recovery/TradeGate
   }

   g_UltraEnvIntel.envReady = true;
   g_UltraEnvIntel.readiness = UENV_READY;
   g_UltraEnvIntel.compatStatus = "COMPATIBLE";
   g_UltraEnvIntel.detail = "READY " + g_UltraEnvIntel.modeName;
   g_UltraEnvIntel.readyCount++;
   why = g_UltraEnvIntel.detail;
   return true;
}

//--------------------------------------------------------------------//
// PRE-TRADE — unified gate over BT + env/broker (never strategy)     //
//--------------------------------------------------------------------//
bool UltraEnvIntel_PreTradeReady(const string s, string &why)
{
   why = "";
   UltraEnvIntel_Synchronize(s);

   // One pipeline — same strategy path Tester/Demo/Live
   if(!UltraBT_PreTradeReady(s, why))
   {
      g_UltraEnvIntel.rejectCount++;
      g_UltraEnvIntel.readiness = UENV_BLOCKED;
      g_UltraEnvIntel.detail = why;
      g_UltraEnvIntel.compatStatus = "NOT_READY";
      return false;
   }

   string w = "";
   if(!UltraEnvIntel_ValidateReadiness(s, w))
   {
      // If BT ready but env degraded with safe mode, still allow structural ready
      if(g_UltraEnvIntel.readiness == UENV_DEGRADED && g_UltraEnvIntel.envReady)
      {
         why = w;
         return true;
      }
      g_UltraEnvIntel.rejectCount++;
      why = w;
      return false;
   }

   why = g_UltraEnvIntel.detail;
   return true;
}

//--------------------------------------------------------------------//
// Thin execution-environment adapters (delegate UltraBT_*)           //
//--------------------------------------------------------------------//
bool UltraEnvIntel_ConnectedOK()   { return UltraBT_ConnectedOK(); }
bool UltraEnvIntel_TradeAllowed()  { return UltraBT_TradeAllowed(); }
bool UltraEnvIntel_SkipLiveOnly()  { return UltraBT_SkipLiveOnly(); }
bool UltraEnvIntel_RelaxEntryDrift(){ return UltraBT_RelaxEntryDrift(); }
bool UltraEnvIntel_CompatMode()    { return UltraBT_CompatMode(); }

string UltraEnvIntel_ModeName()
{
   return g_UltraEnvIntel.modeName;
}

//--------------------------------------------------------------------//
void UltraEnvIntel_Sync(const string s)
{
   if(!g_UltraEnvIntel.booted) return;

   g_UltraEnvIntel.mode = UltraEnvIntel_DetectMode();
   g_UltraEnvIntel.modeName = UltraEnvIntel_ModeNameFromEnum(g_UltraEnvIntel.mode);
   // Keep BT mode string aligned
   g_UltraBT.modeName = UltraBT_ModeName();

   string why = "";
   UltraEnvIntel_RefreshBroker(s, why);
   UltraEnvIntel_Synchronize(s);

   g_UltraEnvIntel.structuralOK =
      g_UltraEnvIntel.strategyLocked &&
      g_UltraEnvIntel.executionAdaptationOnly &&
      g_UltraEnvIntel.booted;

   if(g_UltraEnvIntel.brokerOK && g_UltraEnvIntel.syncOK)
      g_UltraEnvIntel.status = "ACTIVE";
   else if(!g_UltraEnvIntel.syncOK)
      g_UltraEnvIntel.status = "DESYNC";
   else
      g_UltraEnvIntel.status = "DEGRADED";

   g_UltraEnvIntel.lastMs = (long)GetTickCount();
}

void UltraEnvIntel_OnTick(const string s)
{
   if(!g_UltraEnvIntel.booted) return;
   UltraEnvIntel_Sync(s);
}

void UltraEnvIntel_Boot(const string s)
{
   ZeroMemory(g_UltraEnvIntel);
   g_UltraEnvIntel.booted = true;
   // §2 UNIFIED STRATEGY — locked invariants (never forked by env)
   g_UltraEnvIntel.strategyLocked = true;
   g_UltraEnvIntel.riskLocked = true;
   g_UltraEnvIntel.thesisLocked = true;
   g_UltraEnvIntel.missionLocked = true;
   g_UltraEnvIntel.executionAdaptationOnly = true;

   g_UltraEnvIntel.mode = UltraEnvIntel_DetectMode();
   g_UltraEnvIntel.modeName = UltraEnvIntel_ModeNameFromEnum(g_UltraEnvIntel.mode);
   g_UltraEnvIntel.readiness = UENV_INIT;
   g_UltraEnvIntel.status = "BOOT";
   g_UltraEnvIntel.compatStatus = "INIT";
   g_UltraEnvIntel.syncStatus = "INIT";
   g_UltraEnvIntel.detail = "one strategy · exec adapts only · " + g_UltraEnvIntel.modeName;
   g_UltraEnvIntel.structuralOK = true;

   string why = "";
   if(StringLen(s) > 0)
   {
      UltraEnvIntel_RefreshBroker(s, why);
      UltraEnvIntel_Synchronize(s);
   }

   UltraLoggerIntel_LogSystem("ENV16",
      "boot mode=" + g_UltraEnvIntel.modeName +
      " compat=" + (UltraBT_CompatMode() ? "Y" : "N") +
      " | strategy/risk/thesis/mission LOCKED · exec adaptation only");
}

string UltraEnvIntel_Dashboard()
{
   string t = "ENV16: ";
   if(!g_UltraEnvIntel.booted) { t += "INIT"; return t; }
   t += g_UltraEnvIntel.modeName;
   t += " ";
   t += UltraEnvIntel_ReadyName(g_UltraEnvIntel.readiness);
   t += " ";
   t += g_UltraEnvIntel.compatStatus;
   t += " sync=";
   t += g_UltraEnvIntel.syncStatus;
   if(g_UltraEnvIntel.broker.valid)
   {
      t += " fill=";
      t += g_UltraEnvIntel.broker.fillingName;
      t += " ex=";
      t += g_UltraEnvIntel.broker.execModeName;
      t += " stops=";
      t += IntegerToString(g_UltraEnvIntel.broker.stopsLevel);
   }
   t += " | locks=Y";
   return t;
}

#endif // HITMAN_ULTRA_ENVIRONMENT_INTELLIGENCE_MQH
