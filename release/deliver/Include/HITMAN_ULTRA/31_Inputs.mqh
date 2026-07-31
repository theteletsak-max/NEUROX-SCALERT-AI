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
input int    UltraSessionTZOverride      = -99;    // London GMT offset override (−99=auto)
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
