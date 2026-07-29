#ifndef HITMAN_ULTRA_02_DATA_MQH
#define HITMAN_ULTRA_02_DATA_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 02_DATA — Tick · Candle · Symbol · Broker · Spread · Cache
//+------------------------------------------------------------------+

struct UltraDataCache
{
   string   symbol;
   datetime barTime;
   double   bid, ask;
   double   spreadPts;
   double   atr;
   bool     valid;
};

UltraDataCache g_UltraDataCache;

bool UltraData_Refresh(const string s)
{
   g_UltraDataCache.symbol = s;
   g_UltraDataCache.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraDataCache.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   g_UltraDataCache.spreadPts = (double)SymbolInfoInteger(s, SYMBOL_SPREAD);
   g_UltraDataCache.barTime = iTime(s, UltraETF(), 0);
   g_UltraDataCache.atr = UltraATR(s, ATR_Period);
   g_UltraDataCache.valid = (g_UltraDataCache.bid > 0 && g_UltraDataCache.ask > 0);
   return g_UltraDataCache.valid;
}

double UltraData_Bid(const string s){ return SymbolInfoDouble(s, SYMBOL_BID); }
double UltraData_Ask(const string s){ return SymbolInfoDouble(s, SYMBOL_ASK); }
double UltraData_Spread(const string s){ return (double)SymbolInfoInteger(s, SYMBOL_SPREAD); }
int    UltraData_Digits(const string s){ return (int)SymbolInfoInteger(s, SYMBOL_DIGITS); }
double UltraData_Point(const string s){ return SymbolInfoDouble(s, SYMBOL_POINT); }

double UltraData_Open(const string s, const int shift){ return iOpen(s, UltraETF(), shift); }
double UltraData_High(const string s, const int shift){ return iHigh(s, UltraETF(), shift); }
double UltraData_Low(const string s, const int shift){ return iLow(s, UltraETF(), shift); }
double UltraData_Close(const string s, const int shift){ return iClose(s, UltraETF(), shift); }

bool UltraData_BrokerInfo(string &company, long &login)
{
   company = AccountInfoString(ACCOUNT_COMPANY);
   login = AccountInfoInteger(ACCOUNT_LOGIN);
   return (login != 0);
}

#endif // HITMAN_ULTRA_02_DATA_MQH
