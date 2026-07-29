#ifndef SNIPER_ULTRA_SHELL_A_MQH
#define SNIPER_ULTRA_SHELL_A_MQH
//+------------------------------------------------------------------+
//| Shell A — Inputs, globals, forward declarations (pre-Ultra)      |
//+------------------------------------------------------------------+

//======================== INPUTS ===================================//

input group "GENERAL"

input long MagicNumber = 40001;
input string TradeComment = "SNIPER AI";

input group "INSTANT OPEN + QUALITY PREFER"
// BEST QUALITY selects the trade (structure + IDP + ADX).
// AGGRESSIVE INSTANT executes immediately once selected (tick path, no idle cooldown).
input bool   InstantQualityMode          = true;   // profile banner / intent lock


// OK93: PRIME inputs replaced — see ULTRA CORE / MARKET / FIB / STRATEGIES inputs in ULTRA module.
// Kept for .set compatibility (unused by live router):
input bool   Enable_FlashSweep   = true;
input bool   Enable_ContSniper   = true;
input bool   Enable_RevSniper    = true;
input bool   Enable_FibSniper    = true;
input bool   Enable_BreakImpulse = true;
input int    MinStrategyScore    = 58;
input int    InstantFireScore    = 75;
input bool   BlockOppositeSameSymbol = true;
input double FibBuyLow         = 0.50;
input double FibBuyHigh        = 0.886;
input double FibSellLow        = 0.114;
input double FibSellHigh       = 0.50;
input bool   SoftPreferFib     = true;


input group "SNIPER IDP - BUILT INTO EA (signal core)"
// Institutional Displacement Pulse computed INSIDE the EA (same math as SNIPER_IDP).
// No separate indicator required for trading. Chart SNIPER_IDP is optional visual only.
input bool   EnableIDPConfluence     = true;   // master: IDP pulse gates live FIRE
input bool   IDP_HardGate            = false;  // OK81: IDP prefer/log only — NEVER hard-block
input bool   IDP_RequireStrong       = false;  // false=QUALITY |pulse|; true=STRONG only
input double IDP_MinAbsPulse         = 30.0;   // OK81 quality prefer threshold (soft)
input double IDP_StrongAbsPulse      = 70.0;   // STRONG floor
input int    IDP_PulseShift          = 1;      // OK79: closed bar = stable quality pulse
input int    IDP_ATR_Period          = 14;
input int    IDP_EMA_Period          = 50;     // trend-side reference
input int    IDP_SwingLookback       = 5;
input double IDP_SweepMinWickRatio   = 0.33;
input double IDP_SweepMinDepthATR    = 0.08;
input double IDP_DispMinBodyRatio    = 0.48;
input double IDP_DispMinATR          = 0.35;
input bool   IDP_ApplyToAPEX         = true;   // gate APEX through IDP
input bool   IDP_ApplyToContFallback = true;   // gate ContFallback through IDP
input bool   IDP_LogGate             = true;   // print IDP pass/fail

input group "PRISM BEAST MODE ENGINE (support only — not a live entry path)"
// OK67: live entries are APEX/ContFallback only. Beast/Ultra still finalize those tags.

input bool   EnableBeastMode                 = true;  // unified PRISM beast pipeline
input bool   EnableSniperMode                = true;  // aggressive fire when beast gates pass
input bool   BeastUseUnifiedStructure        = true;  // MPI/ICE/rank share one structure snapshot
input bool   BeastRequireReversalStack       = true;  // RevSniper/LiquiditySweep need liquidity stack
input int    BeastMinReversalLiquidityScore  = 8;     // BEST: higher Rev liquidity floor (max 15)
// ALLTRADE56: do not block same-bar Cont re-fire across multi-chart attaches.
// OK54 logic still safe if turned back on (only while direction still open).
input bool   BeastDuplicateBarGuard          = false; // OFF: never suppress Cont/Rev after FIRE
input bool   BeastCaptureSignalSnapshot      = true;  // record MPI/ICE at decision time
input bool   EnableBeastDashboard            = true;  // rich HUD when EnableDashboard=true

input group "MARKET REVERSAL SNIPER (RETIRED live — RevSniper offline OK67)"

input bool   EnableEarlyMarketReversal       = true;  // catch flips before full trend ADX
input bool   ReversalRequireTrendADX         = false; // false = don't wait for new trend+ADX
input bool   ReversalAcceptCHoCHOrSweep      = true;  // CHoCH can help reclaim confirm
input bool   ReversalIMCESoftInTrend         = true;  // allow Rev in TREND if stack is strong
input int    ReversalStructureRecencyBars    = 30;    // lookback for sweep/CHoCH
input bool   ReversalRequireCorrectSideSweep = true;  // BUY needs lows swept; SELL needs highs swept
input bool   ReversalRequireReclaimConfirm   = true;  // CHoCH / displacement / stop-hunt / inducement
input bool   ReversalRequireZone             = true;  // OB or FVG in trade direction
input bool   ReversalStrictCorrectSignal     = true;  // plain candle alone is NOT enough reclaim
input bool   ReversalRejectWrongSideRecent   = true;  // block if opposite sweep is more recent
input bool   ReversalPreferStopHunt          = false; // true = require stop-hunt candle (stricter)
input bool   ReversalLogValidation           = true;  // print why Rev passed/failed

input group "PRISM ULTRA CORE v11"
// BEST QUALITY: Cont/Rev need structure + confirmations. InstantTrend is
// fallback only. Ultra still fires fast AFTER quality path + engines pass.
// Score floors apply hard to InstantTrend; Cont/Rev use HP confirms.

input bool   EnableUltraCore                 = true;  // master Ultra Core switch
input bool   UltraCycleCache                 = true;  // cache structure/score per cycle
input bool   UltraSmartTickFilter            = true;  // skip re-eval when bid/ask+bar unchanged
input bool   UltraSniperEntryGate            = true;  // checklist (soft on Cont/Instant when aggressive)
input bool   UltraAggressiveFire             = true;  // fire AFTER quality path+engines pass
input int    UltraMinBeastScore              = 30;    // InstantTrend hard floor (0=off)
input int    UltraMinConfidencePct           = 35;    // InstantTrend hard floor (0=off)
input bool   UltraInstantTrendSoftGates      = false; // BEST: Instant must pass full gates
input bool   UltraLogRejectReasons           = true;  // explain signal rejects (throttled 1x/bar)
input bool   UltraHealthMonitor              = true;  // track decision latency + health
input bool   EnableUltraDashboard            = true;  // Ultra HUD (latency, score, last reject)
input bool   UltraHighProbability            = true;  // prefer Cont/Rev; Instant only as fallback
input int    UltraHP_MinConfirmations        = 4;     // Cont/Rev HARD min confirms when BestQualitySetups

// RETIRED ContSniper/Instant live switches (OK67) — kept for old .set compatibility only
input bool   BestQualitySetups           = true;  // used by ContFallback structure quality helpers only
input bool   BestPathsOnly               = true;  // RETIRED live
input bool   AggressiveInstantQuality    = true;  // RETIRED live
input bool   PreferQualityPaths          = true;  // RETIRED live
input bool   TryNextPathIfEnginesFail    = false; // RETIRED — no Instant fallback
input bool   EnableAdaptivePathRanking   = false; // RETIRED live
input int    AdaptivePathMinTrades       = 10;
input bool   PrintPathStatsOnInit        = true;

input group "APEX - WORLD-CLASS LIQUIDITY SNIPER (LIVE)"
// From-scratch best path: structural HTF bias (swings+MA) → map liquidity
// pool → stop-hunt sweep of that pool → displacement reclaim with tick-vol
// expansion → enter only unmitigated FVG/OB → SL beyond sweep.
// ONE decision. NO post-FIRE veto (tag APEX bypasses ICE/IMCE/Ultra re-check).

input bool   EnableAPEXStrategy          = false; // OK91 DELETED live — retired
// OK67 PURE: live path is ONLY APEX → ContFallback (BOS+zone). No PRISM/LCS/ContSniper live.
input bool   EnableAntiScalpMode         = false;  // OK81: off — was enabling wait gates
input bool   EnableContFallback          = false;  // OK91 DELETED live — retired
input bool   ContFallbackBypassEngines   = true;   // ContFallback skips ICE/IMCE after structure pass
input bool   ContFallbackOncePerBar      = false;  // OK81: never OncePerBar-block
input int    ContFallbackCooldownMinutes = 0;      // OK81: NEVER ContFallbackCooldown block
input int    ContFallbackMinimumHoldBars = 8;      // OK79: quality hold (not scalp)
input double ContFallbackSL_ATR_Boost    = 1.5;    // wider SL — not a scalp stop
input int    ContFallbackMaxOpen         = 1;      // max open ContFallback positions on this symbol
input bool   ContFallbackDisableAdaptiveHold = true; // do not shorten hold in ranging for ContFallback/APEX

input group "CONT STRUCTURE - INSTANT OPEN (OK81)"
// Anytime: sessions never hard-block.
// Instant quality ContFallback: trend + BOS + zone + (near OR disp) + score.
// ADX not hard-required (still scores). IDP still hard-gates direction.
input int    ContStruct_BOS_MaxBars          = 18;    // OK80 wider BOS window
input bool   ContStruct_RequireTwoBarBOS     = false; // OK80: fresh single BOS OK
input bool   ContStruct_FreshOBOnly          = false; // OK80: allow active OB/FVG
input double ContStruct_MinFVG_ATR           = 0.20;  // quality FVG size vs ATR
input double ContStruct_MaxFVGFillPct        = 55.0;  // reject mostly-filled FVGs
input double ContStruct_ZoneProximityATR     = 1.15;  // OK79 quality near-zone
input bool   ContStruct_RequireDisplacement  = false; // use ZoneOrDisp
input bool   ContStruct_ZoneOrDisplacement   = true;  // near-zone OR displacement required
input double ContStruct_MinDispBodyRatio     = 0.48;  // OK79 quality displacement
input double ContStruct_MinDispATR           = 0.35;  // OK79 quality displacement
input bool   ContStruct_RequireHTF_BOS       = false; // optional HTF BOS
input bool   ContStruct_PreferDiscountPrem   = false; // soft only (scores bonus; not hard gate)
input bool   ContStruct_RequireTrendADX      = false; // OK80: ADX soft (fixes ADX waits)
input bool   ContStruct_SkipRanging          = false; // OK80: FIX ranging-regime hard wait
input int    ContStruct_MinScore             = 20;    // OK81 low floor — quality via components
input bool   ContStruct_LogDetail            = false; // wait logs once/bar via Ultra throttle

input ENUM_TIMEFRAMES APEX_BiasTF        = PERIOD_H4;
input ENUM_TIMEFRAMES APEX_EntryTF       = PERIOD_CURRENT; // OK80 chart TF
input int    APEX_BiasMA_Period          = 200;
input int    APEX_SwingStrength          = 2;      // bars left/right for swing pivot
input int    APEX_SwingLookback          = 40;      // BiasTF bars to map structure
input int    APEX_PoolLookback           = 30;      // EntryTF bars to find equal H/L pool
input double APEX_EqualTolATR            = 0.12;    // equal high/low tolerance vs ATR
input int    APEX_SweepLookback          = 24;     // OK62 longer
input double APEX_MinSweepWickRatio      = 0.28;   // OK62 relaxed
input double APEX_MinSweepDepthATR       = 0.06;
input double APEX_DispMinBodyRatio       = 0.48;   // OK79 best quality
input double APEX_DispMinATR             = 0.40;   // OK79 best quality
input double APEX_TickVolExpansion       = 1.25;    // bar1 tick vol vs avg (1.0=off soft)
input bool   APEX_RequireTickVol         = false;
input bool   APEX_RequireUnmitigatedZone = false;  // OK69: OFF so APEX can fill (zone still preferred in path)
input bool   APEX_RequireStructureBias   = false;
input bool   APEX_RequireMAAlign         = true;
input bool   APEX_BiasNeedStructOrMA     = true;
input bool   APEX_RelaxedEntries         = true;   // OK62: softer wick/disp + swing-sweep path
input bool   APEX_UseSweepSL             = true;
input double APEX_SL_BufferATR           = 0.12;
input double APEX_MaxSL_ATR              = 4.0;
input bool   APEX_LogValidation          = true;
input bool   APEX_LogFailsEveryBar       = true;

input group "SESSION DETECT (London / New York / Asia)"
// OK72: detect sessions for analysis. HardBlock OFF = TRADE ANYTIME.
// Strong quality comes from structure/ADX — not from session blocking.

input bool   EnableSessionDetect         = true;   // ON: detect & log London/NY/Asia
input bool   EnableAPEXSessionFilter     = true;   // ON: kill-zone awareness (annotate)
input bool   APEX_SessionHardBlock       = false;  // OK72 LOCK: false = TRADE ANYTIME
input bool   APEX_UseGMT                 = true;   // true=TimeGMT hours; false=broker server hours
input bool   SessionLogOnChange          = true;   // print when session name changes
input bool   APEX_AllowLondon            = true;   // London counts as kill-zone
input int    APEX_LondonStartHourGMT     = 7;      // inclusive
input int    APEX_LondonEndHourGMT       = 16;     // exclusive (covers London open into NY overlap)
input bool   APEX_AllowNewYork           = true;   // NY counts as kill-zone
input int    APEX_NYStartHourGMT         = 12;     // inclusive
input int    APEX_NYEndHourGMT           = 21;     // exclusive
input bool   APEX_AllowAsia              = true;   // OK71: Asia detected + optional kill-zone
input int    APEX_AsiaStartHourGMT       = 0;      // inclusive
input int    APEX_AsiaEndHourGMT         = 7;      // exclusive (until London)
input bool   APEX_SessionFilterCryptoToo = false;  // crypto: always anytime unless hard+this true

input group "LCS - RETIRED (not on live path OK67)"
input bool   EnableLCSStrategy           = false;  // RETIRED — ignored by EvaluateStrategySignals
input bool   LCSOnlyLivePath             = false;
input ENUM_TIMEFRAMES LCS_BiasTF         = PERIOD_H4;
input ENUM_TIMEFRAMES LCS_EntryTF        = PERIOD_H1;
input int    LCS_BiasMA_Period           = 200;
input int    LCS_SweepLookbackBars       = 12;
input int    LCS_SwingPadBars            = 5;
input double LCS_MinSweepWickRatio       = 0.40;
input double LCS_MinSweepDepthATR        = 0.08;
input double LCS_DispMinBodyRatio        = 0.55;
input double LCS_DispMinATR              = 0.60;
input bool   LCS_RequireZone             = true;
input bool   LCS_RequireDisplacement     = true;
input bool   LCS_UseSweepSL              = true;
input double LCS_SL_BufferATR            = 0.10;
input bool   LCS_LogValidation           = true;

input bool   EnableAlwaysQualityMode     = true;
input bool   QualityRequireStructureZone = true;  // Cont needs BOS/OB/FVG (or pullback)
input bool   QualityRequireTrendAndADX   = true;  // OK72: strong setups prefer trend+ADX
input bool   QualityDisableWeakPaths     = true;  // BEST: suppress weak VolBreakout unless stacked
input int    QualityMPIScore             = 0;

input bool   EnableInstantSniperMode     = false; // RETIRED live — InstantTrend offline
input bool   AllowTrendOnlyInstantEntry  = false; // RETIRED — no trend-only scalp fallback
input bool   AggressiveSniperEntries     = true;
input bool   NeverBlockValidSniperEntry  = true;  // don't veto approved Cont/Rev
input bool   ResolveConflictByTrend      = true;
input bool   AggressiveInstitutionalExecution = true; // fast Cont/Rev once quality stack OK
input double PullbackMaxATRMultiple      = 2.5;   // max ATR distance from EMA to count as pullback
input double InstantPullbackATRMultiple  = 2.5;   // tighter pullback for quality Cont
input int    InstantStructureRecencyBars = 24;
input int    InstantMinimumMPIScore      = 0;
input bool   InstantTwoOfThreeLiquidity  = true;
input bool   InstantFvgOrOb              = true;
input double InstantChannelBreakATR      = 0.35;
input int    DirectionalBOS_LookbackBars = 8;     // OK68: tighter same-dir BOS window

input group "TRADE SIZE & LIMITS (adjustable)"
// Change these in EA Inputs after attach — they are live settings.

input double LotSize = 0.01;              // lots per trade (when UseFixedLot=true)
input bool   UseFixedLot = true;          // true = use LotSize; false = risk % of equity
input double RiskPercent = 1.0;           // used only when UseFixedLot=false
input double MaxLotSizeHardCap = 5.0;     // hard ceiling so sizing never goes insane

input group "OPEN TRADES CAPS (adjustable — set in Inputs)"
// All caps are live Inputs. Set any to 0 = unlimited / off for that cap.
// Turn EnforceOpenTradeCaps=false to ignore ALL open-trade count limits.

input bool   EnforceOpenTradeCaps         = true;  // master: false = no open-trade count blocks
input int    MaxOpenTrades                = 3;     // OK91: max 3 open trades
input int    MaxTotalOpenTradesAllSymbols = 0;     // ALLTRADE56: 0=unlimited — was 9 blocking multi-chart
input int    MaxOpenTradesPerCurrency     = 0;     // ALLTRADE56: 0=off — was 4 blocking EUR/GBP/XAU USD share

input group "SMT - SMART MONEY TECHNIQUE"
// RIGHT PLACE: SMT belongs on REVERSAL / liquidity paths (RevSniper,
// LiquiditySweep). It must NOT hard-block InstantTrend/ContSniper — that
// duplicated RevSniper's sweep+zone checks and killed BTC trend execution.

input bool   EnableSMT                 = true;
input string SMTReferenceSymbol        = "";   // e.g. ETHUSD.m for BTC — blank = internal SMT only
input bool   SMTAllowInternal          = true;
input bool   SMTRequireForEntry        = true;  // HARD on RevSniper/LiquiditySweep when stack fails
input bool   SMTBlockContinuationPaths = false; // keep FALSE so Cont/Instant are not SMT-blocked
input int    SMTSwingLookbackBars      = 20;
input bool   SMTFailOpenIfNoRefData    = true;  // if ref blank/unavailable, do not block (fail-open)

input group "IMCE - INSTITUTIONAL MARKET CONTEXT ENGINE"
// HARD context gate — blocks chop on reversal paths; continuation/InstantTrend
// can still fire when trend+ADX agree (fixes OK27 BTC chop deadlock).

input bool   EnableIMCE                = true;
input bool   IMCERequireForEntry       = true;  // HARD gate
input bool   IMCEBlockManipulationChop = true;
input bool   IMCEAllowTrendContinuationsInChop = true; // InstantTrend/Cont in chop when trend agrees

input group "ICE - INSTITUTIONAL CONFIDENCE ENGINE"
// Your log: HARD ICE 25 < 50 — old saved input floor was 50.
// NEW input name ICE_MinScore resets that. Trend+ADX+IMCE now scores ~45.

input bool   EnableInstitutionalConfidence = true;
input bool   ICERequireForEntry            = true;  // HARD gate
input int    ICE_MinScore                  = 25;    // ALLTRADE56: was 32 — fewer false Cont rejects

input group "FILTERS"

input bool UseEMA = true;
input bool UseADX = true;
input bool UseATR = true;

input group "TIMEFRAMES"

input ENUM_TIMEFRAMES TrendTF = PERIOD_CURRENT; // OK80 chart TF
input ENUM_TIMEFRAMES EntryTF = PERIOD_CURRENT; // OK80: use chart TF (H4 chart = H4)

input group "LONG TERM HOLDING"

input bool EnableLongTermHolding = true;
input int  MinimumHoldBars = 24; // OK64: longer hold on EntryTF (H1≈24h)

input group "ATR TRAILING STOP"

input bool   EnableATRTrailing = true;
input double ATR_TrailingMultiplier = 2.5;

input group "TREND EXIT"

input bool EnableTrendExit = false; // FIX: was true by default - this is the second time in this project trend-exit has turned out to be closing trades that weren't actually supposed to close. Rather than keep special-casing individual symbols (as was done for BTC/ETH), it's now off everywhere by default. SL/TP1/TP2/TP3/trailing still fully protect every trade; turn this back on deliberately if you specifically want ADX-based early exits.
input int  TrendExitADXLevel = 20;

input group "HIGHER TIMEFRAME CONFIRMATION"

input bool             EnableHTFConfirmation = false; // OFF: HTF was a hard blocker; aggressive sniper uses entry-TF structure
input ENUM_TIMEFRAMES  HigherTimeframe = PERIOD_H4;

input group "NEWS AWARENESS"
// Know news via calendar logs. Hard-block retired — never pauses trading for news.

input bool EnableNewsAwareness = true;  // know/log high-impact news (does NOT block)
input int  MinutesBeforeNews = 30;
input int  MinutesAfterNews = 30;
input bool NewsAwarenessLogOncePerBar = true; // log at most once per EntryTF bar
// Hard news block RETIRED (OK66): EnableNewsFilter / BlockHighImpact* removed — awareness only.

// EVENT TIGHTEN RETIRED (OK67) — news awareness must not raise ICE/MPI or block.
input bool   EnableEventQualityMode       = false; // forced inert via EventQualityModeActive()
input bool   EventQualityAppliesToCrypto  = false;
input bool   EventDisableWeakPaths        = false;
input bool   EventRequireStructureZone    = false;
input bool   EventRequireTrendAndADX      = false;
input int    EventQualityMPIScore         = 0;
input int    EventICE_MinScoreBoost       = 0;
input int    EventMinutesBeforeNews       = 30;
input int    EventMinutesAfterNews        = 30;

//======================== GLOBALS ==================================//

bool TradingAllowed=true;

// APEX runtime (world-class path invalidation → Execute SL)
double   g_APEX_InvalidationPrice = 0.0;
datetime g_APEX_SweepBarTime      = 0;
string   g_APEX_LastDetail        = "";
string   g_APEX_LastBuyFail       = "";
string   g_APEX_LastSellFail      = "";

// LCS runtime (fallback path)
double   g_LCS_InvalidationPrice = 0.0;
datetime g_LCS_SweepBarTime      = 0;
string   g_LCS_LastDetail        = "";

string BrokerSymbol="";

// Trade statistics (persisted via GlobalVariable - see Part 18)
int    Stat_TotalTrades      = 0;
int    Stat_WinTrades        = 0;
int    Stat_LossTrades       = 0;
double Stat_GrossProfit      = 0.0;
double Stat_GrossLoss        = 0.0;
int    Stat_ConsecutiveWins  = 0;
int    Stat_ConsecutiveLosses = 0;

// Daily loss tracking (real per-day reference balance, not a placeholder)

datetime DailyTrackedDay=0;
double   DailyStartBalance=0.0;
datetime WeeklyTrackedWeekStart=0;
double   WeeklyStartBalance=0.0;
datetime MonthlyTrackedMonthStart=0;
double   MonthlyStartBalance=0.0;

// Indicator Handles - PER SYMBOL (see MULTI-SYMBOL EXECUTION, Part 19).
// Arrays instead of single handles so each symbol in MultiSymbolList gets
// its own indicator instance; index-matched to MultiSymbolList[].
int EMAHandles[];
int ADXHandles[];
int ATRHandlesArr[];
int FilterATRHandles[];
int HTFEMAHandlesArr[];

// NEW - Mean-Reversion strategy module handles (see Part 15b). Per-symbol,
// same indexing pattern as every other indicator handle array above.
int RSIHandlesArr[];
int BBHandlesArr[];

// NEW - Trend-Following strategy module (Part 15d). Deliberately SEPARATE
// from EMAHandles above (the existing single 200-period EMA used by the
// SMC engine's trend filter) - this needs a genuine fast/slow PAIR to
// detect an actual crossover, not one trend-direction reference line.
int FastEMAHandlesArr[];
int SlowEMAHandlesArr[];

string MultiSymbolList[];
string PrimarySymbol=""; // the chart's own symbol - used for dashboard display and as the fallback when multi-symbol trading is off

// Per-trade tracking - PER SYMBOL, index-matched to MultiSymbolList[].
// FIX: these used to be single global values, which meant in multi-symbol
// mode a trade opening on one symbol would incorrectly start the cooldown
// (and post-loss cooldown) for every OTHER symbol too, since the cooldown
// checks read one shared value regardless of which symbol was being
// evaluated.
datetime LastTradeTimeArr[];
datetime LastAttemptTimeArr[];
bool     LastTradeWasLossArr[];
datetime LastLossCloseTimeArr[];

// OK64 anti-scalp ContFallback tracking (NeverBlock cannot bypass these)
datetime g_ContFallbackLastSignalBar = 0;
datetime g_ContFallbackLastFillTime  = 0;
datetime g_NewsAwareLastLogBar       = 0;

// FIX: same class of bug as above, found during this review - these were
// previously single globals/statics shared across every symbol instead of
// arrays index-matched to MultiSymbolList. In multi-symbol mode this meant:
//  - LastEntryEvalBarTime (bar-gate for new entries) being stamped by
//    whichever symbol last ran InstantExecution(), so other symbols could
//    have their own genuinely-new bar silently skipped (or, less often,
//    incorrectly allowed) depending on timing coincidences between symbols.
//  - DetectCHoCH()'s internal state (previously function-local statics)
//    comparing one symbol's trend flip against a DIFFERENT symbol's last
//    recorded state, and gating "already evaluated this bar" against
//    whichever symbol happened to run last - producing false or missed
//    CHoCH signals whenever more than one symbol was traded.
// Both are now arrays, index-matched to MultiSymbolList like everything
// else per-symbol in this file.
datetime LastEntryEvalBarTimeArr[];

// NEW - per-symbol consecutive win/loss tracking (fixes adaptive scoring
// penalty bleeding between unrelated symbols - see OnTradeTransaction and
// GetEffectiveMinimumScore). In-memory only, same documented tradeoff as
// SignalSnapshots[] - resets on restart rather than adding yet another
// persisted GlobalVariable set; the aggregate Stat_ConsecutiveLosses this
// supplements is still persisted as before.
int ConsecutiveLossesPerSymbolArr[];
int ConsecutiveWinsPerSymbolArr[];
datetime CHoCH_LastBarTimeArr[];
bool     CHoCH_LastBullTrendArr[];
bool     CHoCH_StateInitializedArr[];
datetime DiagLastBarTimeArr[];
datetime LastBOSTrueBarTimeArr[];
datetime LastCHoCHTrueBarTimeArr[];
bool     LastCHoCHWasBullArr[]; // AUDITFIX49: direction of last confirmed CHoCH (for reclaim polarity)
datetime LastSweepTrueBarTimeArr[]; // CRITICAL FIX (this pass): DetectLiquiditySweep() was being required to coincide on the exact same bar as CHoCH/OB in the live PRISM strategy setups - see the fix at LiquiditySweepBuySetup()/SellSetup() for the full explanation.

// FIX: DetectCHoCH() is called from many places inside a single decision
// cycle (CalculateTradeScore, HasStructureConfluence, HasHTFStructureConfluence,
// CapturePendingSignalSnapshot, the dashboard...). It used to flag itself as
// "already evaluated this bar" the instant the FIRST caller ran it, so only
// that first caller ever saw the real true/false answer - every other
// caller in the SAME cycle silently got false, even on a bar where a
// genuine CHoCH had just fired. That meant CHoCH's score contribution and
// the confluence checks could disagree with each other purely due to call
// order. These two arrays cache the real per-bar result once per (symbol,
// g_CycleCounter tick) - same pattern already used for the EMA/ADX/ATR
// indicator cache - so every consumer within one decision cycle agrees.
long CHoCH_CacheCycleArr[];
bool CHoCH_CacheResultArr[];

// NEW (this pass) - ORDER BLOCK FRESH/MITIGATED/INVALIDATED TRACKING:
// DetectBullishOrderBlock()/DetectBearishOrderBlock() only ever look at the
// last 2 candles, so by the time a caller asks about an order block a few
// bars later, the zone has already scrolled out of that window and the
// function just (correctly, but unhelpfully) returns false - there was no
// way to know a zone existed, was still untouched ("fresh"), had already
// been tapped once ("mitigated"), or had been fully closed through
// ("invalidated"). These arrays persist the single most recent bullish and
// bearish order-block zone per symbol so its state can be tracked forward
// bar by bar. Only the latest zone per direction is kept (not a full
// history) - simpler, and the latest zone is what matters for scoring the
// current setup.
datetime OB_Bull_BarTimeArr[];
double   OB_Bull_TopArr[];
double   OB_Bull_BottomArr[];
bool     OB_Bull_ActiveArr[];
bool     OB_Bull_MitigatedArr[];

datetime OB_Bear_BarTimeArr[];
double   OB_Bear_TopArr[];
double   OB_Bear_BottomArr[];
bool     OB_Bear_ActiveArr[];
bool     OB_Bear_MitigatedArr[];

datetime OB_LastProcessedBarTimeArr[]; // gates UpdateOrderBlockTracking() to run once per newly closed bar per symbol

// NEW (this pass) - FVG MITIGATION TRACKING: same idea as the order-block
// tracking above. GetBullishFVGQualityScore()/GetBearishFVGQualityScore()
// score a gap's size against ATR but have no idea whether that gap has
// since been partly or fully traded back into (a half-filled gap is much
// weaker supporting evidence than one price hasn't touched since it formed).
datetime FVG_Bull_BarTimeArr[];
double   FVG_Bull_TopArr[];
double   FVG_Bull_BottomArr[];
bool     FVG_Bull_ActiveArr[];
double   FVG_Bull_FilledPctArr[];

datetime FVG_Bear_BarTimeArr[];
double   FVG_Bear_TopArr[];
double   FVG_Bear_BottomArr[];
bool     FVG_Bear_ActiveArr[];
double   FVG_Bear_FilledPctArr[];

datetime FVG_LastProcessedBarTimeArr[]; // gates UpdateFVGTracking() to run once per newly closed bar per symbol

// PERFORMANCE (this pass): GetRecentHigh()/GetRecentLow() at EntryTF are
// called many times per decision cycle (BOS, liquidity sweep, equal-highs/
// lows, FVG-adjacent checks, fake-breakout trap, premium/discount,
// displacement, dynamic S/R...) and each call re-scans a StructureLookback
// x SwingBars nested loop from scratch. Cached once per (symbol,
// g_CycleCounter tick) - same pattern as the CHoCH cache above - so a
// whole decision cycle pays for that scan once instead of 5-10 times. Only
// covers the EntryTF (PERIOD_CURRENT/default) case, which is the hot path;
// explicit-timeframe calls (HTF confluence) are infrequent enough not to
// need caching.
long   SwingHighCacheCycleArr[];
double SwingHighCacheArr[];
long   SwingLowCacheCycleArr[];
double SwingLowCacheArr[];

// PERFORMANCE (this pass): DetectBOS() re-derives the swing levels and
// re-reads closes on every call; it's called from CalculateTradeScore(),
// HasStructureConfluence(), diagnostics, and the signal snapshot capture -
// several times per cycle. Same per-cycle cache pattern.
long BOS_CacheCycleArr[];
bool BOS_CacheResultArr[];

// DUPLICATE SIGNAL FILTER (this pass): CooldownFinished() only throttles by
// elapsed TIME since the last FILLED trade - it says nothing about whether
// the CURRENT signal is the same one that already fired earlier on this
// same bar. With EnableTickLevelSignalDetection on (default), every tick
// re-runs EvaluateStrategySignals(); if TradeCooldownMinutes is short (or
// zero) relative to the bar period, the same underlying setup could in
// principle trigger more than one entry attempt before the bar closes.
// These record the bar time of the last APPROVED (score passed) signal per
// direction per symbol, independent of cooldown minutes, so a second
// approval on the same still-forming bar is recognized as a duplicate of
// the one just acted on rather than a fresh opportunity.
datetime LastApprovedBuyBarTimeArr[];
datetime LastApprovedSellBarTimeArr[];

// MARKET REGIME HYSTERESIS (this pass): a raw ADX-vs-threshold read flips
// REGIME_TRENDING/REGIME_RANGING back and forth on every bar where ADX is
// hovering near RegimeADXThreshold - "switching accuracy" in the literal
// sense the request asks about. Persists the last confirmed regime per
// symbol and only allows a flip once ADX clears the threshold by a buffer
// band, so borderline noise doesn't relabel the regime every bar.
int      RegimeLastStateArr[]; // stores MarketRegime as int, -1 = not yet set

void PrintStrategyPerformanceReport(); // full upgrade: print on init
int  PathBasePriority(const string tag);
int  PathQualityRankScore(const string tag, const bool buy);

// CopyBuffer() every single call - unlike GetEMA()/GetADX()/GetATR(),
// which already cache once per (symbol, trading cycle) via
// IndicatorCacheCycleArr. The mean-reversion functions that used these are
// no longer reachable (legacy strategy modes removed - PRISM is the only
// strategy now), but the cache is harmless to keep in case they're ever
// re-enabled. Same caching pattern as above.
long   RSI_CacheCycleArr[];
double RSI_CacheValueArr[];
long   BB_CacheCycleArr[];
double BB_CacheUpperArr[];
double BB_CacheLowerArr[];
double BB_CacheMidArr[];

// Buffers

double EMABuffer[];
double ADXBuffer[];
double ATRBuffer[];
double HTF_EMABuffer[];

//======================== INIT =====================================//


// --- OK93 early decls for modular includes ---
input bool EnableMultiSymbolTrading = false;
input int  MultiSymbolTimerSeconds  = 15;
input bool EnableDashboard = true;   // OK93 modular: early decl for Dashboard module
input int DashboardRefreshMillis = 1000;
int GetSymbolIndex(string symbol);

#endif
