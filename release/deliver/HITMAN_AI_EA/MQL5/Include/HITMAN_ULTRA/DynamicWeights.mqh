#ifndef HITMAN_ULTRA_DYNAMIC_WEIGHTS_MQH
#define HITMAN_ULTRA_DYNAMIC_WEIGHTS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 5 DYNAMIC WEIGHT ENGINE                        |
//| Regime-based module weights (soft, neutral by default)           |
//+------------------------------------------------------------------+

struct UltraDynWeights
{
   double structure;
   double trend;
   double bos;
   double choch;
   double liquidity;
   double fibonacci;
   double institutional;
   double momentum;
   double volatility;
   double regime;
   double session;
   double news;
   double precision;
   double probability;
   double risk;
   double execution;
};

void UltraWeights_Neutral(UltraDynWeights &w)
{
   w.structure = w.trend = w.bos = w.choch = w.liquidity = 1.0;
   w.fibonacci = w.institutional = w.momentum = w.volatility = 1.0;
   w.regime = w.session = w.news = 1.0;
   w.precision = w.probability = w.risk = w.execution = 1.0;
}

void UltraWeights_FromRegime(const ENUM_ULTRA_REGIME r, UltraDynWeights &w)
{
   UltraWeights_Neutral(w);
   if(!UltraUpgradeEnabled || !UltraDynWeightsEnabled) return;

   // Soft boosts only (±0.15) so InstantQuality is not frozen
   if(r == UREG_STRONG_TREND || r == UREG_HEALTHY_TREND || r == UREG_WEAK_TREND || r == UREG_BREAKOUT)
   {
      w.trend = 1.15; w.bos = 1.12; w.momentum = 1.12; w.structure = 0.95;
   }
   else if(r == UREG_RANGE || r == UREG_ACCUMULATION || r == UREG_DISTRIBUTION || r == UREG_COMPRESSION)
   {
      w.structure = 1.15; w.liquidity = 1.12; w.precision = 1.12; w.trend = 0.95;
   }
   else if(r == UREG_EXPANSION || r == UREG_REVERSAL || r == UREG_EXHAUSTION)
   {
      w.volatility = 1.15; w.risk = 1.15; w.probability = 1.08; w.momentum = 0.95;
   }
}

int UltraWeights_Apply(const int raw, const double weight)
{
   double v = (double)raw * weight;
   int out = (int)MathRound(v);
   if(out < 0) out = 0;
   if(out > 100) out = 100;
   // Soft mode: clamp movement vs raw to ±5
   if(!UltraUpgradeStrict)
   {
      int lo = raw - 5; if(lo < 0) lo = 0;
      int hi = raw + 5; if(hi > 100) hi = 100;
      if(out < lo) out = lo;
      if(out > hi) out = hi;
   }
   return out;
}

#endif
