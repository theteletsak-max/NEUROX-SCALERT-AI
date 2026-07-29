#ifndef SNIPER_AI_ULTRA_09_TREND_MQH
#define SNIPER_AI_ULTRA_09_TREND_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 09_TREND — Adaptive Trend · Strength · Persistence
//+------------------------------------------------------------------+
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

#endif // SNIPER_AI_ULTRA_09_TREND_MQH
