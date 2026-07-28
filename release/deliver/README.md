# SNIPER AI

MetaTrader 5 Expert Advisor — **IDP pulse built into the EA**.

> Not financial advice. Demo-test before live.

## Current file (use this)

| File | Role | BUILD |
|------|------|-------|
| [`SNIPER_AI_OK74.mq5`](SNIPER_AI_OK74.mq5) | Expert Advisor (IDP inside) | `SA_QUALITY_74` |
| [`SNIPER_IDP.mq5`](SNIPER_IDP.mq5) | Optional chart visual | `IDP_1` |

Download EA: https://github.com/theteletsak-max/NEUROX-SCALERT-AI/blob/cursor/sniper-ai-compile-fix-b12d/SNIPER_AI_OK74.mq5

## Live path

1. APEX first  
2. ContFallback STRONG/QUALITY  
3. **Built-in IDP pulse** hard-gates FIRE (BUY +pulse / SELL −pulse)  
4. Trade anytime · news aware · spread never blocks  
5. PRISM multi-path retired  

## Install

1. Remove **PRISM STRATEGY**  
2. F7 `SNIPER_AI_OK74.mq5` → attach  
3. Journal: `SA_QUALITY_74` + `IDP BUILT-IN CORE`  

No separate indicator required to trade.

Older builds: `release/archive/` — do not attach.
