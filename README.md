# NEUROX Scalper AI

Forex scalping trading robot with risk controls, session filters, backtesting, and paper replay.

**Not financial advice.** This is a research / paper-trading toolkit. Do not run it with real money until you have validated it thoroughly on your own data and broker.

## Strategy

NEUROX uses a short-horizon trend scalper on M5 (configurable):

1. **EMA cross** — fast EMA vs slow EMA for direction
2. **RSI filter** — skip buys when overbought / sells when oversold
3. **ATR stops** — stop-loss and take-profit sized from ATR
4. **Session window** — optional London/NY overlap (UTC 12–16 by default)
5. **Risk manager** — % risk per trade, max daily loss, max open trades, spread filter

## Quick start

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install -e .

# Write a local config
neurox init-config -o config.yaml

# Backtest on synthetic EURUSD-like data
neurox backtest --bars 3000

# Backtest your own candles
neurox backtest --csv path/to/ohlc.csv --export-trades trades.csv

# Paper replay of the latest bars
neurox paper --bars 1000 --tail 300
```

### CSV format

```csv
time,open,high,low,close,volume
2024-01-02 00:00:00,1.10421,1.10455,1.10390,1.10410,120
```

`time` should be UTC (timezone-aware preferred).

## Project layout

```
neurox_scalper/
  config.py      # YAML config models
  indicators.py  # EMA, RSI, ATR
  strategy.py    # Signal logic
  risk.py        # Position sizing & limits
  broker.py      # Paper execution (spread + commission)
  engine.py      # Backtest / paper engine
  data.py        # CSV loader + synthetic OHLC
  cli.py         # `neurox` commands
config.example.yaml
tests/
```

## Configure

Copy `config.example.yaml` → `config.yaml` and tune:

| Section   | Key ideas                                      |
|-----------|-------------------------------------------------|
| strategy  | EMA lengths, RSI bands, ATR stop/target multiples |
| risk      | Risk %, daily loss cap, pip size, lot sizing     |
| session   | Enable/disable UTC trading window                |
| engine    | Symbol, timeframe, balance, spread, commission   |

```bash
neurox --config config.yaml backtest --bars 5000 --json
```

## Live brokers

This release ships a **paper broker** only. To go live, plug a broker adapter into `PaperBroker`'s interface (same open/close/update methods) for MetaTrader 5, OANDA, or your bridge. Keep the risk manager in front of every order.

## Tests

```bash
pytest -q
```

## Disclaimer

Forex trading involves substantial risk of loss. Past backtest results do not guarantee future performance. Synthetic data is for demos only — always validate on real historical ticks/candles from your broker.
