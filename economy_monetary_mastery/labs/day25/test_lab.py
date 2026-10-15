import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.bdate_range("2024-01-01", periods=3)


def test_always_long_matches_buy_and_hold():
    p = pd.Series([100.0, 101.0, 102.0], IDX)
    bt = m.backtest(p, pd.Series(1.0, IDX))
    assert list(bt.columns) == ["asset_ret", "position", "turnover", "cost", "strat_ret", "equity"]
    assert bt["position"].tolist() == [0.0, 1.0, 1.0]
    assert bt["equity"].iloc[-1] == pytest.approx(1.02)


def test_costs_charged_on_turnover():
    p = pd.Series([100.0, 101.0, 102.0], IDX)
    bt = m.backtest(p, pd.Series(1.0, IDX), cost_bps=10)
    assert bt["turnover"].tolist() == [0.0, 1.0, 0.0]
    assert bt["equity"].iloc[-1] == pytest.approx((1 + 0.01 - 0.001) * (102 / 101))


def test_flat_signal():
    p = pd.Series([100.0, 90.0, 120.0], IDX)
    assert m.backtest(p, pd.Series(0.0, IDX))["equity"].tolist() == [1.0, 1.0, 1.0]


def test_no_lookahead():
    rng = np.random.default_rng(0)
    idx = pd.bdate_range("2020-01-01", periods=300)
    p = pd.Series(100 * np.exp(np.cumsum(rng.normal(0, 0.01, 300))), idx)
    pos = m.backtest(p, m.momentum_signal(p, 20))["position"]
    p2 = p.copy()
    p2.iloc[200:] *= 0.5
    pos2 = m.backtest(p2, m.momentum_signal(p2, 20))["position"]
    assert pos.iloc[:201].equals(pos2.iloc[:201])


def test_momentum_signal():
    p = pd.Series([1.0, 2.0, 3.0, 2.0, 1.0])
    assert m.momentum_signal(p, 2).tolist() == [0.0, 0.0, 1.0, 0.0, 0.0]
