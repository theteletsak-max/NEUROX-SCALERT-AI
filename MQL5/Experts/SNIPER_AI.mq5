//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_ULTRA_93                                             |
//| SNIPER AI ULTRA — MODULAR PROFESSIONAL ARCHITECTURE               |
//| Comment: SNIPER AI | MaxOpen=3                                    |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "9.30"
#property description "SNIPER AI ULTRA modular architecture (Include/SNIPER_ULTRA)"
#property description "Modules 01-09 + Shell. BUILD=SA_ULTRA_93"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "SniperCoreAI_ChartBackground"

CTrade trade;

//======================== MODULE LOAD ORDER ========================//
// Shell A : classic inputs/globals/forwards (Magic, MaxOpen, TP...)
// Ultra   : Types → Inputs → Core → MTF → Market → Diag → Capital →
//           Execution → AI → MultiSymbol → Dashboard
// Shell B : ExecuteBuy/Sell, ManageOpenTrades, OnTick/OnTimer, ...
//===================================================================//

#include <SNIPER_ULTRA/Shell_A_InputsGlobals.mqh>
#include <SNIPER_ULTRA/SNIPER_ULTRA.mqh>
#include <SNIPER_ULTRA/Shell_B_TradeSystem.mqh>

// Event handlers live in Shell_B (OnInit/OnTick/OnTimer/OnDeinit/...).
