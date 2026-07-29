//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_ULTRA_94                                             |
//| SNIPER AI ULTRA — ULTIMATE PROJECT STRUCTURE (00-30)              |
//| Comment: SNIPER AI | MaxOpen=3                                    |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "9.40"
#property description "SNIPER AI ULTRA ultimate modular structure 00-30"
#property description "Include/SNIPER_AI_ULTRA. BUILD=SA_ULTRA_94"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "SniperCoreAI_ChartBackground"

CTrade trade;

//==================== ULTIMATE MODULE LOAD ORDER ===================//
// Shell A → SNIPER_AI_ULTRA (00-30) → Shell B
//===================================================================//

#include <SNIPER_AI_ULTRA/Shell_A_InputsGlobals.mqh>
#include <SNIPER_AI_ULTRA/SNIPER_AI_ULTRA.mqh>
#include <SNIPER_AI_ULTRA/Shell_B_TradeSystem.mqh>

// Event handlers: OnInit/OnTick/OnTimer/OnDeinit live in Shell_B.
