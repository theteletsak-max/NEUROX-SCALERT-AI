#ifndef HITMAN_ULTRA_27_LOGGER_MQH
#define HITMAN_ULTRA_27_LOGGER_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 27_LOGGER — Error · Trade · AI · Execution · System logs
//+------------------------------------------------------------------+
void UltraLog(const string msg)
{
   if(UltraLoggingEnabled)
      Print("ULTRA| ", msg);
}
void UltraSetError(const string e)
{
   if(!UltraErrorHandlingEnabled) return;
   g_UltraCore.errorCount++;
   g_UltraCore.lastError = e;
   UltraLog("ERR " + e);
}

void UltraLogTrade(const string msg){ UltraLog("TRADE| " + msg); }
void UltraLogAI(const string msg){ UltraLog("AI| " + msg); }
void UltraLogExec(const string msg){ UltraLog("EXEC| " + msg); }
void UltraLogPerf(const string msg){ UltraLog("PERF| " + msg); }

#endif // HITMAN_ULTRA_27_LOGGER_MQH
