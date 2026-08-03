#ifndef HITMAN_ULTRA_35_SIGNAL_MQH
#define HITMAN_ULTRA_35_SIGNAL_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 4 · SIGNAL INTELLIGENCE ENGINE   |
//| Transform Strategy output → one clean BUY/SELL candidate / WAIT  |
//| NEVER executes · NEVER manages positions · NEVER controls risk   |
//| Mission Control decides whether execution is allowed             |
//+------------------------------------------------------------------+

struct UltraRawSignal
{
   bool   buy;
   bool   sell;
   int    score;
   string tag;
   string reason;
   string explanation;
   bool   valid;
   string candidate;
   int    confidence;
   int    quality;
};

struct UltraSignalChecklist
{
   bool structure;
   bool bosOrChoch;
   bool liquidity;
   bool trend;
   bool momentum;
   bool precisionOK;
   bool confidenceOK;
   int  passed;
};

struct UltraSignalIntelState
{
   bool   booted;
   string lastCandidate;     // BUY_CANDIDATE | SELL_CANDIDATE | WAIT
   string lastLife;
   string lastTag;
   string lastWhy;
   int    lastConfidence;    // one score
   int    lastQuality;
   int    lastStrength;
   int    lastStability;
   int    lastReliability;
   int    lastConsistency;
   ulong  createdCount;
   ulong  validatedCount;
   ulong  rejectedCount;
   ulong  archivedCount;
   long   lastMs;
};

UltraSignalIntelState g_UltraSignalIntel;

//--------------------------------------------------------------------//
string UltraSignalIntel_LifeName(const ENUM_ULTRA_SIGNAL_LIFE L)
{
   switch(L)
   {
      case USIG_CREATED:   return "CREATED";
      case USIG_VALIDATED: return "VALIDATED";
      case USIG_MISSION:   return "MISSION";
      case USIG_EXECUTED:  return "EXECUTED";
      case USIG_REJECTED:  return "REJECTED";
      case USIG_ARCHIVED:  return "ARCHIVED";
      default:             return "NONE";
   }
}

void UltraSignalIntel_Boot()
{
   g_UltraSignalIntel.booted = true;
   g_UltraSignalIntel.lastCandidate = "WAIT";
   g_UltraSignalIntel.lastLife = "NONE";
   g_UltraSignalIntel.lastTag = "";
   g_UltraSignalIntel.lastWhy = "";
   g_UltraSignalIntel.lastConfidence = 0;
   g_UltraSignalIntel.lastQuality = 0;
   g_UltraSignalIntel.lastStrength = 0;
   g_UltraSignalIntel.lastStability = 0;
   g_UltraSignalIntel.lastReliability = 0;
   g_UltraSignalIntel.lastConsistency = 0;
   g_UltraSignalIntel.createdCount = 0;
   g_UltraSignalIntel.validatedCount = 0;
   g_UltraSignalIntel.rejectedCount = 0;
   g_UltraSignalIntel.archivedCount = 0;
   g_UltraSignalIntel.lastMs = 0;
}

void UltraSignalIntel_Clear(UltraSignal &sig)
{
   sig.buy = sig.sell = false;
   sig.score = 0;
   sig.tag = "NONE";
   sig.reason = "";
   sig.explanation = "";
   sig.candidate = "WAIT";
   sig.confidence = 0;
   sig.quality = 0;
   sig.strength = sig.stability = sig.reliability = sig.consistency = 0;
   sig.life = USIG_NONE;
   sig.lifeName = "NONE";
}

void UltraSignalIntel_SetLife(UltraSignal &sig, const ENUM_ULTRA_SIGNAL_LIFE L)
{
   sig.life = L;
   sig.lifeName = UltraSignalIntel_LifeName(L);
   g_UltraSignalIntel.lastLife = sig.lifeName;
   g_UltraSignalIntel.lastMs = (long)GetTickCount();
}

void UltraSignalIntel_SyncState(const UltraSignal &sig, const string why)
{
   g_UltraSignalIntel.lastCandidate = sig.candidate;
   g_UltraSignalIntel.lastTag = sig.tag;
   g_UltraSignalIntel.lastWhy = why;
   g_UltraSignalIntel.lastConfidence = sig.confidence;
   g_UltraSignalIntel.lastQuality = sig.quality;
   g_UltraSignalIntel.lastStrength = sig.strength;
   g_UltraSignalIntel.lastStability = sig.stability;
   g_UltraSignalIntel.lastReliability = sig.reliability;
   g_UltraSignalIntel.lastConsistency = sig.consistency;
   g_UltraSignalIntel.lastLife = sig.lifeName;
   g_UltraSignalIntel.lastMs = (long)GetTickCount();
}

//--------------------------------------------------------------------//
// CHECKLIST — BUY/SELL detection support                             //
//--------------------------------------------------------------------//
UltraSignalChecklist UltraSignal_EvalSide(const UltraSnap &u, const bool buySide)
{
   UltraSignalChecklist c;
   if(buySide)
   {
      c.structure  = (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation);
      c.bosOrChoch = (u.bos.buy || u.choch.buy);
      c.liquidity  = (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.grabBuy || u.liq.equalLows);
      c.trend      = (u.trend.bull || u.trend.htfBull || u.trend.macroBull || u.trend.mtfVotesBuy >= u.trend.mtfVotesSell);
      c.momentum   = (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy || u.ind.smi > 0);
   }
   else
   {
      c.structure  = (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
      c.bosOrChoch = (u.bos.sell || u.choch.sell);
      c.liquidity  = (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.grabSell || u.liq.equalHighs);
      c.trend      = (u.trend.bear || u.trend.htfBear || u.trend.macroBear || u.trend.mtfVotesSell > u.trend.mtfVotesBuy);
      c.momentum   = (u.mom.momSell || u.mom.impulse || u.ict.dispSell || u.ind.smi < 0);
   }
   c.precisionOK  = (u.score.precision >= UltraMinPrecision || u.score.confidence >= UltraInstantFireConf);
   c.confidenceOK = (u.score.confidence >= UltraFireFloor() || u.score.confidence >= UltraInstantFireConf ||
                     (InstantQualityMode && u.score.confidence >= UltraFireFloor() - 8));
   c.passed = (c.structure?1:0)+(c.bosOrChoch?1:0)+(c.liquidity?1:0)+(c.trend?1:0)+
              (c.momentum?1:0)+(c.precisionOK?1:0)+(c.confidenceOK?1:0);
   return c;
}

string UltraSignal_Explain(const UltraSnap &u, const bool buySide, const bool approved, const string decision)
{
   return UltraBuildExplanation(u, buySide, approved, decision);
}

bool UltraSignal_ChecklistPass(const UltraSnap &u, const bool buySide)
{
   UltraSignalChecklist c = UltraSignal_EvalSide(u, buySide);
   if(InstantQualityMode)
      return (c.passed >= 4 && c.confidenceOK);
   return (c.structure && c.bosOrChoch && c.trend && c.confidenceOK &&
           (c.liquidity || c.momentum) && c.precisionOK);
}

//--------------------------------------------------------------------//
// CHAPTER 4 §1 — SIGNAL CORE · mark candidate (CREATED)              //
//--------------------------------------------------------------------//
void UltraSignalIntel_MarkCreated(UltraSignal &sig)
{
   if(sig.buy && !sig.sell) sig.candidate = "BUY_CANDIDATE";
   else if(sig.sell && !sig.buy) sig.candidate = "SELL_CANDIDATE";
   else
   {
      sig.candidate = "WAIT";
      sig.buy = sig.sell = false;
   }
   UltraSignalIntel_SetLife(sig, USIG_CREATED);
   g_UltraSignalIntel.createdCount++;
   UltraSignalIntel_SyncState(sig, "created");
}

//--------------------------------------------------------------------//
// CHAPTER 4 §5 — SIGNAL QUALITY (strength·stability·reliability·cons)//
//--------------------------------------------------------------------//
void UltraSignalIntel_ComputeQuality(const string s, const UltraSnap &u,
                                     UltraSignal &sig, const UltraSignalEvo &evo)
{
   // Strength — strategy score + confluence lean
   int confB = 0, confS = 0;
   if(UltraPerfCacheConfluence && g_UltraLastConfValid)
   { confB = g_UltraLastConfBuy; confS = g_UltraLastConfSell; }
   else
   { confB = UltraConfluenceBuy(u); confS = UltraConfluenceSell(u); }
   int lean = sig.buy ? confB : confS;
   sig.strength = MathMax(0, MathMin(100, (sig.score > 0 ? sig.score : lean)));
   if(sig.strength < lean) sig.strength = MathMin(100, (sig.strength + lean) / 2);

   // Stability — Signal Evolution
   sig.stability = evo.stability;
   if(sig.stability <= 0) sig.stability = 50;

   // Reliability — structure / BOS quality
   int rel = 40;
   if(sig.buy)
   {
      if(u.bos.buy && u.bos.confirmed) rel += 20;
      if(u.bos.reliability > 0) rel = MathMax(rel, u.bos.reliability);
      if(u.st.quality > 0) rel = MathMax(rel, (rel + u.st.quality) / 2);
   }
   else if(sig.sell)
   {
      if(u.bos.sell && u.bos.confirmed) rel += 20;
      if(u.bos.reliability > 0) rel = MathMax(rel, u.bos.reliability);
      if(u.st.quality > 0) rel = MathMax(rel, (rel + u.st.quality) / 2);
   }
   if(rel > 100) rel = 100;
   sig.reliability = rel;

   // Consistency — MTF vote agreement (no conflicting picture)
   int votes = sig.buy ? u.trend.mtfVotesBuy : u.trend.mtfVotesSell;
   int opp   = sig.buy ? u.trend.mtfVotesSell : u.trend.mtfVotesBuy;
   int cons = 50 + (votes - opp) * 8;
   if(cons < 0) cons = 0;
   if(cons > 100) cons = 100;
   if(u.trend.continuation) cons = MathMin(100, cons + 8);
   if(u.trend.exhaustion)   cons = MathMax(0, cons - 15);
   sig.consistency = cons;

   // Composite quality
   sig.quality = (sig.strength * 30 + sig.stability * 25 +
                  sig.reliability * 25 + sig.consistency * 20) / 100;
   if(sig.quality > 100) sig.quality = 100;
   if(sig.quality < 0) sig.quality = 0;
}

//--------------------------------------------------------------------//
// CHAPTER 4 §4 — SIGNAL VALIDATION (thesis·context·trend·mom·conf)   //
//--------------------------------------------------------------------//
bool UltraSignalIntel_ValidateCore(const UltraSnap &u, const UltraSignal &sig, string &why)
{
   why = "";
   if(!(sig.buy || sig.sell) || sig.candidate == "WAIT")
   { why = "SIGNAL: no candidate"; return false; }

   // Trade Thesis — strategy tag/reason required
   if(sig.tag == "" || sig.tag == "NONE")
   { why = "SIGNAL: poor trade thesis (no tag)"; return false; }
   if(StringLen(sig.reason) == 0 && sig.score <= 0)
   { why = "SIGNAL: poor trade thesis"; return false; }

   // Market Context — Market Intelligence picture present
   if(UltraMarketIntelEnabled && g_UltraMarketIntel.booted &&
      !g_UltraMarketIntel.approved)
   { why = "SIGNAL: market context rejected"; return false; }

   UltraSignalChecklist c = UltraSignal_EvalSide(u, sig.buy);
   if(!c.trend)
   { why = "SIGNAL: trend invalid"; return false; }
   if(!c.momentum && !InstantQualityMode)
   { why = "SIGNAL: momentum invalid"; return false; }
   if(InstantQualityMode && !c.momentum && !c.liquidity)
   { why = "SIGNAL: momentum/liquidity weak"; return false; }

   // One confidence score
   int conf = u.score.confidence;
   if(conf < UltraFireFloor() && conf < UltraInstantFireConf)
   { why = "SIGNAL: confidence low"; return false; }

   return true;
}

//--------------------------------------------------------------------//
// CHAPTER 4 §6 — FALSE SIGNAL REDUCTION                              //
//--------------------------------------------------------------------//
bool UltraSignalIntel_FalseReduce(const UltraSnap &u, const UltraSignal &sig,
                                  const UltraSignalEvo &evo, string &why)
{
   why = "";
   // Weak trend
   if(u.trend.strength > 0 && u.trend.strength < 35 && !u.trend.continuation)
   { why = "SIGNAL: weak trend"; return false; }

   // Weak momentum
   if(u.mom.strength > 0 && u.mom.strength < 30 && u.mom.weakness && !u.mom.impulse)
   { why = "SIGNAL: weak momentum"; return false; }

   // Poor thesis / evolution reversal
   if(evo.state == SEVO_REVERSAL)
   { why = "SIGNAL: contradictory reversal"; return false; }

   // Low confidence (hard floor already applied; soft belt)
   if(u.score.confidence < UltraFireFloor() - (InstantQualityMode ? 8 : 0) &&
      u.score.confidence < UltraInstantFireConf)
   { why = "SIGNAL: low confidence"; return false; }

   // Contradictory conditions — buy vs bear HTF stack / sell vs bull
   if(sig.buy && u.trend.htfBear && u.trend.macroBear && !u.trend.htfBull)
   { why = "SIGNAL: contradictory bull vs HTF bear"; return false; }
   if(sig.sell && u.trend.htfBull && u.trend.macroBull && !u.trend.htfBear)
   { why = "SIGNAL: contradictory sell vs HTF bull"; return false; }

   // Quality floor — improve entry quality without inventing a new engine
   if(sig.quality > 0 && sig.quality < 28 && !InstantQualityMode)
   { why = "SIGNAL: quality too low"; return false; }

   return true;
}

//--------------------------------------------------------------------//
// CHAPTER 4 — FINALIZE CANDIDATE (before Mission · never executes)   //
//--------------------------------------------------------------------//
bool UltraSignalIntel_Finalize(const string s, const UltraSnap &u, UltraSignal &sig, string &why)
{
   why = "";
   // Sole confidence score in the EA
   sig.confidence = u.score.confidence;
   if(sig.confidence < 0) sig.confidence = 0;
   if(sig.confidence > 100) sig.confidence = 100;
   sig.score = MathMax(sig.score, sig.confidence);

   if(!(sig.buy || sig.sell))
   {
      sig.candidate = "WAIT";
      UltraSignalIntel_SetLife(sig, USIG_REJECTED);
      g_UltraSignalIntel.rejectedCount++;
      UltraSignalIntel_SyncState(sig, "no side");
      why = "SIGNAL: WAIT (no side)";
      return false;
   }

   if(sig.buy && sig.sell)
   {
      // No conflicting signals — collapse to WAIT
      sig.buy = sig.sell = false;
      sig.candidate = "WAIT";
      UltraSignalIntel_SetLife(sig, USIG_REJECTED);
      g_UltraSignalIntel.rejectedCount++;
      UltraSignalIntel_SyncState(sig, "conflict");
      why = "SIGNAL: conflicting BUY+SELL";
      return false;
   }

   UltraSignalIntel_MarkCreated(sig);

   UltraSignalEvo evo = UltraEvo_Evaluate(s, u, sig.buy);
   UltraSignalIntel_ComputeQuality(s, u, sig, evo);

   if(!UltraSignalIntel_ValidateCore(u, sig, why))
   {
      sig.buy = sig.sell = false;
      sig.candidate = "WAIT";
      UltraSignalIntel_SetLife(sig, USIG_REJECTED);
      g_UltraSignalIntel.rejectedCount++;
      UltraSignalIntel_SyncState(sig, why);
      return false;
   }

   if(!UltraSignalIntel_FalseReduce(u, sig, evo, why))
   {
      sig.buy = sig.sell = false;
      sig.candidate = "WAIT";
      UltraSignalIntel_SetLife(sig, USIG_REJECTED);
      g_UltraSignalIntel.rejectedCount++;
      UltraSignalIntel_SyncState(sig, why);
      return false;
   }

   UltraSignalIntel_SetLife(sig, USIG_VALIDATED);
   g_UltraSignalIntel.validatedCount++;
   sig.explanation = UltraSignal_Explain(u, sig.buy, true, sig.tag);
   UltraSignalIntel_SyncState(sig, "validated");
   // LOCK: do not execute · Mission decides next
   return true;
}

void UltraSignalIntel_MarkMission(UltraSignal &sig)
{
   if(sig.life == USIG_VALIDATED || sig.life == USIG_CREATED)
   {
      UltraSignalIntel_SetLife(sig, USIG_MISSION);
      UltraSignalIntel_SyncState(sig, "mission");
   }
}

void UltraSignalIntel_MarkExecuted(UltraSignal &sig)
{
   UltraSignalIntel_SetLife(sig, USIG_EXECUTED);
   UltraSignalIntel_SyncState(sig, "executed");
}

void UltraSignalIntel_MarkRejected(UltraSignal &sig, const string why)
{
   sig.buy = sig.sell = false;
   sig.candidate = "WAIT";
   UltraSignalIntel_SetLife(sig, USIG_REJECTED);
   g_UltraSignalIntel.rejectedCount++;
   UltraSignalIntel_SyncState(sig, why);
}

void UltraSignalIntel_Archive(UltraSignal &sig)
{
   UltraSignalIntel_SetLife(sig, USIG_ARCHIVED);
   g_UltraSignalIntel.archivedCount++;
   UltraSignalIntel_SyncState(sig, "archived");
}

string UltraSignalIntel_Dashboard()
{
   string t = "SIGNAL: ";
   t += g_UltraSignalIntel.lastCandidate;
   t += " life=";
   t += g_UltraSignalIntel.lastLife;
   t += " conf=";
   t += IntegerToString(g_UltraSignalIntel.lastConfidence);
   t += " Q=";
   t += IntegerToString(g_UltraSignalIntel.lastQuality);
   t += " [";
   t += IntegerToString(g_UltraSignalIntel.lastStrength);
   t += "/";
   t += IntegerToString(g_UltraSignalIntel.lastStability);
   t += "/";
   t += IntegerToString(g_UltraSignalIntel.lastReliability);
   t += "/";
   t += IntegerToString(g_UltraSignalIntel.lastConsistency);
   t += "]";
   if(StringLen(g_UltraSignalIntel.lastTag) > 0)
   {
      t += " ";
      t += g_UltraSignalIntel.lastTag;
   }
   return t;
}

//--------------------------------------------------------------------//
// LEGACY RAW API — candidate-only (no Mission / no execute)          //
//--------------------------------------------------------------------//
UltraRawSignal UltraSignal_Generate(const string s)
{
   UltraRawSignal out;
   out.buy = out.sell = false; out.score = 0; out.tag = "NONE";
   out.reason = ""; out.explanation = ""; out.valid = false;
   out.candidate = "WAIT"; out.confidence = 0; out.quality = 0;

   UltraSnap snap;
   if(!UltraBuildSnapshot(s, snap))
   {
      out.reason = "snapshot fail";
      out.explanation = "Decision = WAIT | Reason = snapshot fail";
      return out;
   }

   UltraSignal best = UltraPickBest(snap);
   if(!(best.buy || best.sell))
   {
      out.reason = best.reason;
      out.score = snap.score.confidence;
      out.confidence = snap.score.confidence;
      out.candidate = "WAIT";
      out.explanation = UltraSignal_Explain(snap, true, false, "NO TRADE");
      return out;
   }

   // Score side for confidence surface
   if(UltraUSM2Enabled)
   {
      UltraUSM2Scores usm;
      UltraUSM2_Score(s, snap, best.buy, usm);
   }
   else
      UltraEngScores(snap, best.buy);

   string why = "";
   if(!UltraSignalIntel_Finalize(s, snap, best, why))
   {
      out.reason = why;
      out.score = snap.score.confidence;
      out.confidence = snap.score.confidence;
      out.quality = best.quality;
      out.candidate = "WAIT";
      out.explanation = UltraSignal_Explain(snap, best.buy, false, "NO TRADE");
      return out;
   }

   out.buy = best.buy; out.sell = best.sell;
   out.score = best.score; out.tag = best.tag; out.reason = best.reason;
   out.explanation = best.explanation;
   out.candidate = best.candidate;
   out.confidence = best.confidence;
   out.quality = best.quality;
   out.valid = (out.buy || out.sell);
   return out;
}

bool UltraSignal_Filter(const UltraRawSignal &sig, const int minScore)
{
   if(!sig.valid) return false;
   if(!(sig.buy || sig.sell)) return false;
   if(sig.score < minScore) return false;
   return true;
}

bool UltraSignal_Validate(const string s, const UltraRawSignal &sig, string &why)
{
   why = "";
   if(!UltraSignal_Filter(sig, UltraFireFloor()) && sig.score < UltraInstantFireConf)
   { why = "score filter"; return false; }
   if(UltraBlockOppositeSameSym)
   {
      int d = UltraSymDir(s);
      if(sig.buy && d < 0){ why = "opposite sell open"; return false; }
      if(sig.sell && d > 0){ why = "opposite buy open"; return false; }
   }
   return true;
}

#endif // HITMAN_ULTRA_35_SIGNAL_MQH
