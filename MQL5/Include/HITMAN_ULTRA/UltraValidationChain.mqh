#ifndef HITMAN_ULTRA_VALIDATION_CHAIN_MQH
#define HITMAN_ULTRA_VALIDATION_CHAIN_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA VALIDATION CHAIN                               |
//| Every critical module returns: VALID · INVALID · WAIT            |
//| No guessing. No skipped validation.                              |
//| Mission Control receives ONLY validated (VALID) outputs.         |
//| Critical INVALID → decision process stops.                       |
//+------------------------------------------------------------------+

#define ULTRA_VCHAIN_MAX 14

enum ENUM_ULTRA_VSTATE
{
   UV_VALID   = 0,
   UV_INVALID = 1,
   UV_WAIT    = 2
};

struct UltraVMod
{
   string            name;
   ENUM_ULTRA_VSTATE state;
   bool              critical;
   string            detail;
};

struct UltraVChainState
{
   UltraVMod         mods[ULTRA_VCHAIN_MAX];
   int               n;
   ENUM_ULTRA_VSTATE overall;      // worst critical state (INVALID > WAIT > VALID)
   bool              missionReady; // true only when every critical module is VALID
   int               validN;
   int               invalidN;
   int               waitN;
   string            blocker;      // first critical non-VALID module
   string            summary;
   long              lastMs;
   string            symbol;
};

UltraVChainState g_UltraVChain;

//--------------------------------------------------------------------//
string UltraV_Name(const ENUM_ULTRA_VSTATE st)
{
   if(st == UV_VALID)   return "VALID";
   if(st == UV_INVALID) return "INVALID";
   return "WAIT";
}

void UltraVChain_Reset()
{
   g_UltraVChain.n = 0;
   g_UltraVChain.overall = UV_VALID;
   g_UltraVChain.missionReady = false;
   g_UltraVChain.validN = 0;
   g_UltraVChain.invalidN = 0;
   g_UltraVChain.waitN = 0;
   g_UltraVChain.blocker = "";
   g_UltraVChain.summary = "";
   g_UltraVChain.symbol = "";
}

void UltraV_Add(const string name, const ENUM_ULTRA_VSTATE st,
                const bool critical, const string detail)
{
   if(g_UltraVChain.n >= ULTRA_VCHAIN_MAX) return;
   int i = g_UltraVChain.n++;
   g_UltraVChain.mods[i].name = name;
   g_UltraVChain.mods[i].state = st;
   g_UltraVChain.mods[i].critical = critical;
   g_UltraVChain.mods[i].detail = detail;

   if(st == UV_VALID) g_UltraVChain.validN++;
   else if(st == UV_INVALID) g_UltraVChain.invalidN++;
   else g_UltraVChain.waitN++;
}

bool UltraVChain_MissionReady()
{
   if(!UltraVChainEnabled) return true;
   return g_UltraVChain.missionReady;
}

//--------------------------------------------------------------------//
// MODULE PROBES — read existing engines; never invent market state   //
//--------------------------------------------------------------------//
ENUM_ULTRA_VSTATE UltraV_ProbeFoundation(string &detail)
{
   detail = g_UltraFoundation.detail;
   if(!UltraFoundationEnabled)
   { detail = "disabled-pass"; return UV_VALID; }
   if(!g_UltraFoundation.booted)
   { detail = "not booted"; return UV_WAIT; }
   if(g_UltraFoundation.status == "RED")
   { detail = g_UltraFoundation.detail; return UV_INVALID; }
   // YELLOW continues trading by design — VALID with soft detail (not a guess)
   if(g_UltraFoundation.status == "GREEN" || g_UltraFoundation.status == "YELLOW")
   { detail = g_UltraFoundation.detail; return UV_VALID; }
   detail = "unknown status";
   return UV_WAIT;
}

ENUM_ULTRA_VSTATE UltraV_ProbeMarketIntel(string &detail)
{
   detail = g_UltraMarketIntel.detail;
   if(!UltraMarketIntelEnabled)
   { detail = "disabled-pass"; return UV_VALID; }
   if(!g_UltraMarketIntel.booted)
   { detail = "not booted"; return UV_WAIT; }
   // REJECTED = hard INVALID. DEGRADED is still approved (spread never sole reject).
   if(!g_UltraMarketIntel.approved || g_UltraMarketIntel.status == "REJECTED")
   { detail = g_UltraMarketIntel.detail; return UV_INVALID; }
   if(g_UltraMarketIntel.status == "APPROVED" || g_UltraMarketIntel.status == "DEGRADED")
   { detail = g_UltraMarketIntel.detail; return UV_VALID; }
   detail = "pending";
   return UV_WAIT;
}

ENUM_ULTRA_VSTATE UltraV_ProbeData(const string s, string &detail)
{
   detail = "";
   if(!UltraDataEngineEnabled)
   { detail = "disabled-pass"; return UV_VALID; }
   if(!g_UltraDataCache.valid)
   {
      UltraData_Refresh(s);
      if(!g_UltraDataCache.valid)
      { detail = "price invalid"; return UV_INVALID; }
   }
   if(g_UltraDataCache.bid <= 0.0 || g_UltraDataCache.ask < g_UltraDataCache.bid)
   { detail = "bid/ask invalid"; return UV_INVALID; }
   // integrityOK is advisory — valid prices are sufficient (no guess, no skip)
   detail = g_UltraDataCache.integrityOK ? "OK" : "OK soft-integrity";
   return UV_VALID;
}

ENUM_ULTRA_VSTATE UltraV_ProbeSnapshot(const string s, const UltraSnap &u, string &detail)
{
   detail = "";
   int bars = Bars(s, UltraETF());
   if(bars < 60)
   { detail = "history loading"; return UV_WAIT; }
   if(iTime(s, UltraETF(), 1) <= 0 || iClose(s, UltraETF(), 1) <= 0.0)
   { detail = "closed bar missing"; return UV_INVALID; }
   if(u.vol.atr < 0.0)
   { detail = "corrupt ATR"; return UV_INVALID; }
   if(u.vol.atr == 0.0)
   { detail = "ATR not ready"; return UV_WAIT; }
   detail = "OK";
   return UV_VALID;
}

ENUM_ULTRA_VSTATE UltraV_ProbeStructure(const UltraSnap &u, string &detail)
{
   // Structure module must have run — strength/quality filled; direction may be flat
   detail = "";
   if(u.st.strength < 0 || u.st.quality < 0)
   { detail = "corrupt structure"; return UV_INVALID; }
   // Flat / undecided structure is WAIT (no guessing)
   if(!(u.st.internalBull || u.st.internalBear || u.st.externalBull || u.st.externalBear ||
        u.trend.bull || u.trend.bear || u.bos.buy || u.bos.sell ||
        u.st.hh || u.st.hl || u.st.lh || u.st.ll))
   {
      detail = "structure undecided";
      return UV_WAIT;
   }
   detail = "OK";
   return UV_VALID;
}

ENUM_ULTRA_VSTATE UltraV_ProbeHealth(const string s, string &detail)
{
   detail = "";
   if(!UltraUpgradeEnabled || !UltraSystemHealthEnabled)
   { detail = "disabled-pass"; return UV_VALID; }
   // Reuse last status; light refresh if empty
   if(g_UltraSysHealth.status == "" || g_UltraSysHealth.status == "GREEN" ||
      g_UltraSysHealth.status == "YELLOW" || g_UltraSysHealth.status == "RED")
   {
      // Keep probe side-effect free of recovery spam: read flags directly
      bool connected = UltraBT_ConnectedOK();
      bool tradeAllow = UltraBT_TradeAllowed();
      bool dataOK = (Bars(s, UltraETF()) >= 60) && (SymbolInfoDouble(s, SYMBOL_BID) > 0.0);
      long tm = 0;
      bool brokerOK = SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) && (tm != 0);
      if(!connected || !tradeAllow || !dataOK || !brokerOK)
      {
         if(!connected) detail = "connection";
         else if(!tradeAllow) detail = "trade blocked";
         else if(!dataOK) detail = "data error";
         else detail = "broker/symbol";
         return UV_INVALID;
      }
      if(!UltraBT_SkipLiveOnly() && g_UltraCore.lastLatencyMs > 500)
      { detail = "latency"; return UV_WAIT; }
      detail = "OK";
      return UV_VALID;
   }
   detail = "pending";
   return UV_WAIT;
}

ENUM_ULTRA_VSTATE UltraV_ProbeCapital(string &detail)
{
   detail = "";
   if(!UltraCapitalProtectEnabled)
   { detail = "disabled-pass"; return UV_VALID; }
   string why = "";
   if(!UltraCapitalOK(why))
   { detail = why; return UV_INVALID; }
   detail = "OK";
   return UV_VALID;
}

ENUM_ULTRA_VSTATE UltraV_ProbeExec(const string s, string &detail)
{
   detail = "";
   // Use core exec readiness only (UFSE wrapper may assemble later — no circular dep)
   string why = "";
   if(!UltraExecReady(s, why))
   {
      detail = why;
      // Permission / broker hard fails → INVALID; cooldown / soft → WAIT
      if(StringFind(why, "trade") >= 0 || StringFind(why, "connect") >= 0 ||
         StringFind(why, "symbol") >= 0 || StringFind(why, "mode") >= 0)
         return UV_INVALID;
      return UV_WAIT;
   }
   detail = "OK";
   return UV_VALID;
}

ENUM_ULTRA_VSTATE UltraV_ProbeBroker(const string s, string &detail)
{
   detail = "";
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm) || tm == 0)
   { detail = "trade mode off"; return UV_INVALID; }
   if(!(bool)TerminalInfoInteger(TERMINAL_CONNECTED))
   { detail = "disconnected"; return UV_INVALID; }
   detail = "OK";
   return UV_VALID;
}

ENUM_ULTRA_VSTATE UltraV_ProbeScores(const UltraSnap &u, string &detail)
{
   detail = "";
   // Scores must be in-range; zero may mean not scored yet → WAIT (no guess)
   if(u.score.confidence < 0 || u.score.confidence > 100 ||
      u.score.precision < 0 || u.score.precision > 100 ||
      u.score.probability < 0 || u.score.probability > 100)
   { detail = "corrupt scores"; return UV_INVALID; }
   if(u.score.confidence == 0 && u.score.precision == 0 && u.score.probability == 0)
   { detail = "scores not computed"; return UV_WAIT; }
   detail = "OK";
   return UV_VALID;
}

//--------------------------------------------------------------------//
// COMPOSE OVERALL — INVALID beats WAIT beats VALID for critical mods //
//--------------------------------------------------------------------//
void UltraVChain_Compose()
{
   g_UltraVChain.overall = UV_VALID;
   g_UltraVChain.blocker = "";
   g_UltraVChain.missionReady = true;

   for(int i = 0; i < g_UltraVChain.n; i++)
   {
      if(!g_UltraVChain.mods[i].critical) continue;
      ENUM_ULTRA_VSTATE st = g_UltraVChain.mods[i].state;
      if(st == UV_INVALID)
      {
         g_UltraVChain.overall = UV_INVALID;
         if(StringLen(g_UltraVChain.blocker) == 0)
         {
            g_UltraVChain.blocker = g_UltraVChain.mods[i].name;
            g_UltraVChain.blocker += "=";
            g_UltraVChain.blocker += UltraV_Name(st);
            g_UltraVChain.blocker += " ";
            g_UltraVChain.blocker += g_UltraVChain.mods[i].detail;
         }
         if(UltraVChainBlockOnInvalid)
            g_UltraVChain.missionReady = false;
      }
      else if(st == UV_WAIT && g_UltraVChain.overall != UV_INVALID)
      {
         g_UltraVChain.overall = UV_WAIT;
         if(StringLen(g_UltraVChain.blocker) == 0)
         {
            g_UltraVChain.blocker = g_UltraVChain.mods[i].name;
            g_UltraVChain.blocker += "=";
            g_UltraVChain.blocker += UltraV_Name(st);
            g_UltraVChain.blocker += " ";
            g_UltraVChain.blocker += g_UltraVChain.mods[i].detail;
         }
         if(UltraVChainBlockOnWait)
            g_UltraVChain.missionReady = false;
      }
   }

   g_UltraVChain.summary = UltraV_Name(g_UltraVChain.overall);
   g_UltraVChain.summary += " V=";
   g_UltraVChain.summary += IntegerToString(g_UltraVChain.validN);
   g_UltraVChain.summary += " I=";
   g_UltraVChain.summary += IntegerToString(g_UltraVChain.invalidN);
   g_UltraVChain.summary += " W=";
   g_UltraVChain.summary += IntegerToString(g_UltraVChain.waitN);
   if(StringLen(g_UltraVChain.blocker) > 0)
   {
      g_UltraVChain.summary += " | ";
      g_UltraVChain.summary += g_UltraVChain.blocker;
   }
}

//--------------------------------------------------------------------//
// FULL CHAIN — call before Mission Control consumes module outputs   //
//--------------------------------------------------------------------//
ENUM_ULTRA_VSTATE UltraVChain_Evaluate(const string s, const UltraSnap &u, string &why)
{
   why = "";
   if(!UltraVChainEnabled)
   {
      UltraVChain_Reset();
      g_UltraVChain.overall = UV_VALID;
      g_UltraVChain.missionReady = true;
      g_UltraVChain.summary = "VALID disabled-pass";
      g_UltraCore.validated = true;
      return UV_VALID;
   }

   UltraVChain_Reset();
   g_UltraVChain.symbol = s;
   g_UltraVChain.lastMs = (long)GetTickCount();

   string d = "";

   // Order is the institutional validation chain — no skips
   ENUM_ULTRA_VSTATE st;

   st = UltraV_ProbeFoundation(d);
   UltraV_Add("FOUNDATION", st, true, d);

   st = UltraV_ProbeMarketIntel(d);
   UltraV_Add("MARKET", st, true, d);

   st = UltraV_ProbeData(s, d);
   UltraV_Add("DATA", st, true, d);

   st = UltraV_ProbeBroker(s, d);
   UltraV_Add("BROKER", st, true, d);

   st = UltraV_ProbeSnapshot(s, u, d);
   UltraV_Add("SNAPSHOT", st, true, d);

   st = UltraV_ProbeStructure(u, d);
   UltraV_Add("STRUCTURE", st, UltraVChainStrictStructure, d);

   st = UltraV_ProbeScores(u, d);
   UltraV_Add("SCORES", st, false, d); // scored later in decide — non-critical pre-score

   st = UltraV_ProbeHealth(s, d);
   UltraV_Add("HEALTH", st, true, d);

   st = UltraV_ProbeCapital(d);
   UltraV_Add("CAPITAL", st, true, d);

   st = UltraV_ProbeExec(s, d);
   UltraV_Add("EXEC", st, true, d);

   UltraVChain_Compose();
   why = g_UltraVChain.blocker;
   if(StringLen(why) == 0) why = g_UltraVChain.summary;

   g_UltraCore.validated = g_UltraVChain.missionReady;
   g_UltraCore.chainOK = g_UltraVChain.missionReady;

   if(UltraVChainLog && !g_UltraVChain.missionReady)
   {
      UltraLog("VCHAIN " + g_UltraVChain.summary);
   }
   return g_UltraVChain.overall;
}

// Post-score recheck — Mission Control final gate (scores become critical)
ENUM_ULTRA_VSTATE UltraVChain_EvaluateForMission(const string s, const UltraSnap &u, string &why)
{
   ENUM_ULTRA_VSTATE base = UltraVChain_Evaluate(s, u, why);
   if(!UltraVChainEnabled) return UV_VALID;
   if(base == UV_INVALID) return UV_INVALID;

   // Promote SCORES to critical for Mission hand-off
   string d = "";
   ENUM_ULTRA_VSTATE sc = UltraV_ProbeScores(u, d);
   // Replace or append scores module as critical
   bool found = false;
   for(int i = 0; i < g_UltraVChain.n; i++)
   {
      if(g_UltraVChain.mods[i].name == "SCORES")
      {
         g_UltraVChain.mods[i].state = sc;
         g_UltraVChain.mods[i].critical = true;
         g_UltraVChain.mods[i].detail = d;
         found = true;
         break;
      }
   }
   if(!found)
      UltraV_Add("SCORES", sc, true, d);

   // Recount
   g_UltraVChain.validN = g_UltraVChain.invalidN = g_UltraVChain.waitN = 0;
   for(int j = 0; j < g_UltraVChain.n; j++)
   {
      if(g_UltraVChain.mods[j].state == UV_VALID) g_UltraVChain.validN++;
      else if(g_UltraVChain.mods[j].state == UV_INVALID) g_UltraVChain.invalidN++;
      else g_UltraVChain.waitN++;
   }
   UltraVChain_Compose();
   why = g_UltraVChain.blocker;
   if(StringLen(why) == 0) why = g_UltraVChain.summary;
   g_UltraCore.validated = g_UltraVChain.missionReady;
   g_UltraCore.chainOK = g_UltraVChain.missionReady;

   if(UltraVChainLog && !g_UltraVChain.missionReady)
      UltraLog("VCHAIN MISSION " + g_UltraVChain.summary);

   return g_UltraVChain.overall;
}

void UltraVChain_Boot()
{
   UltraVChain_Reset();
   g_UltraVChain.overall = UV_WAIT;
   g_UltraVChain.summary = "WAIT boot";
   g_UltraCore.chainOK = false;
   if(!UltraVChainEnabled)
   {
      g_UltraVChain.overall = UV_VALID;
      g_UltraVChain.missionReady = true;
      g_UltraVChain.summary = "VALID disabled-pass";
      g_UltraCore.chainOK = true;
   }
   if(UltraVChainLog)
      UltraLog("VCHAIN boot enabled=" + (UltraVChainEnabled ? "Y" : "N"));
}

string UltraVChain_Dashboard()
{
   string t = "VCHAIN: ";
   if(!UltraVChainEnabled) { t += "OFF"; return t; }
   t += UltraV_Name(g_UltraVChain.overall);
   t += " V=";
   t += IntegerToString(g_UltraVChain.validN);
   t += " I=";
   t += IntegerToString(g_UltraVChain.invalidN);
   t += " W=";
   t += IntegerToString(g_UltraVChain.waitN);
   if(!g_UltraVChain.missionReady && StringLen(g_UltraVChain.blocker) > 0)
   {
      t += " | ";
      t += g_UltraVChain.blocker;
   }
   else if(g_UltraVChain.missionReady)
      t += " | MISSION_READY";
   return t;
}

#endif // HITMAN_ULTRA_VALIDATION_CHAIN_MQH
