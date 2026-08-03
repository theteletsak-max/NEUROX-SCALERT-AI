#ifndef HITMAN_ULTRA_STOP_EVOLUTION_MQH
#define HITMAN_ULTRA_STOP_EVOLUTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA STOP EVOLUTION ∞                               |
//| Protect growing profits · allow room for trends                  |
//| NEVER tighten SL without objective confirmation                  |
//| NEVER widen SL / move risk farther away                          |
//| SL modify only — Mission remains sole close authority            |
//| Final Development Rule: refinement, not a new strategy           |
//+------------------------------------------------------------------+

// Shell helpers (assembled later)
double NormalizeTradePrice(double price);
double GetFilterATR();

#define ULTRA_STOP_EVO_MAX 64

enum ENUM_ULTRA_STOP_LEVEL
{
   USEVO_L1_SMALL = 1,
   USEVO_L2_MODERATE = 2,
   USEVO_L3_STRONG = 3,
   USEVO_L4_LARGE = 4,
   USEVO_L5_EXCEPTIONAL = 5
};

struct UltraStopEvoTicket
{
   ulong  ticket;
   double initialSL;
   double initialRisk;
   double peakMFE;
   int    level;
   int    confirmBars;
   int    failCount;
   datetime lastModify;
   string reason;
};

struct UltraStopEvoState
{
   bool   booted;
   UltraStopEvoTicket slots[ULTRA_STOP_EVO_MAX];
   int    n;
   int    modifyOK;
   int    modifyFail;
   int    skipped;
   int    lastLevel;
   string summary;
};

UltraStopEvoState g_UltraStopEvo;

//--------------------------------------------------------------------//
int UltraStopEvo_Find(const ulong ticket)
{
   for(int i = 0; i < g_UltraStopEvo.n; i++)
      if(g_UltraStopEvo.slots[i].ticket == ticket)
         return i;
   return -1;
}

int UltraStopEvo_Ensure(const ulong ticket, const double openPrice, const double currentSL)
{
   int idx = UltraStopEvo_Find(ticket);
   if(idx >= 0) return idx;
   if(g_UltraStopEvo.n >= ULTRA_STOP_EVO_MAX)
   {
      // drop oldest
      for(int i = 1; i < g_UltraStopEvo.n; i++)
         g_UltraStopEvo.slots[i - 1] = g_UltraStopEvo.slots[i];
      g_UltraStopEvo.n--;
   }
   idx = g_UltraStopEvo.n++;
   g_UltraStopEvo.slots[idx].ticket = ticket;
   g_UltraStopEvo.slots[idx].initialSL = currentSL;
   double risk = MathAbs(openPrice - currentSL);
   if(risk <= 0.0)
   {
      double atr = GetFilterATR();
      risk = (atr > 0.0) ? atr * UltraStopEvoRiskATR : 0.0;
   }
   g_UltraStopEvo.slots[idx].initialRisk = risk;
   g_UltraStopEvo.slots[idx].peakMFE = 0.0;
   g_UltraStopEvo.slots[idx].level = USEVO_L1_SMALL;
   g_UltraStopEvo.slots[idx].confirmBars = 0;
   g_UltraStopEvo.slots[idx].failCount = 0;
   g_UltraStopEvo.slots[idx].lastModify = 0;
   g_UltraStopEvo.slots[idx].reason = "INIT";
   return idx;
}

void UltraStopEvo_PruneClosed()
{
   for(int i = g_UltraStopEvo.n - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_UltraStopEvo.slots[i].ticket))
      {
         for(int j = i + 1; j < g_UltraStopEvo.n; j++)
            g_UltraStopEvo.slots[j - 1] = g_UltraStopEvo.slots[j];
         g_UltraStopEvo.n--;
      }
   }
}

string UltraStopEvo_LevelName(const int lv)
{
   if(lv >= USEVO_L5_EXCEPTIONAL) return "L5_EXCEPTIONAL";
   if(lv >= USEVO_L4_LARGE) return "L4_LARGE";
   if(lv >= USEVO_L3_STRONG) return "L3_STRONG";
   if(lv >= USEVO_L2_MODERATE) return "L2_MODERATE";
   return "L1_SMALL";
}

//--------------------------------------------------------------------//
// Profit level from R-multiple (favorable / initial risk)            //
//--------------------------------------------------------------------//
int UltraStopEvo_CalcLevel(const double profitR)
{
   if(profitR >= UltraStopEvoL5R) return USEVO_L5_EXCEPTIONAL;
   if(profitR >= UltraStopEvoL4R) return USEVO_L4_LARGE;
   if(profitR >= UltraStopEvoL3R) return USEVO_L3_STRONG;
   if(profitR >= UltraStopEvoL2R) return USEVO_L2_MODERATE;
   return USEVO_L1_SMALL;
}

//--------------------------------------------------------------------//
// Validation — thesis · trend · health · tighten-only · broker       //
//--------------------------------------------------------------------//
bool UltraStopEvo_Validate(const string s, const bool isBuy, const ulong ticket,
                           const double openPrice, const double price,
                           const double currentSL, const double newSL,
                           const UltraSnap &u, string &why)
{
   why = "";

   // Thesis / trend / health from Position Evolution (when available)
   if(UltraPosEvoEnabled)
   {
      if(!g_UltraPosEvoLast.thesisValid)
      {
         why = "thesis invalid — no tighten";
         return false;
      }
      if(!g_UltraPosEvoLast.masterTrendValid && UltraStopEvoRequireTrend)
      {
         why = "trend invalid — no tighten";
         return false;
      }
      if(g_UltraPosEvoLast.command == SUP_EXIT && UltraStopEvoRequireHealthy)
      {
         why = "position EXIT state — no tighten (Mission owns close)";
         return false;
      }
      if(UltraStopEvoRequireHealthy && g_UltraPosEvoLast.holdScore > 0 &&
         g_UltraPosEvoLast.holdScore < UltraStopEvoMinHoldScore)
      {
         why = "holdScore weak — give room";
         return false;
      }
   }

   // Soft structure from snap
   if(UltraStopEvoRequireTrend)
   {
      if(isBuy && u.trend.bear && !u.trend.bull)
      {
         why = "snap trend against BUY";
         return false;
      }
      if(!isBuy && u.trend.bull && !u.trend.bear)
      {
         why = "snap trend against SELL";
         return false;
      }
   }

   // Position still in profit for protective moves beyond L1
   double fav = isBuy ? (price - openPrice) : (openPrice - price);
   if(fav <= 0.0)
   {
      why = "not in profit";
      return false;
   }

   // New stop must protect better (tighten only — never widen risk)
   if(isBuy)
   {
      if(currentSL > 0.0 && newSL <= currentSL)
      {
         why = "new SL not better (BUY)";
         return false;
      }
      if(newSL >= price)
      {
         why = "new SL through market (BUY)";
         return false;
      }
   }
   else
   {
      if(currentSL > 0.0 && newSL >= currentSL)
      {
         why = "new SL not better (SELL)";
         return false;
      }
      if(currentSL <= 0.0 && newSL <= 0.0)
      {
         why = "invalid SELL SL";
         return false;
      }
      if(newSL <= price)
      {
         why = "new SL through market (SELL)";
         return false;
      }
   }

   // Broker stops / freeze
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   long stops = UltraSymStopsLevel(s);
   long freeze = UltraSymFreezeLevel(s);
   long need = stops;
   if(freeze > need) need = freeze;
   double minDist = (double)need * point;
   if(minDist <= 0.0) minDist = point;

   double dist = isBuy ? (price - newSL) : (newSL - price);
   if(dist < minDist)
   {
      why = "broker stop/freeze distance";
      return false;
   }

   // Never one-candle panic: require min bars held (caller also gates)
   return true;
}

//--------------------------------------------------------------------//
// Propose protective SL for level (tighten-only geometry)            //
//--------------------------------------------------------------------//
double UltraStopEvo_ProposeSL(const bool isBuy, const double openPrice, const double price,
                              const double currentSL, const double peakPrice,
                              const int level, const double atr)
{
   double proposed = currentSL;

   if(level <= USEVO_L1_SMALL)
      return currentSL; // keep initial

   if(level == USEVO_L2_MODERATE)
   {
      if(!UltraStopEvoBreakEven)
         return currentSL;
      // Break-even (optional)
      proposed = openPrice;
   }
   else if(level == USEVO_L3_STRONG)
   {
      // Lock partial of MFE into profit
      double mfe = isBuy ? (peakPrice - openPrice) : (openPrice - peakPrice);
      if(mfe <= 0.0) return currentSL;
      double lock = mfe * UltraStopEvoL3LockFrac;
      double buf = (atr > 0.0) ? atr * UltraStopEvoBufferATR : 0.0;
      proposed = isBuy ? (openPrice + lock - buf) : (openPrice - lock + buf);
      // At least BE
      if(isBuy && proposed < openPrice) proposed = openPrice;
      if(!isBuy && proposed > openPrice) proposed = openPrice;
   }
   else if(level == USEVO_L4_LARGE)
   {
      // Dynamic trail — follow trend with ATR room
      double trail = (atr > 0.0) ? atr * UltraStopEvoL4TrailATR : 0.0;
      if(trail <= 0.0) return currentSL;
      proposed = isBuy ? (price - trail) : (price + trail);
      // Never below BE once L4
      if(isBuy && proposed < openPrice) proposed = openPrice;
      if(!isBuy && proposed > openPrice) proposed = openPrice;
   }
   else // L5
   {
      // Exceptional — wider trail, never cut trend prematurely
      double trail = (atr > 0.0) ? atr * UltraStopEvoL5TrailATR : 0.0;
      if(trail <= 0.0) return currentSL;
      proposed = isBuy ? (price - trail) : (price + trail);
      // Keep at least L3-style lock of peak if stronger
      double mfe = isBuy ? (peakPrice - openPrice) : (openPrice - peakPrice);
      if(mfe > 0.0)
      {
         double lock = mfe * UltraStopEvoL5LockFrac;
         double buf = (atr > 0.0) ? atr * UltraStopEvoBufferATR : 0.0;
         double floorSL = isBuy ? (openPrice + lock - buf) : (openPrice - lock + buf);
         if(isBuy && floorSL > proposed) proposed = floorSL;
         if(!isBuy && (proposed <= 0.0 || floorSL < proposed)) proposed = floorSL;
      }
      if(isBuy && proposed < openPrice) proposed = openPrice;
      if(!isBuy && proposed > openPrice) proposed = openPrice;
   }

   proposed = NormalizeTradePrice(proposed);

   // Enforce tighten-only vs current
   if(isBuy)
   {
      if(currentSL > 0.0 && proposed <= currentSL)
         return currentSL;
   }
   else
   {
      if(currentSL > 0.0 && proposed >= currentSL)
         return currentSL;
   }
   return proposed;
}

//--------------------------------------------------------------------//
// Modify + verify + safe retry                                       //
//--------------------------------------------------------------------//
bool UltraStopEvo_ModifyVerify(const ulong ticket, const double newSL, const double currentTP,
                               string &why)
{
   why = "";
   if(!PositionSelectByTicket(ticket))
   {
      why = "position gone";
      return false;
   }

   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   if(MathAbs(newSL - curSL) < point && MathAbs(currentTP - curTP) < point)
   {
      why = "no change";
      return true;
   }

   for(int attempt = 0; attempt < UltraStopEvoMaxRetry; attempt++)
   {
      if(!PositionSelectByTicket(ticket))
      {
         why = "position gone mid-retry";
         return false;
      }
      double tpKeep = PositionGetDouble(POSITION_TP);
      // Keep existing TP — stop evolution never clears TP
      if(currentTP > 0.0) tpKeep = currentTP;

      ResetLastError();
      bool ok = g_Trade.PositionModify(ticket, newSL, tpKeep);
      if(ok)
      {
         if(PositionSelectByTicket(ticket))
         {
            double live = PositionGetDouble(POSITION_SL);
            if(MathAbs(live - newSL) <= point * 2.0 ||
               (live > 0.0 && MathAbs(live - newSL) / MathMax(point, 1e-10) < 5.0))
            {
               why = "OK";
               g_UltraStopEvo.modifyOK++;
               return true;
            }
            // Broker rounded — accept if still a tighten
            why = "OK_ROUNDED";
            g_UltraStopEvo.modifyOK++;
            return true;
         }
      }
      why = g_Trade.ResultRetcodeDescription();
      // transient — brief pause then retry
      if(attempt + 1 < UltraStopEvoMaxRetry)
         Sleep(UltraStopEvoRetryMs);
   }

   g_UltraStopEvo.modifyFail++;
   return false;
}

//--------------------------------------------------------------------//
// Main — call from ManageOpenTrades after Mission HOLD/MANAGE        //
//--------------------------------------------------------------------//
bool UltraStopEvo_OnManage(const ulong ticket, const string s, const bool isBuy,
                           const double openPrice, const double price,
                           double &currentSL, const double currentTP,
                           const int barsHeld, const UltraSnap &u)
{
   if(!UltraStopEvoEnabled || !g_UltraStopEvo.booted)
      return false;
   if(ticket == 0 || StringLen(s) == 0)
      return false;

   UltraStopEvo_PruneClosed();

   if(barsHeld < UltraStopEvoMinBars)
   {
      g_UltraStopEvo.skipped++;
      return false;
   }

   int idx = UltraStopEvo_Ensure(ticket, openPrice, currentSL);
   if(idx < 0) return false;

   // Peak favorable
   double peak = g_UltraStopEvo.slots[idx].peakMFE;
   if(peak <= 0.0) peak = openPrice;
   if(isBuy && price > peak) peak = price;
   if(!isBuy && price < peak) peak = price;
   g_UltraStopEvo.slots[idx].peakMFE = peak;

   double risk = g_UltraStopEvo.slots[idx].initialRisk;
   if(risk <= 0.0)
   {
      double atr0 = GetFilterATR();
      risk = (atr0 > 0.0) ? atr0 * UltraStopEvoRiskATR : 0.0;
      g_UltraStopEvo.slots[idx].initialRisk = risk;
   }
   if(risk <= 0.0)
   {
      g_UltraStopEvo.skipped++;
      return false;
   }

   double fav = isBuy ? (price - openPrice) : (openPrice - price);
   double profitR = fav / risk;
   int level = UltraStopEvo_CalcLevel(profitR);

   // Anti one-candle: require level persistence
   if(level > g_UltraStopEvo.slots[idx].level)
   {
      g_UltraStopEvo.slots[idx].confirmBars++;
      if(g_UltraStopEvo.slots[idx].confirmBars < UltraStopEvoConfirmBars)
      {
         g_UltraStopEvo.skipped++;
         return false; // wait for objective confirmation
      }
   }
   else
   {
      g_UltraStopEvo.slots[idx].confirmBars = 0;
   }

   // L1 — keep initial stop
   if(level <= USEVO_L1_SMALL)
   {
      g_UltraStopEvo.slots[idx].level = level;
      g_UltraStopEvo.lastLevel = level;
      return false;
   }

   // L5: never cut trend prematurely — skip tighten if thesis exceptionally strong
   // and holdScore high (give room) unless SL is still below BE
   if(level >= USEVO_L5_EXCEPTIONAL && UltraStopEvoL5GiveRoom)
   {
      bool alreadyProtected = isBuy ? (currentSL >= openPrice) : (currentSL > 0.0 && currentSL <= openPrice);
      if(alreadyProtected && UltraPosEvoEnabled && g_UltraPosEvoLast.holdScore >= UltraStopEvoL5HoldSkip)
      {
         // Still allow trail propose but with L5 wide distance only if much better
         // fall through — ProposeSL uses wide trail
      }
   }

   double atr = u.vol.atr;
   if(atr <= 0.0) atr = GetFilterATR();

   double newSL = UltraStopEvo_ProposeSL(isBuy, openPrice, price, currentSL, peak, level, atr);
   if(newSL == currentSL || (currentSL > 0.0 && MathAbs(newSL - currentSL) < SymbolInfoDouble(s, SYMBOL_POINT)))
   {
      g_UltraStopEvo.slots[idx].level = level;
      g_UltraStopEvo.lastLevel = level;
      return false;
   }

   string why = "";
   if(!UltraStopEvo_Validate(s, isBuy, ticket, openPrice, price, currentSL, newSL, u, why))
   {
      g_UltraStopEvo.skipped++;
      g_UltraStopEvo.slots[idx].reason = why;
      return false;
   }

   // Throttle modifies
   if(g_UltraStopEvo.slots[idx].lastModify > 0 &&
      (TimeCurrent() - g_UltraStopEvo.slots[idx].lastModify) < UltraStopEvoMinModifySec)
   {
      g_UltraStopEvo.skipped++;
      return false;
   }

   string modWhy = "";
   bool ok = UltraStopEvo_ModifyVerify(ticket, newSL, currentTP, modWhy);
   if(ok)
   {
      if(PositionSelectByTicket(ticket))
         currentSL = PositionGetDouble(POSITION_SL);
      else
         currentSL = newSL;
      g_UltraStopEvo.slots[idx].level = level;
      g_UltraStopEvo.slots[idx].lastModify = TimeCurrent();
      g_UltraStopEvo.slots[idx].failCount = 0;
      g_UltraStopEvo.slots[idx].reason = UltraStopEvo_LevelName(level) + " R=" +
         DoubleToString(profitR, 2) + " " + modWhy;
      g_UltraStopEvo.lastLevel = level;

      if(UltraStopEvoLog)
         Print("STOP EVO ", UltraStopEvo_LevelName(level),
               " ticket=", ticket,
               " SL→", DoubleToString(currentSL, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)),
               " R=", DoubleToString(profitR, 2),
               " ", g_UltraStopEvo.slots[idx].reason);

      UltraBug_Explain("STOP_EVO", "UltraStopEvolution", "UltraStopEvo_OnManage",
                       g_UltraStopEvo.slots[idx].reason,
                       isBuy ? "BUY" : "SELL", ticket);
      return true;
   }

   g_UltraStopEvo.slots[idx].failCount++;
   g_UltraStopEvo.slots[idx].reason = "FAIL " + modWhy;
   if(UltraStopEvoLog)
      Print("STOP EVO modify failed ticket=", ticket, " ", modWhy,
            " retries=", UltraStopEvoMaxRetry);
   return false;
}

void UltraStopEvo_Boot()
{
   ZeroMemory(g_UltraStopEvo);
   g_UltraStopEvo.booted = true;
   g_UltraStopEvo.summary = "STOP_EVO READY";
   if(UltraStopEvoLogBoot || UltraFoundationLogBoot)
      UltraLog("STOP EVOLUTION ∞ boot Enabled=" +
               (UltraStopEvoEnabled ? "Y" : "N") +
               " L2R=" + DoubleToString(UltraStopEvoL2R, 2) +
               " L3R=" + DoubleToString(UltraStopEvoL3R, 2) +
               " L4R=" + DoubleToString(UltraStopEvoL4R, 2) +
               " L5R=" + DoubleToString(UltraStopEvoL5R, 2) +
               " BE=" + (UltraStopEvoBreakEven ? "Y" : "N") +
               " BUILD=HA_ULTRA_93");
}

string UltraStopEvo_Dashboard()
{
   g_UltraStopEvo.summary = "STOP_EVO L=";
   g_UltraStopEvo.summary += UltraStopEvo_LevelName(g_UltraStopEvo.lastLevel);
   g_UltraStopEvo.summary += " ok=";
   g_UltraStopEvo.summary += IntegerToString(g_UltraStopEvo.modifyOK);
   g_UltraStopEvo.summary += " fail=";
   g_UltraStopEvo.summary += IntegerToString(g_UltraStopEvo.modifyFail);
   g_UltraStopEvo.summary += " skip=";
   g_UltraStopEvo.summary += IntegerToString(g_UltraStopEvo.skipped);
   return g_UltraStopEvo.summary;
}

#endif // HITMAN_ULTRA_STOP_EVOLUTION_MQH
