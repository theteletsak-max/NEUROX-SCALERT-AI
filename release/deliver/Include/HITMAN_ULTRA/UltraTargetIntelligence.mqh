#ifndef HITMAN_ULTRA_TARGET_INTELLIGENCE_MQH
#define HITMAN_ULTRA_TARGET_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA TARGET INTELLIGENCE ENGINE ∞                   |
//| Institutional target management — every TP has a validated reason|
//| Never random. Never fixed-only. Thesis + structure + momentum.   |
//+------------------------------------------------------------------+

struct UltraTargetPlan
{
   bool   valid;
   bool   tp3Armed;          // exceptional continuation only
   bool   isBuy;
   double entry;
   double sl;
   double tp1;
   double tp2;
   double tp3;
   double risk;
   double rr1;
   double rr2;
   double rr3;
   string reasonSL;
   string reasonTP1;
   string reasonTP2;
   string reasonTP3;
   string thesisTag;
   string summary;
   int    conf;
   datetime ts;
};

UltraTargetPlan g_UltraTargetLast;

//--------------------------------------------------------------------//
void UltraTarget_Clear(UltraTargetPlan &p)
{
   p.valid = false;
   p.tp3Armed = false;
   p.isBuy = true;
   p.entry = p.sl = p.tp1 = p.tp2 = p.tp3 = 0.0;
   p.risk = p.rr1 = p.rr2 = p.rr3 = 0.0;
   p.reasonSL = p.reasonTP1 = p.reasonTP2 = p.reasonTP3 = "";
   p.thesisTag = "";
   p.summary = "";
   p.conf = 0;
   p.ts = 0;
}

double UltraTarget_Norm(const string s, const double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(s, SYMBOL_DIGITS));
}

double UltraTarget_Point(const string s)
{
   double pt = SymbolInfoDouble(s, SYMBOL_POINT);
   return (pt > 0.0) ? pt : _Point;
}

//--------------------------------------------------------------------//
// Structural / fib / liquidity anchors                               //
//--------------------------------------------------------------------//
double UltraTarget_StructSL(const UltraSnap &u, const bool isBuy, const double entry,
                            const double atr, string &why)
{
   why = "";
   double buf = atr * UltraTargetStructBufferATR;
   if(isBuy)
   {
      double cand = 0.0;
      if(u.st.swingLowOK && u.st.swingLow > 0.0 && u.st.swingLow < entry)
      {
         cand = u.st.swingLow - buf;
         why = "SL beyond swing low (structure invalidation)";
      }
      // Liquidity sweep extreme as invalidation
      if(u.liq.genuineBuy && u.st.swingLow > 0.0 && u.st.swingLow < entry)
      {
         double liqSL = u.st.swingLow - buf;
         if(cand <= 0.0 || liqSL < cand)
         {
            cand = liqSL;
            why = "SL beyond genuine buy-side sweep / equal lows";
         }
      }
      return cand;
   }
   // sell
   double candS = 0.0;
   if(u.st.swingHighOK && u.st.swingHigh > 0.0 && u.st.swingHigh > entry)
   {
      candS = u.st.swingHigh + buf;
      why = "SL beyond swing high (structure invalidation)";
   }
   if(u.liq.genuineSell && u.st.swingHigh > 0.0 && u.st.swingHigh > entry)
   {
      double liqSL = u.st.swingHigh + buf;
      if(candS <= 0.0 || liqSL > candS)
      {
         candS = liqSL;
         why = "SL beyond genuine sell-side sweep / equal highs";
      }
   }
   return candS;
}

double UltraTarget_PickBuyTP(const UltraSnap &u, const double entry, const double minDist,
                             const double preferNear, const double preferFar, string &why)
{
   why = "";
   double best = 0.0;
   string bestWhy = "";

   // Conservative / primary: opposing swing structure
   if(u.st.swingHighOK && u.st.swingHigh > entry + minDist)
   {
      best = u.st.swingHigh;
      bestWhy = "structure swing high";
   }
   // Fib extensions / levels above entry
   if(u.fib.f618 > entry + minDist)
   {
      if(best <= 0.0 || (preferNear > 0.0 && u.fib.f618 < best && u.fib.f618 >= entry + preferNear))
      { best = u.fib.f618; bestWhy = "fib 0.618 objective"; }
   }
   if(u.fib.f100 > entry + minDist)
   {
      if(best <= 0.0 || (preferFar > 0.0 && MathAbs(u.fib.f100 - (entry + preferFar)) < MathAbs(best - (entry + preferFar))))
      { /* keep for TP2 preference below */ }
      if(best <= 0.0) { best = u.fib.f100; bestWhy = "fib range high (1.0)"; }
   }
   if(u.fib.ext127 > entry + minDist)
   {
      if(best <= 0.0) { best = u.fib.ext127; bestWhy = "fib 1.272 extension"; }
   }
   if(u.fib.ext161 > entry + minDist)
   {
      if(best <= 0.0) { best = u.fib.ext161; bestWhy = "fib 1.618 extension"; }
   }

   why = bestWhy;
   return best;
}

double UltraTarget_PickSellTP(const UltraSnap &u, const double entry, const double minDist,
                              const double preferNear, const double preferFar, string &why)
{
   why = "";
   double best = 0.0;
   string bestWhy = "";

   if(u.st.swingLowOK && u.st.swingLow > 0.0 && u.st.swingLow < entry - minDist)
   {
      best = u.st.swingLow;
      bestWhy = "structure swing low";
   }
   if(u.fib.f382 > 0.0 && u.fib.f382 < entry - minDist)
   {
      if(best <= 0.0 || (preferNear > 0.0 && u.fib.f382 > best && u.fib.f382 <= entry - preferNear))
      { best = u.fib.f382; bestWhy = "fib 0.382 objective"; }
   }
   if(u.fib.f0 > 0.0 && u.fib.f0 < entry - minDist)
   {
      if(best <= 0.0) { best = u.fib.f0; bestWhy = "fib range low (0.0)"; }
   }
   if(u.fib.ext127 > 0.0 && u.fib.ext127 < entry - minDist)
   {
      if(best <= 0.0) { best = u.fib.ext127; bestWhy = "fib 1.272 extension"; }
   }
   if(u.fib.ext161 > 0.0 && u.fib.ext161 < entry - minDist)
   {
      if(best <= 0.0) { best = u.fib.ext161; bestWhy = "fib 1.618 extension"; }
   }

   why = bestWhy;
   return best;
}

//--------------------------------------------------------------------//
// BUILD — Entry → SL → TP1 → TP2 → TP3 (strategy-based, logged)      //
//--------------------------------------------------------------------//
bool UltraTarget_Build(const string s, const bool isBuy, const double entry,
                       const UltraSnap &u, const string thesisTag, UltraTargetPlan &p)
{
   UltraTarget_Clear(p);
   p.isBuy = isBuy;
   p.entry = entry;
   p.thesisTag = thesisTag;
   p.conf = u.score.confidence;
   p.ts = TimeCurrent();

   if(!UltraTargetEnabled)
   {
      p.summary = "target engine disabled — caller uses legacy distances";
      return false;
   }
   if(entry <= 0.0)
   {
      p.summary = "invalid entry";
      return false;
   }

   double atr = u.vol.atr;
   if(atr <= 0.0) atr = UltraATR(s, IDP_ATR_Period);
   if(atr <= 0.0)
   {
      p.summary = "ATR unavailable — cannot build intelligent targets";
      return false;
   }

   double point = UltraTarget_Point(s);
   // Self-contained ATR stop (no Shell_B input dependency)
   double atrSLDist = atr * UltraTargetSLATR;

   // ---- STOP LOSS (structure-first, ATR floor) ----
   string slWhy = "";
   double structSL = UltraTarget_StructSL(u, isBuy, entry, atr, slWhy);
   double atrSL = isBuy ? (entry - atrSLDist) : (entry + atrSLDist);
   double maxRisk = atr * UltraTargetMaxSLATR;

   if(structSL > 0.0)
   {
      double structRisk = MathAbs(entry - structSL);
      if(structRisk >= atr * UltraTargetMinSLATR && structRisk <= maxRisk)
      {
         p.sl = structSL;
         p.reasonSL = slWhy;
      }
      else if(structRisk > maxRisk)
      {
         // Structure too far — clamp to ATR-based with reason
         p.sl = atrSL;
         p.reasonSL = "ATR stop (structure SL beyond max risk)";
      }
      else
      {
         p.sl = atrSL;
         p.reasonSL = "ATR stop (structure SL too tight / noise)";
      }
   }
   else
   {
      p.sl = atrSL;
      p.reasonSL = "ATR stop (no valid structure invalidation)";
   }
   p.sl = UltraTarget_Norm(s, p.sl);
   p.risk = MathAbs(entry - p.sl);
   if(p.risk < point * 2.0)
   {
      p.summary = "risk too small after SL calc";
      return false;
   }

   // Minimum distances from RR floors (not sole targets — floors only)
   double minTP1 = p.risk * UltraTargetMinRR1;
   double minTP2 = p.risk * UltraTargetMinRR2;
   double minTP3 = p.risk * UltraTargetMinRR3;

   // ---- TP1 — secure first objective (high probability, conservative) ----
   string t1w = "";
   double t1 = 0.0;
   if(isBuy)
   {
      // Prefer nearer fib/partial structure for conservative TP1
      if(u.fib.f500 > entry + minTP1 * 0.5 && u.fib.f500 > entry)
      { t1 = u.fib.f500; t1w = "TP1 fib 0.50 — conservative high-probability"; }
      else if(u.fib.f618 > entry + minTP1 * 0.5 && u.fib.f618 > entry)
      { t1 = u.fib.f618; t1w = "TP1 fib 0.618 — conservative structure objective"; }
      else
         t1 = UltraTarget_PickBuyTP(u, entry, minTP1 * 0.5, minTP1, minTP2, t1w);

      if(t1 <= entry)
      {
         t1 = entry + minTP1;
         t1w = "TP1 RR-floor (no nearer structure — risk-based, not random)";
      }
      else if(t1 < entry + minTP1)
      {
         t1 = entry + minTP1;
         t1w += " | lifted to min RR1 floor";
      }
      // Cap TP1 so it stays conservative (not steal TP2)
      double cap1 = entry + p.risk * UltraTargetTP1MaxRR;
      if(t1 > cap1)
      {
         t1 = cap1;
         t1w += " | capped conservative TP1";
      }
   }
   else
   {
      if(u.fib.f500 > 0.0 && u.fib.f500 < entry - minTP1 * 0.5)
      { t1 = u.fib.f500; t1w = "TP1 fib 0.50 — conservative high-probability"; }
      else if(u.fib.f382 > 0.0 && u.fib.f382 < entry - minTP1 * 0.5)
      { t1 = u.fib.f382; t1w = "TP1 fib 0.382 — conservative structure objective"; }
      else
         t1 = UltraTarget_PickSellTP(u, entry, minTP1 * 0.5, minTP1, minTP2, t1w);

      if(t1 <= 0.0 || t1 >= entry)
      {
         t1 = entry - minTP1;
         t1w = "TP1 RR-floor (no nearer structure — risk-based, not random)";
      }
      else if(t1 > entry - minTP1)
      {
         t1 = entry - minTP1;
         t1w += " | lifted to min RR1 floor";
      }
      double cap1 = entry - p.risk * UltraTargetTP1MaxRR;
      if(t1 < cap1)
      {
         t1 = cap1;
         t1w += " | capped conservative TP1";
      }
   }
   // Momentum / thesis audit soft-tag (does not invent price)
   if(!(u.mom.momBuy || u.mom.momSell || u.mom.impulse) && StringFind(t1w, "RR-floor") < 0)
      t1w += " | momentum soft";
   p.tp1 = UltraTarget_Norm(s, t1);
   p.reasonTP1 = t1w;
   p.rr1 = p.risk > 0.0 ? MathAbs(p.tp1 - entry) / p.risk : 0.0;

   // ---- TP2 — primary move (trend continuation + structure) ----
   string t2w = "";
   double t2 = 0.0;
   if(isBuy)
   {
      if(u.fib.ext127 > entry + minTP2 * 0.5)
      { t2 = u.fib.ext127; t2w = "TP2 fib 1.272 — primary continuation"; }
      else if(u.fib.f100 > entry + minTP2 * 0.5)
      { t2 = u.fib.f100; t2w = "TP2 swing/fib high — primary structure objective"; }
      else if(u.st.swingHighOK && u.st.swingHigh > p.tp1)
      { t2 = u.st.swingHigh; t2w = "TP2 structure swing high — main objective"; }
      else
      {
         t2 = entry + minTP2;
         t2w = "TP2 RR-floor (primary risk objective — structure thin)";
      }
      if(t2 <= p.tp1)
      {
         t2 = p.tp1 + p.risk * 0.5;
         t2w += " | stepped beyond TP1";
      }
      if(t2 < entry + minTP2)
      {
         t2 = entry + minTP2;
         t2w += " | lifted to min RR2";
      }
   }
   else
   {
      if(u.fib.ext127 > 0.0 && u.fib.ext127 < entry - minTP2 * 0.5)
      { t2 = u.fib.ext127; t2w = "TP2 fib 1.272 — primary continuation"; }
      else if(u.fib.f0 > 0.0 && u.fib.f0 < entry - minTP2 * 0.5)
      { t2 = u.fib.f0; t2w = "TP2 swing/fib low — primary structure objective"; }
      else if(u.st.swingLowOK && u.st.swingLow > 0.0 && u.st.swingLow < p.tp1)
      { t2 = u.st.swingLow; t2w = "TP2 structure swing low — main objective"; }
      else
      {
         t2 = entry - minTP2;
         t2w = "TP2 RR-floor (primary risk objective — structure thin)";
      }
      if(t2 >= p.tp1)
      {
         t2 = p.tp1 - p.risk * 0.5;
         t2w += " | stepped beyond TP1";
      }
      if(t2 > entry - minTP2)
      {
         t2 = entry - minTP2;
         t2w += " | lifted to min RR2";
      }
   }
   if(u.trend.continuation || u.trend.strength >= 55)
      t2w += " | trend continuation validated";
   p.tp2 = UltraTarget_Norm(s, t2);
   p.reasonTP2 = t2w;
   p.rr2 = p.risk > 0.0 ? MathAbs(p.tp2 - entry) / p.risk : 0.0;

   // ---- TP3 — exceptional continuation ONLY (never forced) ----
   string t3w = "";
   double t3 = 0.0;
   bool thesisStrong = (u.score.confidence >= UltraTargetTP3MinConf) &&
                       (u.trend.strength >= UltraTargetTP3MinTrend) &&
                       (u.trend.continuation || u.mom.impulse) &&
                       (isBuy ? (u.trend.bull || u.bos.buy) : (u.trend.bear || u.bos.sell));
   bool allowTP3 = thesisStrong && UltraTargetEnableTP3;

   if(allowTP3)
   {
      if(isBuy)
      {
         if(u.fib.ext161 > p.tp2)
         { t3 = u.fib.ext161; t3w = "TP3 fib 1.618 — exceptional continuation"; }
         else if(u.liq.equalHighs && u.st.swingHigh > p.tp2)
         { t3 = u.st.swingHigh + atr * 0.25; t3w = "TP3 liquidity pool beyond equal highs"; }
         else
         {
            t3 = entry + minTP3;
            t3w = "TP3 RR-floor — thesis still valid for runner";
         }
         if(t3 <= p.tp2)
         {
            // Never force a weak TP3 past primary — disarm
            allowTP3 = false;
            t3w = "TP3 disarmed — no exceptional level beyond TP2";
            t3 = 0.0;
         }
      }
      else
      {
         if(u.fib.ext161 > 0.0 && u.fib.ext161 < p.tp2)
         { t3 = u.fib.ext161; t3w = "TP3 fib 1.618 — exceptional continuation"; }
         else if(u.liq.equalLows && u.st.swingLow > 0.0 && u.st.swingLow < p.tp2)
         { t3 = u.st.swingLow - atr * 0.25; t3w = "TP3 liquidity pool beyond equal lows"; }
         else
         {
            t3 = entry - minTP3;
            t3w = "TP3 RR-floor — thesis still valid for runner";
         }
         if(t3 >= p.tp2 || t3 <= 0.0)
         {
            allowTP3 = false;
            t3w = "TP3 disarmed — no exceptional level beyond TP2";
            t3 = 0.0;
         }
      }
   }
   else
   {
      t3w = "TP3 not armed — thesis/trend/momentum not exceptional (never forced)";
      t3 = 0.0;
   }

   p.tp3Armed = allowTP3 && (t3 > 0.0);
   if(p.tp3Armed)
   {
      p.tp3 = UltraTarget_Norm(s, t3);
      p.rr3 = p.risk > 0.0 ? MathAbs(p.tp3 - entry) / p.risk : 0.0;
   }
   else
   {
      // Ladder expects a far broker TP — use TP2 as broker far target when TP3 disarmed
      p.tp3 = p.tp2;
      p.rr3 = p.rr2;
   }
   p.reasonTP3 = t3w;

   // ---- VALIDATE COMPLETE TRADE ----
   string vWhy = "";
   if(!UltraTarget_ValidatePlan(p, vWhy))
   {
      p.valid = false;
      p.summary = vWhy;
      if(UltraTargetLog)
         UltraLog("TARGET INVALID " + vWhy);
      return false;
   }

   p.valid = true;
   p.summary = "TARGET OK SL=" + p.reasonSL +
               " | TP1=" + p.reasonTP1 +
               " | TP2=" + p.reasonTP2 +
               " | TP3=" + p.reasonTP3 +
               " RR=" + DoubleToString(p.rr1, 2) + "/" +
               DoubleToString(p.rr2, 2) + "/" + DoubleToString(p.rr3, 2);
   g_UltraTargetLast = p;

   if(UltraTargetLog)
   {
      UltraLogDecision("TARGET", 0, isBuy ? "BUY" : "SELL", thesisTag,
                       p.conf, (int)MathRound(p.rr2 * 100.0),
                       p.thesisTag, "TP_PLAN",
                       0.0, p.risk, p.summary);
      UltraLog("TARGET SL: " + p.reasonSL +
               " @ " + DoubleToString(p.sl, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)));
      UltraLog("TARGET TP1: " + p.reasonTP1 +
               " @ " + DoubleToString(p.tp1, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)) +
               " RR=" + DoubleToString(p.rr1, 2));
      UltraLog("TARGET TP2: " + p.reasonTP2 +
               " @ " + DoubleToString(p.tp2, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)) +
               " RR=" + DoubleToString(p.rr2, 2));
      UltraLog("TARGET TP3: " + p.reasonTP3 +
               " @ " + DoubleToString(p.tp3, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)) +
               " armed=" + (p.tp3Armed ? "Y" : "N") +
               " RR=" + DoubleToString(p.rr3, 2));
   }
   return true;
}

//--------------------------------------------------------------------//
bool UltraTarget_ValidatePlan(const UltraTargetPlan &p, string &why)
{
   why = "";
   if(p.entry <= 0.0){ why = "entry invalid"; return false; }
   if(p.sl <= 0.0){ why = "SL invalid"; return false; }
   if(p.tp1 <= 0.0){ why = "TP1 invalid"; return false; }
   if(p.tp2 <= 0.0){ why = "TP2 invalid"; return false; }
   if(p.risk <= 0.0){ why = "risk invalid"; return false; }

   if(p.isBuy)
   {
      if(!(p.sl < p.entry)){ why = "BUY SL must be below entry"; return false; }
      if(!(p.tp1 > p.entry)){ why = "BUY TP1 must be above entry"; return false; }
      if(!(p.tp2 > p.tp1)){ why = "BUY TP2 must be beyond TP1"; return false; }
      if(p.tp3 > 0.0 && !(p.tp3 >= p.tp2)){ why = "BUY TP3 must be >= TP2"; return false; }
   }
   else
   {
      if(!(p.sl > p.entry)){ why = "SELL SL must be above entry"; return false; }
      if(!(p.tp1 < p.entry)){ why = "SELL TP1 must be below entry"; return false; }
      if(!(p.tp2 < p.tp1)){ why = "SELL TP2 must be beyond TP1"; return false; }
      if(p.tp3 > 0.0 && !(p.tp3 <= p.tp2)){ why = "SELL TP3 must be <= TP2"; return false; }
   }

   if(p.rr1 + 1e-9 < UltraTargetMinRR1){ why = "TP1 RR below minimum"; return false; }
   if(p.rr2 + 1e-9 < UltraTargetMinRR2){ why = "TP2 RR below minimum"; return false; }
   if(StringLen(p.reasonSL) == 0 || StringLen(p.reasonTP1) == 0 || StringLen(p.reasonTP2) == 0)
   { why = "missing target reason"; return false; }

   return true;
}

//--------------------------------------------------------------------//
// APPLY — override ExecuteBuy/Sell levels with validated plan        //
//--------------------------------------------------------------------//
bool UltraTarget_Apply(const string s, const bool isBuy, const double entry,
                       double &sl, double &tp1, double &tp2, double &tp3,
                       double &slDist, double &tp1Dist, double &tp2Dist, double &tp3Dist,
                       string &why)
{
   why = "";
   if(!UltraTargetEnabled)
   {
      why = "disabled";
      return false;
   }

   UltraSnap u = g_UltraLastSnap;
   // Ensure snap matches symbol context; rebuild if empty ATR
   if(u.vol.atr <= 0.0)
   {
      if(!UltraBuildSnapshot(s, u))
      {
         why = "snapshot failed for targets";
         return false;
      }
   }

   UltraTargetPlan p;
   string tag = g_UltraLastSignal.tag;
   if(StringLen(tag) == 0) tag = "ULTRA";
   if(!UltraTarget_Build(s, isBuy, entry, u, tag, p) || !p.valid)
   {
      why = (StringLen(p.summary) > 0) ? p.summary : "target build failed";
      if(UltraTargetStrict)
         return false; // block trade — no unvalidated targets
      why = "fallback legacy distances — " + why;
      return false; // soft: caller keeps GetTradeDistances
   }

   sl = p.sl;
   tp1 = p.tp1;
   tp2 = p.tp2;
   tp3 = p.tp3;
   slDist = MathAbs(entry - sl);
   tp1Dist = MathAbs(tp1 - entry);
   tp2Dist = MathAbs(tp2 - entry);
   tp3Dist = MathAbs(tp3 - entry);
   why = p.summary;
   return true;
}

void UltraTarget_Boot()
{
   UltraTarget_Clear(g_UltraTargetLast);
   if(UltraTargetLog)
      UltraLog("TARGET INTEL ∞ boot Enabled=" + (UltraTargetEnabled ? "Y" : "N") +
               " Strict=" + (UltraTargetStrict ? "Y" : "N") +
               " TP3=" + (UltraTargetEnableTP3 ? "Y" : "N") +
               " BUILD=HA_ULTRA_93");
}

string UltraTarget_Dashboard()
{
   string t = "TARGET: ";
   if(!UltraTargetEnabled) { t += "OFF"; return t; }
   if(!g_UltraTargetLast.valid) { t += "—"; return t; }
   t += g_UltraTargetLast.isBuy ? "BUY" : "SELL";
   t += " RR=";
   t += DoubleToString(g_UltraTargetLast.rr1, 1);
   t += "/";
   t += DoubleToString(g_UltraTargetLast.rr2, 1);
   t += "/";
   t += DoubleToString(g_UltraTargetLast.rr3, 1);
   t += g_UltraTargetLast.tp3Armed ? " TP3:Y" : " TP3:N";
   return t;
}

#endif // HITMAN_ULTRA_TARGET_INTELLIGENCE_MQH
