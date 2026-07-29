#ifndef HITMAN_ULTRA_40_DEBUG_MQH
#define HITMAN_ULTRA_40_DEBUG_MQH
//+------------------------------------------------------------------+
//| 40_DebugTools — asserts · timers · diagnostic helpers           |
//+------------------------------------------------------------------+


long g_UltraDebugTimerStart = 0;

void UltraDebug_Msg(const string msg)
{
   if(!UltraDebugEnabled) return;
   Print("ULTRA-DEBUG| ", msg);
}

void UltraDebug_Assert(const bool cond, const string msg)
{
   if(cond) return;
   UltraSetError("ASSERT " + msg);
   if(UltraDebugEnabled) Print("ULTRA-ASSERT FAILED| ", msg);
}

void UltraDebug_TimerStart()
{
   g_UltraDebugTimerStart = (long)GetTickCount();
}

long UltraDebug_TimerElapsedMs()
{
   if(g_UltraDebugTimerStart <= 0) return 0;
   return (long)GetTickCount() - g_UltraDebugTimerStart;
}

void UltraDebug_DumpSnapshot(const string s)
{
   if(!UltraDebugEnabled) return;
   UltraSnap u;
   if(!UltraBuildSnapshot(s, u))
   {
      UltraDebug_Msg("snapshot fail " + g_UltraCore.lastError);
      return;
   }
   UltraDebug_Msg("regime=" + UltraRegimeName(u.regime) +
                  " conf=" + IntegerToString(u.score.confidence) +
                  " prec=" + IntegerToString(u.score.precision) +
                  " session=" + u.ctx.session +
                  " SMI=" + DoubleToString(u.ind.smi, 1));
}

string UltraDebug_ModuleStatus()
{
   return UltraDebugEnabled ? "DEBUG ON" : "DEBUG OFF";
}

#endif
