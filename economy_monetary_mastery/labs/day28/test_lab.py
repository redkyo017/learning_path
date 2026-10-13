import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.bdate_range("2024-01-01", periods=30)
PRICES = pd.DataFrame({"up": 100 * 1.01 ** np.arange(30), "flat": [100.0] * 30,
                       "down": 100 * 0.99 ** np.arange(30)}, index=IDX)


def test_trend_signal():
    s = m.trend_signal(PRICES, 10)
    assert s.iloc[:10].eq(0).all().all()
    assert s.iloc[20].tolist() == [1, 0, -1]


def test_mean_reversion_signal():
    p = pd.Series([10.0] * 19 + [12.0])
    s = m.mean_reversion_signal(p, 20, 2.0)
    assert s.iloc[-1] == -1
    assert s.iloc[:-1].eq(0).all()
    assert m.mean_reversion_signal(pd.Series([10.0] * 19 + [8.0]), 20, 2.0).iloc[-1] == 1


def test_inverse_vol_weights():
    rets = pd.DataFrame({"a": [0.02, -0.02] * 15, "b": [0.01, -0.01] * 15}, index=IDX)
    w = m.inverse_vol_weights(rets, 10)
    assert w.index[0] == IDX[9]
    assert w.iloc[-1].tolist() == pytest.approx([1 / 3, 2 / 3])
    assert w.sum(axis=1).tolist() == pytest.approx([1.0] * len(w))


def test_cross_sectional_momentum():
    w = m.cross_sectional_momentum(PRICES, 5, 1)
    assert w.iloc[:5].eq(0).all().all()
    assert w.iloc[10].tolist() == [1.0, 0.0, 0.0]
    w2 = m.cross_sectional_momentum(PRICES, 5, 2)
    assert w2.iloc[10].tolist() == [0.5, 0.5, 0.0]


def test_combine_strategies():
    r = pd.DataFrame({"trend": [0.01, 0.02], "carry": [0.0, -0.01]})
    assert m.combine_strategies(r, {"trend": 0.5, "carry": 0.5}).tolist() == pytest.approx(
        [0.005, 0.005])
    with pytest.raises(ValueError):
        m.combine_strategies(r, {"value": 1.0})
