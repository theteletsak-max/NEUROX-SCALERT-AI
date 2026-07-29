#ifndef SNIPER_ULTRA_36_BROKERHEALTH_MQH
#define SNIPER_ULTRA_36_BROKERHEALTH_MQH
//+------------------------------------------------------------------+
//| 36_BrokerHealth — connection · permissions · market · symbols    |
//+------------------------------------------------------------------+

struct UltraBrokerHealth
{
   bool connected;
   bool tradeAllowed;
   bool terminalTrade;
   bool marketOpen;      // soft: has quotes
   bool symbolOK;
   long pingMs;          // TerminalInfoInteger TERMINAL_PING approx if available
   string status;
};

UltraBrokerHealth g_UltraBrokerHealth;

void UltraHealth_Update(const string s)
{
   g_UltraBrokerHealth.connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   g_UltraBrokerHealth.terminalTrade = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   g_UltraBrokerHealth.tradeAllowed = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
   g_UltraBrokerHealth.symbolOK = (SymbolInfoInteger(s, SYMBOL_SELECT) != 0);
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraBrokerHealth.marketOpen = (bid > 0.0);
   g_UltraBrokerHealth.pingMs = 0; // broker RTT probe reserved
   if(!g_UltraBrokerHealth.connected) g_UltraBrokerHealth.status = "DISCONNECTED";
   else if(!g_UltraBrokerHealth.terminalTrade || !g_UltraBrokerHealth.tradeAllowed) g_UltraBrokerHealth.status = "TRADE_BLOCKED";
   else if(!g_UltraBrokerHealth.symbolOK) g_UltraBrokerHealth.status = "SYMBOL_BAD";
   else if(!g_UltraBrokerHealth.marketOpen) g_UltraBrokerHealth.status = "NO_QUOTES";
   else g_UltraBrokerHealth.status = "OK";
}

bool UltraHealth_OK(const string s)
{
   UltraHealth_Update(s);
   return (g_UltraBrokerHealth.status == "OK");
}

string UltraHealth_Summary(const string s)
{
   UltraHealth_Update(s);
   return g_UltraBrokerHealth.status + " pingMs=" + IntegerToString((int)g_UltraBrokerHealth.pingMs);
}

#endif
