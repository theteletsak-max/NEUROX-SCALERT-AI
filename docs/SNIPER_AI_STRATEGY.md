# Sniper AI — Strategy Lock (No Code Yet)

**Bot name:** Sniper AI  
**Identity:** Aggressive sniper  
**Execution:** Instant — when the kill-chain passes, send the order immediately (no delay, no manual confirm, no “wait for next signal”)  
**Status:** Strategy **SIGNED OFF** — build plan next; coding only when user says go

---

## Locked decisions

| Topic | Decision |
|-------|----------|
| Name | **Sniper AI** |
| Style | Aggressive sniper (selective entries, decisive size) |
| Execution | **Instant execution** on valid setup |
| Direction | BUY & SELL |
| Symbols | **All forex pairs the broker lists** |
| Horizon | Intraday (hours) |
| Timeframes | **H4 bias → H1 setup → M5 entry** |
| v1 path | **Trend continuation** first (reversals = v2) |
| Max open trades | **3 total on the account** (also ≤ 3 per symbol) |
| Lot | **0.01** default (user-changeable input) |
| SL / TP / BE | **1.5×ATR(H1)** / **2R** / BE at **+1R** |
| Management | SL / TP / Break-even only |
| Forbidden | Grid, martingale, trailing, partials, self-optimising AI |
| AI role | Assist ranking / labelling only — never bypass rules |
| Slot priority | **Instant if slot free**; if several qualify same pass → **highest score first** |

---

## Philosophy

1. Price structure is the foundation.  
2. Liquidity explains where price is likely to go.  
3. Institutional confirmation (displacement + OB/FVG) validates the shot.  
4. AI supports — never replaces — hard rules.  
5. Risk is never compromised.  
6. No trade without structure + liquidity + risk validation.  
7. When valid → **instant sniper execution**.

---

## Multi-timeframe map (locked)

| Layer | TF | Role |
|-------|----|------|
| Bias | **H4** | Bullish / bearish structure direction |
| Setup | **H1** | BOS, liquidity, OB / FVG zone |
| Entry | **M5** | Confirmation candle → instant market order |

Why this stack: H4/H1 keep sniper quality (from B); M5 makes the shot faster without dropping to M1 noise.

## What “instant execution” means

- H4 + H1 gates must already be valid.  
- On **closed M5 confirmation candle**, if all gates pass → **market order immediately**.  
- No pending “maybe later”, no extra candle wait beyond that M5 close.  
- Still **rule-gated** — instant ≠ reckless.

---

## v1 Entry kill-chain (Path A — continuation)

1. **H4 bias** clear (bullish or bearish structure)  
2. **H1 BOS** with that bias  
3. **H1 liquidity** interaction OK (sweep/clear opposing side or clean break)  
4. Pullback into **fresh OB and/or untested FVG** on H1  
5. **M5 confirmation candle** with trend closes  
6. **Risk** valid (SL / TP / lot)  
7. Account open Sniper AI trades **< 3**, and that symbol **< 3**  

→ **Instant market BUY/SELL** on that M5 close

*(Path B — reversal after sweep + CHoCH — deferred to v2)*

---

## Risk / management (locked)

| Setting | Value | Notes |
|---------|--------|------|
| Lot | **0.01** default | Input — user can change |
| SL | **1.5 × ATR(H1)** | ATR-based stop |
| TP | **2R** | 2 × stop distance |
| BE | At **+1R** | Move SL to break-even |
| Ends on | SL / TP / BE | No trailing, no partials |

---

## Exposure (locked)

- Scan **all forex symbols** available on the broker  
- Hard cap: **3 open Sniper AI trades total** on the account  
- Per-symbol cap remains **3** (account cap usually binds first)  
- Non-forex (gold, indices, crypto) = out of scope unless you add them later  

## Slot allocation (locked) — A + B

1. **Speed (B):** If account open trades **< 3** and a pair’s kill-chain passes → **instant execution** (do not wait for other pairs).  
2. **Score (A):** If **multiple pairs** qualify in the **same evaluation pass** and only *N* slots remain → take the **top N by setup score**.  
3. Do **not** close an existing trade just to free a slot for a “better” new setup.  
4. Score uses structure + liquidity + zone quality (AI may help rank; rules still gate entry).

## Sign-off

- Strategy freeze accepted (user: “1 and 2” = sign-off + build plan).  
- No further strategy changes unless explicitly reopened.  
- Coding starts only on user command.

---

## Supersedes

This lock updates naming and execution intent from `PRISM_STRATEGY.md`.  
Core institutional stack remains; product name is now **Sniper AI**.
