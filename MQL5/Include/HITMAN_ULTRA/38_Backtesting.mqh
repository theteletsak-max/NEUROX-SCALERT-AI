#ifndef HITMAN_ULTRA_38_BACKTEST_MQH
#define HITMAN_ULTRA_38_BACKTEST_MQH
//+------------------------------------------------------------------+
//| 38_Backtesting — tester detection · stats · walk-forward hooks   |
//+------------------------------------------------------------------+

bool UltraBT_IsTester()
{
   return (bool)MQLInfoInteger(MQL_TESTER);
}

bool UltraBT_IsOptimization()
{
   return (bool)MQLInfoInteger(MQL_OPTIMIZATION);
}

bool UltraBT_IsVisual()
{
   return (bool)MQLInfoInteger(MQL_VISUAL_MODE);
}

string UltraBT_ModeName()
{
   if(UltraBT_IsOptimization()) return "OPTIMIZATION";
   if(UltraBT_IsTester())
   {
      if(UltraBT_IsVisual()) return "TESTER_VISUAL";
      return "TESTER";
   }
   return "LIVE";
}

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
