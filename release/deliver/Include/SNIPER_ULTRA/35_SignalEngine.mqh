#ifndef SNIPER_ULTRA_35_SIGNAL_MQH
#define SNIPER_ULTRA_35_SIGNAL_MQH
//+------------------------------------------------------------------+
//| 35_SignalEngine — Master Blueprint BUY/SELL checklist            |
//| BUY:  Structure · BOS|CHoCH · Liquidity · Trend · Momentum ·     |
//|       Precision · Confidence                                     |
//| SELL: same on bearish side                                       |
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

// Soft checklist note: live fire stays UltraAIDecide; this API adds explain + formal gates
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

UltraRawSignal UltraSignal_Generate(const string s)
{
   UltraRawSignal out;
   out.buy = out.sell = false; out.score = 0; out.tag = "NONE";
   out.reason = ""; out.explanation = ""; out.valid = false;

   UltraSnap snap;
   if(!UltraBuildSnapshot(s, snap))
   {
      out.reason = "snapshot fail";
      out.explanation = "Decision = WAIT | Reason = snapshot fail";
      return out;
   }

   UltraSignal best;
   string why = "";
   if(!UltraAIDecide(s, snap, best, why))
   {
      bool leanBuy = (UltraConfluenceBuy(snap) >= UltraConfluenceSell(snap));
      out.reason = why;
      out.score = snap.score.confidence;
      out.explanation = UltraSignal_Explain(snap, leanBuy, false, "NO TRADE");
      return out;
   }

   if(!UltraSignal_ChecklistPass(snap, best.buy))
   {
      out.reason = "checklist incomplete";
      out.score = snap.score.confidence;
      out.explanation = UltraSignal_Explain(snap, best.buy, false, "NO TRADE");
      return out;
   }

   out.buy = best.buy; out.sell = best.sell;
   out.score = best.score; out.tag = best.tag; out.reason = best.reason;
   out.explanation = UltraSignal_Explain(snap, best.buy, true, best.tag);
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

#endif // SNIPER_ULTRA_35_SIGNAL_MQH
