#ifndef HITMAN_ULTRA_PROP_STRATEGY_MQH
#define HITMAN_ULTRA_PROP_STRATEGY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 3 · PROPRIETARY STRATEGY ENGINE  |
//| Market → one Trade Thesis · one Confluence · one Confidence      |
//| NEVER places/closes/manages orders — candidates only             |
//| Mission Control makes the final decision                         |
//+------------------------------------------------------------------+

struct UltraPropStrategyState
{
   bool   booted;
   bool   approved;              // Strategy Approved (not Mission / not exec)
   string context;               // BULLISH|BEARISH|NEUTRAL|TRANSITION
   string candidate;             // BUY_CANDIDATE|SELL_CANDIDATE|WAIT
   string tag;
   string thesis;                // why this trade should exist
   string evidence;
   string riskNote;
   int    confluence;            // one confluence result 0..100
   int    confidence;            // one confidence 0..100 (USM2)
   bool   trendOK;
   bool   momentumOK;
   bool   liquidityOK;
   bool   thesisOK;
   bool   entryOK;
   string why;
   long   lastMs;
};

UltraPropStrategyState g_UltraPropStrategy;

void UltraPropStrategy_Boot()
{
   g_UltraPropStrategy.booted = true;
   g_UltraPropStrategy.approved = false;
   g_UltraPropStrategy.context = "NEUTRAL";
   g_UltraPropStrategy.candidate = "WAIT";
   g_UltraPropStrategy.tag = "";
   g_UltraPropStrategy.thesis = "";
   g_UltraPropStrategy.evidence = "";
   g_UltraPropStrategy.riskNote = "";
   g_UltraPropStrategy.confluence = 0;
   g_UltraPropStrategy.confidence = 0;
   g_UltraPropStrategy.trendOK = false;
   g_UltraPropStrategy.momentumOK = false;
   g_UltraPropStrategy.liquidityOK = false;
   g_UltraPropStrategy.thesisOK = false;
   g_UltraPropStrategy.entryOK = false;
   g_UltraPropStrategy.why = "boot";
   g_UltraPropStrategy.lastMs = 0;
}

bool UltraPropStrategy_Approved()
{
   return g_UltraPropStrategy.approved;
}

//--------------------------------------------------------------------//
// §2 MARKET CONTEXT — Bullish · Bearish · Neutral · Transition       //
//--------------------------------------------------------------------//
string UltraPropStrategy_MarketContext(const UltraSnap &u)
{
   // Prefer Chapter 2 reader/trend when available (no duplicate calc)
   if(StringLen(g_UltraMarketIntel.readerState) > 0)
   {
      if(g_UltraMarketIntel.readerState == "TRANSITION")
         return "TRANSITION";
      if(g_UltraMarketIntel.outTrend == "BULLISH")
         return "BULLISH";
      if(g_UltraMarketIntel.outTrend == "BEARISH")
         return "BEARISH";
      if(g_UltraMarketIntel.readerState == "TRENDING")
      {
         if(u.trend.bull || u.trend.htfBull) return "BULLISH";
         if(u.trend.bear || u.trend.htfBear) return "BEARISH";
         return "TRANSITION";
      }
      if(g_UltraMarketIntel.readerState == "RANGING" ||
         g_UltraMarketIntel.readerState == "COMPRESSION")
         return "NEUTRAL";
   }

   bool bull = (u.trend.bull || u.trend.htfBull || u.trend.macroBull);
   bool bear = (u.trend.bear || u.trend.htfBear || u.trend.macroBear);
   if(bull && bear) return "TRANSITION";
   if(bull && !bear) return "BULLISH";
   if(bear && !bull) return "BEARISH";
   if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) return "NEUTRAL";
   if(u.regime == UREG_REVERSAL || u.regime == UREG_EXHAUSTION) return "TRANSITION";
   return "NEUTRAL";
}

//--------------------------------------------------------------------//
// §7 CONFLUENCE — one result for the active side                     //
//--------------------------------------------------------------------//
int UltraPropStrategy_Confluence(const UltraSnap &u, const bool buySide)
{
   int c = 0;
   if(UltraPerfCacheConfluence && g_UltraLastConfValid)
      c = buySide ? g_UltraLastConfBuy : g_UltraLastConfSell;
   else
      c = buySide ? UltraConfluenceBuy(u) : UltraConfluenceSell(u);
   if(c < 0) c = 0;
   if(c > 100) c = 100;
   return c;
}

//--------------------------------------------------------------------//
// §3–5 TREND · MOMENTUM · LIQUIDITY VALIDATION                       //
//--------------------------------------------------------------------//
bool UltraPropStrategy_ValidateTrend(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   // Weak trends never become high-confidence trades
   if(u.trend.strength > 0 && u.trend.strength < 35 && !u.trend.continuation)
   { why = "STRATEGY: weak trend"; return false; }
   if(u.trend.exhaustion && u.trend.strength < 55)
   { why = "STRATEGY: trend exhaustion"; return false; }

   bool dirOK = buySide
      ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull ||
         u.trend.mtfVotesBuy >= u.trend.mtfVotesSell)
      : (u.trend.bear || u.trend.htfBear || u.trend.macroBear ||
         u.trend.mtfVotesSell > u.trend.mtfVotesBuy);
   if(!dirOK)
   { why = "STRATEGY: trend direction invalid"; return false; }
   return true;
}

bool UltraPropStrategy_ValidateMomentum(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool dirOK = buySide
      ? (u.mom.momBuy || u.mom.impulse || u.mom.direction > 0 || u.ind.smi > 0)
      : (u.mom.momSell || u.mom.impulse || u.mom.direction < 0 || u.ind.smi < 0);
   if(!dirOK && !InstantQualityMode)
   { why = "STRATEGY: momentum direction invalid"; return false; }
   if(u.mom.strength > 0 && u.mom.strength < 30 && u.mom.weakness && !u.mom.impulse)
   { why = "STRATEGY: weak momentum energy"; return false; }
   // Acceleration / continuation soft — impulse or non-weak accel
   if(!u.mom.impulse && u.mom.acceleration > 0 && u.mom.acceleration < 35 &&
      u.mom.weakness && !InstantQualityMode)
   { why = "STRATEGY: momentum decelerating"; return false; }
   return true;
}

bool UltraPropStrategy_ValidateLiquidity(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   // Support decision quality — soft fail only on clear thin/fake
   if(u.liq.quality > 0.0 && u.liq.quality < 25.0 &&
      !u.liq.genuineBuy && !u.liq.genuineSell)
   { why = "STRATEGY: thin liquidity"; return false; }
   if(buySide && u.liq.fakeBuy && !u.liq.genuineBuy && !u.liq.confirmedBuy)
   { why = "STRATEGY: fake buy liquidity"; return false; }
   if(!buySide && u.liq.fakeSell && !u.liq.genuineSell && !u.liq.confirmedSell)
   { why = "STRATEGY: fake sell liquidity"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// §6 TRADE THESIS — Why should this trade exist?                     //
//--------------------------------------------------------------------//
string UltraPropStrategy_BuildThesis(const UltraSnap &u, const UltraSignal &sig,
                                     const string context, const int confluence)
{
   string th = "";
   if(sig.buy) th = "BUY ";
   else if(sig.sell) th = "SELL ";
   else return "NO THESIS";

   th += sig.tag;
   th += " | ctx=";
   th += context;
   th += " | conf=";
   th += IntegerToString(u.score.confidence);
   th += " | cfl=";
   th += IntegerToString(confluence);

   // Supporting evidence
   string ev = "";
   if(sig.buy)
   {
      if(u.trend.bull || u.trend.htfBull) ev += "trend+ ";
      if(u.bos.buy) ev += "BOS+ ";
      if(u.liq.sweepBuy || u.liq.genuineBuy) ev += "liq+ ";
      if(u.mom.momBuy || u.mom.impulse) ev += "mom+ ";
      if(u.fib.atBuyZone || u.ict.inDiscount) ev += "zone+ ";
   }
   else
   {
      if(u.trend.bear || u.trend.htfBear) ev += "trend+ ";
      if(u.bos.sell) ev += "BOS+ ";
      if(u.liq.sweepSell || u.liq.genuineSell) ev += "liq+ ";
      if(u.mom.momSell || u.mom.impulse) ev += "mom+ ";
      if(u.fib.atSellZone || u.ict.inPremium) ev += "zone+ ";
   }
   if(StringLen(ev) == 0) ev = "setup ";
   th += " | ev=";
   th += ev;

   // Risk assessment (informational — Strategy never controls risk)
   string risk = "risk=";
   if(u.score.riskProb >= 70) risk += "HIGH";
   else if(u.score.riskProb >= 45) risk += "MID";
   else risk += "LOW";
   if(u.vol.expansion) risk += "/VOL+";
   if(StringLen(g_UltraMarketIntel.outSpread) > 0)
   {
      risk += "/spr=";
      risk += g_UltraMarketIntel.outSpread;
   }
   th += " | ";
   th += risk;

   if(StringLen(sig.reason) > 0)
   {
      th += " | ";
      th += sig.reason;
   }
   return th;
}

bool UltraPropStrategy_ThesisClear(const UltraSignal &sig, const string thesis, string &why)
{
   why = "";
   if(sig.tag == "" || sig.tag == "NONE")
   { why = "STRATEGY: no clear thesis (no tag)"; return false; }
   if(!(sig.buy || sig.sell))
   { why = "STRATEGY: no clear thesis (no side)"; return false; }
   if(StringLen(thesis) < 8 || thesis == "NO THESIS")
   { why = "STRATEGY: no clear thesis"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// §9 ENTRY VALIDATION → Strategy Approved                            //
//--------------------------------------------------------------------//
bool UltraPropStrategy_ValidateEntry(const UltraSnap &u, const UltraSignal &sig,
                                     const int confluence, string &why)
{
   why = "";
   if(!g_UltraPropStrategy.thesisOK)
   { why = "STRATEGY: thesis required"; return false; }
   if(!g_UltraPropStrategy.trendOK)
   { why = (StringLen(g_UltraPropStrategy.why) > 0) ? g_UltraPropStrategy.why : "STRATEGY: trend"; return false; }
   if(!g_UltraPropStrategy.momentumOK)
   { why = (StringLen(g_UltraPropStrategy.why) > 0) ? g_UltraPropStrategy.why : "STRATEGY: momentum"; return false; }

   // Confluence agreement
   int floor = UltraFireFloor();
   if(InstantQualityMode) floor = MathMax(1, floor - 8);
   if(confluence < floor && u.score.confidence < UltraInstantFireConf)
   { why = "STRATEGY: confluence low"; return false; }

   // Risk requirements — soft informational gate (Strategy never sizes/closes)
   if(u.score.riskProb >= 90 && u.score.confidence < UltraInstantFireConf)
   { why = "STRATEGY: risk requirements not met"; return false; }

   // Context alignment — avoid fighting environment
   if(sig.buy && g_UltraPropStrategy.context == "BEARISH" &&
      !(u.trend.htfBull || u.bos.buy))
   { why = "STRATEGY: BUY vs bearish environment"; return false; }
   if(sig.sell && g_UltraPropStrategy.context == "BULLISH" &&
      !(u.trend.htfBear || u.bos.sell))
   { why = "STRATEGY: SELL vs bullish environment"; return false; }

   return true;
}

//--------------------------------------------------------------------//
// §1 / §10 — EVALUATE · outputs BUY/SELL Candidate or WAIT only      //
//--------------------------------------------------------------------//
bool UltraPropStrategy_Evaluate(const string s, const UltraSnap &u, UltraSignal &sig, string &why)
{
   why = "";
   g_UltraPropStrategy.approved = false;
   g_UltraPropStrategy.entryOK = false;
   g_UltraPropStrategy.trendOK = false;
   g_UltraPropStrategy.momentumOK = false;
   g_UltraPropStrategy.liquidityOK = false;
   g_UltraPropStrategy.thesisOK = false;
   g_UltraPropStrategy.lastMs = (long)GetTickCount();

   // No conflicting strategy sides
   if(sig.buy && sig.sell)
   {
      sig.buy = sig.sell = false;
      g_UltraPropStrategy.candidate = "WAIT";
      g_UltraPropStrategy.why = "STRATEGY: contradictory BUY+SELL";
      why = g_UltraPropStrategy.why;
      return false;
   }

   if(!(sig.buy || sig.sell) || sig.tag == "NONE")
   {
      g_UltraPropStrategy.candidate = "WAIT";
      g_UltraPropStrategy.context = UltraPropStrategy_MarketContext(u);
      g_UltraPropStrategy.confidence = u.score.confidence;
      g_UltraPropStrategy.confluence = 0;
      g_UltraPropStrategy.thesis = "NO THESIS";
      g_UltraPropStrategy.why = "STRATEGY: no opportunity";
      why = g_UltraPropStrategy.why;
      return false;
   }

   // §2 Context
   g_UltraPropStrategy.context = UltraPropStrategy_MarketContext(u);
   g_UltraPropStrategy.tag = sig.tag;

   // §7 One confluence
   g_UltraPropStrategy.confluence = UltraPropStrategy_Confluence(u, sig.buy);

   // §8 One confidence (USM2 already wrote u.score.confidence)
   g_UltraPropStrategy.confidence = u.score.confidence;
   if(g_UltraPropStrategy.confidence < 0) g_UltraPropStrategy.confidence = 0;
   if(g_UltraPropStrategy.confidence > 100) g_UltraPropStrategy.confidence = 100;

   // §3–5 Validations
   string w = "";
   g_UltraPropStrategy.trendOK = UltraPropStrategy_ValidateTrend(u, sig.buy, w);
   if(!g_UltraPropStrategy.trendOK) g_UltraPropStrategy.why = w;
   w = "";
   g_UltraPropStrategy.momentumOK = UltraPropStrategy_ValidateMomentum(u, sig.buy, w);
   if(!g_UltraPropStrategy.momentumOK && StringLen(g_UltraPropStrategy.why) == 0)
      g_UltraPropStrategy.why = w;
   w = "";
   g_UltraPropStrategy.liquidityOK = UltraPropStrategy_ValidateLiquidity(u, sig.buy, w);
   // Liquidity supports quality — soft: warn only unless hard fake/thin
   if(!g_UltraPropStrategy.liquidityOK)
   {
      g_UltraPropStrategy.why = w;
      g_UltraPropStrategy.candidate = "WAIT";
      sig.buy = sig.sell = false;
      why = w;
      return false;
   }

   // §6 Thesis
   g_UltraPropStrategy.thesis = UltraPropStrategy_BuildThesis(
      u, sig, g_UltraPropStrategy.context, g_UltraPropStrategy.confluence);
   g_UltraPropStrategy.evidence = g_UltraPropStrategy.thesis;
   g_UltraPropStrategy.riskNote = StringFormat("riskProb=%d", u.score.riskProb);
   w = "";
   g_UltraPropStrategy.thesisOK = UltraPropStrategy_ThesisClear(sig, g_UltraPropStrategy.thesis, w);
   if(!g_UltraPropStrategy.thesisOK)
   {
      g_UltraPropStrategy.candidate = "WAIT";
      g_UltraPropStrategy.why = w;
      sig.buy = sig.sell = false;
      why = w;
      return false;
   }

   // §9 Entry validation
   w = "";
   g_UltraPropStrategy.entryOK = UltraPropStrategy_ValidateEntry(
      u, sig, g_UltraPropStrategy.confluence, w);
   if(!g_UltraPropStrategy.entryOK)
   {
      g_UltraPropStrategy.candidate = "WAIT";
      g_UltraPropStrategy.why = w;
      g_UltraPropStrategy.approved = false;
      sig.buy = sig.sell = false;
      why = w;
      return false;
   }

   // Attach thesis onto signal reason trail (Strategy never executes)
   if(StringLen(sig.reason) > 0) sig.reason = sig.reason + " | ";
   sig.reason = sig.reason + g_UltraPropStrategy.thesis;

   g_UltraPropStrategy.candidate = sig.buy ? "BUY_CANDIDATE" : "SELL_CANDIDATE";
   g_UltraPropStrategy.approved = true;
   g_UltraPropStrategy.why = "STRATEGY_APPROVED";
   // Candidate label for Chapter 4 consumption (still not execution)
   if(sig.buy && !sig.sell) sig.candidate = "BUY_CANDIDATE";
   else if(sig.sell && !sig.buy) sig.candidate = "SELL_CANDIDATE";
   return true;
}

string UltraPropStrategy_Dashboard()
{
   string t = "STRATEGY: ";
   if(!g_UltraPropStrategy.booted) { t += "OFF"; return t; }
   if(g_UltraPropStrategy.approved) t += "APPROVED ";
   else t += "WAIT ";
   t += g_UltraPropStrategy.candidate;
   t += " ctx=";
   t += g_UltraPropStrategy.context;
   t += " cfl=";
   t += IntegerToString(g_UltraPropStrategy.confluence);
   t += " conf=";
   t += IntegerToString(g_UltraPropStrategy.confidence);
   if(StringLen(g_UltraPropStrategy.tag) > 0)
   {
      t += " [";
      t += g_UltraPropStrategy.tag;
      t += "]";
   }
   if(!g_UltraPropStrategy.approved && StringLen(g_UltraPropStrategy.why) > 0)
   {
      t += " | ";
      t += g_UltraPropStrategy.why;
   }
   return t;
}

#endif // HITMAN_ULTRA_PROP_STRATEGY_MQH
