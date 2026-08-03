#ifndef HITMAN_ULTRA_LOW_LATENCY_MQH
#define HITMAN_ULTRA_LOW_LATENCY_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA LOW-LATENCY ARCHITECTURE ∞                     |
//| Performance orchestration only (Final Development Rule)          |
//| Wires UltraOpt + smart-tick + heavy-pass cadence                 |
//| NEVER skips ManageOpenTrades / Mission / Execute on price change |
//| NEVER changes strategy, signal, thesis, or Mission authority     |
//+------------------------------------------------------------------+

// Shell_B — defined later in assemble order
bool UltraSmartTickUnchanged();

// 37_Optimization — assembled after this module (forwards; no defaults)
void   UltraOpt_OnTickStart();
bool   UltraOpt_ShouldSkipHeavy(const int minIntervalMs);
void   UltraOpt_NoteLatency(const long ms);
string UltraOpt_Summary();

struct UltraLowLatencyState
{
   bool   booted;
   ulong  tickStarts;
   ulong  skipEntry;
   ulong  skipHeavy;
   ulong  heavyRuns;
   long   lastTickStartMs;
   long   lastTickLatencyMs;
   long   peakTickLatencyMs;
   long   lastDecisionMs;
   string summary;
};

UltraLowLatencyState g_UltraLL;

//--------------------------------------------------------------------//
void UltraLL_RefreshSummary()
{
   g_UltraLL.summary = "LL ";
   g_UltraLL.summary += UltraLowLatencyEnabled ? "ON" : "OFF";
   g_UltraLL.summary += " ticks=";
   g_UltraLL.summary += IntegerToString((int)g_UltraLL.tickStarts);
   g_UltraLL.summary += " skipE=";
   g_UltraLL.summary += IntegerToString((int)g_UltraLL.skipEntry);
   g_UltraLL.summary += " skipH=";
   g_UltraLL.summary += IntegerToString((int)g_UltraLL.skipHeavy);
   g_UltraLL.summary += " lat=";
   g_UltraLL.summary += IntegerToString((int)g_UltraLL.lastTickLatencyMs);
   g_UltraLL.summary += "ms peak=";
   g_UltraLL.summary += IntegerToString((int)g_UltraLL.peakTickLatencyMs);
   g_UltraLL.summary += "ms";
}

void UltraLL_Boot()
{
   ZeroMemory(g_UltraLL);
   g_UltraLL.booted = true;
   UltraLL_RefreshSummary();
   if(UltraLowLatencyLogBoot || UltraFoundationLogBoot)
      UltraLog("LOW-LATENCY ARCHITECTURE ∞ boot " + g_UltraLL.summary +
               " HeavyMs=" + IntegerToString(UltraLowLatencyHeavyMs) +
               " EarlySmartTick=" + (UltraLowLatencyEarlySmartTick ? "Y" : "N") +
               " BUILD=HA_ULTRA_93");
}

//--------------------------------------------------------------------//
// Call once per RunTradingCycle — budgets the tick                   //
//--------------------------------------------------------------------//
void UltraLL_OnTickStart()
{
   UltraOpt_OnTickStart();
   g_UltraLL.tickStarts++;
   g_UltraLL.lastTickStartMs = (long)GetTickCount();
}

void UltraLL_OnTickEnd()
{
   if(g_UltraLL.lastTickStartMs <= 0)
      return;
   long dt = (long)GetTickCount() - g_UltraLL.lastTickStartMs;
   if(dt < 0) dt = 0;
   g_UltraLL.lastTickLatencyMs = dt;
   if(dt > g_UltraLL.peakTickLatencyMs)
      g_UltraLL.peakTickLatencyMs = dt;
   UltraOpt_NoteLatency(dt);
   UltraLL_RefreshSummary();
}

void UltraLL_NoteDecisionLatency(const long ms)
{
   g_UltraLL.lastDecisionMs = ms;
   UltraOpt_NoteLatency(ms);
}

void UltraLL_NoteSkipEntry()
{
   g_UltraLL.skipEntry++;
}

//--------------------------------------------------------------------//
// Heavy analytics / maintenance cadence (never position manage/exec) //
//--------------------------------------------------------------------//
bool UltraLL_AllowMaintPass()
{
   if(!UltraLowLatencyEnabled || !UltraLowLatencySkipHeavy)
      return true;

   if(UltraOpt_ShouldSkipHeavy(UltraLowLatencyHeavyMs))
   {
      g_UltraLL.skipHeavy++;
      return false;
   }
   g_UltraLL.heavyRuns++;
   return true;
}

//--------------------------------------------------------------------//
// Entry eval: false = price unchanged + already decided (skip path)  //
// News InstantPath always allows (maximum event responsiveness)      //
//--------------------------------------------------------------------//
bool UltraLL_ShouldEarlySkipEntry()
{
   if(!UltraLowLatencyEnabled || !UltraLowLatencyEarlySmartTick)
      return false;
   if(!EnableTickLevelSignalDetection)
      return false;
   if(UltraNewsExec_InstantPath())
      return false;
   return UltraSmartTickUnchanged();
}

string UltraLL_Dashboard()
{
   UltraLL_RefreshSummary();
   return g_UltraLL.summary;
}

string UltraLL_Summary()
{
   UltraLL_RefreshSummary();
   string t = g_UltraLL.summary;
   t += " | ";
   t += UltraOpt_Summary();
   return t;
}

#endif // HITMAN_ULTRA_LOW_LATENCY_MQH
