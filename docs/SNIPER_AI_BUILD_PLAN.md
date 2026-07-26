# Sniper AI — Build Plan (No Code Yet)

Based on signed-off `SNIPER_AI_STRATEGY.md`.

---

## Frozen product summary

| Item | Lock |
|------|------|
| Name | Sniper AI |
| Style | Aggressive sniper |
| Execution | Instant on valid M5 confirmation |
| Pairs | All broker forex symbols |
| Max trades | 3 account-wide (≤3 per symbol) |
| TF stack | H4 bias → H1 setup → M5 entry |
| v1 path | Trend continuation only |
| Risk | Lot 0.01 (input), SL 1.5×ATR(H1), TP 2R, BE +1R |
| Slots | Instant if free; same-pass → highest score |
| Forbidden | Grid, martingale, trailing, partials, self-opt AI |

---

## Build phases

### Phase 0 — Project shape
- Rename product surface to **Sniper AI** (docs, EA name, magic comment)
- MT5 EA as primary runtime
- Keep Python toolkit optional for later research (not required for v1 EA)

### Phase 1 — Core scaffold (MT5)
- `SniperAI.mq5` (or `Sniper_AI.mq5`) expert
- Inputs: lot, magic, max trades, ATR mult, RR, BE trigger, symbol scan toggle
- Symbol universe loader (all forex pairs from broker)
- Position counters (account + per symbol)
- Journal `Print` / file log hooks

### Phase 2 — Structure engine (H4 / H1)
- Swing high/low detection
- HH/HL/LH/LL + bias
- BOS detection on H1 aligned with H4 bias

### Phase 3 — Liquidity + zones (H1)
- Equal highs/lows + sweep detection
- Displacement → FVG + Order Block (fresh/untested)
- Setup score (structure + liquidity + zone quality)

### Phase 4 — Entry + execution (M5)
- M5 confirmation candle with trend
- Kill-chain gate in order
- Instant market order when pass
- Same-pass multi-symbol ranking before filling remaining slots

### Phase 5 — Risk + management
- SL from 1.5×ATR(H1), TP = 2R
- BE move at +1R
- Enforce max 3 account trades
- No trailing / no partials / no martingale

### Phase 6 — Validation
- Strategy Tester on several majors first (even though universe is all forex)
- Demo forward test
- Journal review: why each trade fired / exited

### Phase 7 — v2 (later, not v1)
- Reversal path (sweep + CHoCH)
- Optional filters (spread/session/news) if needed after demo data

---

## Module map (what we will code later)

```
SniperAI.mq5
  ├─ SymbolUniverse
  ├─ Structure (H4/H1)
  ├─ Liquidity
  ├─ Zones (OB/FVG/Displacement)
  ├─ Score
  ├─ Entry (M5)
  ├─ Risk
  ├─ TradeExec (instant market)
  └─ Journal
```

---

## Out of scope for first coding pass

- Reversal engine
- Dashboard UI
- True ML model training
- Multi-account / prop-firm rulesets
- Non-forex symbols

---

## Next user command options

- **`go code`** — start Phase 0–1 implementation  
- **`go code phase 2`** — jump after scaffold  
- **`reopen strategy`** — change locks before coding  
