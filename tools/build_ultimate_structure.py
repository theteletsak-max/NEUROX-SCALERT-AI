#!/usr/bin/env python3
"""Build SNIPER_AI_ULTRA ultimate 00-30 module structure (OK94)."""
from pathlib import Path
import re
import shutil

ROOT = Path("/workspace")
SRC = ROOT / "MQL5/Include/SNIPER_ULTRA"
DST = ROOT / "MQL5/Include/SNIPER_AI_ULTRA"
if DST.exists():
    shutil.rmtree(DST)
DST.mkdir(parents=True)

def read(name):
    return (SRC / name).read_text(encoding="utf-8", errors="replace")

def strip_guard(txt):
    txt = re.sub(r"#ifndef[^\n]+\n#define[^\n]+\n", "", txt, count=1)
    txt = re.sub(r"\n#endif\s*(//[^\n]*)?\s*$", "\n", txt)
    # strip leading banner comments block partially keep content
    return txt.strip() + "\n"

def write(name, banner, body):
    guard = "SNIPER_AI_ULTRA_" + re.sub(r"[^A-Z0-9]", "_", name.upper().replace(".MQH", "")) + "_MQH"
    content = f"""#ifndef {guard}
#define {guard}
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — {banner}
//+------------------------------------------------------------------+
{body.rstrip()}

#endif // {guard}
"""
    (DST / name).write_text(content, encoding="utf-8")
    print(f"{name:30s} {content.count(chr(10))+1:5d} lines")

def extract_funcs(src, start_pat, end_pat=None):
    """Extract from start_pat line to before end_pat (or EOF of logical)."""
    s = src.find(start_pat)
    if s < 0:
        return f"// MISSING {start_pat}\n"
    if end_pat:
        e = src.find(end_pat, s + 1)
        if e < 0:
            e = len(src)
        return src[s:e]
    return src[s:]

def func_block(src, signature):
    s = src.find(signature)
    if s < 0:
        return f"// MISSING {signature}\n"
    # find opening brace
    i = src.find("{", s)
    depth = 0
    j = i
    while j < len(src):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[s : j + 1] + "\n"
        j += 1
    return src[s:]

market = strip_guard(read("02_Market.mqh"))
ai = strip_guard(read("03_AI.mqh"))
core = strip_guard(read("01_Core.mqh"))
types = strip_guard(read("00_Types.mqh"))
inputs = strip_guard(read("10_Inputs.mqh"))
execu = strip_guard(read("04_Execution.mqh"))
cap = strip_guard(read("05_Capital.mqh"))
ms = strip_guard(read("06_MultiSymbol.mqh"))
mtf = strip_guard(read("07_MTF.mqh"))
dash = strip_guard(read("08_Dashboard.mqh"))
diag = strip_guard(read("09_Diagnostics.mqh"))

# --- 00 Types ---
write("00_Types.mqh", "00_TYPES — Enums · Structures · Shared Definitions", types)

# --- Inputs companion (not in 00-30 list but needed) ---
write("00_Inputs.mqh", "00_INPUTS — Ultra configuration inputs", inputs)

# Split core into utilities / logger / recovery / core
util_funcs = []
for sig in [
    "ENUM_TIMEFRAMES UltraETF()",
    "double UltraATR(",
    "double UltraSMA(",
    "bool UltraSwingHighAt(",
    "bool UltraSwingLowAt(",
    "bool UltraFindSwings(",
]:
    util_funcs.append(func_block(core, sig))

logger_body = func_block(core, "void UltraLog(") + func_block(core, "void UltraSetError(")
recovery_body = func_block(core, "void UltraRecover(")
core_rest = (
    func_block(core, "bool UltraConfigOK(")
    + func_block(core, "bool UltraValidateSymbol(")
    + func_block(core, "void UltraCoreInit(")
)

write(
    "28_Utilities.mqh",
    "28_UTILITIES — Helpers · Math · Time · Price",
    "// Timeframe / ATR / SMA / Swing helpers\n" + "".join(util_funcs),
)

write(
    "27_Logger.mqh",
    "27_LOGGER — Error · Trade · AI · Execution · System logs",
    logger_body
    + """
void UltraLogTrade(const string msg){ UltraLog("TRADE| " + msg); }
void UltraLogAI(const string msg){ UltraLog("AI| " + msg); }
void UltraLogExec(const string msg){ UltraLog("EXEC| " + msg); }
void UltraLogPerf(const string msg){ UltraLog("PERF| " + msg); }
""",
)

write(
    "30_Recovery.mqh",
    "30_RECOVERY — Restart · Connection · State · Position recovery",
    recovery_body
    + """
bool UltraRecovery_ConnectionOK()
{
   return (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
}

bool UltraRecovery_TerminalTradeOK()
{
   return (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
       && (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
}

void UltraRecovery_OnReconnect(const string why)
{
   if(!UltraRecovery_ConnectionOK()) return;
   UltraRecover(why);
}
""",
)

write(
    "01_Core.mqh",
    "01_CORE — Init · Loader · Config · Validation · State Controller",
    core_rest
    + """
void UltraSystemController_Boot()
{
   UltraCoreInit();
   if(!UltraConfigOK())
      UltraSetError("config validation failed at boot");
}
""",
)

write(
    "02_Data.mqh",
    "02_DATA — Tick · Candle · Symbol · Broker · Spread · Cache",
    """
struct UltraDataCache
{
   string   symbol;
   datetime barTime;
   double   bid, ask;
   double   spreadPts;
   double   atr;
   bool     valid;
};

UltraDataCache g_UltraDataCache;

bool UltraData_Refresh(const string s)
{
   g_UltraDataCache.symbol = s;
   g_UltraDataCache.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraDataCache.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   g_UltraDataCache.spreadPts = (double)SymbolInfoInteger(s, SYMBOL_SPREAD);
   g_UltraDataCache.barTime = iTime(s, UltraETF(), 0);
   g_UltraDataCache.atr = UltraATR(s, ATR_Period);
   g_UltraDataCache.valid = (g_UltraDataCache.bid > 0 && g_UltraDataCache.ask > 0);
   return g_UltraDataCache.valid;
}

double UltraData_Bid(const string s){ return SymbolInfoDouble(s, SYMBOL_BID); }
double UltraData_Ask(const string s){ return SymbolInfoDouble(s, SYMBOL_ASK); }
double UltraData_Spread(const string s){ return (double)SymbolInfoInteger(s, SYMBOL_SPREAD); }
int    UltraData_Digits(const string s){ return (int)SymbolInfoInteger(s, SYMBOL_DIGITS); }
double UltraData_Point(const string s){ return SymbolInfoDouble(s, SYMBOL_POINT); }

double UltraData_Open(const string s, const int shift){ return iOpen(s, UltraETF(), shift); }
double UltraData_High(const string s, const int shift){ return iHigh(s, UltraETF(), shift); }
double UltraData_Low(const string s, const int shift){ return iLow(s, UltraETF(), shift); }
double UltraData_Close(const string s, const int shift){ return iClose(s, UltraETF(), shift); }

bool UltraData_BrokerInfo(string &company, long &login)
{
   company = AccountInfoString(ACCOUNT_COMPANY);
   login = AccountInfoInteger(ACCOUNT_LOGIN);
   return (login != 0);
}
""",
)

# Market splits
write("03_MarketStructure.mqh", "03_MARKET_STRUCTURE — HH/HL/LH/LL · Swings · Internal/External", func_block(market, "void UltraEngStructure("))
write("04_BOS.mqh", "04_BOS — Proprietary Break Of Structure", func_block(market, "void UltraEngBOS("))
write("05_CHoCH.mqh", "05_CHOCH — Proprietary Change Of Character", func_block(market, "void UltraEngCHoCH("))
write("06_Liquidity.mqh", "06_LIQUIDITY — Sweeps · Pools · Stop Hunts", func_block(market, "void UltraEngLiquidity("))
write("07_Fibonacci.mqh", "07_FIBONACCI — Proprietary Fib Intelligence (UFIE)", func_block(market, "void UltraEngFib("))
write("08_Institutional.mqh", "08_INSTITUTIONAL — OB · Breaker · FVG · Smart Money", func_block(market, "void UltraEngInstitutional("))
write("09_Trend.mqh", "09_TREND — Adaptive Trend · Strength · Persistence", func_block(market, "void UltraEngTrend("))
write(
    "10_Momentum.mqh",
    "10_MOMENTUM — SMI · Strength · Acceleration · Quality",
    func_block(market, "void UltraEngMomentum(") + func_block(market, "void UltraEngIndicators("),
)
write("11_Volatility.mqh", "11_VOLATILITY — ATR Expand/Compress · Classification", func_block(market, "void UltraEngVolatility("))
write(
    "12_MarketRegime.mqh",
    "12_MARKET_REGIME — Trend/Range/Compression/Expansion/...",
    func_block(market, "void UltraEngRegime(") + func_block(market, "string UltraRegimeName("),
)

# Session / News — split UltraEngSessionNews body into two engines
session_news = func_block(market, "void UltraEngSessionNews(")
# rewrite as two functions
write(
    "17_SessionIntelligence.mqh",
    "17_SESSION_INTELLIGENCE — Asia/London/NY · 24/5 · Never blocks",
    """
void UltraEngSession(const string s, UltraSnap &u)
{
   u.ctx.session = "OFF";
   if(!UltraSessionIntelEnabled) return;
   MqlDateTime t; TimeToStruct(TimeGMT(), t);
   int h = t.hour;
   u.ctx.asia = (h >= 0 && h < 7);
   u.ctx.london = (h >= 7 && h < 16);
   u.ctx.newyork = (h >= 12 && h < 21);
   u.ctx.overlap = (u.ctx.london && u.ctx.newyork);
   u.ctx.killZone = (u.ctx.london || u.ctx.newyork);
   if(u.ctx.overlap) u.ctx.session = "LONDON/NY";
   else if(u.ctx.london) u.ctx.session = "LONDON";
   else if(u.ctx.newyork) u.ctx.session = "NEW YORK";
   else if(u.ctx.asia) u.ctx.session = "ASIA";
   else u.ctx.session = "OTHER";
   u.ctx.sessionConfidence = u.ctx.overlap ? 90 : (u.ctx.killZone ? 75 : 50);
   u.ctx.sessionQuality = u.ctx.sessionConfidence;
   // Never blocks trading
}

// Compatibility wrapper
void UltraEngSessionNews(const string s, UltraSnap &u)
{
   UltraEngSession(s, u);
   UltraEngNews(s, u);
}
""",
)

write(
    "18_NewsIntelligence.mqh",
    "18_NEWS_INTELLIGENCE — Impact proxy · Vol/Spread/Slip · Never blocks",
    """
void UltraEngNews(const string s, UltraSnap &u)
{
   if(!UltraNewsIntelEnabled) return;
   u.ctx.newsVol = u.vol.expansion && u.vol.relative >= 1.45;
   u.ctx.highImpactProxy = (u.vol.relative >= 1.80);
   u.ctx.midImpactProxy  = (u.vol.relative >= 1.45 && u.vol.relative < 1.80);
   u.ctx.lowImpactProxy  = (u.vol.relative >= 1.20 && u.vol.relative < 1.45);
   u.ctx.spreadPts = UltraData_Spread(s);
   u.ctx.slipProxy = MathMax(0.0, u.ctx.spreadPts * 0.15);
   // Trades before/during/after news — NEVER blocks
}
""",
)

# AI splits
conf_buy = func_block(ai, "int UltraConfluenceBuy(")
conf_sell = func_block(ai, "int UltraConfluenceSell(")
scores = func_block(ai, "void UltraEngScores(")

# Precision / Probability extracted from scores conceptually
write(
    "13_Precision.mqh",
    "13_PRECISION — Entry/Exit/Signal precision · False signal cut",
    """
int UltraPrecisionScore(const UltraSnap &u)
{
   int prec = (u.st.quality + u.bos.reliability + u.fib.quality + u.liq.rejectionScore) / 4;
   if(u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION) prec -= 8;
   if(u.ict.smConfluence) prec += 8;
   if(prec < 0) prec = 0; if(prec > 100) prec = 100;
   return prec;
}
""",
)

write(
    "14_Probability.mqh",
    "14_PROBABILITY — Success · Confidence · Risk probability",
    """
int UltraProbabilityScore(const UltraSnap &u, const int confidence, const int precision)
{
   int succ = (confidence + precision + (int)MathRound(MathAbs(u.ind.smi))) / 3;
   if(succ > 100) succ = 100;
   return succ;
}

int UltraRiskProbability(const int successProb)
{
   return 100 - successProb;
}
""",
)

write(
    "15_Confluence.mqh",
    "15_CONFLUENCE — Combines all engines → AI Confidence",
    conf_buy + conf_sell,
)

# Strategies + AI decide + build snapshot + pick
strats = extract_funcs(ai, "void UltraResolveSides(", "void UltraClearSnap(")
pipe = extract_funcs(ai, "void UltraClearSnap(", "string UltraDashboardText(")
# EvaluateStrategySignals may be at end of ai
eval_sig = ""
if "void EvaluateStrategySignals(" in ai:
    eval_sig = func_block(ai, "void EvaluateStrategySignals(")

# Fix UltraEngScores to use precision/probability modules
new_scores = """
void UltraEngScores(UltraSnap &u, const bool buySide)
{
   int conf = buySide ? UltraConfluenceBuy(u) : UltraConfluenceSell(u);
   u.score.confluence = conf;
   u.score.confidence = conf;
   u.score.precision = UltraPrecisionScore(u);
   u.score.successProb = UltraProbabilityScore(u, conf, u.score.precision);
   u.score.riskProb = UltraRiskProbability(u.score.successProb);
   u.score.probability = u.score.successProb;
}
"""

# UltraBuildSnapshot must call UltraEngSessionNews which now wraps session+news
# Ensure UltraEngNews declared before Session wrapper — include order: 18 before 17? 
# 17 calls UltraEngNews — so 18 before 17 in master include.

write(
    "16_AI_Core.mqh",
    "16_AI_CORE — Decision · Approval/Rejection · Controller · Strategies",
    new_scores + strats + pipe + eval_sig,
)

write("19_Execution.mqh", "19_EXECUTION — Fast exec · Retry · Fill · Sync · Broker compat", execu)
write("20_CapitalProtection.mqh", "20_CAPITAL_PROTECTION — Equity · Margin · Exposure · Sizing", cap)

write(
    "21_TradeManagement.mqh",
    "21_TRADE_MANAGEMENT — SL/TP · BE · Trail · Long hold · Exits",
    """
// Deep TP1/TP2/TP3 + BE + trailing + hold logic lives in Shell_B_TradeSystem.mqh
// (ManageOpenTrades / ApplyProfitLockSL / GetTradeDistances).
// This module is the Ultra-facing bridge.

bool UltraTM_HasOpenOnSymbol(const string s)
{
   return (UltraSymDir(s) != 0);
}

string UltraTM_ModuleStatus()
{
   return "Shell_B ManageOpenTrades active (TP1/TP2/TP3 + BE + trail)";
}
""",
)

write("22_MultiSymbol.mqh", "22_MULTI_SYMBOL — Scanner · Sync · Independent analysis", ms)
write("23_MultiTimeframe.mqh", "23_MULTI_TIMEFRAME — MN..M1 · Bias · Voting · Weighting", mtf)
write("24_Dashboard.mqh", "24_DASHBOARD — AI Conf · Prec · Prob · Session · Stats", dash)

write(
    "25_Statistics.mqh",
    "25_STATISTICS — WR · PF · Expectancy · RR · Reports",
    """
void UltraStats_Refresh()
{
   UltraMemoryUpdateFromStats();
}

double UltraStats_WinRate(){ return g_UltraMem.winRate; }
double UltraStats_ProfitFactor(){ return g_UltraMem.profitFactor; }
double UltraStats_AvgRR(){ return g_UltraMem.avgRR; }

string UltraStats_Report()
{
   return "WR=" + DoubleToString(g_UltraMem.winRate, 1) +
          "% PF=" + DoubleToString(g_UltraMem.profitFactor, 2) +
          " RR=" + DoubleToString(g_UltraMem.avgRR, 2);
}
""",
)

# Diagnostics / memory from diag
mem = func_block(diag, "void UltraMemoryUpdateFromStats(") if "void UltraMemoryUpdateFromStats(" in diag else ""
engd = func_block(diag, "void UltraEngDiagnostics(") if "void UltraEngDiagnostics(" in diag else diag

write("26_Diagnostics.mqh", "26_DIAGNOSTICS — Tick · Memory · Connection · Health", engd)
write(
    "29_MarketMemory.mqh",
    "29_MARKET_MEMORY — History · Behaviour · Strategy analytics",
    mem
    + """
void UltraMemory_NoteDecision(const string tag, const int conf)
{
   if(!UltraMarketMemoryEnabled) return;
   UltraLogAI("memory note tag=" + tag + " conf=" + IntegerToString(conf));
}
""",
)

# Shell copies with BUILD rename
for shell in ["Shell_A_InputsGlobals.mqh", "Shell_B_TradeSystem.mqh"]:
    s = read(shell)
    s = s.replace("SNIPER_ULTRA_SHELL", "SNIPER_AI_ULTRA_SHELL")
    s = s.replace("SA_ULTRA_93", "SA_ULTRA_94")
    s = s.replace("OK93", "OK94")
    s = s.replace("MODULAR", "ULTIMATE-MODULAR")
    # fix include refs if any
    (DST / shell).write_text(s, encoding="utf-8")
    print(f"{shell:30s} {(s.count(chr(10))+1):5d} lines")

# Master include — ORDER CRITICAL
master = """#ifndef SNIPER_AI_ULTRA_MASTER_MQH
#define SNIPER_AI_ULTRA_MASTER_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — ULTIMATE MASTER INCLUDE (00-30)                |
//+------------------------------------------------------------------+

#include "00_Types.mqh"
#include "00_Inputs.mqh"
#include "28_Utilities.mqh"
#include "27_Logger.mqh"
#include "30_Recovery.mqh"
#include "01_Core.mqh"
#include "02_Data.mqh"

#include "11_Volatility.mqh"
#include "03_MarketStructure.mqh"
#include "04_BOS.mqh"
#include "05_CHoCH.mqh"
#include "06_Liquidity.mqh"
#include "08_Institutional.mqh"
#include "07_Fibonacci.mqh"
#include "09_Trend.mqh"
#include "10_Momentum.mqh"
#include "12_MarketRegime.mqh"
#include "18_NewsIntelligence.mqh"
#include "17_SessionIntelligence.mqh"

#include "13_Precision.mqh"
#include "14_Probability.mqh"
#include "15_Confluence.mqh"
#include "26_Diagnostics.mqh"
#include "29_MarketMemory.mqh"
#include "20_CapitalProtection.mqh"
#include "19_Execution.mqh"
#include "16_AI_Core.mqh"
#include "21_TradeManagement.mqh"
#include "22_MultiSymbol.mqh"
#include "23_MultiTimeframe.mqh"
#include "25_Statistics.mqh"
#include "24_Dashboard.mqh"

#endif // SNIPER_AI_ULTRA_MASTER_MQH
"""
(DST / "SNIPER_AI_ULTRA.mqh").write_text(master, encoding="utf-8")

readme = """SNIPER AI ULTRA — ULTIMATE PROJECT STRUCTURE (OK94)

00_Types
01_Core
02_Data
03_MarketStructure
04_BOS
05_CHoCH
06_Liquidity
07_Fibonacci
08_Institutional
09_Trend
10_Momentum
11_Volatility
12_MarketRegime
13_Precision
14_Probability
15_Confluence
16_AI_Core
17_SessionIntelligence
18_NewsIntelligence
19_Execution
20_CapitalProtection
21_TradeManagement
22_MultiSymbol
23_MultiTimeframe
24_Dashboard
25_Statistics
26_Diagnostics
27_Logger
28_Utilities
29_MarketMemory
30_Recovery

+ 00_Inputs.mqh
+ Shell_A_InputsGlobals.mqh
+ Shell_B_TradeSystem.mqh
+ SNIPER_AI_ULTRA.mqh (master)

Main EA: SNIPER_AI_OK94.mq5
BUILD_ID: SA_ULTRA_94
"""
(DST / "README_STRUCTURE.txt").write_text(readme, encoding="utf-8")

main = """//+------------------------------------------------------------------+
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
"""
(ROOT / "SNIPER_AI_OK94.mq5").write_text(main, encoding="utf-8")

# Fix dashboard BUILD string
p = DST / "24_Dashboard.mqh"
t = p.read_text(encoding="utf-8")
t = t.replace("SA_ULTRA_93", "SA_ULTRA_94")
t = t.replace("SNIPER AI ULTRA MODULAR", "SNIPER AI ULTRA 00-30")
t = t.replace("SNIPER AI ULTRA", "SNIPER AI ULTRA")
p.write_text(t, encoding="utf-8")

# Fix AI / any leftover 93
for p in DST.glob("*.mqh"):
    t = p.read_text(encoding="utf-8")
    nt = t.replace("SA_ULTRA_93", "SA_ULTRA_94").replace("OK93", "OK94")
    if nt != t:
        p.write_text(nt, encoding="utf-8")

print("modules:", len(list(DST.glob('*.mqh'))))
print("main:", ROOT / "SNIPER_AI_OK94.mq5")
