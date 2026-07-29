#ifndef HITMAN_ULTRA_29_MARKETMEMORY_MQH
#define HITMAN_ULTRA_29_MARKETMEMORY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 29_MARKET_MEMORY — L2 stores theses · patterns · behaviour
//+------------------------------------------------------------------+

struct UltraMemPattern
{
   string tag;
   int    wins;
   int    losses;
   int    lastConf;
   long   lastTs;
};

#define ULTRA_MEM_PAT_MAX 24
UltraMemPattern g_UltraMemPat[ULTRA_MEM_PAT_MAX];
int g_UltraMemPatN = 0;

int UltraMemory_FindPat(const string tag)
{
   for(int i = 0; i < g_UltraMemPatN; i++)
      if(g_UltraMemPat[i].tag == tag) return i;
   return -1;
}

void UltraMemory_NotePattern(const string tag, const int conf, const bool won)
{
   if(!UltraMarketMemoryEnabled) return;
   if(tag == "" || tag == "NONE") return;
   int idx = UltraMemory_FindPat(tag);
   if(idx < 0)
   {
      if(g_UltraMemPatN >= ULTRA_MEM_PAT_MAX) return;
      idx = g_UltraMemPatN++;
      g_UltraMemPat[idx].tag = tag;
      g_UltraMemPat[idx].wins = 0;
      g_UltraMemPat[idx].losses = 0;
   }
   if(won) g_UltraMemPat[idx].wins++;
   else g_UltraMemPat[idx].losses++;
   g_UltraMemPat[idx].lastConf = conf;
   g_UltraMemPat[idx].lastTs = (long)TimeCurrent();
}

void UltraMemoryUpdateFromStats()
{
   if(!UltraMarketMemoryEnabled || !UltraPerfEngineEnabled) return;
   // Soft sync from existing EA stats if available (bodies in Shell_B)
   g_UltraMem.winRate = GetWinRatePercent();
   g_UltraMem.profitFactor = GetProfitFactor();
   g_UltraMem.avgRR = GetAverageRR();
   g_UltraMem.lastSave = (long)TimeCurrent();
}

void UltraMemory_NoteDecision(const string tag, const int conf)
{
   if(!UltraMarketMemoryEnabled) return;
   UltraLogAI("memory note tag=" + tag + " conf=" + IntegerToString(conf));
   int idx = UltraMemory_FindPat(tag);
   if(idx < 0)
   {
      if(g_UltraMemPatN >= ULTRA_MEM_PAT_MAX) return;
      idx = g_UltraMemPatN++;
      g_UltraMemPat[idx].tag = tag;
      g_UltraMemPat[idx].wins = 0;
      g_UltraMemPat[idx].losses = 0;
   }
   g_UltraMemPat[idx].lastConf = conf;
   g_UltraMemPat[idx].lastTs = (long)TimeCurrent();
}

string UltraMemory_Dashboard()
{
   string t = "MEMORY: patterns=";
   t += IntegerToString(g_UltraMemPatN);
   t += " WR=";
   t += DoubleToString(g_UltraMem.winRate, 1);
   return t;
}

#endif // HITMAN_ULTRA_29_MARKETMEMORY_MQH
