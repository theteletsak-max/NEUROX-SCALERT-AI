#ifndef SNIPER_ULTRA_31_INPUTS_MQH
#define SNIPER_ULTRA_31_INPUTS_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — 31_INPUTS                                       |
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
input int    UltraMinConfluence          = 62;   // Final AI confidence floor
input int    UltraInstantFireConf        = 78;
input int    UltraMinPrecision           = 55;
input int    UltraMinProbability         = 55;
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

input group "31 · DASHBOARD INPUTS"
input bool   UltraDashboardEnabled       = true;
input bool   UltraDiagnosticsEnabled     = true;
input bool   UltraMarketMemoryEnabled    = true;
input bool   UltraDebugEnabled           = false;

#endif // SNIPER_ULTRA_31_INPUTS_MQH
