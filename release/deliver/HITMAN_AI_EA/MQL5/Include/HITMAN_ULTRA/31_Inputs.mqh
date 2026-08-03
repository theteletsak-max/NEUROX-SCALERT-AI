#ifndef HITMAN_ULTRA_31_INPUTS_MQH
#define HITMAN_ULTRA_31_INPUTS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 31_INPUTS                                       |
//| Trading · Risk · Dashboard · Strategy · Session · News ·          |
//| Execution · Capital Protection                                    |
//| Shell_A still holds Magic / TradeComment / MaxOpenTrades=3        |
//+------------------------------------------------------------------+

input group "31 · TRADING INPUTS"
input bool   UltraCoreEnabled            = true;
input bool   UltraDataEngineEnabled      = true;
input bool   UltraConfigEngineEnabled    = true;
input bool   UltraValidationEnabled      = true;
input bool   UltraStateSyncEnabled       = true;
input bool   UltraTrade24x5              = true; // always allow (24/5)

input group "31 · ULTRA SYSTEM FOUNDATION ENGINE (Phase 1)"
input bool   UltraFoundationEnabled      = true;   // institutional foundation backbone
input bool   UltraFoundationHealthTick   = true;   // every-tick health path (throttled)
input int    UltraFoundationHealthMs     = 250;    // full health interval (ms)
input int    UltraFoundationMaxObjects   = 400;    // chart object runaway guard
input bool   UltraFoundationStrictConfig = true;   // enforce product locks at boot
input bool   UltraFoundationLogBoot      = true;   // boot/shutdown foundation audit

input group "31 · ULTRA MARKET INTELLIGENCE ENGINE (Phase 2)"
input bool   UltraMarketIntelEnabled         = true;   // verified data gate before analysis
input int    UltraMarketIntelIntervalMs      = 100;    // full validation throttle (ms)
input bool   UltraMarketIntelLog             = true;   // MARKET_INTEL audit lines
input bool   UltraMarketIntelAutoRecover     = true;   // recover on hard REJECT
input bool   UltraMarketIntelRejectWeekend   = false;  // soft flag; hard only if session closed
input bool   UltraMarketIntelRejectHoliday   = true;   // no analysis when trade mode closed
input bool   UltraMarketIntelRejectBadGaps   = false;  // hard-reject extreme gaps (soft default)
input bool   UltraMarketIntelStrictIndicators= false;  // hard-reject broken handles
input double UltraMarketIntelSpreadWarnPts   = 50.0;   // wide-spread DEGRADED only — never sole reject
input double UltraMarketIntelMinTickSpeed    = 0.0;    // soft warn floor (0=off)
input double UltraMarketIntelMaxJumpATR      = 3.5;    // tick jump soft flag vs ATR
input double UltraMarketIntelGapATR          = 1.25;   // gap vs ATR threshold
input int    UltraMarketIntelMaxGaps         = 3;      // soft gap count in sample
input int    UltraMarketIntelMaxQuoteAgeSec  = 120;    // hard stale-quote reject (0=off)
input double UltraMarketIntelLiqSpreadATR    = 0.35;   // spread/ATR liquidity soft flag
input double UltraMarketIntelHighVolRel      = 1.80;   // HIGH_VOLATILITY classifier
input double UltraMarketIntelLowVolRel       = 0.55;   // LOW_VOLATILITY classifier
input double UltraMarketIntelExpandRel       = 1.35;   // EXPANSION classifier
input double UltraMarketIntelCompressRel     = 0.70;   // COMPRESSION classifier

input group "31 · ULTRA VALIDATION CHAIN"
input bool   UltraVChainEnabled              = true;   // VALID / INVALID / WAIT gate
input bool   UltraVChainLog                  = true;   // VCHAIN audit lines
input bool   UltraVChainStrictStructure      = false;  // structure undecided = WAIT (critical)
input bool   UltraVChainBlockOnInvalid       = true;   // critical INVALID stops decision
input bool   UltraVChainBlockOnWait          = true;   // critical WAIT stops decision (no guessing)

input group "31 · STRATEGY INPUTS"
input bool   UltraEnable_FlashSweep      = true;
input bool   UltraEnable_ContSniper      = true;
input bool   UltraEnable_RevSniper       = true;
input bool   UltraEnable_FibSniper       = true;
input bool   UltraEnable_BreakImpulse    = true;
input bool   UltraEnable_InstZone        = true;
input int    UltraSwingStrength          = 2;
input int    UltraStructLookback         = 48;
input int    UltraBOS_ConfirmBars        = 14;
input int    UltraSweepLookback          = 24;
input double UltraEqualTolATR            = 0.12;
input double UltraSweepWickMin           = 0.35;  // ROADMAP P5 — ignore shallow fake wicks
input double UltraSweepDepthATR          = 0.08;
input double UltraDispBodyMin            = 0.55;  // ROADMAP P6/P7 — institutional displacement
input double UltraDispATRMin             = 0.40;
input double UltraFVG_MinATR             = 0.18;  // ROADMAP P7 — ignore weak gaps
input int    UltraLiqMinQuality          = 55;    // genuine sweep quality floor
input int    UltraMasterHysteresisBars   = 2;     // ROADMAP P4/P10 — no master flicker
input double UltraVolExpandMult          = 1.20;
input int    UltraMomentumBars           = 3;
input double UltraFibBuyLow              = 0.50;
input double UltraFibBuyHigh             = 0.886;
input double UltraFibSellLow             = 0.114;
input double UltraFibSellHigh            = 0.50;
input bool   UltraSoftPreferFib          = true;
input double UltraFibExt127              = 1.272;
input double UltraFibExt161              = 1.618;
input int    UltraMinConfluence          = 45;   // Live floor (InstantQuality softens further)
input int    UltraInstantFireConf        = 58;
input int    UltraMinPrecision           = 38;
input int    UltraMinProbability         = 38;
input bool   UltraBlockOppositeSameSym   = true;

input group "31 · RISK INPUTS"
input bool   UltraErrorHandlingEnabled   = true;
input bool   UltraPerfEngineEnabled      = true;
input bool   UltraMemoryEngineEnabled    = true;
input bool   UltraLoggingEnabled         = true;
input bool   UltraRecoveryEnabled        = true;

input group "31 · SESSION INPUTS (context only — NEVER blocks)"
input bool   UltraSessionIntelEnabled    = true;
input bool   UltraBoostKillZone          = true;

input group "31 · ULTRA SESSION INTELLIGENCE ENGINE ∞ (Phase 16.5)"
input bool   UltraSessionEngineEnabled   = true;   // institutional session awareness
input bool   UltraSessionAlwaysActive    = true;   // EA active 24/7 — no session block
input bool   UltraSessionAutoDST         = true;   // auto London DST (GMT↔BST)
input int    UltraSessionTZOverride      = -99;    // London GMT offset override (-99=auto)
input bool   UltraSessionBoostOpen       = true;   // London Open / Overlap can raise confidence
input bool   UltraSessionPenalizeWeakLiq = true;   // weak liquidity can lower confidence
input int    UltraSessionMaxBoost        = 12;     // max confidence boost from session
input int    UltraSessionMaxPenalty      = 8;      // max confidence penalty from weak session
input bool   UltraSessionLog             = false;  // optional session audit log

input group "31 · NEWS INPUTS (context only — NEVER blocks)"
input bool   UltraNewsIntelEnabled       = true;
input bool   UltraBoostNewsVol           = true;

input group "31 · ULTRA EVENT TRADING ENGINE ∞ (Phase 16)"
input bool   UltraEventEngineEnabled     = true;   // institutional event path
input bool   UltraEventAlwaysActive      = true;   // never news shutdown
input bool   UltraEventNeverSpreadBlock  = true;   // never reject solely for elevated spread
input bool   UltraEventNeverNewsBlock    = true;   // never reject solely because news is on
input bool   UltraEventForceTrade        = false;  // never force a trade because of news
input int    UltraEventMinConf           = 55;     // min confidence during active event
input int    UltraEventExecQualityMin    = 40;     // min exec quality during event (soft)
input double UltraEventSpreadWarnPts     = 40.0;   // warn/log only — not a hard block
input bool   UltraEventLogDecisions      = true;   // EVENT audit log lines

input group "31 · PHASE 23 ULTRA NEWS EXECUTION PROTOCOL ∞"
input bool   UltraNewsExecEnabled        = true;   // news mode + full validation path
input bool   UltraNewsExecLog            = true;   // NEWS_MODE / NEWS_FIRE / NEWS_FILL logs
input bool   UltraNewsExecInstantPath    = true;   // instant tick path during news mode
input bool   UltraNewsExecForceReanalyze = true;   // complete re-analysis before event trade
input bool   UltraNewsExecRequireVChain  = true;   // Mission-ready validation chain required
input bool   UltraNewsExecAutoRecover    = true;   // exec/fill recovery under news mode
input bool   UltraNewsExecPhase23Boost   = true;   // raise monitor/exec priority in News Mode
input int    UltraNewsExecMonitorMs      = 50;     // market monitoring interval (news mode)
input int    UltraNewsExecValidateMs     = 50;     // signal validation cadence (news mode)
input int    UltraNewsExecExecMonMs      = 50;     // execution monitoring interval
input int    UltraNewsExecReanalyzeMs    = 0;      // 0 = every event decision rebuilds
input int    UltraNewsExecMinConf        = 55;     // confidence floor during news (never reduced)
input double UltraNewsExecHighVolRel     = 1.45;   // high-volatility news-mode trigger
input bool   UltraNewsExecProtocolEnabled = true;  // prepare→submit→verify→retry protocol
input bool   UltraNewsExecProtocolFastRetry = true; // minimize Sleep under InstantPath
input int    UltraNewsExecProtocolRetryMs = 20;    // fast retry pause (ms); 0 = none
input bool   UltraNewsExecUseCalendarContext = true;  // wire MQL5 calendar into news context
input bool   UltraNewsExecRequireStability = true;    // Phase 2 market stabilization before entry
input int    UltraNewsExecMinStabilityScore = 60;     // 0..100 combined stability floor
input int    UltraNewsExecMaxPacketAgeMs = 250;       // stale prepared packet → refresh/cancel
input bool   UltraNewsExecLogActualSlippage = true;   // fill vs prepared quote slippage
input bool   UltraNewsExecStrongerOnWeakExec = true;  // weak execQ needs stronger setup

input group "31 · ULTRA TARGET INTELLIGENCE ENGINE ∞"
input bool   UltraTargetEnabled          = true;   // institutional TP/SL intelligence
input bool   UltraTargetLog              = true;   // log every target reason
input bool   UltraTargetStrict           = false;  // true = block trade if target build fails
input bool   UltraTargetEnableTP3        = true;   // arm TP3 only when thesis exceptional
input double UltraTargetSLATR            = 2.0;    // ATR multiplier for stop floor
input double UltraTargetMinSLATR         = 0.60;   // min structure SL distance (ATR)
input double UltraTargetMaxSLATR         = 3.50;   // max structure SL distance (ATR)
input double UltraTargetStructBufferATR  = 0.10;   // buffer beyond structure
input double UltraTargetMinRR1           = 1.50;   // TP1 minimum R:R floor
input double UltraTargetMinRR2           = 2.50;   // TP2 minimum R:R floor
input double UltraTargetMinRR3           = 4.00;   // TP3 minimum R:R floor
input double UltraTargetTP1MaxRR         = 2.00;   // TP1 conservative cap (R)
input int    UltraTargetTP3MinConf       = 62;     // min confidence to arm TP3
input int    UltraTargetTP3MinTrend      = 60;     // min trend strength to arm TP3

input group "31 · ULTRA TRADE GATE (ANY FAIL = NO TRADE)"
input bool   UltraTradeGateEnabled       = true;   // hard pre-trade validation
input bool   UltraTradeGateLog           = true;   // TRADE_GATE PASS/FAIL logs
input bool   UltraTradeGateRequireTargets= true;   // Target Intelligence plan mandatory

input group "31 · ULTRA PERF ANALYTICS / ADAPTIVE ∞ (Final Order P13 · was P18)"
input bool   UltraAdaptiveEnabled           = true;  // master — decision quality only
input bool   UltraAdaptiveLog               = true;  // ADAPTIVE audit / record logs
input bool   UltraAdaptiveConfEnabled       = true;  // soft confidence bias
input bool   UltraAdaptiveRiskEnabled       = true;  // soft risk scale (clamped)
input bool   UltraAdaptiveExecEnabled       = true;  // soft slippage bias
input bool   UltraAdaptiveTargetEnabled     = true;  // soft TP distance scale
input bool   UltraAdaptiveMonitorEnabled    = true;  // soft monitor cadence
input bool   UltraAdaptivePosEnabled        = true;  // soft position intelligence
input bool   UltraAdaptiveExitEnabled       = true;  // soft exit urgency (never auto-close)
input bool   UltraAdaptiveReanalyzeEnabled  = true;  // continuous re-analysis
input bool   UltraAdaptiveSelfReviewEnabled = true;  // post-trade self analysis
input bool   UltraAdaptiveAnalyticsEnabled  = true;  // record + review stats
input bool   UltraAdaptiveLearnEnabled      = true;  // statistical soft nudge only
input int    UltraAdaptiveMaxConfBoost      = 6;     // max soft confidence boost
input int    UltraAdaptiveMaxConfPenalty    = 6;     // max soft confidence penalty
input int    UltraAdaptiveMaxPosHoldBias    = 6;     // max soft hold-score bias
input int    UltraAdaptiveExitUrgencyManage = 55;    // urg≥ → soft HOLD→MANAGE only
input int    UltraAdaptiveMinTradesLearn    = 8;     // min closed trades before hist nudge
input int    UltraAdaptiveReanalyzeMs       = 250;   // continuous re-analysis throttle
input double UltraAdaptiveRiskMinScale      = 0.85;  // floor risk multiplier
input double UltraAdaptiveRiskMaxScale      = 1.15;  // ceiling risk multiplier
input double UltraAdaptiveTargetMinScale    = 0.90;  // floor TP scale
input double UltraAdaptiveTargetMaxScale    = 1.12;  // ceiling TP scale
input int    UltraAdaptiveSlipExtraPts      = 8;     // extra deviation under weak exec
input int    UltraAdaptiveSlipTightenPts    = 4;     // tighten deviation under strong exec
input int    UltraAdaptiveMonitorTightenMs  = 15;    // reduce monitor interval
input int    UltraAdaptiveMonitorRelaxMs    = 10;    // relax monitor interval

input group "31 · ULTRA QUALITY ASSURANCE ∞ (Internal Standard v6+ P18)"
input bool   UltraQAEnabled              = true;   // consistency / integrity / conflict audit
input bool   UltraQALog                  = true;   // log QA FAIL lines

input group "31 · ULTRA MAINTENANCE / BUG ELIMINATION ∞ (Internal Standard v6+ P19)"
input bool   UltraBugEnabled             = true;   // master — stability / explain path
input bool   UltraBugLogBoot             = true;   // boot / deinit audit lines
input bool   UltraBugLogExplain          = true;   // structured ULTRA EXPLAIN blocks
input bool   UltraBugSignalAudit         = true;   // duplicate/conflict/invalid conf
input bool   UltraBugExecAudit           = true;   // retcode / stops / volume explain
input bool   UltraBugPositionAudit       = true;   // SL sync / Mission lock sync
input bool   UltraBugBrokerAudit         = true;   // symbol specs / account mode
input bool   UltraBugEventAudit          = true;   // news/session consistency
input bool   UltraBugPerfAudit           = true;   // tick latency warn
input int    UltraBugPositionAuditMs     = 1000;   // position sync cadence
input int    UltraBugPerfWarnMs          = 50;     // tick latency warn threshold
input bool   UltraMaintenanceEnabled     = true;   // P19 — orchestrates Bug+resources

input group "31 · ULTRA STOP EVOLUTION ∞ (profit protect)"
input bool   UltraStopEvoEnabled         = true;   // master — intelligent SL evolution
input bool   UltraStopEvoLog             = true;   // STOP EVO modify logs
input bool   UltraStopEvoLogBoot         = true;   // boot line
input bool   UltraStopEvoBreakEven       = true;   // L2 optional BE
input bool   UltraStopEvoRequireTrend    = true;   // trend must still agree
input bool   UltraStopEvoRequireHealthy  = true;   // block tighten on EXIT/weak hold
input bool   UltraStopEvoL5GiveRoom      = true;   // exceptional profit — wider trail
input double UltraStopEvoRiskATR         = 1.0;    // fallback R unit when no initial SL
input double UltraStopEvoL2R             = 0.80;   // moderate → BE
input double UltraStopEvoL3R             = 1.50;   // strong → lock partial
input double UltraStopEvoL4R             = 2.50;   // large → dynamic trail
input double UltraStopEvoL5R             = 4.00;   // exceptional → wide protect
input double UltraStopEvoL3LockFrac      = 0.35;   // lock fraction of MFE at L3
input double UltraStopEvoL5LockFrac      = 0.55;   // floor lock fraction at L5
input double UltraStopEvoL4TrailATR      = 1.20;   // L4 trail distance (ATR)
input double UltraStopEvoL5TrailATR      = 1.80;   // L5 wider trail (ATR)
input double UltraStopEvoBufferATR       = 0.08;   // buffer under lock
input int    UltraStopEvoMinBars         = 2;      // never one-candle tighten
input int    UltraStopEvoConfirmBars     = 2;      // level must persist
input int    UltraStopEvoMinModifySec    = 3;      // modify throttle
input int    UltraStopEvoMaxRetry        = 2;      // verify retry count
input int    UltraStopEvoRetryMs         = 50;     // retry pause
input int    UltraStopEvoMinHoldScore    = 30;     // below → give room (no tighten)
input int    UltraStopEvoL5HoldSkip      = 70;     // strong hold → prefer wide L5 trail

input group "31 · ULTRA LOW-LATENCY ARCHITECTURE ∞ (perf only)"
input bool   UltraLowLatencyEnabled         = true;  // master — tick budget / early skip
input bool   UltraLowLatencyEarlySmartTick  = true;  // skip news/market prelude when price unchanged
input bool   UltraLowLatencySkipHeavy       = true;  // cadence Adaptive/Bug/Maint only
input int    UltraLowLatencyHeavyMs         = 50;    // min ms between heavy analytics passes
input bool   UltraLowLatencyLogBoot         = true;  // boot summary line
input bool   UltraPerfOneAnalysisPerCycle   = true;  // one market analysis / score / decision per cycle
input bool   UltraPerfCacheConfluence       = true;  // compute buy/sell confluence once per PickBest
input bool   UltraPerfReuseVChain           = true;  // reuse VChain base within same tick for Mission
input bool   UltraPerfSkipDupMarketPrelude  = true;  // skip AnalyzeLiveMarket when snap already fresh

input group "31 · ULTRA ZERO-FAIL RECOVERY ENGINE ∞ (Final Order P16)"
input bool   UltraZFREnabled             = true;   // master — never stop on recoverable faults
input bool   UltraZFRLog                 = true;   // recovery action logs
input bool   UltraZFRConnectionRecovery  = true;
input bool   UltraZFRIndicatorRecovery   = true;
input bool   UltraZFRBufferRecovery      = true;
input bool   UltraZFRMemoryRecovery      = true;
input bool   UltraZFRPositionRecovery    = true;
input bool   UltraZFRExecRecovery        = true;
input bool   UltraZFRSymbolRecovery      = true;
input bool   UltraZFRTimeframeRecovery   = true;
input bool   UltraZFRSessionRecovery     = true;
input bool   UltraZFREventRecovery       = true;
input bool   UltraZFRDashboardRecovery   = true;
input bool   UltraZFRLoggerRecovery      = true;
input int    UltraZFRMonitorMs           = 200;    // system verify cadence
input int    UltraZFRRetryBackoffMs      = 250;    // backoff after failed recover
input int    UltraZFRPositionMs          = 1000;   // position sync cadence
input int    UltraZFRDashboardMs         = 5000;   // dashboard/object check cadence

input group "31 · ULTRA BACKTEST COMPATIBILITY ENGINE ∞"
input bool   UltraBacktestCompatEnabled  = true;   // Strategy Tester compatibility mode
input bool   UltraBacktestLogBoot        = true;   // boot mode line
input bool   UltraBacktestLogRejects     = true;   // structured TRADE REJECTED blocks
input int    UltraBacktestMinBars        = 60;     // historical bars required

input group "31 · EXECUTION INPUTS"
input bool   UltraExecQualityEnabled     = true;
input ENUM_TIMEFRAMES UltraTF_Bias       = PERIOD_H4;
input ENUM_TIMEFRAMES UltraTF_Macro      = PERIOD_D1;
input ENUM_TIMEFRAMES UltraTF_Week       = PERIOD_W1;
input ENUM_TIMEFRAMES UltraTF_Month      = PERIOD_MN1;
input bool   UltraUseMTFVoting           = true;
input bool   UltraUseM30                 = true;
input bool   UltraUseM15                 = true;
input bool   UltraUseM5                  = true;
input bool   UltraUseM1Optional          = false;

input group "31 · CAPITAL PROTECTION INPUTS"
input bool   UltraCapitalProtectEnabled  = true;

input group "31 · ULTRA FAST SIGNAL ENGINE v1.0"
input bool   UltraFastSignalEnabled      = true;  // event-driven cache + scanner
input bool   UltraMasterTrendLock        = true;  // LTF cannot reverse HTF master
input bool   UltraSignalLockEnabled      = true;  // block duplicates until unlock event
input bool   UltraUFSE_ExplainLog        = true;  // PASS/FAIL explain on fire/wait
input bool   UltraUFSE_EntryTriggerGate  = true;  // formal entry trigger checklist

input group "31 · DEFENSE LINE ENGINE v1.0"
input bool   UltraDefenseEnabled         = true;  // master switch — 10 defense lines
input bool   UltraDefenseStrict          = false; // true = hard gates; false = InstantQuality soft
input bool   UltraDefenseLog             = true;  // journal GREEN/YELLOW/RED explain
input bool   UltraDefenseGateEntry       = true;  // Lines 1-6 + 10 on UltraAIDecide
input bool   UltraDefenseGateExec        = true;  // Line 7 before fire
input bool   UltraDefensePosition        = true;  // Line 8 open-position protect
input bool   UltraDefenseCloseOnFlip     = false; // L8 hard-close on adverse flip (else BE only)
input bool   UltraDefenseEmergency       = true;  // Line 9 auto-recover

input group "31 · TRADE ENTRY DISCIPLINE v1.0"
input bool   UltraDisciplineEnabled      = true;  // irregular trade prevention master
input bool   UltraDisciplineStrict       = false; // true = hard 12-rule gates
input bool   UltraDisciplineLog          = true;  // journal discipline PASS/WAIT
input int    UltraDisciplineStableEvals  = 1;     // Rule #3: InstantQuality default = 1 (was 2 WAIT)
input int    UltraDisciplineMTFMinAgree  = 2;     // Rule #6: InstantQuality default = 2 of 5 (was 3)
input bool   UltraDisciplineNeedNewStruct= false; // Rule #11: require new structure after fill

input group "31 · ULTRA UPGRADE PACK (Levels 1-20)"
input bool   UltraUpgradeEnabled         = true;  // master switch for upgrade pack
input bool   UltraUpgradeStrict          = false; // soft InstantQuality-compatible
input bool   UltraUpgradeLog             = true;  // log supreme / thesis / exits
input bool   UltraSupremeEnabled         = true;  // L1/L20 Supreme Command
input bool   UltraUSM2Enabled            = true;  // L4 Ultra Scoring Machine 2.0
input bool   UltraDynWeightsEnabled      = true;  // L5 Dynamic Weight Engine
input bool   UltraSignalEvoEnabled       = true;  // L3 Signal Evolution
input bool   UltraThesisEnabled          = true;  // L11 Trade Thesis Engine
input bool   UltraHoldScoreEnabled       = true;  // L12 Hold Score
input bool   UltraCorrectionEnabled      = true;  // L13 Correction Detector
// FIX: thesis SmartExit was closing before SL/TP — off by default.
// Trades exit via SL/TP ladder or opt-in risk nets. Re-enable deliberately.
input bool   UltraSmartExitEnabled       = false; // L14 Smart Exit
// MASTER AUDIT Phase 14: only Mission/risk/TP-manage may close.
// When true: blocks indicator/trend/session/score/defense hard-closes.
// Kept: SL/TP ladder, BE, trail, max-hold risk, emergency risk, Mission EXIT.
input bool   UltraMissionOnlyExits       = true;  // sole close path discipline
input bool   UltraSystemHealthEnabled    = true;  // L15-17 System Health

input group "31 · PHASE A DECISION FLOW AUDIT"
input bool   UltraPhaseA_MissionSoleAuthority = true; // NOTHING after Mission may flip BUY→WAIT
input bool   UltraPhaseA_LogPostMissionWarn   = true; // log demoted post-Mission gates

input group "31 · POSITION EVOLUTION ENGINE"
input bool   UltraPosEvoEnabled          = true;  // Intelligent Position Evolution
input bool   UltraPosEvoCloseOnL3        = true;  // Mission may close on L3 invalidation
input int    UltraPosEvoL3ConfirmBars    = 2;     // anti-whipsaw: L3 must persist N bars
input int    UltraPosEvoMinHoldConf      = 35;    // below → L2 MANAGE (not auto-close)
input bool   UltraPosEvoReplaceEnabled   = true;  // Ultra Reversal / Signal Replacement
input bool   UltraPosEvoReplaceNextBarOnly = true; // never same-bar flip (anti-whipsaw)
input int    UltraPosEvoReplaceMinConf   = 62;    // replacement confidence floor
input int    UltraPosEvoReplaceMinHits   = 4;     // ROADMAP P17 — high-confidence replace only
input int    UltraPosEvoReplaceMaxBars   = 5;     // expire unused replace arm

input group "31 · DASHBOARD INPUTS"
input bool   UltraDashboardEnabled       = true;
input bool   UltraDiagnosticsEnabled     = true;
input bool   UltraMarketMemoryEnabled    = true;
input bool   UltraDebugEnabled           = false;

#endif // HITMAN_ULTRA_31_INPUTS_MQH
