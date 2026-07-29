//+------------------------------------------------------------------+
//| HITMAN_AI.mq5                                                     |
//| BUILD_ID: HA_ULTRA_93                                             |
//| HITMAN EA / HITMAN AI — MASTER BLUEPRINT modules 00-40            |
//| Comment: HITMAN AI | MaxOpen=3                                    |
//+------------------------------------------------------------------+
#property copyright "HITMAN AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "HITMAN EA / HITMAN AI MASTER BLUEPRINT Include/HITMAN_ULTRA 00-40"
#property description "BUILD=HA_ULTRA_93"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "HitmanAI_ChartBackground"

CTrade trade;

#include <HITMAN_ULTRA/Shell_A_InputsGlobals.mqh>
#include <HITMAN_ULTRA/HITMAN_ULTRA.mqh>
#include <HITMAN_ULTRA/Shell_B_TradeSystem.mqh>
