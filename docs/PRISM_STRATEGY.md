# P.R.I.S.M. EA Strategy (Deduplicated Spec)

**P.R.I.S.M.** = **P**rice structure · **R**isk · **I**nstitutional confirmation · **S**niper execution · **M**anagement

This is the cleaned strategy copy: overlaps merged, contradictions resolved, “AI engine” labels collapsed into one support layer.

---

## 1. Core Identity

| Attribute | Rule |
|-----------|------|
| Style | Aggressive sniper (selective setups, decisive execution) |
| Logic | Rule-based hybrid decision engine |
| Bias source | Institutional price action first; AI assists scoring only |
| Symbols | **Single symbol** only |
| Directions | BUY and SELL |
| Modes | Trend continuation **and** reversal (separate rule paths, same checklist) |

**Philosophy (single list)**
1. Price structure is the foundation.
2. Liquidity explains where price is likely to go.
3. Institutional confirmation (displacement + OB/FVG) validates the shot.
4. AI supports ranking/filtering — never replaces hard rules.
5. Risk is never compromised.
6. No trade without structure + liquidity + risk validation.
7. Execute only sniper setups; manage simply until SL / TP / BE.

---

## 2. Trading Style (one definition)

- **Primary:** Trend continuation after structure break in the trend direction  
- **Secondary:** Reversal after liquidity sweep + CHoCH against the prior leg  
- **Execution feel:** High-probability sniper entries (not spray-and-pray)  
- **Holding horizon:** Intraday (hours)

> “Aggressive” here means **decisive size/execution when the checklist passes**, not unlimited low-quality entries.

---

## 3. Market Structure Engine

*(Merged former: Market Structure + Support/Resistance + parts of Breakout/Reversal)*

**Detect**
- Swing highs / swing lows  
- HH, HL, LH, LL  
- Break of Structure (**BOS**)  
- Change of Character (**CHoCH**)  
- Dynamic reaction levels (prior swings = support/resistance)

**Use**
- Structure defines **bias** (bullish / bearish / transitioning)  
- BOS → continuation path  
- CHoCH → reversal path candidate  

**AI role (optional):** classify structure state; cannot open a trade alone.

---

## 4. Liquidity Engine

*(Merged former: Liquidity System + Market Manipulation Detection + Liquidity Reversals)*

**Map**
- Buy-side / sell-side liquidity  
- Equal highs / equal lows  
- Liquidity pools above highs / below lows  

**Events**
- Liquidity sweep / stop hunt / liquidity grab  
- False breakout / trap (sweep that fails to hold)

**Rule**
- Continuation: prefer entry **after** opposing liquidity is swept or cleared in trend direction  
- Reversal: require sweep **then** CHoCH  

**AI role (optional):** rank sweep quality; cannot bypass sweep/CHoCH rules.

---

## 5. Institutional Confirmation Engine

*(Merged former: Order Blocks + FVG + Supply/Demand + Displacement)*

These are **one confirmation family**, not four separate strategies.

| Concept | Meaning in P.R.I.S.M. |
|---------|------------------------|
| Displacement | Strong impulsive candle(s) that break structure |
| Fair Value Gap (FVG) | Imbalance left by displacement; prefer untested |
| Order Block / Supply-Demand | Last opposing candle before displacement; fresh > mitigated |

**Ranking (single score)**
1. Freshness (untested / not mitigated)  
2. Alignment with structure bias  
3. Proximity to liquidity event  
4. Displacement strength  

**AI role (optional):** rank zones; price-action rules still decide validity.

---

## 6. Execution Context Engine

*(Merged former: Candle + Momentum + Volume + Volatility + Premium/Discount + Gaps)*

Used only as **context / confirmation**, never as the sole entry reason.

| Module | What it confirms |
|--------|------------------|
| Candle | Rejection, engulfing, breakout/momentum candle, wick strength |
| Momentum | Acceleration vs exhaustion |
| Volume | Tick-volume expansion with displacement/breakout |
| Volatility | ATR regime; expansion favors breakouts; contraction warns of fake moves |
| Premium / Discount | Fib equilibrium; prefer buys in discount, sells in premium (esp. reversals) |
| Gaps | Opening gap note only; no standalone signals in v1 |

---

## 7. Market Regime

*(Replaces duplicate “trending/ranging” mentions scattered elsewhere)*

Detect one of:
- **Trending** → prefer continuation path  
- **Ranging** → prefer sweep reversals at range liquidity; reduce continuation  
- **Transition** → wait for CHoCH/BOS clarity  

Indicators, if used, only **confirm regime** — price action always leads.

---

## 8. Multi-Timeframe Map

| Timeframe | Role |
|-----------|------|
| Higher | Bias (structure direction) |
| Middle | Setup (BOS/CHoCH + liquidity + zone) |
| Lower | Sniper entry (confirmation candle) |

Correlation / sentiment: **optional later** — not required for v1 entries.

---

## 9. Entry Rules (single kill-chain)

Every trade must pass **all** mandatory gates:

1. **Structure** — clear bias via swings + BOS (continuation) or CHoCH (reversal)  
2. **Liquidity** — relevant sweep/pool interaction confirmed  
3. **Institutional zone** — displacement + fresh OB and/or untested FVG  
4. **Context** — candle/momentum (+ volume/volatility if available) agrees  
5. **Location** — continuation: with HTF bias; reversal: discount (buy) / premium (sell) preferred  
6. **Risk** — SL/TP/lot valid before send  
7. **Control** — no duplicate entry on same setup/zone  

Then: **immediate sniper execution**.

### Path A — Trend continuation
`HTF bias` → `BOS with trend` → `pullback into OB/FVG` → `continuation candle` → entry

### Path B — Reversal
`liquidity sweep` → `CHoCH` → `displacement + OB/FVG` → `confirmation candle in discount/premium` → entry

---

## 10. Risk Management

| Item | Rule |
|------|------|
| Profile | Aggressive but capped |
| Lot size | Fixed lot *(v1)* — optional % risk later |
| Stop loss | Fixed base SL **with** ATR adjustment (wider in high ATR) |
| Take profit | Fixed TP and/or fixed R:R target |
| Break-even | Fixed BE rule (e.g. move SL to BE at +1R) |
| Forbidden | Martingale, grid, lot multiplication |

---

## 11. Trade Management

**Enabled**
- Run until **Stop Loss**, **Take Profit**, or **Break-Even** hit  

**Disabled**
- Trailing stop  
- Partial profits  
- Other dynamic management  

---

## 12. Trade Control

| Rule | v1 decision |
|------|-------------|
| Symbol | Single symbol |
| Duplicate protection | Yes (same zone / same bar / already in position) |
| Max open trades | **1** (replaces “unlimited trades” — sniper discipline) |
| Spread / session / news filters | Off by default per original; can enable later |

---

## 13. AI Support Layer (one layer, not 14 engines)

AI may help with:
- Structure / sweep / zone **ranking**  
- Regime tagging  
- Post-trade loss review notes  

AI must **not**:
- Self-optimise or change rules live  
- Bypass mandatory gates  
- Martingale / recovery lot sizing  
- Multi-symbol trading  

---

## 14. Recovery

- Analyse losses in the journal  
- Improve rules **manually**  
- **No** martingale, grid, or lot multiplication  

---

## 15. Logging / Journal

Log every trade:
- Path (continuation / reversal)  
- Entry reasons (structure, liquidity, zone, context)  
- Exit reason (SL / TP / BE)  
- Regime + volatility snapshot  
- Stats for manual review  

---

## 16. Development Rules

- Manual backtesting  
- Manual optimisation  
- **No** automatic rule changes  
- **No** AI self-optimisation  

---

## 17. Explicitly Disabled (v1)

- Grid / martingale  
- Trailing stop / partials  
- Dashboard / confidence score UI  
- AI self-optimisation / live rule mutation  
- Multi-symbol trading  
- Correlation & sentiment as hard filters *(defer)*  

---

## Deduplication changelog

| Removed / merged | Into |
|------------------|------|
| Supply & Demand as separate system | §5 Institutional Confirmation (with OB) |
| Manipulation / stop hunt / trap sections | §4 Liquidity Engine |
| Reversal Analysis + Breakout Analysis duplicates | §3 Structure + §9 Entry paths |
| Support & Resistance system | §3 Dynamic reaction levels |
| 14 separate “AI Engines” | §13 one AI Support Layer |
| Momentum vs Displacement overlap | Displacement in §5; momentum context in §6 |
| Disabled features repeated in management/recovery | §11 + §17 once |
| “Unlimited trades” vs sniper identity | Cap **1** open trade (§12) |
| Gap / correlation / sentiment as core | Context optional / deferred |

---

## Still to decide (not assumed)

1. Primary symbol + timeframes (HTF / MTF / LTF)  
2. Fixed lot size value and SL/TP/BE numbers  
3. Whether v1 ships **Path A only**, **Path B only**, or **both**  
4. Whether spread filter stays off for live or demo-only aggression  
