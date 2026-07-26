import pandas as pd

from neurox_scalper.config import SessionConfig, StrategyConfig
from neurox_scalper.data import generate_synthetic_ohlc
from neurox_scalper.models import SignalAction
from neurox_scalper.strategy import NeuroxScalperStrategy


def test_session_filter_blocks_outside_hours():
    strat = NeuroxScalperStrategy(
        StrategyConfig(),
        SessionConfig(enabled=True, start_hour_utc=12, end_hour_utc=16),
    )
    assert strat.in_session(pd.Timestamp("2024-01-01 13:00:00", tz="UTC"))
    assert not strat.in_session(pd.Timestamp("2024-01-01 08:00:00", tz="UTC"))


def test_strategy_prepare_and_evaluate_hold_when_open():
    df = generate_synthetic_ohlc(bars=400, seed=7)
    strat = NeuroxScalperStrategy(StrategyConfig(), SessionConfig(enabled=False))
    prepared = strat.prepare(df)
    row = prepared.iloc[-1]
    signal = strat.evaluate(row, has_open_trade=True)
    assert signal.action == SignalAction.HOLD
