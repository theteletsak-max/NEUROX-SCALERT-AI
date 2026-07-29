#ifndef HITMAN_ULTRA_17_SESSIONINTELLIGENCE_MQH
#define HITMAN_ULTRA_17_SESSIONINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 17_SESSION_INTELLIGENCE                         |
//| Asian · London · New York · Overlap · Session Liquidity           |
//| Context Only · Trades 24/5 · NEVER blocks                         |
//+------------------------------------------------------------------+

void UltraEngSession(const string s, UltraSnap &u)
{
   u.ctx.session = "OFF";
   u.ctx.asia = u.ctx.london = u.ctx.newyork = u.ctx.overlap = false;
   u.ctx.killZone = false;
   u.ctx.sessionLiquidity = false;
   u.ctx.sessionConfidence = 0;
   u.ctx.sessionQuality = 0;
   if(!UltraSessionIntelEnabled) return;

   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   int h = t.hour;
   u.ctx.asia    = (h >= 0 && h < 7);
   u.ctx.london  = (h >= 7 && h < 16);
   u.ctx.newyork = (h >= 12 && h < 21);
   u.ctx.overlap = (u.ctx.london && u.ctx.newyork);
   u.ctx.killZone = (u.ctx.london || u.ctx.newyork);
   u.ctx.sessionLiquidity = (u.ctx.overlap || u.ctx.killZone);

   if(u.ctx.overlap)        u.ctx.session = "LONDON/NY";
   else if(u.ctx.london)    u.ctx.session = "LONDON";
   else if(u.ctx.newyork)   u.ctx.session = "NEW YORK";
   else if(u.ctx.asia)      u.ctx.session = "ASIA";
   else                     u.ctx.session = "OTHER";

   u.ctx.sessionConfidence = u.ctx.overlap ? 90 : (u.ctx.killZone ? 75 : (u.ctx.asia ? 55 : 45));
   u.ctx.sessionQuality = u.ctx.sessionConfidence;
   // UltraTrade24x5 / context — never rejects trades
}

void UltraEngSessionNews(const string s, UltraSnap &u)
{
   UltraEngSession(s, u);
   UltraEngNews(s, u);
}

#endif // HITMAN_ULTRA_17_SESSIONINTELLIGENCE_MQH
