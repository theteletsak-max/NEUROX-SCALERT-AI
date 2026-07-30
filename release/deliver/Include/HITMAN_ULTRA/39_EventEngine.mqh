#ifndef HITMAN_ULTRA_39_EVENTS_MQH
#define HITMAN_ULTRA_39_EVENTS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 39_EVENT ENGINE — event-driven market + lifecycle    |
//+------------------------------------------------------------------+

enum ENUM_ULTRA_EVENT
{
   UEV_INIT = 0,
   UEV_TICK,
   UEV_TIMER,
   UEV_TRADE_TX,
   UEV_CHART,
   UEV_DEINIT,
   UEV_BOS,
   UEV_CHOCH,
   UEV_SWEEP,
   UEV_FIRE,
   UEV_WAIT
};

struct UltraEventStats
{
   ulong initCount;
   ulong tickCount;
   ulong timerCount;
   ulong tradeTxCount;
   ulong chartCount;
   ulong deinitCount;
   ulong bosCount;
   ulong chochCount;
   ulong sweepCount;
   ulong fireCount;
   ulong waitCount;
   datetime lastMarketEvent;
   string lastMarketTag;
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
      case UEV_BOS:      g_UltraEventStats.bosCount++; break;
      case UEV_CHOCH:    g_UltraEventStats.chochCount++; break;
      case UEV_SWEEP:    g_UltraEventStats.sweepCount++; break;
      case UEV_FIRE:     g_UltraEventStats.fireCount++; break;
      case UEV_WAIT:     g_UltraEventStats.waitCount++; break;
   }
}

void UltraEvent_NoteMarket(const UltraSnap &u)
{
   bool edged = false;
   if(u.bos.buy || u.bos.sell)
   {
      UltraEvent_Note(UEV_BOS);
      g_UltraEventStats.lastMarketTag = "BOS";
      edged = true;
   }
   if(u.choch.buy || u.choch.sell)
   {
      UltraEvent_Note(UEV_CHOCH);
      g_UltraEventStats.lastMarketTag = "CHoCH";
      edged = true;
   }
   if(u.liq.sweepBuy || u.liq.sweepSell || u.liq.stopHuntBuy || u.liq.stopHuntSell)
   {
      UltraEvent_Note(UEV_SWEEP);
      g_UltraEventStats.lastMarketTag = "SWEEP";
      edged = true;
   }
   if(edged)
      g_UltraEventStats.lastMarketEvent = TimeCurrent();
}

void UltraEvent_OnBoot()
{
   UltraEvent_Note(UEV_INIT);
   UltraLog("EVENT boot — HITMAN AI event engine ready");
}

string UltraEvent_Summary()
{
   string t = "ticks=";
   t += IntegerToString((int)g_UltraEventStats.tickCount);
   t += " bos=";
   t += IntegerToString((int)g_UltraEventStats.bosCount);
   t += " choch=";
   t += IntegerToString((int)g_UltraEventStats.chochCount);
   t += " sweep=";
   t += IntegerToString((int)g_UltraEventStats.sweepCount);
   t += " fire=";
   t += IntegerToString((int)g_UltraEventStats.fireCount);
   return t;
}

string UltraEvent_Dashboard()
{
   string t = "EVENT: ";
   t += UltraEvent_Summary();
   if(StringLen(g_UltraEventStats.lastMarketTag) > 0)
   {
      t += " last=";
      t += g_UltraEventStats.lastMarketTag;
   }
   return t;
}

#endif
