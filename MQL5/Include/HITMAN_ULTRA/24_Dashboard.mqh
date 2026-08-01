#ifndef HITMAN_ULTRA_24_DASHBOARD_MQH
#define HITMAN_ULTRA_24_DASHBOARD_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 24_DASHBOARD — Master · Regime · Thesis · Hold · Risk
//+------------------------------------------------------------------+
string UltraDashboardText(const string s)
{
   UltraSnap u = g_UltraLastSnap;
   UltraSignal sig = g_UltraLastSignal;
   string dir = "-";
   if(sig.buy) dir = "BUY";
   else if(sig.sell) dir = "SELL";
   if(g_UltraBrainLast.decision == SUP_BUY) dir = "BUY";
   else if(g_UltraBrainLast.decision == SUP_SELL) dir = "SELL";
   else if(g_UltraBrainLast.decision == SUP_WAIT && !(sig.buy || sig.sell)) dir = "WAIT";

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

   string master = "-";
   int md = UltraMTF_MasterDir(s);
   if(md > 0) master = "BUY";
   else if(md < 0) master = "SELL";

   string explain = sig.explanation;
   if(StringLen(explain) == 0)
   {
      bool leanBuy = (dir != "SELL");
      bool approved = (dir == "BUY" || dir == "SELL");
      explain = UltraUFSE_DebugExplain(u, leanBuy, approved);
   }

   string t = "======= HITMAN AI =======\n";
   t += "BUILD: HA_ULTRA_93 MASTER | Comment: HITMAN AI\n";
   t += "Symbol: "; t += s;
   t += " | TF: "; t += EnumToString(UltraETF());
   t += "\n"; t += UltraBrain_Dashboard();
   t += "\n"; t += UltraMission_Dashboard();
   t += "\n"; t += UltraPosEvo_Dashboard();
   t += "\n"; t += UltraInput_Dashboard();
   t += " | "; t += UltraData_Dashboard();
   t += "\nMaster Trend: "; t += master;
   t += " | Regime: "; t += UltraRegimeName(u.regime);
   t += " | Cycle: "; t += u.st.cycleName;
   t += "\nOpen Trades: "; t += IntegerToString(CountOpenTrades());
   t += " / "; t += IntegerToString(MaxOpenTrades);
   t += "\nAI Conf: "; t += IntegerToString(u.score.confidence);
   t += " | Prec: "; t += IntegerToString(u.score.precision);
   t += " | Prob: "; t += IntegerToString(u.score.probability);
   t += "\n"; t += UltraThesis_Dashboard();
   t += " | "; t += UltraHold_Dashboard();
   t += "\n"; t += UltraMTF_Dashboard(s);
   t += "\nSession: "; t += u.ctx.session;
   t += " ["; t += u.ctx.sessionRegion; t += "]";
   t += " LH="; t += IntegerToString(u.ctx.londonHour);
   t += " ★"; t += IntegerToString(u.ctx.sessionPriority);
   t += " | bias="; t += IntegerToString(u.ctx.sessionBias);
   t += " | Liq="; t += IntegerToString(u.ctx.sessionLiqScore);
   t += " Tr="; t += IntegerToString(u.ctx.sessionTrendScore);
   t += " | (24/7 never blocks)";
   t += "\n"; t += UltraSession_Dashboard();
   t += " | News: "; t += u.ctx.newsPhase;
   t += "\nTrend votes B/S: "; t += IntegerToString(u.trend.mtfVotesBuy);
   t += "/"; t += IntegerToString(u.trend.mtfVotesSell);
   t += " | Str: "; t += IntegerToString(u.trend.strength);
   t += "\nBOS: "; t += bos;
   t += " CHoCH: "; t += choch;
   t += " Sweep: "; t += sweep;
   t += "\nFib zone B/S: "; if(u.fib.atBuyZone) t += "Y"; else t += "N";
   t += "/"; if(u.fib.atSellZone) t += "Y"; else t += "N";
   t += " | InstLiq B/S: "; if(u.ict.institutionalLiqBuy) t += "Y"; else t += "N";
   t += "/"; if(u.ict.institutionalLiqSell) t += "Y"; else t += "N";
   t += "\nSMI: "; t += DoubleToString(u.ind.smi, 1);
   t += " | MEO: "; t += DoubleToString(u.ind.meo, 1);
   t += " | IFI: "; t += DoubleToString(u.ind.ifi, 1);
   t += "\nVol: "; t += vol;
   long dig = 0; SymbolInfoInteger(s, SYMBOL_DIGITS, dig);
   t += " ATR="; t += DoubleToString(u.vol.atr, (int)dig);
   t += "\nExec: "; if(u.diag.brokerOK && u.diag.connectionOK) t += "READY"; else t += "CHECK";
   t += " | Risk: "; if(u.score.riskProb < 70) t += "OK"; else t += "HIGH";
   t += " | Capital: "; if(g_UltraCore.healthy) t += "OK"; else t += "CHECK";
   t += "\n"; t += UltraFoundation_Dashboard();
   t += "\n"; t += UltraMarketIntel_Dashboard();
   t += "\n"; t += UltraVChain_Dashboard();
   t += "\n"; t += UltraSystemHealth_Dashboard();
   t += " | "; t += UltraResource_Monitor();
   t += "\nWR: "; t += DoubleToString(g_UltraMem.winRate, 1); t += "%";
   t += " PF: "; t += DoubleToString(g_UltraMem.profitFactor, 2);
   t += " RR: "; t += DoubleToString(g_UltraMem.avgRR, 2);
   t += "\nSignal: "; t += dir; t += " ["; t += sig.tag; t += "] "; t += sig.reason;
   t += "\n"; t += UltraDefense_DashboardLine();
   t += " | "; t += UltraDiscipline_DashboardLine();
   t += "\n"; t += UltraSupreme_Dashboard();
   t += " | "; t += UltraMemory_Dashboard();
   if(UltraUSM2Enabled && g_UltraUSM2Last.tradeScore > 0)
   {
      t += "\nUSM2: conf="; t += IntegerToString(g_UltraUSM2Last.confidence);
      t += " score="; t += IntegerToString(g_UltraUSM2Last.tradeScore);
      t += " "; t += g_UltraUSM2Last.grade;
      t += " evo="; t += g_UltraSupremeLast.evo;
   }
   t += "\nUFSE: "; t += UltraUFSE_Stats(s);
   t += "\n"; t += UltraEvent_Dashboard();
   t += "\nEvent: "; t += u.ctx.eventClass;
   t += " phase="; t += u.ctx.newsPhase;
   t += " conf="; t += IntegerToString(u.ctx.eventConfidence);
   t += " execQ="; t += IntegerToString(u.ctx.execQuality);
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
