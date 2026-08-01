#ifndef HITMAN_ULTRA_FOUNDATION_MQH
#define HITMAN_ULTRA_FOUNDATION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA SYSTEM FOUNDATION ENGINE (Phase 1)             |
//| Architecture · Config · Memory · Resources · Health · Recovery   |
//| Every future engine depends on this foundation.                  |
//+------------------------------------------------------------------+

#define ULTRA_BUILD_ID        "HA_ULTRA_93"
#define ULTRA_MIN_BARS_FOUND  60
#define ULTRA_FOUNDATION_MOD  12

struct UltraFoundationState
{
   bool   booted;
   bool   shuttingDown;
   bool   modulesOK;
   bool   memoryOK;
   bool   indicatorsOK;
   bool   handlesOK;
   bool   objectsOK;
   bool   configOK;
   bool   symbolOK;
   bool   timeframeOK;
   bool   dashboardOK;
   bool   loggerOK;
   bool   runtimeOK;
   bool   resourcesOK;
   int    chartObjectCount;
   int    invalidHandleCount;
   int    validHandleCount;
   long   lastHealthMs;
   long   bootMs;
   string status;   // GREEN / YELLOW / RED
   string detail;
   string symbol;
   ENUM_TIMEFRAMES entryTF;
};

UltraFoundationState g_UltraFoundation;

//--------------------------------------------------------------------//
// CONFIGURATION / PARAMETER VALIDATION                               //
//--------------------------------------------------------------------//
bool UltraFoundation_ValidateParams(string &why)
{
   why = "";
   if(!UltraConfigEngineEnabled && !UltraFoundationStrictConfig)
      return true;

   if(TradeComment != "HITMAN AI")
   { why = "TradeComment must be exactly HITMAN AI"; return false; }
   if(MaxOpenTrades != 3 && UltraFoundationStrictConfig)
   {
      // Soft warn if changed — still allow but mark detail
      why = "MaxOpenTrades expected 3";
      // do not hard-fail unless < 1
   }
   if(MaxOpenTrades < 1)
   { why = "MaxOpenTrades < 1"; return false; }
   if(MagicNumber <= 0)
   { why = "MagicNumber invalid"; return false; }
   if(LotSize <= 0.0)
   { why = "LotSize invalid"; return false; }
   if(UltraMinConfluence < 1 || UltraMinConfluence > 100)
   { why = "UltraMinConfluence out of range"; return false; }
   if(UltraMinPrecision < 1 || UltraMinPrecision > 100)
   { why = "UltraMinPrecision out of range"; return false; }
   if(UltraMinProbability < 1 || UltraMinProbability > 100)
   { why = "UltraMinProbability out of range"; return false; }
   if(StringLen(why) > 0) return true; // soft warning kept in why
   return true;
}

//--------------------------------------------------------------------//
// SYMBOL / TIMEFRAME MANAGER                                         //
//--------------------------------------------------------------------//
bool UltraFoundation_SymbolOK(const string s, string &why)
{
   why = "";
   if(StringLen(s) == 0){ why = "empty symbol"; return false; }
   long sel = 0;
   if(!SymbolInfoInteger(s, SYMBOL_SELECT, sel) || sel == 0)
   {
      if(!SymbolSelect(s, true))
      { why = "symbol not selectable"; return false; }
   }
   if(SymbolInfoDouble(s, SYMBOL_BID) <= 0.0)
   { why = "no bid"; return false; }
   if(Bars(s, PERIOD_CURRENT) < ULTRA_MIN_BARS_FOUND)
   { why = "insufficient bars"; return false; }
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) || tm == 0)
   { why = "trade mode disabled"; return false; }
   return true;
}

ENUM_TIMEFRAMES UltraFoundation_EntryTF()
{
   if(EntryTF == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)Period();
   return EntryTF;
}

bool UltraFoundation_TimeframeOK(string &why)
{
   why = "";
   ENUM_TIMEFRAMES tf = UltraFoundation_EntryTF();
   if(tf <= 0){ why = "bad entry TF"; return false; }
   g_UltraFoundation.entryTF = tf;
   g_UltraFoundation.timeframeOK = true;
   return true;
}

//--------------------------------------------------------------------//
// RESOURCE / HANDLE / OBJECT PROTECTION                              //
//--------------------------------------------------------------------//
int UltraFoundation_CountInvalidHandles()
{
   int bad = 0;
   int good = 0;
   // Shell arrays may be empty before init — safe
   int n = ArraySize(EMAHandles);
   for(int i = 0; i < n; i++)
   {
      if(i < ArraySize(EMAHandles))
      {
         if(EMAHandles[i] == INVALID_HANDLE) bad++;
         else if(EMAHandles[i] != 0) good++;
      }
      if(i < ArraySize(ADXHandles))
      {
         if(ADXHandles[i] == INVALID_HANDLE) bad++;
         else if(ADXHandles[i] != 0) good++;
      }
      if(i < ArraySize(ATRHandlesArr))
      {
         if(ATRHandlesArr[i] == INVALID_HANDLE) bad++;
         else if(ATRHandlesArr[i] != 0) good++;
      }
   }
   g_UltraFoundation.validHandleCount = good;
   g_UltraFoundation.invalidHandleCount = bad;
   return bad;
}

bool UltraFoundation_ObjectsOK()
{
   int total = ObjectsTotal(0, -1, -1);
   g_UltraFoundation.chartObjectCount = total;
   int maxObj = UltraFoundationMaxObjects;
   if(maxObj < 50) maxObj = 50;
   // Watermark + branding labels are expected — runaway is the risk
   g_UltraFoundation.objectsOK = (total <= maxObj);
   return g_UltraFoundation.objectsOK;
}

bool UltraFoundation_MemoryOK()
{
   // Lightweight: trade memory overflow + terminal memory flag
   bool ok = true;
   if(UltraMemoryEngineEnabled && g_UltraMem.trades > 100000)
      ok = false;
   g_UltraFoundation.memoryOK = ok;
   return ok;
}

bool UltraFoundation_RuntimeOK()
{
   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   bool tradeAllow = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                     (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);
   g_UltraFoundation.runtimeOK = (connected && tradeAllow && !g_UltraFoundation.shuttingDown);
   return g_UltraFoundation.runtimeOK;
}

bool UltraFoundation_LoggerOK()
{
   // Logger is print-based — always available when logging enabled or disabled by design
   g_UltraFoundation.loggerOK = true;
   return true;
}

bool UltraFoundation_DashboardOK()
{
   // Dashboard is Comment()-based — OK if terminal connected
   g_UltraFoundation.dashboardOK = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   return g_UltraFoundation.dashboardOK;
}

//--------------------------------------------------------------------//
// ULTRA HEALTH ENGINE — Every Tick (throttled full scan)             //
//--------------------------------------------------------------------//
bool UltraFoundation_HealthTick(const string s)
{
   if(!UltraFoundationEnabled || !UltraFoundationHealthTick)
   {
      g_UltraFoundation.status = "GREEN";
      g_UltraCore.foundationOK = true;
      return true;
   }

   long now = (long)GetTickCount();
   int interval = UltraFoundationHealthMs;
   if(interval < 50) interval = 50;

   // Light path every tick
   g_UltraCore.healthTickCount++;
   UltraFoundation_RuntimeOK();
   UltraFoundation_LoggerOK();

   bool doFull = (g_UltraFoundation.lastHealthMs <= 0) ||
                 ((now - g_UltraFoundation.lastHealthMs) >= interval);
   if(!doFull)
   {
      g_UltraCore.foundationOK = (g_UltraFoundation.status != "RED");
      return (g_UltraFoundation.status != "RED");
   }
   g_UltraFoundation.lastHealthMs = now;

   // Full verification path
   string why = "";
   g_UltraFoundation.symbol = s;
   g_UltraFoundation.symbolOK = UltraFoundation_SymbolOK(s, why);
   UltraFoundation_TimeframeOK(why);
   g_UltraFoundation.configOK = UltraConfigOK();
   UltraFoundation_MemoryOK();
   UltraFoundation_CountInvalidHandles();
   // Handles: INVALID_HANDLE before indicators init is OK; after boot, warn if all invalid
   g_UltraFoundation.handlesOK = true;
   if(g_UltraFoundation.booted && ArraySize(EMAHandles) > 0 &&
      g_UltraFoundation.validHandleCount == 0 && g_UltraFoundation.invalidHandleCount > 0)
      g_UltraFoundation.handlesOK = false;
   g_UltraFoundation.indicatorsOK = g_UltraFoundation.handlesOK;
   UltraFoundation_ObjectsOK();
   UltraFoundation_DashboardOK();
   g_UltraFoundation.resourcesOK = g_UltraFoundation.objectsOK && g_UltraFoundation.memoryOK;
   g_UltraFoundation.modulesOK = g_UltraCore.loaded && g_UltraFoundation.configOK;

   // Compose status — RED only on hard failures (never soft-block for latency)
   bool hardFail = (!g_UltraFoundation.runtimeOK || !g_UltraFoundation.symbolOK ||
                    !g_UltraFoundation.configOK || !g_UltraFoundation.modulesOK);
   bool softFail = (!g_UltraFoundation.memoryOK || !g_UltraFoundation.objectsOK ||
                    !g_UltraFoundation.handlesOK);

   if(hardFail)
   {
      g_UltraFoundation.status = "RED";
      if(!g_UltraFoundation.runtimeOK) g_UltraFoundation.detail = "runtime/connection";
      else if(!g_UltraFoundation.symbolOK) g_UltraFoundation.detail = "symbol/data";
      else if(!g_UltraFoundation.configOK) g_UltraFoundation.detail = "config";
      else g_UltraFoundation.detail = "modules";
      UltraRecover("FOUNDATION " + g_UltraFoundation.detail);
   }
   else if(softFail)
   {
      g_UltraFoundation.status = "YELLOW";
      if(!g_UltraFoundation.objectsOK)
         g_UltraFoundation.detail = "objects=" + IntegerToString(g_UltraFoundation.chartObjectCount);
      else if(!g_UltraFoundation.handlesOK)
         g_UltraFoundation.detail = "handles";
      else
         g_UltraFoundation.detail = "memory";
   }
   else
   {
      g_UltraFoundation.status = "GREEN";
      g_UltraFoundation.detail = "OK";
   }

   g_UltraCore.foundationOK = (g_UltraFoundation.status != "RED");
   g_UltraCore.dataOK = g_UltraFoundation.symbolOK;
   // Do not overwrite healthy=false from soft yellow — only hard RED degrades core healthy
   if(g_UltraFoundation.status == "RED")
      g_UltraCore.healthy = false;
   else if(g_UltraFoundation.status == "GREEN")
      g_UltraCore.healthy = true;

   return (g_UltraFoundation.status != "RED");
}

//--------------------------------------------------------------------//
// BOOT / SHUTDOWN SEQUENCE                                           //
//--------------------------------------------------------------------//
void UltraFoundation_Boot()
{
   // Never ZeroMemory structs with string fields (MQL5 unsafe)
   g_UltraFoundation.booted = false;
   g_UltraFoundation.shuttingDown = false;
   g_UltraFoundation.modulesOK = g_UltraFoundation.memoryOK = false;
   g_UltraFoundation.indicatorsOK = g_UltraFoundation.handlesOK = false;
   g_UltraFoundation.objectsOK = g_UltraFoundation.configOK = false;
   g_UltraFoundation.symbolOK = g_UltraFoundation.timeframeOK = false;
   g_UltraFoundation.dashboardOK = g_UltraFoundation.loggerOK = false;
   g_UltraFoundation.runtimeOK = g_UltraFoundation.resourcesOK = false;
   g_UltraFoundation.chartObjectCount = 0;
   g_UltraFoundation.invalidHandleCount = 0;
   g_UltraFoundation.validHandleCount = 0;
   g_UltraFoundation.lastHealthMs = 0;
   g_UltraFoundation.bootMs = (long)GetTickCount();
   g_UltraFoundation.status = "INIT";
   g_UltraFoundation.detail = "booting";
   g_UltraFoundation.symbol = "";
   g_UltraFoundation.entryTF = PERIOD_CURRENT;
   g_UltraCore.buildId = ULTRA_BUILD_ID;
   g_UltraCore.foundationOK = false;

   if(!UltraFoundationEnabled)
   {
      g_UltraFoundation.booted = true;
      g_UltraFoundation.status = "GREEN";
      g_UltraFoundation.detail = "disabled-pass";
      g_UltraCore.foundationOK = true;
      return;
   }

   string why = "";
   bool paramsOK = UltraFoundation_ValidateParams(why);
   g_UltraFoundation.configOK = UltraConfigOK() && paramsOK;
   UltraFoundation_TimeframeOK(why);

   string sym = BrokerSymbol;
   if(StringLen(sym) == 0) sym = _Symbol;
   g_UltraFoundation.symbolOK = UltraFoundation_SymbolOK(sym, why);
   g_UltraFoundation.symbol = sym;

   UltraFoundation_MemoryOK();
   UltraFoundation_ObjectsOK();
   UltraFoundation_LoggerOK();
   UltraFoundation_DashboardOK();
   UltraFoundation_RuntimeOK();
   g_UltraFoundation.modulesOK = g_UltraCore.loaded;
   g_UltraFoundation.handlesOK = true;
   g_UltraFoundation.indicatorsOK = true;
   g_UltraFoundation.resourcesOK = g_UltraFoundation.memoryOK && g_UltraFoundation.objectsOK;

   g_UltraFoundation.booted = true;
   g_UltraFoundation.shuttingDown = false;

   if(!g_UltraFoundation.configOK || !g_UltraFoundation.symbolOK || !g_UltraFoundation.runtimeOK)
   {
      g_UltraFoundation.status = "RED";
      g_UltraFoundation.detail = (StringLen(why) > 0) ? why : "boot validation failed";
      g_UltraCore.foundationOK = false;
      UltraSetError("FOUNDATION boot: " + g_UltraFoundation.detail);
   }
   else
   {
      g_UltraFoundation.status = "GREEN";
      g_UltraFoundation.detail = "OK";
      g_UltraCore.foundationOK = true;
   }

   if(UltraFoundationLogBoot)
   {
      UltraLog("FOUNDATION boot BUILD=" + ULTRA_BUILD_ID +
               " Comment=HITMAN AI MaxOpen=" + IntegerToString(MaxOpenTrades) +
               " TF=" + EnumToString(g_UltraFoundation.entryTF) +
               " status=" + g_UltraFoundation.status +
               " detail=" + g_UltraFoundation.detail +
               " objs=" + IntegerToString(g_UltraFoundation.chartObjectCount));
   }
}

void UltraFoundation_Shutdown(const int reason)
{
   g_UltraFoundation.shuttingDown = true;
   if(UltraFoundationLogBoot)
   {
      UltraLog("FOUNDATION shutdown reason=" + IntegerToString(reason) +
               " healthTicks=" + IntegerToString(g_UltraCore.healthTickCount) +
               " errors=" + IntegerToString(g_UltraCore.errorCount) +
               " recoveries=" + IntegerToString(g_UltraCore.recoveryCount) +
               " objs=" + IntegerToString(ObjectsTotal(0, -1, -1)));
   }
   g_UltraFoundation.booted = false;
   g_UltraCore.foundationOK = false;
   g_UltraFoundation.status = "OFF";
   g_UltraFoundation.detail = "shutdown";
}

void UltraFoundation_OnTick(const string s)
{
   if(!UltraFoundationEnabled) return;
   // Light + throttled full health (UltraOpt cadence lives in 37_Optimization)
   UltraFoundation_HealthTick(s);
}

string UltraFoundation_Dashboard()
{
   string t = "FOUNDATION: ";
   t += g_UltraFoundation.status;
   t += " ";
   t += g_UltraFoundation.detail;
   t += " | objs=";
   t += IntegerToString(g_UltraFoundation.chartObjectCount);
   t += " hnd=";
   t += IntegerToString(g_UltraFoundation.validHandleCount);
   t += "/";
   t += IntegerToString(g_UltraFoundation.invalidHandleCount);
   t += " TF=";
   t += EnumToString(g_UltraFoundation.entryTF);
   return t;
}

#endif // HITMAN_ULTRA_FOUNDATION_MQH
