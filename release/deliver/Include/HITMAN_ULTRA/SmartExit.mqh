#ifndef HITMAN_ULTRA_SMART_EXIT_MQH
#define HITMAN_ULTRA_SMART_EXIT_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — SMART EXIT — decision only (Mission executes close)  |
//| Exit only when original idea failed OR risk requires exit        |
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

   // Never close on healthy correction / noise
   if(corr.state == CORR_PULLBACK || corr.state == CORR_CONTINUATION ||
      corr.state == CORR_LIQ_GRAB || corr.state == CORR_RETEST || corr.state == CORR_UNKNOWN)
   {
      x.action = SX_BE;
      x.reason = "healthy correction — do not close";
      return x;
   }

   // CLOSE suggestion only if hold says EXIT and thesis invalid + true reversal
   // (Mission Control still runs multi-confirm ValidateExit before closing)
   if(hold.action == HOLD_EXIT && !thesisValid && corr.state == CORR_REVERSAL)
   {
      x.action = SX_CLOSE;
      x.reason = "trade thesis failed + true reversal";
      return x;
   }

   if(hold.action == HOLD_MANAGE || hold.action == HOLD_EXIT)
   {
      x.action = SX_BE;
      x.reason = "manage / protect — keep holding";
   }
   return x;
}

#endif
