import pytest

from neurox_scalper.config import RiskConfig
from neurox_scalper.models import AccountState, Side
from neurox_scalper.risk import RiskManager


def test_position_size_scales_with_risk():
    rm = RiskManager(RiskConfig(risk_per_trade_pct=1.0, pip_size=0.0001, contract_size=100_000))
    lots = rm.position_size(balance=10_000, stop_distance=0.0010)  # 10 pips
    # risk $100 / (10 pips * $10/pip) = 1.0 lot
    assert lots == 1.0


def test_daily_loss_blocks_entries():
    rm = RiskManager(RiskConfig(max_daily_loss_pct=3.0, max_open_trades=1))
    account = AccountState(balance=10_000, equity=9_600, daily_pnl=-350)
    ok, reason = rm.can_open(account, spread_pips=1.0)
    assert not ok
    assert "daily loss" in reason


def test_stop_take_prices_buy_sell():
    rm = RiskManager(RiskConfig())
    sl, tp = rm.stop_take_prices(Side.BUY, 1.1000, 0.0010, 0.0015)
    assert sl == pytest.approx(1.0990)
    assert tp == pytest.approx(1.1015)
    sl, tp = rm.stop_take_prices(Side.SELL, 1.1000, 0.0010, 0.0015)
    assert sl == pytest.approx(1.1010)
    assert tp == pytest.approx(1.0985)
