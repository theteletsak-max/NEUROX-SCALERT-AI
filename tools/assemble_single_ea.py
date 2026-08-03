#!/usr/bin/env python3
from pathlib import Path
root = Path("MQL5/Include/HITMAN_ULTRA")
order = [
    "Shell_A_InputsGlobals.mqh","00_Types.mqh","31_Inputs.mqh","28_Utilities.mqh",
    "27_Logger.mqh","30_Recovery.mqh","01_Core.mqh","UltraFoundation.mqh",
    "UltraBacktestCompat.mqh",
    "02_Data.mqh","11_Volatility.mqh",
    "03_MarketStructure.mqh","04_BOS.mqh","05_CHoCH.mqh","06_Liquidity.mqh",
    "07_Fibonacci.mqh","08_Institutional.mqh","09_Trend.mqh","10_Momentum.mqh",
    "12_MarketRegime.mqh","MarketCycle.mqh",
    "18_NewsIntelligence.mqh","17_SessionIntelligence.mqh",
    "13_Precision.mqh","14_Probability.mqh","15_Confluence.mqh","26_Diagnostics.mqh",
    "29_MarketMemory.mqh","39_EventEngine.mqh",
    "UltraMarketIntelligence.mqh",
    "20_CapitalProtection.mqh","19_Execution.mqh",
    "UltraMarketInput.mqh",
    "23_MultiTimeframe.mqh",
    "16_AI_Core.mqh",
    "DefenseLineEngine.mqh",
    "TradeEntryDiscipline.mqh",
    "DynamicWeights.mqh","UltraScoringMachine2.mqh","SignalEvolution.mqh",
    "TradeThesis.mqh","CorrectionDetector.mqh","HoldScore.mqh",
    "SmartExit.mqh","PositionEvolution.mqh","SystemHealth.mqh","MasterAIBrain.mqh","SupremeCommand.mqh",
    "UltraValidationChain.mqh",
    "UltraNewsExecution.mqh",
    "UltraTargetIntelligence.mqh",
    "UltraAdaptiveIntelligence.mqh",
    "MissionControl.mqh",
    "UltraBugElimination.mqh",
    "UltraStopEvolution.mqh",
    "UltraMaintenance.mqh",
    "UltraLowLatency.mqh",
    "UltraZeroFailRecovery.mqh",
    "UltraTradeGate.mqh",
    "UltraQualityAssurance.mqh",
    "UltraModuleManager.mqh",
    "UFSE_FastSignalEngine.mqh",
    "21_TradeManagement.mqh","22_MultiSymbol.mqh",
    "25_Statistics.mqh","37_Optimization.mqh","24_Dashboard.mqh",
    "32_BrokerCompatibility.mqh","36_BrokerHealth.mqh","33_OrderManagement.mqh",
    "34_PositionManagement.mqh","35_SignalEngine.mqh",
    "38_Backtesting.mqh","40_DebugTools.mqh",
    "Shell_B_TradeSystem.mqh",
]
header = '''//+------------------------------------------------------------------+
//| HITMAN_AI.mq5                                                     |
//| BUILD_ID: HA_ULTRA_93                                             |
//| HITMAN AI — MASTER + ULTRA FAST SIGNAL ENGINE v1.0                |
//| Comment: HITMAN AI | MaxOpen=3 | EntryTF follows chart            |
//+------------------------------------------------------------------+
#property copyright "HITMAN AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "HITMAN AI ULTRA X — Full Architecture Blueprint"
#property description "BUILD=HA_ULTRA_93 Comment=HITMAN AI MaxOpen=3"

#include <Trade/Trade.mqh>

#define BG_OBJECT_NAME "HitmanAI_ChartBackground"

// Hitman chart watermark — same resource name as classic HITMAN_AI.mq5
// Place chart_background.bmp in Data Folder MQL5/Images before compile
#resource "\\\\Images\\\\chart_background.bmp"

CTrade g_Trade;

//==================== HITMAN AI — SINGLE-FILE MASTER =================//
'''
parts = [header]
for name in order:
    text = (root / name).read_text(encoding="utf-8", errors="replace")
    lines = []
    for line in text.splitlines(True):
        s = line.strip()
        if s.startswith("#include"):
            if s.startswith("#include <") and "HITMAN_ULTRA" not in s and "SNIPER_ULTRA" not in s and '"' not in s:
                lines.append(line)
            continue
        lines.append(line)
    parts.append(f"\n//===== BEGIN {name} =====\n")
    parts.append("".join(lines))
    if not parts[-1].endswith("\n"):
        parts.append("\n")
    parts.append(f"//===== END {name} =====\n")
out = "".join(parts)
for dest in [Path("HITMAN_AI.mq5"), Path("HITMAN_AI_OK93.mq5"), Path("Experts_HITMAN_AI.mq5"),
             Path("release/deliver/HITMAN_AI.mq5"), Path("release/deliver/HITMAN_AI_OK93.mq5"),
             Path("release/deliver/HITMAN_AI_EA/MQL5/Experts/HITMAN_AI.mq5")]:
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(out, encoding="utf-8")
    print(dest, dest.stat().st_size)
