import numpy as np
import pandas as pd
import pytest

from common import quant
from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.bdate_range("2020-01-01", periods=800)


def series(seed):
    rng = np.random.default_rng(seed)
    return pd.Series(100 * np.exp(np.cumsum(rng.normal(0.0003, 0.01, len(IDX)))), IDX)


def test_to_vnd_prices():
    p = pd.Series([100.0, 110.0], IDX[:2])
    fx = pd.Series([25000.0], IDX[:1])
    assert m.to_vnd_prices(p, fx).tolist() == [2_500_000.0, 2_750_000.0]


def test_scorecard_matches_reference_helpers():
    a, b = series(1), series(2)
    sc = m.scorecard({"a": a, "b": b})
    assert list(sc.index) == ["a", "b"]
    assert list(sc.columns) == ["cagr", "vol", "sharpe", "max_drawdown"]
    r = quant.simple_returns(a)
    assert sc.loc["a", "cagr"] == pytest.approx(quant.cagr(a))
    assert sc.loc["a", "vol"] == pytest.approx(quant.annualize_vol(r))
    assert sc.loc["a", "sharpe"] == pytest.approx(quant.sharpe(r))
    assert sc.loc["a", "max_drawdown"] == pytest.approx(quant.max_drawdown(a))


@pytest.mark.parametrize("dep,cost,expected", [(0.04, 0.01, "hedge"),
                                               (0.01, 0.03, "stay unhedged"),
                                               (0.02, 0.02, "stay unhedged")])
def test_hedge_decision(dep, cost, expected):
    assert m.hedge_decision(dep, cost) == expected
