#ifndef HITMAN_ULTRA_32_BROKERCOMPAT_MQH
#define HITMAN_ULTRA_32_BROKERCOMPAT_MQH
//+------------------------------------------------------------------+
//| 32_BrokerCompatibility — fill/exec modes · stops · freeze · caps |
//+------------------------------------------------------------------+

struct UltraBrokerCaps
{
   string company;
   long   login;
   int    stopsLevel;
   int    freezeLevel;
   int    fillingMode;
   bool   fillFOK;
   bool   fillIOC;
   bool   fillRETURN;
   bool   tradeAllowed;
   bool   valid;
};

UltraBrokerCaps g_UltraBrokerCaps;

void UltraBroker_ClearCaps(UltraBrokerCaps &c)
{
   c.company = "";
   c.login = 0;
   c.stopsLevel = 0;
   c.freezeLevel = 0;
   c.fillingMode = 0;
   c.fillFOK = c.fillIOC = c.fillRETURN = false;
   c.tradeAllowed = false;
   c.valid = false;
}

bool UltraBroker_Detect(const string s, UltraBrokerCaps &c)
{
   UltraBroker_ClearCaps(c);
   c.company = AccountInfoString(ACCOUNT_COMPANY);
   c.login   = AccountInfoInteger(ACCOUNT_LOGIN);
   long stopsLevel = 0, freezeLevel = 0, fillingMode = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel);
   SymbolInfoInteger(s, SYMBOL_TRADE_FREEZE_LEVEL, freezeLevel);
   SymbolInfoInteger(s, SYMBOL_FILLING_MODE, fillingMode);
   c.stopsLevel  = (int)stopsLevel;
   c.freezeLevel = (int)freezeLevel;
   c.fillingMode = (int)fillingMode;
   c.fillFOK    = ((c.fillingMode & SYMBOL_FILLING_FOK) != 0);
   c.fillIOC    = ((c.fillingMode & SYMBOL_FILLING_IOC) != 0);
   c.fillRETURN = true;
   long tmMode = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tmMode);
   c.tradeAllowed = (tmMode != 0);
   c.valid = (SymbolInfoDouble(s, SYMBOL_BID) > 0.0);
   g_UltraBrokerCaps = c;
   return c.valid;
}

ENUM_ORDER_TYPE_FILLING UltraBroker_PickFilling(const string s)
{
   UltraBrokerCaps c;
   UltraBroker_Detect(s, c);
   if(c.fillFOK) return ORDER_FILLING_FOK;
   if(c.fillIOC) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool UltraBroker_StopsOK(const string s, const double price, const double sl, const double tp, string &why)
{
   why = "";
   long stops = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL, stops);
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   if(point <= 0){ why = "bad point"; return false; }
   double minDist = stops * point;
   if(sl > 0 && MathAbs(price - sl) < minDist){ why = "SL inside stops level"; return false; }
   if(tp > 0 && MathAbs(price - tp) < minDist){ why = "TP inside stops level"; return false; }
   return true;
}

bool UltraBroker_FreezeOK(const string s, const double price, const double sl, const double tp, string &why)
{
   why = "";
   long freeze = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_FREEZE_LEVEL, freeze);
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   if(freeze <= 0 || point <= 0) return true;
   double minDist = freeze * point;
   if(sl > 0 && MathAbs(price - sl) < minDist){ why = "SL inside freeze level"; return false; }
   if(tp > 0 && MathAbs(price - tp) < minDist){ why = "TP inside freeze level"; return false; }
   return true;
}

string UltraBroker_Summary(const string s)
{
   UltraBrokerCaps c; UltraBroker_Detect(s, c);
   string t = c.company;
   t += " stops="; t += IntegerToString(c.stopsLevel);
   t += " freeze="; t += IntegerToString(c.freezeLevel);
   t += " FOK=";
   if(c.fillFOK) t += "Y"; else t += "N";
   t += " IOC=";
   if(c.fillIOC) t += "Y"; else t += "N";
   return t;
}

#endif
