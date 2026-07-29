#ifndef SNIPER_ULTRA_25_STATISTICS_MQH
#define SNIPER_ULTRA_25_STATISTICS_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 25_STATISTICS — WR · PF · Expectancy · RR · Reports
//+------------------------------------------------------------------+

void UltraStats_Refresh()
{
   UltraMemoryUpdateFromStats();
}

double UltraStats_WinRate(){ return g_UltraMem.winRate; }
double UltraStats_ProfitFactor(){ return g_UltraMem.profitFactor; }
double UltraStats_AvgRR(){ return g_UltraMem.avgRR; }

string UltraStats_Report()
{
   return "WR=" + DoubleToString(g_UltraMem.winRate, 1) +
          "% PF=" + DoubleToString(g_UltraMem.profitFactor, 2) +
          " RR=" + DoubleToString(g_UltraMem.avgRR, 2);
}

#endif // SNIPER_ULTRA_25_STATISTICS_MQH
