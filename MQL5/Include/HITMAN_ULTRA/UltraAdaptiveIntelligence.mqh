#ifndef HITMAN_ULTRA_ADAPTIVE_INTELLIGENCE_MQH
#define HITMAN_ULTRA_ADAPTIVE_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA ADAPTIVE INTELLIGENCE ENGINE ∞ (Phase 17)      |
//| Continuously optimizes DECISION QUALITY — never the strategy.    |
//| Soft refinements only · statistical learning · no hidden params  |
//| Path: Confidence → Exec Quality → Adaptive → Mission → Execute   |
//+------------------------------------------------------------------+

#define ULTRA_ADAPT_OPEN_MAX   32
#define ULTRA_ADAPT_CLOSED_MAX 128
#define ULTRA_ADAPT_BUCKET_MAX 16

//--------------------------------------------------------------------//
// AUDIT DIMENSIONS (0..100 quality scores)                            //
//--------------------------------------------------------------------//
struct UltraAdaptiveAudit
{
   int regime;
   int trendQuality;
   int trendStrength;
   int trendSpeed;
   int momentumQuality;
   int liquidityQuality;
   int volatilityQuality;
   int executionQuality;
   int sessionQuality;
   int eventQuality;
   int symbolBehaviour;
   int timeframeBehaviour;
   int tradeConfidence;
   int riskQuality;
   int composite;          // blended 0..100
   int confBias;           // soft confidence delta (−Max..+Max)
   double riskScale;       // soft lot risk multiplier (clamped)
   double targetScale;     // soft TP distance scale (clamped)
   int slipBiasPts;        // soft slippage deviation delta
   int monitorMsBias;      // soft monitor interval delta (negative = tighter)
   string summary;
   datetime ts;
};

struct UltraAdaptiveOpenRec
{
   bool     active;
   ulong    ticket;
   string   symbol;
   bool     isBuy;
   string   tag;
   string   thesis;
   string   entryReason;
   string   regime;
   string   trend;
   string   session;
   string   newsEvent;
   double   spread;
   double   slipProxy;
   double   execSpeed;
   int      confidence;
   double   sl;
   double   tp1;
   double   tp2;
   double   tp3;
   datetime openTime;
   long     openMs;
};

struct UltraAdaptiveClosedRec
{
   ulong    ticket;
   string   symbol;
   bool     isBuy;
   string   tag;
   string   thesis;
   string   entryReason;
   string   exitReason;
   string   regime;
   string   trend;
   string   session;
   string   newsEvent;
   string   timeframe;
   double   spread;
   double   slipProxy;
   double   execSpeed;
   int      holdingSec;
   int      confidence;
   double   sl;
   double   tp1;
   double   tp2;
   double   tp3;
   double   profit;
   bool     won;
   datetime openTime;
   datetime closeTime;
};

struct UltraAdaptiveBucket
{
   string key;
   int    trades;
   int    wins;
   double profitSum;
   double lossSum;
};

struct UltraAdaptiveReview
{
   int    trades;
   int    wins;
   int    losses;
   double winRate;
   double avgWin;
   double avgLoss;
   double riskReward;
   double profitFactor;
   double expectancy;
   double maxDrawdown;
   double grossProfit;
   double grossLoss;
   double equityPeak;
   double equityCurve;
   string bestSession;
   string bestSymbol;
   string bestTimeframe;
   string worstNews;
   datetime lastUpdate;
};

struct UltraAdaptiveState
{
   UltraAdaptiveAudit  audit;
   UltraAdaptiveReview review;
   UltraAdaptiveOpenRec openRec[ULTRA_ADAPT_OPEN_MAX];
   UltraAdaptiveClosedRec closed[ULTRA_ADAPT_CLOSED_MAX];
   UltraAdaptiveBucket sessBucket[ULTRA_ADAPT_BUCKET_MAX];
   UltraAdaptiveBucket newsBucket[ULTRA_ADAPT_BUCKET_MAX];
   UltraAdaptiveBucket symBucket[ULTRA_ADAPT_BUCKET_MAX];
   UltraAdaptiveBucket tfBucket[ULTRA_ADAPT_BUCKET_MAX];
   UltraAdaptiveBucket stratBucket[ULTRA_ADAPT_BUCKET_MAX];
   int    sessBucketN;
   int    newsBucketN;
   int    symBucketN;
   int    tfBucketN;
   int    stratBucketN;
   int    openN;
   int    closedN;
   int    closedHead;       // ring write index
   ulong  applyCount;
   ulong  recordOpenCount;
   ulong  recordCloseCount;
   string lastWhy;
   bool   booted;
};

UltraAdaptiveState g_UltraAdapt;

//--------------------------------------------------------------------//
int UltraAdapt_ClampI(const int v, const int lo, const int hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

double UltraAdapt_ClampD(const double v, const double lo, const double hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

string UltraAdapt_RegimeName(const ENUM_ULTRA_REGIME r)
{
   if(r == UREG_STRONG_TREND || r == UREG_HEALTHY_TREND) return "TRENDING";
   if(r == UREG_WEAK_TREND) return "WEAK_TREND";
   if(r == UREG_RANGE) return "RANGING";
   if(r == UREG_COMPRESSION) return "COMPRESSION";
   if(r == UREG_EXPANSION || r == UREG_BREAKOUT) return "EXPANSION";
   if(r == UREG_REVERSAL || r == UREG_EXHAUSTION) return "REVERSAL";
   if(r == UREG_ACCUMULATION) return "ACCUMULATION";
   if(r == UREG_DISTRIBUTION) return "DISTRIBUTION";
   return "UNKNOWN";
}

string UltraAdapt_TrendName(const UltraSnap &u)
{
   if(u.trend.bull && u.trend.htfBull) return "BULL_ALIGNED";
   if(u.trend.bear && u.trend.htfBear) return "BEAR_ALIGNED";
   if(u.trend.bull) return "BULL";
   if(u.trend.bear) return "BEAR";
   return "NEUTRAL";
}

string UltraAdapt_TFName()
{
   ENUM_TIMEFRAMES tf = UltraETF();
   return EnumToString(tf);
}

//--------------------------------------------------------------------//
// BUCKET HELPERS — statistical only (never mutates strategy params)   //
// kind: 0=session 1=news 2=symbol 3=tf 4=strategy                      //
//--------------------------------------------------------------------//
int UltraAdapt_BucketFindKind(const int kind, const string key)
{
   int n = 0;
   if(kind == 0) n = g_UltraAdapt.sessBucketN;
   else if(kind == 1) n = g_UltraAdapt.newsBucketN;
   else if(kind == 2) n = g_UltraAdapt.symBucketN;
   else if(kind == 3) n = g_UltraAdapt.tfBucketN;
   else if(kind == 4) n = g_UltraAdapt.stratBucketN;
   for(int i = 0; i < n; i++)
   {
      string k = "";
      if(kind == 0) k = g_UltraAdapt.sessBucket[i].key;
      else if(kind == 1) k = g_UltraAdapt.newsBucket[i].key;
      else if(kind == 2) k = g_UltraAdapt.symBucket[i].key;
      else if(kind == 3) k = g_UltraAdapt.tfBucket[i].key;
      else k = g_UltraAdapt.stratBucket[i].key;
      if(k == key) return i;
   }
   return -1;
}

void UltraAdapt_BucketNoteKind(const int kind, const string key,
                               const bool won, const double profit)
{
   if(StringLen(key) == 0) return;
   int idx = UltraAdapt_BucketFindKind(kind, key);
   if(idx < 0)
   {
      int used = 0;
      if(kind == 0) used = g_UltraAdapt.sessBucketN;
      else if(kind == 1) used = g_UltraAdapt.newsBucketN;
      else if(kind == 2) used = g_UltraAdapt.symBucketN;
      else if(kind == 3) used = g_UltraAdapt.tfBucketN;
      else used = g_UltraAdapt.stratBucketN;
      if(used >= ULTRA_ADAPT_BUCKET_MAX) return;
      idx = used;
      if(kind == 0)
      {
         g_UltraAdapt.sessBucket[idx].key = key;
         g_UltraAdapt.sessBucket[idx].trades = 0;
         g_UltraAdapt.sessBucket[idx].wins = 0;
         g_UltraAdapt.sessBucket[idx].profitSum = 0.0;
         g_UltraAdapt.sessBucket[idx].lossSum = 0.0;
         g_UltraAdapt.sessBucketN++;
      }
      else if(kind == 1)
      {
         g_UltraAdapt.newsBucket[idx].key = key;
         g_UltraAdapt.newsBucket[idx].trades = 0;
         g_UltraAdapt.newsBucket[idx].wins = 0;
         g_UltraAdapt.newsBucket[idx].profitSum = 0.0;
         g_UltraAdapt.newsBucket[idx].lossSum = 0.0;
         g_UltraAdapt.newsBucketN++;
      }
      else if(kind == 2)
      {
         g_UltraAdapt.symBucket[idx].key = key;
         g_UltraAdapt.symBucket[idx].trades = 0;
         g_UltraAdapt.symBucket[idx].wins = 0;
         g_UltraAdapt.symBucket[idx].profitSum = 0.0;
         g_UltraAdapt.symBucket[idx].lossSum = 0.0;
         g_UltraAdapt.symBucketN++;
      }
      else if(kind == 3)
      {
         g_UltraAdapt.tfBucket[idx].key = key;
         g_UltraAdapt.tfBucket[idx].trades = 0;
         g_UltraAdapt.tfBucket[idx].wins = 0;
         g_UltraAdapt.tfBucket[idx].profitSum = 0.0;
         g_UltraAdapt.tfBucket[idx].lossSum = 0.0;
         g_UltraAdapt.tfBucketN++;
      }
      else
      {
         g_UltraAdapt.stratBucket[idx].key = key;
         g_UltraAdapt.stratBucket[idx].trades = 0;
         g_UltraAdapt.stratBucket[idx].wins = 0;
         g_UltraAdapt.stratBucket[idx].profitSum = 0.0;
         g_UltraAdapt.stratBucket[idx].lossSum = 0.0;
         g_UltraAdapt.stratBucketN++;
      }
   }

   if(kind == 0)
   {
      g_UltraAdapt.sessBucket[idx].trades++;
      if(won) { g_UltraAdapt.sessBucket[idx].wins++; g_UltraAdapt.sessBucket[idx].profitSum += profit; }
      else g_UltraAdapt.sessBucket[idx].lossSum += MathAbs(profit);
   }
   else if(kind == 1)
   {
      g_UltraAdapt.newsBucket[idx].trades++;
      if(won) { g_UltraAdapt.newsBucket[idx].wins++; g_UltraAdapt.newsBucket[idx].profitSum += profit; }
      else g_UltraAdapt.newsBucket[idx].lossSum += MathAbs(profit);
   }
   else if(kind == 2)
   {
      g_UltraAdapt.symBucket[idx].trades++;
      if(won) { g_UltraAdapt.symBucket[idx].wins++; g_UltraAdapt.symBucket[idx].profitSum += profit; }
      else g_UltraAdapt.symBucket[idx].lossSum += MathAbs(profit);
   }
   else if(kind == 3)
   {
      g_UltraAdapt.tfBucket[idx].trades++;
      if(won) { g_UltraAdapt.tfBucket[idx].wins++; g_UltraAdapt.tfBucket[idx].profitSum += profit; }
      else g_UltraAdapt.tfBucket[idx].lossSum += MathAbs(profit);
   }
   else
   {
      g_UltraAdapt.stratBucket[idx].trades++;
      if(won) { g_UltraAdapt.stratBucket[idx].wins++; g_UltraAdapt.stratBucket[idx].profitSum += profit; }
      else g_UltraAdapt.stratBucket[idx].lossSum += MathAbs(profit);
   }
}

string UltraAdapt_BucketBestKind(const int kind)
{
   string best = "-";
   double bestWR = -1.0;
   int n = 0;
   if(kind == 0) n = g_UltraAdapt.sessBucketN;
   else if(kind == 1) n = g_UltraAdapt.newsBucketN;
   else if(kind == 2) n = g_UltraAdapt.symBucketN;
   else if(kind == 3) n = g_UltraAdapt.tfBucketN;
   else n = g_UltraAdapt.stratBucketN;
   for(int i = 0; i < n; i++)
   {
      int tr = 0, wn = 0; string key = "";
      if(kind == 0) { tr = g_UltraAdapt.sessBucket[i].trades; wn = g_UltraAdapt.sessBucket[i].wins; key = g_UltraAdapt.sessBucket[i].key; }
      else if(kind == 1) { tr = g_UltraAdapt.newsBucket[i].trades; wn = g_UltraAdapt.newsBucket[i].wins; key = g_UltraAdapt.newsBucket[i].key; }
      else if(kind == 2) { tr = g_UltraAdapt.symBucket[i].trades; wn = g_UltraAdapt.symBucket[i].wins; key = g_UltraAdapt.symBucket[i].key; }
      else if(kind == 3) { tr = g_UltraAdapt.tfBucket[i].trades; wn = g_UltraAdapt.tfBucket[i].wins; key = g_UltraAdapt.tfBucket[i].key; }
      else { tr = g_UltraAdapt.stratBucket[i].trades; wn = g_UltraAdapt.stratBucket[i].wins; key = g_UltraAdapt.stratBucket[i].key; }
      if(tr < 3) continue;
      double wr = 100.0 * (double)wn / (double)tr;
      if(wr > bestWR) { bestWR = wr; best = key; }
   }
   return best;
}

string UltraAdapt_BucketWorstKind(const int kind)
{
   string worst = "-";
   double worstWR = 101.0;
   int n = 0;
   if(kind == 0) n = g_UltraAdapt.sessBucketN;
   else if(kind == 1) n = g_UltraAdapt.newsBucketN;
   else if(kind == 2) n = g_UltraAdapt.symBucketN;
   else if(kind == 3) n = g_UltraAdapt.tfBucketN;
   else n = g_UltraAdapt.stratBucketN;
   for(int i = 0; i < n; i++)
   {
      int tr = 0, wn = 0; string key = "";
      if(kind == 0) { tr = g_UltraAdapt.sessBucket[i].trades; wn = g_UltraAdapt.sessBucket[i].wins; key = g_UltraAdapt.sessBucket[i].key; }
      else if(kind == 1) { tr = g_UltraAdapt.newsBucket[i].trades; wn = g_UltraAdapt.newsBucket[i].wins; key = g_UltraAdapt.newsBucket[i].key; }
      else if(kind == 2) { tr = g_UltraAdapt.symBucket[i].trades; wn = g_UltraAdapt.symBucket[i].wins; key = g_UltraAdapt.symBucket[i].key; }
      else if(kind == 3) { tr = g_UltraAdapt.tfBucket[i].trades; wn = g_UltraAdapt.tfBucket[i].wins; key = g_UltraAdapt.tfBucket[i].key; }
      else { tr = g_UltraAdapt.stratBucket[i].trades; wn = g_UltraAdapt.stratBucket[i].wins; key = g_UltraAdapt.stratBucket[i].key; }
      if(tr < 3) continue;
      double wr = 100.0 * (double)wn / (double)tr;
      if(wr < worstWR) { worstWR = wr; worst = key; }
   }
   return worst;
}

//--------------------------------------------------------------------//
// PATTERN / SYMBOL BEHAVIOUR (from Market Memory — soft read only)    //
//--------------------------------------------------------------------//
int UltraAdapt_SymbolBehaviourScore(const string tag)
{
   int idx = UltraMemory_FindPat(tag);
   if(idx < 0) return 55; // neutral — insufficient data
   int w = g_UltraMemPat[idx].wins;
   int l = g_UltraMemPat[idx].losses;
   int n = w + l;
   if(n < 3) return 55;
   double wr = 100.0 * (double)w / (double)n;
   return UltraAdapt_ClampI((int)MathRound(wr), 0, 100);
}

int UltraAdapt_TFBehaviourScore()
{
   // Soft: use global expectancy proxy when enough trades exist
   if(g_UltraAdapt.review.trades < 5) return 55;
   double exp = g_UltraAdapt.review.expectancy;
   int sc = 55 + (int)MathRound(exp * 2.0); // mild mapping
   return UltraAdapt_ClampI(sc, 20, 90);
}

int UltraAdapt_HistSoftBias()
{
   // Statistical soft nudge from closed-trade expectancy — NEVER auto-optimizes params
   if(!UltraAdaptiveLearnEnabled) return 0;
   if(g_UltraAdapt.review.trades < UltraAdaptiveMinTradesLearn) return 0;
   int bias = 0;
   if(g_UltraAdapt.review.expectancy > 0.25 && g_UltraAdapt.review.winRate >= 55.0)
      bias += 2;
   if(g_UltraAdapt.review.expectancy < -0.10 || g_UltraAdapt.review.winRate < 40.0)
      bias -= 2;
   if(g_UltraAdapt.review.profitFactor >= 1.40) bias += 1;
   if(g_UltraAdapt.review.profitFactor > 0.0 && g_UltraAdapt.review.profitFactor < 0.90) bias -= 1;
   return UltraAdapt_ClampI(bias, -3, 3);
}

//--------------------------------------------------------------------//
// ULTRA ADAPTIVE AUDIT                                                //
//--------------------------------------------------------------------//
void UltraAdaptive_Audit(const string s, const UltraSnap &u, const UltraSignal &sig)
{
   UltraAdaptiveAudit a;
   ZeroMemory(a);
   a.ts = TimeCurrent();

   // Market Regime
   a.regime = 50;
   if(u.regime == UREG_STRONG_TREND || u.regime == UREG_HEALTHY_TREND) a.regime = 82;
   else if(u.regime == UREG_WEAK_TREND) a.regime = 60;
   else if(u.regime == UREG_RANGE) a.regime = 55;
   else if(u.regime == UREG_COMPRESSION) a.regime = 48;
   else if(u.regime == UREG_EXPANSION || u.regime == UREG_BREAKOUT) a.regime = 70;
   else if(u.regime == UREG_REVERSAL || u.regime == UREG_EXHAUSTION) a.regime = 35;
   else if(u.regime == UREG_ACCUMULATION) a.regime = 62;
   else if(u.regime == UREG_DISTRIBUTION) a.regime = 40;

   // Trend Quality / Strength / Speed
   a.trendQuality = UltraAdapt_ClampI(u.trend.persistence, 0, 100);
   if(u.trend.exhaustion) a.trendQuality = UltraAdapt_ClampI(a.trendQuality - 15, 0, 100);
   a.trendStrength = UltraAdapt_ClampI(u.trend.strength, 0, 100);
   int speed = UltraAdapt_ClampI(u.mom.acceleration, 0, 100);
   if(u.mom.impulse) speed = UltraAdapt_ClampI(speed + 15, 0, 100);
   if(u.mom.weakness) speed = UltraAdapt_ClampI(speed - 20, 0, 100);
   a.trendSpeed = speed;

   // Momentum Quality
   a.momentumQuality = UltraAdapt_ClampI(u.mom.quality, 0, 100);
   if(sig.buy && u.mom.momBuy) a.momentumQuality = UltraAdapt_ClampI(a.momentumQuality + 8, 0, 100);
   if(sig.sell && u.mom.momSell) a.momentumQuality = UltraAdapt_ClampI(a.momentumQuality + 8, 0, 100);

   // Liquidity Quality
   a.liquidityQuality = UltraAdapt_ClampI((int)MathRound(u.liq.quality), 0, 100);
   if(u.ctx.sessionLiquidity) a.liquidityQuality = UltraAdapt_ClampI(a.liquidityQuality + 10, 0, 100);
   if(u.ctx.sessionLiqScore > 0)
      a.liquidityQuality = UltraAdapt_ClampI((a.liquidityQuality + u.ctx.sessionLiqScore) / 2, 0, 100);

   // Volatility Quality (healthy expansion ≠ chaos)
   a.volatilityQuality = 55;
   if(u.vol.compression) a.volatilityQuality = 45;
   if(u.vol.expansion && u.vol.relative >= 1.0 && u.vol.relative <= 2.2) a.volatilityQuality = 75;
   if(u.vol.expansion && u.vol.relative > 2.8) a.volatilityQuality = 35;
   if(u.vol.relative > 0.0 && u.vol.relative < 0.55) a.volatilityQuality = 40;

   // Execution Quality
   a.executionQuality = UltraAdapt_ClampI(u.ctx.execQuality, 0, 100);
   if(a.executionQuality <= 0)
      a.executionQuality = (u.diag.brokerOK && u.diag.connectionOK) ? 70 : 30;
   if(u.ctx.spreadPts > 0.0 && u.ctx.spreadPts > UltraEventSpreadWarnPts)
      a.executionQuality = UltraAdapt_ClampI(a.executionQuality - 8, 0, 100);

   // Session Quality
   a.sessionQuality = UltraAdapt_ClampI(u.ctx.sessionQuality, 0, 100);
   if(a.sessionQuality <= 0) a.sessionQuality = UltraAdapt_ClampI(u.ctx.sessionPriority * 18, 0, 100);

   // Event Quality (context — never forces)
   a.eventQuality = 60;
   if(u.ctx.duringNews && u.ctx.eventImpact >= 2) a.eventQuality = 45;
   else if(u.ctx.beforeNews && u.ctx.eventImpact >= 2) a.eventQuality = 50;
   else if(u.ctx.afterNews) a.eventQuality = 55;
   if(u.ctx.eventConfidence > 0)
      a.eventQuality = UltraAdapt_ClampI((a.eventQuality + u.ctx.eventConfidence) / 2, 0, 100);
   if(UltraNewsExec_IsNewsMode()) a.eventQuality = UltraAdapt_ClampI(a.eventQuality - 5, 0, 100);

   // Symbol / Timeframe behaviour (statistical)
   string tag = sig.tag;
   if(StringLen(tag) == 0) tag = g_UltraLastSignal.tag;
   a.symbolBehaviour = UltraAdapt_SymbolBehaviourScore(tag);
   a.timeframeBehaviour = UltraAdapt_TFBehaviourScore();

   // Trade Confidence (current USM2)
   a.tradeConfidence = UltraAdapt_ClampI(u.score.confidence, 0, 100);

   // Risk Quality
   a.riskQuality = UltraAdapt_ClampI(100 - u.score.riskProb, 0, 100);
   if(u.score.riskProb >= 70) a.riskQuality = UltraAdapt_ClampI(a.riskQuality - 15, 0, 100);

   // Composite (decision-quality blend — not a new strategy score)
   double comp =
      a.regime * 0.06 + a.trendQuality * 0.10 + a.trendStrength * 0.10 + a.trendSpeed * 0.06 +
      a.momentumQuality * 0.08 + a.liquidityQuality * 0.08 + a.volatilityQuality * 0.06 +
      a.executionQuality * 0.10 + a.sessionQuality * 0.06 + a.eventQuality * 0.04 +
      a.symbolBehaviour * 0.06 + a.timeframeBehaviour * 0.04 +
      a.tradeConfidence * 0.10 + a.riskQuality * 0.06;
   a.composite = UltraAdapt_ClampI((int)MathRound(comp), 0, 100);

   // Soft confidence bias from decision quality (never changes strategy tag)
   int bias = 0;
   if(UltraAdaptiveConfEnabled)
   {
      if(a.composite >= 78) bias += 4;
      else if(a.composite >= 68) bias += 2;
      else if(a.composite <= 35) bias -= 4;
      else if(a.composite <= 48) bias -= 2;

      if(a.trendQuality >= 70 && a.trendStrength >= 65) bias += 2;
      if(a.executionQuality < 40) bias -= 2;
      if(a.riskQuality < 35) bias -= 2;
      if(a.liquidityQuality < 35) bias -= 1;
      if(a.volatilityQuality < 35) bias -= 1;
      bias += UltraAdapt_HistSoftBias();
      bias = UltraAdapt_ClampI(bias, -UltraAdaptiveMaxConfPenalty, UltraAdaptiveMaxConfBoost);
   }
   a.confBias = bias;

   // Soft risk scale
   a.riskScale = 1.0;
   if(UltraAdaptiveRiskEnabled)
   {
      if(a.composite >= 75 && a.riskQuality >= 60) a.riskScale = 1.08;
      else if(a.composite <= 40 || a.riskQuality < 35) a.riskScale = 0.88;
      else if(a.executionQuality < 40) a.riskScale = 0.92;
      a.riskScale = UltraAdapt_ClampD(a.riskScale, UltraAdaptiveRiskMinScale, UltraAdaptiveRiskMaxScale);
   }

   // Soft target scale (TP stretch / tighten — SL unchanged by caller)
   a.targetScale = 1.0;
   if(UltraAdaptiveTargetEnabled)
   {
      if(a.trendStrength >= 70 && a.momentumQuality >= 65 && a.composite >= 70)
         a.targetScale = 1.08;
      else if(a.volatilityQuality < 40 || a.composite < 45)
         a.targetScale = 0.92;
      a.targetScale = UltraAdapt_ClampD(a.targetScale, UltraAdaptiveTargetMinScale, UltraAdaptiveTargetMaxScale);
   }

   // Soft execution slip bias
   a.slipBiasPts = 0;
   if(UltraAdaptiveExecEnabled)
   {
      if(a.executionQuality < 40 || UltraNewsExec_IsNewsMode()) a.slipBiasPts = UltraAdaptiveSlipExtraPts;
      else if(a.executionQuality >= 80 && a.volatilityQuality >= 60) a.slipBiasPts = -UltraAdaptiveSlipTightenPts;
   }

   // Soft monitor cadence (tighter when quality weak / news)
   a.monitorMsBias = 0;
   if(UltraAdaptiveMonitorEnabled)
   {
      if(a.composite < 50 || UltraNewsExec_IsNewsMode() || a.volatilityQuality < 40)
         a.monitorMsBias = -UltraAdaptiveMonitorTightenMs;
      else if(a.composite >= 80)
         a.monitorMsBias = UltraAdaptiveMonitorRelaxMs;
   }

   a.summary = "ADAPT Q=";
   a.summary += IntegerToString(a.composite);
   a.summary += " bias=";
   a.summary += IntegerToString(a.confBias);
   a.summary += " risk×";
   a.summary += DoubleToString(a.riskScale, 2);
   a.summary += " tgt×";
   a.summary += DoubleToString(a.targetScale, 2);

   g_UltraAdapt.audit = a;
}

//--------------------------------------------------------------------//
// APPLY — soft decision intelligence (never blocks, never forces)     //
//--------------------------------------------------------------------//
bool UltraAdaptive_Apply(const string s, UltraSnap &u, UltraSignal &sig, string &note)
{
   note = "";
   if(!UltraAdaptiveEnabled)
   {
      note = "adaptive off";
      return true; // never blocks
   }

   // LOCK: never mutate strategy selection
   string lockedTag = sig.tag;
   bool lockedBuy = sig.buy;
   bool lockedSell = sig.sell;

   UltraAdaptive_Audit(s, u, sig);

   // Soft confidence refinement
   if(UltraAdaptiveConfEnabled && g_UltraAdapt.audit.confBias != 0)
   {
      int before = u.score.confidence;
      int after = UltraAdapt_ClampI(before + g_UltraAdapt.audit.confBias, 0, 100);
      u.score.confidence = after;
      u.score.confluence = after;
      u.score.adaptiveBias = g_UltraAdapt.audit.confBias;
      if(UltraUSM2Enabled)
      {
         g_UltraUSM2Last.confidence = after;
         // tradeScore soft nudge only — grade may update
         int ts = UltraAdapt_ClampI(g_UltraUSM2Last.tradeScore + (g_UltraAdapt.audit.confBias / 2), 0, 100);
         g_UltraUSM2Last.tradeScore = ts;
         g_UltraUSM2Last.grade = UltraUSM2_Grade((double)ts);
      }
   }
   else
      u.score.adaptiveBias = 0;

   // Integrity: strategy untouched
   sig.tag = lockedTag;
   sig.buy = lockedBuy;
   sig.sell = lockedSell;

   g_UltraAdapt.applyCount++;
   g_UltraAdapt.lastWhy = g_UltraAdapt.audit.summary;
   note = g_UltraAdapt.audit.summary;

   if(UltraAdaptiveLog)
      UltraLog("ADAPTIVE ∞ " + note +
               " tag=" + lockedTag +
               " conf=" + IntegerToString(u.score.confidence) +
               " | strategy LOCKED");

   return true; // NEVER hard-rejects
}

//--------------------------------------------------------------------//
// SOFT SCALE GETTERS (used by risk / exec / targets / monitor)        //
//--------------------------------------------------------------------//
double UltraAdaptive_RiskScale()
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveRiskEnabled) return 1.0;
   double sc = g_UltraAdapt.audit.riskScale;
   if(sc <= 0.0) sc = 1.0;
   return UltraAdapt_ClampD(sc, UltraAdaptiveRiskMinScale, UltraAdaptiveRiskMaxScale);
}

double UltraAdaptive_TargetScale()
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveTargetEnabled) return 1.0;
   double sc = g_UltraAdapt.audit.targetScale;
   if(sc <= 0.0) sc = 1.0;
   return UltraAdapt_ClampD(sc, UltraAdaptiveTargetMinScale, UltraAdaptiveTargetMaxScale);
}

int UltraAdaptive_SlipBiasPts()
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveExecEnabled) return 0;
   return g_UltraAdapt.audit.slipBiasPts;
}

int UltraAdaptive_MonitorMs(const int baseMs)
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveMonitorEnabled) return baseMs;
   int ms = baseMs + g_UltraAdapt.audit.monitorMsBias;
   if(ms < 25) ms = 25;
   return ms;
}

bool UltraAdaptive_TightenMonitor()
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveMonitorEnabled) return false;
   return (g_UltraAdapt.audit.monitorMsBias < 0);
}

//--------------------------------------------------------------------//
// SOFT TARGET APPLY — scale TP distances; never invents random TPs    //
//--------------------------------------------------------------------//
void UltraAdaptive_ApplyTargetBias(const bool isBuy, const double entry,
                                   double &tp1, double &tp2, double &tp3,
                                   double &tp1Dist, double &tp2Dist, double &tp3Dist)
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveTargetEnabled) return;
   double sc = UltraAdaptive_TargetScale();
   if(MathAbs(sc - 1.0) < 0.001) return;
   if(entry <= 0.0) return;

   tp1Dist *= sc;
   tp2Dist *= sc;
   tp3Dist *= sc;
   if(isBuy)
   {
      tp1 = entry + tp1Dist;
      tp2 = entry + tp2Dist;
      tp3 = entry + tp3Dist;
   }
   else
   {
      tp1 = entry - tp1Dist;
      tp2 = entry - tp2Dist;
      tp3 = entry - tp3Dist;
   }
   if(UltraAdaptiveLog)
      UltraLog("ADAPTIVE TARGET soft×" + DoubleToString(sc, 2) + " (SL unchanged)");
}

//--------------------------------------------------------------------//
// PERFORMANCE ANALYTICS — record open / close                         //
//--------------------------------------------------------------------//
int UltraAdapt_FindOpen(const ulong ticket)
{
   for(int i = 0; i < ULTRA_ADAPT_OPEN_MAX; i++)
      if(g_UltraAdapt.openRec[i].active && g_UltraAdapt.openRec[i].ticket == ticket)
         return i;
   return -1;
}

int UltraAdapt_AllocOpen()
{
   for(int i = 0; i < ULTRA_ADAPT_OPEN_MAX; i++)
      if(!g_UltraAdapt.openRec[i].active) return i;
   return 0; // overwrite oldest slot if saturated
}

void UltraAdaptive_RecordOpen(const ulong ticket, const string s, const bool isBuy, const string tag)
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveAnalyticsEnabled) return;
   if(ticket == 0) return;

   int idx = UltraAdapt_FindOpen(ticket);
   if(idx < 0) idx = UltraAdapt_AllocOpen();

   UltraSnap u = g_UltraLastSnap;
   UltraAdaptiveOpenRec r;
   ZeroMemory(r);
   r.active = true;
   r.ticket = ticket;
   r.symbol = s;
   r.isBuy = isBuy;
   r.tag = tag;
   r.thesis = g_UltraMissionLast.thesis;
   if(StringLen(r.thesis) == 0) r.thesis = tag;
   r.entryReason = g_UltraLastSignal.reason;
   if(StringLen(r.entryReason) == 0) r.entryReason = tag;
   r.regime = UltraAdapt_RegimeName(u.regime);
   r.trend = UltraAdapt_TrendName(u);
   r.session = u.ctx.session;
   r.newsEvent = u.ctx.eventClass;
   if(StringLen(r.newsEvent) == 0) r.newsEvent = "NONE";
   r.spread = u.ctx.spreadPts;
   r.slipProxy = u.ctx.slipProxy;
   r.execSpeed = u.ctx.tickSpeed;
   r.confidence = u.score.confidence;
   if(g_UltraTargetLast.valid)
   {
      r.sl = g_UltraTargetLast.sl;
      r.tp1 = g_UltraTargetLast.tp1;
      r.tp2 = g_UltraTargetLast.tp2;
      r.tp3 = g_UltraTargetLast.tp3;
   }
   r.openTime = TimeCurrent();
   r.openMs = (long)GetTickCount();
   g_UltraAdapt.openRec[idx] = r;
   g_UltraAdapt.recordOpenCount++;

   if(UltraAdaptiveLog)
      UltraLog("ADAPTIVE REC OPEN ticket=" + IntegerToString((int)ticket) +
               " tag=" + tag +
               " regime=" + r.regime +
               " sess=" + r.session +
               " conf=" + IntegerToString(r.confidence));
}

void UltraAdaptive_RecomputeReview()
{
   UltraAdaptiveReview rv;
   ZeroMemory(rv);
   rv.bestSession = "-";
   rv.bestSymbol = "-";
   rv.bestTimeframe = "-";
   rv.worstNews = "-";

   double peak = 0.0;
   double curve = 0.0;
   double maxDD = 0.0;
   double sumWin = 0.0;
   double sumLoss = 0.0;

   for(int i = 0; i < g_UltraAdapt.closedN && i < ULTRA_ADAPT_CLOSED_MAX; i++)
   {
      UltraAdaptiveClosedRec c = g_UltraAdapt.closed[i];
      if(c.ticket == 0 && c.closeTime == 0) continue;
      rv.trades++;
      curve += c.profit;
      if(curve > peak) peak = curve;
      double dd = peak - curve;
      if(dd > maxDD) maxDD = dd;

      if(c.won)
      {
         rv.wins++;
         sumWin += c.profit;
         rv.grossProfit += c.profit;
      }
      else
      {
         rv.losses++;
         sumLoss += MathAbs(c.profit);
         rv.grossLoss += MathAbs(c.profit);
      }
   }

   rv.equityPeak = peak;
   rv.equityCurve = curve;
   rv.maxDrawdown = maxDD;
   if(rv.trades > 0)
      rv.winRate = 100.0 * (double)rv.wins / (double)rv.trades;
   if(rv.wins > 0) rv.avgWin = sumWin / (double)rv.wins;
   if(rv.losses > 0) rv.avgLoss = sumLoss / (double)rv.losses;
   if(rv.avgLoss > 0.0) rv.riskReward = rv.avgWin / rv.avgLoss;
   if(rv.grossLoss > 0.0) rv.profitFactor = rv.grossProfit / rv.grossLoss;
   else if(rv.grossProfit > 0.0) rv.profitFactor = 99.0;
   if(rv.trades > 0)
      rv.expectancy = (rv.grossProfit - rv.grossLoss) / (double)rv.trades;

   rv.bestSession = UltraAdapt_BucketBestKind(0);
   rv.bestSymbol = UltraAdapt_BucketBestKind(2);
   rv.bestTimeframe = UltraAdapt_BucketBestKind(3);
   rv.worstNews = UltraAdapt_BucketWorstKind(1);
   rv.lastUpdate = TimeCurrent();
   g_UltraAdapt.review = rv;

   // Soft sync into UltraMemory (analytics mirror — no param mutation)
   if(UltraAdaptiveAnalyticsEnabled && rv.trades > 0)
   {
      g_UltraMem.trades = rv.trades;
      g_UltraMem.wins = rv.wins;
      g_UltraMem.profitSum = rv.grossProfit;
      g_UltraMem.lossSum = rv.grossLoss;
      g_UltraMem.winRate = rv.winRate;
      g_UltraMem.profitFactor = rv.profitFactor;
      g_UltraMem.avgRR = rv.riskReward;
      g_UltraMem.expectancy = rv.expectancy;
      g_UltraMem.lastSave = (long)TimeCurrent();
   }
}

void UltraAdaptive_RecordClose(const ulong ticket, const double profit, const string exitReason)
{
   if(!UltraAdaptiveEnabled || !UltraAdaptiveAnalyticsEnabled) return;
   if(ticket == 0) return;

   int oidx = UltraAdapt_FindOpen(ticket);
   UltraAdaptiveClosedRec c;
   ZeroMemory(c);
   c.ticket = ticket;
   c.profit = profit;
   c.won = (profit >= 0.0);
   c.closeTime = TimeCurrent();
   c.exitReason = exitReason;
   if(StringLen(c.exitReason) == 0) c.exitReason = (c.won ? "TP/MANAGE" : "SL/EXIT");
   c.timeframe = UltraAdapt_TFName();

   if(oidx >= 0)
   {
      UltraAdaptiveOpenRec o = g_UltraAdapt.openRec[oidx];
      c.symbol = o.symbol;
      c.isBuy = o.isBuy;
      c.tag = o.tag;
      c.thesis = o.thesis;
      c.entryReason = o.entryReason;
      c.regime = o.regime;
      c.trend = o.trend;
      c.session = o.session;
      c.newsEvent = o.newsEvent;
      c.spread = o.spread;
      c.slipProxy = o.slipProxy;
      c.execSpeed = o.execSpeed;
      c.confidence = o.confidence;
      c.sl = o.sl; c.tp1 = o.tp1; c.tp2 = o.tp2; c.tp3 = o.tp3;
      c.openTime = o.openTime;
      c.holdingSec = (int)(c.closeTime - o.openTime);
      if(c.holdingSec < 0) c.holdingSec = 0;
      g_UltraAdapt.openRec[oidx].active = false;
   }
   else
   {
      // Fallback from live position / last snap
      if(PositionSelectByTicket(ticket))
      {
         c.symbol = PositionGetString(POSITION_SYMBOL);
         c.isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         c.openTime = (datetime)PositionGetInteger(POSITION_TIME);
         c.holdingSec = (int)(c.closeTime - c.openTime);
      }
      c.tag = g_UltraLastSignal.tag;
      c.thesis = g_UltraMissionLast.thesis;
      c.entryReason = g_UltraLastSignal.reason;
      c.regime = UltraAdapt_RegimeName(g_UltraLastSnap.regime);
      c.trend = UltraAdapt_TrendName(g_UltraLastSnap);
      c.session = g_UltraLastSnap.ctx.session;
      c.newsEvent = g_UltraLastSnap.ctx.eventClass;
      c.confidence = g_UltraLastSnap.score.confidence;
   }

   // Ring write
   int w = g_UltraAdapt.closedHead % ULTRA_ADAPT_CLOSED_MAX;
   g_UltraAdapt.closed[w] = c;
   g_UltraAdapt.closedHead++;
   if(g_UltraAdapt.closedN < ULTRA_ADAPT_CLOSED_MAX)
      g_UltraAdapt.closedN++;

   UltraAdapt_BucketNoteKind(0, c.session, c.won, c.profit);
   UltraAdapt_BucketNoteKind(1, c.newsEvent, c.won, c.profit);
   UltraAdapt_BucketNoteKind(2, c.symbol, c.won, c.profit);
   UltraAdapt_BucketNoteKind(3, c.timeframe, c.won, c.profit);
   UltraAdapt_BucketNoteKind(4, c.tag, c.won, c.profit);

   // Pattern memory soft note (existing engine)
   UltraMemory_NotePattern(c.tag, c.confidence, c.won);

   g_UltraAdapt.recordCloseCount++;
   UltraAdaptive_RecomputeReview();

   if(UltraAdaptiveLog)
      UltraLog("ADAPTIVE REC CLOSE ticket=" + IntegerToString((int)ticket) +
               " pnl=" + DoubleToString(profit, 2) +
               " hold=" + IntegerToString(c.holdingSec) + "s" +
               " exit=" + c.exitReason +
               " | WR=" + DoubleToString(g_UltraAdapt.review.winRate, 1) +
               " PF=" + DoubleToString(g_UltraAdapt.review.profitFactor, 2) +
               " EXP=" + DoubleToString(g_UltraAdapt.review.expectancy, 2));
}

//--------------------------------------------------------------------//
void UltraAdaptive_Boot()
{
   ZeroMemory(g_UltraAdapt);
   g_UltraAdapt.audit.riskScale = 1.0;
   g_UltraAdapt.audit.targetScale = 1.0;
   g_UltraAdapt.review.bestSession = "-";
   g_UltraAdapt.review.bestSymbol = "-";
   g_UltraAdapt.review.bestTimeframe = "-";
   g_UltraAdapt.review.worstNews = "-";
   g_UltraAdapt.booted = true;
   if(UltraAdaptiveLog || UltraFoundationLogBoot)
      UltraLog("ADAPTIVE INTEL ∞ boot Enabled=" + (UltraAdaptiveEnabled ? "Y" : "N") +
               " Conf=" + (UltraAdaptiveConfEnabled ? "Y" : "N") +
               " Risk=" + (UltraAdaptiveRiskEnabled ? "Y" : "N") +
               " Exec=" + (UltraAdaptiveExecEnabled ? "Y" : "N") +
               " Target=" + (UltraAdaptiveTargetEnabled ? "Y" : "N") +
               " Analytics=" + (UltraAdaptiveAnalyticsEnabled ? "Y" : "N") +
               " Learn=STAT_ONLY BUILD=HA_ULTRA_93");
}

string UltraAdaptive_Dashboard()
{
   string t = "ADAPT: ";
   if(!UltraAdaptiveEnabled) { t += "OFF"; return t; }
   t += "Q=";
   t += IntegerToString(g_UltraAdapt.audit.composite);
   t += " bias=";
   t += IntegerToString(g_UltraAdapt.audit.confBias);
   t += " risk×";
   t += DoubleToString(UltraAdaptive_RiskScale(), 2);
   if(UltraAdaptiveAnalyticsEnabled && g_UltraAdapt.review.trades > 0)
   {
      t += " | WR=";
      t += DoubleToString(g_UltraAdapt.review.winRate, 1);
      t += "% PF=";
      t += DoubleToString(g_UltraAdapt.review.profitFactor, 2);
      t += " EXP=";
      t += DoubleToString(g_UltraAdapt.review.expectancy, 2);
      t += " DD=";
      t += DoubleToString(g_UltraAdapt.review.maxDrawdown, 1);
      t += " n=";
      t += IntegerToString(g_UltraAdapt.review.trades);
   }
   return t;
}

string UltraAdaptive_ReviewLine()
{
   UltraAdaptiveReview r = g_UltraAdapt.review;
   string t = "ADAPT REVIEW: WR=";
   t += DoubleToString(r.winRate, 1);
   t += " AW=";
   t += DoubleToString(r.avgWin, 2);
   t += " AL=";
   t += DoubleToString(r.avgLoss, 2);
   t += " RR=";
   t += DoubleToString(r.riskReward, 2);
   t += " PF=";
   t += DoubleToString(r.profitFactor, 2);
   t += " EXP=";
   t += DoubleToString(r.expectancy, 2);
   t += " MaxDD=";
   t += DoubleToString(r.maxDrawdown, 2);
   t += " | Sess=";
   t += r.bestSession;
   t += " Sym=";
   t += r.bestSymbol;
   t += " TF=";
   t += r.bestTimeframe;
   t += " NewsWorst=";
   t += r.worstNews;
   return t;
}

#endif // HITMAN_ULTRA_ADAPTIVE_INTELLIGENCE_MQH
