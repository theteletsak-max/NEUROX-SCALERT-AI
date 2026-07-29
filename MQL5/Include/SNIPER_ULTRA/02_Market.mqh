#ifndef SNIPER_ULTRA_02_MARKET_MQH
#define SNIPER_ULTRA_02_MARKET_MQH
//+------------------------------------------------------------------+
//| 02. Ultra Market Analysis Engine                                 |
//| Structure · UBOSE · UCHOCHE · ULSE · UFIE · ICT · Trend · Mom ·  |
//| Vol · Regime · Session/News context · SMI/MEO/IFI                |
//+------------------------------------------------------------------+
void UltraEngStructure(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   int iH1, iH2, iL1, iL2;
   if(UltraFindSwings(s, tf, UltraStructLookback, UltraSwingStrength, iH1, iH2, iL1, iL2))
   {
      double h1 = iHigh(s, tf, iH1), h2 = iHigh(s, tf, iH2);
      double l1 = iLow(s, tf, iL1), l2 = iLow(s, tf, iL2);
      u.st.hh = (h1 > h2); u.st.hl = (l1 > l2); u.st.lh = (h1 < h2); u.st.ll = (l1 < l2);
      u.st.swingHigh = h1; u.st.swingLow = l1;
      u.st.swingHighOK = true; u.st.swingLowOK = true;
      u.st.externalBull = (u.st.hh && u.st.hl);
      u.st.externalBear = (u.st.lh && u.st.ll);
   }
   else
   {
      u.st.swingHigh = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, UltraStructLookback, 1));
      u.st.swingLow  = iLow(s, tf, iLowest(s, tf, MODE_LOW, UltraStructLookback, 1));
   }
   // Internal structure (shorter lookback)
   int jH1, jH2, jL1, jL2;
   if(UltraFindSwings(s, tf, MathMax(UltraStructLookback / 2, 16), UltraSwingStrength, jH1, jH2, jL1, jL2))
   {
      bool ihh = iHigh(s, tf, jH1) > iHigh(s, tf, jH2);
      bool ihl = iLow(s, tf, jL1) > iLow(s, tf, jL2);
      bool ilh = iHigh(s, tf, jH1) < iHigh(s, tf, jH2);
      bool ill = iLow(s, tf, jL1) < iLow(s, tf, jL2);
      u.st.internalBull = (ihh && ihl);
      u.st.internalBear = (ilh && ill);
   }
   u.st.continuation = (u.st.externalBull && u.st.internalBull) || (u.st.externalBear && u.st.internalBear);
   u.st.reversal = (u.st.externalBull && u.st.internalBear) || (u.st.externalBear && u.st.internalBull);
   u.st.strength = 40;
   if(u.st.externalBull || u.st.externalBear) u.st.strength += 20;
   if(u.st.internalBull || u.st.internalBear) u.st.strength += 15;
   if(u.st.continuation) u.st.strength += 15;
   if(u.st.reversal) u.st.strength += 10;
   if(u.st.strength > 100) u.st.strength = 100;
   u.st.quality = u.st.strength;
   if(u.st.swingHigh <= u.st.swingLow) u.st.quality = MathMax(u.st.quality - 20, 0);
}

void UltraEngBOS(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double c1 = iClose(s, tf, 1);
   u.bos.buy = (u.st.swingHigh > 0 && c1 > u.st.swingHigh);
   u.bos.sell = (u.st.swingLow > 0 && c1 < u.st.swingLow);
   for(int i = 1; i <= UltraBOS_ConfirmBars; i++)
   {
      double c = iClose(s, tf, i);
      if(c > u.st.swingHigh) u.bos.buy = true;
      if(c < u.st.swingLow)  u.bos.sell = true;
   }
   u.bos.confirmation = 0;
   if(u.bos.buy || u.bos.sell)
   {
      double body = MathAbs(iClose(s, tf, 1) - iOpen(s, tf, 1));
      double rng = iHigh(s, tf, 1) - iLow(s, tf, 1);
      u.bos.confirmation = (rng > 0 && body / rng >= UltraDispBodyMin) ? 80 : 55;
   }
   u.bos.strength = u.bos.confirmation;
   if((u.bos.buy && u.st.externalBull) || (u.bos.sell && u.st.externalBear)) u.bos.strength += 15;
   if(u.bos.strength > 100) u.bos.strength = 100;
   u.bos.quality = u.bos.strength;
   u.bos.reliability = (u.bos.confirmation >= 70 && u.st.quality >= 50) ? 75 : 45;
   u.bos.score = (u.bos.strength + u.bos.quality + u.bos.reliability) / 3;
}

void UltraEngCHoCH(const string s, UltraSnap &u)
{
   u.choch.buy  = u.bos.buy  && (u.st.ll || u.st.externalBear || u.st.internalBear);
   u.choch.sell = u.bos.sell && (u.st.hh || u.st.externalBull || u.st.internalBull);
   u.choch.internalC = (u.choch.buy || u.choch.sell) && (u.st.internalBull || u.st.internalBear);
   u.choch.externalC = (u.choch.buy || u.choch.sell) && (u.st.externalBull || u.st.externalBear);
   u.choch.majorC = u.choch.externalC && u.bos.score >= 65;
   u.choch.minorC = (u.choch.buy || u.choch.sell) && !u.choch.majorC;
   u.choch.strength = 0;
   if(u.choch.buy || u.choch.sell) u.choch.strength = 50 + (u.choch.majorC ? 30 : 10) + (u.choch.internalC ? 10 : 0);
   if(u.choch.strength > 100) u.choch.strength = 100;
   u.choch.confidence = u.choch.strength;
}

void UltraEngLiquidity(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   if(u.vol.atr <= 0) return;
   double tol = u.vol.atr * UltraEqualTolATR;
   int lb = MathMax(UltraStructLookback / 2, 12);
   double lo = iLow(s, tf, iLowest(s, tf, MODE_LOW, lb, 1));
   double hi = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, lb, 1));
   int nL = 0, nH = 0;
   for(int i = 1; i <= lb; i++)
   {
      if(MathAbs(iLow(s, tf, i) - lo) <= tol) nL++;
      if(MathAbs(iHigh(s, tf, i) - hi) <= tol) nH++;
   }
   u.liq.poolBuy = (nL >= 2);  // equal lows = sell-side pool / buy grab target
   u.liq.poolSell = (nH >= 2);
   u.liq.sellSideLiq = u.liq.poolBuy || (u.st.swingLow > 0);
   u.liq.buySideLiq  = u.liq.poolSell || (u.st.swingHigh > 0);
   u.liq.poolLow = u.liq.poolBuy ? lo : u.st.swingLow;
   u.liq.poolHigh = u.liq.poolSell ? hi : u.st.swingHigh;

   double minD = u.vol.atr * UltraSweepDepthATR;
   int swlb = MathMax(UltraSweepLookback, 5);
   double bestDepth = 0;
   for(int i = 1; i <= swlb; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), c = iClose(s, tf, i), o = iOpen(s, tf, i);
      double rng = h - l; if(rng <= 0) continue;
      if(!u.liq.sweepBuy && u.liq.poolLow > 0 && l < u.liq.poolLow - minD && c > u.liq.poolLow)
      {
         double wick = (MathMin(c, u.liq.poolLow) - l) / rng;
         if(wick >= UltraSweepWickMin)
         {
            u.liq.sweepBuy = true; u.liq.grabBuy = true; u.liq.sweepExtBuy = l;
            bestDepth = MathMax(bestDepth, (u.liq.poolLow - l) / u.vol.atr);
            u.liq.confirmedBuy = (c > o);
         }
      }
      if(!u.liq.sweepSell && u.liq.poolHigh > 0 && h > u.liq.poolHigh + minD && c < u.liq.poolHigh)
      {
         double wick = (h - MathMax(c, u.liq.poolHigh)) / rng;
         if(wick >= UltraSweepWickMin)
         {
            u.liq.sweepSell = true; u.liq.grabSell = true; u.liq.sweepExtSell = h;
            bestDepth = MathMax(bestDepth, (h - u.liq.poolHigh) / u.vol.atr);
            u.liq.confirmedSell = (c < o);
         }
      }
      double upper = h - MathMax(c, o);
      double lower = MathMin(c, o) - l;
      if(lower / rng >= 0.45 && c > o) u.liq.stopHuntBuy = true;
      if(upper / rng >= 0.45 && c < o) u.liq.stopHuntSell = true;
   }
   u.liq.depthATR = bestDepth;
   u.liq.speed = (u.liq.sweepBuy || u.liq.sweepSell) ? MathMin(100.0, 40.0 + bestDepth * 40.0) : 0;
   u.liq.strength = u.liq.speed;
   u.liq.quality = 40;
   if(u.liq.confirmedBuy || u.liq.confirmedSell) u.liq.quality += 25;
   if(u.liq.stopHuntBuy || u.liq.stopHuntSell) u.liq.quality += 15;
   if(u.liq.poolBuy || u.liq.poolSell) u.liq.quality += 10;
   if(u.liq.quality > 100) u.liq.quality = 100;
   u.liq.rejectionScore = (int)MathRound(u.liq.quality);
}

void UltraEngFib(const string s, UltraSnap &u)
{
   // Proprietary swing selection = structure swings; impulse = external structure move
   u.fib.f100 = u.st.swingHigh; u.fib.f0 = u.st.swingLow;
   double rng = u.fib.f100 - u.fib.f0;
   if(rng <= 0) return;
   u.fib.impulseOK = (u.vol.atr > 0 && rng >= u.vol.atr * 1.2);
   u.fib.f382 = u.fib.f0 + rng * 0.382;
   u.fib.f500 = u.fib.f0 + rng * 0.500;
   u.fib.f618 = u.fib.f0 + rng * 0.618;
   u.fib.f786 = u.fib.f0 + rng * 0.786;
   u.fib.ext127 = u.fib.f100 + rng * (UltraFibExt127 - 1.0);
   u.fib.ext161 = u.fib.f100 + rng * (UltraFibExt161 - 1.0);
   // For bear impulse, extensions below f0
   if(u.st.externalBear)
   {
      u.fib.ext127 = u.fib.f0 - rng * (UltraFibExt127 - 1.0);
      u.fib.ext161 = u.fib.f0 - rng * (UltraFibExt161 - 1.0);
   }
   double px = SymbolInfoDouble(s, SYMBOL_BID);
   u.fib.retracePos = (px - u.fib.f0) / rng;
   u.fib.atBuyZone  = (u.fib.retracePos >= UltraFibBuyLow && u.fib.retracePos <= UltraFibBuyHigh);
   u.fib.atSellZone = (u.fib.retracePos >= UltraFibSellLow && u.fib.retracePos <= UltraFibSellHigh);
   // Zone ranking: 0.618 best, then 0.5, 0.786, 0.382
   u.fib.zoneRank = 0;
   if(MathAbs(u.fib.retracePos - 0.618) < 0.05) u.fib.zoneRank = 100;
   else if(MathAbs(u.fib.retracePos - 0.500) < 0.05) u.fib.zoneRank = 85;
   else if(MathAbs(u.fib.retracePos - 0.786) < 0.05) u.fib.zoneRank = 75;
   else if(MathAbs(u.fib.retracePos - 0.382) < 0.05) u.fib.zoneRank = 65;
   else if(u.fib.atBuyZone || u.fib.atSellZone) u.fib.zoneRank = 55;
   u.fib.confluence = u.fib.zoneRank;
   if(u.fib.impulseOK) u.fib.confluence += 10;
   if((u.fib.atBuyZone && u.liq.sweepBuy) || (u.fib.atSellZone && u.liq.sweepSell)) u.fib.confluence += 15;
   if(u.fib.confluence > 100) u.fib.confluence = 100;
   u.fib.quality = u.fib.confluence;
   u.fib.confidence = u.fib.quality;
}

void UltraEngInstitutional(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double o1 = iOpen(s, tf, 1), c1 = iClose(s, tf, 1), h1 = iHigh(s, tf, 1), l1 = iLow(s, tf, 1);
   double r1 = h1 - l1;
   if(r1 > 0)
   {
      double br = MathAbs(c1 - o1) / r1;
      bool atrOK = (u.vol.atr <= 0) || (r1 >= u.vol.atr * UltraDispATRMin);
      if(br >= UltraDispBodyMin && atrOK){ u.ict.dispBuy = (c1 > o1); u.ict.dispSell = (c1 < o1); }
   }
   double gapB = iLow(s, tf, 1) - iHigh(s, tf, 3);
   double gapS = iLow(s, tf, 3) - iHigh(s, tf, 1);
   if(gapB > 0 && (u.vol.atr <= 0 || gapB >= u.vol.atr * UltraFVG_MinATR)) u.ict.fvgBuy = true;
   if(gapS > 0 && (u.vol.atr <= 0 || gapS >= u.vol.atr * UltraFVG_MinATR)) u.ict.fvgSell = true;
   double o2 = iOpen(s, tf, 2), c2 = iClose(s, tf, 2);
   if(u.ict.dispBuy && c2 < o2) u.ict.obBuy = true;
   if(u.ict.dispSell && c2 > o2) u.ict.obSell = true;
   // Breaker: prior OB invalidated then reclaim
   if(u.bos.buy && u.ict.obSell) u.ict.breakerBuy = true;
   if(u.bos.sell && u.ict.obBuy) u.ict.breakerSell = true;
   // Mitigation: price returned into OB/FVG
   double px = SymbolInfoDouble(s, SYMBOL_BID);
   if(u.ict.obBuy && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationBuy = true;
   if(u.ict.obSell && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationSell = true;
   if(u.st.swingHigh > u.st.swingLow)
   {
      double mid = (u.st.swingHigh + u.st.swingLow) * 0.5;
      u.ict.inDiscount = (px <= mid); u.ict.inPremium = (px >= mid);
   }
   u.ict.instZoneBuy = (u.ict.obBuy || u.ict.fvgBuy || u.ict.breakerBuy) && u.ict.inDiscount;
   u.ict.instZoneSell = (u.ict.obSell || u.ict.fvgSell || u.ict.breakerSell) && u.ict.inPremium;
   u.ict.rejectZoneBuy = u.liq.stopHuntBuy && u.ict.inDiscount;
   u.ict.rejectZoneSell = u.liq.stopHuntSell && u.ict.inPremium;
   u.ict.smConfluence = ((u.ict.obBuy || u.ict.fvgBuy) && u.liq.sweepBuy && u.ict.dispBuy) ||
                        ((u.ict.obSell || u.ict.fvgSell) && u.liq.sweepSell && u.ict.dispSell);
}

void UltraEngTrend(const string s, UltraSnap &u)
{
   u.trend.bull = u.st.externalBull || u.st.internalBull;
   u.trend.bear = u.st.externalBear || u.st.internalBear;
   // HTF / Macro / Week / Month
   int iH1, iH2, iL1, iL2;
   if(UltraFindSwings(s, UltraTF_Bias, 40, UltraSwingStrength, iH1, iH2, iL1, iL2))
   {
      bool hh = iHigh(s, UltraTF_Bias, iH1) > iHigh(s, UltraTF_Bias, iH2);
      bool hl = iLow(s, UltraTF_Bias, iL1) > iLow(s, UltraTF_Bias, iL2);
      bool lh = iHigh(s, UltraTF_Bias, iH1) < iHigh(s, UltraTF_Bias, iH2);
      bool ll = iLow(s, UltraTF_Bias, iL1) < iLow(s, UltraTF_Bias, iL2);
      u.trend.htfBull = (hh && hl); u.trend.htfBear = (lh && ll);
   }
   double smaH = UltraSMA(s, UltraTF_Bias, 50);
   double cH = iClose(s, UltraTF_Bias, 1);
   if(smaH > 0){ if(cH > smaH) u.trend.htfBull = true; if(cH < smaH) u.trend.htfBear = true; }
   double smaD = UltraSMA(s, UltraTF_Macro, 20);
   double cD = iClose(s, UltraTF_Macro, 1);
   if(smaD > 0){ u.trend.macroBull = (cD > smaD); u.trend.macroBear = (cD < smaD); }
   double smaW = UltraSMA(s, UltraTF_Week, 10);
   double cW = iClose(s, UltraTF_Week, 1);
   if(smaW > 0){ u.trend.weekBull = (cW > smaW); u.trend.weekBear = (cW < smaW); }
   double smaM = UltraSMA(s, UltraTF_Month, 6);
   double cM = iClose(s, UltraTF_Month, 1);
   if(smaM > 0){ u.trend.monthBull = (cM > smaM); u.trend.monthBear = (cM < smaM); }

   u.trend.mtfVotesBuy = 0; u.trend.mtfVotesSell = 0;
   if(u.trend.bull) u.trend.mtfVotesBuy++; if(u.trend.bear) u.trend.mtfVotesSell++;
   if(u.trend.htfBull) u.trend.mtfVotesBuy++; if(u.trend.htfBear) u.trend.mtfVotesSell++;
   if(u.trend.macroBull) u.trend.mtfVotesBuy++; if(u.trend.macroBear) u.trend.mtfVotesSell++;
   if(u.trend.weekBull) u.trend.mtfVotesBuy++; if(u.trend.weekBear) u.trend.mtfVotesSell++;
   if(u.trend.monthBull) u.trend.mtfVotesBuy++; if(u.trend.monthBear) u.trend.mtfVotesSell++;
   if(UltraUseMTFVoting)
   {
      ENUM_TIMEFRAMES tfs[3]; int n = 0;
      if(UltraUseM30) tfs[n++] = PERIOD_M30;
      if(UltraUseM15) tfs[n++] = PERIOD_M15;
      if(UltraUseM5)  tfs[n++] = PERIOD_M5;
      if(UltraUseM1Optional) { /* optional skipped into compact array */ }
      for(int i = 0; i < n; i++)
      {
         double sma = UltraSMA(s, tfs[i], 20);
         double c = iClose(s, tfs[i], 1);
         if(sma <= 0) continue;
         if(c > sma) u.trend.mtfVotesBuy++; else if(c < sma) u.trend.mtfVotesSell++;
      }
   }
   u.trend.strength = 30 + u.trend.mtfVotesBuy * 8 + u.trend.mtfVotesSell * 0;
   if(u.trend.bear) u.trend.strength = 30 + u.trend.mtfVotesSell * 8;
   if(u.trend.bull && u.trend.bear) u.trend.strength = 40;
   if(u.trend.strength > 100) u.trend.strength = 100;
   u.trend.quality = u.trend.strength;
   u.trend.persistence = MathMin(100, 20 + MathAbs(u.trend.mtfVotesBuy - u.trend.mtfVotesSell) * 12);
}

void UltraEngMomentum(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   int up = 0, dn = 0;
   double bodySum = 0, prevBody = 0;
   for(int i = 1; i <= MathMax(UltraMomentumBars, 3); i++)
   {
      double o = iOpen(s, tf, i), c = iClose(s, tf, i);
      double b = MathAbs(c - o);
      if(c > o) up++; if(c < o) dn++;
      if(i == 1) prevBody = b; else bodySum += b;
   }
   u.mom.momBuy = (up >= 2); u.mom.momSell = (dn >= 2);
   u.mom.direction = (up > dn) ? 1 : (dn > up ? -1 : 0);
   u.mom.strength = MathMin(100, (int)MathRound(100.0 * MathMax(up, dn) / MathMax(UltraMomentumBars, 3)));
   double avgPrev = bodySum / MathMax(UltraMomentumBars - 1, 1);
   u.mom.acceleration = (avgPrev > 0 && prevBody > avgPrev * 1.25) ? 80 : ((avgPrev > 0 && prevBody < avgPrev * 0.75) ? 30 : 55);
   u.mom.quality = (u.mom.strength + u.mom.acceleration) / 2;
   u.mom.confirmation = (u.mom.momBuy && u.ict.dispBuy) || (u.mom.momSell && u.ict.dispSell) ? 80 : 45;
}

void UltraEngVolatility(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   u.vol.atr = UltraATR(s, ATR_Period);
   if(u.vol.atr <= 0) return;
   double avg = 0.0;
   for(int i = 2; i <= 21; i++) avg += (iHigh(s, tf, i) - iLow(s, tf, i));
   avg /= 20.0;
   double r1 = iHigh(s, tf, 1) - iLow(s, tf, 1);
   u.vol.relative = (avg > 0) ? (r1 / avg) : 1.0;
   u.vol.expansion = (u.vol.relative >= 1.35);
   u.vol.compression = (u.vol.relative <= 0.70);
   if(u.vol.expansion) u.vol.classification = 1;
   else if(u.vol.compression) u.vol.classification = -1;
   else u.vol.classification = 0;
}

void UltraEngRegime(UltraSnap &u)
{
   if(u.vol.compression && !(u.trend.bull || u.trend.bear)) u.regime = UREG_COMPRESSION;
   else if(u.vol.expansion && (u.choch.buy || u.choch.sell)) u.regime = UREG_REVERSAL;
   else if(u.vol.expansion && u.trend.strength >= 70) u.regime = UREG_EXPANSION;
   else if(u.trend.strength >= 75 && u.st.continuation) u.regime = UREG_STRONG_TREND;
   else if(u.trend.strength >= 55 && u.st.continuation) u.regime = UREG_HEALTHY_TREND;
   else if(u.trend.strength >= 40 && (u.trend.bull || u.trend.bear)) u.regime = UREG_WEAK_TREND;
   else if(u.liq.sweepBuy && u.ict.inDiscount && !u.trend.htfBear) u.regime = UREG_ACCUMULATION;
   else if(u.liq.sweepSell && u.ict.inPremium && !u.trend.htfBull) u.regime = UREG_DISTRIBUTION;
   else if(u.mom.acceleration <= 30 && u.vol.expansion) u.regime = UREG_EXHAUSTION;
   else u.regime = UREG_RANGE;
}

string UltraRegimeName(const ENUM_ULTRA_REGIME r)
{
   switch(r)
   {
      case UREG_STRONG_TREND: return "STRONG_TREND";
      case UREG_WEAK_TREND: return "WEAK_TREND";
      case UREG_HEALTHY_TREND: return "HEALTHY_TREND";
      case UREG_RANGE: return "RANGE";
      case UREG_COMPRESSION: return "COMPRESSION";
      case UREG_EXPANSION: return "EXPANSION";
      case UREG_REVERSAL: return "REVERSAL";
      case UREG_ACCUMULATION: return "ACCUMULATION";
      case UREG_DISTRIBUTION: return "DISTRIBUTION";
      case UREG_EXHAUSTION: return "EXHAUSTION";
   }
   return "RANGE";
}

//--------------------------------------------------------------------//
// 3. SESSION / NEWS INTELLIGENCE (never blocks)
//--------------------------------------------------------------------//

void UltraEngSessionNews(const string s, UltraSnap &u)
{
   u.ctx.session = "OFF";
   if(UltraSessionIntelEnabled)
   {
      MqlDateTime t; TimeToStruct(TimeGMT(), t);
      int h = t.hour;
      u.ctx.asia = (h >= 0 && h < 7);
      u.ctx.london = (h >= 7 && h < 16);
      u.ctx.newyork = (h >= 12 && h < 21);
      u.ctx.overlap = (u.ctx.london && u.ctx.newyork);
      u.ctx.killZone = (u.ctx.london || u.ctx.newyork);
      if(u.ctx.overlap) u.ctx.session = "LONDON/NY";
      else if(u.ctx.london) u.ctx.session = "LONDON";
      else if(u.ctx.newyork) u.ctx.session = "NEW YORK";
      else if(u.ctx.asia) u.ctx.session = "ASIA";
      else u.ctx.session = "OTHER";
      u.ctx.sessionConfidence = u.ctx.overlap ? 90 : (u.ctx.killZone ? 75 : 50);
      u.ctx.sessionQuality = u.ctx.sessionConfidence;
   }
   if(UltraNewsIntelEnabled)
   {
      u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
      u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
      u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
      u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   }
   u.ctx.spreadPts = (double)SymbolInfoInteger(s, SYMBOL_SPREAD);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);
   // UltraTrade24x5 / never blocks — no return false path here
}

//--------------------------------------------------------------------//
// 4. PROPRIETARY INDICATORS — SMI / MEO / IFI
//--------------------------------------------------------------------//

void UltraEngIndicators(const string s, UltraSnap &u)
{
   // SMI: direction * momentum * acceleration scaled -100..100
   double dir = (double)u.mom.direction;
   double smi = dir * (0.45 * u.mom.strength + 0.35 * u.mom.acceleration + 0.20 * u.mom.confirmation);
   if(smi > 100) smi = 100; if(smi < -100) smi = -100;
   u.ind.smi = smi;

   // MEO: market energy / participation / trend energy 0..100
   double energy = 0.35 * (u.vol.relative * 40.0) + 0.35 * u.trend.strength + 0.30 * u.liq.quality;
   if(energy < 0) energy = 0; if(energy > 100) energy = 100;
   u.ind.meo = energy;

   // IFI: institutional footprint from sweep+disp+OB/FVG+vol expand
   double ifi = 0;
   if(u.liq.sweepBuy || u.ict.dispBuy || u.ict.obBuy || u.ict.fvgBuy) ifi += 25;
   if(u.liq.sweepSell || u.ict.dispSell || u.ict.obSell || u.ict.fvgSell) ifi -= 25;
   if(u.ict.smConfluence) ifi += (u.ict.dispBuy ? 20 : -20);
   if(u.vol.expansion) ifi += (ifi >= 0 ? 15 : -15);
   if(ifi > 100) ifi = 100; if(ifi < -100) ifi = -100;
   u.ind.ifi = ifi;
}

//--------------------------------------------------------------------//
// 5. CONFLUENCE / PROBABILITY / PRECISION / AI DECISION
//--------------------------------------------------------------------//

#endif
