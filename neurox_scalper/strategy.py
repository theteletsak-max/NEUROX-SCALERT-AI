"""NEUROX EMA + RSI scalping strategy."""

from __future__ import annotations

import pandas as pd

from neurox_scalper.config import SessionConfig, StrategyConfig
from neurox_scalper.indicators import enrich
from neurox_scalper.models import Signal, SignalAction


class NeuroxScalperStrategy:
    """
    Trend-following scalper:

    - BUY when fast EMA crosses above slow EMA and RSI is not overbought
    - SELL when fast EMA crosses below slow EMA and RSI is not oversold
    - Stops / targets sized from ATR for short holding periods
    """

    def __init__(self, strategy: StrategyConfig, session: SessionConfig, pip_size: float = 0.0001):
        self.cfg = strategy
        self.session = session
        self.pip_size = pip_size

    def prepare(self, df: pd.DataFrame) -> pd.DataFrame:
        prepared = enrich(
            df,
            fast=self.cfg.fast_ema,
            slow=self.cfg.slow_ema,
            rsi_period=self.cfg.rsi_period,
            atr_period=self.cfg.atr_period,
        )
        prepared["ema_cross_up"] = (prepared["ema_fast"] > prepared["ema_slow"]) & (
            prepared["ema_fast"].shift(1) <= prepared["ema_slow"].shift(1)
        )
        prepared["ema_cross_down"] = (prepared["ema_fast"] < prepared["ema_slow"]) & (
            prepared["ema_fast"].shift(1) >= prepared["ema_slow"].shift(1)
        )
        return prepared

    def in_session(self, ts: pd.Timestamp) -> bool:
        if not self.session.enabled:
            return True
        hour = int(ts.tz_convert("UTC").hour) if getattr(ts, "tzinfo", None) else int(ts.hour)
        start = self.session.start_hour_utc
        end = self.session.end_hour_utc
        if start <= end:
            return start <= hour < end
        return hour >= start or hour < end

    def evaluate(self, row: pd.Series, has_open_trade: bool) -> Signal:
        if has_open_trade:
            return Signal(SignalAction.HOLD, "position already open")

        if pd.isna(row.get("atr")) or pd.isna(row.get("rsi")):
            return Signal(SignalAction.HOLD, "indicators warming up")

        ts = row.name if isinstance(row.name, pd.Timestamp) else pd.Timestamp(row.get("time"))
        if not self.in_session(ts):
            return Signal(SignalAction.HOLD, "outside trading session")

        atr_pips = float(row["atr"]) / self.pip_size
        if atr_pips < self.cfg.min_atr_pips:
            return Signal(SignalAction.HOLD, "ATR too low for scalping")

        stop = float(row["atr"]) * self.cfg.stop_atr_mult
        take = float(row["atr"]) * self.cfg.take_atr_mult

        if bool(row["ema_cross_up"]) and float(row["rsi"]) <= self.cfg.rsi_buy_max:
            return Signal(SignalAction.BUY, "EMA cross up + RSI filter", stop, take)

        if bool(row["ema_cross_down"]) and float(row["rsi"]) >= self.cfg.rsi_sell_min:
            return Signal(SignalAction.SELL, "EMA cross down + RSI filter", stop, take)

        return Signal(SignalAction.HOLD, "no setup")
