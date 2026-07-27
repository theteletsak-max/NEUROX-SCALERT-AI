# SNIPER AI - BabFX PRISM build

Canonical: `SNIPER_AI_OK15.mq5` (`BUILD_ID: SA_BABFX_TRADE_15`)

Source: user's BabFX Sniper AI / PRISM engine.

Portability edits:
- Removed `#property strict` (MQL4-only)
- Removed `#resource` watermark BMP dependency
- `TradeComment` default/lock: `SNIPER AI`
- Dashboard default off
- Kept `CTrade` execution (ConfigureFillingMode + invalid-stops open-then-attach)

## OK37 — correct reversal signals (`SA_PRISM_REV_CORRECT_37`)

RevSniper must detect reversals with the **correct** side only:

- BUY: sell-side sweep (lows) + bullish zone + strong reclaim
- SELL: buy-side sweep (highs) + bearish zone + strong reclaim
- `ReversalRejectWrongSideRecent=true`: blocks when opposite sweep is as/more recent (continuation trap)
- `ReversalStrictCorrectSignal=true`: plain candle alone is not reclaim — needs CHoCH / displacement / stop-hunt / inducement
- Cont/Instant unchanged (aggressive trend continuation)

File: `SNIPER_AI_OK37.mq5`
