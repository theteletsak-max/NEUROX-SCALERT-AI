# Sniper AI — Strategy Lock (No Code Yet)

**Bot name:** Sniper AI  
**Identity:** Aggressive sniper  
**Execution:** Instant — when the kill-chain passes, send the order immediately (no delay, no manual confirm, no “wait for next signal”)  
**Status:** Design only — not coding yet

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
| v1 path | **Trend continuation** first (reversals = v2) |
| Max open trades | **3 total on the account** (also ≤ 3 per symbol) |
| Management | SL / TP / Break-even only |
| Forbidden | Grid, martingale, trailing, partials, self-optimising AI |
| AI role | Assist ranking / labelling only — never bypass rules |

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

## What “instant execution” means

- Evaluate on the **closed confirmation candle** (or defined entry tick rule — to freeze next).  
- If all mandatory gates pass → **market order immediately**.  
- No pending “maybe later”, no extra candle wait beyond the defined entry rule.  
- Still **rule-gated** — instant ≠ reckless.

---

## v1 Entry kill-chain (Path A — continuation)

1. **HTF bias** clear (bullish or bearish structure)  
2. **BOS** with trend on setup timeframe  
3. **Liquidity** interaction OK (sweep/clear opposing side or clean break)  
4. Pullback into **fresh OB and/or untested FVG**  
5. **Confirmation candle** with trend  
6. **Risk** valid (SL / TP / lot)  
7. Account open Sniper AI trades **< 3**, and that symbol **< 3**  

→ **Instant market BUY/SELL**

*(Path B — reversal after sweep + CHoCH — deferred to v2)*

---

## Risk / management (direction locked; numbers TBD)

- Fixed lot **or** % risk (pick one later)  
- SL: fixed base + ATR adjustment  
- TP: fixed R:R  
- BE: move to break-even at defined R  
- Trade ends only on SL, TP, or BE stop

---

## Exposure (locked)

- Scan **all forex symbols** available on the broker  
- Hard cap: **3 open Sniper AI trades total** on the account  
- Per-symbol cap remains **3** (account cap usually binds first)  
- Non-forex (gold, indices, crypto) = out of scope unless you add them later  

## Still open (decide next, piece by piece)

1. Timeframes (HTF / setup / entry)  
2. Exact SL / TP / BE / lot numbers  
3. Entry timing detail (close of candle vs tick inside zone)  
4. How to pick which setups win when more than 3 pairs qualify (best score first?)

---

## Supersedes

This lock updates naming and execution intent from `PRISM_STRATEGY.md`.  
Core institutional stack remains; product name is now **Sniper AI**.
