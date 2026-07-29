#!/usr/bin/env python3
"""Split SNIPER AI OK92 into professional modular Include/SNIPER_ULTRA + OK93 main."""
from pathlib import Path

ROOT = Path("/workspace")
INC = ROOT / "MQL5/Include/SNIPER_ULTRA"
INC.mkdir(parents=True, exist_ok=True)

ok92 = (ROOT / "SNIPER_AI_OK92.mq5").read_text(encoding="utf-8", errors="replace")

oninit = ok92.find("\nint OnInit()")
ultra_start = ok92.find("// SNIPER AI ULTRA — COMPLETE FEATURE ARCHITECTURE")
assert oninit > 0 and ultra_start > oninit

def func_end(src, sig_start):
    i = src.find("{", sig_start)
    depth = 0
    j = i
    in_str = in_chr = in_lc = in_bc = False
    while j < len(src):
        c = src[j]
        n = src[j + 1] if j + 1 < len(src) else ""
        if in_lc:
            if c == "\n":
                in_lc = False
            j += 1
            continue
        if in_bc:
            if c == "*" and n == "/":
                in_bc = False
                j += 2
                continue
            j += 1
            continue
        if in_str:
            if c == "\\" and n:
                j += 2
                continue
            if c == '"':
                in_str = False
            j += 1
            continue
        if in_chr:
            if c == "\\" and n:
                j += 2
                continue
            if c == "'":
                in_chr = False
            j += 1
            continue
        if c == "/" and n == "/":
            in_lc = True
            j += 2
            continue
        if c == "/" and n == "*":
            in_bc = True
            j += 2
            continue
        if c == '"':
            in_str = True
            j += 1
            continue
        if c == "'":
            in_chr = True
            j += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    raise RuntimeError("no end")

esig = ok92.find(
    "void EvaluateStrategySignals(bool &buySignal, bool &sellSignal, string &strategyTag)",
    ultra_start,
)
ultra_end = func_end(ok92, esig)
ultra_block = ok92[ultra_start:ultra_end]

cd = ok92.find("void CreateDashboard()", ultra_end)
cd_end = func_end(ok92, cd) if cd > 0 else -1

ctrade = ok92.find("CTrade trade;")
after_trade = ok92.find("\n", ctrade) + 1
shell_a = ok92[after_trade:oninit]
shell_b1 = ok92[oninit:ultra_start]
shell_b2 = ok92[ultra_end:]
if cd > 0:
    rel = cd - ultra_end
    rel_end = cd_end - ultra_end
    shell_b2 = (
        shell_b2[:rel]
        + "\n// CreateDashboard -> SNIPER_ULTRA/08_Dashboard.mqh\n"
        + shell_b2[rel_end:]
    )


def write(name, content):
    p = INC / name
    p.write_text(content.rstrip() + "\n", encoding="utf-8")
    print(f"wrote {name}: {content.count(chr(10)) + 1} lines")


markers = {
    "inputs": ultra_block.find('input group "ULTRA CORE SYSTEM"'),
    "types": ultra_block.find("enum ENUM_ULTRA_REGIME"),
    "core_funcs": ultra_block.find("ENUM_TIMEFRAMES UltraETF()"),
    "market_struct": ultra_block.find("void UltraEngStructure("),
    "session": ultra_block.find("void UltraEngSessionNews("),
    "indicators": ultra_block.find("void UltraEngIndicators("),
    "confluence": ultra_block.find("int UltraConfluenceBuy("),
    "diag": ultra_block.find("void UltraEngDiagnostics("),
    "strats": ultra_block.find("void UltraResolveSides("),
    "pipeline": ultra_block.find("void UltraClearSnap("),
    "dashboard": ultra_block.find("string UltraDashboardText("),
    "eval": ultra_block.find("void EvaluateStrategySignals("),
}
for k, v in markers.items():
    if v < 0:
        raise SystemExit(f"marker missing: {k}")

inputs_txt = ultra_block[markers["inputs"] : markers["types"]]
types_txt = ultra_block[markers["types"] : markers["core_funcs"]]
core_txt = ultra_block[markers["core_funcs"] : markers["market_struct"]]
market_txt = ultra_block[markers["market_struct"] : markers["session"]]
session_txt = ultra_block[markers["session"] : markers["indicators"]]
ind_txt = ultra_block[markers["indicators"] : markers["confluence"]]
ai_score_txt = ultra_block[markers["confluence"] : markers["diag"]]
diag_txt = ultra_block[markers["diag"] : markers["strats"]]
strats_txt = ultra_block[markers["strats"] : markers["pipeline"]]
pipe_txt = ultra_block[markers["pipeline"] : markers["dashboard"]]
dash_txt = ultra_block[markers["dashboard"] : markers["eval"]]
eval_txt = ultra_block[markers["eval"] :]

cap_start = diag_txt.find("bool UltraCapitalOK")
exec_ready_start = diag_txt.find("bool UltraExecReady")
mem_start = diag_txt.find("void UltraMemoryUpdateFromStats")
eng_diag = diag_txt[:cap_start] if cap_start > 0 else diag_txt
capital_txt = (
    diag_txt[cap_start:exec_ready_start]
    if cap_start > 0 and exec_ready_start > cap_start
    else ""
)
if exec_ready_start > 0:
    end_er = diag_txt.find("void UltraMemoryUpdateFromStats", exec_ready_start)
    if end_er < 0:
        end_er = len(diag_txt)
    exec_ready_txt = diag_txt[exec_ready_start:end_er]
else:
    exec_ready_txt = ""
mem_txt = diag_txt[mem_start:] if mem_start > 0 else ""

write(
    "00_Types.mqh",
    f"""#ifndef SNIPER_ULTRA_00_TYPES_MQH
#define SNIPER_ULTRA_00_TYPES_MQH
//+------------------------------------------------------------------+
//| 00. Shared Types — SNIPER AI ULTRA                               |
//+------------------------------------------------------------------+
{types_txt}
#endif
""",
)

write(
    "10_Inputs.mqh",
    f"""#ifndef SNIPER_ULTRA_10_INPUTS_MQH
#define SNIPER_ULTRA_10_INPUTS_MQH
//+------------------------------------------------------------------+
//| Ultra-specific inputs (Shell holds Magic/TradeComment/MaxOpen)   |
//+------------------------------------------------------------------+
{inputs_txt}
#endif
""",
)

write(
    "01_Core.mqh",
    f"""#ifndef SNIPER_ULTRA_01_CORE_MQH
#define SNIPER_ULTRA_01_CORE_MQH
//+------------------------------------------------------------------+
//| 01. Ultra Core System                                            |
//| Init · Config · Validation · Error · Memory · Logging · Recovery |
//+------------------------------------------------------------------+
{core_txt}
#endif
""",
)

write(
    "02_Market.mqh",
    f"""#ifndef SNIPER_ULTRA_02_MARKET_MQH
#define SNIPER_ULTRA_02_MARKET_MQH
//+------------------------------------------------------------------+
//| 02. Ultra Market Analysis Engine                                 |
//| Structure · UBOSE · UCHOCHE · ULSE · UFIE · ICT · Trend · Mom ·  |
//| Vol · Regime · Session/News context · SMI/MEO/IFI                |
//+------------------------------------------------------------------+
{market_txt}
{session_txt}
{ind_txt}
#endif
""",
)

write(
    "03_AI.mqh",
    f"""#ifndef SNIPER_ULTRA_03_AI_MQH
#define SNIPER_ULTRA_03_AI_MQH
//+------------------------------------------------------------------+
//| 03. AI Decision Core                                             |
//| Confluence · Precision · Probability · Strategies · Approval     |
//+------------------------------------------------------------------+
{ai_score_txt}
{strats_txt}
{pipe_txt}
{eval_txt}
#endif
""",
)

write(
    "05_Capital.mqh",
    f"""#ifndef SNIPER_ULTRA_05_CAPITAL_MQH
#define SNIPER_ULTRA_05_CAPITAL_MQH
//+------------------------------------------------------------------+
//| 05. Capital Protection Engine                                    |
//| Equity · Margin · Exposure · Sizing bridge · Profit protection   |
//+------------------------------------------------------------------+
{capital_txt}
// Deep capital rules also live in Shell_B (RiskManagementOK / Drawdown / lots).
#endif
""",
)

write(
    "04_Execution.mqh",
    f"""#ifndef SNIPER_ULTRA_04_EXEC_MQH
#define SNIPER_ULTRA_04_EXEC_MQH
//+------------------------------------------------------------------+
//| 04. Ultra Execution Engine                                       |
//| Fast exec · fill policy · retry · duplicate protect · sync       |
//| Bridges InstantExecution / ExecuteBuy / ExecuteSell (Shell_B)    |
//+------------------------------------------------------------------+

{exec_ready_txt}

bool UltraExec_DuplicateBarGuard(const string s)
{{
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar <= 0) return false;
   if(g_UltraLastFireBar == bar) return true;
   return false;
}}

void UltraExec_MarkFired(const string s)
{{
   datetime bar = iTime(s, UltraETF(), 0);
   if(bar > 0) g_UltraLastFireBar = bar;
}}

bool UltraExec_Ready(const string s, string &why)
{{
   return UltraExecReady(s, why);
}}

int UltraExec_OpenCountMagic()
{{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {{
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      n++;
   }}
   return n;
}}

#endif
""",
)

write(
    "06_MultiSymbol.mqh",
    """#ifndef SNIPER_ULTRA_06_MULTISYM_MQH
#define SNIPER_ULTRA_06_MULTISYM_MQH
//+------------------------------------------------------------------+
//| 06. Ultra Multi Symbol Engine                                    |
//| Scanner · Sync · Independent analysis · Symbol statistics        |
//+------------------------------------------------------------------+

int UltraMulti_SymbolCount()
{
   return ArraySize(MultiSymbolList);
}

string UltraMulti_SymbolAt(const int idx)
{
   if(idx < 0 || idx >= ArraySize(MultiSymbolList)) return "";
   return MultiSymbolList[idx];
}

bool UltraMulti_IsTracked(const string s)
{
   return (GetSymbolIndex(s) >= 0);
}

void UltraMulti_ScanSummary(string &out)
{
   out = "symbols=" + IntegerToString(UltraMulti_SymbolCount());
   if(EnableMultiSymbolTrading)
      out += " multi=ON timer=" + IntegerToString(MultiSymbolTimerSeconds) + "s";
   else
      out += " multi=OFF primary=" + BrokerSymbol;
}

bool UltraMulti_AnalyzeSymbol(const string s, UltraSnap &u)
{
   if(!UltraMulti_IsTracked(s) && s != BrokerSymbol && s != _Symbol)
      return false;
   return UltraBuildSnapshot(s, u);
}

#endif
""",
)

write(
    "07_MTF.mqh",
    """#ifndef SNIPER_ULTRA_07_MTF_MQH
#define SNIPER_ULTRA_07_MTF_MQH
//+------------------------------------------------------------------+
//| 07. Ultra Multi Timeframe Engine                                 |
//| MN / W1 / D1 / H4 / H1 / M30 / M15 / M5 / M1                     |
//+------------------------------------------------------------------+

ENUM_TIMEFRAMES UltraMTF_List(const int idx)
{
   switch(idx)
   {
      case 0: return PERIOD_MN1;
      case 1: return PERIOD_W1;
      case 2: return PERIOD_D1;
      case 3: return PERIOD_H4;
      case 4: return PERIOD_H1;
      case 5: return PERIOD_M30;
      case 6: return PERIOD_M15;
      case 7: return PERIOD_M5;
      case 8: return PERIOD_M1;
   }
   return PERIOD_CURRENT;
}

int UltraMTF_Count() { return 9; }

bool UltraMTF_Bull(const string s, const ENUM_TIMEFRAMES tf, const int smaPeriod=20)
{
   double sma = UltraSMA(s, tf, smaPeriod);
   if(sma <= 0.0) return false;
   return (iClose(s, tf, 1) > sma);
}

bool UltraMTF_Bear(const string s, const ENUM_TIMEFRAMES tf, const int smaPeriod=20)
{
   double sma = UltraSMA(s, tf, smaPeriod);
   if(sma <= 0.0) return false;
   return (iClose(s, tf, 1) < sma);
}

void UltraMTF_Vote(const string s, int &votesBuy, int &votesSell)
{
   votesBuy = 0; votesSell = 0;
   ENUM_TIMEFRAMES core[4] = {UltraTF_Month, UltraTF_Week, UltraTF_Macro, UltraTF_Bias};
   for(int i = 0; i < 4; i++)
   {
      if(UltraMTF_Bull(s, core[i])) votesBuy++;
      if(UltraMTF_Bear(s, core[i])) votesSell++;
   }
   if(UltraUseM30){ if(UltraMTF_Bull(s, PERIOD_M30)) votesBuy++; if(UltraMTF_Bear(s, PERIOD_M30)) votesSell++; }
   if(UltraUseM15){ if(UltraMTF_Bull(s, PERIOD_M15)) votesBuy++; if(UltraMTF_Bear(s, PERIOD_M15)) votesSell++; }
   if(UltraUseM5){  if(UltraMTF_Bull(s, PERIOD_M5))  votesBuy++; if(UltraMTF_Bear(s, PERIOD_M5))  votesSell++; }
   if(UltraUseM1Optional){ if(UltraMTF_Bull(s, PERIOD_M1)) votesBuy++; if(UltraMTF_Bear(s, PERIOD_M1)) votesSell++; }
}

double UltraMTF_WeightBias(const int votesBuy, const int votesSell)
{
   int d = votesBuy - votesSell;
   return MathMax(-1.0, MathMin(1.0, d / 6.0));
}

#endif
""",
)

write(
    "09_Diagnostics.mqh",
    f"""#ifndef SNIPER_ULTRA_09_DIAG_MQH
#define SNIPER_ULTRA_09_DIAG_MQH
//+------------------------------------------------------------------+
//| 09. Diagnostics & Analytics                                      |
//+------------------------------------------------------------------+
{eng_diag}
{mem_txt}
#endif
""",
)

write(
    "08_Dashboard.mqh",
    f"""#ifndef SNIPER_ULTRA_08_DASH_MQH
#define SNIPER_ULTRA_08_DASH_MQH
//+------------------------------------------------------------------+
//| 08. Dashboard System                                             |
//+------------------------------------------------------------------+
{dash_txt}

void CreateDashboard()
{{
   if(!EnableDashboard)
      return;
   Comment(UltraDashboardText(BrokerSymbol));
}}

#endif
""",
)

write(
    "SNIPER_ULTRA.mqh",
    """#ifndef SNIPER_ULTRA_MASTER_MQH
#define SNIPER_ULTRA_MASTER_MQH
//+------------------------------------------------------------------+
//| SNIPER AI ULTRA — Master module include                          |
//+------------------------------------------------------------------+
#include "00_Types.mqh"
#include "10_Inputs.mqh"
#include "01_Core.mqh"
#include "07_MTF.mqh"
#include "02_Market.mqh"
#include "09_Diagnostics.mqh"
#include "05_Capital.mqh"
#include "04_Execution.mqh"
#include "03_AI.mqh"
#include "06_MultiSymbol.mqh"
#include "08_Dashboard.mqh"
#endif
""",
)

write(
    "Shell_A_InputsGlobals.mqh",
    f"""#ifndef SNIPER_ULTRA_SHELL_A_MQH
#define SNIPER_ULTRA_SHELL_A_MQH
//+------------------------------------------------------------------+
//| Shell A — Inputs, globals, forward declarations (pre-Ultra)      |
//+------------------------------------------------------------------+
{shell_a}
#endif
""",
)

write(
    "Shell_B_TradeSystem.mqh",
    f"""#ifndef SNIPER_ULTRA_SHELL_B_MQH
#define SNIPER_ULTRA_SHELL_B_MQH
//+------------------------------------------------------------------+
//| Shell B — Trade system / management / events (post-Ultra)        |
//+------------------------------------------------------------------+
{shell_b1}
{shell_b2}
#endif
""",
)

for fn in [
    "Shell_A_InputsGlobals.mqh",
    "Shell_B_TradeSystem.mqh",
    "08_Dashboard.mqh",
    "03_AI.mqh",
]:
    p = INC / fn
    s = p.read_text(encoding="utf-8")
    s = s.replace("SA_ULTRA_92R", "SA_ULTRA_93")
    s = s.replace("SA_ULTRA_92", "SA_ULTRA_93")
    s = s.replace("OK92", "OK93")
    s = s.replace("SA_ULTRA_93R", "SA_ULTRA_93")
    p.write_text(s, encoding="utf-8")

# Fix UltraDashboardText BUILD string inside 08
p = INC / "08_Dashboard.mqh"
s = p.read_text(encoding="utf-8")
s = s.replace("BUILD: SA_ULTRA_93", "BUILD: SA_ULTRA_93")
s = s.replace("======= SNIPER AI ULTRA =======", "======= SNIPER AI ULTRA MODULAR =======")
p.write_text(s, encoding="utf-8")

main = """//+------------------------------------------------------------------+
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
"""

(ROOT / "SNIPER_AI_OK93.mq5").write_text(main, encoding="utf-8")
print("main OK93 lines", main.count("\n") + 1)
print("files", sorted(p.name for p in INC.glob("*.mqh")))
print("Shell_A", (INC / "Shell_A_InputsGlobals.mqh").read_text().count("\n") + 1)
print("Shell_B", (INC / "Shell_B_TradeSystem.mqh").read_text().count("\n") + 1)
# total modular lines
total = sum(p.read_text().count("\n") + 1 for p in INC.glob("*.mqh"))
total += main.count("\n") + 1
print("total modular project lines", total)
