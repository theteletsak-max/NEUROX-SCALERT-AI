#ifndef SNIPER_AI_ULTRA_26_DIAGNOSTICS_MQH
#define SNIPER_AI_ULTRA_26_DIAGNOSTICS_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 26_DIAGNOSTICS — Tick · Memory · Connection · Health
//+------------------------------------------------------------------+
void UltraEngDiagnostics(const string s, UltraSnap &u)
{
   u.diag.tickOK = (SymbolInfoDouble(s, SYMBOL_BID) > 0);
   u.diag.brokerOK = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
   u.diag.connectionOK = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   u.diag.indicatorOK = (u.vol.atr > 0);
   u.diag.memoryOK = true;
   if(UltraMemoryEngineEnabled && g_UltraMem.trades > 100000) u.diag.memoryOK = false;
   u.diag.processSpeedMs = g_UltraCore.lastLatencyMs;
   bool ok = u.diag.tickOK && u.diag.brokerOK && u.diag.connectionOK && u.diag.indicatorOK && u.diag.memoryOK;
   u.diag.health = ok ? "OK" : "DEGRADED";
   g_UltraCore.healthy = ok;
}

#endif // SNIPER_AI_ULTRA_26_DIAGNOSTICS_MQH
