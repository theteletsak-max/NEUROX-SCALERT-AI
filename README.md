# SNIPER AI

MetaTrader 5 Expert Advisor — single-file product.

> Not financial advice. Demo-test before live.

## Use this file

**[`SNIPER_AI_OK69.mq5`](SNIPER_AI_OK69.mq5)**  
`BUILD_ID: SA_CANTRADE_69` · Trade comment: `SNIPER AI`

Download:  
https://github.com/theteletsak-max/NEUROX-SCALERT-AI/blob/cursor/sniper-ai-compile-fix-b12d/SNIPER_AI_OK69.mq5

Also mirrored as [`SNIPER_AI.mq5`](SNIPER_AI.mq5) and [`MQL5/Experts/SNIPER_AI.mq5`](MQL5/Experts/SNIPER_AI.mq5).

## Live path (only)

1. **APEX** — liquidity sweep sniper (unmitigated zone soft / OFF by default)
2. **ContFallback** — tradable structure:
   - clear trend + directional BOS
   - fresh OB **or** quality FVG
   - price at zone **OR** displacement (not both required)

Retired (cannot open trades): ContSniper, RevSniper, InstantTrend, LCS, SpecCompliant / PRISM multi-path.

## Locked behaviour

| Setting | Default |
|--------|---------|
| Session | Soft ON (tracks London/NY, does **not** hard-block) |
| News | Aware (logs) — does **not** hard-block |
| Spread | Never blocks |
| Anti-scalp | ContFallback cooldown / hold / wider SL |
| Max open | 1 per symbol |
| Comment | must be exactly `SNIPER AI` |

## Install (critical)

1. **Remove `PRISM STRATEGY` from every chart**
2. Delete old `SNIPER*.ex5`
3. Copy `SNIPER_AI_OK69.mq5` → `MQL5/Experts/`
4. Compile (F7)
5. Attach **SNIPER_AI_OK69** (Experts source must not say PRISM STRATEGY)
6. Confirm Journal: `BUILD_ID=SA_CANTRADE_69`
7. Algo Trading ON · AutoTrading ON

Look for: `FIRE [APEX]` or `FIRE [ContFallback] BEST …`

See [`SEND_THIS_EA.txt`](SEND_THIS_EA.txt) · [`DOWNLOAD_SNIPER_AI.txt`](DOWNLOAD_SNIPER_AI.txt) · [`release/deliver/`](release/deliver/)

## Legacy note

`mt5/SniperAI/` is an older modular experiment. **Do not use it for live trading** — use `SNIPER_AI_OK69.mq5` only.
