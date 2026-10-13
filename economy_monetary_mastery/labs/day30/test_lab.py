import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
GOOD = dict(dsr=0.97, is_sharpe=1.0, oos_sharpe=0.8, net_sharpe=0.9, benchmark_sharpe=0.5,
            n_trades=60, max_drawdown=-0.2, breakeven_cost_bps=40.0, assumed_cost_bps=10.0)


def test_good_strategy_passes():
    assert m.kill_checklist(GOOD) == []
    assert m.verdict(GOOD) == "paper-trade"


@pytest.mark.parametrize("change,failed", [
    ({"dsr": 0.9}, "deflated_sharpe"),
    ({"oos_sharpe": 0.4}, "oos_decay"),
    ({"net_sharpe": 0.5}, "beats_benchmark"),
    ({"n_trades": 29}, "sample_size"),
    ({"max_drawdown": -0.36}, "drawdown"),
    ({"breakeven_cost_bps": 19.0}, "cost_survival"),
])
def test_each_rule(change, failed):
    r = {**GOOD, **change}
    assert m.kill_checklist(r) == [failed]
    assert m.verdict(r) == "kill"


def test_missing_keys_named():
    with pytest.raises(ValueError, match="dsr"):
        m.kill_checklist({k: v for k, v in GOOD.items() if k != "dsr"})


def test_run_capstone_produces_full_report():
    rng = np.random.default_rng(7)
    idx = pd.bdate_range("2015-01-01", periods=1500)
    p = pd.Series(100 * np.exp(np.cumsum(rng.normal(0.0003, 0.01, 1500))), idx)
    r = m.run_capstone(p, [20, 60, 120], cost_bps=10)
    assert set(m.REQUIRED_KEYS) <= r.keys()
    assert r["chosen_lookback"] in (20, 60, 120)
    assert 0.0 <= r["dsr"] <= 1.0 and r["max_drawdown"] <= 0
    assert m.verdict(r) in ("paper-trade", "kill")
