#ifndef HITMAN_ULTRA_30_RECOVERY_MQH
#define HITMAN_ULTRA_30_RECOVERY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 30_RECOVERY — Restart · Connection · State recovery  |
//| LEVEL 7 — real recovery actions (not a no-op healthy=true)       |
//+------------------------------------------------------------------+
void UltraRecover(const string why)
{
   if(!UltraRecoveryEnabled) return;
   g_UltraCore.recoveryCount++;

   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   bool tradeOK = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                  (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);

   string actions = "";
   // Refresh tick / data surface
   MqlTick tick;
   string sym = BrokerSymbol;
   if(StringLen(sym) == 0) sym = _Symbol;
   if(SymbolInfoTick(sym, tick) && tick.bid > 0.0)
   {
      actions += "tickOK ";
      g_UltraCore.dataOK = true;
   }
   else
   {
      actions += "tickFAIL ";
      g_UltraCore.dataOK = false;
   }

   // Refresh deal/order history window
   if(HistorySelect(TimeCurrent() - 86400, TimeCurrent() + 60))
      actions += "historyOK ";
   else
      actions += "historyFAIL ";

   // Invalidate UFSE cache so next eval rebuilds (declared later in assemble — use global if present)
   // Soft: mark core state from measured data only
   int bars = Bars(sym, PERIOD_CURRENT);
   if(bars < 60)
   {
      actions += "thinBars ";
      g_UltraCore.dataOK = false;
   }

   g_UltraCore.healthy = (connected && tradeOK && g_UltraCore.dataOK);
   // Note: UltraConfigOK lives in 01_Core (assembled after Recovery) — do not call here

   UltraLog("RECOVERY why=" + why +
            " connected=" + (connected ? "Y" : "N") +
            " trade=" + (tradeOK ? "Y" : "N") +
            " healthy=" + (g_UltraCore.healthy ? "Y" : "N") +
            " actions=" + actions);
}

bool UltraRecovery_ConnectionOK()
{
   return (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
}

bool UltraRecovery_TerminalTradeOK()
{
   return (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
       && (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
}

void UltraRecovery_OnReconnect(const string why)
{
   if(!UltraRecovery_ConnectionOK()) return;
   UltraRecover(why);
}

#endif // HITMAN_ULTRA_30_RECOVERY_MQH
