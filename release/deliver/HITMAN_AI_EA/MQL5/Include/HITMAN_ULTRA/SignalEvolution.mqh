#ifndef HITMAN_ULTRA_SIGNAL_EVOLUTION_MQH
#define HITMAN_ULTRA_SIGNAL_EVOLUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 3 SIGNAL EVOLUTION ENGINE                      |
//| Improvement / weakening / correction / true reversal / stability |
//+------------------------------------------------------------------+

enum ENUM_SIGNAL_EVOLUTION
{
   SEVO_IMPROVING = 0,
   SEVO_STABLE,
   SEVO_WEAKENING,
   SEVO_CORRECTION,
   SEVO_REVERSAL,
   SEVO_UNKNOWN
};

struct UltraSignalEvo
{
   ENUM_SIGNAL_EVOLUTION state;
   int stability;      // 0-100
   int deltaConf;      // confidence change
   string label;
};

int g_Evo_PrevConf = 0;
int g_Evo_PrevDir = 0;
datetime g_Evo_PrevBar = 0;

string UltraEvo_Name(const ENUM_SIGNAL_EVOLUTION e)
{
   if(e == SEVO_IMPROVING) return "IMPROVING";
   if(e == SEVO_STABLE) return "STABLE";
   if(e == SEVO_WEAKENING) return "WEAKENING";
   if(e == SEVO_CORRECTION) return "CORRECTION";
   if(e == SEVO_REVERSAL) return "REVERSAL";
   return "UNKNOWN";
}

string g_Evo_PrevSym = "";

UltraSignalEvo UltraEvo_Evaluate(const string s, const UltraSnap &u, const bool buySide)
{
   UltraSignalEvo e;
   e.state = SEVO_UNKNOWN;
   e.stability = 50;
   e.deltaConf = 0;
   e.label = "UNKNOWN";
   if(!UltraUpgradeEnabled || !UltraSignalEvoEnabled) { e.state = SEVO_STABLE; e.label = "STABLE"; return e; }

   int dir = buySide ? 1 : -1;
   int conf = u.score.confidence;
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar <= 0) bar = TimeCurrent();
   e.deltaConf = conf - g_Evo_PrevConf;

   bool against = buySide
      ? (u.bos.sell && u.bos.confirmed) || (u.choch.sell && u.choch.majorC)
      : (u.bos.buy && u.bos.confirmed) || (u.choch.buy && u.choch.majorC);
   bool softPull = buySide
      ? (u.mom.weakness || u.ind.smi < 0) && !against
      : (u.mom.weakness || u.ind.smi > 0) && !against;

   if(against && u.trend.exhaustion)
      e.state = SEVO_REVERSAL;
   else if(softPull)
      e.state = SEVO_CORRECTION;
   else if(e.deltaConf >= 5 && g_Evo_PrevDir == dir)
      e.state = SEVO_IMPROVING;
   else if(e.deltaConf <= -8)
      e.state = SEVO_WEAKENING;
   else
      e.state = SEVO_STABLE;

   e.stability = UltraUSM2_Clamp(60 + e.deltaConf);
   if(e.state == SEVO_REVERSAL) e.stability = 15;
   if(e.state == SEVO_CORRECTION) e.stability = 45;
   e.label = UltraEvo_Name(e.state);

   if(bar != g_Evo_PrevBar || s != g_Evo_PrevSym)
   {
      g_Evo_PrevConf = conf;
      g_Evo_PrevDir = dir;
      g_Evo_PrevBar = bar;
      g_Evo_PrevSym = s;
   }
   return e;
}

#endif
