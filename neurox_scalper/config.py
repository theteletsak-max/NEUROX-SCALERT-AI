"""Configuration models and loaders for NEUROX Scalper AI."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass
class StrategyConfig:
    """Scalping signal parameters."""

    fast_ema: int = 9
    slow_ema: int = 21
    rsi_period: int = 14
    rsi_buy_max: float = 65.0
    rsi_sell_min: float = 35.0
    atr_period: int = 14
    stop_atr_mult: float = 1.2
    take_atr_mult: float = 1.8
    min_atr_pips: float = 2.0


@dataclass
class RiskConfig:
    """Position sizing and account risk limits."""

    risk_per_trade_pct: float = 0.5
    max_daily_loss_pct: float = 3.0
    max_open_trades: int = 1
    max_spread_pips: float = 2.0
    pip_size: float = 0.0001
    contract_size: float = 100_000.0


@dataclass
class SessionConfig:
    """Optional London/NY overlap filter (UTC hours)."""

    enabled: bool = True
    start_hour_utc: int = 12
    end_hour_utc: int = 16


@dataclass
class EngineConfig:
    """Runtime and backtest settings."""

    symbol: str = "EURUSD"
    timeframe: str = "M5"
    initial_balance: float = 10_000.0
    commission_per_lot: float = 7.0
    default_spread_pips: float = 1.0
    seed: int = 42


@dataclass
class RobotConfig:
    """Top-level robot configuration."""

    strategy: StrategyConfig = field(default_factory=StrategyConfig)
    risk: RiskConfig = field(default_factory=RiskConfig)
    session: SessionConfig = field(default_factory=SessionConfig)
    engine: EngineConfig = field(default_factory=EngineConfig)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "RobotConfig":
        return cls(
            strategy=StrategyConfig(**data.get("strategy", {})),
            risk=RiskConfig(**data.get("risk", {})),
            session=SessionConfig(**data.get("session", {})),
            engine=EngineConfig(**data.get("engine", {})),
        )


def load_config(path: str | Path | None = None) -> RobotConfig:
    """Load YAML config or return defaults."""
    if path is None:
        return RobotConfig()
    with open(path, encoding="utf-8") as fh:
        raw = yaml.safe_load(fh) or {}
    return RobotConfig.from_dict(raw)


def save_config(config: RobotConfig, path: str | Path) -> None:
    """Write config to YAML."""
    with open(path, "w", encoding="utf-8") as fh:
        yaml.safe_dump(config.to_dict(), fh, sort_keys=False)
