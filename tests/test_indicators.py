import pandas as pd

from neurox_scalper.data import generate_synthetic_ohlc
from neurox_scalper.indicators import atr, ema, enrich, rsi


def test_ema_tracks_series():
    s = pd.Series([1.0, 2.0, 3.0, 4.0, 5.0])
    out = ema(s, 3)
    assert out.iloc[-1] > out.iloc[0]


def test_rsi_bounds():
    df = generate_synthetic_ohlc(bars=300, seed=1)
    values = rsi(df["close"], 14).dropna()
    assert values.min() >= 0
    assert values.max() <= 100


def test_atr_positive():
    df = generate_synthetic_ohlc(bars=300, seed=2)
    values = atr(df, 14).dropna()
    assert (values > 0).all()


def test_enrich_adds_columns():
    df = generate_synthetic_ohlc(bars=200, seed=3)
    out = enrich(df, 9, 21, 14, 14)
    for col in ("ema_fast", "ema_slow", "rsi", "atr"):
        assert col in out.columns
