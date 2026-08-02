#ifndef HITMAN_ULTRA_19_EXECUTION_MQH
#define HITMAN_ULTRA_19_EXECUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 19_EXECUTION — Fast exec · Retry · Fill · Sync · Broker compat
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 04. Ultra Execution Engine                                       |
//| Fast exec · fill policy · retry · duplicate protect · sync       |
//| Bridges InstantExecution / ExecuteBuy / ExecuteSell (Shell_B)    |
//+------------------------------------------------------------------+

bool UltraExecReady(const string s, string &why)
{
   why = "";
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) || tm == 0)
   {
      // Tester: some symbols report mode oddly — allow if bid present in compat mode
      if(!(UltraBT_CompatMode() && SymbolInfoDouble(s, SYMBOL_BID) > 0.0))
      { why = "symbol trade mode off"; return false; }
   }
   if(!UltraBT_TradeAllowed()) { why = "terminal blocked"; return false; }
   // fill policy / stops validated later in ExecuteBuy/Sell
   return true;
}



bool UltraExec_DuplicateBarGuard(const string s)
{
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar <= 0) return false;
   if(g_UltraLastFireBar == bar) return true;
   return false;
}

void UltraExec_MarkFired(const string s)
{
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar > 0) g_UltraLastFireBar = bar;
}

bool UltraExec_Ready(const string s, string &why)
{
   return UltraExecReady(s, why);
}

int UltraExec_OpenCountMagic()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      n++;
   }
   return n;
}

#endif // HITMAN_ULTRA_19_EXECUTION_MQH
