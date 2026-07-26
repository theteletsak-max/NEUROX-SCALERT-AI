from neurox_scalper.config import RobotConfig, SessionConfig
from neurox_scalper.data import generate_synthetic_ohlc
from neurox_scalper.engine import TradingEngine


def test_backtest_runs_and_reports():
    cfg = RobotConfig()
    cfg.session = SessionConfig(enabled=False)
    df = generate_synthetic_ohlc(bars=1500, seed=99)
    engine = TradingEngine(cfg)
    report = engine.run(df)
    assert report.bars == 1500
    assert report.final_balance > 0
    assert report.trades >= 0
    d = report.as_dict()
    assert "profit_factor" in d


def test_cli_backtest_smoke(tmp_path):
    from neurox_scalper.cli import main

    code = main(["backtest", "--bars", "800", "--json"])
    assert code == 0
