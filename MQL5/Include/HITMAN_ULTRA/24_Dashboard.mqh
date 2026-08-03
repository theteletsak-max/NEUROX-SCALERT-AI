#ifndef HITMAN_ULTRA_24_DASHBOARD_MQH
#define HITMAN_ULTRA_24_DASHBOARD_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 24_DASHBOARD — Chapter 14 display surface            |
//| NEVER trades · NEVER executes · ONLY displays (via Dash Intel)   |
//+------------------------------------------------------------------+
string UltraDashboardText(const string s)
{
   // Chapter 14 — one composition from Dashboard Intelligence panels
   return UltraDashboardIntel_Build(s);
}

void CreateDashboard()
{
   if(!EnableDashboard && !UltraDashboardEnabled)
      return;
   UltraDashboardIntel_Refresh(BrokerSymbol);
}

#endif // HITMAN_ULTRA_24_DASHBOARD_MQH
