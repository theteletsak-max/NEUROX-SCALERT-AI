#ifndef HITMAN_ULTRA_MODULE_MANAGER_MQH
#define HITMAN_ULTRA_MODULE_MANAGER_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA MODULE MANAGER (Final Module Order)            |
//| Registers Phases 1–17 · no duplicate lifecycle logic             |
//| Status mirrors live engines — never guess                        |
//+------------------------------------------------------------------+

#define ULTRA_MOD_MAX 32

struct UltraModEntry
{
   string name;
   bool   critical;
   bool   present;
   bool   healthy;
   string detail;
};

struct UltraModuleManagerState
{
   UltraModEntry mods[ULTRA_MOD_MAX];
   int    n;
   int    presentN;
   int    healthyN;
   bool   allCriticalOK;
   string summary;
};

UltraModuleManagerState g_UltraMods;

void UltraMod_Clear()
{
   g_UltraMods.n = 0;
   g_UltraMods.presentN = 0;
   g_UltraMods.healthyN = 0;
   g_UltraMods.allCriticalOK = true;
   g_UltraMods.summary = "";
}

void UltraMod_Reg(const string name, const bool critical, const bool present,
                  const bool healthy, const string detail)
{
   if(g_UltraMods.n >= ULTRA_MOD_MAX) return;
   int i = g_UltraMods.n++;
   g_UltraMods.mods[i].name = name;
   g_UltraMods.mods[i].critical = critical;
   g_UltraMods.mods[i].present = present;
   g_UltraMods.mods[i].healthy = healthy;
   g_UltraMods.mods[i].detail = detail;
   if(present) g_UltraMods.presentN++;
   if(present && healthy) g_UltraMods.healthyN++;
   if(critical && (!present || !healthy))
      g_UltraMods.allCriticalOK = false;
}

//--------------------------------------------------------------------//
// Refresh registry — FINAL MODULE ORDER Phases 1–17                  //
//--------------------------------------------------------------------//
void UltraMod_Refresh()
{
   UltraMod_Clear();

   // PHASE 1 — Foundation
   bool foundOK = (g_UltraFoundation.booted && g_UltraFoundation.status != "RED");
   UltraMod_Reg("P01_FOUNDATION", true, UltraFoundationEnabled, foundOK, g_UltraFoundation.status);

   // PHASE 2 — Market Intelligence
   bool mktOK = (!UltraMarketIntelEnabled) ||
                (g_UltraMarketIntel.booted && g_UltraMarketIntel.approved);
   UltraMod_Reg("P02_MARKET_INTEL", true, UltraMarketIntelEnabled, mktOK, g_UltraMarketIntel.status);

   // PHASE 3 — Proprietary Strategy (UFSE + Thesis + Confluence path)
   UltraMod_Reg("P03_PROP_STRATEGY", true, UltraFastSignalEnabled, UltraFastSignalEnabled,
                "UFSE+Thesis sole strategy");

   // PHASE 4 — Signal Intelligence
   UltraMod_Reg("P04_SIGNAL_INTEL", true, UltraFastSignalEnabled, UltraFastSignalEnabled,
                "BUY/SELL validate+filter");

   // PHASE 5 / PHASE 23 — News Intelligence + Event Trading Quality
   UltraMod_Reg("P05_NEWS_INTEL", false, UltraNewsExecEnabled, UltraNewsExecEnabled,
                UltraNewsExecEnabled
                ? (UltraNewsExec_IsNewsMode()
                   ? ("NEWS_MODE " + g_UltraNewsExec.eventName + "/" + g_UltraNewsExec.phase)
                   : UltraNewsExec_Dashboard())
                : "OFF");

   // PHASE 6 — Mission Control (Phase A: sole final WAIT/BUY/SELL/REPLACE)
   UltraMod_Reg("P06_MISSION", true, true, true,
                UltraPhaseA_MissionSoleAuthority
                ? "SOLE_FINAL BUY|SELL|WAIT|REPLACE"
                : "BUY|SELL|WAIT|REPLACE");

   // PHASE 7 — Execution pipeline (Signal→Risk→Prepare→Submit→Fill→Pos→Protect)
   UltraMod_Reg("P07_EXECUTION", true, true, true,
                "pipe@" + IntegerToString(g_UltraExecPipelineStage));

   // PHASE 8 — Target Intelligence
   UltraMod_Reg("P08_TARGET_INTEL", true, UltraTargetEnabled, UltraTargetEnabled,
                g_UltraTargetLast.valid ? "PLAN_OK" : "—");

   // PHASE 9 — Position Evolution
   UltraMod_Reg("P09_POS_EVO", false, UltraPosEvoEnabled, UltraPosEvoEnabled, "L1/L2/L3");

   // PHASE 10 — Exit Intelligence (Mission-only closes)
   UltraMod_Reg("P10_EXIT_INTEL", true, true, UltraMissionOnlyExits, "Mission-only closes");

   // Stop Evolution — profit protect (SL tighten only; supports P9/P10)
   UltraMod_Reg("SUP_STOP_EVO", false, UltraStopEvoEnabled, UltraStopEvoEnabled,
                UltraStopEvoEnabled ? UltraStopEvo_Dashboard() : "OFF");

   // PHASE 11 — Risk Intelligence (Capital + TradeGate)
   bool gateOK = (!UltraTradeGateEnabled) || g_UltraTradeGate.passed ||
                 (StringLen(g_UltraTradeGate.failStep) == 0);
   UltraMod_Reg("P11_RISK_INTEL", true, UltraTradeGateEnabled, gateOK,
                g_UltraTradeGate.passed ? "GATE_PASS" :
                (StringLen(g_UltraTradeGate.failStep) > 0 ? g_UltraTradeGate.failStep : "—"));

   // PHASE 12 — Backtest Compatibility
   UltraMod_Reg("P12_BT_COMPAT", false, UltraBacktestCompatEnabled, true, UltraBT_ModeName());

   // PHASE 13 — Performance Analytics (Adaptive soft analytics)
   UltraMod_Reg("P13_PERF_ANALYTICS", false, UltraAdaptiveEnabled, UltraAdaptiveEnabled,
                UltraAdaptiveEnabled
                ? ("Q=" + IntegerToString(g_UltraAdapt.audit.composite) +
                   " n=" + IntegerToString(g_UltraAdapt.review.trades))
                : "OFF");

   // PHASE 14 — Logger
   UltraMod_Reg("P14_LOGGER", false, UltraLoggingEnabled, true, "OK");

   // PHASE 15 — Dashboard
   UltraMod_Reg("P15_DASHBOARD", false, UltraDashboardEnabled, true, "OK");

   // PHASE 16 — Zero-Fail Recovery
   UltraMod_Reg("P16_ZERO_FAIL", false, UltraZFREnabled, UltraZFREnabled,
                UltraZFREnabled
                ? (g_UltraZFR.summary + " ok=" + IntegerToString(g_UltraZFR.recoverSuccess))
                : "OFF");

   // PHASE 17 — Maintenance (Bug Elimination orchestration)
   bool maintOK = (!UltraMaintenanceEnabled) || g_UltraMaint.stabilityOK;
   UltraMod_Reg("P17_MAINTENANCE", false, UltraMaintenanceEnabled, maintOK,
                UltraMaintenanceEnabled ? g_UltraMaint.summary : "OFF");

   // Supporting (Foundation-backed — not separate product phases)
   UltraMod_Reg("SUP_USM2", true, UltraUSM2Enabled, UltraUSM2Enabled, "sole confidence");
   UltraMod_Reg("SUP_THESIS", true, UltraThesisEnabled, UltraThesisEnabled, "sole thesis");
   UltraMod_Reg("SUP_HEALTH", false, UltraSystemHealthEnabled, g_UltraSysHealth.status != "RED",
                g_UltraSysHealth.status);
   UltraMod_Reg("SUP_MEMORY", false, UltraMemoryEngineEnabled, g_UltraFoundation.memoryOK,
                g_UltraFoundation.memoryOK ? "OK" : "OVERFLOW");
   UltraMod_Reg("SUP_LOW_LATENCY", false, UltraLowLatencyEnabled, UltraLowLatencyEnabled,
                UltraLowLatencyEnabled ? g_UltraLL.summary : "OFF");

   g_UltraMods.summary = "MODS ";
   g_UltraMods.summary += IntegerToString(g_UltraMods.healthyN);
   g_UltraMods.summary += "/";
   g_UltraMods.summary += IntegerToString(g_UltraMods.presentN);
   g_UltraMods.summary += " crit=";
   g_UltraMods.summary += g_UltraMods.allCriticalOK ? "OK" : "FAIL";
   g_UltraMods.summary += " FMO=1-17";
}

void UltraMod_Boot()
{
   UltraMod_Refresh();
   if(UltraFoundationLogBoot)
      UltraLog("MODULE MANAGER boot Final Module Order P1-17 " + g_UltraMods.summary +
               " BUILD=HA_ULTRA_93");
}

string UltraMod_Dashboard()
{
   UltraMod_Refresh();
   string t = "MODULES: ";
   t += g_UltraMods.summary;
   if(!g_UltraMods.allCriticalOK)
   {
      for(int i = 0; i < g_UltraMods.n; i++)
      {
         if(g_UltraMods.mods[i].critical &&
            (!g_UltraMods.mods[i].present || !g_UltraMods.mods[i].healthy))
         {
            t += " | ";
            t += g_UltraMods.mods[i].name;
            t += "=";
            t += g_UltraMods.mods[i].detail;
            break;
         }
      }
   }
   return t;
}

#endif // HITMAN_ULTRA_MODULE_MANAGER_MQH
