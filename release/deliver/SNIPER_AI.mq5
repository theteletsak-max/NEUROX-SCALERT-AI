//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_ULTRA_93                                             |
//| SNIPER AI ULTRA v1 BLUEPRINT — modules 00-31                      |
//| Comment: SNIPER AI | MaxOpen=3                                    |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "SNIPER AI ULTRA v1 blueprint Include/SNIPER_ULTRA 00-31"
#property description "BUILD=SA_ULTRA_93"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "SniperCoreAI_ChartBackground"

CTrade trade;

//==================== v1 BLUEPRINT LOAD ORDER ======================//
// Shell A → SNIPER_ULTRA (00-31) → Shell B
// System flow: Data→Structure→BOS→CHoCH→Liq→Fib→Inst→Trend→Mom→Vol→
// Regime→Session→News→Confluence→Prob→Prec→AI→Capital→Exec→Manage
//===================================================================//

#include <SNIPER_ULTRA/Shell_A_InputsGlobals.mqh>
#include <SNIPER_ULTRA/SNIPER_ULTRA.mqh>
#include <SNIPER_ULTRA/Shell_B_TradeSystem.mqh>

// Event handlers live in Shell_B (OnInit/OnTick/OnTimer/OnDeinit/...).
