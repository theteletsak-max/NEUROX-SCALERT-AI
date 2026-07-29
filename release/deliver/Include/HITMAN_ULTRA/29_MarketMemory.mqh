#ifndef HITMAN_ULTRA_29_MARKETMEMORY_MQH
#define HITMAN_ULTRA_29_MARKETMEMORY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 29_MARKET_MEMORY — History · Behaviour · Strategy analytics
//+------------------------------------------------------------------+
void UltraMemoryUpdateFromStats()
{
   if(!UltraMarketMemoryEnabled || !UltraPerfEngineEnabled) return;
   // Soft sync from existing EA stats if available
   g_UltraMem.winRate = GetWinRatePercent();
   g_UltraMem.profitFactor = GetProfitFactor();
   g_UltraMem.avgRR = GetAverageRR();
   g_UltraMem.lastSave = (long)TimeCurrent();
}

void UltraMemory_NoteDecision(const string tag, const int conf)
{
   if(!UltraMarketMemoryEnabled) return;
   UltraLogAI("memory note tag=" + tag + " conf=" + IntegerToString(conf));
}

#endif // HITMAN_ULTRA_29_MARKETMEMORY_MQH
