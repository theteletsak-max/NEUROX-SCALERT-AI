#ifndef SNIPER_ULTRA_01_CORE_MQH
#define SNIPER_ULTRA_01_CORE_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 01_CORE — Init · Loader · Config · Validation · State Controller
//+------------------------------------------------------------------+
bool UltraConfigOK()
{
   if(!UltraConfigEngineEnabled) return true;
   if(TradeComment != "SNIPER AI") return false;
   if(MaxOpenTrades < 1) return false;
   if(UltraMinConfluence < 1 || UltraMinConfluence > 100) return false;
   return true;
}
bool UltraValidateSymbol(const string s)
{
   if(!UltraValidationEnabled) return true;
   if(s == "" || !SymbolInfoInteger(s, SYMBOL_SELECT)) return false;
   if(Bars(s, UltraETF()) < 60) return false;
   return true;
}
void UltraCoreInit()
{
   g_UltraCore.loaded = false;
   g_UltraCore.configOK = false;
   g_UltraCore.dataOK = false;
   g_UltraCore.validated = false;
   g_UltraCore.healthy = false;
   g_UltraCore.lastCycleMs = 0;
   g_UltraCore.lastLatencyMs = 0;
   g_UltraCore.errorCount = 0;
   g_UltraCore.recoveryCount = 0;
   g_UltraCore.lastError = "";
   g_UltraMem.trades = 0;
   g_UltraMem.wins = 0;
   g_UltraMem.profitSum = 0;
   g_UltraMem.lossSum = 0;
   g_UltraMem.avgRR = 0;
   g_UltraMem.winRate = 0;
   g_UltraMem.profitFactor = 0;
   g_UltraMem.expectancy = 0;
   g_UltraMem.lastSave = 0;
   g_UltraCore.loaded = true;
   g_UltraCore.configOK = UltraConfigOK();
   g_UltraCore.healthy = g_UltraCore.configOK;
   UltraLog("CORE loaded configOK=" + (string)g_UltraCore.configOK);
}

void UltraSystemController_Boot()
{
   UltraCoreInit();
   if(!UltraConfigOK())
      UltraSetError("config validation failed at boot");
}

#endif // SNIPER_ULTRA_01_CORE_MQH
