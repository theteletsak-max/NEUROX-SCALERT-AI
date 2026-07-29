#ifndef HITMAN_ULTRA_37_OPT_MQH
#define HITMAN_ULTRA_37_OPT_MQH
//+------------------------------------------------------------------+
//| 37_Optimization — memory/CPU/tick performance helpers            |
//+------------------------------------------------------------------+

struct UltraPerfOpt
{
   long lastTickMs;
   long lastHeavyMs;
   ulong cycleCount;
   bool skipHeavy;
};

UltraPerfOpt g_UltraPerfOpt;

void UltraOpt_OnTickStart()
{
   g_UltraPerfOpt.lastTickMs = (long)GetTickCount();
   g_UltraPerfOpt.cycleCount++;
}

bool UltraOpt_ShouldSkipHeavy(const int minIntervalMs=50)
{
   long now = (long)GetTickCount();
   if(g_UltraPerfOpt.lastHeavyMs > 0 && (now - g_UltraPerfOpt.lastHeavyMs) < minIntervalMs)
   {
      g_UltraPerfOpt.skipHeavy = true;
      return true;
   }
   g_UltraPerfOpt.skipHeavy = false;
   g_UltraPerfOpt.lastHeavyMs = now;
   return false;
}

void UltraOpt_MarkHeavyDone()
{
   g_UltraPerfOpt.lastHeavyMs = (long)GetTickCount();
}

string UltraOpt_Summary()
{
   return "cycles=" + IntegerToString((int)g_UltraPerfOpt.cycleCount) +
          " skipHeavy=" + (g_UltraPerfOpt.skipHeavy ? "Y" : "N");
}

#endif
