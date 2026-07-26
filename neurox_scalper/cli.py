"""Command-line interface for NEUROX Scalper AI."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from neurox_scalper.config import RobotConfig, load_config, save_config
from neurox_scalper.data import generate_synthetic_ohlc, load_ohlc_csv
from neurox_scalper.engine import TradingEngine, format_report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="neurox",
        description="NEUROX Scalper AI — forex scalping robot (backtest & paper sim)",
    )
    parser.add_argument("--config", type=Path, help="Path to YAML config")
    sub = parser.add_subparsers(dest="command", required=True)

    init_p = sub.add_parser("init-config", help="Write a default config YAML")
    init_p.add_argument("-o", "--output", type=Path, default=Path("config.yaml"))

    bt = sub.add_parser("backtest", help="Run a backtest on CSV or synthetic data")
    bt.add_argument("--csv", type=Path, help="OHLC CSV with time,open,high,low,close")
    bt.add_argument("--bars", type=int, default=3000, help="Synthetic bars if no CSV")
    bt.add_argument("--json", action="store_true", help="Emit JSON report")
    bt.add_argument("--export-trades", type=Path, help="Write closed trades CSV")

    paper = sub.add_parser("paper", help="Paper-trade the latest N bars (replay)")
    paper.add_argument("--csv", type=Path, help="OHLC CSV")
    paper.add_argument("--bars", type=int, default=500, help="Synthetic bars if no CSV")
    paper.add_argument("--tail", type=int, default=200, help="Only simulate last N bars")

    return parser


def cmd_init_config(args: argparse.Namespace) -> int:
    cfg = load_config(args.config) if args.config else RobotConfig()
    save_config(cfg, args.output)
    print(f"Wrote default config to {args.output}")
    return 0


def _load_frame(args: argparse.Namespace, cfg: RobotConfig):
    if getattr(args, "csv", None):
        return load_ohlc_csv(args.csv)
    minutes = 5
    if cfg.engine.timeframe.upper().startswith("M"):
        try:
            minutes = int(cfg.engine.timeframe[1:])
        except ValueError:
            minutes = 5
    return generate_synthetic_ohlc(
        bars=args.bars,
        timeframe_minutes=minutes,
        seed=cfg.engine.seed,
    )


def cmd_backtest(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    df = _load_frame(args, cfg)
    engine = TradingEngine(cfg)
    report = engine.run(df)

    if args.json:
        print(json.dumps(report.as_dict(), indent=2))
    else:
        print(format_report(report))

    if args.export_trades:
        _export_trades(engine, args.export_trades)
        print(f"Exported trades to {args.export_trades}")
    return 0


def cmd_paper(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    df = _load_frame(args, cfg)
    if args.tail > 0 and len(df) > args.tail:
        df = df.iloc[-args.tail :]
    engine = TradingEngine(cfg)
    report = engine.run(df)
    print("=== NEUROX Scalper AI — Paper Replay ===")
    print(format_report(report))
    open_n = len(engine.broker.account.open_trades)
    print(f"Open trades left : {open_n}")
    return 0


def _export_trades(engine: TradingEngine, path: Path) -> None:
    import csv

    rows = engine.broker.account.closed_trades
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "id",
                "symbol",
                "side",
                "volume",
                "entry_time",
                "entry_price",
                "exit_time",
                "exit_price",
                "pnl",
                "commission",
                "reason",
            ],
        )
        writer.writeheader()
        for t in rows:
            writer.writerow(
                {
                    "id": t.id,
                    "symbol": t.symbol,
                    "side": t.side.value,
                    "volume": t.volume,
                    "entry_time": t.entry_time.isoformat(),
                    "entry_price": t.entry_price,
                    "exit_time": t.exit_time.isoformat() if t.exit_time else "",
                    "exit_price": t.exit_price,
                    "pnl": t.pnl,
                    "commission": t.commission,
                    "reason": t.reason,
                }
            )


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "init-config":
        return cmd_init_config(args)
    if args.command == "backtest":
        return cmd_backtest(args)
    if args.command == "paper":
        return cmd_paper(args)
    parser.error(f"unknown command {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
