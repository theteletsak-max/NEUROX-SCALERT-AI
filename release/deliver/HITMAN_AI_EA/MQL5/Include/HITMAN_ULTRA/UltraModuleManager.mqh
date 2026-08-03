#ifndef HITMAN_ULTRA_MODULE_MANAGER_MQH
#define HITMAN_ULTRA_MODULE_MANAGER_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA MODULE MANAGER (Internal Standard v6+)         |
//| Registers Phases 1–19 · no duplicate lifecycle logic             |
//| Status mirrors live engines — never guess                        |
//+------------------------------------------------------------------+

#define ULTRA_MOD_MAX 40

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
// Refresh registry — INTERNAL STANDARD v6+ Phases 1–19               //
//--------------------------------------------------------------------//
void UltraMod_Refresh()
{
   UltraMod_Clear();

   // PHASE 1 — Core Foundation
   bool foundOK = (g_UltraFoundation.booted && g_UltraFoundation.status != "RED");
   UltraMod_Reg("P01_FOUNDATION", true, UltraFoundationEnabled, foundOK, g_UltraFoundation.status);

   // PHASE 2 — Market Intelligence
   bool mktOK = (!UltraMarketIntelEnabled) ||
                (g_UltraMarketIntel.booted && g_UltraMarketIntel.approved);
   string mktDetail = g_UltraMarketIntel.status;
   if(StringLen(g_UltraMarketIntel.readerState) > 0)
   {
      mktDetail += " ";
      mktDetail += g_UltraMarketIntel.readerState;
      mktDetail += " Q=";
      mktDetail += IntegerToString(g_UltraMarketIntel.marketQuality);
   }
   UltraMod_Reg("P02_MARKET_INTEL", true, UltraMarketIntelEnabled, mktOK, mktDetail);

   // PHASE 3 — Proprietary Strategy (Chapter 3 — never executes)
   string stratDetail = g_UltraPropStrategy.approved ? "APPROVED " : "WAIT ";
   stratDetail += g_UltraPropStrategy.candidate;
   stratDetail += " ctx=";
   stratDetail += g_UltraPropStrategy.context;
   stratDetail += " cfl=";
   stratDetail += IntegerToString(g_UltraPropStrategy.confluence);
   stratDetail += " conf=";
   stratDetail += IntegerToString(g_UltraPropStrategy.confidence);
   UltraMod_Reg("P03_PROP_STRATEGY", true, UltraFastSignalEnabled,
                (!UltraFastSignalEnabled) || g_UltraPropStrategy.booted, stratDetail);

   // PHASE 4 — Signal Intelligence (Chapter 4 — never executes)
   bool sigOK = UltraFastSignalEnabled;
   string sigDetail = g_UltraSignalIntel.lastCandidate;
   if(StringLen(sigDetail) == 0) sigDetail = "WAIT";
   sigDetail += " ";
   sigDetail += g_UltraSignalIntel.lastLife;
   sigDetail += " conf=";
   sigDetail += IntegerToString(g_UltraSignalIntel.lastConfidence);
   sigDetail += " Q=";
   sigDetail += IntegerToString(g_UltraSignalIntel.lastQuality);
   UltraMod_Reg("P04_SIGNAL_INTEL", true, UltraFastSignalEnabled, sigOK, sigDetail);

   // PHASE 5 — News Intelligence
   UltraMod_Reg("P05_NEWS_INTEL", false, UltraNewsExecEnabled, UltraNewsExecEnabled,
                UltraNewsExecEnabled
                ? (UltraNewsExec_IsNewsMode()
                   ? ("NEWS_MODE " + g_UltraNewsExec.eventName + "/" + g_UltraNewsExec.phase)
                   : UltraNewsExec_Dashboard())
                : "OFF");

   // PHASE 6 — Mission Control (ONLY final decision maker)
   UltraMod_Reg("P06_MISSION", true, true, true,
                UltraPhaseA_MissionSoleAuthority
                ? "SOLE_FINAL BUY|SELL|WAIT|REPLACE"
                : "BUY|SELL|WAIT|REPLACE");

   // PHASE 7 — Risk Intelligence (Chapter 7 — never executes)
   bool riskOK = g_UltraRiskIntel.booted &&
                 (g_UltraRiskIntel.approved || g_UltraRiskIntel.status == "INIT");
   string riskDetail = g_UltraRiskIntel.status;
   riskDetail += " lot=";
   riskDetail += DoubleToString(g_UltraRiskIntel.approvedLot, 2);
   riskDetail += " exp=";
   riskDetail += g_UltraRiskIntel.exposureStatus;
   riskDetail += " mgn=";
   riskDetail += g_UltraRiskIntel.marginStatus;
   UltraMod_Reg("P07_RISK_INTEL", true, true, riskOK, riskDetail);

   // PHASE 8 — Execution Intelligence (Chapter 8 — Mission-only)
   {
      bool execOK = g_UltraExecIntel.booted &&
                    g_UltraExecIntel.outcome != UEXEC_FAILED;
      string execDetail = g_UltraExecIntel.status;
      execDetail += " ";
      execDetail += g_UltraExecIntel.outcomeName;
      execDetail += " fill=";
      execDetail += g_UltraExecIntel.fillingName;
      execDetail += " pipe@";
      execDetail += IntegerToString(g_UltraExecPipelineStage);
      UltraMod_Reg("P08_EXECUTION", true, true, execOK, execDetail);
   }

   // PHASE 9 — Target Intelligence (Chapter 9 — never executes/signals)
   {
      bool tgtOK = g_UltraTargetIntel.booted &&
                   (g_UltraTargetIntel.approved || g_UltraTargetIntel.status == UTARGET_IDLE ||
                    !UltraTargetEnabled);
      string tgtDetail = g_UltraTargetIntel.statusName;
      tgtDetail += " evo=";
      tgtDetail += g_UltraTargetIntel.evoStatus;
      if(g_UltraTargetLast.valid)
      {
         tgtDetail += " RR=";
         tgtDetail += DoubleToString(g_UltraTargetIntel.rr1, 1);
         tgtDetail += "/";
         tgtDetail += DoubleToString(g_UltraTargetIntel.rr2, 1);
      }
      else
         tgtDetail += UltraTargetEnabled ? " —" : " OFF";
      UltraMod_Reg("P09_TARGET_INTEL", true, UltraTargetEnabled, tgtOK, tgtDetail);
   }

   // PHASE 10 — Position Evolution (Chapter 10 — continuous manage)
   {
      bool pevoOK = g_UltraPosEvoIntel.booted &&
                    (UltraPosEvoEnabled || UltraStopEvoEnabled);
      string pevoDetail = g_UltraPosEvoIntel.levelName;
      pevoDetail += " → ";
      pevoDetail += g_UltraPosEvoIntel.outputName;
      pevoDetail += " Q=";
      pevoDetail += IntegerToString(g_UltraPosEvoIntel.quality);
      UltraMod_Reg("P10_POS_EVO", true, UltraPosEvoEnabled, pevoOK, pevoDetail);
   }
   UltraMod_Reg("SUP_STOP_EVO", false, UltraStopEvoEnabled, UltraStopEvoEnabled,
                UltraStopEvoEnabled ? UltraStopEvo_Dashboard() : "OFF");

   // PHASE 11 — Exit Intelligence (Chapter 11 — Mission sole close)
   {
      bool exitOK = g_UltraExitIntel.booted && UltraMissionOnlyExits;
      string exitDetail = g_UltraExitIntel.status;
      exitDetail += " ";
      exitDetail += g_UltraExitIntel.outcomeName;
      if(StringLen(g_UltraExitIntel.exitMethod) > 0)
      {
         exitDetail += " ";
         exitDetail += g_UltraExitIntel.exitMethod;
      }
      exitDetail += " closes=";
      exitDetail += IntegerToString((int)g_UltraExitIntel.closeCount);
      UltraMod_Reg("P11_EXIT_INTEL", true, true, exitOK, exitDetail);
   }

   // PHASE 12 — Performance Analytics (Chapter 12 — never trades)
   {
      UltraPerfAnalytics_Sync();
      bool perfOK = g_UltraPerfAnalytics.booted &&
                    (UltraAdaptiveEnabled || g_UltraPerfAnalytics.status == "OFF");
      string perfDetail = g_UltraPerfAnalytics.status;
      perfDetail += " WR=";
      perfDetail += DoubleToString(g_UltraPerfAnalytics.winRate, 1);
      perfDetail += "% n=";
      perfDetail += IntegerToString(g_UltraPerfAnalytics.trades);
      perfDetail += " Q=";
      perfDetail += IntegerToString(g_UltraPerfAnalytics.systemQuality);
      UltraMod_Reg("P12_PERF_ANALYTICS", true, UltraAdaptiveEnabled, perfOK, perfDetail);
   }

   // PHASE 13 — Logger & Diagnostics (Chapter 13 — never trades)
   {
      UltraLoggerIntel_Sync();
      bool logOK = g_UltraLoggerIntel.booted &&
                   (UltraLoggingEnabled || g_UltraLoggerIntel.status == "OFF");
      string logDetail = g_UltraLoggerIntel.status;
      logDetail += " evt=";
      logDetail += IntegerToString((int)g_UltraLoggerIntel.totalEvents);
      logDetail += " err=";
      logDetail += IntegerToString((int)g_UltraLoggerIntel.errorCount);
      logDetail += " diag=";
      logDetail += g_UltraLoggerIntel.diagHealth;
      UltraMod_Reg("P13_LOGGER", true, UltraLoggingEnabled, logOK, logDetail);
   }

   // PHASE 14 — Dashboard
   UltraMod_Reg("P14_DASHBOARD", false, UltraDashboardEnabled, true, "OK");

   // PHASE 15 — Zero-Fail Recovery
   UltraMod_Reg("P15_ZERO_FAIL", false, UltraZFREnabled, UltraZFREnabled,
                UltraZFREnabled
                ? (g_UltraZFR.summary + " ok=" + IntegerToString(g_UltraZFR.recoverSuccess))
                : "OFF");

   // PHASE 16 — Backtest Compatibility
   UltraMod_Reg("P16_BT_COMPAT", false, UltraBacktestCompatEnabled, true, UltraBT_ModeName());

   // PHASE 17 — Low-Latency
   UltraMod_Reg("P17_LOW_LATENCY", false, UltraLowLatencyEnabled, UltraLowLatencyEnabled,
                UltraLowLatencyEnabled ? g_UltraLL.summary : "OFF");

   // PHASE 18 — Quality Assurance
   bool qaOK = (!UltraQAEnabled) || g_UltraQA.ok;
   UltraMod_Reg("P18_QA", false, UltraQAEnabled, qaOK,
                UltraQAEnabled ? g_UltraQA.summary : "OFF");

   // PHASE 19 — Maintenance
   bool maintOK = (!UltraMaintenanceEnabled) || g_UltraMaint.stabilityOK;
   UltraMod_Reg("P19_MAINTENANCE", false, UltraMaintenanceEnabled, maintOK,
                UltraMaintenanceEnabled ? g_UltraMaint.summary : "OFF");

   // Engineering locks (one thesis · one confidence)
   UltraMod_Reg("SUP_USM2", true, UltraUSM2Enabled, UltraUSM2Enabled, "sole confidence");
   UltraMod_Reg("SUP_THESIS", true, UltraThesisEnabled, UltraThesisEnabled, "sole thesis");
   UltraMod_Reg("SUP_HEALTH", false, UltraSystemHealthEnabled, g_UltraSysHealth.status != "RED",
                g_UltraSysHealth.status);
   UltraMod_Reg("SUP_MEMORY", false, UltraMemoryEngineEnabled, g_UltraFoundation.memoryOK,
                g_UltraFoundation.memoryOK ? "OK" : "OVERFLOW");

   g_UltraMods.summary = "MODS ";
   g_UltraMods.summary += IntegerToString(g_UltraMods.healthyN);
   g_UltraMods.summary += "/";
   g_UltraMods.summary += IntegerToString(g_UltraMods.presentN);
   g_UltraMods.summary += " crit=";
   g_UltraMods.summary += g_UltraMods.allCriticalOK ? "OK" : "FAIL";
   g_UltraMods.summary += " IS=v6+";
}

void UltraMod_Boot()
{
   UltraMod_Refresh();
   if(UltraFoundationLogBoot)
      UltraLog("MODULE MANAGER boot Internal Standard v6+ P1-19 " + g_UltraMods.summary +
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
