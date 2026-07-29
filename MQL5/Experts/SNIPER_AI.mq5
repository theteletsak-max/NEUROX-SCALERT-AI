//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_ULTRA_93                                             |
//| SNIPER AI ULTRA — ULTIMATE PROFESSIONAL STRUCTURE (00-40)         |
//| Comment: SNIPER AI | MaxOpen=3                                    |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "9.31"
#property description "SNIPER AI ULTRA ultimate professional Include/SNIPER_ULTRA 00-40"
#property description "BUILD=SA_ULTRA_93"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "SniperCoreAI_ChartBackground"

CTrade trade;

//==================== ULTIMATE MODULE LOAD ORDER ===================//
// Shell A → SNIPER_ULTRA (00-40) → Shell B
//===================================================================//

#include <SNIPER_ULTRA/Shell_A_InputsGlobals.mqh>
#include <SNIPER_ULTRA/SNIPER_ULTRA.mqh>
#include <SNIPER_ULTRA/Shell_B_TradeSystem.mqh>

// Event handlers live in Shell_B (OnInit/OnTick/OnTimer/OnDeinit/...).
