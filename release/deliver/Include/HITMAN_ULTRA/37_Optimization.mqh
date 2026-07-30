#ifndef HITMAN_ULTRA_37_OPT_MQH
#define HITMAN_ULTRA_37_OPT_MQH
//+------------------------------------------------------------------+
//| 37_Optimization — cache · event cadence · resource monitoring    |
//+------------------------------------------------------------------+

struct UltraPerfOpt
{
   long lastTickMs;
   long lastHeavyMs;
   ulong cycleCount;
   bool skipHeavy;
   long peakLatencyMs;
   long lastLatencyMs;
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

void UltraOpt_NoteLatency(const long ms)
{
   g_UltraPerfOpt.lastLatencyMs = ms;
   if(ms > g_UltraPerfOpt.peakLatencyMs)
      g_UltraPerfOpt.peakLatencyMs = ms;
}

// Lightweight resource monitor (tick budget / latency / cycle pressure)
string UltraResource_Monitor()
{
   long lat = g_UltraCore.lastLatencyMs;
   UltraOpt_NoteLatency(lat);
   string t = "RES: lat=";
   t += IntegerToString((int)lat);
   t += "ms peak=";
   t += IntegerToString((int)g_UltraPerfOpt.peakLatencyMs);
   t += "ms cycles=";
   t += IntegerToString((int)g_UltraPerfOpt.cycleCount);
   if(lat > 500) t += " WARN";
   else t += " OK";
   return t;
}

string UltraOpt_Summary()
{
   string t = "cycles=";
   t += IntegerToString((int)g_UltraPerfOpt.cycleCount);
   t += " skipHeavy=";
   if(g_UltraPerfOpt.skipHeavy) t += "Y"; else t += "N";
   return t;
}

#endif
