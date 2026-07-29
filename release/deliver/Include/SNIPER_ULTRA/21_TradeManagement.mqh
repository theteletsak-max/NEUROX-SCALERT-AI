#ifndef SNIPER_ULTRA_21_TRADEMANAGEMENT_MQH
#define SNIPER_ULTRA_21_TRADEMANAGEMENT_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 21_TRADE_MANAGEMENT — SL/TP · BE · Trail · Long hold · Exits
//+------------------------------------------------------------------+

// Deep TP1/TP2/TP3 + BE + trailing + hold logic lives in Shell_B_TradeSystem.mqh
// (ManageOpenTrades / ApplyProfitLockSL / GetTradeDistances).
// This module is the Ultra-facing bridge.

bool UltraTM_HasOpenOnSymbol(const string s)
{
   return (UltraSymDir(s) != 0);
}

string UltraTM_ModuleStatus()
{
   return "Shell_B ManageOpenTrades active (TP1/TP2/TP3 + BE + trail)";
}

#endif // SNIPER_ULTRA_21_TRADEMANAGEMENT_MQH
