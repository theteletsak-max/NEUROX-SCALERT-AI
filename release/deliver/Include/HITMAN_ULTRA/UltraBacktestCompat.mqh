#ifndef HITMAN_ULTRA_BACKTEST_COMPAT_MQH
#define HITMAN_ULTRA_BACKTEST_COMPAT_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA BACKTEST COMPATIBILITY ENGINE ∞                |
//| Same strategy · Same decisions · Tester / Demo / Live            |
//| Tester mode disables live-only gates; never changes strategy.    |
//+------------------------------------------------------------------+

struct UltraBacktestState
{
   bool   tester;
   bool   optimization;
   bool   visual;
   bool   compatMode;          // Tester Compatibility Mode active
   bool   liveOnlyDisabled;    // quote-age / terminal-connected hard gates softened
   bool   histOK;
   bool   handlesOK;
   bool   buffersOK;
   bool   symbolOK;
   bool   timeframeOK;
   bool   tickOK;
   bool   sessionOK;
   bool   newsOK;
   bool   tradePermOK;
   bool   marginOK;
   bool   stopsOK;
   bool   freezeOK;
   bool   lotOK;
   bool   ready;               // pre-trade ready
   string modeName;
   string detail;
   long   lastReadyMs;
   ulong  rejectCount;
   ulong  readyPassCount;
};

UltraBacktestState g_UltraBT;

//--------------------------------------------------------------------//
// DETECTION                                                          //
//--------------------------------------------------------------------//
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

bool UltraBT_IsDemo()
{
   if(UltraBT_IsTester()) return false;
   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   return (mode == ACCOUNT_TRADE_MODE_DEMO);
}

bool UltraBT_IsLiveAccount()
{
   if(UltraBT_IsTester()) return false;
   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   return (mode == ACCOUNT_TRADE_MODE_REAL);
}

string UltraBT_ModeName()
{
   if(UltraBT_IsOptimization()) return "OPTIMIZATION";
   if(UltraBT_IsTester())
   {
      if(UltraBT_IsVisual()) return "TESTER_VISUAL";
      return "TESTER";
   }
   if(UltraBT_IsDemo()) return "DEMO";
   if(UltraBT_IsLiveAccount()) return "LIVE";
   return "LIVE";
}

bool UltraBT_CompatMode()
{
   if(!UltraBacktestCompatEnabled) return false;
   return UltraBT_IsTester();
}

//--------------------------------------------------------------------//
// LIVE-ONLY REPLACEMENTS (same strategy — softer environment gates)  //
//--------------------------------------------------------------------//
bool UltraBT_ConnectedOK()
{
   // Strategy Tester has no terminal "connection" in the live sense
   if(UltraBT_CompatMode()) return true;
   return (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);
}

bool UltraBT_TradeAllowed()
{
   // Tester: MQL trade allow is the authority; terminal flag is unreliable
   if(UltraBT_CompatMode())
      return (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);
   return (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) != 0) &&
          (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);
}

bool UltraBT_SkipLiveOnly()
{
   // Disable live-only features: stale quote age, disconnect hard-fail, etc.
   return UltraBT_CompatMode();
}

bool UltraBT_RelaxEntryDrift()
{
   // In tester, modeled prices can jump between decide and send
   return UltraBT_CompatMode();
}

//--------------------------------------------------------------------//
// HISTORICAL / INDICATOR / BROKER VALIDATION                         //
//--------------------------------------------------------------------//
bool UltraBT_ValidateHistory(const string s, string &why)
{
   why = "";
   ENUM_TIMEFRAMES tf = UltraETF();
   int bars = Bars(s, tf);
   int need = UltraBacktestMinBars;
   if(need < 60) need = 60;
   if(bars < need)
   { why = "insufficient historical bars (" + IntegerToString(bars) + "<" + IntegerToString(need) + ")"; return false; }
   if(iTime(s, tf, 1) <= 0 || iClose(s, tf, 1) <= 0.0)
   { why = "closed bar history invalid"; return false; }
   return true;
}

bool UltraBT_ValidateBuffers(const string s, string &why)
{
   why = "";
   ENUM_TIMEFRAMES tf = UltraETF();
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(s, tf, 0, 16, rates);
   if(n < 8)
   { why = "CopyRates/buffer validation failed"; return false; }
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(s, tf, 0, 8, close) < 5)
   { why = "CopyClose validation failed"; return false; }
   return true;
}

bool UltraBT_ValidateSymbolTF(const string s, string &why)
{
   why = "";
   if(StringLen(s) == 0){ why = "empty symbol"; return false; }
   long sel = 0;
   if(!SymbolInfoInteger(s, SYMBOL_SELECT, sel) || sel == 0)
   {
      if(!SymbolSelect(s, true))
      { why = "symbol not selectable"; return false; }
   }
   ENUM_TIMEFRAMES tf = UltraETF();
   if(tf <= 0){ why = "invalid timeframe"; return false; }
   return true;
}

bool UltraBT_ValidateTick(const string s, string &why)
{
   why = "";
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0){ why = "tick bid/ask invalid"; return false; }
   if(ask < bid){ why = "ask < bid"; return false; }
   return true;
}

bool UltraBT_ValidateBrokerRules(const string s, string &why)
{
   why = "";
   long stops = UltraSymStopsLevel(s);
   long freeze = UltraSymFreezeLevel(s);
   // Levels themselves are informational — invalid only if symbol trade mode off
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) || tm == 0)
   {
      // In tester some symbols report mode oddly — allow if tester + bid OK
      if(!(UltraBT_CompatMode() && SymbolInfoDouble(s, SYMBOL_BID) > 0.0))
      { why = "symbol trade mode disabled"; return false; }
   }
   double minLot = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0 || maxLot < minLot || step <= 0.0)
   { why = "lot constraints invalid"; return false; }
   // Stash for dashboard
   g_UltraBT.stopsOK = (stops >= 0);
   g_UltraBT.freezeOK = (freeze >= 0);
   g_UltraBT.lotOK = true;
   return true;
}

bool UltraBT_ValidateMargin(string &why)
{
   why = "";
   double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(free < 0.0){ why = "margin free negative"; return false; }
   // Tester can start with tiny deposit — only fail if zero and not tester
   if(free <= 0.0 && !UltraBT_CompatMode())
   { why = "no free margin"; return false; }
   return true;
}

bool UltraBT_ValidateHandles(string &why)
{
   why = "";
   // Soft: if handles array empty (pre-init) OK; if all invalid after boot → fail
   int n = ArraySize(EMAHandles);
   if(n <= 0) return true;
   int good = 0, bad = 0;
   for(int i = 0; i < n; i++)
   {
      if(EMAHandles[i] == INVALID_HANDLE) bad++;
      else if(EMAHandles[i] != 0) good++;
   }
   if(g_UltraFoundation.booted && good == 0 && bad > 0)
   { why = "indicator handles invalid"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// PRE-TRADE READY PIPELINE                                           //
//--------------------------------------------------------------------//
bool UltraBT_PreTradeReady(const string s, string &why)
{
   why = "";
   g_UltraBT.ready = false;
   g_UltraBT.histOK = g_UltraBT.handlesOK = g_UltraBT.buffersOK = false;
   g_UltraBT.symbolOK = g_UltraBT.timeframeOK = g_UltraBT.tickOK = false;
   g_UltraBT.sessionOK = g_UltraBT.newsOK = true; // never hard-block
   g_UltraBT.tradePermOK = g_UltraBT.marginOK = false;
   g_UltraBT.stopsOK = g_UltraBT.freezeOK = g_UltraBT.lotOK = false;

   string w = "";
   if(!UltraBT_ValidateSymbolTF(s, w))
   { why = w; g_UltraBT.detail = w; return false; }
   g_UltraBT.symbolOK = true;
   g_UltraBT.timeframeOK = true;

   if(!UltraBT_ValidateHistory(s, w))
   { why = w; g_UltraBT.detail = w; return false; }
   g_UltraBT.histOK = true;

   if(!UltraBT_ValidateBuffers(s, w))
   { why = w; g_UltraBT.detail = w; return false; }
   g_UltraBT.buffersOK = true;

   if(!UltraBT_ValidateHandles(w))
   { why = w; g_UltraBT.detail = w; return false; }
   g_UltraBT.handlesOK = true;

   if(!UltraBT_ValidateTick(s, w))
   { why = w; g_UltraBT.detail = w; return false; }
   g_UltraBT.tickOK = true;

   if(!UltraBT_TradeAllowed())
   { why = "trade not allowed"; g_UltraBT.detail = why; return false; }
   g_UltraBT.tradePermOK = true;

   if(!UltraBT_ValidateMargin(w))
   { why = w; g_UltraBT.detail = w; return false; }
   g_UltraBT.marginOK = true;

   if(!UltraBT_ValidateBrokerRules(s, w))
   { why = w; g_UltraBT.detail = w; return false; }

   g_UltraBT.ready = true;
   g_UltraBT.readyPassCount++;
   g_UltraBT.detail = "READY " + g_UltraBT.modeName;
   g_UltraBT.lastReadyMs = (long)GetTickCount();
   why = g_UltraBT.detail;
   return true;
}

//--------------------------------------------------------------------//
// STRUCTURED REJECT LOGGER                                           //
//--------------------------------------------------------------------//
void UltraBT_LogReject(const string module, const string func, const string reason)
{
   g_UltraBT.rejectCount++;
   UltraSnap u = g_UltraLastSnap;
   long spr = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spr);
   if(u.ctx.spreadPts > 0.0) spr = (long)u.ctx.spreadPts;

   string trend = "FLAT";
   if(u.trend.bull && !u.trend.bear) trend = "BULL";
   else if(u.trend.bear && !u.trend.bull) trend = "BEAR";
   else if(u.trend.bull && u.trend.bear) trend = "MIXED";

   string mkt = (StringLen(u.st.cycleName) > 0) ? u.st.cycleName : "UNKNOWN";

   string news = u.ctx.eventClass;
   if(StringLen(news) == 0 || news == "NONE")
      news = (StringLen(u.ctx.newsPhase) > 0 ? u.ctx.newsPhase : "NONE");

   string mission = "n/a";
   // Mission sticky entry (defined later in assemble — guarded via core flags)
   if(g_UltraCore.validated && g_UltraCore.chainOK) mission = "CHAIN_OK";
   if(!g_UltraCore.validated) mission = "NOT_VALIDATED";

   string execSt = UltraBT_TradeAllowed() ? "TRADE_OK" : "TRADE_BLOCKED";
   if(!UltraBT_ConnectedOK()) execSt = "NO_CONN";

   string t = "";
   t += "TRADE REJECTED\n";
   t += "Module: "; t += module; t += "\n";
   t += "Function: "; t += func; t += "\n";
   t += "Reason: "; t += reason; t += "\n";
   t += "Confidence: "; t += IntegerToString(u.score.confidence); t += "%\n";
   t += "Spread: "; t += IntegerToString((int)spr); t += "\n";
   t += "Trend: "; t += trend; t += "\n";
   t += "Market State: "; t += mkt; t += "\n";
   t += "News: "; t += news; t += "\n";
   t += "Event: "; t += u.ctx.newsPhase; t += "\n";
   t += "Mission Control: "; t += mission; t += "\n";
   t += "Execution Status: "; t += execSt; t += "\n";
   t += "Mode: "; t += UltraBT_ModeName();

   if(UltraBacktestLogRejects || UltraLoggingEnabled)
      Print(t);

   UltraLogDecision("TRADE_REJECTED", 0, "-", module, u.score.confidence, 0,
                    func, news, (double)spr, u.ctx.slipProxy, reason);
}

//--------------------------------------------------------------------//
void UltraBT_Boot()
{
   g_UltraBT.tester = UltraBT_IsTester();
   g_UltraBT.optimization = UltraBT_IsOptimization();
   g_UltraBT.visual = UltraBT_IsVisual();
   g_UltraBT.compatMode = UltraBT_CompatMode();
   g_UltraBT.liveOnlyDisabled = g_UltraBT.compatMode;
   g_UltraBT.histOK = g_UltraBT.handlesOK = g_UltraBT.buffersOK = false;
   g_UltraBT.symbolOK = g_UltraBT.timeframeOK = g_UltraBT.tickOK = false;
   g_UltraBT.sessionOK = g_UltraBT.newsOK = true;
   g_UltraBT.tradePermOK = g_UltraBT.marginOK = false;
   g_UltraBT.stopsOK = g_UltraBT.freezeOK = g_UltraBT.lotOK = false;
   g_UltraBT.ready = false;
   g_UltraBT.modeName = UltraBT_ModeName();
   g_UltraBT.detail = g_UltraBT.compatMode ? "COMPAT_ON" : "NATIVE";
   g_UltraBT.lastReadyMs = 0;
   g_UltraBT.rejectCount = 0;
   g_UltraBT.readyPassCount = 0;

   if(UltraBacktestLogBoot)
   {
      UltraLog("BACKTEST COMPAT ∞ mode=" + g_UltraBT.modeName +
               " compat=" + (g_UltraBT.compatMode ? "Y" : "N") +
               " liveOnlyDisabled=" + (g_UltraBT.liveOnlyDisabled ? "Y" : "N") +
               " | Same strategy Tester/Demo/Live | BUILD=HA_ULTRA_93");
   }
}

string UltraBT_Dashboard()
{
   string t = "BT: ";
   t += g_UltraBT.modeName;
   if(g_UltraBT.compatMode) t += " COMPAT";
   t += g_UltraBT.ready ? " READY" : "";
   t += " rej=";
   t += IntegerToString((int)g_UltraBT.rejectCount);
   return t;
}

#endif // HITMAN_ULTRA_BACKTEST_COMPAT_MQH
