"""Risk management and position sizing."""

from __future__ import annotations

from neurox_scalper.config import RiskConfig
from neurox_scalper.models import AccountState, Side


class RiskManager:
    """Enforces risk-per-trade, daily loss, and spread filters."""

    def __init__(self, cfg: RiskConfig):
        self.cfg = cfg

    def can_open(self, account: AccountState, spread_pips: float) -> tuple[bool, str]:
        open_count = sum(1 for t in account.open_trades if t.is_open)
        if open_count >= self.cfg.max_open_trades:
            return False, "max open trades reached"

        if account.balance <= 0:
            return False, "no balance"

        max_loss = account.balance * (self.cfg.max_daily_loss_pct / 100.0)
        if account.daily_pnl <= -max_loss:
            return False, "daily loss limit hit"

        if spread_pips > self.cfg.max_spread_pips:
            return False, "spread too wide"

        return True, "ok"

    def position_size(self, balance: float, stop_distance: float) -> float:
        """
        Size lots so stop-out risk ≈ risk_per_trade_pct of balance.

        risk_amount = balance * risk%
        pip_risk = stop_distance / pip_size
        value_per_pip_per_lot ≈ contract_size * pip_size  (quote currency for XXXUSD)
        lots = risk_amount / (pip_risk * value_per_pip)
        """
        if stop_distance <= 0 or balance <= 0:
            return 0.0

        risk_amount = balance * (self.cfg.risk_per_trade_pct / 100.0)
        pip_risk = stop_distance / self.cfg.pip_size
        value_per_pip = self.cfg.contract_size * self.cfg.pip_size
        if pip_risk <= 0 or value_per_pip <= 0:
            return 0.0

        lots = risk_amount / (pip_risk * value_per_pip)
        # Round to 0.01 lot and clamp to a sane micro/mini range
        lots = max(0.01, min(round(lots, 2), 50.0))
        return lots

    def stop_take_prices(self, side: Side, entry: float, stop_dist: float, take_dist: float) -> tuple[float, float]:
        if side == Side.BUY:
            return entry - stop_dist, entry + take_dist
        return entry + stop_dist, entry - take_dist
