"""Paper broker for simulated order execution."""

from __future__ import annotations

from datetime import datetime

from neurox_scalper.config import EngineConfig, RiskConfig
from neurox_scalper.models import AccountState, Side, Trade


class PaperBroker:
    """Simple fill model with spread + fixed commission per lot."""

    def __init__(self, engine: EngineConfig, risk: RiskConfig):
        self.engine = engine
        self.risk = risk
        self._next_id = 1
        self.account = AccountState(
            balance=engine.initial_balance,
            equity=engine.initial_balance,
        )

    def _spread_price(self) -> float:
        return self.engine.default_spread_pips * self.risk.pip_size

    def mark_day(self, ts: datetime) -> None:
        day = ts.strftime("%Y-%m-%d")
        if self.account.day_marker != day:
            self.account.day_marker = day
            self.account.daily_pnl = 0.0

    def open_trade(
        self,
        side: Side,
        volume: float,
        mid_price: float,
        ts: datetime,
        stop_loss: float,
        take_profit: float,
        reason: str = "",
    ) -> Trade:
        spread = self._spread_price()
        entry = mid_price + spread / 2 if side == Side.BUY else mid_price - spread / 2
        commission = self.engine.commission_per_lot * volume
        trade = Trade(
            id=self._next_id,
            symbol=self.engine.symbol,
            side=side,
            volume=volume,
            entry_price=entry,
            entry_time=ts,
            stop_loss=stop_loss,
            take_profit=take_profit,
            commission=commission,
            reason=reason,
        )
        self._next_id += 1
        self.account.balance -= commission
        self.account.open_trades.append(trade)
        self._refresh_equity(mid_price)
        return trade

    def close_trade(self, trade: Trade, mid_price: float, ts: datetime, reason: str = "") -> Trade:
        spread = self._spread_price()
        if trade.side == Side.BUY:
            exit_price = mid_price - spread / 2
            points = exit_price - trade.entry_price
        else:
            exit_price = mid_price + spread / 2
            points = trade.entry_price - exit_price

        pnl = points * self.risk.contract_size * trade.volume
        trade.exit_price = exit_price
        trade.exit_time = ts
        trade.pnl = pnl
        trade.status = "CLOSED"
        trade.reason = reason or trade.reason

        self.account.balance += pnl
        self.account.daily_pnl += pnl
        self.account.open_trades = [t for t in self.account.open_trades if t.id != trade.id]
        self.account.closed_trades.append(trade)
        self._refresh_equity(mid_price)
        return trade

    def update_open_trades(self, high: float, low: float, close: float, ts: datetime) -> list[Trade]:
        """Check SL/TP against bar extremes (conservative: SL before TP on same bar)."""
        closed: list[Trade] = []
        for trade in list(self.account.open_trades):
            hit_sl = hit_tp = False
            if trade.side == Side.BUY:
                hit_sl = low <= trade.stop_loss
                hit_tp = high >= trade.take_profit
            else:
                hit_sl = high >= trade.stop_loss
                hit_tp = low <= trade.take_profit

            if hit_sl and hit_tp:
                # Ambiguous same-bar hit: assume stop first (conservative)
                closed.append(self.close_trade(trade, trade.stop_loss, ts, "stop_loss"))
            elif hit_sl:
                closed.append(self.close_trade(trade, trade.stop_loss, ts, "stop_loss"))
            elif hit_tp:
                closed.append(self.close_trade(trade, trade.take_profit, ts, "take_profit"))

        self._refresh_equity(close)
        return closed

    def _refresh_equity(self, mid_price: float) -> None:
        unrealized = 0.0
        spread = self._spread_price()
        for trade in self.account.open_trades:
            if trade.side == Side.BUY:
                mark = mid_price - spread / 2
                points = mark - trade.entry_price
            else:
                mark = mid_price + spread / 2
                points = trade.entry_price - mark
            unrealized += points * self.risk.contract_size * trade.volume
        self.account.equity = self.account.balance + unrealized
