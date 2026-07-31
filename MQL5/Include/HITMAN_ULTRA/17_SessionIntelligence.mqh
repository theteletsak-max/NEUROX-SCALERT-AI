#ifndef HITMAN_ULTRA_17_SESSIONINTELLIGENCE_MQH
#define HITMAN_ULTRA_17_SESSIONINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 17_ULTRA SESSION INTELLIGENCE ENGINE ∞ (Phase 16.5)  |
//| Sydney · Tokyo · London · New York · London Open · Overlap       |
//| Intelligence only · Active 24/7 · NEVER blocks · NEVER forces    |
//+------------------------------------------------------------------+

struct UltraSessionStats
{
   ulong scans;
   ulong londonOpenHits;
   ulong overlapHits;
   ulong asianHits;
   string lastWindow;
   int    lastBias;
};

UltraSessionStats g_UltraSessionStats;

//--------------------------------------------------------------------//
// Automatic Daylight Saving — London (EU) approximate                //
// Last Sunday of March → last Sunday of October = BST (GMT+1)        //
//--------------------------------------------------------------------//
int UltraSession_LastSundayDay(const int year, const int month)
{
   // day-of-month of last Sunday (MQL5: day_of_week 0=Sunday)
   int daysInMonth = 31;
   if(month == 4 || month == 6 || month == 9 || month == 11) daysInMonth = 30;
   if(month == 2)
   {
      bool leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0));
      daysInMonth = leap ? 29 : 28;
   }
   MqlDateTime lastDt;
   ZeroMemory(lastDt);
   lastDt.year = year; lastDt.mon = month; lastDt.day = daysInMonth;
   lastDt.hour = 12; lastDt.min = 0; lastDt.sec = 0;
   datetime lastTs = StructToTime(lastDt);
   MqlDateTime lt; TimeToStruct(lastTs, lt);
   return daysInMonth - lt.day_of_week; // rewind to Sunday
}

bool UltraSession_IsLondonDST(const datetime gmtNow)
{
   MqlDateTime t; TimeToStruct(gmtNow, t);
   int y = t.year;
   int startDay = UltraSession_LastSundayDay(y, 3);
   int endDay   = UltraSession_LastSundayDay(y, 10);

   MqlDateTime sdt; ZeroMemory(sdt);
   sdt.year = y; sdt.mon = 3; sdt.day = startDay;
   sdt.hour = 1; sdt.min = 0; sdt.sec = 0; // 01:00 GMT
   datetime start = StructToTime(sdt);

   MqlDateTime edt; ZeroMemory(edt);
   edt.year = y; edt.mon = 10; edt.day = endDay;
   edt.hour = 1; edt.min = 0; edt.sec = 0;
   datetime endt = StructToTime(edt);

   return (gmtNow >= start && gmtNow < endt);
}

int UltraSession_LondonOffsetGMT()
{
   if(UltraSessionTZOverride != -99)
      return UltraSessionTZOverride;
   if(!UltraSessionAutoDST)
      return 0;
   return UltraSession_IsLondonDST(TimeGMT()) ? 1 : 0;
}

int UltraSession_LondonHour()
{
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   int h = t.hour + UltraSession_LondonOffsetGMT();
   if(h >= 24) h -= 24;
   if(h < 0) h += 24;
   return h;
}

int UltraSession_Clamp(const int v, const int lo, const int hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

//--------------------------------------------------------------------//
// Window detection (London local clock)                              //
// London Open 09-11 ★★★★★ · Cont 11-14 ★★★★ · Overlap 14-18 ★★★★★  //
// NY Cont 18-23 ★★★★ · Asian 23-09 ★★★                              //
//--------------------------------------------------------------------//
void UltraSession_DetectWindow(const int lh, UltraSnap &u)
{
   u.ctx.sydney = u.ctx.tokyo = u.ctx.asia = false;
   u.ctx.london = u.ctx.newyork = u.ctx.overlap = false;
   u.ctx.londonOpen = u.ctx.londonCont = u.ctx.nyCont = false;
   u.ctx.killZone = false;
   u.ctx.sessionLiquidity = false;
   u.ctx.sessionTransition = false;
   u.ctx.sessionPriority = 3;
   u.ctx.session = "ASIAN";
   u.ctx.sessionRegion = "Tokyo";

   // Region overlays (GMT-based approximations)
   MqlDateTime gt; TimeToStruct(TimeGMT(), gt);
   int gh = gt.hour;
   u.ctx.sydney = (gh >= 21 || gh < 6);   // ~Sydney cash hours
   u.ctx.tokyo  = (gh >= 0 && gh < 9);    // Tokyo cash hours
   u.ctx.asia   = (lh >= 23 || lh < 9);

   if(lh >= 9 && lh < 11)
   {
      u.ctx.londonOpen = true;
      u.ctx.london = true;
      u.ctx.killZone = true;
      u.ctx.sessionLiquidity = true;
      u.ctx.sessionPriority = 5;
      u.ctx.session = "LONDON_OPEN";
      u.ctx.sessionRegion = "London";
   }
   else if(lh >= 11 && lh < 14)
   {
      u.ctx.londonCont = true;
      u.ctx.london = true;
      u.ctx.killZone = true;
      u.ctx.sessionLiquidity = true;
      u.ctx.sessionPriority = 4;
      u.ctx.session = "LONDON_CONT";
      u.ctx.sessionRegion = "London";
   }
   else if(lh >= 14 && lh < 18)
   {
      u.ctx.overlap = true;
      u.ctx.london = true;
      u.ctx.newyork = true;
      u.ctx.killZone = true;
      u.ctx.sessionLiquidity = true;
      u.ctx.sessionPriority = 5;
      u.ctx.session = "LONDON_NY_OVERLAP";
      u.ctx.sessionRegion = "Overlap";
   }
   else if(lh >= 18 && lh < 23)
   {
      u.ctx.nyCont = true;
      u.ctx.newyork = true;
      u.ctx.killZone = true;
      u.ctx.sessionLiquidity = true;
      u.ctx.sessionPriority = 4;
      u.ctx.session = "NY_CONT";
      u.ctx.sessionRegion = "NewYork";
   }
   else
   {
      // Asian 23:00 → 09:00
      u.ctx.asia = true;
      u.ctx.sessionPriority = 3;
      if(u.ctx.sydney && !u.ctx.tokyo)
      {
         u.ctx.session = "SYDNEY";
         u.ctx.sessionRegion = "Sydney";
      }
      else if(u.ctx.tokyo)
      {
         u.ctx.session = "TOKYO";
         u.ctx.sessionRegion = "Tokyo";
      }
      else
      {
         u.ctx.session = "ASIAN";
         u.ctx.sessionRegion = "Tokyo";
      }
   }

   // Transition: within 15 minutes of hour boundary into next window
   MqlDateTime tmin; TimeToStruct(TimeGMT(), tmin);
   if(tmin.min >= 55 || tmin.min <= 5)
      u.ctx.sessionTransition = true;
}

//--------------------------------------------------------------------//
// Session intelligence scores (analysis — never gates)               //
//--------------------------------------------------------------------//
void UltraSession_Analyze(const string s, UltraSnap &u)
{
   // Base confidence from priority stars
   int base = 50;
   if(u.ctx.sessionPriority >= 5) base = 92;
   else if(u.ctx.sessionPriority == 4) base = 80;
   else if(u.ctx.sessionPriority == 3) base = 58;
   else base = 50;
   if(u.ctx.overlap) base = MathMax(base, 95);
   if(u.ctx.londonOpen) base = MathMax(base, 92);

   // Liquidity analysis
   int liq = 40;
   if(u.ctx.sessionLiquidity) liq += 25;
   if(u.ctx.overlap || u.ctx.londonOpen) liq += 20;
   if(u.liq.genuineBuy || u.liq.genuineSell) liq += 10;
   if(u.liq.quality >= 55) liq += 8;
   if(u.ctx.asia && !u.ctx.sessionLiquidity) liq -= 10;
   if(u.liq.fakeBuy || u.liq.fakeSell) liq -= 12;
   u.ctx.sessionLiqScore = UltraSession_Clamp(liq, 0, 100);

   // Volatility analysis
   int vs = 45;
   if(u.vol.expansion) vs += 20;
   if(u.vol.relative >= 1.5) vs += 15;
   if(u.vol.compression) vs -= 10;
   if(u.ctx.asia && u.vol.compression) vs -= 8;
   u.ctx.sessionVolScore = UltraSession_Clamp(vs, 0, 100);

   // Momentum analysis
   int ms = 40;
   if(u.mom.impulse) ms += 20;
   if(u.mom.momBuy || u.mom.momSell) ms += 15;
   ms += u.mom.strength / 5;
   if(u.mom.weakness) ms -= 12;
   u.ctx.sessionMomScore = UltraSession_Clamp(ms, 0, 100);

   // Trend quality
   int ts = 40;
   if(u.trend.bull || u.trend.bear) ts += 15;
   if(u.trend.htfBull || u.trend.htfBear) ts += 15;
   ts += u.trend.quality / 5;
   ts += u.trend.persistence / 6;
   if(u.trend.exhaustion) ts -= 10;
   u.ctx.sessionTrendScore = UltraSession_Clamp(ts, 0, 100);

   // Spread behaviour (higher = healthier)
   int ss = 70;
   if(u.ctx.spreadPts > UltraEventSpreadWarnPts) ss -= 20;
   else if(u.ctx.spreadPts > UltraEventSpreadWarnPts * 0.6) ss -= 10;
   if(u.ctx.overlap || u.ctx.londonOpen) ss += 10;
   if(u.ctx.asia && u.ctx.spreadPts > 25) ss -= 10;
   u.ctx.sessionSpreadScore = UltraSession_Clamp(ss, 0, 100);

   // Execution analysis (terminal + tick flow)
   int es = 65;
   if((bool)TerminalInfoInteger(TERMINAL_CONNECTED) &&
      (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      es += 15;
   if(u.ctx.tickSpeed >= 1.5) es += 10;
   else if(u.ctx.tickSpeed > 0.0 && u.ctx.tickSpeed < 0.25) es -= 12;
   if(u.ctx.sessionSpreadScore < 45) es -= 10;
   u.ctx.sessionExecScore = UltraSession_Clamp(es, 0, 100);

   // Composite session quality / confidence
   int qual = (base * 40 + u.ctx.sessionLiqScore * 20 + u.ctx.sessionTrendScore * 15 +
               u.ctx.sessionMomScore * 10 + u.ctx.sessionVolScore * 8 +
               u.ctx.sessionSpreadScore * 4 + u.ctx.sessionExecScore * 3) / 100;
   if(u.ctx.sessionTransition) qual -= 4; // mild — transition noise
   if(UltraBoostKillZone && u.ctx.killZone) qual += 3;
   u.ctx.sessionQuality = UltraSession_Clamp(qual, 0, 100);
   u.ctx.sessionConfidence = u.ctx.sessionQuality;

   // Soft bias for USM2 — never gates, never forces
   int bias = 0;
   if(UltraSessionBoostOpen && (u.ctx.londonOpen || u.ctx.overlap))
      bias += 6;
   if(u.ctx.londonCont || u.ctx.nyCont)
      bias += 3;
   if(UltraSessionPenalizeWeakLiq && u.ctx.sessionLiqScore < 45)
      bias -= 5;
   if(u.ctx.asia && u.ctx.sessionLiqScore < 50)
      bias -= 3;
   if(u.ctx.sessionSpreadScore < 40)
      bias -= 2;
   if(u.ctx.sessionLiqScore >= 75 && (u.ctx.overlap || u.ctx.londonOpen))
      bias += 4;

   int maxB = UltraSessionMaxBoost;
   int maxP = UltraSessionMaxPenalty;
   if(maxB < 0) maxB = 0;
   if(maxP < 0) maxP = 0;
   bias = UltraSession_Clamp(bias, -maxP, maxB);
   u.ctx.sessionBias = bias;

   g_UltraSessionStats.scans++;
   g_UltraSessionStats.lastWindow = u.ctx.session;
   g_UltraSessionStats.lastBias = bias;
   if(u.ctx.londonOpen) g_UltraSessionStats.londonOpenHits++;
   if(u.ctx.overlap) g_UltraSessionStats.overlapHits++;
   if(u.ctx.asia) g_UltraSessionStats.asianHits++;
}

void UltraEngSession(const string s, UltraSnap &u)
{
   u.ctx.session = "OFF";
   u.ctx.sessionRegion = "OFF";
   u.ctx.sydney = u.ctx.tokyo = u.ctx.asia = u.ctx.london = u.ctx.newyork = u.ctx.overlap = false;
   u.ctx.londonOpen = u.ctx.londonCont = u.ctx.nyCont = false;
   u.ctx.killZone = false;
   u.ctx.sessionLiquidity = false;
   u.ctx.sessionTransition = false;
   u.ctx.sessionPriority = 0;
   u.ctx.sessionConfidence = 0;
   u.ctx.sessionQuality = 0;
   u.ctx.sessionLiqScore = u.ctx.sessionVolScore = u.ctx.sessionMomScore = 0;
   u.ctx.sessionTrendScore = u.ctx.sessionSpreadScore = u.ctx.sessionExecScore = 0;
   u.ctx.sessionBias = 0;
   u.ctx.londonHour = 0;

   if(!UltraSessionIntelEnabled && !UltraSessionEngineEnabled)
      return;

   // PHASE 16.5 — always active 24/7; sessions are intelligence only
   int lh = UltraSession_LondonHour();
   u.ctx.londonHour = lh;
   UltraSession_DetectWindow(lh, u);

   // Need spread for session spread score (news engine may fill later — use data now)
   if(u.ctx.spreadPts <= 0.0)
      u.ctx.spreadPts = UltraData_Spread(s);

   UltraSession_Analyze(s, u);

   if(UltraSessionLog)
   {
      UltraLog("SESSION " + u.ctx.session +
               " region=" + u.ctx.sessionRegion +
               " LH=" + IntegerToString(u.ctx.londonHour) +
               " pri=" + IntegerToString(u.ctx.sessionPriority) +
               " conf=" + IntegerToString(u.ctx.sessionConfidence) +
               " bias=" + IntegerToString(u.ctx.sessionBias) +
               " liq=" + IntegerToString(u.ctx.sessionLiqScore) +
               " | never blocks");
   }
   // UltraSessionAlwaysActive / no session restrictions — never rejects
}

// Soft intelligence helper for scoring (never used as a hard gate)
int UltraSession_ConfidenceBias(const UltraSnap &u)
{
   if(!UltraSessionEngineEnabled) return 0;
   return u.ctx.sessionBias;
}

bool UltraSession_AllowTrade()
{
   // RULES: No session restrictions · No automatic session blocking
   // Session never overrides strategy — always allow path to continue
   return true;
}

string UltraSession_Dashboard()
{
   string t = "SESSION: ";
   t += g_UltraSessionStats.lastWindow;
   t += " bias=";
   t += IntegerToString(g_UltraSessionStats.lastBias);
   t += " openHits=";
   t += IntegerToString((int)g_UltraSessionStats.londonOpenHits);
   t += " ovlp=";
   t += IntegerToString((int)g_UltraSessionStats.overlapHits);
   return t;
}

void UltraEngSessionNews(const string s, UltraSnap &u)
{
   UltraEngSession(s, u);
   UltraEngNews(s, u);
   // Re-run session spread/exec with fresh news spread if needed
   if(UltraSessionEngineEnabled || UltraSessionIntelEnabled)
      UltraSession_Analyze(s, u);
}

#endif // HITMAN_ULTRA_17_SESSIONINTELLIGENCE_MQH
