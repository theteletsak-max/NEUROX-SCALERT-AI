#ifndef HITMAN_ULTRA_SYSTEM_HEALTH_MQH
#define HITMAN_ULTRA_SYSTEM_HEALTH_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 15/16/17 SELF-DIAG · PERF · SYSTEM HEALTH      |
//+------------------------------------------------------------------+

struct UltraSystemHealth
{
   bool connected;
   bool tradeAllowed;
   bool dataOK;
   bool brokerOK;
   bool execOK;
   bool memoryOK;
   long latencyMs;
   string status;   // GREEN / YELLOW / RED
   string detail;
};

UltraSystemHealth g_UltraSysHealth;

void UltraHealth_Clear()
{
   g_UltraSysHealth.connected = true;
   g_UltraSysHealth.tradeAllowed = true;
   g_UltraSysHealth.dataOK = true;
   g_UltraSysHealth.brokerOK = true;
   g_UltraSysHealth.execOK = true;
   g_UltraSysHealth.memoryOK = true;
   g_UltraSysHealth.latencyMs = 0;
   g_UltraSysHealth.status = "GREEN";
   g_UltraSysHealth.detail = "OK";
}

bool UltraSystemHealth_Update(const string s)
{
   UltraHealth_Clear();
   if(!UltraUpgradeEnabled || !UltraSystemHealthEnabled) return true;

   g_UltraSysHealth.connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   g_UltraSysHealth.tradeAllowed =
      (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
      (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);
   g_UltraSysHealth.dataOK = (Bars(s, UltraETF()) >= 50) && (SymbolInfoDouble(s, SYMBOL_BID) > 0.0);

   long tm = 0;
   bool modeOK = SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm);
   g_UltraSysHealth.brokerOK = modeOK && (tm != 0);

   string why = "";
   g_UltraSysHealth.execOK = UltraDefense_Line7_Execution(s, why);
   g_UltraSysHealth.memoryOK = !(UltraMarketMemoryEnabled && g_UltraMem.trades > 100000);
   g_UltraSysHealth.latencyMs = g_UltraCore.lastLatencyMs;

   bool hardFail = (!g_UltraSysHealth.connected || !g_UltraSysHealth.tradeAllowed ||
                    !g_UltraSysHealth.dataOK || !g_UltraSysHealth.brokerOK);

   if(hardFail)
   {
      g_UltraSysHealth.status = "RED";
      if(!g_UltraSysHealth.connected) g_UltraSysHealth.detail = "connection";
      else if(!g_UltraSysHealth.tradeAllowed) g_UltraSysHealth.detail = "trade blocked";
      else if(!g_UltraSysHealth.dataOK) g_UltraSysHealth.detail = "data error";
      else g_UltraSysHealth.detail = "broker/symbol";
      // self-diagnostic recovery attempt
      UltraRecover(g_UltraSysHealth.detail);
      return false;
   }

   if(!g_UltraSysHealth.execOK || g_UltraSysHealth.latencyMs > 500)
   {
      g_UltraSysHealth.status = "YELLOW";
      g_UltraSysHealth.detail = !g_UltraSysHealth.execOK ? why : "latency";
      return true; // soft — do not hard-block entries
   }

   g_UltraSysHealth.status = "GREEN";
   g_UltraSysHealth.detail = "OK";
   return true;
}

string UltraSystemHealth_Dashboard()
{
   string t = "HEALTH: ";
   t += g_UltraSysHealth.status;
   t += " ";
   t += g_UltraSysHealth.detail;
   return t;
}

#endif
