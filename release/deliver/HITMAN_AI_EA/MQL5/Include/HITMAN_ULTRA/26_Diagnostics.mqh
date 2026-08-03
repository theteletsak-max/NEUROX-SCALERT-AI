#ifndef HITMAN_ULTRA_26_DIAGNOSTICS_MQH
#define HITMAN_ULTRA_26_DIAGNOSTICS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 26_DIAGNOSTICS — Tick · Memory · Connection · Health
//| Chapter 13 — feeds Logger Intel (defined later in assemble)      |
//+------------------------------------------------------------------+
void UltraLoggerIntel_NoteDiagnostics(const UltraSnap &u);

void UltraEngDiagnostics(const string s, UltraSnap &u)
{
   if(!UltraDiagnosticsEnabled)
   {
      u.diag.health = "OFF";
      return;
   }
   u.diag.tickOK = (SymbolInfoDouble(s, SYMBOL_BID) > 0);
   u.diag.brokerOK = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
   u.diag.connectionOK = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   u.diag.indicatorOK = (u.vol.atr > 0);
   u.diag.memoryOK = true;
   if(UltraMemoryEngineEnabled && g_UltraMem.trades > 100000) u.diag.memoryOK = false;
   u.diag.processSpeedMs = g_UltraCore.lastLatencyMs;
   bool ok = u.diag.tickOK && u.diag.brokerOK && u.diag.connectionOK && u.diag.indicatorOK && u.diag.memoryOK;
   if(ok) u.diag.health = "OK"; else u.diag.health = "DEGRADED";
   g_UltraCore.healthy = ok;
   UltraLoggerIntel_NoteDiagnostics(u);
}

#endif // HITMAN_ULTRA_26_DIAGNOSTICS_MQH
