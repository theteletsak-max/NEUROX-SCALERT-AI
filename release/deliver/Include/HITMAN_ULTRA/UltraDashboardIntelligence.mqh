#ifndef HITMAN_ULTRA_DASHBOARD_INTELLIGENCE_MQH
#define HITMAN_ULTRA_DASHBOARD_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 14 · DASHBOARD ENGINE            |
//| Professional real-time interface — display only                  |
//| NEVER trades · NEVER executes · ONLY displays information        |
//+------------------------------------------------------------------+

// Shell_B / UFSE / Optimization (assembled later)
int    CountOpenTrades();
string UltraUFSE_DebugExplain(const UltraSnap &u, const bool buySide, const bool approved);
string UltraResource_Monitor();

enum ENUM_ULTRA_DASH_STATE
{
   UDASH_INITIALIZING = 0,
   UDASH_READY,
   UDASH_SCANNING,
   UDASH_VALIDATING,
   UDASH_EXECUTING,
   UDASH_MANAGING,
   UDASH_RECOVERING,
   UDASH_ERROR
};

struct UltraDashboardIntelState
{
   bool   booted;
   ENUM_ULTRA_DASH_STATE state;
   string stateName;
   string detail;
   ulong  refreshCount;
   ulong  tradeRefresh;
   ulong  errorRefresh;
   long   lastMs;
   string lastText;
};

UltraDashboardIntelState g_UltraDashboardIntel;

string UltraDashboardIntel_StateName(const ENUM_ULTRA_DASH_STATE st)
{
   switch(st)
   {
      case UDASH_READY:       return "READY";
      case UDASH_SCANNING:    return "SCANNING";
      case UDASH_VALIDATING:  return "VALIDATING";
      case UDASH_EXECUTING:   return "EXECUTING";
      case UDASH_MANAGING:    return "MANAGING POSITION";
      case UDASH_RECOVERING:  return "RECOVERING";
      case UDASH_ERROR:       return "ERROR";
      default:                return "INITIALIZING";
   }
}

void UltraDashboardIntel_Boot()
{
   g_UltraDashboardIntel.booted = true;
   g_UltraDashboardIntel.state = UDASH_INITIALIZING;
   g_UltraDashboardIntel.stateName = "INITIALIZING";
   g_UltraDashboardIntel.detail = "boot — display only · never trades · never executes";
   g_UltraDashboardIntel.refreshCount = 0;
   g_UltraDashboardIntel.tradeRefresh = 0;
   g_UltraDashboardIntel.errorRefresh = 0;
   g_UltraDashboardIntel.lastMs = 0;
   g_UltraDashboardIntel.lastText = "";
}

void UltraDashboardIntel_SetState(const ENUM_ULTRA_DASH_STATE st, const string detail)
{
   g_UltraDashboardIntel.state = st;
   g_UltraDashboardIntel.stateName = UltraDashboardIntel_StateName(st);
   g_UltraDashboardIntel.detail = detail;
   g_UltraDashboardIntel.lastMs = (long)GetTickCount();
}

void UltraDashboardIntel_ResolveState(const string s)
{
   if(!g_UltraDashboardIntel.booted)
   {
      UltraDashboardIntel_SetState(UDASH_INITIALIZING, "not booted");
      return;
   }
   if(g_UltraZFR.recovering)
   {
      UltraDashboardIntel_SetState(UDASH_RECOVERING, g_UltraZFR.lastAction);
      return;
   }
   if(!g_UltraCore.healthy || g_UltraLoggerIntel.diagHealth == "DEGRADED")
   {
      UltraDashboardIntel_SetState(UDASH_ERROR, "system/diag degraded");
      return;
   }
   if(g_UltraExecIntel.status == "SUBMITTING")
   {
      UltraDashboardIntel_SetState(UDASH_EXECUTING, g_UltraExecIntel.outcomeName);
      return;
   }
   int openN = CountOpenTrades();
   if(openN > 0)
   {
      UltraDashboardIntel_SetState(UDASH_MANAGING, g_UltraPosEvoIntel.outputName);
      return;
   }
   if(g_UltraTradeGate.failMask != 0 || g_UltraVChain.invalidN > 0)
   {
      UltraDashboardIntel_SetState(UDASH_VALIDATING, "gate/chain");
      return;
   }
   if(g_UltraMissionLast.command == SUP_WAIT || g_UltraMissionLast.command == SUP_HOLD)
   {
      UltraDashboardIntel_SetState(UDASH_SCANNING, g_UltraMissionLast.reason);
      return;
   }
   UltraDashboardIntel_SetState(UDASH_READY, "idle · watching market");
}

//--------------------------------------------------------------------//
// PANELS — one source of truth from Chapter facades (display only)   //
//--------------------------------------------------------------------//
string UltraDashboardIntel_PanelSystem(const string s)
{
   string t = "— SYSTEM —\n";
   t += "HITMAN AI HA_ULTRA_93 | ";
   t += g_UltraDashboardIntel.stateName;
   t += "\n";
   t += s;
   t += " ";
   t += EnumToString(UltraETF());
   t += " | ";
   t += AccountInfoString(ACCOUNT_COMPANY);
   t += "\nServer: ";
   t += TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   t += " | Local: ";
   t += TimeToString(TimeLocal(), TIME_SECONDS);
   t += "\nConn: ";
   t += (TerminalInfoInteger(TERMINAL_CONNECTED) ? "ONLINE" : "OFFLINE");
   t += " | Ping≈";
   t += IntegerToString((int)g_UltraCore.lastLatencyMs);
   t += "ms";
   return t;
}

string UltraDashboardIntel_PanelMarket(const UltraSnap &u)
{
   string t = "— MARKET —\n";
   t += UltraMarketIntel_Dashboard();
   t += "\nTrend ";
   t += (u.trend.bull ? "BULL" : (u.trend.bear ? "BEAR" : "FLAT"));
   t += " str=";
   t += IntegerToString(u.trend.strength);
   t += " | Mom ";
   t += (u.mom.momBuy ? "BUY" : (u.mom.momSell ? "SELL" : "-"));
   t += " | Vol ";
   t += (u.vol.expansion ? "EXPAND" : (u.vol.compression ? "COMPRESS" : "NORMAL"));
   t += "\nLiq=";
   t += g_UltraMarketIntel.outLiquidity;
   t += " | Q=";
   t += IntegerToString(g_UltraMarketIntel.marketQuality);
   t += " | Spread=";
   t += DoubleToString(u.ctx.spreadPts, 1);
   t += " | Sess=";
   t += u.ctx.session;
   t += " | News=";
   t += u.ctx.newsPhase;
   t += " ";
   t += u.ctx.eventClass;
   return t;
}

string UltraDashboardIntel_PanelStrategy(const UltraSnap &u, const UltraSignal &sig)
{
   string t = "— STRATEGY —\n";
   t += UltraPropStrategy_Dashboard();
   t += "\n";
   t += UltraSignalIntel_Dashboard();
   t += "\n";
   t += UltraMission_Dashboard();
   t += "\nThesis: ";
   t += UltraThesis_Dashboard();
   t += " | Conf=";
   t += IntegerToString(u.score.confidence);
   t += " | Sig=";
   if(sig.buy) t += "BUY";
   else if(sig.sell) t += "SELL";
   else t += "WAIT";
   t += " [";
   t += sig.tag;
   t += "]";
   return t;
}

string UltraDashboardIntel_PanelPosition(const string s)
{
   string t = "— POSITION —\n";
   t += UltraPosEvo_Dashboard();
   t += "\n";
   t += UltraExitIntel_Dashboard();
   t += "\n";
   t += UltraTarget_Dashboard();

   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      found = true;
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double price = isBuy ? SymbolInfoDouble(s, SYMBOL_BID) : SymbolInfoDouble(s, SYMBOL_ASK);
      int digits = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      int mins = (ot > 0) ? (int)((TimeCurrent() - ot) / 60) : 0;
      t += "\n";
      t += (isBuy ? "BUY" : "SELL");
      t += " #";
      t += IntegerToString((int)ticket);
      t += " @";
      t += DoubleToString(entry, digits);
      t += " now=";
      t += DoubleToString(price, digits);
      t += "\nSL=";
      t += DoubleToString(sl, digits);
      t += " TP=";
      t += DoubleToString(tp, digits);
      if(g_UltraTargetLast.valid)
      {
         t += " | TP1/2/3=";
         t += DoubleToString(g_UltraTargetLast.tp1, digits);
         t += "/";
         t += DoubleToString(g_UltraTargetLast.tp2, digits);
         t += "/";
         t += DoubleToString(g_UltraTargetLast.tp3, digits);
      }
      t += "\nFloatP=";
      t += DoubleToString((profit > 0.0 ? profit : 0.0), 2);
      t += " | FloatL=";
      t += DoubleToString((profit < 0.0 ? -profit : 0.0), 2);
      t += " | Dur=";
      t += IntegerToString(mins);
      t += "m";
      break;
   }
   if(!found)
   {
      t += "\nOpen: ";
      t += IntegerToString(CountOpenTrades());
      t += "/";
      t += IntegerToString(MaxOpenTrades);
      t += " (flat)";
   }
   return t;
}

string UltraDashboardIntel_PanelRisk()
{
   string t = "— RISK —\n";
   t += UltraRiskIntel_Dashboard();
   t += "\nFreeM=";
   t += DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);
   t += " | MLevel=";
   double used = AccountInfoDouble(ACCOUNT_MARGIN);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(used > 0.0) t += DoubleToString((eq / used) * 100.0, 1);
   else t += "—";
   t += "% | Lot=";
   t += DoubleToString(g_UltraRiskIntel.approvedLot, 2);
   t += " | DD=";
   t += DoubleToString(g_UltraRiskIntel.drawdownPct, 2);
   t += "%";
   return t;
}

string UltraDashboardIntel_PanelPerformance()
{
   string t = "— PERFORMANCE —\n";
   t += UltraPerfAnalytics_Dashboard();
   t += "\n";
   t += UltraPerfAnalytics_TradingStats();
   t += "\nWR=";
   t += DoubleToString(g_UltraPerfAnalytics.winRate, 1);
   t += "% PF=";
   t += DoubleToString(g_UltraPerfAnalytics.profitFactor, 2);
   t += " AW/AL=";
   t += DoubleToString(g_UltraPerfAnalytics.avgWin, 2);
   t += "/";
   t += DoubleToString(g_UltraPerfAnalytics.avgLoss, 2);
   return t;
}

string UltraDashboardIntel_PanelExecution()
{
   string t = "— EXECUTION —\n";
   t += UltraExecIntel_Dashboard();
   t += "\nVerify sync=";
   t += (g_UltraExecIntel.synced ? "Y" : "N");
   t += " | ticket=";
   t += IntegerToString((int)g_UltraExecIntel.positionTicket);
   t += " | ret=";
   t += IntegerToString((int)g_UltraExecIntel.lastRetcode);
   return t;
}

string UltraDashboardIntel_PanelHealth()
{
   string t = "— HEALTH —\n";
   t += UltraSystemHealth_Dashboard();
   t += " | ";
   t += UltraResource_Monitor();
   t += "\n";
   t += UltraZFR_Dashboard();
   t += "\n";
   t += UltraLoggerIntel_Dashboard();
   t += "\n";
   t += UltraFoundation_Dashboard();
   t += "\n";
   t += UltraMod_Dashboard();
   return t;
}

string UltraDashboardIntel_Dashboard(); // Q1/Q2/Q3 (defined below)

string UltraDashboardIntel_Build(const string s)
{
   UltraSnap u = g_UltraLastSnap;
   UltraSignal sig = g_UltraLastSignal;
   UltraDashboardIntel_ResolveState(s);
   g_UltraDashboardIntel.refreshCount++;

   string explain = sig.explanation;
   if(StringLen(explain) == 0)
   {
      bool leanBuy = !(sig.sell);
      bool approved = (sig.buy || sig.sell);
      explain = UltraUFSE_DebugExplain(u, leanBuy, approved);
   }

   string t = "======= HITMAN AI =======\n";
   t += UltraDashboardIntel_Dashboard();
   t += "\n";
   t += UltraDashboardIntel_PanelSystem(s);
   t += "\n";
   t += UltraDashboardIntel_PanelMarket(u);
   t += "\n";
   t += UltraDashboardIntel_PanelStrategy(u, sig);
   t += "\n";
   t += UltraDashboardIntel_PanelPosition(s);
   t += "\n";
   t += UltraDashboardIntel_PanelRisk();
   t += "\n";
   t += UltraDashboardIntel_PanelPerformance();
   t += "\n";
   t += UltraDashboardIntel_PanelExecution();
   t += "\n";
   t += UltraDashboardIntel_PanelHealth();
   t += "\n---- EXPLAIN ----\n";
   t += explain;
   t += "\n===============================";
   g_UltraDashboardIntel.lastText = t;
   g_UltraDashboardIntel.lastMs = (long)GetTickCount();
   return t;
}

void UltraDashboardIntel_NoteTradeRefresh()
{
   g_UltraDashboardIntel.tradeRefresh++;
   if(!g_UltraDashboardIntel.booted) return;
   if(!EnableDashboard && !UltraDashboardEnabled) return;
   string s = BrokerSymbol;
   if(StringLen(s) == 0) s = _Symbol;
   Comment(UltraDashboardIntel_Build(s));
}

void UltraDashboardIntel_NoteErrorRefresh()
{
   g_UltraDashboardIntel.errorRefresh++;
   if(!g_UltraDashboardIntel.booted) return;
   if(!EnableDashboard && !UltraDashboardEnabled) return;
   string s = BrokerSymbol;
   if(StringLen(s) == 0) s = _Symbol;
   Comment(UltraDashboardIntel_Build(s));
}

string UltraDashboardIntel_Dashboard()
{
   // Answers instantly: market? thinking? doing?
   string t = "AWARE: ";
   if(!g_UltraDashboardIntel.booted) { t += "INIT"; return t; }
   t += "Mkt=";
   t += g_UltraMarketIntel.readerState;
   t += "/";
   t += g_UltraMarketIntel.outTrend;
   t += " | Think=";
   t += g_UltraMissionLast.reason;
   t += " | Do=";
   t += g_UltraDashboardIntel.stateName;
   t += " rf=";
   t += IntegerToString((int)g_UltraDashboardIntel.refreshCount);
   t += " tr=";
   t += IntegerToString((int)g_UltraDashboardIntel.tradeRefresh);
   t += " | display-only";
   return t;
}

void UltraDashboardIntel_Refresh(const string s)
{
   if(!EnableDashboard && !UltraDashboardEnabled)
      return;
   Comment(UltraDashboardIntel_Build(s));
}

#endif // HITMAN_ULTRA_DASHBOARD_INTELLIGENCE_MQH
