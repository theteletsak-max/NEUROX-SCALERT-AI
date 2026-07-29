#ifndef SNIPER_ULTRA_16_AI_CORE_MQH
#define SNIPER_ULTRA_16_AI_CORE_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 16_AI_CORE — Decision · Approval/Rejection · Controller · Strategies
//+------------------------------------------------------------------+

datetime g_UltraLastWaitBar = 0;
string   g_UltraLastWaitSym = "";

int UltraFireFloor()
{
   // InstantQualityMode: softer live floor so charts actually trade
   if(InstantQualityMode)
      return MathMin(UltraMinConfluence, 45);
   return UltraMinConfluence;
}

void UltraEngScores(UltraSnap &u, const bool buySide)
{
   int conf = buySide ? UltraConfluenceBuy(u) : UltraConfluenceSell(u);
   u.score.confluence = conf;
   u.score.confidence = conf;
   u.score.precision = UltraPrecisionScore(u);
   u.score.successProb = UltraProbabilityScore(u, conf, u.score.precision);
   u.score.riskProb = UltraRiskProbability(u.score.successProb);
   u.score.probability = u.score.successProb;
}

void UltraEngScoresBest(UltraSnap &u)
{
   int sb = UltraConfluenceBuy(u);
   int ss = UltraConfluenceSell(u);
   UltraEngScores(u, (sb >= ss));
}

void UltraResolveSides(UltraSignal &r, const int sb, const int ss)
{
   if(r.buy && r.sell)
   {
      if(sb >= ss) r.sell = false; else r.buy = false;
      r.score = MathMax(sb, ss);
   }
}

bool UltraPassScore(const int sc)
{
   int floor = UltraFireFloor();
   if(sc >= floor) return true;
   if(sc >= UltraInstantFireConf) return true;
   // Soft pass: close to floor in InstantQualityMode
   if(InstantQualityMode && sc >= floor - 8) return true;
   return false;
}

UltraSignal UltraStrat_FlashSweep(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "FlashSweep"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool biasB = (u.trend.htfBull || u.trend.bull || u.trend.macroBull || u.trend.mtfVotesBuy >= u.trend.mtfVotesSell);
   bool biasS = (u.trend.htfBear || u.trend.bear || u.trend.macroBear || u.trend.mtfVotesSell > u.trend.mtfVotesBuy);
   bool b = (u.liq.sweepBuy || u.liq.stopHuntBuy) && (u.ict.dispBuy || u.mom.momBuy || u.bos.buy) && biasB;
   bool s = (u.liq.sweepSell || u.liq.stopHuntSell) && (u.ict.dispSell || u.mom.momSell || u.bos.sell) && biasS;
   if(b && UltraPassScore(sb)){ r.buy = true; r.score = sb; r.reason = "ULSE sweep+impulse+bias"; }
   if(s && UltraPassScore(ss)){ r.sell = true; r.score = ss; r.reason = "ULSE sweep+impulse+bias"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_ContSniper(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "ContSniper"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool biasB = (u.trend.htfBull || u.trend.bull || u.trend.macroBull || u.st.externalBull || u.st.internalBull);
   bool biasS = (u.trend.htfBear || u.trend.bear || u.trend.macroBear || u.st.externalBear || u.st.internalBear);
   bool zoneB = (u.bos.buy || u.ict.obBuy || u.ict.fvgBuy || u.fib.atBuyZone || u.ict.instZoneBuy);
   bool zoneS = (u.bos.sell || u.ict.obSell || u.ict.fvgSell || u.fib.atSellZone || u.ict.instZoneSell);
   bool impB  = (u.ict.dispBuy || u.mom.momBuy || u.liq.sweepBuy || u.vol.expansion);
   bool impS  = (u.ict.dispSell || u.mom.momSell || u.liq.sweepSell || u.vol.expansion);
   bool b = biasB && zoneB && impB;
   bool s = biasS && zoneS && impS;
   // Instant: 2-of-3 stack is enough
   if(InstantQualityMode)
   {
      int eb = (biasB ? 1 : 0) + (zoneB ? 1 : 0) + (impB ? 1 : 0);
      int es = (biasS ? 1 : 0) + (zoneS ? 1 : 0) + (impS ? 1 : 0);
      b = (eb >= 2); s = (es >= 2);
   }
   if(b && UltraPassScore(sb)){ r.buy = true; r.score = sb; r.reason = "UBOSE cont+zone+impulse"; }
   if(s && UltraPassScore(ss)){ r.sell = true; r.score = ss; r.reason = "UBOSE cont+zone+impulse"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_RevSniper(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "RevSniper"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = (u.liq.sweepBuy || u.liq.stopHuntBuy) &&
            (u.choch.buy || u.ict.dispBuy || u.bos.buy) &&
            (u.ict.obBuy || u.ict.fvgBuy || u.ict.inDiscount || u.fib.atBuyZone);
   bool s = (u.liq.sweepSell || u.liq.stopHuntSell) &&
            (u.choch.sell || u.ict.dispSell || u.bos.sell) &&
            (u.ict.obSell || u.ict.fvgSell || u.ict.inPremium || u.fib.atSellZone);
   if(b && UltraPassScore(sb)){ r.buy = true; r.score = sb + 2; r.reason = "UCHOCHE rev stack"; }
   if(s && UltraPassScore(ss)){ r.sell = true; r.score = ss + 2; r.reason = "UCHOCHE rev stack"; }
   UltraResolveSides(r, sb, ss);
   if(r.score > 100) r.score = 100;
   return r;
}

UltraSignal UltraStrat_FibSniper(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "FibSniper"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool biasB = (u.trend.htfBull || u.trend.bull || u.trend.macroBull || u.mom.momBuy);
   bool biasS = (u.trend.htfBear || u.trend.bear || u.trend.macroBear || u.mom.momSell);
   bool b = u.fib.atBuyZone && biasB && (u.ict.dispBuy || u.mom.momBuy || u.ict.obBuy || u.liq.sweepBuy || u.bos.buy);
   bool s = u.fib.atSellZone && biasS && (u.ict.dispSell || u.mom.momSell || u.ict.obSell || u.liq.sweepSell || u.bos.sell);
   if(b && UltraPassScore(sb)){ r.buy = true; r.score = sb; r.reason = "UFIE fib zone"; }
   if(s && UltraPassScore(ss)){ r.sell = true; r.score = ss; r.reason = "UFIE fib zone"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_BreakImpulse(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "BreakImpulse"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = u.bos.buy && (u.ict.dispBuy || u.mom.momBuy || u.vol.expansion) &&
            (u.trend.htfBull || u.trend.macroBull || u.trend.bull || u.st.externalBull);
   bool s = u.bos.sell && (u.ict.dispSell || u.mom.momSell || u.vol.expansion) &&
            (u.trend.htfBear || u.trend.macroBear || u.trend.bear || u.st.externalBear);
   if(b && UltraPassScore(sb)){ r.buy = true; r.score = sb; r.reason = "BOS+impulse+vol"; }
   if(s && UltraPassScore(ss)){ r.sell = true; r.score = ss; r.reason = "BOS+impulse+vol"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

UltraSignal UltraStrat_InstZone(const UltraSnap &u)
{
   UltraSignal r; r.buy = r.sell = false; r.score = 0; r.tag = "InstZone"; r.reason = "";
   int sb = UltraConfluenceBuy(u), ss = UltraConfluenceSell(u);
   bool b = (u.ict.instZoneBuy || ((u.ict.obBuy || u.ict.fvgBuy) && u.ict.inDiscount)) &&
            (u.ict.smConfluence || u.fib.atBuyZone || u.liq.sweepBuy || u.bos.buy);
   bool s = (u.ict.instZoneSell || ((u.ict.obSell || u.ict.fvgSell) && u.ict.inPremium)) &&
            (u.ict.smConfluence || u.fib.atSellZone || u.liq.sweepSell || u.bos.sell);
   if(b && UltraPassScore(sb)){ r.buy = true; r.score = sb; r.reason = "institutional zone"; }
   if(s && UltraPassScore(ss)){ r.sell = true; r.score = ss; r.reason = "institutional zone"; }
   UltraResolveSides(r, sb, ss);
   return r;
}

bool Ultra_IsLiveTag(const string tag)
{
   return (tag == "FlashSweep" || tag == "ContSniper" || tag == "RevSniper" ||
           tag == "FibSniper" || tag == "BreakImpulse" || tag == "InstZone");
}

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
   UltraSignal best; best.buy = best.sell = false; best.score = -1; best.tag = "NONE";
   best.reason = "no setup"; best.explanation = "";
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
   if(best.score >= 0 && !UltraPassScore(best.score))
   {
      best.buy = best.sell = false; best.tag = "NONE";
      best.reason = StringFormat("below confluence (%d<%d)", best.score, UltraFireFloor());
   }
   return best;
}

// Master Blueprint explainable decision (BUY/SELL/WAIT + checklist)
string UltraBuildExplanation(const UltraSnap &u, const bool buySide, const bool approved, const string tag)
{
   bool structure = buySide
      ? (u.st.hh || u.st.hl || u.st.externalBull || u.st.internalBull || u.st.continuation)
      : (u.st.lh || u.st.ll || u.st.externalBear || u.st.internalBear || u.st.continuation);
   bool bosCh = buySide ? (u.bos.buy || u.choch.buy) : (u.bos.sell || u.choch.sell);
   bool liq   = buySide ? (u.liq.sweepBuy || u.liq.stopHuntBuy || u.liq.equalLows)
                        : (u.liq.sweepSell || u.liq.stopHuntSell || u.liq.equalHighs);
   bool trend = buySide ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull)
                        : (u.trend.bear || u.trend.htfBear || u.trend.macroBear);
   bool mom   = buySide ? (u.mom.momBuy || u.mom.impulse || u.ict.dispBuy)
                        : (u.mom.momSell || u.mom.impulse || u.ict.dispSell);
   bool fib   = buySide ? u.fib.atBuyZone : u.fib.atSellZone;
   int passed = (structure?1:0)+(bosCh?1:0)+(liq?1:0)+(trend?1:0)+(mom?1:0)+(fib?1:0);

   string t = (approved ? tag : "NO TRADE") + "\n";
   t += (structure ? "[OK] " : "[X]  ") + "Structure\n";
   t += (bosCh     ? "[OK] " : "[X]  ") + "BOS/CHoCH\n";
   t += (liq       ? "[OK] " : "[X]  ") + "Liquidity\n";
   t += (fib       ? "[OK] " : "[-]  ") + "Fibonacci\n";
   t += (trend     ? "[OK] " : "[X]  ") + "Trend\n";
   t += (mom       ? "[OK] " : "[X]  ") + "Momentum\n";
   t += "Confidence = " + IntegerToString(u.score.confidence) + "%\n";
   t += "Precision  = " + IntegerToString(u.score.precision) + "%\n";
   t += "Probability= " + IntegerToString(u.score.probability) + "%\n";
   if(approved)
      t += "Decision = " + (buySide ? "BUY" : "SELL");
   else
      t += "Decision = WAIT | Reason = Insufficient Confluence (" + IntegerToString(passed) + "/6)";
   return t;
}

void UltraClearSnap(UltraSnap &u)
{
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
   u.ctx.sessionLiquidity = false;
   u.ctx.sessionConfidence = 0; u.ctx.sessionQuality = 0;
   u.ctx.newsVol = false;
   u.ctx.highImpactProxy = u.ctx.midImpactProxy = u.ctx.lowImpactProxy = false;
   u.ctx.beforeNews = u.ctx.duringNews = u.ctx.afterNews = false;
   u.ctx.newsPhase = "NONE";
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

   UltraEngVolatility(s, u);
   UltraEngStructure(s, u);
   UltraEngBOS(s, u);
   UltraEngCHoCH(s, u);
   UltraEngLiquidity(s, u);
   UltraEngFib(s, u);              // before institutional (zone uses fib)
   UltraEngInstitutional(s, u);
   UltraEngTrend(s, u);
   UltraEngMomentum(s, u);
   UltraEngRegime(u);
   UltraEngSessionNews(s, u);
   UltraEngIndicators(s, u);
   UltraEngDiagnostics(s, u);
   UltraMemoryUpdateFromStats();
   UltraEngScoresBest(u);          // always fill conf/prec/prob for dashboard + wait logs

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
   int floor = UltraFireFloor();
   if(u.score.confidence < floor && u.score.confidence < UltraInstantFireConf &&
      !(InstantQualityMode && u.score.confidence >= floor - 8))
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
   return true;
}

void EvaluateStrategySignals(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   buySignal = false;
   sellSignal = false;
   strategyTag = "";

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
      bool leanBuy = (UltraConfluenceBuy(snap) >= UltraConfluenceSell(snap));
      best.explanation = UltraBuildExplanation(snap, leanBuy, false, "NO TRADE");
      g_UltraLastSignal = best;
      datetime bar = iTime(BrokerSymbol, UltraETF(), 0);
      bool logIt = (EnableVerboseLogging || ContStruct_LogDetail) &&
                   (bar != g_UltraLastWaitBar || BrokerSymbol != g_UltraLastWaitSym);
      if(logIt)
      {
         g_UltraLastWaitBar = bar;
         g_UltraLastWaitSym = BrokerSymbol;
         Print("ULTRA wait [", why, "] conf=", snap.score.confidence,
               " prec=", snap.score.precision, " prob=", snap.score.probability,
               " regime=", UltraRegimeName(snap.regime),
               " bos=", (snap.bos.buy ? "B" : (snap.bos.sell ? "S" : "-")),
               " sweep=", (snap.liq.sweepBuy ? "B" : (snap.liq.sweepSell ? "S" : "-")),
               " fibB/S=", snap.fib.atBuyZone, "/", snap.fib.atSellZone,
               " on ", BrokerSymbol);
      }
      return;
   }

   buySignal = best.buy;
   sellSignal = best.sell;
   strategyTag = best.tag;
   best.explanation = UltraBuildExplanation(snap, best.buy, true, best.tag);
   g_UltraLastSnap = snap;
   g_UltraLastSignal = best;
   Print("ULTRA FIRE ", (best.buy ? "BUY" : "SELL"), " [", best.tag, "] conf=", snap.score.confidence,
         " prec=", snap.score.precision, " prob=", snap.score.probability,
         " ", best.reason, " SMI=", DoubleToString(snap.ind.smi, 1),
         " session=", snap.ctx.session, " on ", BrokerSymbol);
}

#endif // SNIPER_ULTRA_16_AI_CORE_MQH
