#ifndef HITMAN_ULTRA_PERF_ANALYTICS_MQH
#define HITMAN_ULTRA_PERF_ANALYTICS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 12 · PERFORMANCE ANALYTICS       |
//| Measure everything · assume nothing                              |
//| NEVER trades · NEVER executes · NEVER modifies strategy          |
//| ONLY measures performance (soft Adaptive consumers stay soft)    |
//+------------------------------------------------------------------+

// 25_Statistics assembled later
string UltraStats_Report();

struct UltraPerfAnalyticsState
{
   bool   booted;
   string status;              // READY | ACTIVE | OFF
   string detail;
   // Aggregate mirrors (measure-only)
   int    trades;
   int    wins;
   int    losses;
   double winRate;
   double avgWin;
   double avgLoss;
   double profitFactor;
   double recoveryFactor;
   double expectancy;
   double maxDrawdown;
   double riskReward;
   // Quality slices
   int    entryQuality;        // from audit tradeConfidence / composite
   int    exitQuality;         // inverse exit urgency blend
   int    execQuality;
   int    riskQuality;
   int    marketQuality;       // regime/trend/liq blend
   int    systemQuality;       // composite
   // Counters (from sibling engines — read only)
   ulong  journalOpen;
   ulong  journalClose;
   ulong  decisionCount;
   ulong  execSubmit;
   ulong  execFail;
   ulong  execRecover;
   ulong  exitClosed;
   ulong  zfrRecover;
   long   lastMs;
   string lastReport;
};

UltraPerfAnalyticsState g_UltraPerfAnalytics;

void UltraPerfAnalytics_Boot()
{
   ZeroMemory(g_UltraPerfAnalytics);
   g_UltraPerfAnalytics.booted = true;
   g_UltraPerfAnalytics.status = UltraAdaptiveEnabled ? "READY" : "OFF";
   g_UltraPerfAnalytics.detail = "boot — measure only · never trades · never modifies strategy";
   g_UltraPerfAnalytics.lastReport = "";
   if(UltraAdaptiveLog || UltraFoundationLogBoot)
      UltraLog("PERF_ANALYTICS Ch12 boot Enabled=" + (UltraAdaptiveEnabled ? "Y" : "N") +
               " Analytics=" + (UltraAdaptiveAnalyticsEnabled ? "Y" : "N") +
               " BUILD=HA_ULTRA_93 NEVER_TRADES");
}

void UltraPerfAnalytics_Log(const string verb)
{
   string line = "PERF_ANALYTICS ";
   line += verb;
   line += " WR=";
   line += DoubleToString(g_UltraPerfAnalytics.winRate, 1);
   line += "% PF=";
   line += DoubleToString(g_UltraPerfAnalytics.profitFactor, 2);
   line += " EXP=";
   line += DoubleToString(g_UltraPerfAnalytics.expectancy, 2);
   line += " n=";
   line += IntegerToString(g_UltraPerfAnalytics.trades);
   line += " | ";
   line += g_UltraPerfAnalytics.detail;
   UltraLog(line);
}

//--------------------------------------------------------------------//
// SYNC — pull measure-only mirrors from Adaptive + sibling engines   //
//--------------------------------------------------------------------//
void UltraPerfAnalytics_Sync()
{
   if(!g_UltraPerfAnalytics.booted) return;

   UltraAdaptiveReview r = g_UltraAdapt.review;
   g_UltraPerfAnalytics.trades = r.trades;
   g_UltraPerfAnalytics.wins = r.wins;
   g_UltraPerfAnalytics.losses = r.losses;
   g_UltraPerfAnalytics.winRate = r.winRate;
   g_UltraPerfAnalytics.avgWin = r.avgWin;
   g_UltraPerfAnalytics.avgLoss = r.avgLoss;
   g_UltraPerfAnalytics.profitFactor = r.profitFactor;
   g_UltraPerfAnalytics.recoveryFactor = r.recoveryFactor;
   g_UltraPerfAnalytics.expectancy = r.expectancy;
   g_UltraPerfAnalytics.maxDrawdown = r.maxDrawdown;
   g_UltraPerfAnalytics.riskReward = r.riskReward;

   UltraAdaptiveAudit a = g_UltraAdapt.audit;
   g_UltraPerfAnalytics.entryQuality = a.tradeConfidence;
   g_UltraPerfAnalytics.exitQuality = 100 - a.exitUrgency;
   if(g_UltraPerfAnalytics.exitQuality < 0) g_UltraPerfAnalytics.exitQuality = 0;
   g_UltraPerfAnalytics.execQuality = a.executionQuality;
   g_UltraPerfAnalytics.riskQuality = a.riskQuality;
   g_UltraPerfAnalytics.marketQuality =
      (a.trendQuality + a.momentumQuality + a.liquidityQuality + a.volatilityQuality) / 4;
   g_UltraPerfAnalytics.systemQuality = a.composite;

   g_UltraPerfAnalytics.journalOpen = g_UltraAdapt.recordOpenCount;
   g_UltraPerfAnalytics.journalClose = g_UltraAdapt.recordCloseCount;
   g_UltraPerfAnalytics.execSubmit = g_UltraExecIntel.submitCount;
   g_UltraPerfAnalytics.execFail = g_UltraExecIntel.failCount;
   g_UltraPerfAnalytics.execRecover = g_UltraExecIntel.recoverCount;
   g_UltraPerfAnalytics.exitClosed = g_UltraExitIntel.closeCount;
   g_UltraPerfAnalytics.zfrRecover = (ulong)g_UltraZFR.recoverSuccess;

   g_UltraPerfAnalytics.status = UltraAdaptiveEnabled ? "ACTIVE" : "OFF";
   g_UltraPerfAnalytics.detail = "synced from Adaptive journal + exec/risk/exit/ZFR counters";
   g_UltraPerfAnalytics.lastMs = (long)GetTickCount();
}

//--------------------------------------------------------------------//
// JOURNAL ALIASES — never open/close trades; forward to Adaptive     //
//--------------------------------------------------------------------//
void UltraPerfAnalytics_RecordOpen(const ulong ticket, const string s,
                                   const bool isBuy, const string tag)
{
   UltraAdaptive_RecordOpen(ticket, s, isBuy, tag);
   UltraPerfAnalytics_Sync();
   if(UltraAdaptiveLog)
      UltraPerfAnalytics_Log("JOURNAL_OPEN");
}

void UltraPerfAnalytics_RecordClose(const ulong ticket, const double profit,
                                    const string exitReason, const double exitPx)
{
   UltraAdaptive_RecordClose(ticket, profit, exitReason, exitPx);
   UltraPerfAnalytics_Sync();
   if(UltraAdaptiveLog)
      UltraPerfAnalytics_Log("JOURNAL_CLOSE");
}

void UltraPerfAnalytics_NoteDecision()
{
   g_UltraPerfAnalytics.decisionCount++;
}

//--------------------------------------------------------------------//
// PERIOD REPORTS — measure closed ring by closeTime (never trades)   //
//--------------------------------------------------------------------//
void UltraPerfAnalytics_PeriodStats(const datetime since, int &trades, int &wins,
                                    double &net, double &pf, double &wr)
{
   trades = 0; wins = 0; net = 0.0; pf = 0.0; wr = 0.0;
   double gp = 0.0, gl = 0.0;
   for(int i = 0; i < g_UltraAdapt.closedN && i < ULTRA_ADAPT_CLOSED_MAX; i++)
   {
      UltraAdaptiveClosedRec c = g_UltraAdapt.closed[i];
      if(c.ticket == 0 && c.closeTime == 0) continue;
      if(since > 0 && c.closeTime < since) continue;
      trades++;
      net += c.profit;
      if(c.won) { wins++; gp += c.profit; }
      else gl += MathAbs(c.profit);
   }
   if(trades > 0) wr = 100.0 * (double)wins / (double)trades;
   if(gl > 1e-9) pf = gp / gl;
   else pf = (gp > 0.0) ? 99.0 : 0.0;
}

string UltraPerfAnalytics_ReportDaily()
{
   datetime since = TimeCurrent() - 86400;
   int n = 0, w = 0; double net = 0.0, pf = 0.0, wr = 0.0;
   UltraPerfAnalytics_PeriodStats(since, n, w, net, pf, wr);
   string t = "DAILY: n=";
   t += IntegerToString(n);
   t += " WR=";
   t += DoubleToString(wr, 1);
   t += "% PF=";
   t += DoubleToString(pf, 2);
   t += " net=";
   t += DoubleToString(net, 2);
   g_UltraPerfAnalytics.lastReport = t;
   return t;
}

string UltraPerfAnalytics_ReportWeekly()
{
   datetime since = TimeCurrent() - 7 * 86400;
   int n = 0, w = 0; double net = 0.0, pf = 0.0, wr = 0.0;
   UltraPerfAnalytics_PeriodStats(since, n, w, net, pf, wr);
   string t = "WEEKLY: n=";
   t += IntegerToString(n);
   t += " WR=";
   t += DoubleToString(wr, 1);
   t += "% PF=";
   t += DoubleToString(pf, 2);
   t += " net=";
   t += DoubleToString(net, 2);
   g_UltraPerfAnalytics.lastReport = t;
   return t;
}

string UltraPerfAnalytics_ReportMonthly()
{
   datetime since = TimeCurrent() - 30 * 86400;
   int n = 0, w = 0; double net = 0.0, pf = 0.0, wr = 0.0;
   UltraPerfAnalytics_PeriodStats(since, n, w, net, pf, wr);
   string t = "MONTHLY: n=";
   t += IntegerToString(n);
   t += " WR=";
   t += DoubleToString(wr, 1);
   t += "% PF=";
   t += DoubleToString(pf, 2);
   t += " net=";
   t += DoubleToString(net, 2);
   g_UltraPerfAnalytics.lastReport = t;
   return t;
}

string UltraPerfAnalytics_ReportOverall()
{
   UltraPerfAnalytics_Sync();
   UltraAdaptiveReview r = g_UltraAdapt.review;
   string t = "OVERALL: WR=";
   t += DoubleToString(r.winRate, 1);
   t += "% PF=";
   t += DoubleToString(r.profitFactor, 2);
   t += " RF=";
   t += DoubleToString(r.recoveryFactor, 2);
   t += " EXP=";
   t += DoubleToString(r.expectancy, 2);
   t += " DD=";
   t += DoubleToString(r.maxDrawdown, 2);
   t += " RR=";
   t += DoubleToString(r.riskReward, 2);
   t += " n=";
   t += IntegerToString(r.trades);
   t += " | bestSess=";
   t += r.bestSession;
   t += " bestSym=";
   t += r.bestSymbol;
   t += " | ";
   t += UltraStats_Report();
   g_UltraPerfAnalytics.lastReport = t;
   return t;
}

//--------------------------------------------------------------------//
// OUTPUT SLICES — performance / trading / strategy / risk / exec     //
//--------------------------------------------------------------------//
string UltraPerfAnalytics_TradingStats()
{
   UltraPerfAnalytics_Sync();
   string t = "TRADE: n=";
   t += IntegerToString(g_UltraPerfAnalytics.trades);
   t += " W/L=";
   t += IntegerToString(g_UltraPerfAnalytics.wins);
   t += "/";
   t += IntegerToString(g_UltraPerfAnalytics.losses);
   t += " AW=";
   t += DoubleToString(g_UltraPerfAnalytics.avgWin, 2);
   t += " AL=";
   t += DoubleToString(g_UltraPerfAnalytics.avgLoss, 2);
   return t;
}

string UltraPerfAnalytics_StrategyStats()
{
   UltraAdaptiveReview r = g_UltraAdapt.review;
   string t = "STRAT: thesis=";
   t += r.bestThesis;
   t += " TF=";
   t += r.bestTimeframe;
   t += " PF=";
   t += DoubleToString(r.profitFactor, 2);
   t += " EXP=";
   t += DoubleToString(r.expectancy, 2);
   return t;
}

string UltraPerfAnalytics_RiskStats()
{
   UltraPerfAnalytics_Sync();
   string t = "RISK: Q=";
   t += IntegerToString(g_UltraPerfAnalytics.riskQuality);
   t += " DD=";
   t += DoubleToString(g_UltraPerfAnalytics.maxDrawdown, 2);
   t += " RF=";
   t += DoubleToString(g_UltraPerfAnalytics.recoveryFactor, 2);
   t += " scale=";
   t += DoubleToString(g_UltraAdapt.audit.riskScale, 2);
   t += " mgn=";
   t += g_UltraRiskIntel.marginStatus;
   return t;
}

string UltraPerfAnalytics_ExecStats()
{
   UltraPerfAnalytics_Sync();
   string t = "EXEC: Q=";
   t += IntegerToString(g_UltraPerfAnalytics.execQuality);
   t += " sub=";
   t += IntegerToString((int)g_UltraPerfAnalytics.execSubmit);
   t += " fail=";
   t += IntegerToString((int)g_UltraPerfAnalytics.execFail);
   t += " rec=";
   t += IntegerToString((int)g_UltraPerfAnalytics.execRecover);
   t += " class=";
   t += g_UltraAdapt.review.bestExecClass;
   return t;
}

string UltraPerfAnalytics_MarketStats()
{
   UltraPerfAnalytics_Sync();
   string t = "MKT: Q=";
   t += IntegerToString(g_UltraPerfAnalytics.marketQuality);
   t += " sess=";
   t += g_UltraAdapt.review.bestSession;
   t += " newsWorst=";
   t += g_UltraAdapt.review.worstNews;
   t += " trendQ=";
   t += IntegerToString(g_UltraAdapt.audit.trendQuality);
   t += " momQ=";
   t += IntegerToString(g_UltraAdapt.audit.momentumQuality);
   return t;
}

string UltraPerfAnalytics_SystemStats()
{
   UltraPerfAnalytics_Sync();
   string t = "SYS: Q=";
   t += IntegerToString(g_UltraPerfAnalytics.systemQuality);
   t += " openJ=";
   t += IntegerToString((int)g_UltraPerfAnalytics.journalOpen);
   t += " closeJ=";
   t += IntegerToString((int)g_UltraPerfAnalytics.journalClose);
   t += " exits=";
   t += IntegerToString((int)g_UltraPerfAnalytics.exitClosed);
   t += " zfr=";
   t += IntegerToString((int)g_UltraPerfAnalytics.zfrRecover);
   t += " | NEVER_TRADES";
   return t;
}

string UltraPerfAnalytics_Dashboard()
{
   UltraPerfAnalytics_Sync();
   string t = "PERF12: ";
   if(!UltraAdaptiveEnabled) { t += "OFF"; return t; }
   t += g_UltraPerfAnalytics.status;
   t += " WR=";
   t += DoubleToString(g_UltraPerfAnalytics.winRate, 1);
   t += "% PF=";
   t += DoubleToString(g_UltraPerfAnalytics.profitFactor, 2);
   t += " EXP=";
   t += DoubleToString(g_UltraPerfAnalytics.expectancy, 2);
   t += " n=";
   t += IntegerToString(g_UltraPerfAnalytics.trades);
   t += " | EntQ=";
   t += IntegerToString(g_UltraPerfAnalytics.entryQuality);
   t += " ExitQ=";
   t += IntegerToString(g_UltraPerfAnalytics.exitQuality);
   t += " ExecQ=";
   t += IntegerToString(g_UltraPerfAnalytics.execQuality);
   return t;
}

// Soft getters — document as soft bias only (strategy unchanged)
double UltraPerfAnalytics_RiskScale(){ return UltraAdaptive_RiskScale(); }
double UltraPerfAnalytics_TargetScale(){ return UltraAdaptive_TargetScale(); }

#endif // HITMAN_ULTRA_PERF_ANALYTICS_MQH
