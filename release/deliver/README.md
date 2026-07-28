# SNIPER AI

MetaTrader 5 — **EA + companion indicator** (single product set).

> Not financial advice. Demo-test before live.

## Current files (use these only)

| File | Role | BUILD |
|------|------|-------|
| [`SNIPER_AI_OK72.mq5`](SNIPER_AI_OK72.mq5) | Expert Advisor | `SA_QUALITY_72` |
| [`SNIPER_IDP.mq5`](SNIPER_IDP.mq5) | Institutional Displacement Pulse | `IDP_1` |

Mirrors: `SNIPER_AI.mq5`, `MQL5/Experts/`, `MQL5/Indicators/`, `release/deliver/`

Downloads:
- EA: https://github.com/theteletsak-max/NEUROX-SCALERT-AI/blob/cursor/sniper-ai-compile-fix-b12d/SNIPER_AI_OK72.mq5
- IDP: https://github.com/theteletsak-max/NEUROX-SCALERT-AI/blob/cursor/sniper-ai-compile-fix-b12d/SNIPER_IDP.mq5

## What is in place

**EA live path**
1. APEX first
2. ContFallback STRONG/QUALITY only (ADX + BOS + zone + near/disp + score)
3. Trade **anytime** (session detect soft — no hard block)
4. News aware · spread never blocks · anti-scalp holds
5. ContSniper / PRISM multi-path **retired**

**SNIPER IDP** (best companion indicator, from scratch)
- One pulse: sweep + displacement + BOS + trend side
- STRONG ±70 · QUALITY ±45
- Not RSI/MACD/Stoch

## Install (critical)

1. **Remove `PRISM STRATEGY` from every chart**
2. Copy `SNIPER_AI_OK72.mq5` → `MQL5/Experts/` → F7
3. Copy `SNIPER_IDP.mq5` → `MQL5/Indicators/` → F7
4. Attach **SNIPER_AI_OK72** (source must not say PRISM STRATEGY)
5. Attach **SNIPER_IDP** on same chart (H1 / EntryTF)
6. Confirm Journal: `BUILD_ID=SA_QUALITY_72` and `SNIPER IDP Loaded BUILD_ID=IDP_1`
7. Algo Trading ON

See [`SEND_THIS_EA.txt`](SEND_THIS_EA.txt) · [`CURRENT.txt`](CURRENT.txt) · [`INSTALL.txt`](INSTALL.txt) · [`IDP_README.txt`](IDP_README.txt)

## Legacy

- Older `SNIPER_AI_OK*.mq5` builds = archive only — do **not** attach
- `mt5/SniperAI/` = legacy modular experiment — do **not** use live
