# NEUROX Scalper AI — MetaTrader 5 Expert Advisor

Built **from scratch** in MQL5. No marketplace template, no external signal service.

## What it does

On each **new closed bar**:

1. Detects fast/slow **EMA crossover**
2. Filters with **RSI** (skip overbought buys / oversold sells)
3. Sizes **stop-loss / take-profit** from **ATR**
4. Optionally trades only inside a **UTC session** (default London/NY overlap 12–16)
5. Applies **risk %** lot sizing, max daily loss, max open trades, and spread filter

## Install in MetaTrader 5

1. Open MT5 → **File → Open Data Folder**
2. Copy files exactly like this:
   - `NeuroX_Scalper_AI.mq5` → `MQL5/Experts/NeuroX_Scalper_AI.mq5`
   - everything in `Include/NeuroX/` → `MQL5/Include/NeuroX/`  
     (so you have `MQL5/Include/NeuroX/NX_Signals.mqh`, etc.)
3. Restart MT5 or refresh the Navigator
4. Open MetaEditor → open `NeuroX_Scalper_AI.mq5` → **Compile** (F7)  
   Zero errors expected. An `.ex5` appears beside the EA.
5. In MT5 Navigator → Expert Advisors → attach **NeuroX_Scalper_AI** to a chart (e.g. EURUSD M5)
6. Enable **Algo Trading**. Start on **demo** first.

Recommended first run: **Strategy Tester** on EURUSD M5 (every tick based on real ticks if available).

## Folder layout

```
mt5/
  NeuroX_Scalper_AI.mq5          # main EA
  Include/NeuroX/
    NX_Config.mqh                # pip/lot helpers
    NX_Session.mqh               # UTC session window
    NX_Indicators.mqh            # EMA / RSI / ATR handles
    NX_Signals.mqh               # crossover + filter logic
    NX_Risk.mqh                  # sizing + daily loss / spread
    NX_Trade.mqh                 # order send wrapper
```

## Key inputs

| Input | Default | Meaning |
|-------|---------|---------|
| Fast / Slow EMA | 9 / 21 | Trend cross |
| RSI buy max / sell min | 65 / 35 | Momentum filter |
| Stop / Take ATR mult | 1.2 / 1.8 | SL/TP distance |
| Risk percent | 0.5% | Risk per trade vs balance |
| Max daily loss | 3% | Halt new entries for the UTC day |
| Session UTC | 12–16 | London/NY overlap |

## Safety

- Always test in **Strategy Tester** and on a **demo** account first
- Magic number isolates this EA’s positions from other robots
- Not financial advice — forex can lose capital quickly
