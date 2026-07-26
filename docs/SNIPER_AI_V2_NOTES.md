# SNIPER AI — Engineering Rebuild Notes

## What changed vs v1

- Full rewrite (not a patch) of the single-file EA
- Persistent ATR handle + bar-time rate cache (major CPU fix)
- Non-repainting swings / BOS / CHoCH on closed bars only
- Deterministic liquidity sweeps (pierce + reclaim)
- Cleaner FVG (3-candle) + displacement OB logic
- Institutional execution: filling mode detect, retries, margin checks, stop-level validation
- Adaptive SL boost in high/extreme ATR regimes (still trades news/high vol)
- Optional trailing / daily DD / consecutive-loss gates (off by default)
- Trade comment exactly `SNIPER AI`
- Expanded premium right-corner dashboard
- Watermark removed

## Strategy preserved

H4 bias → H1 structure/liquidity/zones → M5 confirmation  
Continuation + reversal · max 3 · lot 0.01 · 1.5×ATR · 2R · BE +1R · 24/7  

## File

Canonical compile-safe EA: `release/deliver/SNIPER_AI.mq5`  
`BUILD_ID: SA_COMPILE_OK_9`

See also: [`SNIPER_AI_COMPILE_FIXES.md`](SNIPER_AI_COMPILE_FIXES.md)

## Superseded by V3

See [`SNIPER_AI_V3_AUDIT.md`](SNIPER_AI_V3_AUDIT.md) — production build is `SA_INSTITUTIONAL_V3`.
