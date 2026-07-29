#ifndef HITMAN_ULTRA_24_DASHBOARD_MQH
#define HITMAN_ULTRA_24_DASHBOARD_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 24_DASHBOARD — AI Conf · Prec · Prob · Session · Stats
//+------------------------------------------------------------------+
string UltraDashboardText(const string s)
{
   UltraSnap u = g_UltraLastSnap;
   UltraSignal sig = g_UltraLastSignal;
   string dir = "-";
   if(sig.buy) dir = "BUY";
   else if(sig.sell) dir = "SELL";

   string bos = "-";
   if(u.bos.buy) bos = "BUY";
   else if(u.bos.sell) bos = "SELL";
   if(u.bos.strong) bos += " STRONG";
   else if(u.bos.weak) bos += " WEAK";
   if(u.bos.failed) bos += " FAILED";

   string choch = "-";
   if(u.choch.buy) choch = "BUY";
   else if(u.choch.sell) choch = "SELL";

   string sweep = "-";
   if(u.liq.sweepBuy) sweep = "BUY";
   else if(u.liq.sweepSell) sweep = "SELL";

   string vol = "NORMAL";
   if(u.vol.expansion) vol = "EXPAND";
   else if(u.vol.compression) vol = "COMPRESS";

   string explain = sig.explanation;
   if(StringLen(explain) == 0)
   {
      bool leanBuy = (dir != "SELL");
      bool approved = (dir != "-");
      explain = UltraUFSE_DebugExplain(u, leanBuy, approved);
   }

   string t = "======= HITMAN AI =======\n";
   t += "BUILD: HA_ULTRA_93 MASTER | Comment: HITMAN AI\n";
   t += "Symbol: "; t += s;
   t += " | TF: "; t += EnumToString(UltraETF());
   t += "\nOpen: "; t += IntegerToString(CountOpenTrades());
   t += " / "; t += IntegerToString(MaxOpenTrades);
   t += "\nAI Conf: "; t += IntegerToString(u.score.confidence);
   t += " | Prec: "; t += IntegerToString(u.score.precision);
   t += " | Prob: "; t += IntegerToString(u.score.probability);
   t += "\nSession: "; t += u.ctx.session;
   t += " | LiqWin: "; if(u.ctx.sessionLiquidity) t += "Y"; else t += "N";
   t += " | News: "; t += u.ctx.newsPhase;
   t += " | NewsVol: "; if(u.ctx.newsVol) t += "Y"; else t += "N";
   t += " | (never blocks)";
   t += "\nRegime: "; t += UltraRegimeName(u.regime);
   t += "\nTrend B/S votes: "; t += IntegerToString(u.trend.mtfVotesBuy);
   t += "/"; t += IntegerToString(u.trend.mtfVotesSell);
   t += " | Str: "; t += IntegerToString(u.trend.strength);
   t += "\nBOS: "; t += bos;
   t += " CHoCH: "; t += choch;
   t += " Sweep: "; t += sweep;
   t += "\nFib zone B/S: "; if(u.fib.atBuyZone) t += "Y"; else t += "N";
   t += "/"; if(u.fib.atSellZone) t += "Y"; else t += "N";
   t += " rank="; t += IntegerToString(u.fib.zoneRank);
   t += "\nSMI: "; t += DoubleToString(u.ind.smi, 1);
   t += " | MEO: "; t += DoubleToString(u.ind.meo, 1);
   t += " | IFI: "; t += DoubleToString(u.ind.ifi, 1);
   t += "\nVol: "; t += vol;
   t += " ATR="; t += DoubleToString(u.vol.atr, (int)SymbolInfoInteger(s, SYMBOL_DIGITS));
   t += "\nCapital: "; if(g_UltraCore.healthy) t += "OK"; else t += "CHECK";
   t += " | Health: "; t += u.diag.health;
   t += " | Lat: "; t += IntegerToString((int)g_UltraCore.lastLatencyMs); t += "ms";
   t += "\nWR: "; t += DoubleToString(g_UltraMem.winRate, 1); t += "%";
   t += " PF: "; t += DoubleToString(g_UltraMem.profitFactor, 2);
   t += " RR: "; t += DoubleToString(g_UltraMem.avgRR, 2);
   t += "\nSignal: "; t += dir; t += " ["; t += sig.tag; t += "] "; t += sig.reason;
   t += "\n"; t += UltraDefense_DashboardLine();
   t += "\nUFSE: "; t += UltraUFSE_Stats(s);
   t += "\n---- EXPLAIN ----\n"; t += explain;
   t += "\n===============================";
   return t;
}

void CreateDashboard()
{
   if(!EnableDashboard && !UltraDashboardEnabled)
      return;
   Comment(UltraDashboardText(BrokerSymbol));
}

#endif // HITMAN_ULTRA_24_DASHBOARD_MQH
