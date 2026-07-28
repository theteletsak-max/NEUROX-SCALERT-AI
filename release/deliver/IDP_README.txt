SNIPER IDP — Institutional Displacement Pulse
BUILD_ID: IDP_1

THE companion indicator for SNIPER AI OK73.

EA signal core reads this via iCustom:
  buffer 0 = pulse (−100..+100)
  BUY needs +pulse, SELL needs −pulse
  QUALITY |pulse| ≥ 45 (default hard gate)
  STRONG  |pulse| ≥ 70

Pulse scores:
  1) Liquidity sweep wick
  2) Displacement impulse
  3) Directional BOS
  4) Trend side vs EMA
  5) Range expansion

Install: MQL5/Indicators/SNIPER_IDP.mq5 → F7 BEFORE attaching OK73 EA
Chart attach is optional (visual); EA loads it itself.
