# SNIPER AI

MetaTrader 5 Expert Advisor — single-file product.

> Not financial advice. Demo-test before live.

## Use this file

**[`SNIPER_AI_OK72.mq5`](SNIPER_AI_OK72.mq5)**  
`BUILD_ID: SA_QUALITY_72` · Trade comment: `SNIPER AI`

Download:  
https://github.com/theteletsak-max/NEUROX-SCALERT-AI/blob/cursor/sniper-ai-compile-fix-b12d/SNIPER_AI_OK72.mq5

Also mirrored as [`SNIPER_AI.mq5`](SNIPER_AI.mq5) and [`MQL5/Experts/SNIPER_AI.mq5`](MQL5/Experts/SNIPER_AI.mq5).


## Best companion indicator (from scratch)

**[`SNIPER_IDP.mq5`](SNIPER_IDP.mq5)** — *Institutional Displacement Pulse* (`BUILD_ID: IDP_1`)

One pulse for this bot (not RSI/MACD/Stoch):
- Sweep wick pressure
- Displacement impulse
- Directional BOS pressure
- Trend-side vs EMA
- Expansion fuel

|Pulse|Meaning|
|-----|-------|
|±70+|**STRONG** (lime/red)|
|±45+|**QUALITY**|
|near 0|no institutional impulse|

Install: copy to `MQL5/Indicators/` → F7 → attach on same chart TF as EntryTF (H1).

## Clean market analysis

Each cycle builds one live snapshot: **session (ASIA/LONDON/NY/OVERLAP) · bias · regime · BOS · zone · Cont READY · APEX wait · news**.
Journal: `MARKET ANALYSIS BUILD=SA_QUALITY_72`.

## Live path (only)

1. **APEX** — liquidity sweep sniper (unmitigated zone soft / OFF by default)
2. **ContFallback** — STRONG/QUALITY only (anytime):
   - ADX trend (skip clear ranging)
   - directional BOS + fresh OB/quality FVG
   - near-zone **OR** displacement + min score

Retired (cannot open trades): ContSniper, RevSniper, InstantTrend, LCS, SpecCompliant / PRISM multi-path.

## Locked behaviour

| Setting | Default |
|--------|---------|
| Session | Detect Asia/London/NY — **trade anytime** (HardBlock OFF) |
| ContFallback | STRONG/QUALITY grades only (ADX + structure score) |
| News | Aware (logs) — does **not** hard-block |
| Spread | Never blocks |
| Anti-scalp | ContFallback cooldown / hold / wider SL |
| Max open | 1 per symbol |
| Comment | must be exactly `SNIPER AI` |

## Install (critical)

1. **Remove `PRISM STRATEGY` from every chart**
2. Delete old `SNIPER*.ex5`
3. Copy `SNIPER_AI_OK72.mq5` → `MQL5/Experts/`
4. Compile (F7)
5. Attach **SNIPER_AI_OK72** (Experts source must not say PRISM STRATEGY)
6. Confirm Journal: `BUILD_ID=SA_QUALITY_72`
7. Algo Trading ON · AutoTrading ON

Look for: `FIRE [APEX]` or `FIRE [ContFallback] BEST …`

See [`SEND_THIS_EA.txt`](SEND_THIS_EA.txt) · [`DOWNLOAD_SNIPER_AI.txt`](DOWNLOAD_SNIPER_AI.txt) · [`release/deliver/`](release/deliver/)

## Legacy note

`mt5/SniperAI/` is an older modular experiment. **Do not use it for live trading** — use `SNIPER_AI_OK72.mq5` only.
