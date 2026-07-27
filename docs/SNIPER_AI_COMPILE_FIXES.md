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

## OK38 — aggressive profit ladder (`SA_PRISM_PROFIT_LOCK_38`)

When TP1 is hit: partial close + **SL locks into profit** + remainder runs to TP2.
When TP2 is hit: partial close + SL locks further + remainder → TP3 / ATR trail.

Defaults flipped for aggressive power:
- `UseFixedTradeManagement=false`
- `AggressiveProfitLadder=true`
- `SecureProfitOnTPHit=true`
- `EnableTrailing=true`

File: `SNIPER_AI_OK38.mq5`

## OK39 — sure profit ladder (`SA_PRISM_PROFIT_SURE_39`)

Makes the aggressive TP ladder reliable:
- Broker TP opens at **TP3** (not TP2) so the broker cannot full-close before EA locks SL
- `ForceSureProfitLadder=true` keeps ladder on even with fixed management
- Stronger locks: 80% at TP1, 85% at TP2
- Bar-touch TP detection so wick hits are not missed

Flow: TP1 → lock SL into profit → TP2 → lock further → TP3 / trail

File: `SNIPER_AI_OK39.mq5`

## OK40 — bugfix (`SA_PRISM_BUGFIX_40`)

Confirmed defects fixed:
1. `LevelTouchedForTP` no longer credits pre-entry bar wicks (barsHeld gate)
2. Trailing skipped same tick as ladder lock; live SL re-read (no loosen)
3. `ApplyProfitLockSL(..., 0, true)` clears broker TP for trail runners
4. Failed `PositionClosePartial` does not set tp1Taken/tp2Taken
5. TP2 min-lot remainder path closes full (mirror TP1)
6. Stagnation exit skipped after TP1 profit lock
7. `EnableTP3Runner=false` → TP2 is final target
8. `DetectStopHunt` score polarity corrected for BUY/SELL

File: `SNIPER_AI_OK40.mq5`

## OK41 — best quality setups (`SA_PRISM_BEST_QUALITY_41`)

`BestQualitySetups=true` (default):
- ContSniper requires trend+ADX+(BOS|OB/FVG|pullback)
- RevSniper keeps correct-side + strong reclaim
- Cont/Rev need UltraHP_MinConfirmations=4 (HARD)
- InstantTrend fallback only: Beast≥30, Conf≥35%, strong trend
- VolBreakout suppressed; ICE_MinScore=32; Rev liquidity floor=8
- Retains OK40 ladder bugfixes + sure TP1→lock→TP2→TP3

File: `SNIPER_AI_OK41.mq5`
