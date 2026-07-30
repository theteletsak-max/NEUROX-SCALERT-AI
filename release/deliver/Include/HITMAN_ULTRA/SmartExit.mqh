#ifndef HITMAN_ULTRA_SMART_EXIT_MQH
#define HITMAN_ULTRA_SMART_EXIT_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 14 SMART EXIT ENGINE                           |
//| Exit ONLY on thesis invalidation + true reversal (or risk rule)  |
//| Never close on 1 candle / small pullback / temp mom / temp spread|
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

   // Hard close requires BOTH invalid thesis AND confirmed reversal
   // (soft mode). Strict may close on either when hold says EXIT.
   bool hardClose = false;
   if(!UltraUpgradeStrict)
      hardClose = (!thesisValid && corr.state == CORR_REVERSAL && hold.action == HOLD_EXIT);
   else
      hardClose = (hold.action == HOLD_EXIT && (!thesisValid || corr.state == CORR_REVERSAL));

   if(hardClose)
   {
      x.action = SX_CLOSE;
      x.reason = "thesis invalidated + true reversal";
      return x;
   }

   // Never exit on pullback / continuation / liq grab / retest / unknown
   if(corr.state == CORR_PULLBACK || corr.state == CORR_CONTINUATION ||
      corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST || corr.state == CORR_UNKNOWN)
   {
      if(hold.action == HOLD_MANAGE || hold.action == HOLD_EXIT)
      {
         x.action = SX_BE;
         x.reason = "healthy correction — protect / do not close";
      }
      return x;
   }

   if(hold.action == HOLD_MANAGE)
   {
      x.action = SX_BE; // prefer BE over tighten-close path
      x.reason = "manage open risk — breakeven protect";
   }
   return x;
}

#endif
