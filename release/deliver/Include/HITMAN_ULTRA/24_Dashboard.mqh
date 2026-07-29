#ifndef HITMAN_ULTRA_24_DASHBOARD_MQH
#define HITMAN_ULTRA_24_DASHBOARD_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 24_DASHBOARD — AI Conf · Prec · Prob · Session · Stats
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 08. Dashboard System                                             |
//+------------------------------------------------------------------+
string UltraDashboardText(const string s)
{
   UltraSnap u = g_UltraLastSnap;
   UltraSignal sig = g_UltraLastSignal;
   string dir = sig.buy ? "BUY" : (sig.sell ? "SELL" : "-");
   return
      "======= HITMAN AI =======\n" +
      "BUILD: HA_ULTRA_93 MASTER | Comment: HITMAN AI\n" +
      "Symbol: " + s + " | TF: " + EnumToString(UltraETF()) + "\n" +
      "Open: " + IntegerToString(CountOpenTrades()) + " / " + IntegerToString(MaxOpenTrades) + "\n" +
      "AI Conf: " + IntegerToString(u.score.confidence) +
      " | Prec: " + IntegerToString(u.score.precision) +
      " | Prob: " + IntegerToString(u.score.probability) + "\n" +
      "Session: " + u.ctx.session +
      " | LiqWin: " + (u.ctx.sessionLiquidity ? "Y" : "N") +
      " | News: " + u.ctx.newsPhase +
      " | NewsVol: " + (u.ctx.newsVol ? "Y" : "N") +
      " | (never blocks)\n" +
      "Regime: " + UltraRegimeName(u.regime) + "\n" +
      "Trend B/S votes: " + IntegerToString(u.trend.mtfVotesBuy) + "/" + IntegerToString(u.trend.mtfVotesSell) +
      " | Str: " + IntegerToString(u.trend.strength) + "\n" +
      "BOS: " + (u.bos.buy ? "BUY" : (u.bos.sell ? "SELL" : "-")) +
      (u.bos.strong ? " STRONG" : (u.bos.weak ? " WEAK" : "")) +
      (u.bos.failed ? " FAILED" : "") +
      " CHoCH: " + (u.choch.buy ? "BUY" : (u.choch.sell ? "SELL" : "-")) +
      " Sweep: " + (u.liq.sweepBuy ? "BUY" : (u.liq.sweepSell ? "SELL" : "-")) + "\n" +
      "Fib zone B/S: " + (u.fib.atBuyZone ? "Y" : "N") + "/" + (u.fib.atSellZone ? "Y" : "N") +
      " rank=" + IntegerToString(u.fib.zoneRank) + "\n" +
      "SMI: " + DoubleToString(u.ind.smi, 1) +
      " | MEO: " + DoubleToString(u.ind.meo, 1) +
      " | IFI: " + DoubleToString(u.ind.ifi, 1) + "\n" +
      "Vol: " + (u.vol.expansion ? "EXPAND" : (u.vol.compression ? "COMPRESS" : "NORMAL")) +
      " ATR=" + DoubleToString(u.vol.atr, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)) + "\n" +
      "Capital: " + (g_UltraCore.healthy ? "OK" : "CHECK") +
      " | Health: " + u.diag.health +
      " | Lat: " + IntegerToString((int)g_UltraCore.lastLatencyMs) + "ms\n" +
      "WR: " + DoubleToString(g_UltraMem.winRate, 1) + "%" +
      " PF: " + DoubleToString(g_UltraMem.profitFactor, 2) +
      " RR: " + DoubleToString(g_UltraMem.avgRR, 2) + "\n" +
      "Signal: " + dir + " [" + sig.tag + "] " + sig.reason + "\n" +
      "---- EXPLAIN ----\n" +
      (sig.explanation != "" ? sig.explanation : UltraBuildExplanation(u, (dir!="SELL"), (dir!="-"), sig.tag)) + "\n" +
      "===============================";
}





void CreateDashboard()
{
   // EnableDashboard (shell) OR UltraDashboardEnabled (ultra module)
   if(!EnableDashboard && !UltraDashboardEnabled)
      return;
   Comment(UltraDashboardText(BrokerSymbol));
}

#endif // HITMAN_ULTRA_24_DASHBOARD_MQH
