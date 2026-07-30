#ifndef HITMAN_ULTRA_02_DATA_MQH
#define HITMAN_ULTRA_02_DATA_MQH
//+------------------------------------------------------------------+
//| HITMAN AI ULTRA X — LEVEL 2 ULTRA DATA CORE                      |
//| Tick cache · Smart cache · Memory · Integrity · Multi-symbol     |
//+------------------------------------------------------------------+

struct UltraDataCache
{
   string   symbol;
   datetime barTime;
   datetime tickTime;
   double   bid, ask;
   double   spreadPts;
   double   atr;
   long     tickVol;
   bool     valid;
   bool     integrityOK;
};

#define ULTRA_MSYM_CACHE_MAX 32
UltraDataCache g_UltraDataCache;
UltraDataCache g_UltraMSymCache[ULTRA_MSYM_CACHE_MAX];
int            g_UltraMSymCacheN = 0;

int UltraData_MSymFind(const string s)
{
   for(int i = 0; i < g_UltraMSymCacheN; i++)
      if(g_UltraMSymCache[i].symbol == s) return i;
   return -1;
}

int UltraData_MSymAlloc(const string s)
{
   int idx = UltraData_MSymFind(s);
   if(idx >= 0) return idx;
   if(g_UltraMSymCacheN >= ULTRA_MSYM_CACHE_MAX) return 0;
   idx = g_UltraMSymCacheN++;
   g_UltraMSymCache[idx].symbol = s;
   return idx;
}

bool UltraData_Integrity(const string s, const UltraDataCache &c)
{
   if(!c.valid) return false;
   if(c.bid <= 0.0 || c.ask < c.bid) return false;
   if(c.spreadPts < 0.0) return false;
   if(c.barTime <= 0) return false;
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm)) return false;
   return true;
}

bool UltraData_Refresh(const string s)
{
   g_UltraDataCache.symbol = s;
   g_UltraDataCache.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraDataCache.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   long spr = 0; SymbolInfoInteger(s, SYMBOL_SPREAD, spr);
   g_UltraDataCache.spreadPts = (double)spr;
   g_UltraDataCache.barTime = iTime(s, UltraETF(), 0);
   g_UltraDataCache.tickTime = TimeCurrent();
   g_UltraDataCache.atr = UltraATR(s, ATR_Period);
   g_UltraDataCache.tickVol = iTickVolume(s, UltraETF(), 0);
   if(g_UltraDataCache.tickVol <= 0)
      g_UltraDataCache.tickVol = iVolume(s, UltraETF(), 0);
   g_UltraDataCache.valid = (g_UltraDataCache.bid > 0 && g_UltraDataCache.ask > 0);
   g_UltraDataCache.integrityOK = UltraData_Integrity(s, g_UltraDataCache);

   int m = UltraData_MSymAlloc(s);
   g_UltraMSymCache[m] = g_UltraDataCache;
   return g_UltraDataCache.valid && g_UltraDataCache.integrityOK;
}

// Smart cache: reuse same-bar snapshot fields when still fresh
bool UltraData_SmartCacheHit(const string s)
{
   if(g_UltraDataCache.symbol != s) return false;
   if(!g_UltraDataCache.valid || !g_UltraDataCache.integrityOK) return false;
   datetime bar = iTime(s, UltraETF(), 0);
   return (bar > 0 && bar == g_UltraDataCache.barTime);
}

double UltraData_Bid(const string s){ return SymbolInfoDouble(s, SYMBOL_BID); }
double UltraData_Ask(const string s){ return SymbolInfoDouble(s, SYMBOL_ASK); }
double UltraData_Spread(const string s){ long v=0; SymbolInfoInteger(s, SYMBOL_SPREAD, v); return (double)v; }
int    UltraData_Digits(const string s){ long v=0; SymbolInfoInteger(s, SYMBOL_DIGITS, v); return (int)v; }
double UltraData_Point(const string s){ return SymbolInfoDouble(s, SYMBOL_POINT); }
long   UltraData_Volume(const string s)
{
   long v = iTickVolume(s, UltraETF(), 0);
   if(v <= 0) v = iVolume(s, UltraETF(), 0);
   return v;
}

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

string UltraData_Dashboard()
{
   string t = "DATA: ";
   if(g_UltraDataCache.integrityOK) t += "OK"; else t += "BAD";
   t += " msym=";
   t += IntegerToString(g_UltraMSymCacheN);
   if(UltraData_SmartCacheHit(g_UltraDataCache.symbol)) t += " CACHE";
   return t;
}

#endif // HITMAN_ULTRA_02_DATA_MQH
