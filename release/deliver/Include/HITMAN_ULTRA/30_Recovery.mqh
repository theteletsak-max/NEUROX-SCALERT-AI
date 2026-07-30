#ifndef HITMAN_ULTRA_30_RECOVERY_MQH
#define HITMAN_ULTRA_30_RECOVERY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 30_RECOVERY — Restart · Connection · State · Position recovery
//+------------------------------------------------------------------+
void UltraRecover(const string why)
{
   if(!UltraRecoveryEnabled) return;
   g_UltraCore.recoveryCount++;
   UltraLog("RECOVERY " + why);
   g_UltraCore.healthy = true;
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
