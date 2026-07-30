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
input double UltraSweepWickMin           = 0.28;
input double UltraSweepDepthATR          = 0.06;
input double UltraDispBodyMin            = 0.48;
input double UltraDispATRMin             = 0.35;
input double UltraFVG_MinATR             = 0.12;
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

input group "31 · NEWS INPUTS (context only — NEVER blocks)"
input bool   UltraNewsIntelEnabled       = true;
input bool   UltraBoostNewsVol           = true;

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
input bool   UltraSystemHealthEnabled    = true;  // L15-17 System Health

input group "31 · DASHBOARD INPUTS"
input bool   UltraDashboardEnabled       = true;
input bool   UltraDiagnosticsEnabled     = true;
input bool   UltraMarketMemoryEnabled    = true;
input bool   UltraDebugEnabled           = false;

#endif // HITMAN_ULTRA_31_INPUTS_MQH
