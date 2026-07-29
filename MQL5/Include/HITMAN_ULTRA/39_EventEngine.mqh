#ifndef HITMAN_ULTRA_39_EVENTS_MQH
#define HITMAN_ULTRA_39_EVENTS_MQH
//+------------------------------------------------------------------+
//| 39_EventEngine — dispatcher helpers around Shell_B handlers      |
//| Actual OnInit/OnTick/OnTimer/... implementations live in Shell_B |
//+------------------------------------------------------------------+

enum ENUM_ULTRA_EVENT
{
   UEV_INIT = 0,
   UEV_TICK,
   UEV_TIMER,
   UEV_TRADE_TX,
   UEV_CHART,
   UEV_DEINIT
};

struct UltraEventStats
{
   ulong initCount;
   ulong tickCount;
   ulong timerCount;
   ulong tradeTxCount;
   ulong chartCount;
   ulong deinitCount;
};

UltraEventStats g_UltraEventStats;

void UltraEvent_Note(const ENUM_ULTRA_EVENT e)
{
   switch(e)
   {
      case UEV_INIT:     g_UltraEventStats.initCount++; break;
      case UEV_TICK:     g_UltraEventStats.tickCount++; break;
      case UEV_TIMER:    g_UltraEventStats.timerCount++; break;
      case UEV_TRADE_TX: g_UltraEventStats.tradeTxCount++; break;
      case UEV_CHART:    g_UltraEventStats.chartCount++; break;
      case UEV_DEINIT:   g_UltraEventStats.deinitCount++; break;
   }
}

void UltraEvent_OnBoot()
{
   UltraEvent_Note(UEV_INIT);
   UltraOpt_OnTickStart();
   UltraSystemController_Boot();
   UltraLog("EVENT boot mode=" + UltraBT_ModeName());
}

string UltraEvent_Summary()
{
   return "ticks=" + IntegerToString((int)g_UltraEventStats.tickCount) +
          " timers=" + IntegerToString((int)g_UltraEventStats.timerCount) +
          " tx=" + IntegerToString((int)g_UltraEventStats.tradeTxCount);
}

#endif
