//+------------------------------------------------------------------+
//| NX_Session.mqh                                                    |
//| Optional UTC trading window filter                                |
//+------------------------------------------------------------------+
#property copyright "NEUROX"
#property strict

#ifndef NEUROX_NX_SESSION_MQH
#define NEUROX_NX_SESSION_MQH

bool NX_InSession(const bool enabled,
                  const int startHourUtc,
                  const int endHourUtc)
  {
   if(!enabled)
      return true;

   datetime now = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int hour = dt.hour;

   if(startHourUtc == endHourUtc)
      return true; // full day

   if(startHourUtc < endHourUtc)
      return (hour >= startHourUtc && hour < endHourUtc);

   // Window crosses midnight
   return (hour >= startHourUtc || hour < endHourUtc);
  }

#endif
//+------------------------------------------------------------------+
