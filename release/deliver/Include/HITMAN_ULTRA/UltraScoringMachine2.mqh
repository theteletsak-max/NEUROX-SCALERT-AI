#ifndef HITMAN_ULTRA_USM2_MQH
#define HITMAN_ULTRA_USM2_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 4 ULTRA SCORING MACHINE 2.0                    |
//| Component scores → Final AI Confidence + Trade Score             |
//+------------------------------------------------------------------+

struct UltraUSM2Scores
{
   int structure, trend, bos, choch, liquidity, fibonacci, institutional;
   int momentum, volatility, regime, session, news, precision, probability;
   int risk, execution;
   int confidence;   // Final AI Confidence 0-100
   int tradeScore;   // Final Trade Score 0-100
   string grade;     // LEGENDARY..IGNORE
};

string UltraUSM2_Grade(const double finalScore)
{
   if(finalScore >= 98.0) return "LEGENDARY";
   if(finalScore >= 95.0) return "ELITE";
   if(finalScore >= 90.0) return "INSTITUTIONAL";
   if(finalScore >= 85.0) return "PROFESSIONAL";
   if(finalScore >= 80.0) return "STRONG";
   if(finalScore >= 75.0) return "WATCHLIST";
   return "IGNORE";
}

int UltraUSM2_Clamp(const int v)
{
   if(v < 0) return 0;
   if(v > 100) return 100;
   return v;
}

int UltraUSM2_ComponentStructure(const UltraSnap &u, const bool buySide)
{
   int sc = 20;
   if(buySide)
   {
      if(u.st.hh || u.st.hl) sc += 20;
      if(u.st.externalBull || u.st.internalBull) sc += 15;
      if(u.st.continuation) sc += 10;
   }
   else
   {
      if(u.st.lh || u.st.ll) sc += 20;
      if(u.st.externalBear || u.st.internalBear) sc += 15;
      if(u.st.continuation) sc += 10;
   }
   sc += u.st.quality / 4;
   sc += u.st.strength / 5;
   if(u.st.swingHighOK || u.st.swingLowOK) sc += 8;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentTrend(const UltraSnap &u, const bool buySide)
{
   int sc = 15;
   if(buySide)
   {
      if(u.trend.bull) sc += 20; if(u.trend.htfBull) sc += 15; if(u.trend.macroBull) sc += 12;
      sc += u.trend.mtfVotesBuy * 4;
   }
   else
   {
      if(u.trend.bear) sc += 20; if(u.trend.htfBear) sc += 15; if(u.trend.macroBear) sc += 12;
      sc += u.trend.mtfVotesSell * 4;
   }
   sc += u.trend.strength / 4;
   sc += u.trend.persistence / 5;
   if(u.trend.exhaustion) sc -= 10;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentBOS(const UltraSnap &u, const bool buySide)
{
   int sc = 10;
   bool hit = buySide ? u.bos.buy : u.bos.sell;
   if(hit) sc += 35;
   if(u.bos.confirmed) sc += 15;
   if(u.bos.strong) sc += 20;
   if(u.bos.weak) sc += 5;
   if(u.bos.failed) sc -= 25;
   sc += u.bos.score / 5;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentCHoCH(const UltraSnap &u, const bool buySide)
{
   int sc = 10;
   bool hit = buySide ? u.choch.buy : u.choch.sell;
   if(hit) sc += 35;
   if(u.choch.majorC) sc += 20;
   if(u.choch.minorC) sc += 8;
   if(u.choch.internalC) sc += 8;
   if(u.choch.externalC) sc += 10;
   sc += u.choch.confidence / 5;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentLiquidity(const UltraSnap &u, const bool buySide)
{
   int sc = 10;
   if(buySide)
   {
      if(u.liq.sweepBuy) sc += 30; if(u.liq.stopHuntBuy) sc += 15;
      if(u.liq.grabBuy) sc += 15; if(u.liq.equalLows) sc += 10;
      if(u.liq.confirmedBuy) sc += 10;
   }
   else
   {
      if(u.liq.sweepSell) sc += 30; if(u.liq.stopHuntSell) sc += 15;
      if(u.liq.grabSell) sc += 15; if(u.liq.equalHighs) sc += 10;
      if(u.liq.confirmedSell) sc += 10;
   }
   sc += (int)(u.liq.quality / 4.0);
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentFib(const UltraSnap &u, const bool buySide)
{
   int sc = 15;
   if(buySide && u.fib.atBuyZone) sc += 35;
   if(!buySide && u.fib.atSellZone) sc += 35;
   if(u.fib.impulseOK) sc += 15;
   sc += u.fib.quality / 4;
   sc += u.fib.confluence / 5;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentInst(const UltraSnap &u, const bool buySide)
{
   int sc = 10;
   if(buySide)
   {
      if(u.ict.obBuy) sc += 18; if(u.ict.breakerBuy) sc += 12;
      if(u.ict.fvgBuy) sc += 15; if(u.ict.instZoneBuy) sc += 18;
      if(u.ict.inDiscount) sc += 12; if(u.ict.dispBuy) sc += 15;
   }
   else
   {
      if(u.ict.obSell) sc += 18; if(u.ict.breakerSell) sc += 12;
      if(u.ict.fvgSell) sc += 15; if(u.ict.instZoneSell) sc += 18;
      if(u.ict.inPremium) sc += 12; if(u.ict.dispSell) sc += 15;
   }
   if(u.ict.smConfluence) sc += 10;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentMom(const UltraSnap &u, const bool buySide)
{
   int sc = 15;
   if(buySide){ if(u.mom.momBuy) sc += 25; if(u.ind.smi > 0) sc += 15; }
   else { if(u.mom.momSell) sc += 25; if(u.ind.smi < 0) sc += 15; }
   if(u.mom.impulse) sc += 20;
   sc += u.mom.strength / 4;
   sc += u.mom.acceleration / 5;
   if(u.mom.weakness) sc -= 12;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentVol(const UltraSnap &u)
{
   int sc = 40;
   if(u.vol.expansion) sc += 25;
   if(u.vol.compression) sc += 10;
   sc += (int)MathMin(25.0, u.vol.relative * 20.0);
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentRegime(const UltraSnap &u)
{
   int sc = 40;
   if(u.regime == UREG_STRONG_TREND || u.regime == UREG_HEALTHY_TREND) sc = 80;
   else if(u.regime == UREG_BREAKOUT || u.regime == UREG_EXPANSION) sc = 70;
   else if(u.regime == UREG_WEAK_TREND) sc = 60;
   else if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) sc = 45;
   else if(u.regime == UREG_REVERSAL || u.regime == UREG_EXHAUSTION) sc = 35;
   return sc;
}

int UltraUSM2_ComponentSession(const UltraSnap &u)
{
   int sc = 35;
   if(u.ctx.sessionLiquidity) sc += 25;
   if(u.ctx.killZone) sc += 15;
   if(u.ctx.overlap) sc += 15;
   sc += u.ctx.sessionQuality / 4;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentNews(const UltraSnap &u)
{
   int sc = 55;
   // context only — never hard-block; mild adjustment
   if(u.ctx.newsVol) sc += 10;
   if(u.ctx.duringNews) sc -= 8;
   if(u.ctx.spreadPts > 30) sc -= 10;
   return UltraUSM2_Clamp(sc);
}

int UltraUSM2_ComponentRisk(const UltraSnap &u)
{
   int sc = 100 - UltraUSM2_Clamp(u.score.riskProb);
   if(sc < 20) sc = 20;
   return sc;
}

int UltraUSM2_ComponentExec(const string s)
{
   string why = "";
   if(UltraDefense_Line7_Execution(s, why)) return 85;
   return 25;
}

void UltraUSM2_Score(const string s, UltraSnap &u, const bool buySide, UltraUSM2Scores &out)
{
   UltraDynWeights w;
   UltraWeights_FromRegime(u.regime, w);

   out.structure = UltraWeights_Apply(UltraUSM2_ComponentStructure(u, buySide), w.structure);
   out.trend = UltraWeights_Apply(UltraUSM2_ComponentTrend(u, buySide), w.trend);
   out.bos = UltraWeights_Apply(UltraUSM2_ComponentBOS(u, buySide), w.bos);
   out.choch = UltraWeights_Apply(UltraUSM2_ComponentCHoCH(u, buySide), w.choch);
   out.liquidity = UltraWeights_Apply(UltraUSM2_ComponentLiquidity(u, buySide), w.liquidity);
   out.fibonacci = UltraWeights_Apply(UltraUSM2_ComponentFib(u, buySide), w.fibonacci);
   out.institutional = UltraWeights_Apply(UltraUSM2_ComponentInst(u, buySide), w.institutional);
   out.momentum = UltraWeights_Apply(UltraUSM2_ComponentMom(u, buySide), w.momentum);
   out.volatility = UltraWeights_Apply(UltraUSM2_ComponentVol(u), w.volatility);
   out.regime = UltraWeights_Apply(UltraUSM2_ComponentRegime(u), w.regime);
   out.session = UltraWeights_Apply(UltraUSM2_ComponentSession(u), w.session);
   out.news = UltraWeights_Apply(UltraUSM2_ComponentNews(u), w.news);

   // precision/probability from existing engines, then weight
   int prec = UltraPrecisionScore(u);
   int confLegacy = buySide ? UltraConfluenceBuy(u) : UltraConfluenceSell(u);
   int prob = UltraProbabilityScore(u, confLegacy, prec);
   out.precision = UltraWeights_Apply(prec, w.precision);
   out.probability = UltraWeights_Apply(prob, w.probability);
   out.risk = UltraWeights_Apply(UltraUSM2_ComponentRisk(u), w.risk);
   out.execution = UltraWeights_Apply(UltraUSM2_ComponentExec(s), w.execution);

   // Weighted blend → confidence
   double conf =
      out.structure * 0.10 + out.trend * 0.12 + out.bos * 0.10 + out.choch * 0.08 +
      out.liquidity * 0.10 + out.fibonacci * 0.06 + out.institutional * 0.08 +
      out.momentum * 0.08 + out.volatility * 0.04 + out.regime * 0.04 +
      out.session * 0.03 + out.news * 0.02 + out.precision * 0.07 + out.probability * 0.08;
   out.confidence = UltraUSM2_Clamp((int)MathRound(conf));

   double trade =
      out.confidence * 0.55 + out.precision * 0.20 + out.probability * 0.15 +
      out.execution * 0.05 + out.risk * 0.05;
   out.tradeScore = UltraUSM2_Clamp((int)MathRound(trade));
   out.grade = UltraUSM2_Grade((double)out.tradeScore);

   // Write back into snap scores (USM2 owns final confidence when enabled)
   u.score.confluence = out.confidence;
   u.score.confidence = out.confidence;
   u.score.precision = out.precision;
   u.score.probability = out.probability;
   u.score.successProb = out.probability;
   u.score.riskProb = UltraUSM2_Clamp(100 - out.probability);
}

string UltraUSM2_LogLine(const UltraUSM2Scores &o)
{
   string t = "USM2 conf=";
   t += IntegerToString(o.confidence);
   t += " trade=";
   t += IntegerToString(o.tradeScore);
   t += " grade=";
   t += o.grade;
   t += " ST="; t += IntegerToString(o.structure);
   t += " TR="; t += IntegerToString(o.trend);
   t += " BOS="; t += IntegerToString(o.bos);
   t += " CH="; t += IntegerToString(o.choch);
   t += " LQ="; t += IntegerToString(o.liquidity);
   return t;
}

UltraUSM2Scores g_UltraUSM2Last;

#endif
