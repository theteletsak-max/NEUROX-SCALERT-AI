#!/usr/bin/env python3
"""Inject SNIPER AI ULTRA architecture into OK92."""
from pathlib import Path

path = Path("/workspace/SNIPER_AI_OK92.mq5")
text = path.read_text(encoding="utf-8", errors="replace")
ultra = Path("/workspace/tools/ultra_module.mq5").read_text(encoding="utf-8")

# Header
text = text.replace(
"""//| BUILD_ID: SA_PRIME_91                                             |
//| SNIPER AI — OK81 EXEC SHELL + NEW STRATEGIES FROM SCRATCH         |
//| Comment: SNIPER AI | MaxOpen=3 | Fib + Cont/Rev/Flash/Break       |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "5.91"
#property description "SNIPER AI OK91: keep exec shell, new strategies+Fib from scratch"
#property description "Old APEX/ContFallback/BB/FastSlowEMA retired. BUILD=SA_PRIME_91"
""",
"""//| BUILD_ID: SA_ULTRA_92                                             |
//| SNIPER AI ULTRA — COMPLETE FEATURE ARCHITECTURE                   |
//| Comment: SNIPER AI | MaxOpen=3 | Session/News never hard-block    |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "9.20"
#property description "SNIPER AI ULTRA: full architecture on OK81 exec shell"
#property description "UBOSE/UCHOCHE/ULSE/UFIE + SMI/MEO/IFI. BUILD=SA_ULTRA_92"
""")

# Replace PRIME inputs with thin redirect note (ULTRA inputs live with module)
old_prime_inputs_start = "input group \"PRIME STRATEGIES (FROM SCRATCH — OK91 LIVE)\""
old_prime_inputs_end = "input ENUM_TIMEFRAMES PRIME_MacroTF = PERIOD_D1;\n"
i0 = text.find(old_prime_inputs_start)
i1 = text.find(old_prime_inputs_end)
if i0 < 0 or i1 < 0:
    raise SystemExit(f"PRIME inputs block not found {i0} {i1}")
i1 += len(old_prime_inputs_end)
text = text[:i0] + (
    "// OK92: PRIME inputs replaced — see ULTRA CORE / MARKET / FIB / STRATEGIES inputs in ULTRA module.\n"
    "// Kept for .set compatibility (unused by live router):\n"
    "input bool   Enable_FlashSweep   = true;\n"
    "input bool   Enable_ContSniper   = true;\n"
    "input bool   Enable_RevSniper    = true;\n"
    "input bool   Enable_FibSniper    = true;\n"
    "input bool   Enable_BreakImpulse = true;\n"
    "input int    MinStrategyScore    = 58;\n"
    "input int    InstantFireScore    = 75;\n"
    "input bool   BlockOppositeSameSymbol = true;\n"
    "input double FibBuyLow         = 0.50;\n"
    "input double FibBuyHigh        = 0.886;\n"
    "input double FibSellLow        = 0.114;\n"
    "input double FibSellHigh       = 0.50;\n"
    "input bool   SoftPreferFib     = true;\n"
) + text[i1:]

# OnInit prints
text = text.replace(
'Print("SNIPER AI Loaded BUILD_ID=SA_PRIME_91 MaxOpen=", MaxOpenTrades, " strategies=Flash/Cont/Rev/Fib/Break");',
'Print("SNIPER AI ULTRA Loaded BUILD_ID=SA_ULTRA_92 MaxOpen=", MaxOpenTrades); UltraCoreInit();'
)
text = text.replace(
'Print("---- MARKET ANALYSIS BUILD=SA_PRIME_91 (", BrokerSymbol, ") ----");',
'Print("---- MARKET ANALYSIS BUILD=SA_ULTRA_92 (", BrokerSymbol, ") ----");'
)

# Forward decls: add UltraCoreInit + GetWinRate helpers if missing
if "void UltraCoreInit();" not in text:
    text = text.replace(
        "bool PRIME_IsLiveTag(const string tag); // OK91 forward — used by Ultra/PRISM before PRIME module",
        "bool PRIME_IsLiveTag(const string tag); // OK92 forward — Ultra live tags\n"
        "void UltraCoreInit();\n"
        "double GetWinRatePercent();\n"
        "double GetProfitFactor();\n"
        "double GetAverageRR();"
    )

# Replace PRIME module + EvaluateStrategySignals through end of EvaluateStrategySignals
start = text.find("//====================================================================//\n// OK91 PRIME — ENGINES + STRATEGIES FROM SCRATCH (LIVE ENTRY PATH)")
if start < 0:
    raise SystemExit("PRIME module start not found")
end_marker = "//+------------------------------------------------------------------+\n//|         DISPLACEMENT / MOMENTUM EXHAUSTION / DYNAMIC S&R (NEW)   |"
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit("displacement marker not found")

new_eval = r'''
void EvaluateStrategySignals(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   buySignal = false;
   sellSignal = false;
   strategyTag = "";

   // OK92 LIVE: SNIPER AI ULTRA complete architecture decision flow
   UltraSnap snap;
   if(!UltraBuildSnapshot(BrokerSymbol, snap))
   {
      if(EnableVerboseLogging)
         Print("ULTRA snapshot failed: ", g_UltraCore.lastError, " on ", BrokerSymbol);
      g_UltraLastSnap = snap;
      return;
   }

   UltraSignal best;
   string why = "";
   if(!UltraAIDecide(BrokerSymbol, snap, best, why))
   {
      g_UltraLastSnap = snap;
      g_UltraLastSignal = best;
      if(EnableVerboseLogging || ContStruct_LogDetail)
         Print("ULTRA wait [", why, "] conf=", snap.score.confidence,
               " prec=", snap.score.precision, " prob=", snap.score.probability,
               " regime=", UltraRegimeName(snap.regime),
               " fibB/S=", snap.fib.atBuyZone, "/", snap.fib.atSellZone,
               " on ", BrokerSymbol);
      return;
   }

   buySignal = best.buy;
   sellSignal = best.sell;
   strategyTag = best.tag;
   g_UltraLastSnap = snap;
   g_UltraLastSignal = best;
   Print("ULTRA FIRE ", (best.buy ? "BUY" : "SELL"), " [", best.tag, "] conf=", snap.score.confidence,
         " prec=", snap.score.precision, " prob=", snap.score.probability,
         " ", best.reason, " SMI=", DoubleToString(snap.ind.smi, 1),
         " session=", snap.ctx.session, " on ", BrokerSymbol);
}

'''

text = text[:start] + ultra + "\n\n" + new_eval + "\n" + text[end:]

# Dashboard — replace CreateDashboard body preference: force Ultra dashboard first
old_create = """void CreateDashboard()
{
   if(!EnableDashboard)
      return;

   if(EnableUltraCore && EnableUltraDashboard)
   {"""

new_create = """void CreateDashboard()
{
   if(!EnableDashboard)
      return;

   if(UltraDashboardEnabled)
   {
      Comment(UltraDashboardText(BrokerSymbol));
      return;
   }

   if(EnableUltraCore && EnableUltraDashboard)
   {"""

if old_create not in text:
    raise SystemExit("CreateDashboard hook missing")
text = text.replace(old_create, new_create, 1)

# InstantExecution comment
text = text.replace(
"   // EvaluateStrategySignals() = OK91 PRIME (Flash/Cont/Rev/Fib/Break) only.",
"   // EvaluateStrategySignals() = OK92 SNIPER AI ULTRA complete architecture."
)

# Ensure MaxOpen still 3
if "MaxOpenTrades                = 3" not in text:
    raise SystemExit("MaxOpenTrades!=3")

path.write_text(text, encoding="utf-8")
print("OK92 written", path, "lines", len(path.read_text().splitlines()))
checks = [
    "SA_ULTRA_92", "UltraBuildSnapshot", "UltraEngFib", "UltraEngBOS", "UltraEngCHoCH",
    "ULSE", "UFIE", "SMI", "Market Energy", "Institutional Footprint",
    "UltraAIDecide", "UltraDashboardText", "PRIME_IsLiveTag", "MaxOpenTrades                = 3",
]
t = path.read_text()
for c in checks:
    print(("OK" if c in t else "MISSING"), c)
# brace balance
print("braces", t.count("{"), t.count("}"))
