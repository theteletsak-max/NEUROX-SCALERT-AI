//====================================================================//
// SNIPER AI ULTRA — COMPLETE FEATURE ARCHITECTURE (OK92 LIVE PATH)
// Price-action primary. Session/News = context only (NEVER hard-block).
//====================================================================//

input group "ULTRA CORE SYSTEM"
input bool   UltraCoreEnabled            = true;
input bool   UltraDataEngineEnabled      = true;
input bool   UltraConfigEngineEnabled    = true;
input bool   UltraValidationEnabled      = true;
input bool   UltraRecoveryEnabled        = true;
input bool   UltraErrorHandlingEnabled   = true;
input bool   UltraMemoryEngineEnabled    = true;
input bool   UltraLoggingEnabled         = true;
input bool   UltraStateSyncEnabled       = true;
input bool   UltraPerfEngineEnabled      = true;

input group "ULTRA MARKET ANALYSIS"
input int    UltraSwingStrength          = 2;
input int    UltraStructLookback         = 48;
input int    UltraBOS_ConfirmBars        = 14;
input int    UltraSweepLookback          = 24;
input double UltraEqualTolATR            = 0.12;
input double UltraSweepWickMin           = 0.28;
input double UltraSweepDepthATR          = 0.06;
input double UltraDispBodyMin            = 0.48;
input double UltraDispATRMin             = 0.35;
input double UltraFVG_MinATR             = 0.12;
input double UltraVolExpandMult          = 1.20;
input int    UltraMomentumBars           = 3;

input group "ULTRA FIBONACCI INTELLIGENCE (UFIE)"
input double UltraFibBuyLow              = 0.50;
input double UltraFibBuyHigh             = 0.886;
input double UltraFibSellLow             = 0.114;
input double UltraFibSellHigh            = 0.50;
input bool   UltraSoftPreferFib          = true;
input double UltraFibExt127              = 1.272;
input double UltraFibExt161              = 1.618;

input group "ULTRA STRATEGIES / AI DECISION"
input bool   UltraEnable_FlashSweep      = true;
input bool   UltraEnable_ContSniper      = true;
input bool   UltraEnable_RevSniper       = true;
input bool   UltraEnable_FibSniper       = true;
input bool   UltraEnable_BreakImpulse    = true;
input bool   UltraEnable_InstZone        = true;
input int    UltraMinConfluence          = 62;   // Final AI confidence floor
input int    UltraInstantFireConf        = 78;
input int    UltraMinPrecision           = 55;
input int    UltraMinProbability         = 55;
input bool   UltraBlockOppositeSameSym   = true;

input group "ULTRA MTF ENGINE"
input ENUM_TIMEFRAMES UltraTF_Bias       = PERIOD_H4;
input ENUM_TIMEFRAMES UltraTF_Macro      = PERIOD_D1;
input ENUM_TIMEFRAMES UltraTF_Week       = PERIOD_W1;
input ENUM_TIMEFRAMES UltraTF_Month      = PERIOD_MN1;
input bool   UltraUseMTFVoting           = true;
input bool   UltraUseM30                 = true;
input bool   UltraUseM15                 = true;
input bool   UltraUseM5                  = true;
input bool   UltraUseM1Optional          = false;

input group "ULTRA SESSION / NEWS (context — NEVER blocks)"
input bool   UltraSessionIntelEnabled    = true;
input bool   UltraNewsIntelEnabled       = true;
input bool   UltraBoostKillZone          = true;
input bool   UltraBoostNewsVol           = true;
input bool   UltraTrade24x5              = true; // always allow

input group "ULTRA CAPITAL / EXEC"
input bool   UltraCapitalProtectEnabled  = true;
input bool   UltraExecQualityEnabled     = true;
input bool   UltraDiagnosticsEnabled     = true;
input bool   UltraMarketMemoryEnabled    = true;
input bool   UltraDashboardEnabled       = true;

//--------------------------------------------------------------------//
// ULTRA TYPES
//--------------------------------------------------------------------//
enum ENUM_ULTRA_REGIME
{
   UREG_STRONG_TREND = 0,
   UREG_WEAK_TREND,
   UREG_HEALTHY_TREND,
   UREG_RANGE,
   UREG_COMPRESSION,
   UREG_EXPANSION,
   UREG_REVERSAL,
   UREG_ACCUMULATION,
   UREG_DISTRIBUTION,
   UREG_EXHAUSTION
};

struct UltraCoreState
{
   bool   loaded;
   bool   configOK;
   bool   dataOK;
   bool   validated;
   bool   healthy;
   long   lastCycleMs;
   long   lastLatencyMs;
   int    errorCount;
   int    recoveryCount;
   string lastError;
};

struct UltraStructure
{
   bool hh, hl, lh, ll;
   bool swingHighOK, swingLowOK;
   bool internalBull, internalBear;
   bool externalBull, externalBear;
   bool continuation, reversal;
   int  strength;   // 0-100
   int  quality;    // 0-100
   double swingHigh, swingLow;
};

struct UltraBOS
{
   bool buy, sell;
   int  strength, quality, confirmation, reliability, score;
};

struct UltraCHoCH
{
   bool buy, sell;
   bool internalC, externalC;
   bool majorC, minorC;
   int  strength, confidence;
};

struct UltraLiquidity
{
   bool buySideLiq, sellSideLiq;
   bool poolBuy, poolSell;
   bool grabBuy, grabSell;
   bool stopHuntBuy, stopHuntSell;
   bool sweepBuy, sweepSell;
   bool confirmedBuy, confirmedSell;
   double poolLow, poolHigh;
   double sweepExtBuy, sweepExtSell;
   double depthATR, speed, strength, quality;
   int rejectionScore;
};

struct UltraFib
{
   double f0, f100, f382, f500, f618, f786;
   double ext127, ext161;
   bool atBuyZone, atSellZone;
   bool impulseOK;
   int zoneRank, confluence, quality, confidence;
   double retracePos;
};

struct UltraInst
{
   bool obBuy, obSell;
   bool breakerBuy, breakerSell;
   bool mitigationBuy, mitigationSell;
   bool fvgBuy, fvgSell;
   bool instZoneBuy, instZoneSell;
   bool rejectZoneBuy, rejectZoneSell;
   bool smConfluence;
   bool dispBuy, dispSell;
   bool inDiscount, inPremium;
};

struct UltraTrend
{
   bool bull, bear;
   int  strength, quality, persistence;
   bool htfBull, htfBear, macroBull, macroBear;
   bool weekBull, weekBear, monthBull, monthBear;
   int  mtfVotesBuy, mtfVotesSell;
};

struct UltraMomentum
{
   int  direction; // +1/-1/0
   int  strength, acceleration, quality, confirmation;
   bool momBuy, momSell;
};

struct UltraVolatility
{
   double atr;
   bool expansion, compression;
   double relative;
   int  classification; // -1 compress, 0 normal, 1 expand
};

struct UltraSessionNews
{
   string session;
   bool   asia, london, newyork, overlap;
   bool   killZone;
   int    sessionConfidence, sessionQuality;
   bool   newsVol;
   bool   highImpactProxy, midImpactProxy, lowImpactProxy;
   double spreadPts, slipProxy;
   // NEVER blocks
};

struct UltraIndicators
{
   double smi;   // Sniper Momentum Index -100..100
   double meo;   // Market Energy Oscillator 0..100
   double ifi;   // Institutional Footprint Index -100..100
};

struct UltraScores
{
   int confidence;   // Final AI Confidence
   int precision;
   int probability;
   int successProb;
   int riskProb;
   int confluence;
};

struct UltraMemory
{
   int   trades;
   int   wins;
   double profitSum;
   double lossSum;
   double avgRR;
   double winRate;
   double profitFactor;
   double expectancy;
   long   lastSave;
};

struct UltraDiag
{
   bool tickOK, brokerOK, connectionOK, indicatorOK, memoryOK;
   long processSpeedMs;
   string health;
};

struct UltraSnap
{
   UltraStructure   st;
   UltraBOS         bos;
   UltraCHoCH       choch;
   UltraLiquidity   liq;
   UltraFib         fib;
   UltraInst        ict;
   UltraTrend       trend;
   UltraMomentum    mom;
   UltraVolatility  vol;
   ENUM_ULTRA_REGIME regime;
   UltraSessionNews ctx;
   UltraIndicators  ind;
   UltraScores      score;
   UltraDiag        diag;
   bool buyBias, sellBias;
};

struct UltraSignal
{
   bool buy, sell;
   int  score;
   string tag;
   string reason;
};

UltraCoreState g_UltraCore;
UltraMemory    g_UltraMem;
UltraSnap      g_UltraLastSnap;
UltraSignal    g_UltraLastSignal;
datetime       g_UltraLastFireBar = 0;

//--------------------------------------------------------------------//
// 1. ULTRA CORE / DATA / CONFIG / VALIDATION / RECOVERY / LOG / PERF
//--------------------------------------------------------------------//
ENUM_TIMEFRAMES UltraETF()
{
   return (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
}

void UltraLog(const string msg)
{
   if(UltraLoggingEnabled)
      Print("ULTRA| ", msg);
}

void UltraSetError(const string e)
{
   if(!UltraErrorHandlingEnabled) return;
   g_UltraCore.errorCount++;
   g_UltraCore.lastError = e;
   UltraLog("ERR " + e);
}

void UltraRecover(const string why)
{
   if(!UltraRecoveryEnabled) return;
   g_UltraCore.recoveryCount++;
   UltraLog("RECOVERY " + why);
   g_UltraCore.healthy = true;
}

bool UltraConfigOK()
{
   if(!UltraConfigEngineEnabled) return true;
   if(TradeComment != "SNIPER AI") return false;
   if(MaxOpenTrades < 1) return false;
   if(UltraMinConfluence < 1 || UltraMinConfluence > 100) return false;
   return true;
}

bool UltraValidateSymbol(const string s)
{
   if(!UltraValidationEnabled) return true;
   if(s == "" || !SymbolInfoInteger(s, SYMBOL_SELECT)) return false;
   if(Bars(s, UltraETF()) < 60) return false;
   return true;
}

double UltraATR(const string s, const int period=14)
{
   int p = MathMax(period, 5);
   ENUM_TIMEFRAMES tf = UltraETF();
   if(Bars(s, tf) < p + 5) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= p; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), pc = iClose(s, tf, i + 1);
      sum += MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
   }
   return sum / p;
}

double UltraSMA(const string s, const ENUM_TIMEFRAMES tf, const int period, const int shift=1)
{
   if(Bars(s, tf) < period + shift + 2) return 0.0;
   double a = 0.0;
   for(int i = shift; i < shift + period; i++) a += iClose(s, tf, i);
   return a / period;
}

bool UltraSwingHighAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double h = iHigh(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iHigh(s, tf, bar - i) >= h || iHigh(s, tf, bar + i) >= h) return false;
   return true;
}

bool UltraSwingLowAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double l = iLow(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iLow(s, tf, bar - i) <= l || iLow(s, tf, bar + i) <= l) return false;
   return true;
}

bool UltraFindSwings(const string s, const ENUM_TIMEFRAMES tf, const int lb, const int strength,
                     int &iH1, int &iH2, int &iL1, int &iL2)
{
   iH1 = iH2 = iL1 = iL2 = 0;
   int sw = MathMax(strength, 1), look = MathMax(lb, 20);
   for(int i = sw + 1; i <= look; i++)
   {
      if(iH1 == 0 && UltraSwingHighAt(s, tf, i, sw)) iH1 = i;
      else if(iH1 > 0 && iH2 == 0 && UltraSwingHighAt(s, tf, i, sw)) iH2 = i;
      if(iL1 == 0 && UltraSwingLowAt(s, tf, i, sw)) iL1 = i;
      else if(iL1 > 0 && iL2 == 0 && UltraSwingLowAt(s, tf, i, sw)) iL2 = i;
      if(iH1 && iH2 && iL1 && iL2) break;
   }
   return (iH1 && iH2 && iL1 && iL2);
}

void UltraCoreInit()
{
   g_UltraCore.loaded = false;
   g_UltraCore.configOK = false;
   g_UltraCore.dataOK = false;
   g_UltraCore.validated = false;
   g_UltraCore.healthy = false;
   g_UltraCore.lastCycleMs = 0;
   g_UltraCore.lastLatencyMs = 0;
   g_UltraCore.errorCount = 0;
   g_UltraCore.recoveryCount = 0;
   g_UltraCore.lastError = "";
   g_UltraMem.trades = 0;
   g_UltraMem.wins = 0;
   g_UltraMem.profitSum = 0;
   g_UltraMem.lossSum = 0;
   g_UltraMem.avgRR = 0;
   g_UltraMem.winRate = 0;
   g_UltraMem.profitFactor = 0;
   g_UltraMem.expectancy = 0;
   g_UltraMem.lastSave = 0;
   g_UltraCore.loaded = true;
   g_UltraCore.configOK = UltraConfigOK();
   g_UltraCore.healthy = g_UltraCore.configOK;
   UltraLog("CORE loaded configOK=" + (string)g_UltraCore.configOK);
}

//--------------------------------------------------------------------//
// 2. MARKET STRUCTURE / BOS / CHoCH / LIQUIDITY / FIB / ICT / TREND /
//    MOMENTUM / VOL / REGIME
//--------------------------------------------------------------------//
void UltraEngStructure(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   int iH1, iH2, iL1, iL2;
   if(UltraFindSwings(s, tf, UltraStructLookback, UltraSwingStrength, iH1, iH2, iL1, iL2))
   {
      double h1 = iHigh(s, tf, iH1), h2 = iHigh(s, tf, iH2);
      double l1 = iLow(s, tf, iL1), l2 = iLow(s, tf, iL2);
      u.st.hh = (h1 > h2); u.st.hl = (l1 > l2); u.st.lh = (h1 < h2); u.st.ll = (l1 < l2);
      u.st.swingHigh = h1; u.st.swingLow = l1;
      u.st.swingHighOK = true; u.st.swingLowOK = true;
      u.st.externalBull = (u.st.hh && u.st.hl);
      u.st.externalBear = (u.st.lh && u.st.ll);
   }
   else
   {
      u.st.swingHigh = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, UltraStructLookback, 1));
      u.st.swingLow  = iLow(s, tf, iLowest(s, tf, MODE_LOW, UltraStructLookback, 1));
   }
   // Internal structure (shorter lookback)
   int jH1, jH2, jL1, jL2;
   if(UltraFindSwings(s, tf, MathMax(UltraStructLookback / 2, 16), UltraSwingStrength, jH1, jH2, jL1, jL2))
   {
      bool ihh = iHigh(s, tf, jH1) > iHigh(s, tf, jH2);
      bool ihl = iLow(s, tf, jL1) > iLow(s, tf, jL2);
      bool ilh = iHigh(s, tf, jH1) < iHigh(s, tf, jH2);
      bool ill = iLow(s, tf, jL1) < iLow(s, tf, jL2);
      u.st.internalBull = (ihh && ihl);
      u.st.internalBear = (ilh && ill);
   }
   u.st.continuation = (u.st.externalBull && u.st.internalBull) || (u.st.externalBear && u.st.internalBear);
   u.st.reversal = (u.st.externalBull && u.st.internalBear) || (u.st.externalBear && u.st.internalBull);
   u.st.strength = 40;
   if(u.st.externalBull || u.st.externalBear) u.st.strength += 20;
   if(u.st.internalBull || u.st.internalBear) u.st.strength += 15;
   if(u.st.continuation) u.st.strength += 15;
   if(u.st.reversal) u.st.strength += 10;
   if(u.st.strength > 100) u.st.strength = 100;
   u.st.quality = u.st.strength;
   if(u.st.swingHigh <= u.st.swingLow) u.st.quality = MathMax(u.st.quality - 20, 0);
}

void UltraEngBOS(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double c1 = iClose(s, tf, 1);
   u.bos.buy = (u.st.swingHigh > 0 && c1 > u.st.swingHigh);
   u.bos.sell = (u.st.swingLow > 0 && c1 < u.st.swingLow);
   for(int i = 1; i <= UltraBOS_ConfirmBars; i++)
   {
      double c = iClose(s, tf, i);
      if(c > u.st.swingHigh) u.bos.buy = true;
      if(c < u.st.swingLow)  u.bos.sell = true;
   }
   u.bos.confirmation = 0;
   if(u.bos.buy || u.bos.sell)
   {
      double body = MathAbs(iClose(s, tf, 1) - iOpen(s, tf, 1));
      double rng = iHigh(s, tf, 1) - iLow(s, tf, 1);
      u.bos.confirmation = (rng > 0 && body / rng >= UltraDispBodyMin) ? 80 : 55;
   }
   u.bos.strength = u.bos.confirmation;
   if((u.bos.buy && u.st.externalBull) || (u.bos.sell && u.st.externalBear)) u.bos.strength += 15;
   if(u.bos.strength > 100) u.bos.strength = 100;
   u.bos.quality = u.bos.strength;
   u.bos.reliability = (u.bos.confirmation >= 70 && u.st.quality >= 50) ? 75 : 45;
   u.bos.score = (u.bos.strength + u.bos.quality + u.bos.reliability) / 3;
}

void UltraEngCHoCH(const string s, UltraSnap &u)
{
   u.choch.buy  = u.bos.buy  && (u.st.ll || u.st.externalBear || u.st.internalBear);
   u.choch.sell = u.bos.sell && (u.st.hh || u.st.externalBull || u.st.internalBull);
   u.choch.internalC = (u.choch.buy || u.choch.sell) && (u.st.internalBull || u.st.internalBear);
   u.choch.externalC = (u.choch.buy || u.choch.sell) && (u.st.externalBull || u.st.externalBear);
   u.choch.majorC = u.choch.externalC && u.bos.score >= 65;
   u.choch.minorC = (u.choch.buy || u.choch.sell) && !u.choch.majorC;
   u.choch.strength = 0;
   if(u.choch.buy || u.choch.sell) u.choch.strength = 50 + (u.choch.majorC ? 30 : 10) + (u.choch.internalC ? 10 : 0);
   if(u.choch.strength > 100) u.choch.strength = 100;
   u.choch.confidence = u.choch.strength;
}

void UltraEngLiquidity(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   if(u.vol.atr <= 0) return;
   double tol = u.vol.atr * UltraEqualTolATR;
   int lb = MathMax(UltraStructLookback / 2, 12);
   double lo = iLow(s, tf, iLowest(s, tf, MODE_LOW, lb, 1));
   double hi = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, lb, 1));
   int nL = 0, nH = 0;
   for(int i = 1; i <= lb; i++)
   {
      if(MathAbs(iLow(s, tf, i) - lo) <= tol) nL++;
      if(MathAbs(iHigh(s, tf, i) - hi) <= tol) nH++;
   }
   u.liq.poolBuy = (nL >= 2);  // equal lows = sell-side pool / buy grab target
   u.liq.poolSell = (nH >= 2);
   u.liq.sellSideLiq = u.liq.poolBuy || (u.st.swingLow > 0);
   u.liq.buySideLiq  = u.liq.poolSell || (u.st.swingHigh > 0);
   u.liq.poolLow = u.liq.poolBuy ? lo : u.st.swingLow;
   u.liq.poolHigh = u.liq.poolSell ? hi : u.st.swingHigh;

   double minD = u.vol.atr * UltraSweepDepthATR;
   int swlb = MathMax(UltraSweepLookback, 5);
   double bestDepth = 0;
   for(int i = 1; i <= swlb; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), c = iClose(s, tf, i), o = iOpen(s, tf, i);
      double rng = h - l; if(rng <= 0) continue;
      if(!u.liq.sweepBuy && u.liq.poolLow > 0 && l < u.liq.poolLow - minD && c > u.liq.poolLow)
      {
         double wick = (MathMin(c, u.liq.poolLow) - l) / rng;
         if(wick >= UltraSweepWickMin)
         {
            u.liq.sweepBuy = true; u.liq.grabBuy = true; u.liq.sweepExtBuy = l;
            bestDepth = MathMax(bestDepth, (u.liq.poolLow - l) / u.vol.atr);
            u.liq.confirmedBuy = (c > o);
         }
      }
      if(!u.liq.sweepSell && u.liq.poolHigh > 0 && h > u.liq.poolHigh + minD && c < u.liq.poolHigh)
      {
         double wick = (h - MathMax(c, u.liq.poolHigh)) / rng;
         if(wick >= UltraSweepWickMin)
         {
            u.liq.sweepSell = true; u.liq.grabSell = true; u.liq.sweepExtSell = h;
            bestDepth = MathMax(bestDepth, (h - u.liq.poolHigh) / u.vol.atr);
            u.liq.confirmedSell = (c < o);
         }
      }
      double upper = h - MathMax(c, o);
      double lower = MathMin(c, o) - l;
      if(lower / rng >= 0.45 && c > o) u.liq.stopHuntBuy = true;
      if(upper / rng >= 0.45 && c < o) u.liq.stopHuntSell = true;
   }
   u.liq.depthATR = bestDepth;
   u.liq.speed = (u.liq.sweepBuy || u.liq.sweepSell) ? MathMin(100.0, 40.0 + bestDepth * 40.0) : 0;
   u.liq.strength = u.liq.speed;
   u.liq.quality = 40;
   if(u.liq.confirmedBuy || u.liq.confirmedSell) u.liq.quality += 25;
   if(u.liq.stopHuntBuy || u.liq.stopHuntSell) u.liq.quality += 15;
   if(u.liq.poolBuy || u.liq.poolSell) u.liq.quality += 10;
   if(u.liq.quality > 100) u.liq.quality = 100;
   u.liq.rejectionScore = (int)MathRound(u.liq.quality);
}

void UltraEngFib(const string s, UltraSnap &u)
{
   // Proprietary swing selection = structure swings; impulse = external structure move
   u.fib.f100 = u.st.swingHigh; u.fib.f0 = u.st.swingLow;
   double rng = u.fib.f100 - u.fib.f0;
   if(rng <= 0) return;
   u.fib.impulseOK = (u.vol.atr > 0 && rng >= u.vol.atr * 1.2);
   u.fib.f382 = u.fib.f0 + rng * 0.382;
   u.fib.f500 = u.fib.f0 + rng * 0.500;
   u.fib.f618 = u.fib.f0 + rng * 0.618;
   u.fib.f786 = u.fib.f0 + rng * 0.786;
   u.fib.ext127 = u.fib.f100 + rng * (UltraFibExt127 - 1.0);
   u.fib.ext161 = u.fib.f100 + rng * (UltraFibExt161 - 1.0);
   // For bear impulse, extensions below f0
   if(u.st.externalBear)
   {
      u.fib.ext127 = u.fib.f0 - rng * (UltraFibExt127 - 1.0);
      u.fib.ext161 = u.fib.f0 - rng * (UltraFibExt161 - 1.0);
   }
   double px = SymbolInfoDouble(s, SYMBOL_BID);
   u.fib.retracePos = (px - u.fib.f0) / rng;
   u.fib.atBuyZone  = (u.fib.retracePos >= UltraFibBuyLow && u.fib.retracePos <= UltraFibBuyHigh);
   u.fib.atSellZone = (u.fib.retracePos >= UltraFibSellLow && u.fib.retracePos <= UltraFibSellHigh);
   // Zone ranking: 0.618 best, then 0.5, 0.786, 0.382
   u.fib.zoneRank = 0;
   if(MathAbs(u.fib.retracePos - 0.618) < 0.05) u.fib.zoneRank = 100;
   else if(MathAbs(u.fib.retracePos - 0.500) < 0.05) u.fib.zoneRank = 85;
   else if(MathAbs(u.fib.retracePos - 0.786) < 0.05) u.fib.zoneRank = 75;
   else if(MathAbs(u.fib.retracePos - 0.382) < 0.05) u.fib.zoneRank = 65;
   else if(u.fib.atBuyZone || u.fib.atSellZone) u.fib.zoneRank = 55;
   u.fib.confluence = u.fib.zoneRank;
   if(u.fib.impulseOK) u.fib.confluence += 10;
   if((u.fib.atBuyZone && u.liq.sweepBuy) || (u.fib.atSellZone && u.liq.sweepSell)) u.fib.confluence += 15;
   if(u.fib.confluence > 100) u.fib.confluence = 100;
   u.fib.quality = u.fib.confluence;
   u.fib.confidence = u.fib.quality;
}

void UltraEngInstitutional(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double o1 = iOpen(s, tf, 1), c1 = iClose(s, tf, 1), h1 = iHigh(s, tf, 1), l1 = iLow(s, tf, 1);
   double r1 = h1 - l1;
   if(r1 > 0)
   {
      double br = MathAbs(c1 - o1) / r1;
      bool atrOK = (u.vol.atr <= 0) || (r1 >= u.vol.atr * UltraDispATRMin);
      if(br >= UltraDispBodyMin && atrOK){ u.ict.dispBuy = (c1 > o1); u.ict.dispSell = (c1 < o1); }
   }
   double gapB = iLow(s, tf, 1) - iHigh(s, tf, 3);
   double gapS = iLow(s, tf, 3) - iHigh(s, tf, 1);
   if(gapB > 0 && (u.vol.atr <= 0 || gapB >= u.vol.atr * UltraFVG_MinATR)) u.ict.fvgBuy = true;
   if(gapS > 0 && (u.vol.atr <= 0 || gapS >= u.vol.atr * UltraFVG_MinATR)) u.ict.fvgSell = true;
   double o2 = iOpen(s, tf, 2), c2 = iClose(s, tf, 2);
   if(u.ict.dispBuy && c2 < o2) u.ict.obBuy = true;
   if(u.ict.dispSell && c2 > o2) u.ict.obSell = true;
   // Breaker: prior OB invalidated then reclaim
   if(u.bos.buy && u.ict.obSell) u.ict.breakerBuy = true;
   if(u.bos.sell && u.ict.obBuy) u.ict.breakerSell = true;
   // Mitigation: price returned into OB/FVG
   double px = SymbolInfoDouble(s, SYMBOL_BID);
   if(u.ict.obBuy && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationBuy = true;
   if(u.ict.obSell && px <= MathMax(o2, c2) && px >= MathMin(o2, c2)) u.ict.mitigationSell = true;
   if(u.st.swingHigh > u.st.swingLow)
   {
      double mid = (u.st.swingHigh + u.st.swingLow) * 0.5;
      u.ict.inDiscount = (px <= mid); u.ict.inPremium = (px >= mid);
   }
   u.ict.instZoneBuy = (u.ict.obBuy || u.ict.fvgBuy || u.ict.breakerBuy) && u.ict.inDiscount;
   u.ict.instZoneSell = (u.ict.obSell || u.ict.fvgSell || u.ict.breakerSell) && u.ict.inPremium;
   u.ict.rejectZoneBuy = u.liq.stopHuntBuy && u.ict.inDiscount;
   u.ict.rejectZoneSell = u.liq.stopHuntSell && u.ict.inPremium;
   u.ict.smConfluence = ((u.ict.obBuy || u.ict.fvgBuy) && u.liq.sweepBuy && u.ict.dispBuy) ||
                        ((u.ict.obSell || u.ict.fvgSell) && u.liq.sweepSell && u.ict.dispSell);
}

void UltraEngTrend(const string s, UltraSnap &u)
{
   u.trend.bull = u.st.externalBull || u.st.internalBull;
   u.trend.bear = u.st.externalBear || u.st.internalBear;
   // HTF / Macro / Week / Month
   int iH1, iH2, iL1, iL2;
   if(UltraFindSwings(s, UltraTF_Bias, 40, UltraSwingStrength, iH1, iH2, iL1, iL2))
   {
      bool hh = iHigh(s, UltraTF_Bias, iH1) > iHigh(s, UltraTF_Bias, iH2);
      bool hl = iLow(s, UltraTF_Bias, iL1) > iLow(s, UltraTF_Bias, iL2);
      bool lh = iHigh(s, UltraTF_Bias, iH1) < iHigh(s, UltraTF_Bias, iH2);
      bool ll = iLow(s, UltraTF_Bias, iL1) < iLow(s, UltraTF_Bias, iL2);
      u.trend.htfBull = (hh && hl); u.trend.htfBear = (lh && ll);
   }
   double smaH = UltraSMA(s, UltraTF_Bias, 50);
   double cH = iClose(s, UltraTF_Bias, 1);
   if(smaH > 0){ if(cH > smaH) u.trend.htfBull = true; if(cH < smaH) u.trend.htfBear = true; }
   double smaD = UltraSMA(s, UltraTF_Macro, 20);
   double cD = iClose(s, UltraTF_Macro, 1);
   if(smaD > 0){ u.trend.macroBull = (cD > smaD); u.trend.macroBear = (cD < smaD); }
   double smaW = UltraSMA(s, UltraTF_Week, 10);
   double cW = iClose(s, UltraTF_Week, 1);
   if(smaW > 0){ u.trend.weekBull = (cW > smaW); u.trend.weekBear = (cW < smaW); }
   double smaM = UltraSMA(s, UltraTF_Month, 6);
   double cM = iClose(s, UltraTF_Month, 1);
   if(smaM > 0){ u.trend.monthBull = (cM > smaM); u.trend.monthBear = (cM < smaM); }

   u.trend.mtfVotesBuy = 0; u.trend.mtfVotesSell = 0;
   if(u.trend.bull) u.trend.mtfVotesBuy++; if(u.trend.bear) u.trend.mtfVotesSell++;
   if(u.trend.htfBull) u.trend.mtfVotesBuy++; if(u.trend.htfBear) u.trend.mtfVotesSell++;
   if(u.trend.macroBull) u.trend.mtfVotesBuy++; if(u.trend.macroBear) u.trend.mtfVotesSell++;
   if(u.trend.weekBull) u.trend.mtfVotesBuy++; if(u.trend.weekBear) u.trend.mtfVotesSell++;
   if(u.trend.monthBull) u.trend.mtfVotesBuy++; if(u.trend.monthBear) u.trend.mtfVotesSell++;
   if(UltraUseMTFVoting)
   {
      ENUM_TIMEFRAMES tfs[3]; int n = 0;
      if(UltraUseM30) tfs[n++] = PERIOD_M30;
      if(UltraUseM15) tfs[n++] = PERIOD_M15;
      if(UltraUseM5)  tfs[n++] = PERIOD_M5;
      if(UltraUseM1Optional) { /* optional skipped into compact array */ }
      for(int i = 0; i < n; i++)
      {
         double sma = UltraSMA(s, tfs[i], 20);
         double c = iClose(s, tfs[i], 1);
         if(sma <= 0) continue;
         if(c > sma) u.trend.mtfVotesBuy++; else if(c < sma) u.trend.mtfVotesSell++;
      }
   }
   u.trend.strength = 30 + u.trend.mtfVotesBuy * 8 + u.trend.mtfVotesSell * 0;
   if(u.trend.bear) u.trend.strength = 30 + u.trend.mtfVotesSell * 8;
   if(u.trend.bull && u.trend.bear) u.trend.strength = 40;
   if(u.trend.strength > 100) u.trend.strength = 100;
   u.trend.quality = u.trend.strength;
   u.trend.persistence = MathMin(100, 20 + MathAbs(u.trend.mtfVotesBuy - u.trend.mtfVotesSell) * 12);
}

void UltraEngMomentum(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   int up = 0, dn = 0;
   double bodySum = 0, prevBody = 0;
   for(int i = 1; i <= MathMax(UltraMomentumBars, 3); i++)
   {
      double o = iOpen(s, tf, i), c = iClose(s, tf, i);
      double b = MathAbs(c - o);
      if(c > o) up++; if(c < o) dn++;
      if(i == 1) prevBody = b; else bodySum += b;
   }
   u.mom.momBuy = (up >= 2); u.mom.momSell = (dn >= 2);
   u.mom.direction = (up > dn) ? 1 : (dn > up ? -1 : 0);
   u.mom.strength = MathMin(100, (int)MathRound(100.0 * MathMax(up, dn) / MathMax(UltraMomentumBars, 3)));
   double avgPrev = bodySum / MathMax(UltraMomentumBars - 1, 1);
   u.mom.acceleration = (avgPrev > 0 && prevBody > avgPrev * 1.25) ? 80 : ((avgPrev > 0 && prevBody < avgPrev * 0.75) ? 30 : 55);
   u.mom.quality = (u.mom.strength + u.mom.acceleration) / 2;
   u.mom.confirmation = (u.mom.momBuy && u.ict.dispBuy) || (u.mom.momSell && u.ict.dispSell) ? 80 : 45;
}

void UltraEngVolatility(const string s, UltraSnap &u)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   u.vol.atr = UltraATR(s, ATR_Period);
   if(u.vol.atr <= 0) return;
   double avg = 0.0;
   for(int i = 2; i <= 21; i++) avg += (iHigh(s, tf, i) - iLow(s, tf, i));
   avg /= 20.0;
   double r1 = iHigh(s, tf, 1) - iLow(s, tf, 1);
   u.vol.relative = (avg > 0) ? (r1 / avg) : 1.0;
   u.vol.expansion = (u.vol.relative >= 1.35);
   u.vol.compression = (u.vol.relative <= 0.70);
   if(u.vol.expansion) u.vol.classification = 1;
   else if(u.vol.compression) u.vol.classification = -1;
   else u.vol.classification = 0;
}

void UltraEngRegime(UltraSnap &u)
{
   if(u.vol.compression && !(u.trend.bull || u.trend.bear)) u.regime = UREG_COMPRESSION;
   else if(u.vol.expansion && (u.choch.buy || u.choch.sell)) u.regime = UREG_REVERSAL;
   else if(u.vol.expansion && u.trend.strength >= 70) u.regime = UREG_EXPANSION;
   else if(u.trend.strength >= 75 && u.st.continuation) u.regime = UREG_STRONG_TREND;
   else if(u.trend.strength >= 55 && u.st.continuation) u.regime = UREG_HEALTHY_TREND;
   else if(u.trend.strength >= 40 && (u.trend.bull || u.trend.bear)) u.regime = UREG_WEAK_TREND;
   else if(u.liq.sweepBuy && u.ict.inDiscount && !u.trend.htfBear) u.regime = UREG_ACCUMULATION;
   else if(u.liq.sweepSell && u.ict.inPremium && !u.trend.htfBull) u.regime = UREG_DISTRIBUTION;
   else if(u.mom.acceleration <= 30 && u.vol.expansion) u.regime = UREG_EXHAUSTION;
   else u.regime = UREG_RANGE;
}

string UltraRegimeName(const ENUM_ULTRA_REGIME r)
{
   switch(r)
   {
      case UREG_STRONG_TREND: return "STRONG_TREND";
      case UREG_WEAK_TREND: return "WEAK_TREND";
      case UREG_HEALTHY_TREND: return "HEALTHY_TREND";
      case UREG_RANGE: return "RANGE";
      case UREG_COMPRESSION: return "COMPRESSION";
      case UREG_EXPANSION: return "EXPANSION";
      case UREG_REVERSAL: return "REVERSAL";
      case UREG_ACCUMULATION: return "ACCUMULATION";
      case UREG_DISTRIBUTION: return "DISTRIBUTION";
      case UREG_EXHAUSTION: return "EXHAUSTION";
   }
   return "RANGE";
}

//--------------------------------------------------------------------//
// 3. SESSION / NEWS INTELLIGENCE (never blocks)
//--------------------------------------------------------------------//
void UltraEngSessionNews(const string s, UltraSnap &u)
{
   u.ctx.session = "OFF";
   if(UltraSessionIntelEnabled)
   {
      MqlDateTime t; TimeToStruct(TimeGMT(), t);
      int h = t.hour;
      u.ctx.asia = (h >= 0 && h < 7);
      u.ctx.london = (h >= 7 && h < 16);
      u.ctx.newyork = (h >= 12 && h < 21);
      u.ctx.overlap = (u.ctx.london && u.ctx.newyork);
      u.ctx.killZone = (u.ctx.london || u.ctx.newyork);
      if(u.ctx.overlap) u.ctx.session = "LONDON/NY";
      else if(u.ctx.london) u.ctx.session = "LONDON";
      else if(u.ctx.newyork) u.ctx.session = "NEW YORK";
      else if(u.ctx.asia) u.ctx.session = "ASIA";
      else u.ctx.session = "OTHER";
      u.ctx.sessionConfidence = u.ctx.overlap ? 90 : (u.ctx.killZone ? 75 : 50);
      u.ctx.sessionQuality = u.ctx.sessionConfidence;
   }
   if(UltraNewsIntelEnabled)
   {
      u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
      u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
      u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
      u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   }
   u.ctx.spreadPts = (double)SymbolInfoInteger(s, SYMBOL_SPREAD);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);
   // UltraTrade24x5 / never blocks — no return false path here
}

//--------------------------------------------------------------------//
// 4. PROPRIETARY INDICATORS — SMI / MEO / IFI
//--------------------------------------------------------------------//
void UltraEngIndicators(const string s, UltraSnap &u)
{
   // SMI: direction * momentum * acceleration scaled -100..100
   double dir = (double)u.mom.direction;
   double smi = dir * (0.45 * u.mom.strength + 0.35 * u.mom.acceleration + 0.20 * u.mom.confirmation);
   if(smi > 100) smi = 100; if(smi < -100) smi = -100;
   u.ind.smi = smi;

   // MEO: market energy / participation / trend energy 0..100
   double energy = 0.35 * (u.vol.relative * 40.0) + 0.35 * u.trend.strength + 0.30 * u.liq.quality;
   if(energy < 0) energy = 0; if(energy > 100) energy = 100;
   u.ind.meo = energy;

   // IFI: institutional footprint from sweep+disp+OB/FVG+vol expand
   double ifi = 0;
   if(u.liq.sweepBuy || u.ict.dispBuy || u.ict.obBuy || u.ict.fvgBuy) ifi += 25;
   if(u.liq.sweepSell || u.ict.dispSell || u.ict.obSell || u.ict.fvgSell) ifi -= 25;
   if(u.ict.smConfluence) ifi += (u.ict.dispBuy ? 20 : -20);
   if(u.vol.expansion) ifi += (ifi >= 0 ? 15 : -15);
   if(ifi > 100) ifi = 100; if(ifi < -100) ifi = -100;
   u.ind.ifi = ifi;
}

//--------------------------------------------------------------------//
// 5. CONFLUENCE / PROBABILITY / PRECISION / AI DECISION
//--------------------------------------------------------------------//
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
void UltraEngDiagnostics(const string s, UltraSnap &u)
{
   u.diag.tickOK = (SymbolInfoDouble(s, SYMBOL_BID) > 0);
   u.diag.brokerOK = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
   u.diag.connectionOK = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   u.diag.indicatorOK = (u.vol.atr > 0);
   u.diag.memoryOK = true;
   if(UltraMemoryEngineEnabled && g_UltraMem.trades > 100000) u.diag.memoryOK = false;
   u.diag.processSpeedMs = g_UltraCore.lastLatencyMs;
   bool ok = u.diag.tickOK && u.diag.brokerOK && u.diag.connectionOK && u.diag.indicatorOK && u.diag.memoryOK;
   u.diag.health = ok ? "OK" : "DEGRADED";
   g_UltraCore.healthy = ok;
}

bool UltraCapitalOK(string &why)
{
   why = "";
   if(!UltraCapitalProtectEnabled) return true;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq <= 0){ why = "bad equity"; return false; }
   if(fm / eq < 0.08){ why = "free margin < 8%"; return false; }
   if(EnforceOpenTradeCaps && MaxOpenTrades > 0 && CountOpenTrades() >= MaxOpenTrades)
   { why = "max open trades"; return false; }
   return true;
}

bool UltraExecReady(const string s, string &why)
{
   why = "";
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE)) { why = "symbol trade mode off"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { why = "terminal blocked"; return false; }
   // fill policy / stops validated later in ExecuteBuy/Sell
   return true;
}

void UltraMemoryUpdateFromStats()
{
   if(!UltraMarketMemoryEnabled || !UltraPerfEngineEnabled) return;
   // Soft sync from existing EA stats if available
   g_UltraMem.winRate = GetWinRatePercent();
   g_UltraMem.profitFactor = GetProfitFactor();
   g_UltraMem.avgRR = GetAverageRR();
   g_UltraMem.lastSave = (long)TimeCurrent();
}

//--------------------------------------------------------------------//
// STRATEGIES (ULTRA)
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

string UltraDashboardText(const string s)
{
   UltraSnap u = g_UltraLastSnap;
   UltraSignal sig = g_UltraLastSignal;
   string dir = sig.buy ? "BUY" : (sig.sell ? "SELL" : "-");
   return
      "======= SNIPER AI ULTRA =======\n" +
      "BUILD: SA_ULTRA_92 | Comment: SNIPER AI\n" +
      "Symbol: " + s + " | TF: " + EnumToString(UltraETF()) + "\n" +
      "Open: " + IntegerToString(CountOpenTrades()) + " / " + IntegerToString(MaxOpenTrades) + "\n" +
      "AI Conf: " + IntegerToString(u.score.confidence) +
      " | Prec: " + IntegerToString(u.score.precision) +
      " | Prob: " + IntegerToString(u.score.probability) + "\n" +
      "Session: " + u.ctx.session +
      " | NewsVol: " + (u.ctx.newsVol ? "Y" : "N") +
      " | (never blocks)\n" +
      "Regime: " + UltraRegimeName(u.regime) + "\n" +
      "Trend B/S votes: " + IntegerToString(u.trend.mtfVotesBuy) + "/" + IntegerToString(u.trend.mtfVotesSell) +
      " | Str: " + IntegerToString(u.trend.strength) + "\n" +
      "BOS: " + (u.bos.buy ? "BUY" : (u.bos.sell ? "SELL" : "-")) +
      " CHoCH: " + (u.choch.buy ? "BUY" : (u.choch.sell ? "SELL" : "-")) +
      " Sweep: " + (u.liq.sweepBuy ? "BUY" : (u.liq.sweepSell ? "SELL" : "-")) + "\n" +
      "Fib zone B/S: " + (u.fib.atBuyZone ? "Y" : "N") + "/" + (u.fib.atSellZone ? "Y" : "N") +
      " rank=" + IntegerToString(u.fib.zoneRank) + "\n" +
      "SMI: " + DoubleToString(u.ind.smi, 1) +
      " | MEO: " + DoubleToString(u.ind.meo, 1) +
      " | IFI: " + DoubleToString(u.ind.ifi, 1) + "\n" +
      "Vol: " + (u.vol.expansion ? "EXPAND" : (u.vol.compression ? "COMPRESS" : "NORMAL")) +
      " ATR=" + DoubleToString(u.vol.atr, (int)SymbolInfoInteger(s, SYMBOL_DIGITS)) + "\n" +
      "Capital: " + (g_UltraCore.healthy ? "OK" : "CHECK") +
      " | Health: " + u.diag.health +
      " | Lat: " + IntegerToString((int)g_UltraCore.lastLatencyMs) + "ms\n" +
      "WR: " + DoubleToString(g_UltraMem.winRate, 1) + "%" +
      " PF: " + DoubleToString(g_UltraMem.profitFactor, 2) +
      " RR: " + DoubleToString(g_UltraMem.avgRR, 2) + "\n" +
      "Signal: " + dir + " [" + sig.tag + "] " + sig.reason + "\n" +
      "===============================";
}
