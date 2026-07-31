#ifndef HITMAN_ULTRA_UFSE_MQH
#define HITMAN_ULTRA_UFSE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA FAST SIGNAL ENGINE v1.0                         |
//| Real-time scanner · Event-driven cache · Priority · Locks · Debug |
//+------------------------------------------------------------------+

#define UFSE_MAX_SYM 48

struct UltraTickScan
{
   double   bid;
   double   ask;
   double   last;
   long     tickVol;
   double   spread;
   int      dir;          // +1 up / -1 down / 0 flat
   double   speed;        // approx ticks/sec
   datetime t;
   bool     valid;
};

struct UltraSymUFSE
{
   string        symbol;
   UltraTickScan tick;
   UltraSnap     snap;
   bool          snapValid;
   datetime      barTime;
   double        cacheBid;
   double        cacheAsk;
   bool          dirtyCritical;   // tick/structure/BOS/CHoCH class
   bool          dirtyMedium;     // fib/vol/session class
   int           masterTrend;     // +1 BUY / -1 SELL / 0 none
   bool          signalLocked;
   bool          lockedIsBuy;
   datetime      lockBar;
   bool          prevBosBuy, prevBosSell;
   bool          prevChochBuy, prevChochSell;
   bool          prevSweepBuy, prevSweepSell;
   datetime      lastEvalBar;
   string        lastDebug;
   ulong         tickCount;
   ulong         cacheHits;
   ulong         fullRebuilds;
};

UltraSymUFSE g_UFSE[UFSE_MAX_SYM];
int          g_UFSE_N = 0;
datetime     g_UFSE_SpeedWindowStart = 0;
int          g_UFSE_SpeedTickCount = 0;

//--------------------------------------------------------------------//
// Inputs (also listed in 31_Inputs via shared names below)           //
//--------------------------------------------------------------------//
// UltraFastSignalEnabled, UltraMasterTrendLock, UltraSignalLock,
// UltraUFSE_ExplainLog — declared in 31_Inputs.mqh (input bool; function name differs)

int UltraUFSE_Find(const string s)
{
   for(int i = 0; i < g_UFSE_N; i++)
      if(g_UFSE[i].symbol == s) return i;
   return -1;
}

int UltraUFSE_Ensure(const string s)
{
   int idx = UltraUFSE_Find(s);
   if(idx >= 0) return idx;
   if(g_UFSE_N >= UFSE_MAX_SYM) return 0;
   idx = g_UFSE_N++;
   UltraSymUFSE z;
   z.symbol = s;
   z.snapValid = false;
   z.barTime = 0;
   z.cacheBid = z.cacheAsk = 0;
   z.dirtyCritical = true;
   z.dirtyMedium = true;
   z.masterTrend = 0;
   z.signalLocked = false;
   z.lockedIsBuy = false;
   z.lockBar = 0;
   z.prevBosBuy = z.prevBosSell = false;
   z.prevChochBuy = z.prevChochSell = false;
   z.prevSweepBuy = z.prevSweepSell = false;
   z.lastEvalBar = 0;
   z.lastDebug = "";
   z.tickCount = z.cacheHits = z.fullRebuilds = 0;
   UltraTickScan blank; blank.bid=blank.ask=blank.last=blank.spread=blank.speed=0; blank.tickVol=0; blank.dir=0; blank.t=0; blank.valid=false;
   z.tick = blank;
   // snap left uninitialized until first build (avoid ZeroMemory on string fields)
   g_UFSE[idx] = z;
   g_UFSE[idx].symbol = s;
   return idx;
}

//--------------------------------------------------------------------//
// 1. REAL-TIME MARKET SCANNER                                        //
//--------------------------------------------------------------------//
void UltraUFSE_ScanTick(const int idx)
{
   if(idx < 0 || idx >= g_UFSE_N) return;
   string s = g_UFSE[idx].symbol;
   UltraTickScan prev = g_UFSE[idx].tick;

   UltraTickScan t;
   t.bid = SymbolInfoDouble(s, SYMBOL_BID);
   t.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   t.last = SymbolInfoDouble(s, SYMBOL_LAST);
   if(t.last <= 0.0) t.last = t.bid;
   t.tickVol = (long)iTickVolume(s, UltraETF(), 0);
   if(t.tickVol <= 0) t.tickVol = (long)iVolume(s, UltraETF(), 0);
   long spr = 0; SymbolInfoInteger(s, SYMBOL_SPREAD, spr);
   t.spread = (double)spr;
   t.t = TimeCurrent();
   t.dir = 0;
   if(prev.valid)
   {
      if(t.bid > prev.bid) t.dir = 1;
      else if(t.bid < prev.bid) t.dir = -1;
   }
   // tick speed: rolling 1s window
   if(g_UFSE_SpeedWindowStart <= 0 || t.t != g_UFSE_SpeedWindowStart)
   {
      if(g_UFSE_SpeedWindowStart > 0 && t.t > g_UFSE_SpeedWindowStart)
         t.speed = (double)g_UFSE_SpeedTickCount / MathMax(1.0, (double)(t.t - g_UFSE_SpeedWindowStart));
      else
         t.speed = (double)g_UFSE_SpeedTickCount;
      g_UFSE_SpeedWindowStart = t.t;
      g_UFSE_SpeedTickCount = 1;
   }
   else
   {
      g_UFSE_SpeedTickCount++;
      t.speed = (double)g_UFSE_SpeedTickCount;
   }
   t.valid = (t.bid > 0.0 && t.ask > 0.0);
   g_UFSE[idx].tick = t;
   g_UFSE[idx].tickCount++;

   // feed shared data cache
   g_UltraDataCache.symbol = s;
   g_UltraDataCache.bid = t.bid;
   g_UltraDataCache.ask = t.ask;
   g_UltraDataCache.spreadPts = t.spread;
   g_UltraDataCache.barTime = iTime(s, UltraETF(), 0);
   g_UltraDataCache.valid = t.valid;
}

//--------------------------------------------------------------------//
// 2/4/5. EVENT FLAGS + PRIORITY                                      //
//--------------------------------------------------------------------//
void UltraUFSE_UpdateDirty(const int idx)
{
   if(idx < 0 || idx >= g_UFSE_N) return;
   string s = g_UFSE[idx].symbol;
   datetime bar = iTime(s, UltraETF(), 0);
   double bid = g_UFSE[idx].tick.bid;
   double ask = g_UFSE[idx].tick.ask;

   bool newBar = (bar > 0 && bar != g_UFSE[idx].barTime);
   bool priceChanged = (bid != g_UFSE[idx].cacheBid || ask != g_UFSE[idx].cacheAsk);
   bool bigMove = false;
   double pt = SymbolInfoDouble(s, SYMBOL_POINT);
   if(pt > 0.0 && g_UFSE[idx].cacheBid > 0.0)
      bigMove = (MathAbs(bid - g_UFSE[idx].cacheBid) >= pt * 8.0);

   // Critical: new bar / structure-class move
   g_UFSE[idx].dirtyCritical = (!g_UFSE[idx].snapValid) || newBar || bigMove;
   // Medium: any price change without new bar
   g_UFSE[idx].dirtyMedium = priceChanged && !newBar;
}

bool UltraUFSE_CacheFresh(const int idx)
{
   if(idx < 0 || idx >= g_UFSE_N) return false;
   if(!g_UFSE[idx].snapValid) return false;
   if(g_UFSE[idx].dirtyCritical) return false;
   // unchanged bid/ask + same bar → cache hit
   if(!g_UFSE[idx].dirtyMedium &&
      g_UFSE[idx].tick.bid == g_UFSE[idx].cacheBid &&
      g_UFSE[idx].tick.ask == g_UFSE[idx].cacheAsk)
      return true;
   return false;
}

//--------------------------------------------------------------------//
// 7. MULTI-TIMEFRAME CACHE (master trend from HTF)                   //
//--------------------------------------------------------------------//
int UltraUFSE_CalcMasterTrend(const UltraSnap &u)
{
   int score = 0;
   if(u.trend.monthBull) score++; if(u.trend.monthBear) score--;
   if(u.trend.weekBull)  score++; if(u.trend.weekBear)  score--;
   if(u.trend.macroBull) score++; if(u.trend.macroBear) score--;
   if(u.trend.htfBull)   score++; if(u.trend.htfBear)   score--;
   if(score > 0) return 1;
   if(score < 0) return -1;
   // fallback to votes
   if(u.trend.mtfVotesBuy > u.trend.mtfVotesSell) return 1;
   if(u.trend.mtfVotesSell > u.trend.mtfVotesBuy) return -1;
   return 0;
}

//--------------------------------------------------------------------//
// 8. EARLY SETUP DETECTION (event edges)                             //
//--------------------------------------------------------------------//
bool UltraUFSE_DetectEarlyEdge(const int idx, const UltraSnap &u)
{
   if(idx < 0 || idx >= g_UFSE_N) return false;
   if(u.bos.buy && !g_UFSE[idx].prevBosBuy) return true;
   if(u.bos.sell && !g_UFSE[idx].prevBosSell) return true;
   if(u.choch.buy && !g_UFSE[idx].prevChochBuy) return true;
   if(u.choch.sell && !g_UFSE[idx].prevChochSell) return true;
   if(u.liq.sweepBuy && !g_UFSE[idx].prevSweepBuy) return true;
   if(u.liq.sweepSell && !g_UFSE[idx].prevSweepSell) return true;
   return false;
}

void UltraUFSE_CommitEarlyFlags(const int idx, const UltraSnap &u)
{
   if(idx < 0 || idx >= g_UFSE_N) return;
   g_UFSE[idx].prevBosBuy = u.bos.buy;
   g_UFSE[idx].prevBosSell = u.bos.sell;
   g_UFSE[idx].prevChochBuy = u.choch.buy;
   g_UFSE[idx].prevChochSell = u.choch.sell;
   g_UFSE[idx].prevSweepBuy = u.liq.sweepBuy;
   g_UFSE[idx].prevSweepSell = u.liq.sweepSell;
}

bool UltraUFSE_EarlyEvent(const int idx, const UltraSnap &u)
{
   bool edge = UltraUFSE_DetectEarlyEdge(idx, u);
   UltraUFSE_CommitEarlyFlags(idx, u);
   return edge;
}

//--------------------------------------------------------------------//
// 11. SIGNAL LOCK                                                    //
//--------------------------------------------------------------------//
void UltraUFSE_Lock(const int idx, const bool isBuy)
{
   if(idx < 0 || idx >= g_UFSE_N) return;
   g_UFSE[idx].signalLocked = true;
   g_UFSE[idx].lockedIsBuy = isBuy;
   g_UFSE[idx].lockBar = iTime(g_UFSE[idx].symbol, UltraETF(), 0);
}

void UltraUFSE_Unlock(const int idx)
{
   if(idx < 0 || idx >= g_UFSE_N) return;
   g_UFSE[idx].signalLocked = false;
   g_UFSE[idx].lockBar = 0;
}

void UltraUFSE_MaybeUnlock(const int idx, const UltraSnap &u)
{
   if(idx < 0 || idx >= g_UFSE_N) return;
   if(!g_UFSE[idx].signalLocked) return;

   if(UltraSymDir(g_UFSE[idx].symbol) == 0)
   {
      bool fresh = UltraUFSE_DetectEarlyEdge(idx, u);
      if(fresh)
         UltraUFSE_Unlock(idx);
      int mt = UltraUFSE_CalcMasterTrend(u);
      if(mt != 0 && ((g_UFSE[idx].lockedIsBuy && mt < 0) || (!g_UFSE[idx].lockedIsBuy && mt > 0)))
         UltraUFSE_Unlock(idx);
   }
}

bool UltraUFSE_LockBlocks(const int idx, const bool wantBuy)
{
   if(idx < 0 || idx >= g_UFSE_N) return false;
   if(!UltraSignalLockEnabled) return false;
   if(!g_UFSE[idx].signalLocked) return false;
   // block duplicate same-direction while locked; allow opposite only after unlock
   if(g_UFSE[idx].lockedIsBuy == wantBuy) return true;
   return true; // while locked, block all new entries until unlock rules fire
}

//--------------------------------------------------------------------//
// 12. MASTER TREND LOCK                                              //
//--------------------------------------------------------------------//
bool UltraUFSE_MasterAllows(const int idx, const bool wantBuy, string &why)
{
   why = "";
   if(!UltraMasterTrendLock) return true;
   // InstantQuality: chart TF Cont/Fib can run against mild HTF mix
   if(InstantQualityMode) return true;
   if(idx < 0 || idx >= g_UFSE_N) return true;
   int mt = g_UFSE[idx].masterTrend;
   if(mt == 0) return true; // no clear master — allow (InstantQuality)
   if(wantBuy && mt < 0){ why = "master trend SELL lock"; return false; }
   if(!wantBuy && mt > 0){ why = "master trend BUY lock"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// 10. EXECUTION READINESS                                            //
//--------------------------------------------------------------------//
bool UltraUFSE_ExecReady(const string s, string &why)
{
   why = "";
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)){ why = "terminal disconnected"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why = "trading not allowed"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)){ why = "EA trading disabled"; return false; }
   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm)){ why = "symbol mode unavailable"; return false; }
   if(tm == 0){ why = "symbol trade disabled"; return false; }
   double bid = SymbolInfoDouble(s, SYMBOL_BID);
   double ask = SymbolInfoDouble(s, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0){ why = "price not fresh"; return false; }
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq <= 0.0){ why = "bad equity"; return false; }
   if(fm <= 0.0){ why = "no free margin"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// 13. ENTRY TRIGGER                                                  //
//--------------------------------------------------------------------//
bool UltraUFSE_EntryTrigger(const UltraSnap &u, const bool buySide, string &why)
{
   why = "";
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   bool bosCh = buySide ? (u.bos.buy || u.choch.buy) : (u.bos.sell || u.choch.sell);
   bool liq   = buySide ? (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.grabBuy || u.liq.equalLows)
                        : (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.grabSell || u.liq.equalHighs);
   bool mom   = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy || u.ind.smi > 0)
                        : (u.mom.momSell || u.mom.impulse || u.ict.dispSell || u.ind.smi < 0);
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull)
                        : (u.trend.bear || u.trend.htfBear || u.trend.macroBear);

   if(InstantQualityMode)
   {
      int n = (structure?1:0)+(bosCh?1:0)+(liq?1:0)+(mom?1:0)+(trend?1:0);
      // ContSniper InstantQuality is 2-of-3 — match that here (was 3/5 WAIT spam)
      if(n < 2){ why = "entry trigger soft fail "+IntegerToString(n)+"/5"; return false; }
   }
   else
   {
      if(!trend){ why = "master/trend fail"; return false; }
      if(!structure){ why = "structure fail"; return false; }
      if(!bosCh){ why = "BOS/CHoCH fail"; return false; }
      if(!liq){ why = "liquidity fail"; return false; }
      if(!mom){ why = "momentum fail"; return false; }
   }
   if(u.score.precision < UltraMinPrecision && u.score.confidence < UltraInstantFireConf)
   { why = "precision threshold"; return false; }
   if(u.score.probability < UltraMinProbability && u.score.confidence < UltraInstantFireConf)
   { why = "probability threshold"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// 9. SMART SIGNAL FILTER                                             //
//--------------------------------------------------------------------//
bool UltraUFSE_SmartFilter(const int idx, const bool buySide, const UltraSnap &u, string &why)
{
   why = "";
   if(idx < 0 || idx >= g_UFSE_N) return true;
   datetime bar = iTime(g_UFSE[idx].symbol, UltraETF(), 0);
   // same-candle duplicate
   if(bar > 0 && bar == g_UFSE[idx].lastEvalBar && g_UFSE[idx].signalLocked)
   { why = "same-candle duplicate"; return false; }
   // weak structure
   if(u.st.quality < 25 && !InstantQualityMode)
   { why = "weak structure"; return false; }
   // low confidence
   if(!UltraPassScore(u.score.confidence) && u.score.confidence < UltraInstantFireConf)
   { why = "low-confidence setup"; return false; }
   if(UltraUFSE_LockBlocks(idx, buySide))
   { why = "signal lock"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// 15. DEBUG OUTPUT                                                   //
//--------------------------------------------------------------------//
string UltraUFSE_DebugExplain(const UltraSnap &u, const bool buySide, const bool approved)
{
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   bool bos   = buySide ? u.bos.buy : u.bos.sell;
   bool choch = buySide ? u.choch.buy : u.choch.sell;
   bool liq   = buySide ? (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.equalLows)
                        : (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.equalHighs);
   bool mom   = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
                        : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull)
                        : (u.trend.bear || u.trend.htfBear || u.trend.macroBear);

   string head = "NO TRADE";
   if(approved)
   {
      if(buySide) head = "BUY SIGNAL";
      else head = "SELL SIGNAL";
   }

   string t = head;
   t += "\nTrend ........ "; if(trend) t += "PASS"; else t += "FAIL";
   t += "\nStructure .... "; if(structure) t += "PASS"; else t += "FAIL";
   t += "\nBOS .......... "; if(bos) t += "PASS"; else t += "FAIL";
   t += "\nCHoCH ........ "; if(choch) t += "PASS"; else t += "FAIL";
   t += "\nLiquidity .... "; if(liq) t += "PASS"; else t += "FAIL";
   t += "\nMomentum ..... "; if(mom) t += "PASS"; else t += "FAIL";
   t += "\n\nConfidence ... "; t += IntegerToString(u.score.confidence); t += "%";
   t += "\nPrecision .... "; t += IntegerToString(u.score.precision); t += "%";
   t += "\nProbability .. "; t += IntegerToString(u.score.probability); t += "%";
   t += "\n\nDecision ..... ";
   if(approved){ if(buySide) t += "BUY"; else t += "SELL"; }
   else t += "WAIT";
   return t;
}

//--------------------------------------------------------------------//
// PIPELINE: Tick → Data → (cached) engines → Decision helpers        //
//--------------------------------------------------------------------//
bool UltraUFSE_BuildSnapshot(const string s, UltraSnap &u, bool &fromCache)
{
   fromCache = false;
   int idx = UltraUFSE_Ensure(s);
   UltraUFSE_ScanTick(idx);
   UltraUFSE_UpdateDirty(idx);

   if(!UltraFastSignalEnabled)
      return UltraBuildSnapshot(s, u);

   if(UltraUFSE_CacheFresh(idx))
   {
      u = g_UFSE[idx].snap;
      fromCache = true;
      g_UFSE[idx].cacheHits++;
      UltraUFSE_MaybeUnlock(idx, u);
      return true;
   }

   // Full rebuild (critical or medium price change)
   if(!UltraBuildSnapshot(s, u))
   {
      g_UFSE[idx].snapValid = false;
      return false;
   }

   g_UFSE[idx].snap = u;
   g_UFSE[idx].snapValid = true;
   g_UFSE[idx].barTime = iTime(s, UltraETF(), 0);
   g_UFSE[idx].cacheBid = g_UFSE[idx].tick.bid;
   g_UFSE[idx].cacheAsk = g_UFSE[idx].tick.ask;
   g_UFSE[idx].dirtyCritical = false;
   g_UFSE[idx].dirtyMedium = false;
   g_UFSE[idx].masterTrend = UltraUFSE_CalcMasterTrend(u);
   g_UFSE[idx].fullRebuilds++;
   UltraUFSE_EarlyEvent(idx, u);
   UltraUFSE_MaybeUnlock(idx, u);
   return true;
}

string UltraUFSE_Stats(const string s)
{
   int idx = UltraUFSE_Find(s);
   if(idx < 0) return "UFSE n/a";
   string master = "FLAT";
   if(g_UFSE[idx].masterTrend > 0) master = "BUY";
   else if(g_UFSE[idx].masterTrend < 0) master = "SELL";
   string lock = "N";
   if(g_UFSE[idx].signalLocked) lock = "Y";
   string t = "ticks=";
   t += IntegerToString((int)g_UFSE[idx].tickCount);
   t += " hits=";
   t += IntegerToString((int)g_UFSE[idx].cacheHits);
   t += " rebuilds=";
   t += IntegerToString((int)g_UFSE[idx].fullRebuilds);
   t += " master=";
   t += master;
   t += " lock=";
   t += lock;
   t += " spd=";
   t += DoubleToString(g_UFSE[idx].tick.speed, 1);
   return t;
}

//--------------------------------------------------------------------//
// LIVE DECISION + EVALUATE (wired to Ultra Fast Signal Engine)       //
//--------------------------------------------------------------------//
bool UltraAIDecide(const string s, UltraSnap &u, UltraSignal &sig, string &why)
{
   why = "";
   sig.buy = sig.sell = false; sig.tag = "NONE"; sig.reason = ""; sig.score = 0; sig.explanation = "";

   string capWhy = "";
   if(!UltraCapitalOK(capWhy)){ why = "capital: " + capWhy; return false; }
   string exWhy = "";
   if(UltraFastSignalEnabled)
   {
      if(!UltraUFSE_ExecReady(s, exWhy)){ why = "exec: " + exWhy; return false; }
   }
   else
   {
      if(!UltraExecReady(s, exWhy)){ why = "exec: " + exWhy; return false; }
   }

   sig = UltraPickBest(u);
   if(!(sig.buy || sig.sell) || sig.tag == "NONE")
   {
      why = "no strategy: " + sig.reason;
      return false;
   }

   UltraEngScores(u, sig.buy);
   int floor = UltraFireFloor();
   if(u.score.confidence < floor && u.score.confidence < UltraInstantFireConf &&
      !(InstantQualityMode && u.score.confidence >= floor - 8))
   { why = "confidence low"; return false; }
   if(u.score.precision < UltraMinPrecision && u.score.confidence < UltraInstantFireConf)
   { why = "precision low"; return false; }
   if(u.score.probability < UltraMinProbability && u.score.confidence < UltraInstantFireConf)
   { why = "probability low"; return false; }

   // DEFENSE LINE ENGINE v1.0 — Lines 1-7 + 10 (GREEN / YELLOW / RED)
   if(UltraDefenseEnabled && UltraDefenseGateEntry)
   {
      UltraDefenseReport defR;
      string defWhy = "";
      if(!UltraDefense_EvaluateEntry(s, u, sig.buy, defR, defWhy))
      {
         why = defWhy;
         UltraDefense_MaybeLog(s, defR);
         return false;
      }
   }

   if(UltraFastSignalEnabled)
   {
      int idx = UltraUFSE_Ensure(s);
      string mtWhy = "";
      if(!UltraUFSE_MasterAllows(idx, sig.buy, mtWhy))
      { why = mtWhy; return false; }

      if(UltraUFSE_EntryTriggerGate)
      {
         string trWhy = "";
         if(!UltraUFSE_EntryTrigger(u, sig.buy, trWhy))
         { why = trWhy; return false; }
      }

      string fWhy = "";
      if(!UltraUFSE_SmartFilter(idx, sig.buy, u, fWhy))
      { why = fWhy; return false; }
   }

   // Position Evolution replace arm: require matching direction + replace floor
   bool replaceArm = (UltraPosEvoEnabled && UltraPosEvoReplaceEnabled && UltraPosEvo_ReplacePending(s));
   if(replaceArm)
   {
      string rWhy = "";
      bool wantBuy = g_UltraPosEvoReplace.wantBuy;
      if((wantBuy && !sig.buy) || (!wantBuy && !sig.sell))
      { why = "REPLACE: signal not opposite validated direction"; return false; }
      if(!UltraPosEvo_ReplaceAllowsEntry(s, wantBuy, rWhy))
      { why = rWhy; return false; }
      if(u.score.confidence < g_UltraPosEvoReplace.minConf)
      { why = "REPLACE: confidence below armed floor"; return false; }
      // Unlock so lock does not block validated replacement
      int ridx = UltraUFSE_Ensure(s);
      if(ridx >= 0) UltraUFSE_Unlock(ridx);
      if(StringLen(sig.reason) > 0) sig.reason = sig.reason + " | ";
      sig.reason = sig.reason + g_UltraPosEvoReplace.reason;
   }

   if(UltraBlockOppositeSameSym && !replaceArm)
   {
      int d = UltraSymDir(s);
      if(sig.buy && d < 0){ why = "opposite SELL open"; return false; }
      if(sig.sell && d > 0){ why = "opposite BUY open"; return false; }
   }

   // TRADE ENTRY DISCIPLINE ENGINE v1.0 — Rules #1-#12 (irregular trade prevention)
   if(UltraDisciplineEnabled)
   {
      string discWhy = "";
      if(!UltraDiscipline_AllowEntry(s, u, sig, discWhy))
      {
         why = discWhy;
         return false;
      }
      // attach explainable thesis onto signal reason trail
      int didx = UltraDisc_Find(s);
      if(didx >= 0 && StringLen(g_UltraDisc[didx].lastThesis) > 0)
      {
         if(StringLen(sig.reason) > 0) sig.reason = sig.reason + " | ";
         sig.reason = sig.reason + g_UltraDisc[didx].lastThesis;
      }
   }

   // ULTRA X — LEVEL 8 MISSION CONTROL (sole entry authority)
   if(UltraUpgradeEnabled && UltraSupremeEnabled)
   {
      string supWhy = "";
      if(!UltraMission_ApproveEntry(s, u, sig, supWhy))
      {
         if(StringLen(supWhy) > 0) why = supWhy;
         else why = "MISSION WAIT";
         return false;
      }
   }
   return true;
}

void EvaluateStrategySignals(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   buySignal = false;
   sellSignal = false;
   strategyTag = "";

   UltraSnap snap;
   bool fromCache = false;
   bool built = false;
   if(UltraFastSignalEnabled)
      built = UltraUFSE_BuildSnapshot(BrokerSymbol, snap, fromCache);
   else
      built = UltraBuildSnapshot(BrokerSymbol, snap);

   if(!built)
   {
      if(EnableVerboseLogging)
         Print("ULTRA snapshot failed: ", g_UltraCore.lastError, " on ", BrokerSymbol);
      g_UltraLastSnap = snap;
      return;
   }

   UltraSignal best;
   string why = "";
   if(!UltraAIDecide(BrokerSymbol, snap, best, why))
   {
      g_UltraLastSnap = snap;
      bool leanBuy = (UltraConfluenceBuy(snap) >= UltraConfluenceSell(snap));
      best.explanation = UltraUFSE_DebugExplain(snap, leanBuy, false);
      g_UltraLastSignal = best;
      datetime bar = iTime(BrokerSymbol, UltraETF(), 0);
      bool logIt = (EnableVerboseLogging || ContStruct_LogDetail || UltraUFSE_ExplainLog) &&
                   (bar != g_UltraLastWaitBar || BrokerSymbol != g_UltraLastWaitSym);
      if(logIt)
      {
         g_UltraLastWaitBar = bar;
         g_UltraLastWaitSym = BrokerSymbol;
         UltraEvent_Note(UEV_WAIT);
         string cacheTag = "REBUILD";
         if(fromCache) cacheTag = "HIT";
         Print("ULTRA wait [", why, "] conf=", snap.score.confidence,
               " prec=", snap.score.precision, " prob=", snap.score.probability,
               " regime=", UltraRegimeName(snap.regime),
               " cache=", cacheTag,
               " ", UltraUFSE_Stats(BrokerSymbol),
               " on ", BrokerSymbol);
         if(UltraUFSE_ExplainLog)
            Print(best.explanation);
      }
      return;
   }

   buySignal = best.buy;
   sellSignal = best.sell;
   strategyTag = best.tag;
   best.explanation = UltraUFSE_DebugExplain(snap, best.buy, true);
   g_UltraLastSnap = snap;
   g_UltraLastSignal = best;

   if(UltraFastSignalEnabled)
   {
      int idx = UltraUFSE_Ensure(BrokerSymbol);
      UltraUFSE_Lock(idx, best.buy);
      g_UFSE[idx].lastEvalBar = iTime(BrokerSymbol, UltraETF(), 0);
   }
   UltraExec_MarkFired(BrokerSymbol);
   UltraEvent_Note(UEV_FIRE);

   string sideTag = "SELL";
   if(best.buy) sideTag = "BUY";
   string cacheTag2 = "REBUILD";
   if(fromCache) cacheTag2 = "HIT";
   Print("ULTRA FIRE ", sideTag, " [", best.tag, "] conf=", snap.score.confidence,
         " prec=", snap.score.precision, " prob=", snap.score.probability,
         " ", best.reason, " SMI=", DoubleToString(snap.ind.smi, 1),
         " session=", snap.ctx.session,
         " cache=", cacheTag2,
         " ", UltraUFSE_Stats(BrokerSymbol),
         " on ", BrokerSymbol);
   if(UltraUFSE_ExplainLog)
      Print(best.explanation);
}

#endif // HITMAN_ULTRA_UFSE_MQH
