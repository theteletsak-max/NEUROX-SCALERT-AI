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
   bool   foundationOK;      // PHASE 1 — foundation engine pass
   bool   marketOK;          // PHASE 2 — market intelligence approved
   bool   chainOK;           // VALIDATION CHAIN — Mission-ready (all critical VALID)
   long   lastCycleMs;
   long   lastLatencyMs;
   int    errorCount;
   int    recoveryCount;
   int    healthTickCount;
   string lastError;
   string buildId;           // HA_ULTRA_93
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
   int    cycle;       // ENUM_MARKET_CYCLE as int
   string cycleName;   // ACCUMULATION / MARKUP / DISTRIBUTION / MARKDOWN
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
   bool fakeBuy, fakeSell;       // ROADMAP P5 — wick reclaim without institutional confirm
   bool genuineBuy, genuineSell; // ROADMAP P5 — confirmed + depth + quality
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
   bool imbalanceBuy, imbalanceSell;     // raw imbalance (gap) distinct from FVG zone use
   bool institutionalLiqBuy, institutionalLiqSell;
   bool instZoneBuy, instZoneSell;
   bool rejectZoneBuy, rejectZoneSell;
   bool smConfluence;
   bool dispBuy, dispSell;
   bool inDiscount, inPremium;
   bool weakOBBuy, weakOBSell;           // ROADMAP P6 — mitigated / no displacement
   bool weakFVGBuy, weakFVGSell;         // ROADMAP P7 — tiny / no displacement gap
   bool strongOBBuy, strongOBSell;       // fresh OB + displacement
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
   string session;                   // window name (LONDON_OPEN / OVERLAP / ...)
   string sessionRegion;             // Sydney|Tokyo|London|NewYork|Overlap
   bool   sydney, tokyo, asia, london, newyork, overlap;
   bool   londonOpen, londonCont, nyCont;
   bool   killZone;
   bool   sessionLiquidity;          // institutional liquidity window
   bool   sessionTransition;         // near window boundary
   int    sessionPriority;           // 1..5 stars
   int    sessionConfidence, sessionQuality;
   int    sessionLiqScore;           // 0..100
   int    sessionVolScore;           // 0..100
   int    sessionMomScore;           // 0..100
   int    sessionTrendScore;         // 0..100
   int    sessionSpreadScore;        // 0..100 (higher = healthier spread)
   int    sessionExecScore;          // 0..100
   int    sessionBias;               // soft confidence delta applied by USM2 (-8..+12)
   int    londonHour;                // DST-adjusted London local hour
   bool   newsVol;
   bool   highImpactProxy, midImpactProxy, lowImpactProxy;
   bool   beforeNews, duringNews, afterNews; // context phases — NEVER block
   string newsPhase;                 // "BEFORE" | "DURING" | "AFTER" | "NONE"
   string eventClass;                // NFP|FOMC|CPI|GDP|PMI|RATES|SPEECH|MAJOR|NONE
   int    eventImpact;               // 0=none 1=low 2=mid 3=high
   int    eventConfidence;           // 0..100 event-context confidence
   double spreadPts, slipProxy;
   double tickSpeed;                 // ticks/sec proxy
   int    execQuality;               // 0..100 broker/exec assessment
   // Session + News: CONTEXT ONLY · Trades 24/7 · never hard-block
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
   int adaptiveBias; // soft delta from Adaptive Intelligence (never strategy change)
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
// DEFENSE LINE ENGINE v1.0 — shared enums / report
//--------------------------------------------------------------------//
enum ENUM_DEFENSE_LEVEL
{
   DEF_GREEN  = 0, // Trade Allowed
   DEF_YELLOW = 1, // Wait for Confirmation
   DEF_RED    = 2  // Block Trade
};

enum ENUM_DEFENSE_ACTION
{
   DEF_ACT_EXECUTE = 0,
   DEF_ACT_WAIT,
   DEF_ACT_NO_TRADE,
   DEF_ACT_DO_NOT_EXECUTE
};

struct UltraDefenseLine
{
   int                id;       // 1..10
   string             name;
   bool               pass;
   ENUM_DEFENSE_LEVEL level;
   string             reason;
};

struct UltraDefenseReport
{
   bool               valid;
   bool               buySide;
   ENUM_DEFENSE_LEVEL overall;
   ENUM_DEFENSE_ACTION action;
   bool               allowEntry;
   bool               allowExecute;
   UltraDefenseLine   line[11]; // 1..10 used
   string             summary;
};

UltraDefenseReport g_UltraDefenseLast;

//--------------------------------------------------------------------//
// MISSION CONTROL — BUY / SELL / WAIT / HOLD / MANAGE / EXIT
//--------------------------------------------------------------------//
enum ENUM_SUPREME_DECISION
{
   SUP_BUY = 0,
   SUP_SELL,
   SUP_WAIT,
   SUP_HOLD,
   SUP_MANAGE,
   SUP_EXIT
};

// Shared early — PositionEvolution / MissionControl both need this type
struct UltraExitValidation
{
   bool thesisBroken;
   bool structureChanged;
   bool masterTrendChanged;
   bool riskRule;
   bool healthyCorrection;
   bool trueReversal;
   bool allowClose;
   string reason;
};

// Forward — Mission Control is sole close authority (defined later)
bool UltraMission_ClosePosition(const ulong ticket, const string whyIn, const bool riskForced);
bool UltraMission_ClosePartial(const ulong ticket, const double volume, const string why);
void UltraMission_NoteOpen(const ulong ticket, const string s, const bool isBuy, const string tag);
bool UltraMission_AllowNewEntry(const string s);

//--------------------------------------------------------------------//
// 1. ULTRA CORE / DATA / CONFIG / VALIDATION / RECOVERY / LOG / PERF
//--------------------------------------------------------------------//

#endif // HITMAN_ULTRA_00_TYPES_MQH
