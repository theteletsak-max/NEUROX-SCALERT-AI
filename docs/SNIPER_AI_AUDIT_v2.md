# SNIPER AI — Technical Audit (pre-rebuild)

## Critical findings (v1)

| Area | Weakness | Rebuild action |
|------|----------|----------------|
| ATR | `iATR` created/released every call | Persistent handle + buffer cache |
| Rates | `CopyRates` on every module call | Shared `CMarketData` cache keyed by bar time |
| Swings | Fragile dual-pass, ambiguous recency | Confirmed fractal swings, closed-bar only |
| BOS/CHoCH | Mixed with live close semantics | Break confirmed on bar `[1]` vs prior swing |
| Liquidity | Loose equal-high logic | Tolerance in ATR/pip units; sweep = pierce + reclaim |
| FVG | Single pattern, no mitigation | 3-candle FVG + untested/fresh flag |
| OB | Weak “last opposite candle” | Impulse → origin OB + mitigation test |
| Execution | Basic `CTrade` only | Filling auto-detect, stop validation, retries |
| Comment | Embedded path/score | Exact `SNIPER AI` only |
| Risk | No margin/DD/loss streak guards | Optional DD + consecutive-loss gates |
| CPU | Multi-symbol full scan every bar | Chart-primary; optional scan with score rank |
| UI | Watermark/resource coupling | Removed; premium HUD expanded |
| Strings | Heavy `StringFormat` in hot paths | Minimal logging; dashboard throttle |

## Non-negotiables preserved

- Strategy: H4 bias → H1 structure/liquidity/zones → M5 confirm  
- Continuation + reversal paths  
- Instant market execution when kill-chain passes  
- 24/7, no news/session block  
- Max 3 trades, lot 0.01 (input), SL 1.5×ATR(H1), TP 2R, BE +1R  
- Single `.mq5` delivery  

## Quality bar (v2)

Deterministic · non-repainting · broker-compatible · low CPU · maintainable sections inside one file.
