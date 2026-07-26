# SNIPER AI — Audit (EXEC FIX V4)

`BUILD_ID: SA_EXEC_FIX_V4`

## Critical execution bug (fixed)

V3 required **BOS + displacement + OB/FVG simultaneously on H1 bar[1]**.

That contradicts the sniper strategy (impulse creates zone → pullback → M5 entry).
On pullback bars displacement is false → **zero trades**.

## V4 fixes

- BOS/CHoCH persisted over structure lookback (closed bars only)
- Displacement / FVG / OB scanned over recent lookback + mitigation checks
- Continuation uses recent displacement as zone creator, not entry-bar impulse
- Location = pullback into OB/FVG
- M5 confirmation kept objective/non-repainting, slightly more executable
- Trade attempt always runs on new M5 (chart mode and fallback)
- Dashboard/lastAction shows why a setup did not fire
- Live stop re-validation on each execution retry

## Strategy preserved

H4 bias → H1 BOS/liquidity/zones → M5 confirm  
Continuation + Reversal · max 3 · ATR SL · 2R · BE · comment `SNIPER AI` · 24/7 adaptive
