# SNIPER AI — MetaTrader 5 Expert Advisor

Aggressive institutional sniper robot:

- Instant market execution  
- 24/7 (no session filter)  
- Trades through news / high volatility (no volatility block)  
- H4 → H1 → M5 structure / liquidity / OB-FVG / continuation + reversal  
- Max 3 open trades · lot `0.01` (changeable) · SL `1.5×ATR` · TP `2R` · BE `+1R`  
- Left **watermark** (`SNIPER AI`) behind candles  
- Right-corner **dashboard**

## Easiest install — 1 file + image

Use the delivery pack:

- [`release/SniperAI/SniperAI.mq5`](../../release/SniperAI/SniperAI.mq5) — **single file** (all code inside)
- [`release/SniperAI/SniperAI_Watermark.bmp`](../../release/SniperAI/SniperAI_Watermark.bmp) — watermark image
- Zip: [`release/SniperAI_SingleFile.zip`](../../release/SniperAI_SingleFile.zip)

1. MT5 → **File → Open Data Folder** → `MQL5/Experts/`
2. Copy **both** `SniperAI.mq5` + `SniperAI_Watermark.bmp` there
3. MetaEditor → Compile **(F7)**
4. Attach to chart → enable **Algo Trading**

## Modular install (developers)

1. Copy the whole folder `mt5/SniperAI/` into `MQL5/Experts/SniperAI/`
2. Compile `SniperAI.mq5` (uses `Include/` + `Images/`)

The EA reads **H4 / H1 / M5** internally; chart timeframe is for display.

## Watermark

`Images/SniperAI_Watermark.bmp` is embedded via `#resource`.  
Object uses `OBJPROP_BACK = true` so **candles stay visible on top**.

## Dashboard

Right-upper HUD: bias, signal, path, score, open trades, balance/equity, status.

## Safety

Demo-test first. Forex is risky. This EA is aggressive by design.
