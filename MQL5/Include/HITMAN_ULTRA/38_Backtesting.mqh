#ifndef HITMAN_ULTRA_38_BACKTEST_MQH
#define HITMAN_ULTRA_38_BACKTEST_MQH
//+------------------------------------------------------------------+
//| 38_Backtesting — walk-forward hooks + stats                      |
//| Core detection/compat lives in UltraBacktestCompat.mqh (early)   |
//+------------------------------------------------------------------+

void UltraBT_LogStats()
{
   if(!UltraBT_IsTester()) return;
   UltraStats_Refresh();
   UltraLogPerf("BT " + UltraBT_ModeName() + " " + UltraStats_Report());
}

// Walk-forward placeholder hooks (fill during optimization campaigns)
datetime g_UltraBT_WF_Start = 0;
datetime g_UltraBT_WF_End   = 0;

void UltraBT_SetWalkForwardWindow(const datetime from, const datetime to)
{
   g_UltraBT_WF_Start = from;
   g_UltraBT_WF_End = to;
}

bool UltraBT_InWalkForwardWindow(const datetime t)
{
   if(g_UltraBT_WF_Start <= 0 || g_UltraBT_WF_End <= 0) return true;
   return (t >= g_UltraBT_WF_Start && t <= g_UltraBT_WF_End);
}

#endif
