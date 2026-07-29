#ifndef HITMAN_ULTRA_00_TYPES_MQH
#define HITMAN_ULTRA_00_TYPES_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 00_TYPES — Enums · Structures · Shared Definitions
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 00. Shared Types — HITMAN AI                               |
//+------------------------------------------------------------------+
enum ENUM_ULTRA_REGIME
{
   UREG_STRONG_TREND = 0,
   UREG_WEAK_TREND,
   UREG_HEALTHY_TREND,
   UREG_RANGE,
   UREG_COMPRESSION,
   UREG_EXPANSION,
   UREG_BREAKOUT,
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
   bool strong, weak;
   bool confirmed, failed;
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
   bool equalLows, equalHighs;   // Master Blueprint aliases
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
   bool continuation, exhaustion;
   bool htfBull, htfBear, macroBull, macroBear;
   bool weekBull, weekBear, monthBull, monthBear;
   int  mtfVotesBuy, mtfVotesSell;
};

struct UltraMomentum
{
   int  direction; // +1/-1/0
   int  strength, acceleration, quality, confirmation;
   bool momBuy, momSell;
   bool weakness, impulse;
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
   bool   sessionLiquidity;          // overlap / kill-zone liquidity window
   int    sessionConfidence, sessionQuality;
   bool   newsVol;
   bool   highImpactProxy, midImpactProxy, lowImpactProxy;
   bool   beforeNews, duringNews, afterNews; // context phases — NEVER block
   string newsPhase;                 // "BEFORE" | "DURING" | "AFTER" | "NONE"
   double spreadPts, slipProxy;
   // Session + News: CONTEXT ONLY · Trades 24/5 · never hard-block
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
   string explanation; // Master Blueprint explainable decision text
};

UltraCoreState g_UltraCore;
UltraMemory    g_UltraMem;
UltraSnap      g_UltraLastSnap;
UltraSignal    g_UltraLastSignal;
datetime       g_UltraLastFireBar = 0;

//--------------------------------------------------------------------//
// 1. ULTRA CORE / DATA / CONFIG / VALIDATION / RECOVERY / LOG / PERF
//--------------------------------------------------------------------//

#endif // HITMAN_ULTRA_00_TYPES_MQH
