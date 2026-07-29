#!/usr/bin/env python3
"""OK92 cleanup with brace-aware function stubbing."""
from pathlib import Path

path = Path("/workspace/SNIPER_AI_OK92.mq5")
text = path.read_text(encoding="utf-8", errors="replace")


def find_func_end(src: str, start: int) -> int:
    """start points at 'void/bool Func(' — find matching closing brace of body."""
    brace_open = src.find("{", start)
    if brace_open < 0:
        raise ValueError("no opening brace")
    depth = 0
    i = brace_open
    in_str = False
    in_chr = False
    in_line_comment = False
    in_block_comment = False
    while i < len(src):
        c = src[i]
        nxt = src[i + 1] if i + 1 < len(src) else ""
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1
            continue
        if in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == "\\" and nxt:
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if in_chr:
            if c == "\\" and nxt:
                i += 2
                continue
            if c == "'":
                in_chr = False
            i += 1
            continue
        if c == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "'":
            in_chr = True
            i += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced braces")


def replace_func(src: str, signature: str, new_body: str) -> str:
    start = src.find(signature)
    if start < 0:
        raise SystemExit(f"missing signature: {signature}")
    end = find_func_end(src, start)
    return src[:start] + new_body.rstrip() + "\n" + src[end:]


# Header / version
text = text.replace(
    '#property description "UBOSE/UCHOCHE/ULSE/UFIE + SMI/MEO/IFI. BUILD=SA_ULTRA_92"',
    '#property description "ULTRA only. Old APEX/Cont/LCS/IDP-gate REMOVED. BUILD=SA_ULTRA_92R"',
)
text = text.replace('#property version   "9.20"', '#property version   "9.21"')

stubs = [
(
"void EvaluateSpecCompliantStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)",
'''void EvaluateSpecCompliantStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK92 REMOVED — old ContSniper/Rev/Instant/PRISM live router
   buySignal = false; sellSignal = false; strategyTag = "";
}
'''
),
(
"bool APEX_SetupOK(const bool buy, string &detail, double &invalidation)",
'''bool APEX_SetupOK(const bool buy, string &detail, double &invalidation)
{
   // OK92 REMOVED — old APEX live strategy deleted
   detail = "APEX retired OK92";
   invalidation = 0.0;
   return false;
}
'''
),
(
"void EvaluateAPEXStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)",
'''void EvaluateAPEXStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK92 REMOVED — never opens trades
   buySignal = false; sellSignal = false; strategyTag = "";
}
'''
),
(
"void EvaluateLCSStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)",
'''void EvaluateLCSStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK92 REMOVED — LCS deleted from live path
   buySignal = false; sellSignal = false; strategyTag = "";
}
'''
),
(
"bool ContFallbackBestStructureOK(const bool buy, string &detail)",
'''bool ContFallbackBestStructureOK(const bool buy, string &detail)
{
   // OK92 REMOVED — ContFallback deleted (ULTRA ContSniper replaces it)
   detail = "ContFallback retired OK92";
   return false;
}
'''
),
(
"void EvaluateContFallback(bool &buySignal, bool &sellSignal, string &strategyTag)",
'''void EvaluateContFallback(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK92 REMOVED — never opens trades
   buySignal = false; sellSignal = false; strategyTag = "";
}
'''
),
(
"bool IDP_ConfluenceOK(const bool buy, string &detail)",
'''bool IDP_ConfluenceOK(const bool buy, string &detail)
{
   // OK92: IDP retired as live gate — ULTRA confluence owns decisions
   detail = "IDP retired soft-pass OK92";
   return true;
}
'''
),
]

for sig, body in stubs:
    text = replace_func(text, sig, body)
    print("stubbed", sig.split("(")[0])

# AnalyzeLiveMarket ContFallback/APEX probes → ULTRA
old_analyze = """   m.contBuyOK  = ContFallbackBestStructureOK(true,  m.contBuyDetail);
   m.contSellOK = ContFallbackBestStructureOK(false, m.contSellDetail);"""
new_analyze = """   // OK92: live analysis from ULTRA only (old ContFallback/APEX probes removed)
   {
      UltraSnap us;
      UltraBuildSnapshot(BrokerSymbol, us);
      UltraSignal ub = UltraStrat_ContSniper(us);
      UltraSignal usw = UltraStrat_FlashSweep(us);
      m.contBuyOK = (ub.buy || usw.buy);
      m.contSellOK = (ub.sell || usw.sell);
      m.contBuyDetail  = m.contBuyOK  ? "ULTRA READY" : ("ULTRA confB=" + IntegerToString(UltraConfluenceBuy(us)));
      m.contSellDetail = m.contSellOK ? "ULTRA READY" : ("ULTRA confS=" + IntegerToString(UltraConfluenceSell(us)));
      g_APEX_LastBuyFail  = us.bos.buy  ? "" : "no ULTRA BOS buy";
      g_APEX_LastSellFail = us.bos.sell ? "" : "no ULTRA BOS sell";
   }"""
if old_analyze not in text:
    raise SystemExit("AnalyzeLiveMarket chunk missing")
text = text.replace(old_analyze, new_analyze, 1)

old_wait = """      AnalyzeLiveMarket(false);
      // Clean wait reason from live market analysis (never PRISM ContSniper spam)
      string wait = "MARKET " + g_LiveMkt.summary;
      if(EnableContFallback)
         wait = StringFormat("WAIT | %s | ContB=%s ContS=%s | APEX B=%s S=%s",
                             g_LiveMkt.summary,
                             g_LiveMkt.contBuyOK ? "READY" : g_LiveMkt.contBuyDetail,
                             g_LiveMkt.contSellOK ? "READY" : g_LiveMkt.contSellDetail,
                             (g_APEX_LastBuyFail == "" ? "-" : g_APEX_LastBuyFail),
                             (g_APEX_LastSellFail == "" ? "-" : g_APEX_LastSellFail));
      g_UltraLastReject = wait;"""
new_wait = """      AnalyzeLiveMarket(false);
      string wait = StringFormat("ULTRA WAIT | %s | ContB=%s ContS=%s | conf=%d prec=%d prob=%d | %s",
                             g_LiveMkt.summary,
                             g_LiveMkt.contBuyOK ? "READY" : g_LiveMkt.contBuyDetail,
                             g_LiveMkt.contSellOK ? "READY" : g_LiveMkt.contSellDetail,
                             g_UltraLastSnap.score.confidence,
                             g_UltraLastSnap.score.precision,
                             g_UltraLastSnap.score.probability,
                             g_UltraLastSignal.reason == "" ? UltraRegimeName(g_UltraLastSnap.regime) : g_UltraLastSignal.reason);
      g_UltraLastReject = wait;"""
if old_wait not in text:
    raise SystemExit("wait path missing")
text = text.replace(old_wait, new_wait, 1)

text = text.replace(
'Print("SNIPER AI ULTRA Loaded BUILD_ID=SA_ULTRA_92 MaxOpen=", MaxOpenTrades); UltraCoreInit();',
'''Print("SNIPER AI ULTRA Loaded BUILD_ID=SA_ULTRA_92R MaxOpen=", MaxOpenTrades);
   UltraCoreInit();
   if(EnableAPEXStrategy || EnableContFallback || EnableLCSStrategy)
      Print("OK92 WARNING: old APEX/ContFallback/LCS input ON — evaluators STUBBED; ULTRA only fires");
   Print("OK92: old APEX/ContFallback/LCS/IDP-gate REMOVED from live path — ULTRA only");'''
)

# Replace CreateDashboard with Ultra-only
start = text.find("void CreateDashboard()")
if start < 0:
    raise SystemExit("CreateDashboard missing")
end = find_func_end(text, start)
new_dash = '''void CreateDashboard()
{
   if(!EnableDashboard)
      return;
   // OK92: ULTRA dashboard only — old PRISM/Beast HUD removed (duplication)
   Comment(UltraDashboardText(BrokerSymbol));
}
'''
text = text[:start] + new_dash + text[end:]

# BUILD id in comments/dashboard
text = text.replace("SA_ULTRA_92", "SA_ULTRA_92R")
text = text.replace("SA_ULTRA_92RR", "SA_ULTRA_92R")

path.write_text(text, encoding="utf-8")
t = path.read_text()
print("lines", len(t.splitlines()))
print("braces", t.count("{"), t.count("}"))
for s in ["APEX retired OK92", "ContFallback retired OK92", "IDP retired soft-pass", "ULTRA WAIT", "old PRISM/Beast HUD removed", "SA_ULTRA_92R", "UltraAIDecide"]:
    print(("OK" if s in t else "MISSING"), s)
# Router must not call EvaluateAPEX
router = t.split("void EvaluateStrategySignals", 1)[1]
router = router[: router.find("\nvoid ") if "\nvoid " in router[:2500] else 2500]
assert "UltraAIDecide" in router
assert "EvaluateAPEXStrategies(" not in router
print("router clean")
