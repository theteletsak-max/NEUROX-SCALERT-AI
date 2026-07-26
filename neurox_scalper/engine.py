"""Trading engine — runs strategy over candle data (backtest / paper)."""

from __future__ import annotations

from dataclasses import dataclass

import pandas as pd

from neurox_scalper.broker import PaperBroker
from neurox_scalper.config import RobotConfig
from neurox_scalper.models import Side, SignalAction
from neurox_scalper.risk import RiskManager
from neurox_scalper.strategy import NeuroxScalperStrategy


@dataclass
class BacktestReport:
    symbol: str
    bars: int
    trades: int
    wins: int
    losses: int
    win_rate: float
    net_pnl: float
    gross_profit: float
    gross_loss: float
    profit_factor: float
    max_drawdown_pct: float
    final_balance: float
    final_equity: float
    return_pct: float

    def as_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "bars": self.bars,
            "trades": self.trades,
            "wins": self.wins,
            "losses": self.losses,
            "win_rate": round(self.win_rate, 4),
            "net_pnl": round(self.net_pnl, 2),
            "gross_profit": round(self.gross_profit, 2),
            "gross_loss": round(self.gross_loss, 2),
            "profit_factor": round(self.profit_factor, 4),
            "max_drawdown_pct": round(self.max_drawdown_pct, 4),
            "final_balance": round(self.final_balance, 2),
            "final_equity": round(self.final_equity, 2),
            "return_pct": round(self.return_pct, 4),
        }


class TradingEngine:
    """Event-driven candle engine for backtests and paper simulation."""

    def __init__(self, config: RobotConfig):
        self.config = config
        self.strategy = NeuroxScalperStrategy(config.strategy, config.session, config.risk.pip_size)
        self.risk = RiskManager(config.risk)
        self.broker = PaperBroker(config.engine, config.risk)
        self.equity_curve: list[float] = []

    def run(self, df: pd.DataFrame) -> BacktestReport:
        prepared = self.strategy.prepare(df)
        self.equity_curve = [self.broker.account.equity]

        for ts, row in prepared.iterrows():
            self.broker.mark_day(ts.to_pydatetime())
            self.broker.update_open_trades(
                high=float(row["high"]),
                low=float(row["low"]),
                close=float(row["close"]),
                ts=ts.to_pydatetime(),
            )

            has_open = any(t.is_open for t in self.broker.account.open_trades)
            signal = self.strategy.evaluate(row, has_open_trade=has_open)

            if signal.action in (SignalAction.BUY, SignalAction.SELL):
                ok, reason = self.risk.can_open(
                    self.broker.account,
                    self.config.engine.default_spread_pips,
                )
                if not ok:
                    self.equity_curve.append(self.broker.account.equity)
                    continue

                volume = self.risk.position_size(self.broker.account.balance, signal.stop_distance)
                if volume <= 0:
                    self.equity_curve.append(self.broker.account.equity)
                    continue

                side = Side.BUY if signal.action == SignalAction.BUY else Side.SELL
                mid = float(row["close"])
                sl, tp = self.risk.stop_take_prices(side, mid, signal.stop_distance, signal.take_distance)
                self.broker.open_trade(
                    side=side,
                    volume=volume,
                    mid_price=mid,
                    ts=ts.to_pydatetime(),
                    stop_loss=sl,
                    take_profit=tp,
                    reason=signal.reason,
                )

            self.equity_curve.append(self.broker.account.equity)

        # Flatten any leftover open trades at last close
        if prepared.empty:
            return self._report(0)
        last_ts = prepared.index[-1].to_pydatetime()
        last_close = float(prepared.iloc[-1]["close"])
        for trade in list(self.broker.account.open_trades):
            self.broker.close_trade(trade, last_close, last_ts, "end_of_data")

        return self._report(len(prepared))

    def _report(self, bars: int) -> BacktestReport:
        closed = self.broker.account.closed_trades
        wins = [t for t in closed if t.pnl > 0]
        losses = [t for t in closed if t.pnl <= 0]
        gross_profit = sum(t.pnl for t in wins)
        gross_loss = abs(sum(t.pnl for t in losses))
        # Commissions already deducted from balance; net_pnl vs start:
        start = self.config.engine.initial_balance
        end = self.broker.account.balance
        net_pnl = end - start
        pf = gross_profit / gross_loss if gross_loss > 0 else float("inf") if gross_profit > 0 else 0.0
        dd = _max_drawdown_pct(self.equity_curve)
        return BacktestReport(
            symbol=self.config.engine.symbol,
            bars=bars,
            trades=len(closed),
            wins=len(wins),
            losses=len(losses),
            win_rate=(len(wins) / len(closed)) if closed else 0.0,
            net_pnl=net_pnl,
            gross_profit=gross_profit,
            gross_loss=gross_loss,
            profit_factor=pf,
            max_drawdown_pct=dd,
            final_balance=end,
            final_equity=self.broker.account.equity,
            return_pct=(end / start - 1.0) * 100.0 if start else 0.0,
        )


def _max_drawdown_pct(curve: list[float]) -> float:
    if not curve:
        return 0.0
    peak = curve[0]
    max_dd = 0.0
    for value in curve:
        peak = max(peak, value)
        if peak > 0:
            dd = (peak - value) / peak * 100.0
            max_dd = max(max_dd, dd)
    return max_dd


def format_report(report: BacktestReport) -> str:
    d = report.as_dict()
    lines = [
        "=== NEUROX Scalper AI — Backtest Report ===",
        f"Symbol          : {d['symbol']}",
        f"Bars            : {d['bars']}",
        f"Trades          : {d['trades']}  (W {d['wins']} / L {d['losses']})",
        f"Win rate        : {d['win_rate'] * 100:.2f}%",
        f"Net PnL         : {d['net_pnl']:.2f}",
        f"Profit factor   : {d['profit_factor']}",
        f"Max drawdown    : {d['max_drawdown_pct']:.2f}%",
        f"Final balance   : {d['final_balance']:.2f}",
        f"Return          : {d['return_pct']:.2f}%",
    ]
    return "\n".join(lines)
