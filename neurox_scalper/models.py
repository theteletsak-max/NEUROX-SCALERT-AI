"""Shared domain models for trades and signals."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class Side(str, Enum):
    BUY = "BUY"
    SELL = "SELL"


class SignalAction(str, Enum):
    HOLD = "HOLD"
    BUY = "BUY"
    SELL = "SELL"
    CLOSE = "CLOSE"


@dataclass
class Signal:
    action: SignalAction
    reason: str
    stop_distance: float = 0.0
    take_distance: float = 0.0


@dataclass
class Trade:
    id: int
    symbol: str
    side: Side
    volume: float
    entry_price: float
    entry_time: datetime
    stop_loss: float
    take_profit: float
    exit_price: Optional[float] = None
    exit_time: Optional[datetime] = None
    pnl: float = 0.0
    commission: float = 0.0
    status: str = "OPEN"
    reason: str = ""

    @property
    def is_open(self) -> bool:
        return self.status == "OPEN"


@dataclass
class AccountState:
    balance: float
    equity: float
    open_trades: list[Trade] = field(default_factory=list)
    closed_trades: list[Trade] = field(default_factory=list)
    daily_pnl: float = 0.0
    day_marker: Optional[str] = None
