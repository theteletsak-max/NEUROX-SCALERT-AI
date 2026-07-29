#ifndef SNIPER_ULTRA_03_AI_MQH
#define SNIPER_ULTRA_03_AI_MQH
//+------------------------------------------------------------------+
//| 03. AI Decision Core                                             |
//| Confluence · Precision · Probability · Strategies · Approval     |
//+------------------------------------------------------------------+
int UltraConfluenceBuy(const UltraSnap &u)
{
   int sc = 0;
   if(u.trend.htfBull) sc += 10; if(u.trend.macroBull) sc += 6; if(u.trend.bull) sc += 8;
   if(u.bos.buy) sc += 10; if(u.choch.buy) sc += 8;
   if(u.liq.sweepBuy) sc += 14; if(u.liq.stopHuntBuy) sc += 5;
   if(u.ict.dispBuy) sc += 10; if(u.ict.fvgBuy) sc += 6; if(u.ict.obBuy) sc += 6;
   if(u.ict.breakerBuy) sc += 4; if(u.ict.instZoneBuy) sc += 6;
   if(u.fib.atBuyZone) sc += 8; if(u.ict.inDiscount) sc += 5;
   if(u.mom.momBuy) sc += 4; if(u.ind.smi > 20) sc += 4; if(u.ind.ifi > 15) sc += 4;
   if(u.ind.meo >= 55) sc += 3;
   if(UltraBoostKillZone && u.ctx.killZone) sc += 3;
   if(UltraBoostNewsVol && u.ctx.newsVol && u.ict.dispBuy) sc += 4;
   if(UltraSoftPreferFib && !u.fib.atBuyZone && !u.ict.inDiscount) sc -= 3;
   if(u.trend.mtfVotesBuy >= 3) sc += 5;
   if(sc < 0) sc = 0; if(sc > 100) sc = 100;
   return sc;
}

int UltraConfluenceSell(const UltraSnap &u)
{
   int sc = 0;
   if(u.trend.htfBear) sc += 10; if(u.trend.macroBear) sc += 6; if(u.trend.bear) sc += 8;
   if(u.bos.sell) sc += 10; if(u.choch.sell) sc += 8;
   if(u.liq.sweepSell) sc += 14; if(u.liq.stopHuntSell) sc += 5;
   if(u.ict.dispSell) sc += 10; if(u.ict.fvgSell) sc += 6; if(u.ict.obSell) sc += 6;
   if(u.ict.breakerSell) sc += 4; if(u.ict.instZoneSell) sc += 6;
   if(u.fib.atSellZone) sc += 8; if(u.ict.inPremium) sc += 5;
   if(u.mom.momSell) sc += 4; if(u.ind.smi < -20) sc += 4; if(u.ind.ifi < -15) sc += 4;
   if(u.ind.meo >= 55) sc += 3;
   if(UltraBoostKillZone && u.ctx.killZone) sc += 3;
   if(UltraBoostNewsVol && u.ctx.newsVol && u.ict.dispSell) sc += 4;
   if(UltraSoftPreferFib && !u.fib.atSellZone && !u.ict.inPremium) sc -= 3;
   if(u.trend.mtfVotesSell >= 3) sc += 5;
   if(sc < 0) sc = 0; if(sc > 100) sc = 100;
   return sc;
}

void UltraEngScores(UltraSnap &u, const bool buySide)
{
   int conf = buySide ? UltraConfluenceBuy(u) : UltraConfluenceSell(u);
   u.score.confluence = conf;
   u.score.confidence = conf;
   // Precision: structure quality + bos reliability + fib quality + false-signal reduction
   int prec = (u.st.quality + u.bos.reliability + u.fib.quality + u.liq.rejectionScore) / 4;
   if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) prec -= 8;
   if(u.ict.smConfluence) prec += 8;
   if(prec < 0) prec = 0; if(prec > 100) prec = 100;
   u.score.precision = prec;
   // Probability
   int succ = (conf + prec + (int)MathRound(MathAbs(u.ind.smi))) / 3;
   if(succ > 100) succ = 100;
   u.score.successProb = succ;
   u.score.riskProb = 100 - succ;
   u.score.probability = succ;
}

//--------------------------------------------------------------------//
// DIAGNOSTICS / MEMORY / CAPITAL / EXEC READINESS
//--------------------------------------------------------------------//

void UltraResolveSides(UltraSignal &r, const int sb, const int ss)
{
   if(r.buy && r.sell)
   {
      if(sb >= ss) r.sell = false; else r.buy = false;
      r.score = MathMax(sb, ss);
   }
}

UltraSignal UltraStrat_FlashSweep(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "FlashSweep"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = u.liq.sweepBuy && u.ict.dispBuy && (u.trend.htfBull || u.trend.bull || u.trend.macroBull);
   bool s = u.liq.sweepSell && u.ict.dispSell && (u.trend.htfBear || u.trend.bear || u.trend.macroBear);
   if(b && sb >= UltraMinConfluence){ r.buy = true; r.score = sb; r.reason = "ULSE sweep+disp+bias"; }
   if(s && ss >= UltraMinConfluence){ r.sell = true; r.score = ss; r.reason = "ULSE sweep+disp+bias"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_ContSniper(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "ContSniper"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = (u.trend.htfBull || u.trend.bull) && (u.bos.buy || u.ict.obBuy || u.ict.fvgBuy) && (u.ict.dispBuy || u.mom.momBuy);
   bool s = (u.trend.htfBear || u.trend.bear) && (u.bos.sell || u.ict.obSell || u.ict.fvgSell) && (u.ict.dispSell || u.mom.momSell);
   if(b && sb >= UltraMinConfluence){ r.buy = true; r.score = sb; r.reason = "UBOSE cont+zone+impulse"; }
   if(s && ss >= UltraMinConfluence){ r.sell = true; r.score = ss; r.reason = "UBOSE cont+zone+impulse"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_RevSniper(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "RevSniper"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = u.liq.sweepBuy && (u.choch.buy || u.ict.dispBuy) && (u.ict.obBuy || u.ict.fvgBuy || u.liq.stopHuntBuy) && u.ict.inDiscount;
   bool s = u.liq.sweepSell && (u.choch.sell || u.ict.dispSell) && (u.ict.obSell || u.ict.fvgSell || u.liq.stopHuntSell) && u.ict.inPremium;
   if(b && sb >= UltraMinConfluence){ r.buy = true; r.score = sb + 2; r.reason = "UCHOCHE rev stack"; }
   if(s && ss >= UltraMinConfluence){ r.sell = true; r.score = ss + 2; r.reason = "UCHOCHE rev stack"; }
   UltraResolveSides(r, sb, ss);
   if(r.score > 100) r.score = 100;
   return r;
}

UltraSignal UltraStrat_FibSniper(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "FibSniper"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = u.fib.atBuyZone && (u.trend.htfBull || u.trend.bull) && (u.ict.dispBuy || u.mom.momBuy || u.ict.obBuy) && (u.ict.inDiscount || u.liq.sweepBuy);
   bool s = u.fib.atSellZone && (u.trend.htfBear || u.trend.bear) && (u.ict.dispSell || u.mom.momSell || u.ict.obSell) && (u.ict.inPremium || u.liq.sweepSell);
   if(b && sb >= UltraMinConfluence){ r.buy = true; r.score = sb; r.reason = "UFIE fib zone"; }
   if(s && ss >= UltraMinConfluence){ r.sell = true; r.score = ss; r.reason = "UFIE fib zone"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_BreakImpulse(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "BreakImpulse"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = u.bos.buy && u.ict.dispBuy && (u.vol.expansion || u.mom.momBuy) && (u.trend.htfBull || u.trend.macroBull || u.trend.bull);
   bool s = u.bos.sell && u.ict.dispSell && (u.vol.expansion || u.mom.momSell) && (u.trend.htfBear || u.trend.macroBear || u.trend.bear);
   if(b && sb >= UltraMinConfluence){ r.buy = true; r.score = sb; r.reason = "BOS+impulse+vol"; }
   if(s && ss >= UltraMinConfluence){ r.sell = true; r.score = ss; r.reason = "BOS+impulse+vol"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_InstZone(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "InstZone"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = u.ict.instZoneBuy && u.ict.smConfluence && (u.fib.atBuyZone || u.liq.sweepBuy);
   bool s = u.ict.instZoneSell && u.ict.smConfluence && (u.fib.atSellZone || u.liq.sweepSell);
   if(b && sb >= UltraMinConfluence){ r.buy = true; r.score = sb; r.reason = "institutional zone"; }
   if(s && ss >= UltraMinConfluence){ r.sell = true; r.score = ss; r.reason = "institutional zone"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

bool Ultra_IsLiveTag(const string tag)
{
   return (tag == "FlashSweep" || tag == "ContSniper" || tag == "RevSniper" ||
           tag == "FibSniper" || tag == "BreakImpulse" || tag == "InstZone");
}

// Compatibility alias used by Ultra/PRISM bypass hooks from OK91
bool PRIME_IsLiveTag(const string tag)
{
   return Ultra_IsLiveTag(tag);
}

int UltraSymDir(const string s)
{
   bool b = false, sel = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      long ty = PositionGetInteger(POSITION_TYPE);
      if(ty == POSITION_TYPE_BUY) b = true;
      if(ty == POSITION_TYPE_SELL) sel = true;
   }
   if(b && sel) return 2;
   if(b) return 1;
   if(sel) return -1;
   return 0;
}

UltraSignal UltraPickBest(const UltraSnap &u)
{
   UltraSignal best; best.buy = best.sell = false; best.score = -1; best.tag = "NONE"; best.reason = "no setup";
   UltraSignal arr[6];
   int n = 0;
   if(UltraEnable_FlashSweep)   arr[n++] = UltraStrat_FlashSweep(u);
   if(UltraEnable_ContSniper)   arr[n++] = UltraStrat_ContSniper(u);
   if(UltraEnable_RevSniper)    arr[n++] = UltraStrat_RevSniper(u);
   if(UltraEnable_FibSniper)    arr[n++] = UltraStrat_FibSniper(u);
   if(UltraEnable_BreakImpulse) arr[n++] = UltraStrat_BreakImpulse(u);
   if(UltraEnable_InstZone)     arr[n++] = UltraStrat_InstZone(u);
   for(int i = 0; i < n; i++)
   {
      if(!(arr[i].buy || arr[i].sell)) continue;
      if(arr[i].score > best.score) best = arr[i];
   }
   if(best.score >= 0 && best.score < UltraMinConfluence && best.score < UltraInstantFireConf)
   {
      best.buy = best.sell = false; best.tag = "NONE"; best.reason = "below confluence";
   }
   return best;
}

//--------------------------------------------------------------------//
// FULL PIPELINE (architecture decision flow 1..27 condensed)
//--------------------------------------------------------------------//

void UltraClearSnap(UltraSnap &u)
{
   // Manual clear — avoid ZeroMemory on structs with string fields (MQL5-safe)
   UltraStructure st; UltraBOS bos; UltraCHoCH choch; UltraLiquidity liq;
   UltraFib fib; UltraInst ict; UltraTrend trend; UltraMomentum mom; UltraVolatility vol;
   UltraIndicators ind; UltraScores score;
   ZeroMemory(st); ZeroMemory(bos); ZeroMemory(choch); ZeroMemory(liq);
   ZeroMemory(fib); ZeroMemory(ict); ZeroMemory(trend); ZeroMemory(mom); ZeroMemory(vol);
   ZeroMemory(ind); ZeroMemory(score);
   u.st = st; u.bos = bos; u.choch = choch; u.liq = liq;
   u.fib = fib; u.ict = ict; u.trend = trend; u.mom = mom; u.vol = vol;
   u.ind = ind; u.score = score;
   u.regime = UREG_RANGE;
   u.buyBias = false; u.sellBias = false;
   u.ctx.session = "OFF";
   u.ctx.asia = u.ctx.london = u.ctx.newyork = u.ctx.overlap = false;
   u.ctx.killZone = false;
   u.ctx.sessionConfidence = 0; u.ctx.sessionQuality = 0;
   u.ctx.newsVol = false;
   u.ctx.highImpactProxy = u.ctx.midImpactProxy = u.ctx.lowImpactProxy = false;
   u.ctx.spreadPts = 0; u.ctx.slipProxy = 0;
   u.diag.tickOK = u.diag.brokerOK = u.diag.connectionOK = false;
   u.diag.indicatorOK = u.diag.memoryOK = false;
   u.diag.processSpeedMs = 0;
   u.diag.health = "INIT";
}

bool UltraBuildSnapshot(const string s, UltraSnap &u)
{
   long t0 = (long)GetTickCount();
   UltraClearSnap(u);
   if(!UltraCoreEnabled){ UltraSetError("core disabled"); return false; }
   if(!UltraConfigOK()){ UltraSetError("config invalid"); return false; }
   if(UltraDataEngineEnabled && !UltraValidateSymbol(s)){ UltraSetError("data/symbol invalid"); return false; }

   UltraEngVolatility(s, u);          // needed early for ATR
   UltraEngStructure(s, u);
   UltraEngBOS(s, u);
   UltraEngCHoCH(s, u);
   UltraEngLiquidity(s, u);
   UltraEngInstitutional(s, u);
   UltraEngFib(s, u);
   UltraEngTrend(s, u);
   UltraEngMomentum(s, u);
   UltraEngRegime(u);
   UltraEngSessionNews(s, u);
   UltraEngIndicators(s, u);
   UltraEngDiagnostics(s, u);
   UltraMemoryUpdateFromStats();

   g_UltraCore.lastLatencyMs = (long)GetTickCount() - t0;
   g_UltraCore.lastCycleMs = (long)GetTickCount();
   g_UltraCore.dataOK = true;
   g_UltraCore.validated = true;
   return true;
}

bool UltraAIDecide(const string s, UltraSnap &u, UltraSignal &sig, string &why)
{
   why = "";
   sig.buy = sig.sell = false; sig.tag = "NONE"; sig.reason = ""; sig.score = 0;

   string capWhy = "";
   if(!UltraCapitalOK(capWhy)){ why = "capital: " + capWhy; return false; }
   string exWhy = "";
   if(!UltraExecReady(s, exWhy)){ why = "exec: " + exWhy; return false; }

   sig = UltraPickBest(u);
   if(!(sig.buy || sig.sell) || sig.tag == "NONE")
   {
      why = "no strategy: " + sig.reason;
      return false;
   }

   UltraEngScores(u, sig.buy);
   if(u.score.confidence < UltraMinConfluence && u.score.confidence < UltraInstantFireConf)
   { why = "confidence low"; return false; }
   if(u.score.precision < UltraMinPrecision && u.score.confidence < UltraInstantFireConf)
   { why = "precision low"; return false; }
   if(u.score.probability < UltraMinProbability && u.score.confidence < UltraInstantFireConf)
   { why = "probability low"; return false; }

   if(UltraBlockOppositeSameSym)
   {
      int d = UltraSymDir(s);
      if(sig.buy && d < 0){ why = "opposite SELL open"; return false; }
      if(sig.sell && d > 0){ why = "opposite BUY open"; return false; }
   }

   // Session/news NEVER reject here — context only (boosts already in confluence)
   return true;
}


void EvaluateStrategySignals(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   buySignal = false;
   sellSignal = false;
   strategyTag = "";

   // OK93 LIVE: SNIPER AI ULTRA complete architecture decision flow
   UltraSnap snap;
   if(!UltraBuildSnapshot(BrokerSymbol, snap))
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
      g_UltraLastSignal = best;
      if(EnableVerboseLogging || ContStruct_LogDetail)
         Print("ULTRA wait [", why, "] conf=", snap.score.confidence,
               " prec=", snap.score.precision, " prob=", snap.score.probability,
               " regime=", UltraRegimeName(snap.regime),
               " fibB/S=", snap.fib.atBuyZone, "/", snap.fib.atSellZone,
               " on ", BrokerSymbol);
      return;
   }

   buySignal = best.buy;
   sellSignal = best.sell;
   strategyTag = best.tag;
   g_UltraLastSnap = snap;
   g_UltraLastSignal = best;
   Print("ULTRA FIRE ", (best.buy ? "BUY" : "SELL"), " [", best.tag, "] conf=", snap.score.confidence,
         " prec=", snap.score.precision, " prob=", snap.score.probability,
         " ", best.reason, " SMI=", DoubleToString(snap.ind.smi, 1),
         " session=", snap.ctx.session, " on ", BrokerSymbol);
}
#endif
