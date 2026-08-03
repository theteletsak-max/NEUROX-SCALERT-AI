#ifndef HITMAN_ULTRA_EXECUTION_INTELLIGENCE_MQH
#define HITMAN_ULTRA_EXECUTION_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 8 · EXECUTION INTELLIGENCE       |
//| Prepare · broker-adapt · validate · submit · verify · sync       |
//| NEVER creates signals · NEVER changes strategy                   |
//| ONLY executes Mission Control decisions                          |
//+------------------------------------------------------------------+

// Shell_B / Dashboard (defined later in assemble)
bool HasSufficientMargin(ENUM_ORDER_TYPE orderType, double lot, double price);
void UltraDashboardIntel_NoteTradeRefresh();

enum ENUM_ULTRA_EXEC_OUTCOME
{
   UEXEC_NONE = 0,
   UEXEC_PREPARED,
   UEXEC_SUBMITTING,
   UEXEC_OPEN,
   UEXEC_VERIFIED,
   UEXEC_FAILED,
   UEXEC_RECOVERY_REQUIRED
};

struct UltraExecPacket
{
   bool   armed;
   bool   isBuy;
   string symbol;
   string comment;
   double volume;
   double entry;
   double sl;
   double tp;          // primary TP (TP1)
   double tp2;
   double tp3;
   long   magic;
   ENUM_ORDER_TYPE_FILLING filling;
   int    stopsLevel;
   int    freezeLevel;
   double volumeMin;
   double volumeMax;
   double volumeStep;
   double tickSize;
   double contractSize;
   long   preparedMs;
};

struct UltraExecIntelState
{
   bool   booted;
   bool   missionLocked;       // only Mission decisions allowed
   ENUM_ULTRA_EXEC_OUTCOME outcome;
   string outcomeName;
   string status;              // READY | PREPARED | OPEN | VERIFIED | FAILED | RECOVERY
   string detail;
   string symbol;
   bool   isBuy;
   double volume;
   double entry;
   double sl;
   double tp;
   ulong  orderTicket;
   ulong  positionTicket;
   uint   lastRetcode;
   int    retryCount;
   bool   verified;
   bool   synced;
   bool   recoveryRequired;
   // Broker intelligence snapshot
   int    stopsLevel;
   int    freezeLevel;
   int    fillingMode;
   double volumeMin;
   double volumeMax;
   double volumeStep;
   double tickSize;
   double contractSize;
   string fillingName;
   long   lastMs;
   ulong  prepareCount;
   ulong  submitCount;
   ulong  verifyCount;
   ulong  failCount;
   ulong  recoverCount;
};

UltraExecIntelState g_UltraExecIntel;
UltraExecPacket     g_UltraExecPacket;

//--------------------------------------------------------------------//
string UltraExecIntel_OutcomeName(const ENUM_ULTRA_EXEC_OUTCOME o)
{
   switch(o)
   {
      case UEXEC_PREPARED:           return "PREPARED";
      case UEXEC_SUBMITTING:         return "SUBMITTING";
      case UEXEC_OPEN:               return "POSITION_OPEN";
      case UEXEC_VERIFIED:           return "POSITION_VERIFIED";
      case UEXEC_FAILED:             return "POSITION_FAILED";
      case UEXEC_RECOVERY_REQUIRED:  return "RECOVERY_REQUIRED";
      default:                       return "NONE";
   }
}

void UltraExecIntel_Boot()
{
   g_UltraExecIntel.booted = true;
   g_UltraExecIntel.missionLocked = true;
   g_UltraExecIntel.outcome = UEXEC_NONE;
   g_UltraExecIntel.outcomeName = "NONE";
   g_UltraExecIntel.status = "READY";
   g_UltraExecIntel.detail = "boot";
   g_UltraExecIntel.symbol = "";
   g_UltraExecIntel.isBuy = true;
   g_UltraExecIntel.volume = g_UltraExecIntel.entry = 0.0;
   g_UltraExecIntel.sl = g_UltraExecIntel.tp = 0.0;
   g_UltraExecIntel.orderTicket = g_UltraExecIntel.positionTicket = 0;
   g_UltraExecIntel.lastRetcode = 0;
   g_UltraExecIntel.retryCount = 0;
   g_UltraExecIntel.verified = g_UltraExecIntel.synced = false;
   g_UltraExecIntel.recoveryRequired = false;
   g_UltraExecIntel.stopsLevel = g_UltraExecIntel.freezeLevel = 0;
   g_UltraExecIntel.fillingMode = 0;
   g_UltraExecIntel.volumeMin = g_UltraExecIntel.volumeMax = 0.0;
   g_UltraExecIntel.volumeStep = g_UltraExecIntel.tickSize = 0.0;
   g_UltraExecIntel.contractSize = 0.0;
   g_UltraExecIntel.fillingName = "RETURN";
   g_UltraExecIntel.lastMs = 0;
   g_UltraExecIntel.prepareCount = g_UltraExecIntel.submitCount = 0;
   g_UltraExecIntel.verifyCount = g_UltraExecIntel.failCount = 0;
   g_UltraExecIntel.recoverCount = 0;
   g_UltraExecPacket.armed = false;
}

void UltraExecIntel_SetOutcome(const ENUM_ULTRA_EXEC_OUTCOME o, const string detail)
{
   g_UltraExecIntel.outcome = o;
   g_UltraExecIntel.outcomeName = UltraExecIntel_OutcomeName(o);
   g_UltraExecIntel.detail = detail;
   g_UltraExecIntel.lastMs = (long)GetTickCount();
   if(o == UEXEC_PREPARED) g_UltraExecIntel.status = "PREPARED";
   else if(o == UEXEC_SUBMITTING) g_UltraExecIntel.status = "SUBMITTING";
   else if(o == UEXEC_OPEN) g_UltraExecIntel.status = "OPEN";
   else if(o == UEXEC_VERIFIED) g_UltraExecIntel.status = "VERIFIED";
   else if(o == UEXEC_FAILED) g_UltraExecIntel.status = "FAILED";
   else if(o == UEXEC_RECOVERY_REQUIRED) g_UltraExecIntel.status = "RECOVERY";
}

void UltraExecIntel_Log(const string verb)
{
   string line = "EXEC_INTEL ";
   line += verb;
   line += " ";
   line += g_UltraExecIntel.outcomeName;
   line += " ";
   line += g_UltraExecIntel.symbol;
   line += (g_UltraExecIntel.isBuy ? " BUY" : " SELL");
   line += " vol=";
   line += DoubleToString(g_UltraExecIntel.volume, 2);
   line += " entry=";
   line += DoubleToString(g_UltraExecIntel.entry, (int)SymbolInfoInteger(g_UltraExecIntel.symbol, SYMBOL_DIGITS));
   line += " sl=";
   line += DoubleToString(g_UltraExecIntel.sl, (int)SymbolInfoInteger(g_UltraExecIntel.symbol, SYMBOL_DIGITS));
   line += " tp=";
   line += DoubleToString(g_UltraExecIntel.tp, (int)SymbolInfoInteger(g_UltraExecIntel.symbol, SYMBOL_DIGITS));
   line += " ret=";
   line += IntegerToString((int)g_UltraExecIntel.lastRetcode);
   line += " ticket=";
   line += IntegerToString((int)g_UltraExecIntel.positionTicket);
   line += " | ";
   line += g_UltraExecIntel.detail;
   UltraLog(line);
}

//--------------------------------------------------------------------//
// §3 BROKER INTELLIGENCE — adapt to broker requirements              //
//--------------------------------------------------------------------//
void UltraExecIntel_BrokerRefresh(const string s)
{
   long stops = 0, freeze = 0, fill = 0;
   SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL, stops);
   SymbolInfoInteger(s, SYMBOL_TRADE_FREEZE_LEVEL, freeze);
   SymbolInfoInteger(s, SYMBOL_FILLING_MODE, fill);
   g_UltraExecIntel.stopsLevel = (int)stops;
   g_UltraExecIntel.freezeLevel = (int)freeze;
   g_UltraExecIntel.fillingMode = (int)fill;
   g_UltraExecIntel.volumeMin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   g_UltraExecIntel.volumeMax = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   g_UltraExecIntel.volumeStep = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   g_UltraExecIntel.tickSize = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   g_UltraExecIntel.contractSize = SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE);

   if((fill & SYMBOL_FILLING_FOK) != 0)
   { g_UltraExecPacket.filling = ORDER_FILLING_FOK; g_UltraExecIntel.fillingName = "FOK"; }
   else if((fill & SYMBOL_FILLING_IOC) != 0)
   { g_UltraExecPacket.filling = ORDER_FILLING_IOC; g_UltraExecIntel.fillingName = "IOC"; }
   else
   { g_UltraExecPacket.filling = ORDER_FILLING_RETURN; g_UltraExecIntel.fillingName = "RETURN"; }

   g_UltraExecPacket.stopsLevel = g_UltraExecIntel.stopsLevel;
   g_UltraExecPacket.freezeLevel = g_UltraExecIntel.freezeLevel;
   g_UltraExecPacket.volumeMin = g_UltraExecIntel.volumeMin;
   g_UltraExecPacket.volumeMax = g_UltraExecIntel.volumeMax;
   g_UltraExecPacket.volumeStep = g_UltraExecIntel.volumeStep;
   g_UltraExecPacket.tickSize = g_UltraExecIntel.tickSize;
   g_UltraExecPacket.contractSize = g_UltraExecIntel.contractSize;
}

//--------------------------------------------------------------------//
// §1 / §4 READY + VALIDATION (never signals)                         //
//--------------------------------------------------------------------//
bool UltraExecIntel_Ready(const string s, string &why)
{
   why = "";
   if(!UltraExecReady(s, why)) return false;
   UltraExecIntel_BrokerRefresh(s);
   if(g_UltraExecIntel.volumeMin <= 0.0)
   { why = "invalid volume min"; return false; }
   if(g_UltraExecIntel.tickSize <= 0.0)
   { why = "invalid tick size"; return false; }
   if(g_UltraExecIntel.contractSize <= 0.0)
   { why = "invalid contract size"; return false; }
   return true;
}

bool UltraExecIntel_MissionAllows(const bool isBuy, string &why)
{
   why = "";
   if(!g_UltraExecIntel.missionLocked) return true;
   // Only Mission Control decisions — Phase A sticky entry
   if(UltraPhaseA_MissionSoleAuthority)
   {
      if(!UltraMission_HasFinalEntry(isBuy))
      {
         why = "EXEC: no Mission final ";
         why += isBuy ? "BUY" : "SELL";
         return false;
      }
   }
   return true;
}

bool UltraExecIntel_ValidatePacket(const UltraExecPacket &p, string &why)
{
   why = "";
   if(!p.armed)
   { why = "order not prepared"; return false; }
   if(StringLen(p.symbol) == 0)
   { why = "missing symbol"; return false; }
   if(p.volume < p.volumeMin || (p.volumeMax > 0.0 && p.volume > p.volumeMax))
   { why = "invalid volume"; return false; }
   if(p.entry <= 0.0)
   { why = "invalid entry price"; return false; }
   if(p.sl <= 0.0)
   { why = "invalid stop loss"; return false; }
   // Broker stops distance
   double point = SymbolInfoDouble(p.symbol, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   double minDist = (double)p.stopsLevel * point;
   if(minDist > 0.0 && MathAbs(p.entry - p.sl) + 1e-12 < minDist)
   { why = "SL inside stops level"; return false; }
   if(p.tp > 0.0 && minDist > 0.0 && MathAbs(p.entry - p.tp) + 1e-12 < minDist)
   { why = "TP inside stops level"; return false; }
   // Freeze level is broker intel for modify/pending — never hard-block market entry
   // (live ≈ entry on market orders; a freeze check would reject every fill).
   if(p.magic == 0)
   { why = "magic number missing"; return false; }
   if(StringLen(p.comment) == 0)
   { why = "trade comment missing"; return false; }
   if(p.volumeStep > 0.0)
   {
      double steps = p.volume / p.volumeStep;
      if(MathAbs(steps - MathRound(steps)) > 1e-6)
      { why = "volume not on broker step"; return false; }
   }
   return true;
}

//--------------------------------------------------------------------//
// §2 ORDER PREPARATION                                               //
//--------------------------------------------------------------------//
bool UltraExecIntel_Prepare(const string s, const bool isBuy,
                            const double entry, const double sl,
                            const double tp1, const double tp2, const double tp3,
                            const double lot, string &why)
{
   why = "";
   g_UltraExecIntel.recoveryRequired = false;
   g_UltraExecIntel.verified = false;
   g_UltraExecIntel.synced = false;
   g_UltraExecIntel.orderTicket = 0;
   g_UltraExecIntel.positionTicket = 0;
   g_UltraExecIntel.lastRetcode = 0;

   if(!UltraExecIntel_MissionAllows(isBuy, why))
   {
      UltraExecIntel_SetOutcome(UEXEC_FAILED, why);
      g_UltraExecIntel.failCount++;
      UltraExecIntel_Log("BLOCK");
      return false;
   }

   if(!UltraExecIntel_Ready(s, why))
   {
      UltraExecIntel_SetOutcome(UEXEC_FAILED, why);
      g_UltraExecIntel.failCount++;
      UltraExecIntel_Log("NOT_READY");
      return false;
   }

   g_UltraExecPacket.armed = true;
   g_UltraExecPacket.isBuy = isBuy;
   g_UltraExecPacket.symbol = s;
   g_UltraExecPacket.comment = TradeComment;
   g_UltraExecPacket.volume = lot;
   g_UltraExecPacket.entry = entry;
   g_UltraExecPacket.sl = sl;
   g_UltraExecPacket.tp = tp1;
   g_UltraExecPacket.tp2 = tp2;
   g_UltraExecPacket.tp3 = tp3;
   g_UltraExecPacket.magic = MagicNumber;
   g_UltraExecPacket.preparedMs = (long)GetTickCount();

   // Prefer Risk Intel approved lot (Chapter 7)
   if(g_UltraRiskIntel.approved && g_UltraRiskIntel.approvedLot > 0.0)
      g_UltraExecPacket.volume = g_UltraRiskIntel.approvedLot;

   // Normalize volume to broker step before validation
   if(g_UltraExecPacket.volumeStep > 0.0)
   {
      double vs = g_UltraExecPacket.volumeStep;
      g_UltraExecPacket.volume = MathFloor(g_UltraExecPacket.volume / vs + 1e-12) * vs;
      if(g_UltraExecPacket.volume < g_UltraExecPacket.volumeMin)
         g_UltraExecPacket.volume = g_UltraExecPacket.volumeMin;
   }

   ENUM_ORDER_TYPE ot = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!HasSufficientMargin(ot, g_UltraExecPacket.volume, entry))
   {
      why = "insufficient margin";
      g_UltraExecPacket.armed = false;
      UltraExecIntel_SetOutcome(UEXEC_FAILED, why);
      g_UltraExecIntel.failCount++;
      UltraExecIntel_Log("MARGIN_FAIL");
      return false;
   }

   if(!UltraExecIntel_ValidatePacket(g_UltraExecPacket, why))
   {
      g_UltraExecPacket.armed = false;
      UltraExecIntel_SetOutcome(UEXEC_FAILED, why);
      g_UltraExecIntel.failCount++;
      UltraExecIntel_Log("VALIDATE_FAIL");
      return false;
   }

   g_UltraExecIntel.symbol = s;
   g_UltraExecIntel.isBuy = isBuy;
   g_UltraExecIntel.volume = g_UltraExecPacket.volume;
   g_UltraExecIntel.entry = entry;
   g_UltraExecIntel.sl = sl;
   g_UltraExecIntel.tp = tp1;
   g_UltraExecIntel.prepareCount++;
   UltraExecIntel_SetOutcome(UEXEC_PREPARED, "order prepared");
   UltraLL_SetPipelineStage(3); // Order Prepared
   UltraExecIntel_Log("PREPARE");
   return true;
}

//--------------------------------------------------------------------//
// §5–8 SUBMIT / VERIFY / RECOVERY / SYNC hooks (Shell owns g_Trade)  //
//--------------------------------------------------------------------//
void UltraExecIntel_NoteSubmitting()
{
   g_UltraExecIntel.submitCount++;
   UltraExecIntel_SetOutcome(UEXEC_SUBMITTING, "submitting to broker");
   UltraExecIntel_Log("SUBMIT");
}

bool UltraExecIntel_IsRecoverable(const uint retcode)
{
   return (retcode == TRADE_RETCODE_REQUOTE ||
           retcode == TRADE_RETCODE_PRICE_OFF ||
           retcode == TRADE_RETCODE_PRICE_CHANGED ||
           retcode == TRADE_RETCODE_TIMEOUT ||
           retcode == TRADE_RETCODE_CONNECTION ||
           retcode == TRADE_RETCODE_TOO_MANY_REQUESTS ||
           retcode == TRADE_RETCODE_INVALID_FILL ||
           retcode == TRADE_RETCODE_INVALID_PRICE);
}

void UltraExecIntel_NoteRetry(const uint retcode)
{
   g_UltraExecIntel.lastRetcode = retcode;
   g_UltraExecIntel.retryCount++;
   g_UltraExecIntel.recoverCount++;
   g_UltraExecIntel.recoveryRequired = true;
   UltraExecIntel_SetOutcome(UEXEC_RECOVERY_REQUIRED,
                             "recoverable retcode=" + IntegerToString((int)retcode));
   UltraExecIntel_Log("RECOVER");
}

void UltraExecIntel_NoteFailed(const uint retcode, const string why)
{
   g_UltraExecIntel.lastRetcode = retcode;
   g_UltraExecIntel.failCount++;
   g_UltraExecPacket.armed = false;
   UltraExecIntel_SetOutcome(UEXEC_FAILED, why);
   UltraExecIntel_Log("FAIL");
}

void UltraExecIntel_NoteOpen(const ulong orderTicket)
{
   g_UltraExecIntel.orderTicket = orderTicket;
   UltraExecIntel_SetOutcome(UEXEC_OPEN, "broker accepted order");
   UltraExecIntel_Log("OPEN");
}

bool UltraExecIntel_VerifyPosition(const ulong posTicket, string &why)
{
   why = "";
   if(posTicket == 0 || !PositionSelectByTicket(posTicket))
   { why = "position not found"; return false; }
   if(PositionGetString(POSITION_SYMBOL) != g_UltraExecIntel.symbol)
   { why = "symbol mismatch"; return false; }
   if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
   { why = "magic mismatch"; return false; }
   double vol = PositionGetDouble(POSITION_VOLUME);
   if(vol <= 0.0)
   { why = "zero volume"; return false; }
   // Volume should be near prepared (step tolerance)
   if(g_UltraExecIntel.volume > 0.0 &&
      MathAbs(vol - g_UltraExecIntel.volume) > MathMax(g_UltraExecIntel.volumeStep, 0.01) + 1e-9)
   {
      // soft warn — some brokers partial-fill; still verify
      g_UltraExecIntel.detail = "volume differs from prepared (partial?)";
   }
   g_UltraExecIntel.positionTicket = posTicket;
   g_UltraExecIntel.entry = PositionGetDouble(POSITION_PRICE_OPEN);
   g_UltraExecIntel.verified = true;
   g_UltraExecIntel.verifyCount++;
   UltraExecIntel_SetOutcome(UEXEC_VERIFIED, "position verified");
   UltraLL_SetPipelineStage(6); // Position Verified
   UltraExecIntel_Log("VERIFY");
   return true;
}

void UltraExecIntel_NoteSynced()
{
   g_UltraExecIntel.synced = true;
   g_UltraExecIntel.recoveryRequired = false;
   g_UltraExecPacket.armed = false;
   UltraLL_SetPipelineStage(7); // Protection / PosEvo ready
   if(g_UltraExecIntel.outcome != UEXEC_VERIFIED)
      UltraExecIntel_SetOutcome(UEXEC_VERIFIED, "position synchronized");
   UltraExecIntel_Log("SYNC");
   UltraDashboardIntel_NoteTradeRefresh(); // Ch14 immediate after trade
}

string UltraExecIntel_Dashboard()
{
   string t = "EXEC: ";
   t += g_UltraExecIntel.status;
   t += " ";
   t += g_UltraExecIntel.outcomeName;
   if(StringLen(g_UltraExecIntel.symbol) > 0)
   {
      t += " ";
      t += g_UltraExecIntel.symbol;
      t += (g_UltraExecIntel.isBuy ? " BUY" : " SELL");
   }
   t += " fill=";
   t += g_UltraExecIntel.fillingName;
   t += " ticket=";
   t += IntegerToString((int)g_UltraExecIntel.positionTicket);
   if(g_UltraExecIntel.retryCount > 0)
   {
      t += " retry=";
      t += IntegerToString(g_UltraExecIntel.retryCount);
   }
   return t;
}

#endif // HITMAN_ULTRA_EXECUTION_INTELLIGENCE_MQH
