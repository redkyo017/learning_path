import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_vol_and_sharpe():
    r = pd.Series([0.01, -0.005] * 126)
    assert m.annualize_vol(r) == pytest.approx(r.std(ddof=1) * np.sqrt(252))
    assert m.sharpe(r) == pytest.approx(r.mean() / r.std(ddof=1) * np.sqrt(252))
    ex = r - 0.0252 / 252
    assert m.sharpe(r, rf=0.0252) == pytest.approx(ex.mean() / ex.std(ddof=1) * np.sqrt(252))


def test_portfolio_returns():
    df = pd.DataFrame({"a": [0.1, 0.0], "b": [0.0, 0.2]})
    assert m.portfolio_returns(df, [0.5, 0.5]).tolist() == pytest.approx([0.05, 0.1])


def test_portfolio_vol():
    cov = np.array([[0.04, 0.0], [0.0, 0.04]])
    assert m.portfolio_vol(np.array([0.5, 0.5]), cov) == pytest.approx(np.sqrt(0.02))


def test_min_variance():
    w = m.min_variance_weights(np.array([[0.04, 0.0], [0.0, 0.01]]))
    assert w == pytest.approx([0.2, 0.8])
    assert w.sum() == pytest.approx(1.0)


def test_frontier_perfect_hedge():
    cov = np.array([[0.04, -0.04], [-0.04, 0.04]])
    f = m.frontier_two_asset([0.08, 0.03], cov)
    assert list(f.columns) == ["w1", "ret", "vol"] and len(f) == 101
    mid = f.loc[np.isclose(f["w1"], 0.5)].iloc[0]
    assert mid["vol"] == pytest.approx(0.0, abs=1e-9)
    assert mid["ret"] == pytest.approx(0.055)
    assert f["w1"].iloc[0] == 0.0 and f["w1"].iloc[-1] == 1.0
