#ifndef SNIPER_AI_ULTRA_18_NEWSINTELLIGENCE_MQH
#define SNIPER_AI_ULTRA_18_NEWSINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 18_NEWS_INTELLIGENCE — Impact proxy · Vol/Spread/Slip · Never blocks
//+------------------------------------------------------------------+

void UltraEngNews(const string s, UltraSnap &u)
{
   if(!UltraNewsIntelEnabled) return;
   u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
   u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
   u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
   u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   u.ctx.spreadPts = UltraData_Spread(s);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);
   // Trades before/during/after news — NEVER blocks
}

#endif // SNIPER_AI_ULTRA_18_NEWSINTELLIGENCE_MQH
