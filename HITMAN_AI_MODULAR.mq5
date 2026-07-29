//+------------------------------------------------------------------+
//| HITMAN_AI.mq5 (modular loader)                                    |
//| BUILD_ID: HA_ULTRA_93                                             |
//| HITMAN AI — MASTER + UFSE + DEFENSE LINE ENGINE v1.0              |
//| Comment: HITMAN AI | MaxOpen=3                                    |
//+------------------------------------------------------------------+
#property copyright "HITMAN AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "HITMAN AI MASTER + UFSE + Defense Line Engine v1.0"
#property description "BUILD=HA_ULTRA_93"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "HitmanAI_ChartBackground"

CTrade trade;

#include <HITMAN_ULTRA/Shell_A_InputsGlobals.mqh>
#include <HITMAN_ULTRA/HITMAN_ULTRA.mqh>
#include <HITMAN_ULTRA/Shell_B_TradeSystem.mqh>
