#ifndef HITMAN_ULTRA_SMART_EXIT_MQH
#define HITMAN_ULTRA_SMART_EXIT_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 14 SMART EXIT ENGINE                           |
//| Exit only on thesis invalidation OR risk rule — decision only    |
//+------------------------------------------------------------------+

enum ENUM_SMART_EXIT
{
   SX_NONE = 0,
   SX_BE,
   SX_TIGHTEN,
   SX_CLOSE
};

struct UltraSmartExit
{
   ENUM_SMART_EXIT action;
   string reason;
};

UltraSmartExit UltraSmartExit_Decide(const UltraHoldScore &hold, const UltraCorrection &corr,
                                     const bool thesisValid, const bool riskForced)
{
   UltraSmartExit x;
   x.action = SX_NONE;
   x.reason = "";

   if(!UltraUpgradeEnabled || !UltraSmartExitEnabled)
      return x;

   if(riskForced)
   {
      x.action = SX_CLOSE;
      x.reason = "risk management rule";
      return x;
   }

   if(hold.action == HOLD_EXIT && (!thesisValid || corr.state == CORR_REVERSAL))
   {
      x.action = SX_CLOSE;
      x.reason = "trade thesis invalidated";
      return x;
   }

   // Never exit on one opposite candle / small pullback / temp vol / minor mom loss
   if(corr.state == CORR_PULLBACK || corr.state == CORR_CONTINUATION ||
      corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST || corr.state == CORR_UNKNOWN)
   {
      if(hold.action == HOLD_MANAGE)
      {
         x.action = SX_BE;
         x.reason = "healthy correction — protect / manage";
      }
      return x;
   }

   if(hold.action == HOLD_MANAGE)
   {
      x.action = SX_TIGHTEN;
      x.reason = "manage open risk";
   }
   return x;
}

#endif
