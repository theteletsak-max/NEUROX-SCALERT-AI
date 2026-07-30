#ifndef HITMAN_ULTRA_CORRECTION_MQH
#define HITMAN_ULTRA_CORRECTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 13 CORRECTION DETECTOR                         |
//| Healthy pullback vs major reversal                               |
//+------------------------------------------------------------------+

enum ENUM_CORR_STATE
{
   CORR_PULLBACK = 0,
   CORR_CONTINUATION,
   CORR_LIQ_GRAB,
   CORR_RETEST,
   CORR_REVERSAL,
   CORR_UNKNOWN
};

struct UltraCorrection
{
   ENUM_CORR_STATE state;
   string label;
   bool isHealthy;
};

string UltraCorr_Name(const ENUM_CORR_STATE s)
{
   if(s == CORR_PULLBACK) return "PULLBACK";
   if(s == CORR_CONTINUATION) return "CONTINUATION";
   if(s == CORR_LIQ_GRAB) return "LIQ_GRAB";
   if(s == CORR_RETEST) return "RETEST";
   if(s == CORR_REVERSAL) return "REVERSAL";
   return "UNKNOWN";
}

UltraCorrection UltraCorr_Detect(const UltraSnap &u, const bool isBuy)
{
   UltraCorrection c;
   c.state = CORR_UNKNOWN;
   c.label = "UNKNOWN";
   c.isHealthy = true;
   if(!UltraUpgradeEnabled || !UltraCorrectionEnabled)
   { c.state = CORR_PULLBACK; c.label = "PULLBACK"; return c; }

   bool adverseBos = isBuy ? (u.bos.sell && u.bos.confirmed) : (u.bos.buy && u.bos.confirmed);
   bool adverseCh  = isBuy ? (u.choch.sell && u.choch.majorC) : (u.choch.buy && u.choch.majorC);
   bool liqGrab = isBuy ? (u.liq.sweepBuy || u.liq.stopHuntBuy) : (u.liq.sweepSell || u.liq.stopHuntSell);
   bool cont = u.st.continuation || (isBuy ? u.trend.bull : u.trend.bear);
   bool softMomLoss = u.mom.weakness && !adverseBos && !adverseCh;

   // True reversal = confirmed adverse BOS + major CHoCH + exhaustion (soft)
   // Soft mode refuses to call REVERSAL on a single BOS flicker.
   bool trueReversal = false;
   if(UltraUpgradeStrict)
      trueReversal = (adverseBos || adverseCh) && u.trend.exhaustion;
   else
      trueReversal = adverseBos && adverseCh && u.trend.exhaustion;

   if(trueReversal)
   {
      c.state = CORR_REVERSAL;
      c.isHealthy = false;
   }
   else if(liqGrab && !adverseBos)
      c.state = CORR_LIQ_GRAB;
   else if(cont && softMomLoss)
      c.state = CORR_PULLBACK;
   else if(cont)
      c.state = CORR_CONTINUATION;
   else if(isBuy ? u.fib.atBuyZone : u.fib.atSellZone)
      c.state = CORR_RETEST;
   else if(adverseBos || adverseCh)
   {
      // Single adverse break without full stack → treat as pullback, not exit
      c.state = CORR_PULLBACK;
      c.isHealthy = true;
   }
   else
   {
      c.state = CORR_UNKNOWN;
      c.isHealthy = true;
   }
   c.label = UltraCorr_Name(c.state);
   return c;
}

#endif
