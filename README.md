# SNIPER AI

Aggressive institutional forex sniper robot for **MetaTrader 5**.

Instant execution · 24/7 · trades through events · execution-focused (no chart dashboard) · H4/H1/M5 kill-chain.

> Not financial advice. Demo-test before live. Forex can lose capital quickly.

## Primary product — MT5 EA

Full robot lives in [`mt5/SniperAI/`](mt5/SniperAI/):

| Piece | Role |
|-------|------|
| `SniperAI.mq5` | Main Expert Advisor |
| `Include/SniperAI/SA_Signal.mqh` | Continuation + reversal kill-chain |
| `Include/SniperAI/SA_Structure.mqh` | Swings, BOS, CHoCH, H4 bias |
| `Include/SniperAI/SA_Liquidity.mqh` | Sweeps / equal highs-lows |
| `Include/SniperAI/SA_Zones.mqh` | Displacement, FVG, order blocks |
| `Include/SniperAI/SA_Risk.mqh` | Lot / ATR SL / 2R / BE / max 3 |
| `Include/SniperAI/SA_Trade.mqh` | Instant market orders |
| `Include/SniperAI/SA_Watermark.mqh` | Background watermark (candles on top) |
| `Include/SniperAI/SA_Dashboard.mqh` | Right-corner HUD |
| `Images/SniperAI_Watermark.bmp` | SNIPER AI branded artwork |

### Install (MT5) — single file (compile-safe)

Use **[`SNIPER_AI_OK65.mq5`](SNIPER_AI_OK65.mq5)**  
`BUILD_ID: SA_NEWS_SPREADFREE_65`

1. **Remove `PRISM STRATEGY` from every chart**  
2. Copy **`SNIPER_AI_OK65.mq5`** → F7  
3. Attach **SNIPER_AI_OK65** (source must not say PRISM STRATEGY)  
4. Experts: `SA_NEWS_SPREADFREE_65` + `NEWS AWARE` / `FIRE [APEX]` or `FIRE [ContFallback]`  

**OK65:** Knows news (awareness log, no hard block). High spread NEVER blocks. Keeps OK64 anti-scalp ContFallback. Soft session anytime.

See [`DOWNLOAD_SNIPER_AI.txt`](DOWNLOAD_SNIPER_AI.txt)


### Locked behaviour

- Chart symbol by default (or all forex if you disable “Trade attached chart only”)
- Max **3** open trades · lot **0.01** (input) · SL **1.5×ATR(H1)** · TP **2R** · BE **+1R**
- **No session filter** · **no volatility block** · runs in news
- No chart dashboard · Experts log for status

## Strategy docs

- [`docs/SNIPER_AI_STRATEGY.md`](docs/SNIPER_AI_STRATEGY.md)
- [`docs/SNIPER_AI_BUILD_PLAN.md`](docs/SNIPER_AI_BUILD_PLAN.md)

## Optional Python research toolkit

`neurox_scalper/` — offline backtests (`neurox backtest`). Not required for the MT5 robot.
