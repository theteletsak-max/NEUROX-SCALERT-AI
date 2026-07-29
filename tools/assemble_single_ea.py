#!/usr/bin/env python3
from pathlib import Path
root = Path("MQL5/Include/SNIPER_ULTRA")
order = [
    "Shell_A_InputsGlobals.mqh","00_Types.mqh","31_Inputs.mqh","28_Utilities.mqh",
    "27_Logger.mqh","30_Recovery.mqh","01_Core.mqh","02_Data.mqh","11_Volatility.mqh",
    "03_MarketStructure.mqh","04_BOS.mqh","05_CHoCH.mqh","06_Liquidity.mqh",
    "08_Institutional.mqh","07_Fibonacci.mqh","09_Trend.mqh","10_Momentum.mqh",
    "12_MarketRegime.mqh","18_NewsIntelligence.mqh","17_SessionIntelligence.mqh",
    "13_Precision.mqh","14_Probability.mqh","15_Confluence.mqh","26_Diagnostics.mqh",
    "29_MarketMemory.mqh","20_CapitalProtection.mqh","19_Execution.mqh","16_AI_Core.mqh",
    "21_TradeManagement.mqh","22_MultiSymbol.mqh","23_MultiTimeframe.mqh",
    "25_Statistics.mqh","24_Dashboard.mqh","Shell_B_TradeSystem.mqh",
]
header = '''//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_ULTRA_93                                             |
//| SNIPER AI ULTRA v1 BLUEPRINT — SINGLE-FILE EA                     |
//| Comment: SNIPER AI | MaxOpen=3                                    |
//| Auto-assembled from Include/SNIPER_ULTRA modules 00-31 + Shells   |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "SNIPER AI ULTRA v1 BLUEPRINT single-file EA"
#property description "BUILD=SA_ULTRA_93 Comment=SNIPER AI MaxOpen=3"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "SniperCoreAI_ChartBackground"

CTrade trade;

//==================== SINGLE-FILE v1 BLUEPRINT =====================//
'''
parts = [header]
for name in order:
    text = (root / name).read_text(encoding="utf-8", errors="replace")
    lines = []
    for line in text.splitlines(True):
        s = line.strip()
        if s.startswith("#include"):
            if s.startswith("#include <") and "SNIPER_ULTRA" not in s and '"' not in s:
                lines.append(line)
            continue
        lines.append(line)
    parts.append(f"\n//===== BEGIN {name} =====\n")
    parts.append("".join(lines))
    if not parts[-1].endswith("\n"):
        parts.append("\n")
    parts.append(f"//===== END {name} =====\n")
out = "".join(parts)
for dest in [Path("SNIPER_AI.mq5"), Path("SNIPER_AI_OK93.mq5"),
             Path("release/deliver/SNIPER_AI.mq5"), Path("release/deliver/SNIPER_AI_OK93.mq5")]:
    dest.write_text(out, encoding="utf-8")
    print(dest, dest.stat().st_size)
