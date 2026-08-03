#ifndef HITMAN_ULTRA_EXIT_INTELLIGENCE_MQH
#define HITMAN_ULTRA_EXIT_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 11 · EXIT INTELLIGENCE ENGINE    |
//| Close only when strategy objectively ends the opportunity        |
//| NEVER emotional / random · NEVER news-alone · NEVER widen risk   |
//| Mission Control remains SOLE PositionClose* owner                |
//+------------------------------------------------------------------+

enum ENUM_ULTRA_EXIT_OUT
{
   UEXIT_READY = 0,
   UEXIT_HOLD,
   UEXIT_VALIDATING,
   UEXIT_PREPARE,
   UEXIT_CLOSED,
   UEXIT_CLOSE_FAIL
};

struct UltraExitIntelState
{
   bool   booted;
   ENUM_ULTRA_EXIT_OUT outcome;
   string outcomeName;
   string status;              // READY | HOLD | VALIDATING | PREPARE_EXIT | CLOSED | FAIL
   string detail;
   string symbol;
   ulong  ticket;
   bool   isBuy;
   string exitReason;
   string exitMethod;          // MISSION | RISK | TP_LADDER | POSEVO | DEFEND | EMERGENCY
   string thesisState;
   bool   thesisValid;
   bool   trendSupports;
   bool   momentumSupports;
   bool   targetComplete;
   bool   stopTriggered;
   bool   newsMode;
   bool   approved;
   bool   verifiedClosed;
   bool   statsUpdated;
   bool   analyticsUpdated;
   bool   readyNext;
   double profit;
   int    durationBars;
   ulong  closeCount;
   ulong  holdCount;
   ulong  failCount;
   long   lastMs;
};

UltraExitIntelState g_UltraExitIntel;

string UltraExitIntel_OutcomeName(const ENUM_ULTRA_EXIT_OUT o)
{
   switch(o)
   {
      case UEXIT_HOLD:       return "HOLD";
      case UEXIT_VALIDATING: return "VALIDATING";
      case UEXIT_PREPARE:    return "PREPARE_EXIT";
      case UEXIT_CLOSED:     return "POSITION_CLOSED";
      case UEXIT_CLOSE_FAIL: return "CLOSE_FAIL";
      default:               return "READY";
   }
}

void UltraExitIntel_Boot()
{
   g_UltraExitIntel.booted = true;
   g_UltraExitIntel.outcome = UEXIT_READY;
   g_UltraExitIntel.outcomeName = "READY";
   g_UltraExitIntel.status = "READY";
   g_UltraExitIntel.detail = "boot — Mission sole close · every exit needs a reason";
   g_UltraExitIntel.symbol = "";
   g_UltraExitIntel.ticket = 0;
   g_UltraExitIntel.isBuy = true;
   g_UltraExitIntel.exitReason = "";
   g_UltraExitIntel.exitMethod = "";
   g_UltraExitIntel.thesisState = "";
   g_UltraExitIntel.thesisValid = true;
   g_UltraExitIntel.trendSupports = true;
   g_UltraExitIntel.momentumSupports = true;
   g_UltraExitIntel.targetComplete = false;
   g_UltraExitIntel.stopTriggered = false;
   g_UltraExitIntel.newsMode = false;
   g_UltraExitIntel.approved = false;
   g_UltraExitIntel.verifiedClosed = false;
   g_UltraExitIntel.statsUpdated = false;
   g_UltraExitIntel.analyticsUpdated = false;
   g_UltraExitIntel.readyNext = true;
   g_UltraExitIntel.profit = 0.0;
   g_UltraExitIntel.durationBars = 0;
   g_UltraExitIntel.closeCount = g_UltraExitIntel.holdCount = 0;
   g_UltraExitIntel.failCount = 0;
   g_UltraExitIntel.lastMs = 0;
}

void UltraExitIntel_SetOutcome(const ENUM_ULTRA_EXIT_OUT o, const string detail)
{
   g_UltraExitIntel.outcome = o;
   g_UltraExitIntel.outcomeName = UltraExitIntel_OutcomeName(o);
   g_UltraExitIntel.detail = detail;
   g_UltraExitIntel.lastMs = (long)GetTickCount();
   if(o == UEXIT_READY) g_UltraExitIntel.status = "READY";
   else if(o == UEXIT_HOLD) g_UltraExitIntel.status = "HOLD";
   else if(o == UEXIT_VALIDATING) g_UltraExitIntel.status = "VALIDATING";
   else if(o == UEXIT_PREPARE) g_UltraExitIntel.status = "PREPARE_EXIT";
   else if(o == UEXIT_CLOSED) g_UltraExitIntel.status = "CLOSED";
   else if(o == UEXIT_CLOSE_FAIL) g_UltraExitIntel.status = "FAIL";
}

void UltraExitIntel_Log(const string verb)
{
   string line = "EXIT_INTEL ";
   line += verb;
   line += " ";
   line += g_UltraExitIntel.outcomeName;
   line += " ";
   line += g_UltraExitIntel.symbol;
   line += (g_UltraExitIntel.isBuy ? " BUY" : " SELL");
   line += " ticket=";
   line += IntegerToString((int)g_UltraExitIntel.ticket);
   line += " pnl=";
   line += DoubleToString(g_UltraExitIntel.profit, 2);
   line += " method=";
   line += g_UltraExitIntel.exitMethod;
   line += " | ";
   line += g_UltraExitIntel.exitReason;
   if(StringLen(g_UltraExitIntel.detail) > 0)
   {
      line += " | ";
      line += g_UltraExitIntel.detail;
   }
   UltraLog(line);
}

//--------------------------------------------------------------------//
// §2–8 MONITOR — thesis · trend · mom · target · news (never alone)  //
//--------------------------------------------------------------------//
void UltraExitIntel_PublishMonitor(const ulong ticket, const string s, const bool isBuy,
                                   const ENUM_SUPREME_DECISION cmd,
                                   const bool prepareExit,
                                   const bool targetComplete,
                                   const bool newsMode,
                                   const UltraSnap &u,
                                   const string why)
{
   g_UltraExitIntel.ticket = ticket;
   g_UltraExitIntel.symbol = s;
   g_UltraExitIntel.isBuy = isBuy;
   g_UltraExitIntel.newsMode = newsMode;
   g_UltraExitIntel.targetComplete = targetComplete;
   g_UltraExitIntel.thesisValid = g_UltraPosEvoLast.thesisValid;
   g_UltraExitIntel.trendSupports = g_UltraPosEvoLast.masterTrendValid;
   g_UltraExitIntel.momentumSupports = isBuy ? (u.mom.momBuy || u.mom.impulse || !u.mom.momSell)
                                           : (u.mom.momSell || u.mom.impulse || !u.mom.momBuy);
   g_UltraExitIntel.thesisState = g_UltraExitIntel.thesisValid ? "VALID" : "INVALID";
   g_UltraExitIntel.exitReason = why;
   g_UltraExitIntel.readyNext = false;
   g_UltraExitIntel.approved = false;
   g_UltraExitIntel.verifiedClosed = false;

   // News alone NEVER triggers exit (Chapter 11 §8)
   if(newsMode && !prepareExit && cmd != SUP_EXIT)
   {
      UltraExitIntel_SetOutcome(UEXIT_HOLD, "news monitor — no force exit");
      g_UltraExitIntel.holdCount++;
      return;
   }

   if(prepareExit || cmd == SUP_EXIT)
   {
      UltraExitIntel_SetOutcome(UEXIT_PREPARE, "exit required — awaiting validation/close");
      g_UltraExitIntel.exitMethod = "POSEVO";
   }
   else if(cmd == SUP_MANAGE)
   {
      UltraExitIntel_SetOutcome(UEXIT_HOLD, "manage/protect — remain in trade");
      g_UltraExitIntel.holdCount++;
   }
   else
   {
      UltraExitIntel_SetOutcome(UEXIT_READY, "thesis supports remain open");
      g_UltraExitIntel.readyNext = false;
   }
}

//--------------------------------------------------------------------//
// §9 VALIDATION — wraps Mission ValidateExit (never bypasses)        //
//--------------------------------------------------------------------//
bool UltraExitIntel_Validate(const ulong ticket, const string s, const bool isBuy,
                             const UltraSnap &u, const bool riskForced, string &why)
{
   why = "";
   UltraExitIntel_SetOutcome(UEXIT_VALIDATING, "validating exit conditions");
   UltraExitValidation v = UltraMission_ValidateExit(ticket, s, isBuy, u, riskForced);

   // Honor PosEvo L3 soft invalidation (same as Mission ClosePosition)
   if(!v.allowClose && !riskForced && UltraPosEvoEnabled && UltraPosEvoCloseOnL3 &&
      g_UltraPosEvoLast.allowClose && g_UltraPosEvoLast.command == SUP_EXIT &&
      g_UltraPosEvoL3Ticket == ticket)
   {
      v.allowClose = true;
      v.reason = (StringLen(g_UltraPosEvoLast.exitReason) > 0)
                 ? g_UltraPosEvoLast.exitReason
                 : "POSEVO L3 soft invalidation confirmed";
   }

   g_UltraExitIntel.thesisValid = !v.thesisBroken;
   g_UltraExitIntel.trendSupports = !v.masterTrendChanged;
   g_UltraExitIntel.thesisState = v.thesisBroken ? "INVALID" : "VALID";
   g_UltraExitIntel.approved = v.allowClose;
   why = v.reason;
   g_UltraExitIntel.exitReason = why;

   if(!v.allowClose)
   {
      UltraExitIntel_SetOutcome(UEXIT_HOLD, why);
      g_UltraExitIntel.holdCount++;
      UltraExitIntel_Log("HOLD");
      return false;
   }
   UltraExitIntel_SetOutcome(UEXIT_PREPARE, why);
   UltraExitIntel_Log("APPROVE");
   return true;
}

//--------------------------------------------------------------------//
// §10 CLOSE — Mission only (facade NEVER calls g_Trade.PositionClose) //
//--------------------------------------------------------------------//
bool UltraExitIntel_VerifyClosed(const ulong ticket)
{
   if(ticket == 0) return true;
   bool gone = !PositionSelectByTicket(ticket);
   g_UltraExitIntel.verifiedClosed = gone;
   return gone;
}

void UltraExitIntel_NoteClosed(const ulong ticket, const string s, const bool isBuy,
                               const string why, const string method,
                               const double profit, const int durationBars)
{
   g_UltraExitIntel.ticket = ticket;
   g_UltraExitIntel.symbol = s;
   g_UltraExitIntel.isBuy = isBuy;
   g_UltraExitIntel.exitReason = why;
   g_UltraExitIntel.exitMethod = method;
   g_UltraExitIntel.profit = profit;
   g_UltraExitIntel.durationBars = durationBars;
   g_UltraExitIntel.approved = true;
   g_UltraExitIntel.verifiedClosed = true;
   g_UltraExitIntel.statsUpdated = true;
   g_UltraExitIntel.analyticsUpdated = true;
   g_UltraExitIntel.readyNext = true;
   g_UltraExitIntel.closeCount++;
   UltraExitIntel_SetOutcome(UEXIT_CLOSED, "position closed · ready for next opportunity");
   UltraExitIntel_Log("CLOSED");
}

void UltraExitIntel_NoteFail(const ulong ticket, const string why)
{
   g_UltraExitIntel.ticket = ticket;
   g_UltraExitIntel.exitReason = why;
   g_UltraExitIntel.failCount++;
   g_UltraExitIntel.verifiedClosed = false;
   g_UltraExitIntel.readyNext = false;
   UltraExitIntel_SetOutcome(UEXIT_CLOSE_FAIL, why);
   UltraExitIntel_Log("FAIL");
}

// Classify method from why string (logging only)
string UltraExitIntel_ClassifyMethod(const string why, const bool riskForced)
{
   if(riskForced)
   {
      if(StringFind(why, "max hold") >= 0) return "RISK";
      if(StringFind(why, "stagnation") >= 0) return "RISK";
      if(StringFind(why, "TP ladder") >= 0) return "TP_LADDER";
      if(StringFind(why, "EMERGENCY") >= 0) return "EMERGENCY";
      if(StringFind(why, "EXEC cleanup") >= 0) return "EXEC";
      if(StringFind(why, "DEFEND") >= 0 || StringFind(why, "DEFENSE") >= 0) return "DEFEND";
      return "RISK";
   }
   if(StringFind(why, "POSEVO") >= 0 || StringFind(why, "L3") >= 0) return "POSEVO";
   if(StringFind(why, "EXIT:") >= 0) return "MISSION";
   return "MISSION";
}

bool UltraExitIntel_RequestClose(const ulong ticket, const string whyIn, const bool riskForced)
{
   if(ticket == 0) return false;
   if(!PositionSelectByTicket(ticket))
   {
      UltraExitIntel_NoteFail(ticket, "position already gone");
      return false;
   }

   string s = PositionGetString(POSITION_SYMBOL);
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int durationBars = 0;
   if(openTime > 0)
   {
      datetime bar0 = iTime(s, UltraETF(), 0);
      if(bar0 > 0)
         durationBars = (int)((bar0 - openTime) / PeriodSeconds(UltraETF()));
      if(durationBars < 0) durationBars = 0;
   }

   g_UltraExitIntel.ticket = ticket;
   g_UltraExitIntel.symbol = s;
   g_UltraExitIntel.isBuy = isBuy;
   g_UltraExitIntel.profit = profit;
   g_UltraExitIntel.durationBars = durationBars;
   g_UltraExitIntel.exitMethod = UltraExitIntel_ClassifyMethod(whyIn, riskForced);
   g_UltraExitIntel.exitReason = whyIn;
   g_UltraExitIntel.stopTriggered = (StringFind(whyIn, "SL") >= 0 || StringFind(whyIn, "stop") >= 0);
   UltraExitIntel_SetOutcome(UEXIT_VALIDATING, "Mission close requested");
   UltraExitIntel_Log("REQUEST");

   // SOLE CLOSE PATH — Mission Control only
   bool ok = UltraMission_ClosePosition(ticket, whyIn, riskForced);
   if(ok)
   {
      if(!UltraExitIntel_VerifyClosed(ticket))
      {
         // Broker lag — brief recheck
         Sleep(20);
         if(!UltraExitIntel_VerifyClosed(ticket))
         {
            UltraExitIntel_NoteFail(ticket, "close reported OK but position still open");
            return false;
         }
      }
      UltraExitIntel_NoteClosed(ticket, s, isBuy, whyIn, g_UltraExitIntel.exitMethod,
                                profit, durationBars);
      return true;
   }

   UltraExitIntel_NoteFail(ticket, (StringLen(whyIn) > 0) ? whyIn : "Mission denied close");
   return false;
}

string UltraExitIntel_Dashboard()
{
   string t = "EXIT: ";
   if(!g_UltraExitIntel.booted) { t += "INIT"; return t; }
   t += g_UltraExitIntel.status;
   t += " ";
   t += g_UltraExitIntel.outcomeName;
   if(g_UltraExitIntel.ticket > 0)
   {
      t += " #";
      t += IntegerToString((int)g_UltraExitIntel.ticket);
   }
   if(StringLen(g_UltraExitIntel.exitMethod) > 0)
   {
      t += " ";
      t += g_UltraExitIntel.exitMethod;
   }
   if(g_UltraExitIntel.outcome == UEXIT_CLOSED)
   {
      t += " pnl=";
      t += DoubleToString(g_UltraExitIntel.profit, 2);
   }
   if(g_UltraExitIntel.newsMode) t += " | NEWS";
   if(g_UltraExitIntel.readyNext && g_UltraExitIntel.outcome == UEXIT_CLOSED)
      t += " | READY";
   return t;
}

#endif // HITMAN_ULTRA_EXIT_INTELLIGENCE_MQH
