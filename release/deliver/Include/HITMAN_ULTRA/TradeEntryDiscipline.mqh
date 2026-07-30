#ifndef HITMAN_ULTRA_TRADE_ENTRY_DISCIPLINE_MQH
#define HITMAN_ULTRA_TRADE_ENTRY_DISCIPLINE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — TRADE ENTRY DISCIPLINE ENGINE v1.0                   |
//| Irregular Trade Prevention System                                |
//| Never open random / emotional / duplicate / low-quality trades   |
//+------------------------------------------------------------------+

#define ULTRA_DISC_MAX 32

struct UltraDiscState
{
   string   symbol;
   int      lastDir;          // +1 buy, -1 sell, 0 none
   int      stableCount;
   datetime lastEvalBar;
   datetime lastFillTime;
   datetime lastFillBar;
   int      lastFillDir;
   string   lastFillTag;
   int      lastFillEpoch;
   string   lastThesis;
   bool     valid;
};

UltraDiscState g_UltraDisc[ULTRA_DISC_MAX];
int            g_UltraDiscN = 0;
string         g_UltraDiscLastSummary = "";

bool UltraDisc_Soft()
{
   if(UltraDisciplineStrict) return false;
   return true;
}

int UltraDisc_Find(const string s)
{
   for(int i = 0; i < g_UltraDiscN; i++)
      if(g_UltraDisc[i].symbol == s) return i;
   return -1;
}

int UltraDisc_Ensure(const string s)
{
   int idx = UltraDisc_Find(s);
   if(idx >= 0) return idx;
   if(g_UltraDiscN >= ULTRA_DISC_MAX) return 0;
   idx = g_UltraDiscN++;
   g_UltraDisc[idx].symbol = s;
   g_UltraDisc[idx].lastDir = 0;
   g_UltraDisc[idx].stableCount = 0;
   g_UltraDisc[idx].lastEvalBar = 0;
   g_UltraDisc[idx].lastFillTime = 0;
   g_UltraDisc[idx].lastFillBar = 0;
   g_UltraDisc[idx].lastFillDir = 0;
   g_UltraDisc[idx].lastFillTag = "";
   g_UltraDisc[idx].lastFillEpoch = 0;
   g_UltraDisc[idx].lastThesis = "";
   g_UltraDisc[idx].valid = true;
   return idx;
}

int UltraDisc_StructEpoch(const UltraSnap &u)
{
   int e = 0;
   if(u.st.hh) e += 1;
   if(u.st.hl) e += 2;
   if(u.st.lh) e += 4;
   if(u.st.ll) e += 8;
   if(u.st.externalBull) e += 16;
   if(u.st.externalBear) e += 32;
   if(u.bos.buy) e += 64;
   if(u.bos.sell) e += 128;
   if(u.bos.confirmed) e += 256;
   if(u.choch.buy) e += 512;
   if(u.choch.sell) e += 1024;
   if(u.liq.sweepBuy) e += 2048;
   if(u.liq.sweepSell) e += 4096;
   e += (u.st.quality / 10) * 8192;
   return e;
}

bool UltraDisc_HasOpenDir(const string s, const bool buySide)
{
   int d = UltraSymDir(s);
   if(buySide) return (d == 1 || d == 2);
   return (d == -1 || d == 2);
}

bool UltraDisc_TFBull(const string s, const ENUM_TIMEFRAMES tf)
{
   double sma = UltraSMA(s, tf, 20, 1);
   if(sma <= 0.0) return false;
   return (iClose(s, tf, 1) > sma);
}

bool UltraDisc_TFBear(const string s, const ENUM_TIMEFRAMES tf)
{
   double sma = UltraSMA(s, tf, 20, 1);
   if(sma <= 0.0) return false;
   return (iClose(s, tf, 1) < sma);
}

//--------------------------------------------------------------------//
// RULE #1 — ZERO IRREGULAR ENTRIES (multi-confirmation)
//--------------------------------------------------------------------//
bool UltraDisc_R1_MultiConfirm(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   bool trend = buySide
      ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull)
      : (u.trend.bear || u.trend.htfBear || u.trend.macroBear);
   bool bosCh = buySide ? (u.bos.buy || u.choch.buy) : (u.bos.sell || u.choch.sell);
   bool liq = buySide
      ? (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.grabBuy || u.liq.equalLows)
      : (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.grabSell || u.liq.equalHighs);
   bool fib = buySide ? (u.fib.atBuyZone || u.ict.inDiscount) : (u.fib.atSellZone || u.ict.inPremium);
   bool mom = buySide
      ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy || u.ind.smi > 0)
      : (u.mom.momSell || u.mom.impulse || u.ict.dispSell || u.ind.smi < 0);

   int n = (structure?1:0)+(trend?1:0)+(bosCh?1:0)+(liq?1:0)+(fib?1:0)+(mom?1:0);
   int need = UltraDisc_Soft() ? 3 : 4;
   if(n >= need) return true;
   why = "R1 irregular: only " + IntegerToString(n) + "/" + IntegerToString(need) + " confirms";
   return false;
}

//--------------------------------------------------------------------//
// RULE #2 — TRADE THESIS VALIDATION
//--------------------------------------------------------------------//
bool UltraDisc_R2_Thesis(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   // Defense Lines already validate the stack; re-check score floors here
   if(u.score.confluence < UltraFireFloor() && u.score.confidence < UltraInstantFireConf)
   {
      if(!(InstantQualityMode && u.score.confidence >= UltraFireFloor() - 8))
      { why = "R2 thesis: confluence fail"; return false; }
   }
   if(u.score.precision < UltraMinPrecision && u.score.confidence < UltraInstantFireConf)
   {
      if(!(InstantQualityMode && u.score.precision >= UltraMinPrecision - 8))
      { why = "R2 thesis: precision fail"; return false; }
   }
   if(u.score.probability < UltraMinProbability && u.score.confidence < UltraInstantFireConf)
   {
      if(!(InstantQualityMode && u.score.probability >= UltraMinProbability - 8))
      { why = "R2 thesis: probability fail"; return false; }
   }
   // directional thesis must exist
   bool sideBias = buySide ? (u.trend.bull || u.bos.buy || u.choch.buy || u.st.continuation)
                           : (u.trend.bear || u.bos.sell || u.choch.sell || u.st.continuation);
   if(!sideBias && !UltraDisc_Soft())
   { why = "R2 thesis: side bias missing"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// RULE #3 — SIGNAL STABILITY (no flicker / one-tick)
//--------------------------------------------------------------------//
bool UltraDisc_R3_Stability(const int idx, const bool buySide, string &why)
{
   why = "";
   int dir = buySide ? 1 : -1;
   datetime bar = iTime(g_UltraDisc[idx].symbol, UltraETF(), 0);

   if(g_UltraDisc[idx].lastDir == dir)
      g_UltraDisc[idx].stableCount++;
   else
   {
      g_UltraDisc[idx].lastDir = dir;
      g_UltraDisc[idx].stableCount = 1;
   }
   g_UltraDisc[idx].lastEvalBar = bar;

   int need = UltraDisciplineStableEvals;
   if(need < 1) need = 1;
   if(UltraDisc_Soft() && InstantQualityMode && need > 2) need = 2;
   if(!UltraDisc_Soft() && need < 2) need = 2;

   if(g_UltraDisc[idx].stableCount >= need) return true;
   why = "R3 unstable signal " + IntegerToString(g_UltraDisc[idx].stableCount) + "/" + IntegerToString(need);
   return false;
}

//--------------------------------------------------------------------//
// RULE #4 — CONFIRMATION LOCK (ordered checklist)
//--------------------------------------------------------------------//
bool UltraDisc_R4_ConfirmLock(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   // Ordered chain: Structure → Trend → Liquidity → Momentum → Confluence → Precision → Probability
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   if(!structure){ why = "R4 lock: structure"; return false; }

   bool trend = buySide
      ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull || u.trend.mtfVotesBuy >= u.trend.mtfVotesSell)
      : (u.trend.bear || u.trend.htfBear || u.trend.macroBear || u.trend.mtfVotesSell >= u.trend.mtfVotesBuy);
   if(!trend && !UltraDisc_Soft()){ why = "R4 lock: trend"; return false; }

   bool liq = buySide
      ? (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.grabBuy || u.liq.equalLows || u.liq.quality >= 20)
      : (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.grabSell || u.liq.equalHighs || u.liq.quality >= 20);
   if(!liq && !UltraDisc_Soft()){ why = "R4 lock: liquidity"; return false; }

   bool mom = buySide
      ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy || u.ind.smi >= 0)
      : (u.mom.momSell || u.mom.impulse || u.ict.dispSell || u.ind.smi <= 0);
   if(!mom && !UltraDisc_Soft()){ why = "R4 lock: momentum"; return false; }

   if(u.score.confluence < 20 && u.score.confidence < 20)
   { why = "R4 lock: confluence"; return false; }
   if(u.score.precision < 20 && !UltraDisc_Soft())
   { why = "R4 lock: precision"; return false; }
   if(u.score.probability < 20 && !UltraDisc_Soft())
   { why = "R4 lock: probability"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// RULE #5 — MASTER TREND LOCK
//--------------------------------------------------------------------//
bool UltraDisc_R5_MasterTrend(const string s, const bool buySide, string &why)
{
   why = "";
   if(!UltraMasterTrendLock) return true;

   // H4 bias + D1 macro as master (no UFSE dependency — this module loads before UFSE)
   bool bull = UltraDisc_TFBull(s, UltraTF_Bias) || UltraDisc_TFBull(s, UltraTF_Macro);
   bool bear = UltraDisc_TFBear(s, UltraTF_Bias) || UltraDisc_TFBear(s, UltraTF_Macro);
   if(bull && bear) return true; // mixed → fail-open
   if(!bull && !bear) return true; // neutral → fail-open
   if(bull && !buySide){ why = "R5 master trend BUY-only"; return false; }
   if(bear && buySide){ why = "R5 master trend SELL-only"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// RULE #6 — TIMEFRAME AGREEMENT (H4→H1→M30→M15→M5)
//--------------------------------------------------------------------//
bool UltraDisc_R6_Timeframes(const string s, const bool buySide, string &why)
{
   why = "";
   ENUM_TIMEFRAMES tfs[5];
   tfs[0] = PERIOD_H4;
   tfs[1] = PERIOD_H1;
   tfs[2] = PERIOD_M30;
   tfs[3] = PERIOD_M15;
   tfs[4] = PERIOD_M5;

   int agree = 0;
   int known = 0;
   bool h4ok = false;
   bool h4known = false;

   for(int i = 0; i < 5; i++)
   {
      double sma = UltraSMA(s, tfs[i], 20, 1);
      if(sma <= 0.0) continue;
      known++;
      bool bull = (iClose(s, tfs[i], 1) > sma);
      bool bear = (iClose(s, tfs[i], 1) < sma);
      bool ok = buySide ? bull : bear;
      if(ok) agree++;
      if(i == 0)
      {
         h4known = true;
         h4ok = ok;
      }
   }

   if(known == 0) return true; // fail-open if no TF data

   int need = UltraDisciplineMTFMinAgree;
   if(need < 1) need = 1;
   if(need > 5) need = 5;
   if(UltraDisc_Soft() && need > 3) need = 3;

   if(!UltraDisc_Soft() && h4known && !h4ok)
   { why = "R6 TF hierarchy: H4 against thesis"; return false; }

   // Timeframe synchronization + no conflicts (MN→M5 / master lock)
   string cf = "";
   if(!UltraMTF_NoConflict(s, buySide, cf))
   {
      if(!UltraDisc_Soft())
      { why = cf; return false; }
      // soft: allow only if agreement already strong
      if(agree < need)
      { why = cf; return false; }
   }

   if(agree >= need) return true;
   why = "R6 TF agree " + IntegerToString(agree) + "/" + IntegerToString(need);
   return false;
}

//--------------------------------------------------------------------//
// RULE #7 — DUPLICATE PROTECTION
//--------------------------------------------------------------------//
bool UltraDisc_R7_Duplicate(const int idx, const bool buySide, const string tag, string &why)
{
   why = "";
   string s = g_UltraDisc[idx].symbol;
   datetime bar = iTime(s, UltraETF(), 0);
   int dir = buySide ? 1 : -1;

   // same direction already open
   if(UltraDisc_HasOpenDir(s, buySide))
   { why = "R7 duplicate: same direction open"; return false; }

   // same candle as last successful fill (same dir)
   if(g_UltraDisc[idx].lastFillBar > 0 && bar == g_UltraDisc[idx].lastFillBar &&
      g_UltraDisc[idx].lastFillDir == dir)
   { why = "R7 duplicate: same candle fill"; return false; }

   // same tag+dir filled moments ago (tick spam)
   if(g_UltraDisc[idx].lastFillTime > 0 &&
      g_UltraDisc[idx].lastFillDir == dir &&
      g_UltraDisc[idx].lastFillTag == tag &&
      (TimeCurrent() - g_UltraDisc[idx].lastFillTime) < 2)
   { why = "R7 duplicate: same tick/setup"; return false; }

   return true;
}

//--------------------------------------------------------------------//
// RULE #8 — ENTRY QUALITY CHECK
//--------------------------------------------------------------------//
bool UltraDisc_R8_Quality(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool location = buySide
      ? (u.fib.atBuyZone || u.ict.obBuy || u.ict.fvgBuy || u.ict.instZoneBuy || u.ict.inDiscount || UltraDisc_Soft())
      : (u.fib.atSellZone || u.ict.obSell || u.ict.fvgSell || u.ict.instZoneSell || u.ict.inPremium || UltraDisc_Soft());
   bool rr = (u.score.precision >= UltraMinPrecision || u.score.confidence >= UltraInstantFireConf ||
              (InstantQualityMode && u.score.precision >= UltraMinPrecision - 8));
   bool liqPos = buySide
      ? (u.liq.sweepBuy || u.liq.grabBuy || u.liq.stopHuntBuy || u.liq.quality >= 15 || UltraDisc_Soft())
      : (u.liq.sweepSell || u.liq.grabSell || u.liq.stopHuntSell || u.liq.quality >= 15 || UltraDisc_Soft());
   bool structure = (u.st.quality >= 20 || u.st.strength >= 20 || UltraDisc_Soft());
   bool trendAlign = buySide
      ? (u.trend.bull || u.trend.htfBull || u.trend.mtfVotesBuy >= u.trend.mtfVotesSell || UltraDisc_Soft())
      : (u.trend.bear || u.trend.htfBear || u.trend.mtfVotesSell >= u.trend.mtfVotesBuy || UltraDisc_Soft());

   if(location && rr && liqPos && structure && trendAlign) return true;
   why = "R8 entry quality incomplete";
   return false;
}

//--------------------------------------------------------------------//
// RULE #9 — BROKER VALIDATION
//--------------------------------------------------------------------//
bool UltraDisc_R9_Broker(const string s, string &why)
{
   why = "";
   string w = "";
   if(UltraDefenseEnabled)
   {
      if(!UltraDefense_Line7_Execution(s, w))
      { why = "R9 broker: " + w; return false; }
      return true;
   }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)){ why = "R9 connection"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why = "R9 trading blocked"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)){ why = "R9 EA disabled"; return false; }
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) || tm == 0){ why = "R9 market closed/disabled"; return false; }
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0){ why = "R9 price not fresh"; return false; }
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) <= 0.0){ why = "R9 no margin"; return false; }
   double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   if(vmin <= 0.0){ why = "R9 invalid volume"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// RULE #11 — TRADE COOL-DOWN (structure / BOS / CHoCH / trade done)
//--------------------------------------------------------------------//
bool UltraDisc_R11_Cooldown(const int idx, const UltraSnap &u, const bool buySide, const string tag, string &why)
{
   why = "";
   string s = g_UltraDisc[idx].symbol;
   int dir = buySide ? 1 : -1;

   // trade completed ⇒ unlock
   if(!UltraDisc_HasOpenDir(s, buySide))
   {
      if(!UltraDisciplineNeedNewStruct) return true;
      // strict optional: need new structure epoch vs last fill
      if(g_UltraDisc[idx].lastFillDir != dir || g_UltraDisc[idx].lastFillTime <= 0)
         return true;
      int epoch = UltraDisc_StructEpoch(u);
      if(epoch != g_UltraDisc[idx].lastFillEpoch) return true;
      // also accept tag change as new setup
      if(tag != g_UltraDisc[idx].lastFillTag && StringLen(tag) > 0) return true;
      why = "R11 cooldown: waiting new structure/BOS/CHoCH";
      return false;
   }

   // still open — blocked (also covered by R7)
   why = "R11 cooldown: trade still open";
   return false;
}

//--------------------------------------------------------------------//
// RULE #12 — EXPLAINABLE THESIS
//--------------------------------------------------------------------//
string UltraDisc_BuildThesis(const UltraSnap &u, const bool buySide, const string tag)
{
   string side = "SELL";
   if(buySide) side = "BUY";
   string t = "THESIS ";
   t += side;
   t += " [";
   t += tag;
   t += "] conf=";
   t += IntegerToString(u.score.confidence);
   t += " prec=";
   t += IntegerToString(u.score.precision);
   t += " prob=";
   t += IntegerToString(u.score.probability);
   t += " conj=";
   t += IntegerToString(u.score.confluence);
   t += " | trend=";
   t += IntegerToString(u.trend.strength);
   t += " bos=";
   if(buySide) { if(u.bos.buy) t += "Y"; else t += "N"; }
   else { if(u.bos.sell) t += "Y"; else t += "N"; }
   t += " choch=";
   if(buySide) { if(u.choch.buy) t += "Y"; else t += "N"; }
   else { if(u.choch.sell) t += "Y"; else t += "N"; }
   t += " liq=";
   if(buySide) { if(u.liq.sweepBuy || u.liq.grabBuy) t += "Y"; else t += "N"; }
   else { if(u.liq.sweepSell || u.liq.grabSell) t += "Y"; else t += "N"; }
   t += " fib=";
   if(buySide) { if(u.fib.atBuyZone) t += "Y"; else t += "N"; }
   else { if(u.fib.atSellZone) t += "Y"; else t += "N"; }
   t += " mom=";
   if(buySide) { if(u.mom.momBuy || u.mom.impulse) t += "Y"; else t += "N"; }
   else { if(u.mom.momSell || u.mom.impulse) t += "Y"; else t += "N"; }
   return t;
}

bool UltraDisc_R12_Explainable(const UltraSnap &u, const bool buySide, const string tag, string &thesis, string &why)
{
   why = "";
   thesis = UltraDisc_BuildThesis(u, buySide, tag);
   if(tag == "" || tag == "NONE")
   { why = "R12 no strategy tag"; return false; }
   if(u.score.confidence <= 0 && u.score.confluence <= 0)
   { why = "R12 empty score thesis"; return false; }
   if(StringLen(thesis) < 20)
   { why = "R12 incomplete thesis"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// RULE #10 — SUPREME AI APPROVAL (all required rules)
//--------------------------------------------------------------------//
bool UltraDiscipline_AllowEntry(const string s, const UltraSnap &u, const UltraSignal &sig, string &why)
{
   why = "";
   g_UltraDiscLastSummary = "DISCIPLINE OFF";
   if(!UltraDisciplineEnabled) return true;

   if(!(sig.buy || sig.sell) || sig.tag == "NONE")
   { why = "DISCIPLINE: no signal"; return false; }

   bool buySide = sig.buy;
   int idx = UltraDisc_Ensure(s);
   string w = "";
   string summary = "DISCIPLINE";

   // R1
   if(!UltraDisc_R1_MultiConfirm(u, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R2
   w = ""; if(!UltraDisc_R2_Thesis(u, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R3
   w = ""; if(!UltraDisc_R3_Stability(idx, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R4
   w = ""; if(!UltraDisc_R4_ConfirmLock(u, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R5
   w = ""; if(!UltraDisc_R5_MasterTrend(s, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R6
   w = ""; if(!UltraDisc_R6_Timeframes(s, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R7
   w = ""; if(!UltraDisc_R7_Duplicate(idx, buySide, sig.tag, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R8
   w = ""; if(!UltraDisc_R8_Quality(u, buySide, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R9
   w = ""; if(!UltraDisc_R9_Broker(s, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R11
   w = ""; if(!UltraDisc_R11_Cooldown(idx, u, buySide, sig.tag, w)) { why = w; g_UltraDiscLastSummary = w; return false; }
   // R12
   string thesis = "";
   w = ""; if(!UltraDisc_R12_Explainable(u, buySide, sig.tag, thesis, w)) { why = w; g_UltraDiscLastSummary = w; return false; }

   g_UltraDisc[idx].lastThesis = thesis;
   summary = "DISCIPLINE PASS | ";
   summary += thesis;
   g_UltraDiscLastSummary = summary;

   if(UltraDisciplineLog)
      Print(summary, " on ", s);

   return true;
}

void UltraDiscipline_OnFill(const string s, const bool buySide, const string tag, const UltraSnap &u)
{
   int idx = UltraDisc_Ensure(s);
   g_UltraDisc[idx].lastFillTime = TimeCurrent();
   g_UltraDisc[idx].lastFillBar = iTime(s, UltraETF(), 0);
   g_UltraDisc[idx].lastFillDir = buySide ? 1 : -1;
   g_UltraDisc[idx].lastFillTag = tag;
   g_UltraDisc[idx].lastFillEpoch = UltraDisc_StructEpoch(u);
   // reset stability so next trade must re-confirm
   g_UltraDisc[idx].stableCount = 0;
   g_UltraDisc[idx].lastDir = 0;
}

string UltraDiscipline_DashboardLine()
{
   if(!UltraDisciplineEnabled) return "DISCIPLINE: OFF";
   if(StringLen(g_UltraDiscLastSummary) == 0) return "DISCIPLINE: READY";
   // keep dashboard short
   if(StringFind(g_UltraDiscLastSummary, "PASS") >= 0) return "DISCIPLINE: PASS";
   return "DISCIPLINE: WAIT";
}

#endif // HITMAN_ULTRA_TRADE_ENTRY_DISCIPLINE_MQH
