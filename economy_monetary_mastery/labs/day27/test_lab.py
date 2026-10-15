import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_kelly():
    assert m.kelly_fraction(0.08, 0.2) == pytest.approx(2.0)
    assert m.fractional_kelly(0.08, 0.2) == pytest.approx(1.0)
    with pytest.raises(ValueError):
        m.kelly_fraction(0.08, 0.0)


def test_vol_target_weights():
    r = pd.Series([0.01, -0.01] * 30)
    w = m.vol_target_weights(r, 0.10, 20, 2.0)
    expected = (0.10 / (r.rolling(20).std() * np.sqrt(252))).shift(1).clip(0, 2.0).fillna(0.0)
    pd.testing.assert_series_equal(w, expected, check_names=False)
    assert w.iloc[:20].eq(0).all()


def test_vol_target_caps_leverage():
    r = pd.Series([1e-6, -1e-6] * 30)
    assert m.vol_target_weights(r, 0.10, 20, 2.0).iloc[-1] == pytest.approx(2.0)


def test_breakeven_cost():
    gross = pd.Series([0.01, 0.0, 0.02])
    turnover = pd.Series([1.0, 0.0, 2.0])
    assert m.breakeven_cost_bps(gross, turnover) == pytest.approx(100.0)
    assert m.breakeven_cost_bps(gross, pd.Series([0.0, 0.0, 0.0])) == float("inf")


def test_drawdown_brake_is_lagged():
    eq = pd.Series([1.0, 1.2, 0.9, 0.95, 1.3])
    assert m.drawdown_brake(eq).tolist() == [1.0, 1.0, 1.0, 0.5, 0.5]
