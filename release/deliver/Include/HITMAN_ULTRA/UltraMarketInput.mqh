#ifndef HITMAN_ULTRA_MARKET_INPUT_MQH
#define HITMAN_ULTRA_MARKET_INPUT_MQH
//+------------------------------------------------------------------+
//| HITMAN AI ULTRA X — LEVEL 1 ULTRA MARKET INPUT ENGINE            |
//| Tick · Price · Spread · Volume · Context · Session · News · Broker
//+------------------------------------------------------------------+

struct UltraMarketInput
{
   bool tickOK;
   bool priceOK;
   bool spreadOK;
   bool volumeOK;
   bool contextOK;
   bool sessionOK;
   bool newsOK;
   bool brokerOK;
   bool symbolOK;
   double bid, ask, spreadPts;
   long   tickVol;
   string session;
   string newsPhase;
   string broker;
   string detail;
};

UltraMarketInput g_UltraMarketInput;

bool UltraInput_Process(const string s, UltraMarketInput &in)
{
   in.tickOK = in.priceOK = in.spreadOK = in.volumeOK = false;
   in.contextOK = in.sessionOK = in.newsOK = in.brokerOK = in.symbolOK = false;
   in.bid = SymbolInfoDouble(s, SYMBOL_BID);
   in.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   long spr = 0; SymbolInfoInteger(s, SYMBOL_SPREAD, spr);
   in.spreadPts = (double)spr;
   in.tickVol = iTickVolume(s, UltraETF(), 0);
   if(in.tickVol <= 0) in.tickVol = iVolume(s, UltraETF(), 0);
   in.session = "";
   in.newsPhase = "";
   in.broker = AccountInfoString(ACCOUNT_COMPANY);
   in.detail = "OK";

   long sel = 0;
   in.symbolOK = (s != "" && SymbolInfoInteger(s, SYMBOL_SELECT, sel) && sel != 0);
   in.priceOK = (in.bid > 0.0 && in.ask >= in.bid);
   in.tickOK = in.priceOK && (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   in.spreadOK = (in.spreadPts >= 0.0);
   in.volumeOK = (in.tickVol >= 0);
   in.brokerOK = (AccountInfoInteger(ACCOUNT_LOGIN) != 0) &&
                 (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0);
   in.sessionOK = true;  // context only — never hard-block
   in.newsOK = true;     // context only — never hard-block
   in.contextOK = in.tickOK && in.priceOK && in.symbolOK;
   g_UltraMarketInput = in;
   return in.contextOK;
}

string UltraInput_Dashboard()
{
   string t = "INPUT: ";
   if(g_UltraMarketInput.contextOK) t += "OK"; else t += "FAIL";
   t += " spr=";
   t += DoubleToString(g_UltraMarketInput.spreadPts, 0);
   t += " vol=";
   t += IntegerToString((int)g_UltraMarketInput.tickVol);
   return t;
}

#endif
