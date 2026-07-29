#ifndef SNIPER_ULTRA_18_NEWSINTELLIGENCE_MQH
#define SNIPER_ULTRA_18_NEWSINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 18_NEWS_INTELLIGENCE                            |
//| Economic Calendar proxy · News Analysis · Volatility Analysis     |
//| Context Only · Trades Before / During / After News                |
//| NEVER hard-blocks                                                 |
//+------------------------------------------------------------------+

void UltraEngNews(const string s, UltraSnap &u)
{
   u.ctx.beforeNews = false;
   u.ctx.duringNews = false;
   u.ctx.afterNews  = false;
   u.ctx.newsPhase  = "NONE";
   if(!UltraNewsIntelEnabled) return;

   // Volatility / spread proxy for calendar impact (no external calendar required)
   u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
   u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
   u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
   u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   u.ctx.spreadPts = UltraData_Spread(s);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);

   // Phase classification from relative vol + expansion state
   if(u.ctx.highImpactProxy && u.vol.expansion)
   {
      u.ctx.duringNews = true;
      u.ctx.newsPhase  = "DURING";
   }
   else if(u.ctx.midImpactProxy && !u.vol.compression)
   {
      u.ctx.beforeNews = true;
      u.ctx.newsPhase  = "BEFORE";
   }
   else if(u.vol.compression && u.vol.relative >= 1.10)
   {
      u.ctx.afterNews = true;
      u.ctx.newsPhase = "AFTER";
   }

   // Context only — trading continues before / during / after
}

#endif // SNIPER_ULTRA_18_NEWSINTELLIGENCE_MQH
