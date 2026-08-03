#ifndef HITMAN_ULTRA_LOW_LATENCY_INTELLIGENCE_MQH
#define HITMAN_ULTRA_LOW_LATENCY_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 17 · LOW-LATENCY & PERFORMANCE   |
//| Maximize efficiency · minimize internal processing time          |
//| NEVER changes trading strategy · ONLY optimizes performance      |
//| Thin facade over UltraLowLatency + 37_Optimization               |
//+------------------------------------------------------------------+

#define ULTRA_LL_SLOW_TICK_MS 250

enum ENUM_ULTRA_LL_STATUS
{
   ULL_INIT = 0,
   ULL_ACTIVE,
   ULL_DEGRADED,
   ULL_OFF
};

struct UltraLowLatencyIntelState
{
   bool   booted;
   bool   strategyLocked;          // invariant — never alters strategy
   bool   missionLocked;           // never delays Mission / ManageOpenTrades
   bool   healthy;
   ENUM_ULTRA_LL_STATUS status;
   string statusName;
   string detail;

   // §6 Module scheduling priority (critical never delayed by non-critical)
   string scheduleOrder;           // EXEC>POS>MISSION>STRAT>MKT>DASH>ANAL>LOG

   // §4 / §5 Cache + tick reuse
   ulong  cacheHits;               // early-skip / reused cycle work
   ulong  cacheMisses;             // full analysis path
   ulong  oneCalcTicks;            // ticks closed with single analysis budget

   // §7 / §8 Runtime + latency
   long   lastTickMs;
   long   peakTickMs;
   long   lastDecisionMs;
   long   avgTickMs;
   ulong  avgSamples;
   ulong  slowOps;
   ulong  warnCount;

   // Pipeline stage timings (ms stamps within tick)
   long   tickStartMs;
   long   prepMs;                  // order prep stage observed
   long   confirmMs;               // exec confirm stage observed

   string cpuStatus;               // derived from tick latency pressure
   string memStatus;               // derived from cycle/opt pressure
   string cacheStatus;
   string perfStatus;

   long   lastMs;
   ulong  lastSkipEntry;
   ulong  lastAnalysis;
};

UltraLowLatencyIntelState g_UltraLLIntel;

string UltraLowLatencyIntel_StatusName(const ENUM_ULTRA_LL_STATUS st)
{
   switch(st)
   {
      case ULL_ACTIVE:   return "ACTIVE";
      case ULL_DEGRADED: return "DEGRADED";
      case ULL_OFF:      return "OFF";
      default:           return "INIT";
   }
}

void UltraLowLatencyIntel_SetStatus(const ENUM_ULTRA_LL_STATUS st, const string detail)
{
   g_UltraLLIntel.status = st;
   g_UltraLLIntel.statusName = UltraLowLatencyIntel_StatusName(st);
   g_UltraLLIntel.detail = detail;
   g_UltraLLIntel.lastMs = (long)GetTickCount();
}

//--------------------------------------------------------------------//
// §7 RUNTIME + §8 LATENCY MONITOR                                    //
//--------------------------------------------------------------------//
void UltraLowLatencyIntel_RefreshMonitors()
{
   g_UltraLLIntel.lastTickMs = g_UltraLL.lastTickLatencyMs;
   g_UltraLLIntel.peakTickMs = g_UltraLL.peakTickLatencyMs;
   g_UltraLLIntel.lastDecisionMs = g_UltraLL.lastDecisionMs;

   // Rolling average (lightweight — no arrays)
   if(g_UltraLLIntel.lastTickMs >= 0)
   {
      g_UltraLLIntel.avgSamples++;
      if(g_UltraLLIntel.avgSamples == 1)
         g_UltraLLIntel.avgTickMs = g_UltraLLIntel.lastTickMs;
      else
         g_UltraLLIntel.avgTickMs =
            (g_UltraLLIntel.avgTickMs * 7 + g_UltraLLIntel.lastTickMs) / 8;
   }

   // CPU proxy — tick processing pressure (no OS CPU API in MQL5)
   if(g_UltraLLIntel.lastTickMs > ULTRA_LL_SLOW_TICK_MS ||
      g_UltraLLIntel.peakTickMs > ULTRA_LL_SLOW_TICK_MS * 2)
      g_UltraLLIntel.cpuStatus = "HIGH";
   else if(g_UltraLLIntel.lastTickMs > 80)
      g_UltraLLIntel.cpuStatus = "ELEVATED";
   else
      g_UltraLLIntel.cpuStatus = "OK";

   // Memory proxy — cycle pressure / skip-heavy activity
   if(g_UltraPerfOpt.cycleCount > 0 && g_UltraLL.skipHeavy > g_UltraLL.heavyRuns * 4)
      g_UltraLLIntel.memStatus = "PRESSURE";
   else
      g_UltraLLIntel.memStatus = "OK";

   // Cache status
   ulong hits = g_UltraLLIntel.cacheHits;
   ulong miss = g_UltraLLIntel.cacheMisses;
   if(hits + miss == 0)
      g_UltraLLIntel.cacheStatus = "IDLE";
   else if(hits >= miss)
      g_UltraLLIntel.cacheStatus = "HIT_OK";
   else
      g_UltraLLIntel.cacheStatus = "MISS_HEAVY";

   if(!UltraLowLatencyEnabled)
   {
      g_UltraLLIntel.perfStatus = "OFF";
      UltraLowLatencyIntel_SetStatus(ULL_OFF, "low-latency disabled");
      g_UltraLLIntel.healthy = true; // not unhealthy — just off
      return;
   }

   if(g_UltraLLIntel.cpuStatus == "HIGH")
   {
      g_UltraLLIntel.perfStatus = "SLOW";
      g_UltraLLIntel.healthy = false;
      UltraLowLatencyIntel_SetStatus(ULL_DEGRADED,
         "tick " + IntegerToString((int)g_UltraLLIntel.lastTickMs) + "ms");
   }
   else
   {
      g_UltraLLIntel.perfStatus = "OK";
      g_UltraLLIntel.healthy = true;
      UltraLowLatencyIntel_SetStatus(ULL_ACTIVE, g_UltraLL.summary);
   }
}

//--------------------------------------------------------------------//
// §9 PERFORMANCE LOGGER — slow ops / runtime warnings                //
//--------------------------------------------------------------------//
void UltraLowLatencyIntel_LogIfSlow()
{
   if(g_UltraLLIntel.lastTickMs <= ULTRA_LL_SLOW_TICK_MS)
      return;
   g_UltraLLIntel.slowOps++;
   g_UltraLLIntel.warnCount++;
   UltraLoggerIntel_LogPerf("SLOW_TICK",
      "lat=" + IntegerToString((int)g_UltraLLIntel.lastTickMs) +
      "ms peak=" + IntegerToString((int)g_UltraLLIntel.peakTickMs) +
      "ms avg=" + IntegerToString((int)g_UltraLLIntel.avgTickMs) +
      "ms cpu=" + g_UltraLLIntel.cpuStatus +
      " cache=" + g_UltraLLIntel.cacheStatus +
      " stage=" + IntegerToString(g_UltraExecPipelineStage));
}

void UltraLowLatencyIntel_Sync()
{
   if(!g_UltraLLIntel.booted) return;

   // Mirror cache reuse from LL skip/analysis deltas
   if(g_UltraLL.skipEntry > g_UltraLLIntel.lastSkipEntry)
   {
      g_UltraLLIntel.cacheHits += (g_UltraLL.skipEntry - g_UltraLLIntel.lastSkipEntry);
      g_UltraLLIntel.lastSkipEntry = g_UltraLL.skipEntry;
   }
   if(g_UltraLL.analysisRuns > g_UltraLLIntel.lastAnalysis)
   {
      g_UltraLLIntel.cacheMisses += (g_UltraLL.analysisRuns - g_UltraLLIntel.lastAnalysis);
      g_UltraLLIntel.lastAnalysis = g_UltraLL.analysisRuns;
   }
   if(UltraPerfOneAnalysisPerCycle)
      g_UltraLLIntel.oneCalcTicks = g_UltraLL.tickStarts;

   UltraLowLatencyIntel_RefreshMonitors();
   UltraLL_RefreshSummary();
}

//--------------------------------------------------------------------//
// Tick boundaries — wrap UltraLL (never skip ManageOpenTrades)       //
//--------------------------------------------------------------------//
void UltraLowLatencyIntel_OnTickStart()
{
   UltraLL_OnTickStart();
   g_UltraLLIntel.tickStartMs = g_UltraLL.lastTickStartMs;
   g_UltraLLIntel.prepMs = 0;
   g_UltraLLIntel.confirmMs = 0;
}

void UltraLowLatencyIntel_OnTickEnd()
{
   UltraLL_OnTickEnd();
   UltraLowLatencyIntel_Sync();
   UltraLowLatencyIntel_LogIfSlow();
}

bool UltraLowLatencyIntel_AllowMaintPass()
{
   // §6 — analytics/logging deferred; never blocks exec/position/mission
   return UltraLL_AllowMaintPass();
}

bool UltraLowLatencyIntel_ShouldEarlySkipEntry()
{
   // §5 — reuse cached results when price unchanged
   return UltraLL_ShouldEarlySkipEntry();
}

void UltraLowLatencyIntel_NotePrep()
{
   if(g_UltraLLIntel.tickStartMs > 0)
      g_UltraLLIntel.prepMs = (long)GetTickCount() - g_UltraLLIntel.tickStartMs;
}

void UltraLowLatencyIntel_NoteConfirm()
{
   if(g_UltraLLIntel.tickStartMs > 0)
      g_UltraLLIntel.confirmMs = (long)GetTickCount() - g_UltraLLIntel.tickStartMs;
}

//--------------------------------------------------------------------//
void UltraLowLatencyIntel_Boot()
{
   ZeroMemory(g_UltraLLIntel);
   g_UltraLLIntel.booted = true;
   g_UltraLLIntel.strategyLocked = true;
   g_UltraLLIntel.missionLocked = true;
   g_UltraLLIntel.scheduleOrder = "EXEC>POS>MISSION>STRAT>MKT>DASH>ANAL>LOG";
   g_UltraLLIntel.cpuStatus = "OK";
   g_UltraLLIntel.memStatus = "OK";
   g_UltraLLIntel.cacheStatus = "IDLE";
   g_UltraLLIntel.perfStatus = UltraLowLatencyEnabled ? "OK" : "OFF";
   g_UltraLLIntel.lastSkipEntry = g_UltraLL.skipEntry;
   g_UltraLLIntel.lastAnalysis = g_UltraLL.analysisRuns;
   UltraLowLatencyIntel_SetStatus(UltraLowLatencyEnabled ? ULL_ACTIVE : ULL_OFF,
      "boot · never changes strategy · schedule " + g_UltraLLIntel.scheduleOrder);

   UltraLoggerIntel_LogPerf("BOOT",
      "Ch17 Low-Latency Intelligence · LL=" + (UltraLowLatencyEnabled ? "Y" : "N") +
      " HeavyMs=" + IntegerToString(UltraLowLatencyHeavyMs) +
      " EarlySmart=" + (UltraLowLatencyEarlySmartTick ? "Y" : "N") +
      " OneAnalysis=" + (UltraPerfOneAnalysisPerCycle ? "Y" : "N") +
      " CacheConf=" + (UltraPerfCacheConfluence ? "Y" : "N") +
      " ReuseVChain=" + (UltraPerfReuseVChain ? "Y" : "N") +
      " | strategy LOCKED");
}

string UltraLowLatencyIntel_Dashboard()
{
   UltraLowLatencyIntel_Sync();
   string t = "LL17: ";
   if(!g_UltraLLIntel.booted) { t += "INIT"; return t; }
   t += g_UltraLLIntel.statusName;
   t += " cpu=";
   t += g_UltraLLIntel.cpuStatus;
   t += " mem=";
   t += g_UltraLLIntel.memStatus;
   t += " cache=";
   t += g_UltraLLIntel.cacheStatus;
   t += " hit/miss=";
   t += IntegerToString((int)g_UltraLLIntel.cacheHits);
   t += "/";
   t += IntegerToString((int)g_UltraLLIntel.cacheMisses);
   t += " lat=";
   t += IntegerToString((int)g_UltraLLIntel.lastTickMs);
   t += "ms avg=";
   t += IntegerToString((int)g_UltraLLIntel.avgTickMs);
   t += "ms";
   if(g_UltraLLIntel.slowOps > 0)
   {
      t += " slow=";
      t += IntegerToString((int)g_UltraLLIntel.slowOps);
   }
   return t;
}

#endif // HITMAN_ULTRA_LOW_LATENCY_INTELLIGENCE_MQH
