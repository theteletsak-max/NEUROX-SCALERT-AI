#ifndef SNIPER_ULTRA_17_SESSIONINTELLIGENCE_MQH
#define SNIPER_ULTRA_17_SESSIONINTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 17_SESSION_INTELLIGENCE — Asia/London/NY · 24/5 · Never blocks
//+------------------------------------------------------------------+

void UltraEngSession(const string s, UltraSnap &u)
{
   u.ctx.session = "OFF";
   if(!UltraSessionIntelEnabled) return;
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
   // Never blocks trading
}

// Compatibility wrapper
void UltraEngSessionNews(const string s, UltraSnap &u)
{
   UltraEngSession(s, u);
   UltraEngNews(s, u);
}

#endif // SNIPER_ULTRA_17_SESSIONINTELLIGENCE_MQH
