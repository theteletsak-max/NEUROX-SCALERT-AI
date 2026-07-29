#ifndef SNIPER_ULTRA_09_DIAG_MQH
#define SNIPER_ULTRA_09_DIAG_MQH
//+------------------------------------------------------------------+
//| 09. Diagnostics & Analytics                                      |
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


void UltraMemoryUpdateFromStats()
{
   if(!UltraMarketMemoryEnabled || !UltraPerfEngineEnabled) return;
   // Soft sync from existing EA stats if available
   g_UltraMem.winRate = GetWinRatePercent();
   g_UltraMem.profitFactor = GetProfitFactor();
   g_UltraMem.avgRR = GetAverageRR();
   g_UltraMem.lastSave = (long)TimeCurrent();
}

//--------------------------------------------------------------------//
// STRATEGIES (ULTRA)
//--------------------------------------------------------------------//

#endif
