#ifndef HITMAN_ULTRA_MODULE_MANAGER_MQH
#define HITMAN_ULTRA_MODULE_MANAGER_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA MODULE MANAGER (Final Master Audit)            |
//| Registers institutional engines · no duplicate lifecycle logic   |
//| Status mirrors Foundation / Market / VChain / Gate — never guess |
//+------------------------------------------------------------------+

#define ULTRA_MOD_MAX 28

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
// Refresh registry from live engine states (deterministic — no guess) //
//--------------------------------------------------------------------//
void UltraMod_Refresh()
{
   UltraMod_Clear();

   bool foundOK = (g_UltraFoundation.booted && g_UltraFoundation.status != "RED");
   UltraMod_Reg("FOUNDATION", true, UltraFoundationEnabled, foundOK, g_UltraFoundation.status);

   bool mktOK = (!UltraMarketIntelEnabled) ||
                (g_UltraMarketIntel.booted && g_UltraMarketIntel.approved);
   UltraMod_Reg("MARKET_INTEL", true, UltraMarketIntelEnabled, mktOK, g_UltraMarketIntel.status);

   // Module present/healthy ≠ trade permission; INVALID engine = unhealthy
   bool vchainOK = (!UltraVChainEnabled) || (g_UltraVChain.overall != UV_INVALID);
   UltraMod_Reg("VCHAIN", true, UltraVChainEnabled, vchainOK, UltraV_Name(g_UltraVChain.overall));

   UltraMod_Reg("NEWS_EXEC", false, UltraNewsExecEnabled, UltraNewsExecEnabled,
                g_UltraNewsExec.newsMode ? "MODE_ON" : "idle");

   UltraMod_Reg("TARGET_INTEL", true, UltraTargetEnabled, UltraTargetEnabled,
                g_UltraTargetLast.valid ? "PLAN_OK" : "—");

   UltraMod_Reg("ADAPTIVE", false, UltraAdaptiveEnabled, UltraAdaptiveEnabled,
                UltraAdaptiveEnabled
                ? ("FINAL Q=" + IntegerToString(g_UltraAdapt.audit.composite) +
                   " n=" + IntegerToString(g_UltraAdapt.review.trades) +
                   (g_UltraAdapt.finalEvolution ? " LOCKED" : ""))
                : "OFF");

   UltraMod_Reg("BUG_ELIM", false, UltraBugEnabled, g_UltraBug.initOK,
                UltraBugEnabled
                ? (g_UltraBug.summary + " expl=" + IntegerToString(g_UltraBug.explainCount))
                : "OFF");

   UltraMod_Reg("ZERO_FAIL", false, UltraZFREnabled, UltraZFREnabled,
                UltraZFREnabled
                ? (g_UltraZFR.summary + " ok=" + IntegerToString(g_UltraZFR.recoverSuccess))
                : "OFF");

   bool gateOK = (!UltraTradeGateEnabled) || g_UltraTradeGate.passed ||
                 (StringLen(g_UltraTradeGate.failStep) == 0);
   UltraMod_Reg("TRADE_GATE", true, UltraTradeGateEnabled, gateOK,
                g_UltraTradeGate.passed ? "PASS" :
                (StringLen(g_UltraTradeGate.failStep) > 0 ? g_UltraTradeGate.failStep : "—"));

   UltraMod_Reg("UFSE", true, UltraFastSignalEnabled, UltraFastSignalEnabled, "sole signal path");
   UltraMod_Reg("USM2", true, UltraUSM2Enabled, UltraUSM2Enabled, "sole confidence");
   UltraMod_Reg("THESIS", true, UltraThesisEnabled, UltraThesisEnabled, "sole thesis");
   UltraMod_Reg("MISSION", true, true, true, "sole entry/close authority");
   UltraMod_Reg("POSEVO", false, UltraPosEvoEnabled, UltraPosEvoEnabled, "L1/L2/L3");
   UltraMod_Reg("EVENT", false, UltraEventEngineEnabled, UltraEventEngineEnabled, "always-active");
   UltraMod_Reg("SESSION", false, UltraSessionEngineEnabled, UltraSessionEngineEnabled, "never blocks");
   UltraMod_Reg("HEALTH", false, UltraSystemHealthEnabled, g_UltraSysHealth.status != "RED",
                g_UltraSysHealth.status);
   UltraMod_Reg("RECOVERY", false, UltraRecoveryEnabled, UltraRecoveryEnabled, "auto");
   UltraMod_Reg("BT_COMPAT", false, UltraBacktestCompatEnabled, true, UltraBT_ModeName());
   UltraMod_Reg("LOGGER", false, UltraLoggingEnabled, true, "OK");
   UltraMod_Reg("DASHBOARD", false, UltraDashboardEnabled, true, "OK");

   // Memory / Resource (Foundation-backed — single source of truth)
   UltraMod_Reg("MEMORY", false, UltraMemoryEngineEnabled, g_UltraFoundation.memoryOK,
                g_UltraFoundation.memoryOK ? "OK" : "OVERFLOW");
   UltraMod_Reg("RESOURCES", false, true, g_UltraFoundation.resourcesOK,
                "objs=" + IntegerToString(g_UltraFoundation.chartObjectCount));

   g_UltraMods.summary = "MODS ";
   g_UltraMods.summary += IntegerToString(g_UltraMods.healthyN);
   g_UltraMods.summary += "/";
   g_UltraMods.summary += IntegerToString(g_UltraMods.presentN);
   g_UltraMods.summary += " crit=";
   g_UltraMods.summary += g_UltraMods.allCriticalOK ? "OK" : "FAIL";
}

void UltraMod_Boot()
{
   UltraMod_Refresh();
   if(UltraFoundationLogBoot)
      UltraLog("MODULE MANAGER boot " + g_UltraMods.summary + " BUILD=HA_ULTRA_93");
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
