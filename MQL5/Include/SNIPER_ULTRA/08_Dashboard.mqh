#ifndef SNIPER_ULTRA_08_DASH_MQH
#define SNIPER_ULTRA_08_DASH_MQH
//+------------------------------------------------------------------+
//| 08. Dashboard System                                             |
//+------------------------------------------------------------------+
string UltraDashboardText(const string s)
{
   UltraSnap u = g_UltraLastSnap;
   UltraSignal sig = g_UltraLastSignal;
   string dir = sig.buy ? "BUY" : (sig.sell ? "SELL" : "-");
   return
      "======= SNIPER AI ULTRA MODULAR =======\n" +
      "BUILD: SA_ULTRA_93 | Comment: SNIPER AI\n" +
      "Symbol: " + s + " | TF: " + EnumToString(UltraETF()) + "\n" +
      "Open: " + IntegerToString(CountOpenTrades()) + " / " + IntegerToString(MaxOpenTrades) + "\n" +
      "AI Conf: " + IntegerToString(u.score.confidence) +
      " | Prec: " + IntegerToString(u.score.precision) +
      " | Prob: " + IntegerToString(u.score.probability) + "\n" +
      "Session: " + u.ctx.session +
      " | NewsVol: " + (u.ctx.newsVol ? "Y" : "N") +
      " | (never blocks)\n" +
      "Regime: " + UltraRegimeName(u.regime) + "\n" +
      "Trend B/S votes: " + IntegerToString(u.trend.mtfVotesBuy) + "/" + IntegerToString(u.trend.mtfVotesSell) +
      " | Str: " + IntegerToString(u.trend.strength) + "\n" +
      "BOS: " + (u.bos.buy ? "BUY" : (u.bos.sell ? "SELL" : "-")) +
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
      "===============================";
}





void CreateDashboard()
{
   // EnableDashboard (shell) OR UltraDashboardEnabled (ultra module)
   if(!EnableDashboard && !UltraDashboardEnabled)
      return;
   Comment(UltraDashboardText(BrokerSymbol));
}

#endif
