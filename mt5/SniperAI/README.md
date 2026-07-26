# SNIPER AI — MetaTrader 5 Expert Advisor

Aggressive institutional sniper robot:

- Instant market execution  
- 24/7 (no session filter)  
- Trades through news / high volatility (no volatility block)  
- H4 → H1 → M5 structure / liquidity / OB-FVG / continuation + reversal  
- Max 3 open trades · lot `0.01` (changeable) · SL `1.5×ATR` · TP `2R` · BE `+1R`  
- Left **watermark** (`SNIPER AI`) behind candles  
- Right-corner **dashboard**

## Install

1. MT5 → **File → Open Data Folder**
2. Copy the whole folder `SniperAI/` into `MQL5/Experts/SniperAI/`  
   so you have:
   ```
   MQL5/Experts/SniperAI/SniperAI.mq5
   MQL5/Experts/SniperAI/Images/SniperAI_Watermark.bmp
   MQL5/Experts/SniperAI/Include/SniperAI/*.mqh
   ```
3. Open `SniperAI.mq5` in MetaEditor → **Compile (F7)**
4. Attach **SniperAI** to your chart (any forex pair / TF for viewing)
5. Enable **Algo Trading**

The EA reads **H4 / H1 / M5** internally; chart timeframe is for display.

## Watermark

`Images/SniperAI_Watermark.bmp` is embedded via `#resource`.  
Object uses `OBJPROP_BACK = true` so **candles stay visible on top**.

## Dashboard

Right-upper HUD: bias, signal, path, score, open trades, balance/equity, status.

## Safety

Demo-test first. Forex is risky. This EA is aggressive by design.
