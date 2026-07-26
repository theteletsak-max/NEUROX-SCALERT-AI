"""Market data helpers — CSV loaders and synthetic OHLC generators."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


REQUIRED_COLS = ("time", "open", "high", "low", "close")


def load_ohlc_csv(path: str | Path) -> pd.DataFrame:
    """Load OHLC candles from CSV with a time column."""
    df = pd.read_csv(path)
    cols = {c.lower(): c for c in df.columns}
    missing = [c for c in REQUIRED_COLS if c not in cols]
    if missing:
        raise ValueError(f"CSV missing columns: {missing}. Need {REQUIRED_COLS}")

    out = pd.DataFrame(
        {
            "time": pd.to_datetime(df[cols["time"]], utc=True),
            "open": df[cols["open"]].astype(float),
            "high": df[cols["high"]].astype(float),
            "low": df[cols["low"]].astype(float),
            "close": df[cols["close"]].astype(float),
        }
    )
    if "volume" in cols:
        out["volume"] = df[cols["volume"]].astype(float)
    else:
        out["volume"] = 0.0

    out = out.sort_values("time").drop_duplicates("time").reset_index(drop=True)
    out = out.set_index("time")
    _validate_ohlc(out)
    return out


def generate_synthetic_ohlc(
    bars: int = 2_000,
    start_price: float = 1.1000,
    timeframe_minutes: int = 5,
    seed: int = 42,
    start: str = "2024-01-01 00:00:00",
) -> pd.DataFrame:
    """
    Generate realistic-ish FX OHLC with mild trend regimes and mean reversion.

    Useful for demos and unit tests when no broker feed is configured.
    """
    rng = np.random.default_rng(seed)
    idx = pd.date_range(start=pd.Timestamp(start, tz="UTC"), periods=bars, freq=f"{timeframe_minutes}min")

    # Regime switching drift + noise
    regime = np.ones(bars)
    cut = bars // 3
    regime[:cut] = 0.00002
    regime[cut : 2 * cut] = -0.000015
    regime[2 * cut :] = 0.00001

    noise = rng.normal(0, 0.00035, size=bars)
    reversion = np.zeros(bars)
    log_prices = np.zeros(bars)
    log_prices[0] = np.log(start_price)
    for i in range(1, bars):
        reversion[i] = -0.05 * (log_prices[i - 1] - np.log(start_price))
        log_prices[i] = log_prices[i - 1] + regime[i] + reversion[i] + noise[i]

    close = np.exp(log_prices)
    open_ = np.roll(close, 1)
    open_[0] = start_price

    wick = np.abs(rng.normal(0, 0.00025, size=bars))
    high = np.maximum(open_, close) + wick
    low = np.minimum(open_, close) - wick
    # Ensure OHLC consistency
    high = np.maximum(high, np.maximum(open_, close))
    low = np.minimum(low, np.minimum(open_, close))

    df = pd.DataFrame(
        {
            "open": open_,
            "high": high,
            "low": low,
            "close": close,
            "volume": rng.integers(50, 500, size=bars).astype(float),
        },
        index=idx,
    )
    df.index.name = "time"
    _validate_ohlc(df)
    return df


def _validate_ohlc(df: pd.DataFrame) -> None:
    bad = (df["high"] < df[["open", "close", "low"]].max(axis=1)) | (
        df["low"] > df[["open", "close", "high"]].min(axis=1)
    )
    if bad.any():
        raise ValueError("Invalid OHLC rows detected")
