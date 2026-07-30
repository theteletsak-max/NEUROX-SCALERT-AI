#ifndef HITMAN_ULTRA_DEFENSE_LINE_ENGINE_MQH
#define HITMAN_ULTRA_DEFENSE_LINE_ENGINE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — DEFENSE LINE ENGINE v1.0                             |
//| Protect entries · block invalid trades · protect positions       |
//| Detect abnormal markets · preserve capital                       |
//+------------------------------------------------------------------+

datetime g_UltraDefenseLastEmergBar = 0;
datetime g_UltraDefenseLastLogBar   = 0;
string   g_UltraDefenseLastLogSym   = "";
bool     g_UltraDefenseWasConnected = true;

string UltraDefense_LevelName(const ENUM_DEFENSE_LEVEL lv)
{
   if(lv == DEF_GREEN)  return "GREEN";
   if(lv == DEF_YELLOW) return "YELLOW";
   return "RED";
}

string UltraDefense_ActionName(const ENUM_DEFENSE_ACTION a)
{
   if(a == DEF_ACT_EXECUTE)        return "EXECUTE";
   if(a == DEF_ACT_WAIT)           return "WAIT";
   if(a == DEF_ACT_DO_NOT_EXECUTE) return "DO NOT EXECUTE";
   return "NO TRADE";
}

void UltraDefense_ClearReport(UltraDefenseReport &r)
{
   r.valid = false;
   r.buySide = true;
   r.overall = DEF_GREEN;
   r.action = DEF_ACT_EXECUTE;
   r.allowEntry = true;
   r.allowExecute = true;
   r.summary = "";
   for(int i = 0; i <= 10; i++)
   {
      r.line[i].id = i;
      r.line[i].name = "";
      r.line[i].pass = true;
      r.line[i].level = DEF_GREEN;
      r.line[i].reason = "";
   }
}

void UltraDefense_SetLine(UltraDefenseReport &r, const int id, const string name,
                          const bool pass, const ENUM_DEFENSE_LEVEL failLevel,
                          const string reason)
{
   if(id < 1 || id > 10) return;
   r.line[id].id = id;
   r.line[id].name = name;
   r.line[id].pass = pass;
   if(pass)
   {
      r.line[id].level = DEF_GREEN;
      r.line[id].reason = "PASS";
   }
   else
   {
      r.line[id].level = failLevel;
      r.line[id].reason = reason;
   }
}

void UltraDefense_RaiseOverall(UltraDefenseReport &r, const ENUM_DEFENSE_LEVEL lv)
{
   if((int)lv > (int)r.overall)
      r.overall = lv;
}

bool UltraDefense_SoftMode()
{
   if(!UltraDefenseStrict && InstantQualityMode) return true;
   return (!UltraDefenseStrict);
}

//--------------------------------------------------------------------//
// LINE 1 — MARKET STRUCTURE DEFENSE  → fail = NO TRADE (RED)
//--------------------------------------------------------------------//
bool UltraDefense_Line1_Structure(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool valid = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   bool broken = u.bos.failed;
   bool cleanSwing = (u.st.swingHighOK || u.st.swingLowOK || u.st.quality >= 30 || u.st.strength >= 30);
   bool fakeBreak = (u.bos.failed && ((buySide && u.bos.sell) || (!buySide && u.bos.buy)));

   if(UltraDefense_SoftMode())
   {
      int n = (valid?1:0) + ((!broken)?1:0) + (cleanSwing?1:0) + ((!fakeBreak)?1:0);
      if(n >= 2) return true;
      why = "structure soft " + IntegerToString(n) + "/4";
      return false;
   }
   if(!valid){ why = "invalid structure"; return false; }
   if(broken && fakeBreak){ why = "broken / fake break"; return false; }
   if(!cleanSwing && u.st.quality < 20){ why = "dirty swing"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// LINE 2 — TREND DEFENSE  → fail = NO TRADE (RED)
//--------------------------------------------------------------------//
bool UltraDefense_Line2_Trend(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool master = buySide
      ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull || u.trend.mtfVotesBuy > u.trend.mtfVotesSell)
      : (u.trend.bear || u.trend.htfBear || u.trend.macroBear || u.trend.mtfVotesSell > u.trend.mtfVotesBuy);
   bool strength = (u.trend.strength >= 25 || u.trend.quality >= 25 || UltraDefense_SoftMode());
   bool stable   = (u.trend.persistence >= 20 || u.trend.continuation || !u.trend.exhaustion || UltraDefense_SoftMode());

   if(UltraDefense_SoftMode())
   {
      int n = (master?1:0)+(strength?1:0)+(stable?1:0);
      if(n >= 1) return true;
      why = "trend soft 0/3";
      return false;
   }
   if(!master){ why = "master trend mismatch"; return false; }
   if(!strength){ why = "trend strength weak"; return false; }
   if(!stable){ why = "trend unstable"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// LINE 3 — LIQUIDITY DEFENSE  → fail = WAIT (YELLOW)
//--------------------------------------------------------------------//
bool UltraDefense_Line3_Liquidity(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool sweep = buySide ? (u.liq.sweepBuy || u.liq.equalLows) : (u.liq.sweepSell || u.liq.equalHighs);
   bool hunt  = buySide ? u.liq.stopHuntBuy : u.liq.stopHuntSell;
   bool grab  = buySide ? (u.liq.grabBuy || u.liq.poolBuy || u.liq.confirmedBuy)
                        : (u.liq.grabSell || u.liq.poolSell || u.liq.confirmedSell);
   if(sweep || hunt || grab) return true;
   if(UltraDefense_SoftMode() && (u.liq.quality >= 20 || u.ict.dispBuy || u.ict.dispSell))
      return true;
   // InstantQuality Cont/Fib/Inst paths often pass without a fresh sweep —
   // do not WAIT-block once confluence already selected a strategy.
   if(InstantQualityMode && UltraDefense_SoftMode())
   {
      bool zone = buySide
         ? (u.ict.obBuy || u.ict.fvgBuy || u.ict.instZoneBuy || u.fib.atBuyZone || u.ict.inDiscount)
         : (u.ict.obSell || u.ict.fvgSell || u.ict.instZoneSell || u.fib.atSellZone || u.ict.inPremium);
      bool mom = buySide ? (u.mom.momBuy || u.mom.impulse) : (u.mom.momSell || u.mom.impulse);
      if(zone || mom || u.st.continuation || u.bos.buy || u.bos.sell ||
         u.score.confidence >= UltraFireFloor() - 5)
         return true;
   }
   why = "liquidity not confirmed";
   return false;
}

//--------------------------------------------------------------------//
// LINE 4 — BOS + CHoCH DEFENSE  → fail = NO TRADE (RED)
// Checklist: BOS Defense · CHoCH Defense (both evaluated)
//--------------------------------------------------------------------//
bool UltraDefense_Line4_BosChoch(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool bos = buySide ? u.bos.buy : u.bos.sell;
   bool choch = buySide ? u.choch.buy : u.choch.sell;
   bool bosOK = bos && (u.bos.confirmed || u.bos.strong || u.bos.score >= 30 || UltraDefense_SoftMode());
   bool chochOK = choch && (u.choch.majorC || u.choch.confidence >= 30 || u.choch.strength >= 30 || UltraDefense_SoftMode());
   bool confirmed = bosOK || chochOK;
   bool strong = (u.bos.strong || u.bos.score >= 40 || u.choch.majorC || u.ict.dispBuy || u.ict.dispSell);

   if(UltraDefense_SoftMode())
   {
      if(bos || choch || u.st.continuation) return true;
      why = "no BOS/CHoCH";
      return false;
   }
   if(!(bos || choch)){ why = "no BOS/CHoCH"; return false; }
   if(!confirmed && !strong){ why = "break not confirmed"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// Momentum Defense (feeds Line 5)
//--------------------------------------------------------------------//
bool UltraDefense_MomentumOK(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool mom = buySide ? (u.mom.momBuy || u.mom.impulse || u.mom.direction > 0)
                      : (u.mom.momSell || u.mom.impulse || u.mom.direction < 0);
   if(mom || u.mom.strength >= 25) return true;
   if(UltraDefense_SoftMode() && !u.mom.weakness) return true;
   why = "momentum against";
   return false;
}

//--------------------------------------------------------------------//
// Fibonacci Defense (feeds Line 5)
//--------------------------------------------------------------------//
bool UltraDefense_FibOK(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool zone = buySide ? (u.fib.atBuyZone || u.ict.inDiscount) : (u.fib.atSellZone || u.ict.inPremium);
   if(zone || u.fib.quality >= 25 || u.fib.zoneRank >= 1) return true;
   if(UltraDefense_SoftMode()) return true; // soft — fib preferred not required
   why = "fib zone miss";
   return false;
}

//--------------------------------------------------------------------//
// Risk Defense (feeds Line 6)
//--------------------------------------------------------------------//
bool UltraDefense_RiskOK(const UltraSnap &u, string &why)
{
   why = "";
   if(u.score.riskProb > 0 && u.score.riskProb >= 70 && !UltraDefense_SoftMode())
   { why = "risk probability high"; return false; }
   if(u.diag.health == "DEGRADED" && !UltraDefense_SoftMode())
   { why = "diag degraded risk"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// LINE 5 — PRECISION + MOMENTUM + FIB DEFENSE  → fail = WAIT (YELLOW)
//--------------------------------------------------------------------//
bool UltraDefense_Line5_Precision(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool zone = buySide
      ? (u.fib.atBuyZone || u.ict.obBuy || u.ict.fvgBuy || u.ict.instZoneBuy || u.ict.inDiscount)
      : (u.fib.atSellZone || u.ict.obSell || u.ict.fvgSell || u.ict.instZoneSell || u.ict.inPremium);
   bool rrOk = (u.score.precision >= UltraMinPrecision ||
                u.score.confidence >= UltraInstantFireConf ||
                (InstantQualityMode && u.score.precision >= UltraMinPrecision - 8));
   bool lowErr = (u.score.precision >= 30 || u.fib.quality >= 30 || zone);

   string mw = "", fw = "";
   bool momOK = UltraDefense_MomentumOK(u, buySide, mw);
   bool fibOK = UltraDefense_FibOK(u, buySide, fw);

   if(rrOk && (zone || lowErr || UltraDefense_SoftMode()) && (momOK || UltraDefense_SoftMode()) && (fibOK || UltraDefense_SoftMode()))
      return true;
   if(UltraDefense_SoftMode() && u.score.confidence >= UltraFireFloor() - 5) return true;
   if(!momOK){ why = mw; return false; }
   if(!fibOK){ why = fw; return false; }
   why = "precision / zone wait";
   return false;
}

//--------------------------------------------------------------------//
// LINE 6 — PROBABILITY + RISK DEFENSE  → fail = NO TRADE (RED)
//--------------------------------------------------------------------//
bool UltraDefense_Line6_Probability(const UltraSnap &u, string &why)
{
   why = "";
   string rw = "";
   if(!UltraDefense_RiskOK(u, rw))
   { why = rw; return false; }
   if(u.score.probability >= UltraMinProbability) return true;
   if(u.score.confidence >= UltraInstantFireConf) return true;
   if(InstantQualityMode && u.score.probability >= UltraMinProbability - 8) return true;
   why = "probability below threshold";
   return false;
}

//--------------------------------------------------------------------//
// LINE 7 — EXECUTION DEFENSE  → fail = DO NOT EXECUTE (RED)
//--------------------------------------------------------------------//
bool UltraDefense_Line7_Execution(const string s, string &why)
{
   why = "";
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)){ why = "connection loss"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why = "terminal trade blocked"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)){ why = "EA trade disabled"; return false; }

   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm)){ why = "symbol mode unavailable"; return false; }
   // trade mode 0 = disabled — compare as long to avoid enum convert errors
   if(tm == 0){ why = "symbol trade disabled"; return false; }

   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0){ why = "price not fresh"; return false; }

   double volMin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double volMax = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   if(volMin <= 0.0 || (volMax > 0.0 && volMax < volMin)){ why = "invalid volume limits"; return false; }

   long stops = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL, stops)){ why = "stops level unavailable"; return false; }
   if(stops < 0){ why = "invalid stops level"; return false; }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq <= 0.0){ why = "invalid equity"; return false; }
   if(fm <= 0.0){ why = "no free margin"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// LINE 10 — AI DEFENSE (final confluence of required checks)
//--------------------------------------------------------------------//
bool UltraDefense_Line10_AI(const UltraDefenseReport &r, string &why)
{
   why = "";
   // Required hard lines: 1,2,4,6 + exec 7 when gated. Soft waits: 3,5.
   if(!r.line[1].pass){ why = "AI: structure"; return false; }
   if(!r.line[2].pass){ why = "AI: trend"; return false; }
   if(!r.line[4].pass){ why = "AI: BOS/CHoCH"; return false; }
   if(!r.line[6].pass){ why = "AI: probability"; return false; }
   if(UltraDefenseGateExec && !r.line[7].pass){ why = "AI: execution"; return false; }
   // Liquidity + Precision are WAIT lines — block entry until confirmed
   if(!r.line[3].pass){ why = "AI: liquidity wait"; return false; }
   if(!r.line[5].pass){ why = "AI: precision wait"; return false; }
   return true;
}

string UltraDefense_BuildSummary(const UltraDefenseReport &r)
{
   string t = "DEFENSE ";
   t += UltraDefense_LevelName(r.overall);
   t += " → ";
   t += UltraDefense_ActionName(r.action);
   t += " |";
   for(int i = 1; i <= 10; i++)
   {
      if(i == 8 || i == 9) continue; // position/emergency reported separately
      t += " L";
      t += IntegerToString(i);
      t += "=";
      if(r.line[i].pass) t += "OK";
      else
      {
         t += UltraDefense_LevelName(r.line[i].level);
         t += ":";
         t += r.line[i].reason;
      }
   }
   return t;
}

//--------------------------------------------------------------------//
// ENTRY + EXEC EVALUATION (Lines 1-7 + 10)
//--------------------------------------------------------------------//
bool UltraDefense_EvaluateEntry(const string s, const UltraSnap &u, const bool buySide,
                                UltraDefenseReport &r, string &why)
{
   UltraDefense_ClearReport(r);
   r.buySide = buySide;
   r.valid = true;
   why = "";

   if(!UltraDefenseEnabled || !UltraDefenseGateEntry)
   {
      r.overall = DEF_GREEN;
      r.action = DEF_ACT_EXECUTE;
      r.allowEntry = true;
      r.allowExecute = true;
      r.summary = "DEFENSE OFF";
      g_UltraDefenseLast = r;
      return true;
   }

   string w = "";
   bool p1 = UltraDefense_Line1_Structure(u, buySide, w);
   UltraDefense_SetLine(r, 1, "STRUCTURE", p1, DEF_RED, w);
   if(!p1) UltraDefense_RaiseOverall(r, DEF_RED);

   w = "";
   bool p2 = UltraDefense_Line2_Trend(u, buySide, w);
   UltraDefense_SetLine(r, 2, "TREND", p2, DEF_RED, w);
   if(!p2) UltraDefense_RaiseOverall(r, DEF_RED);

   w = "";
   bool p3 = UltraDefense_Line3_Liquidity(u, buySide, w);
   UltraDefense_SetLine(r, 3, "LIQUIDITY", p3, DEF_YELLOW, w);
   if(!p3) UltraDefense_RaiseOverall(r, DEF_YELLOW);

   w = "";
   bool p4 = UltraDefense_Line4_BosChoch(u, buySide, w);
   UltraDefense_SetLine(r, 4, "BOS_CHOCH", p4, DEF_RED, w);
   if(!p4) UltraDefense_RaiseOverall(r, DEF_RED);

   w = "";
   bool p5 = UltraDefense_Line5_Precision(u, buySide, w);
   UltraDefense_SetLine(r, 5, "PREC_MOM_FIB", p5, DEF_YELLOW, w);
   if(!p5) UltraDefense_RaiseOverall(r, DEF_YELLOW);

   w = "";
   bool p6 = UltraDefense_Line6_Probability(u, w);
   UltraDefense_SetLine(r, 6, "PROB_RISK", p6, DEF_RED, w);
   if(!p6) UltraDefense_RaiseOverall(r, DEF_RED);

   w = "";
   bool p7 = true;
   if(UltraDefenseGateExec)
      p7 = UltraDefense_Line7_Execution(s, w);
   UltraDefense_SetLine(r, 7, "EXECUTION", p7, DEF_RED, w);
   if(!p7) UltraDefense_RaiseOverall(r, DEF_RED);

   // Position + Emergency are runtime — mark GREEN here
   UltraDefense_SetLine(r, 8, "POSITION", true, DEF_GREEN, "runtime");
   UltraDefense_SetLine(r, 9, "EMERGENCY", true, DEF_GREEN, "runtime");

   w = "";
   bool p10 = UltraDefense_Line10_AI(r, w);
   UltraDefense_SetLine(r, 10, "AI", p10, DEF_RED, w);
   if(!p10) UltraDefense_RaiseOverall(r, DEF_RED);

   // Map overall → action
   r.allowEntry = false;
   r.allowExecute = false;
   if(!p7)
   {
      r.action = DEF_ACT_DO_NOT_EXECUTE;
      r.allowEntry = false;
      r.allowExecute = false;
   }
   else if(!p1 || !p2 || !p4 || !p6 || !p10)
   {
      // distinguish WAIT (yellow-only fails on 3/5) vs NO TRADE
      if(p1 && p2 && p4 && p6 && (!p3 || !p5))
      {
         r.action = DEF_ACT_WAIT;
         r.overall = DEF_YELLOW;
      }
      else
      {
         r.action = DEF_ACT_NO_TRADE;
         if(r.overall < DEF_RED) r.overall = DEF_RED;
      }
   }
   else if(!p3 || !p5)
   {
      r.action = DEF_ACT_WAIT;
      r.overall = DEF_YELLOW;
   }
   else
   {
      r.action = DEF_ACT_EXECUTE;
      r.overall = DEF_GREEN;
      r.allowEntry = true;
      r.allowExecute = true;
   }

   r.summary = UltraDefense_BuildSummary(r);
   g_UltraDefenseLast = r;

   if(r.allowEntry && r.allowExecute)
   {
      why = "";
      return true;
   }

   why = "DEFENSE ";
   why += UltraDefense_LevelName(r.overall);
   why += " ";
   why += UltraDefense_ActionName(r.action);
   why += " — ";
   // pick first failing line reason
   for(int i = 1; i <= 10; i++)
   {
      if(i == 8 || i == 9) continue;
      if(!r.line[i].pass)
      {
         why += "L";
         why += IntegerToString(i);
         why += " ";
         why += r.line[i].name;
         why += ": ";
         why += r.line[i].reason;
         break;
      }
   }
   return false;
}

//--------------------------------------------------------------------//
// LINE 8 — POSITION DEFENSE (open trades)
// Protect profit · BE · trail handoff · trend-change monitor
// Returns true if position was CLOSED by defense.
//--------------------------------------------------------------------//
bool UltraDefense_Line8_Position(const ulong ticket, const long type,
                                 const double openPrice, const double price,
                                 double &currentSL, double &currentTP,
                                 const int stateIndex)
{
   if(!UltraDefenseEnabled || !UltraDefensePosition) return false;
   if(!PositionSelectByTicket(ticket)) return false;

   const bool isBuy = (type == POSITION_TYPE_BUY);
   UltraSnap u = g_UltraLastSnap;

   // Trend change against open position → move to break-even (capital preserve)
   bool trendFlip = isBuy
      ? (u.trend.bear && (u.trend.htfBear || u.trend.macroBear) && !u.trend.bull)
      : (u.trend.bull && (u.trend.htfBull || u.trend.macroBull) && !u.trend.bear);

   bool bosAgainst = isBuy ? (u.bos.sell && (u.bos.confirmed || u.bos.strong))
                           : (u.bos.buy  && (u.bos.confirmed || u.bos.strong));

   if(trendFlip || bosAgainst)
   {
      bool needsBE = isBuy ? (currentSL < openPrice) : (currentSL > openPrice || currentSL <= 0.0);
      // only BE if price is at/through open (avoid impossible modify)
      bool atProfit = isBuy ? (price >= openPrice) : (price <= openPrice);
      if(needsBE && atProfit)
      {
         if(g_Trade.PositionModify(ticket, openPrice, currentTP))
         {
            currentSL = openPrice;
            if(UltraDefenseLog)
               Print("DEFENSE L8 POSITION: BE on trend/BOS flip ticket=", ticket);
         }
      }
   }

   // Optional hard close on adverse exhaustion flip
   // MASTER AUDIT: blocked when UltraMissionOnlyExits (keep BE manage above)
   if(!UltraMissionOnlyExits && UltraDefenseCloseOnFlip && trendFlip && bosAgainst && u.trend.exhaustion)
   {
      if(UltraDefenseLog)
         Print("DEFENSE L8 POSITION: request CLOSE adverse flip ticket=", ticket);
      // Sole close authority = Mission Control
      return UltraMission_ClosePosition(ticket, "DEFENSE L8 adverse flip", false);
   }

   g_UltraDefenseLast.line[8].id = 8;
   g_UltraDefenseLast.line[8].name = "POSITION";
   g_UltraDefenseLast.line[8].pass = true;
   g_UltraDefenseLast.line[8].level = DEF_GREEN;
   g_UltraDefenseLast.line[8].reason = "monitoring";
   return false;
}

//--------------------------------------------------------------------//
// LINE 9 — EMERGENCY DEFENSE (recover automatically)
//--------------------------------------------------------------------//
void UltraDefense_Line9_Emergency(const string s)
{
   if(!UltraDefenseEnabled || !UltraDefenseEmergency) return;

   datetime bar = iTime(s, UltraETF(), 0);
   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   bool tradeCtxBusy = !((bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
   bool badEquity = (AccountInfoDouble(ACCOUNT_EQUITY) <= 0.0);
   long tm = 0;
   bool modeOK = SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm);
   bool symbolErr = (!modeOK) || (tm == 0) || (SymbolInfoDouble(s, SYMBOL_BID) <= 0.0);
   bool invalidData = (Bars(s, UltraETF()) < 50);

   string why = "";
   bool needRecover = false;

   if(!connected)
   {
      why = "connection loss";
      needRecover = true;
      g_UltraDefenseWasConnected = false;
   }
   else if(!g_UltraDefenseWasConnected && connected)
   {
      why = "VPS/terminal reconnect";
      needRecover = true;
      g_UltraDefenseWasConnected = true;
   }
   else
      g_UltraDefenseWasConnected = connected;

   if(tradeCtxBusy){ why = "trade context busy/blocked"; needRecover = true; }
   if(badEquity){ why = "invalid account data"; needRecover = true; }
   if(symbolErr){ why = "symbol error"; needRecover = true; }
   if(invalidData){ why = "invalid market data"; needRecover = true; }

   g_UltraDefenseLast.line[9].id = 9;
   g_UltraDefenseLast.line[9].name = "EMERGENCY";
   if(needRecover)
   {
      g_UltraDefenseLast.line[9].pass = false;
      g_UltraDefenseLast.line[9].level = DEF_RED;
      g_UltraDefenseLast.line[9].reason = why;
      UltraRecover(why);
      if(UltraDefenseLog && bar != g_UltraDefenseLastEmergBar)
      {
         g_UltraDefenseLastEmergBar = bar;
         Print("DEFENSE L9 EMERGENCY recover: ", why, " on ", s);
      }
   }
   else
   {
      g_UltraDefenseLast.line[9].pass = true;
      g_UltraDefenseLast.line[9].level = DEF_GREEN;
      g_UltraDefenseLast.line[9].reason = "OK";
   }
}

void UltraDefense_MaybeLog(const string s, const UltraDefenseReport &r)
{
   if(!UltraDefenseLog) return;
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar == g_UltraDefenseLastLogBar && s == g_UltraDefenseLastLogSym) return;
   if(r.overall == DEF_GREEN && r.allowEntry) return; // keep journal clean; fire path logs
   g_UltraDefenseLastLogBar = bar;
   g_UltraDefenseLastLogSym = s;
   Print(r.summary, " on ", s);
}

string UltraDefense_DashboardLine()
{
   if(!UltraDefenseEnabled) return "DEFENSE: OFF";
   UltraDefenseReport r = g_UltraDefenseLast;
   string t = "DEFENSE: ";
   t += UltraDefense_LevelName(r.overall);
   t += " ";
   t += UltraDefense_ActionName(r.action);
   return t;
}

#endif // HITMAN_ULTRA_DEFENSE_LINE_ENGINE_MQH
