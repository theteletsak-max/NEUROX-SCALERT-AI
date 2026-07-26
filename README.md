# NEUROX Scalper AI

Forex scalping robot built **from scratch** — MetaTrader 5 Expert Advisor (MQL5) plus an optional Python research/backtest toolkit.

> Not financial advice. Demo-test thoroughly before any live use.

## 1) MetaTrader 5 robot (primary)

The live trading robot lives in [`mt5/`](mt5/):

| Piece | Role |
|-------|------|
| `NeuroX_Scalper_AI.mq5` | Main Expert Advisor |
| `Include/NeuroX/NX_Signals.mqh` | EMA cross + RSI filter |
| `Include/NeuroX/NX_Risk.mqh` | Risk % sizing, daily loss, spread |
| `Include/NeuroX/NX_Trade.mqh` | Order execution |
| `Include/NeuroX/NX_Indicators.mqh` | EMA / RSI / ATR handles |
| `Include/NeuroX/NX_Session.mqh` | UTC session window |

### Install

See **[mt5/README.md](mt5/README.md)** for copy paths, compile steps, and Strategy Tester usage.

Short version:

1. Copy `NeuroX_Scalper_AI.mq5` → MT5 `MQL5/Experts/`
2. Copy `Include/NeuroX/` → MT5 `MQL5/Include/NeuroX/`
3. Compile in MetaEditor (F7)
4. Attach to EURUSD M5 (or your pair/TF), enable Algo Trading
5. Start on **demo** / Strategy Tester

### Strategy (from scratch)

```
new closed bar
   → EMA fast crosses EMA slow?
   → RSI allows the direction?
   → ATR large enough to scalp?
   → inside session + risk checks pass?
   → open trade with ATR stop & target, risk-% lot size
```

## 2) Python research toolkit (optional)

Offline backtests and paper replay without MetaTrader:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -e .

neurox init-config -o config.yaml
neurox backtest --bars 3000
neurox backtest --csv your_ohlc.csv --export-trades trades.csv
pytest -q
```

Config knobs: [`config.example.yaml`](config.example.yaml)

## Disclaimer

Forex trading involves substantial risk of loss. Backtests (especially on synthetic data) do not guarantee live results. Validate on your broker’s history and a demo account first.
