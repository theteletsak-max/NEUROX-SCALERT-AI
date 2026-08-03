#ifndef HITMAN_ULTRA_18_NEWSINTELLIGENCE_MQH
#define HITMAN_ULTRA_18_NEWSINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 5 · NEWS INTELLIGENCE ENGINE     |
//| Event detect · classify · mode · vol/spread/liq intelligence     |
//| NEVER trades · NEVER executes · NEVER overrides strategy/Mission |
//| ONLY provides market intelligence (context outputs)              |
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
   return (t.day >= 1 && t.day <= 7);
}

//--------------------------------------------------------------------//
// EVENT DETECTION — NFP · CPI · FOMC · Rates · GDP · PMI · EMP · Speech
//--------------------------------------------------------------------//
string UltraNews_ClassifyEvent(const MqlDateTime &t, const bool highImpact, const bool midImpact)
{
   int h = t.hour;
   int dow = t.day_of_week; // 0=Sun .. 5=Fri

   // NFP / employment — first Friday ~12:30–15:00 GMT
   if(UltraNews_IsFirstFridayGMT(t) && h >= 12 && h <= 15)
      return "NFP";

   // FOMC / interest rate decision — Wed ~17:00–20:00 GMT
   if(dow == 3 && h >= 17 && h <= 20 && (highImpact || midImpact))
      return "FOMC";

   // US data dump — CPI / employment / retail ~12:30 GMT
   if(h >= 12 && h <= 14 && (highImpact || midImpact) && dow >= 1 && dow <= 5)
   {
      if(highImpact) return "CPI";
      return "EMP";
   }

   // EU PMI / GDP soft window ~08:00–10:00 GMT
   if(h >= 8 && h <= 10 && (midImpact || highImpact) && dow >= 1 && dow <= 5)
   {
      if(highImpact) return "GDP";
      return "PMI";
   }

   // Central bank speeches / rates spillover — London/NY afternoon
   if(h >= 14 && h <= 18 && highImpact)
      return "SPEECH";

   // Emergency / extreme vol without calendar class
   if(highImpact) return "MAJOR";
   if(midImpact)  return "MAJOR";
   return "NONE";
}

//--------------------------------------------------------------------//
// EVENT CLASSIFICATION — LOW → MEDIUM → HIGH → EXTREME (never blocks)
//--------------------------------------------------------------------//
string UltraNews_IntensityName(const int impact)
{
   if(impact >= 4) return "EXTREME";
   if(impact == 3) return "HIGH";
   if(impact == 2) return "MEDIUM";
   if(impact == 1) return "LOW";
   return "NONE";
}

int UltraNews_ClassifyIntensity(const UltraSnap &u, const bool calendarHit)
{
   // EXTREME — explosive vol + expansion (+ calendar or major class)
   if(u.vol.relative >= 2.20 && u.vol.expansion &&
      (calendarHit || u.ctx.eventClass == "NFP" || u.ctx.eventClass == "FOMC" ||
       u.ctx.eventClass == "MAJOR"))
      return 4;
   if(u.ctx.highImpactProxy && u.vol.expansion) return 3;
   if(u.ctx.midImpactProxy) return 2;
   if(u.ctx.lowImpactProxy || (calendarHit && u.ctx.eventImpact >= 1)) return 1;
   if(u.ctx.eventImpact > 0) return u.ctx.eventImpact;
   return 0;
}

//--------------------------------------------------------------------//
// NEWS MODE — Normal → Pre-News → Live News → Post-News
//--------------------------------------------------------------------//
string UltraNews_ModeFromPhase(const string phase)
{
   if(phase == "BEFORE") return "PRE_NEWS";
   if(phase == "DURING") return "LIVE_NEWS";
   if(phase == "AFTER")  return "POST_NEWS";
   return "NORMAL";
}

//--------------------------------------------------------------------//
// CHAPTER 5 OUTPUTS — Event / Intensity / Vol / Spread / Liq / Context
//--------------------------------------------------------------------//
void UltraNews_PublishOutputs(UltraSnap &u)
{
   // Event state (mode)
   u.ctx.eventState = UltraNews_ModeFromPhase(u.ctx.newsPhase);

   // Intensity
   bool cal = (UltraNewsExecUseCalendarContext && g_UltraCalInWindow &&
               g_UltraCalUpdated > 0 && (TimeCurrent() - g_UltraCalUpdated) <= 120);
   int impact = UltraNews_ClassifyIntensity(u, cal);
   if(impact > u.ctx.eventImpact) u.ctx.eventImpact = impact;
   u.ctx.eventIntensity = UltraNews_IntensityName(u.ctx.eventImpact);

   // Volatility state
   if(u.vol.compression) u.ctx.volatilityState = "COMPRESS";
   else if(u.vol.expansion || u.vol.relative >= 1.45) u.ctx.volatilityState = "EXPAND";
   else u.ctx.volatilityState = "NORMAL";

   // Spread state — informational only (never rejects)
   double spr = u.ctx.spreadPts;
   if(spr <= 0.0) spr = UltraData_Spread(_Symbol);
   if(spr >= UltraEventSpreadWarnPts * 2.0) u.ctx.spreadState = "EXTREME";
   else if(spr >= UltraEventSpreadWarnPts) u.ctx.spreadState = "ELEVATED";
   else u.ctx.spreadState = "STABLE";

   // Liquidity — snap/genuine liq only (EventEngine assembles later; never hard-reject)
   if(u.liq.genuineBuy || u.liq.genuineSell || u.liq.confirmedBuy || u.liq.confirmedSell)
      u.ctx.liquidityState = "RICH";
   else if(u.liq.fakeBuy || u.liq.fakeSell || u.liq.quality < 35.0)
      u.ctx.liquidityState = "THIN";
   else
      u.ctx.liquidityState = "NORMAL";

   // News context one-liner (intelligence only)
   u.ctx.newsContext = "NEWS ";
   u.ctx.newsContext += u.ctx.eventState;
   u.ctx.newsContext += " | ";
   u.ctx.newsContext += u.ctx.eventClass;
   u.ctx.newsContext += " | ";
   u.ctx.newsContext += u.ctx.eventIntensity;
   u.ctx.newsContext += " | vol=";
   u.ctx.newsContext += u.ctx.volatilityState;
   u.ctx.newsContext += " | spr=";
   u.ctx.newsContext += u.ctx.spreadState;
   u.ctx.newsContext += " | liq=";
   u.ctx.newsContext += u.ctx.liquidityState;
   if(cal && g_UltraCalHitCount > 0)
   {
      u.ctx.newsContext += " | cal=";
      u.ctx.newsContext += IntegerToString(g_UltraCalHitCount);
   }
}

string UltraNewsIntel_Dashboard()
{
   const UltraSnap u = g_UltraLastSnap;
   string t = "NEWS INTEL: ";
   if(!UltraNewsIntelEnabled) { t += "OFF"; return t; }
   if(StringLen(u.ctx.newsContext) > 0)
      t += u.ctx.newsContext;
   else
   {
      t += UltraNews_ModeFromPhase(u.ctx.newsPhase);
      t += " ";
      t += u.ctx.eventClass;
      t += " ";
      t += UltraNews_IntensityName(u.ctx.eventImpact);
   }
   return t;
}

//--------------------------------------------------------------------//
// NEWS CORE — fill UltraSnap news context (NEVER trades / NEVER blocks)
//--------------------------------------------------------------------//
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
   u.ctx.eventState = "NORMAL";
   u.ctx.eventIntensity = "NONE";
   u.ctx.volatilityState = "NORMAL";
   u.ctx.spreadState = "STABLE";
   u.ctx.liquidityState = "NORMAL";
   u.ctx.newsContext = "NEWS NORMAL | idle";
   if(!UltraNewsIntelEnabled) return;

   // VOLATILITY / SPREAD INTELLIGENCE (proxies — never sole reject)
   u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
   u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
   u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
   u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   u.ctx.spreadPts = UltraData_Spread(s);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);

   MqlDateTime gt; TimeToStruct(TimeGMT(), gt);
   u.ctx.eventClass = UltraNews_ClassifyEvent(gt, u.ctx.highImpactProxy, u.ctx.midImpactProxy);

   // NEWS MODE phases from vol + calendar window
   bool calWindow = (u.ctx.eventClass != "NONE");
   if((u.ctx.highImpactProxy && u.vol.expansion) || (calWindow && u.ctx.highImpactProxy))
   {
      u.ctx.duringNews = true;
      u.ctx.newsPhase  = "DURING"; // LIVE_NEWS
      u.ctx.eventImpact = 3;
   }
   else if(u.ctx.midImpactProxy && !u.vol.compression)
   {
      u.ctx.beforeNews = true;
      u.ctx.newsPhase  = "BEFORE"; // PRE_NEWS
      u.ctx.eventImpact = 2;
      if(u.ctx.eventClass == "NONE") u.ctx.eventClass = "MAJOR";
   }
   else if(u.vol.compression && u.vol.relative >= 1.10)
   {
      u.ctx.afterNews = true;
      u.ctx.newsPhase = "AFTER";   // POST_NEWS
      u.ctx.eventImpact = 1;
   }
   else if(calWindow && u.ctx.lowImpactProxy)
   {
      u.ctx.beforeNews = true;
      u.ctx.newsPhase = "BEFORE";
      u.ctx.eventImpact = 1;
   }

   // Wire live MQL5 calendar window (never forces / never sole-blocks)
   if(UltraNewsExecUseCalendarContext && g_UltraCalInWindow &&
      g_UltraCalUpdated > 0 && (TimeCurrent() - g_UltraCalUpdated) <= 120)
   {
      if(u.ctx.eventClass == "NONE")
         u.ctx.eventClass = "MAJOR";
      if(u.ctx.eventImpact < 2)
         u.ctx.eventImpact = 2;
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
   if(u.ctx.eventClass == "CPI" || u.ctx.eventClass == "RATES" ||
      u.ctx.eventClass == "SPEECH" || u.ctx.eventClass == "GDP") ec += 10;
   if(u.ctx.eventClass == "EMP" || u.ctx.eventClass == "PMI") ec += 6;
   if(u.ctx.newsVol) ec += 5;
   if(g_UltraCalInWindow) ec += 8;
   if(ec > 100) ec = 100;
   u.ctx.eventConfidence = ec;

   // CHAPTER 5 — publish structured intelligence outputs
   UltraNews_PublishOutputs(u);

   // LOCKS: continue analysis · never hard-block · never trade · never override Mission
}

#endif // HITMAN_ULTRA_18_NEWSINTELLIGENCE_MQH
