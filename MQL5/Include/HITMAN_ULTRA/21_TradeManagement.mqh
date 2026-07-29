#ifndef HITMAN_ULTRA_21_TRADEMANAGEMENT_MQH
#define HITMAN_ULTRA_21_TRADEMANAGEMENT_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 21_TRADE_MANAGEMENT                             |
//| Ultra Long Holding · Dynamic SL · Dynamic TP · Break-even ·       |
//| Adaptive Trailing Stop · Intelligent Exit                         |
//|                                                                   |
//| Deep TP1/TP2/TP3 + BE + trail + hold live in Shell_B:             |
//|   ManageOpenTrades / ApplyProfitLockSL / GetTradeDistances        |
//+------------------------------------------------------------------+

bool UltraTM_HasOpenOnSymbol(const string s)
{
   return (UltraSymDir(s) != 0);
}

bool UltraTM_UltraLongHoldingEnabled()
{
   // Shell_B holds ultra-long management path; bridge flag for dashboard/status
   return true;
}

bool UltraTM_DynamicStopsActive()
{
   return true; // Shell_B dynamic SL/TP path
}

bool UltraTM_BreakEvenActive()
{
   return true; // Shell_B BE path
}

bool UltraTM_AdaptiveTrailActive()
{
   return true; // Shell_B adaptive trailing path
}

bool UltraTM_IntelligentExitActive()
{
   return true; // Shell_B intelligent exit / profit lock
}

string UltraTM_ModuleStatus()
{
   return "UltraLong+DynSL/TP+BE+Trail+IntelExit via Shell_B ManageOpenTrades";
}

#endif // HITMAN_ULTRA_21_TRADEMANAGEMENT_MQH
