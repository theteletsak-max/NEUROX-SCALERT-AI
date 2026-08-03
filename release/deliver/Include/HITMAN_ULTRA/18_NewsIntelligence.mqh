#ifndef HITMAN_ULTRA_18_NEWSINTELLIGENCE_MQH
#define HITMAN_ULTRA_18_NEWSINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 18_NEWS_INTELLIGENCE                                 |
//| Event classification · Volatility / Spread / Slippage proxies    |
//| Supports: NFP · FOMC · CPI · GDP · PMI · Rates · Speeches        |
//| Context Only · Trades Before / During / After · NEVER hard-block |
//+------------------------------------------------------------------+

// Shared calendar awareness (set by Shell UpdateNewsAwareness; read by EngNews/Detect)
bool     g_UltraCalInWindow = false;
string   g_UltraCalNames = "";
int      g_UltraCalHitCount = 0;
datetime g_UltraCalUpdated = 0;

void UltraNews_SetCalendarContext(const bool inWindow, const int hitCount, const string names)
{
   g_UltraCalInWindow = inWindow;
   g_UltraCalHitCount = hitCount;
   g_UltraCalNames = names;
   g_UltraCalUpdated = TimeCurrent();
}

bool UltraNews_IsFirstFridayGMT(const MqlDateTime &t)
{
   if(t.day_of_week != 5) return false; // Friday
   // first Friday of month: day 1..7
   return (t.day >= 1 && t.day <= 7);
}

// Calendar-window proxy (no external calendar feed required).
// Classifies likely high-impact US/EU release windows in GMT.
string UltraNews_ClassifyEvent(const MqlDateTime &t, const bool highImpact, const bool midImpact)
{
   int h = t.hour;
   int dow = t.day_of_week; // 0=Sun .. 5=Fri

   // NFP — first Friday ~12:30–15:00 GMT
   if(UltraNews_IsFirstFridayGMT(t) && h >= 12 && h <= 15)
      return "NFP";

   // FOMC / rate decision window — Wed ~17:00–20:00 GMT (common)
   if(dow == 3 && h >= 17 && h <= 20 && (highImpact || midImpact))
      return "FOMC";

   // US data dump window — CPI/PPI/Retail/Unemployment ~12:30 GMT
   if(h >= 12 && h <= 14 && (highImpact || midImpact) && dow >= 1 && dow <= 5)
   {
      if(highImpact) return "CPI";
      return "MAJOR";
   }

   // EU PMI / GDP soft window ~08:00–10:00 GMT
   if(h >= 8 && h <= 10 && midImpact && dow >= 1 && dow <= 5)
      return "PMI";

   // Central bank speech / rates spillover — London/NY afternoon high vol
   if(h >= 14 && h <= 18 && highImpact)
      return "RATES";

   if(highImpact) return "MAJOR";
   if(midImpact)  return "MAJOR";
   return "NONE";
}

void UltraEngNews(const string s, UltraSnap &u)
{
   u.ctx.beforeNews = false;
   u.ctx.duringNews = false;
   u.ctx.afterNews  = false;
   u.ctx.newsPhase  = "NONE";
   u.ctx.eventClass = "NONE";
   u.ctx.eventImpact = 0;
   u.ctx.eventConfidence = 0;
   u.ctx.tickSpeed = 0;
   u.ctx.execQuality = 100;
   if(!UltraNewsIntelEnabled) return;

   // Volatility / spread proxy for calendar impact
   u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
   u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
   u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
   u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   u.ctx.spreadPts = UltraData_Spread(s);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);

   MqlDateTime gt; TimeToStruct(TimeGMT(), gt);
   u.ctx.eventClass = UltraNews_ClassifyEvent(gt, u.ctx.highImpactProxy, u.ctx.midImpactProxy);

   // Phase classification from relative vol + expansion + calendar window
   bool calWindow = (u.ctx.eventClass != "NONE");
   if((u.ctx.highImpactProxy && u.vol.expansion) || (calWindow && u.ctx.highImpactProxy))
   {
      u.ctx.duringNews = true;
      u.ctx.newsPhase  = "DURING";
      u.ctx.eventImpact = 3;
   }
   else if(u.ctx.midImpactProxy && !u.vol.compression)
   {
      u.ctx.beforeNews = true;
      u.ctx.newsPhase  = "BEFORE";
      u.ctx.eventImpact = 2;
      if(u.ctx.eventClass == "NONE") u.ctx.eventClass = "MAJOR";
   }
   else if(u.vol.compression && u.vol.relative >= 1.10)
   {
      u.ctx.afterNews = true;
      u.ctx.newsPhase = "AFTER";
      u.ctx.eventImpact = 1;
   }
   else if(calWindow && u.ctx.lowImpactProxy)
   {
      u.ctx.beforeNews = true;
      u.ctx.newsPhase = "BEFORE";
      u.ctx.eventImpact = 1;
   }

   // PHASE 1 — wire live MQL5 calendar window (never forces / never sole-blocks)
   if(UltraNewsExecUseCalendarContext && g_UltraCalInWindow &&
      g_UltraCalUpdated > 0 && (TimeCurrent() - g_UltraCalUpdated) <= 120)
   {
      if(u.ctx.eventClass == "NONE")
         u.ctx.eventClass = "MAJOR";
      if(u.ctx.eventImpact < 2)
         u.ctx.eventImpact = 2;
      // Upcoming calendar → BEFORE unless already in high-vol DURING
      if(!u.ctx.duringNews)
      {
         u.ctx.beforeNews = true;
         if(u.ctx.newsPhase == "NONE")
            u.ctx.newsPhase = "BEFORE";
      }
   }

   // Event-context confidence (informational — never a sole reject)
   int ec = 50;
   if(u.ctx.duringNews) ec = 70;
   else if(u.ctx.beforeNews) ec = 60;
   else if(u.ctx.afterNews) ec = 55;
   if(u.ctx.eventClass == "NFP" || u.ctx.eventClass == "FOMC") ec += 15;
   if(u.ctx.eventClass == "CPI" || u.ctx.eventClass == "RATES") ec += 10;
   if(u.ctx.newsVol) ec += 5;
   if(g_UltraCalInWindow) ec += 8;
   if(ec > 100) ec = 100;
   u.ctx.eventConfidence = ec;

   // Context only — trading continues before / during / after
   // Never hard-block on news phase or elevated spread alone.
}

#endif // HITMAN_ULTRA_18_NEWSINTELLIGENCE_MQH
