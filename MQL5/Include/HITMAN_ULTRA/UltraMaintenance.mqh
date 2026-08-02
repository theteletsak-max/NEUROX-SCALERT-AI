#ifndef HITMAN_ULTRA_MAINTENANCE_MQH
#define HITMAN_ULTRA_MAINTENANCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA MAINTENANCE ENGINE ∞ (Final Module Order P17)  |
//| Thin orchestration over Bug Elimination + Foundation resources   |
//| NOT a new strategy — maintenance only (Final Development Rule)   |
//| Bug · Performance · Memory · CPU · Stability · Broker · Version  |
//+------------------------------------------------------------------+

struct UltraMaintenanceState
{
   bool   booted;
   bool   bugOK;
   bool   memoryOK;
   bool   resourcesOK;
   bool   versionOK;
   bool   stabilityOK;
   string version;
   string summary;
   int    bugExplains;
   int    bugCritical;
   long   lastScanMs;
};

UltraMaintenanceState g_UltraMaint;

//--------------------------------------------------------------------//
// Refresh from live Bug Elimination + Foundation (single source)     //
//--------------------------------------------------------------------//
void UltraMaint_Refresh()
{
   g_UltraMaint.version     = ULTRA_BUILD_ID;
   g_UltraMaint.versionOK   = (StringCompare(g_UltraMaint.version, "HA_ULTRA_93") == 0);
   g_UltraMaint.memoryOK    = g_UltraFoundation.memoryOK;
   g_UltraMaint.resourcesOK = g_UltraFoundation.resourcesOK;

   if(UltraBugEnabled)
   {
      g_UltraMaint.bugOK       = g_UltraBug.initOK;
      g_UltraMaint.bugExplains = g_UltraBug.explainCount;
      g_UltraMaint.bugCritical = g_UltraBug.criticalCount;
   }
   else
   {
      g_UltraMaint.bugOK       = true;
      g_UltraMaint.bugExplains = 0;
      g_UltraMaint.bugCritical = 0;
   }

   g_UltraMaint.stabilityOK =
      g_UltraMaint.bugOK &&
      g_UltraMaint.memoryOK &&
      g_UltraMaint.resourcesOK &&
      g_UltraMaint.versionOK;

   g_UltraMaint.summary = "MAINT ";
   g_UltraMaint.summary += g_UltraMaint.stabilityOK ? "OK" : "DEGRADED";
   g_UltraMaint.summary += " bug=";
   g_UltraMaint.summary += g_UltraMaint.bugOK ? "OK" : "FAIL";
   g_UltraMaint.summary += " mem=";
   g_UltraMaint.summary += g_UltraMaint.memoryOK ? "OK" : "OVERFLOW";
   g_UltraMaint.summary += " ver=";
   g_UltraMaint.summary += g_UltraMaint.version;
   g_UltraMaint.lastScanMs = (long)GetTickCount();
}

//--------------------------------------------------------------------//
// Boot — version lock + initial stability snapshot                   //
//--------------------------------------------------------------------//
void UltraMaint_Boot()
{
   ZeroMemory(g_UltraMaint);
   g_UltraMaint.booted  = true;
   g_UltraMaint.version = ULTRA_BUILD_ID;
   UltraMaint_Refresh();

   if(UltraBugLogBoot || UltraFoundationLogBoot)
      UltraLog("MAINTENANCE ENGINE ∞ boot (Final Module Order P17) " +
               g_UltraMaint.summary +
               " | BugDetect=Y Perf=Y Mem=Y CPU=via_Bug Perf Stability=Y BrokerAudit=Y Version=LOCK");
}

//--------------------------------------------------------------------//
// Tick — soft status refresh only (Bug OnTick remains authoritative) //
//--------------------------------------------------------------------//
void UltraMaint_OnTick(const string symbol)
{
   if(!UltraMaintenanceEnabled || !g_UltraMaint.booted)
      return;

   long now = (long)GetTickCount();
   if(g_UltraMaint.lastScanMs > 0 && (now - g_UltraMaint.lastScanMs) < 500)
      return;

   UltraMaint_Refresh();
   // Bug Elimination remains the structured explain authority;
   // Maintenance only mirrors Foundation/Bug health for Module Manager.
}

string UltraMaint_Dashboard()
{
   UltraMaint_Refresh();
   return g_UltraMaint.summary;
}

#endif // HITMAN_ULTRA_MAINTENANCE_MQH
