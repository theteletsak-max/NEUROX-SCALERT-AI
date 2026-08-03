#ifndef HITMAN_ULTRA_QUALITY_ASSURANCE_MQH
#define HITMAN_ULTRA_QUALITY_ASSURANCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — PHASE 18 QUALITY ASSURANCE ENGINE                    |
//| INTERNAL STANDARD v6+ — consistency / integrity / conflicts      |
//| Thin auditor over live engines (Final Development Rule)          |
//| NEVER changes strategy · NEVER forces trades · NEVER closes      |
//+------------------------------------------------------------------+

struct UltraQAState
{
   bool   booted;
   bool   ok;
   int    checks;
   int    fails;
   int    warns;
   string lastDetail;
   string summary;
   long   lastMs;
};

UltraQAState g_UltraQA;

void UltraQA_RefreshSummary()
{
   g_UltraQA.summary = "QA ";
   g_UltraQA.summary += g_UltraQA.ok ? "OK" : "FAIL";
   g_UltraQA.summary += " c=";
   g_UltraQA.summary += IntegerToString(g_UltraQA.checks);
   g_UltraQA.summary += " f=";
   g_UltraQA.summary += IntegerToString(g_UltraQA.fails);
   g_UltraQA.summary += " w=";
   g_UltraQA.summary += IntegerToString(g_UltraQA.warns);
}

void UltraQA_Boot()
{
   ZeroMemory(g_UltraQA);
   g_UltraQA.booted = true;
   g_UltraQA.ok = true;
   UltraQA_RefreshSummary();
   if(UltraFoundationLogBoot)
      UltraLog("QUALITY ASSURANCE ∞ boot (Internal Standard v6+ P18) BUILD=HA_ULTRA_93");
}

//--------------------------------------------------------------------//
// Consistency audit — cadenced from RunTradingCycle heavy pass       //
//--------------------------------------------------------------------//
bool UltraQA_Audit(string &detail)
{
   detail = "";
   if(!UltraQAEnabled)
   {
      g_UltraQA.ok = true;
      detail = "QA OFF";
      UltraQA_RefreshSummary();
      return true;
   }

   g_UltraQA.checks = 0;
   g_UltraQA.fails = 0;
   g_UltraQA.warns = 0;
   g_UltraQA.ok = true;
   g_UltraQA.lastMs = (long)GetTickCount();

   // 1) Foundation integrity
   g_UltraQA.checks++;
   if(UltraFoundationEnabled && g_UltraFoundation.booted && g_UltraFoundation.status == "RED")
   {
      g_UltraQA.fails++;
      g_UltraQA.ok = false;
      detail += "FOUNDATION_RED ";
   }

   // 2) Decision consistency — Phase A sticky vs conflicting final signal
   g_UltraQA.checks++;
   if(UltraPhaseA_MissionSoleAuthority && g_UltraMissionEntryOK)
   {
      if(g_UltraLastSignal.buy && g_UltraLastSignal.sell)
      {
         g_UltraQA.fails++;
         g_UltraQA.ok = false;
         detail += "STICKY_CONFLICT ";
      }
   }

   // 3) Signal consistency — no BUY+SELL final signal
   g_UltraQA.checks++;
   if(g_UltraLastSignal.buy && g_UltraLastSignal.sell)
   {
      g_UltraQA.fails++;
      g_UltraQA.ok = false;
      detail += "BUY+SELL ";
   }

   // 4) Confidence source of truth — USM2 when enabled
   g_UltraQA.checks++;
   if(UltraUSM2Enabled && (g_UltraLastSignal.buy || g_UltraLastSignal.sell))
   {
      if(g_UltraUSM2Last.tradeScore <= 0 && g_UltraLastSnap.score.confidence <= 0)
      {
         g_UltraQA.warns++;
         detail += "CONF_EMPTY ";
      }
   }

   // 5) WAIT reason required (every WAIT has a reason)
   g_UltraQA.checks++;
   if(g_UltraMissionLast.command == SUP_WAIT &&
      g_UltraMissionLast.reason != "INIT" &&
      StringLen(g_UltraMissionLast.reason) == 0)
   {
      g_UltraQA.fails++;
      g_UltraQA.ok = false;
      detail += "WAIT_NO_REASON ";
   }

   // 6) Risk / TradeGate conflict — fail mask with passed flag
   g_UltraQA.checks++;
   if(UltraTradeGateEnabled && g_UltraTradeGate.passed && g_UltraTradeGate.failMask != 0)
   {
      g_UltraQA.fails++;
      g_UltraQA.ok = false;
      detail += "GATE_CONFLICT ";
   }

   // 7) Position / exit lock
   g_UltraQA.checks++;
   if(!UltraMissionOnlyExits)
   {
      g_UltraQA.warns++;
      detail += "EXIT_LOCK_OFF ";
   }

   // 8) One thesis · one confidence — engineering rules
   g_UltraQA.checks++;
   if(!UltraThesisEnabled || !UltraUSM2Enabled)
   {
      g_UltraQA.warns++;
      detail += "THESIS_OR_USM2_OFF ";
   }

   // 9) Market Intel integrity (when enabled)
   g_UltraQA.checks++;
   if(UltraMarketIntelEnabled && g_UltraMarketIntel.booted &&
      !g_UltraMarketIntel.approved && g_UltraMarketIntel.status == "RED")
   {
      g_UltraQA.warns++;
      detail += "MKT_RED ";
   }

   if(StringLen(detail) == 0)
      detail = "QA PASS";
   g_UltraQA.lastDetail = detail;
   UltraQA_RefreshSummary();
   return g_UltraQA.ok;
}

void UltraQA_OnTick(const string s)
{
   if(!UltraQAEnabled) return;
   string d = "";
   UltraQA_Audit(d);
   if(!g_UltraQA.ok && UltraQALog)
      UltraLog("QA FAIL " + d + " on " + s);
}

string UltraQA_Dashboard()
{
   UltraQA_RefreshSummary();
   string t = g_UltraQA.summary;
   if(StringLen(g_UltraQA.lastDetail) > 0)
   {
      t += " | ";
      t += g_UltraQA.lastDetail;
   }
   return t;
}

#endif // HITMAN_ULTRA_QUALITY_ASSURANCE_MQH
