//+------------------------------------------------------------------+
//| SNIPER_AI.mq5 — compatibility loader → HITMAN AI                 |
//| BUILD_ID: HA_ULTRA_93                                             |
//| Use HITMAN_AI.mq5 (single-file) for MetaEditor F7.                |
//+------------------------------------------------------------------+
#property copyright "HITMAN AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "HITMAN AI loader (legacy SNIPER_AI filename)"
#property description "BUILD=HA_ULTRA_93 Comment=HITMAN AI MaxOpen=3"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "HitmanAI_ChartBackground"

CTrade trade;

#include <HITMAN_ULTRA/Shell_A_InputsGlobals.mqh>
#include <HITMAN_ULTRA/HITMAN_ULTRA.mqh>
#include <HITMAN_ULTRA/Shell_B_TradeSystem.mqh>
