#ifndef HITMAN_ULTRA_TRADE_GATE_MQH
#define HITMAN_ULTRA_TRADE_GATE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA TRADE GATE (HARD PRE-TRADE VALIDATION)         |
//| Every BUY/SELL must pass ALL checks. ANY fail → NO TRADE.        |
//| Entry · SL · TP1 · TP2 · TP3 · Risk · Exec · Thesis · Mission    |
//+------------------------------------------------------------------+

#define ULTRA_GATE_ENTRY   0x001
#define ULTRA_GATE_SL      0x002
#define ULTRA_GATE_TP1     0x004
#define ULTRA_GATE_TP2     0x008
#define ULTRA_GATE_TP3     0x010
#define ULTRA_GATE_RISK    0x020
#define ULTRA_GATE_EXEC    0x040
#define ULTRA_GATE_THESIS  0x080
#define ULTRA_GATE_MISSION 0x100
#define ULTRA_GATE_ALL     0x1FF

// Chapter 15 Recovery — assembled after TradeGate (forward)
bool UltraRecoveryIntel_AllowNewEntries();

struct UltraTradeGateState
{
   bool   passed;
   bool   isBuy;
   int    passMask;
   int    failMask;
   string failStep;      // first failed validation name
   string detail;
   double entry, sl, tp1, tp2, tp3;
   double risk, rr1, rr2, rr3;
   datetime ts;
};

UltraTradeGateState g_UltraTradeGate;

void UltraTradeGate_Reset()
{
   g_UltraTradeGate.passed = false;
   g_UltraTradeGate.isBuy = true;
   g_UltraTradeGate.passMask = 0;
   g_UltraTradeGate.failMask = 0;
   g_UltraTradeGate.failStep = "";
   g_UltraTradeGate.detail = "";
   g_UltraTradeGate.entry = g_UltraTradeGate.sl = 0.0;
   g_UltraTradeGate.tp1 = g_UltraTradeGate.tp2 = g_UltraTradeGate.tp3 = 0.0;
   g_UltraTradeGate.risk = g_UltraTradeGate.rr1 = 0.0;
   g_UltraTradeGate.rr2 = g_UltraTradeGate.rr3 = 0.0;
   g_UltraTradeGate.ts = 0;
}

void UltraTradeGate_Fail(const int bit, const string step, const string why)
{
   g_UltraTradeGate.failMask |= bit;
   if(StringLen(g_UltraTradeGate.failStep) == 0)
   {
      g_UltraTradeGate.failStep = step;
      g_UltraTradeGate.detail = why;
   }
   g_UltraTradeGate.passed = false;
}

void UltraTradeGate_Pass(const int bit)
{
   g_UltraTradeGate.passMask |= bit;
}

//--------------------------------------------------------------------//
// HARD GATE — if ANY validation fails → NO TRADE                     //
//--------------------------------------------------------------------//
bool UltraTradeGate_Validate(const string s, const bool isBuy,
                             const double entry, const double sl,
                             const double tp1, const double tp2, const double tp3,
                             string &why)
{
   why = "";
   UltraTradeGate_Reset();
   g_UltraTradeGate.isBuy = isBuy;
   g_UltraTradeGate.entry = entry;
   g_UltraTradeGate.sl = sl;
   g_UltraTradeGate.tp1 = tp1;
   g_UltraTradeGate.tp2 = tp2;
   g_UltraTradeGate.tp3 = tp3;
   g_UltraTradeGate.ts = TimeCurrent();

   if(!UltraTradeGateEnabled)
   {
      g_UltraTradeGate.passed = true;
      g_UltraTradeGate.passMask = ULTRA_GATE_ALL;
      g_UltraTradeGate.detail = "gate disabled-pass";
      return true;
   }

   // Ch15 Safe Mode — suspend new trade execution; positions still managed elsewhere
   if(!UltraRecoveryIntel_AllowNewEntries())
   {
      UltraTradeGate_Fail(ULTRA_GATE_EXEC, "RECOVERY", "safe mode — new entries suspended");
      why = g_UltraTradeGate.detail;
      return false;
   }

   const UltraSnap u = g_UltraLastSnap;
   double point = SymbolInfoDouble(s, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;

   // 1) ENTRY VALIDATION
   if(entry <= 0.0 || !MathIsValidNumber(entry))
   {
      UltraTradeGate_Fail(ULTRA_GATE_ENTRY, "ENTRY", "invalid entry price");
   }
   else
   {
      double live = isBuy ? SymbolInfoDouble(s, SYMBOL_ASK) : SymbolInfoDouble(s, SYMBOL_BID);
      if(live <= 0.0)
         UltraTradeGate_Fail(ULTRA_GATE_ENTRY, "ENTRY", "live quote missing");
      else if(!UltraBT_RelaxEntryDrift() &&
              MathAbs(live - entry) > MathMax(point * 50.0, (u.vol.atr > 0.0 ? u.vol.atr * 0.15 : point * 50.0)))
         UltraTradeGate_Fail(ULTRA_GATE_ENTRY, "ENTRY", "entry drifted from live price");
      else if(isBuy && !g_UltraLastSignal.buy)
         UltraTradeGate_Fail(ULTRA_GATE_ENTRY, "ENTRY", "no BUY signal for entry");
      else if(!isBuy && !g_UltraLastSignal.sell)
         UltraTradeGate_Fail(ULTRA_GATE_ENTRY, "ENTRY", "no SELL signal for entry");
      else if(g_UltraLastSignal.tag == "" || g_UltraLastSignal.tag == "NONE")
         UltraTradeGate_Fail(ULTRA_GATE_ENTRY, "ENTRY", "entry strategy tag missing");
      else
         UltraTradeGate_Pass(ULTRA_GATE_ENTRY);
   }

   // 2) STOP LOSS VALIDATION
   if(sl <= 0.0 || !MathIsValidNumber(sl))
      UltraTradeGate_Fail(ULTRA_GATE_SL, "SL", "invalid stop loss");
   else if(isBuy && !(sl < entry - point))
      UltraTradeGate_Fail(ULTRA_GATE_SL, "SL", "BUY SL must be below entry");
   else if(!isBuy && !(sl > entry + point))
      UltraTradeGate_Fail(ULTRA_GATE_SL, "SL", "SELL SL must be above entry");
   else
   {
      g_UltraTradeGate.risk = MathAbs(entry - sl);
      if(g_UltraTradeGate.risk < point * 2.0)
         UltraTradeGate_Fail(ULTRA_GATE_SL, "SL", "SL risk too small");
      else if(UltraTargetEnabled && g_UltraTargetLast.valid && StringLen(g_UltraTargetLast.reasonSL) == 0)
         UltraTradeGate_Fail(ULTRA_GATE_SL, "SL", "SL missing validated reason");
      else
         UltraTradeGate_Pass(ULTRA_GATE_SL);
   }

   if(g_UltraTradeGate.risk <= 0.0 && (g_UltraTradeGate.failMask & ULTRA_GATE_SL) == 0)
      g_UltraTradeGate.risk = MathAbs(entry - sl);

   // 3) TP1 VALIDATION
   if(tp1 <= 0.0 || !MathIsValidNumber(tp1))
      UltraTradeGate_Fail(ULTRA_GATE_TP1, "TP1", "invalid TP1");
   else if(isBuy && !(tp1 > entry + point))
      UltraTradeGate_Fail(ULTRA_GATE_TP1, "TP1", "BUY TP1 must be above entry");
   else if(!isBuy && !(tp1 < entry - point))
      UltraTradeGate_Fail(ULTRA_GATE_TP1, "TP1", "SELL TP1 must be below entry");
   else
   {
      g_UltraTradeGate.rr1 = g_UltraTradeGate.risk > 0.0 ? MathAbs(tp1 - entry) / g_UltraTradeGate.risk : 0.0;
      if(g_UltraTradeGate.rr1 + 1e-9 < UltraTargetMinRR1)
         UltraTradeGate_Fail(ULTRA_GATE_TP1, "TP1", "TP1 RR below minimum");
      else if(UltraTargetEnabled && g_UltraTargetLast.valid && StringLen(g_UltraTargetLast.reasonTP1) == 0)
         UltraTradeGate_Fail(ULTRA_GATE_TP1, "TP1", "TP1 missing validated reason");
      else
         UltraTradeGate_Pass(ULTRA_GATE_TP1);
   }

   // 4) TP2 VALIDATION
   if(tp2 <= 0.0 || !MathIsValidNumber(tp2))
      UltraTradeGate_Fail(ULTRA_GATE_TP2, "TP2", "invalid TP2");
   else if(isBuy && !(tp2 > tp1 + point))
      UltraTradeGate_Fail(ULTRA_GATE_TP2, "TP2", "BUY TP2 must be beyond TP1");
   else if(!isBuy && !(tp2 < tp1 - point))
      UltraTradeGate_Fail(ULTRA_GATE_TP2, "TP2", "SELL TP2 must be beyond TP1");
   else
   {
      g_UltraTradeGate.rr2 = g_UltraTradeGate.risk > 0.0 ? MathAbs(tp2 - entry) / g_UltraTradeGate.risk : 0.0;
      if(g_UltraTradeGate.rr2 + 1e-9 < UltraTargetMinRR2)
         UltraTradeGate_Fail(ULTRA_GATE_TP2, "TP2", "TP2 RR below minimum");
      else if(UltraTargetEnabled && g_UltraTargetLast.valid && StringLen(g_UltraTargetLast.reasonTP2) == 0)
         UltraTradeGate_Fail(ULTRA_GATE_TP2, "TP2", "TP2 missing validated reason");
      else
         UltraTradeGate_Pass(ULTRA_GATE_TP2);
   }

   // 5) TP3 VALIDATION — level must exist and not invert ladder (disarmed TP3==TP2 OK)
   if(tp3 <= 0.0 || !MathIsValidNumber(tp3))
      UltraTradeGate_Fail(ULTRA_GATE_TP3, "TP3", "invalid TP3");
   else if(isBuy && !(tp3 + 1e-12 >= tp2))
      UltraTradeGate_Fail(ULTRA_GATE_TP3, "TP3", "BUY TP3 must be >= TP2");
   else if(!isBuy && !(tp3 - 1e-12 <= tp2))
      UltraTradeGate_Fail(ULTRA_GATE_TP3, "TP3", "SELL TP3 must be <= TP2");
   else
   {
      g_UltraTradeGate.rr3 = g_UltraTradeGate.risk > 0.0 ? MathAbs(tp3 - entry) / g_UltraTradeGate.risk : 0.0;
      // If TP3 uniquely armed beyond TP2, enforce min RR3; if equal to TP2 (disarmed), still valid
      bool uniqueTP3 = (MathAbs(tp3 - tp2) > point);
      if(uniqueTP3 && g_UltraTradeGate.rr3 + 1e-9 < UltraTargetMinRR3)
         UltraTradeGate_Fail(ULTRA_GATE_TP3, "TP3", "TP3 RR below minimum");
      else if(UltraTargetEnabled && g_UltraTargetLast.valid && StringLen(g_UltraTargetLast.reasonTP3) == 0)
         UltraTradeGate_Fail(ULTRA_GATE_TP3, "TP3", "TP3 missing validated reason");
      else
         UltraTradeGate_Pass(ULTRA_GATE_TP3);
   }

   // When Target Intelligence is ON, a valid plan is mandatory (no unvalidated targets)
   if(UltraTargetEnabled && UltraTradeGateRequireTargets)
   {
      if(!g_UltraTargetLast.valid || g_UltraTargetLast.isBuy != isBuy)
      {
         if((g_UltraTradeGate.failMask & ULTRA_GATE_TP1) == 0 &&
            (g_UltraTradeGate.failMask & ULTRA_GATE_TP2) == 0)
            UltraTradeGate_Fail(ULTRA_GATE_TP1, "TP1", "Target Intelligence plan not valid — NO TRADE");
      }
   }

   // 6) RISK VALIDATION — Chapter 7 Risk Intelligence (lot/margin/exposure/DD)
   {
      string riskWhy = "";
      bool riskOK = UltraRiskIntel_Validate(s, isBuy, entry, sl, riskWhy);
      if(g_UltraTradeGate.risk <= 0.0)
      {
         riskOK = false;
         riskWhy = "zero risk distance";
      }
      if(!riskOK)
         UltraTradeGate_Fail(ULTRA_GATE_RISK, "RISK", riskWhy);
      else
         UltraTradeGate_Pass(ULTRA_GATE_RISK);
   }

   // 7) EXECUTION VALIDATION — Chapter 8 Execution Intelligence
   {
      string exWhy = "";
      if(!UltraExecIntel_Ready(s, exWhy))
         UltraTradeGate_Fail(ULTRA_GATE_EXEC, "EXEC", exWhy);
      else if(!UltraBT_ConnectedOK())
         UltraTradeGate_Fail(ULTRA_GATE_EXEC, "EXEC", "terminal disconnected");
      else if(!UltraBT_TradeAllowed())
         UltraTradeGate_Fail(ULTRA_GATE_EXEC, "EXEC", "trading not allowed");
      else
         UltraTradeGate_Pass(ULTRA_GATE_EXEC);
   }

   // 8) TRADE THESIS VALIDATION
   // PHASE A — if Mission already finalized BUY/SELL, thesis is advisory only
   {
      bool thesisOK = false;
      string thWhy = "";
      if(g_UltraLastSignal.tag == "" || g_UltraLastSignal.tag == "NONE")
         thWhy = "no strategy thesis tag";
      else if(isBuy)
      {
         thesisOK = (g_UltraLastSignal.buy &&
                     (u.bos.buy || u.choch.buy || UltraLiq_IsGenuine(u, true) ||
                      (u.trend.bull && (u.ict.instZoneBuy || u.fib.atBuyZone || u.st.hl || u.st.hh))));
         if(!thesisOK) thWhy = "BUY thesis shape invalid";
      }
      else
      {
         thesisOK = (g_UltraLastSignal.sell &&
                     (u.bos.sell || u.choch.sell || UltraLiq_IsGenuine(u, false) ||
                      (u.trend.bear && (u.ict.instZoneSell || u.fib.atSellZone || u.st.lh || u.st.ll))));
         if(!thesisOK) thWhy = "SELL thesis shape invalid";
      }
      if(!thesisOK && UltraPhaseA_MissionSoleAuthority && UltraMission_HasFinalEntry(isBuy))
      {
         UltraTradeGate_Pass(ULTRA_GATE_THESIS);
         if(UltraTradeGateLog || UltraPhaseA_LogPostMissionWarn)
            UltraLog("PHASE_A THESIS WARN only (Mission sole authority): " + thWhy);
      }
      else if(!thesisOK)
         UltraTradeGate_Fail(ULTRA_GATE_THESIS, "THESIS", thWhy);
      else
         UltraTradeGate_Pass(ULTRA_GATE_THESIS);
   }

   // 9) MISSION CONTROL APPROVAL — assert sticky final decision (not a soft re-WAIT)
   {
      bool missionOK = true;
      string mWhy = "";
      if(!UltraMission_AllowNewEntry(s))
      {
         missionOK = false;
         mWhy = "Mission blocked new entry (one-decision / replace gate)";
      }
      else if(UltraUpgradeEnabled && UltraSupremeEnabled)
      {
         if(!UltraMission_HasFinalEntry(isBuy))
         {
            missionOK = false;
            mWhy = "Mission Control not approved for ";
            mWhy += isBuy ? "BUY" : "SELL";
         }
      }
      if(!missionOK)
         UltraTradeGate_Fail(ULTRA_GATE_MISSION, "MISSION", mWhy);
      else
         UltraTradeGate_Pass(ULTRA_GATE_MISSION);
   }

   // Compose — ANY fail → NO TRADE
   if(g_UltraTradeGate.failMask != 0 ||
      (g_UltraTradeGate.passMask & ULTRA_GATE_ALL) != ULTRA_GATE_ALL)
   {
      g_UltraTradeGate.passed = false;
      why = "NO TRADE — ";
      why += g_UltraTradeGate.failStep;
      why += ": ";
      why += g_UltraTradeGate.detail;
      why += " mask=";
      why += IntegerToString(g_UltraTradeGate.passMask);
      why += "/";
      why += IntegerToString(ULTRA_GATE_ALL);
      if(UltraTradeGateLog)
      {
         UltraLog("TRADE_GATE FAIL " + why);
         UltraLogDecision("NO_TRADE", 0, isBuy ? "BUY" : "SELL",
                          g_UltraLastSignal.tag, u.score.confidence, 0,
                          "GATE", g_UltraTradeGate.failStep, 0.0,
                          g_UltraTradeGate.risk, why);
      }
      UltraBT_LogReject("UltraTradeGate", "UltraTradeGate_Validate",
                        g_UltraTradeGate.failStep + ": " + g_UltraTradeGate.detail);
      return false;
   }

   g_UltraTradeGate.passed = true;
   why = "TRADE_GATE PASS Entry/SL/TP1/TP2/TP3/Risk/Exec/Thesis/Mission";
   g_UltraTradeGate.detail = why;
   if(UltraTradeGateLog)
      UltraLog("TRADE_GATE PASS " + (isBuy ? "BUY" : "SELL") +
               " RR=" + DoubleToString(g_UltraTradeGate.rr1, 2) + "/" +
               DoubleToString(g_UltraTradeGate.rr2, 2) + "/" +
               DoubleToString(g_UltraTradeGate.rr3, 2) +
               " tag=" + g_UltraLastSignal.tag);
   return true;
}

void UltraTradeGate_Boot()
{
   UltraTradeGate_Reset();
   if(UltraTradeGateLog)
      UltraLog("TRADE_GATE boot Enabled=" + (UltraTradeGateEnabled ? "Y" : "N") +
               " RequireTargets=" + (UltraTradeGateRequireTargets ? "Y" : "N") +
               " ANY fail = NO TRADE | BUILD=HA_ULTRA_93");
}

string UltraTradeGate_Dashboard()
{
   string t = "GATE: ";
   if(!UltraTradeGateEnabled) { t += "OFF"; return t; }
   if(g_UltraTradeGate.passed) t += "PASS";
   else if(StringLen(g_UltraTradeGate.failStep) > 0)
   {
      t += "NO_TRADE ";
      t += g_UltraTradeGate.failStep;
   }
   else t += "—";
   t += " ";
   t += IntegerToString(g_UltraTradeGate.passMask);
   t += "/";
   t += IntegerToString(ULTRA_GATE_ALL);
   return t;
}

#endif // HITMAN_ULTRA_TRADE_GATE_MQH
