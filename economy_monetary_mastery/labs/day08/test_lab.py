import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_pv():
    assert m.pv_cashflows([100, 100, 100], 0.1) == pytest.approx(
        100 / 1.1 + 100 / 1.21 + 100 / 1.331)


def test_gordon_and_duration():
    assert m.gordon_value(5, 0.08, 0.03) == pytest.approx(100)
    assert m.equity_duration(0.08, 0.03) == pytest.approx(20)


@pytest.mark.parametrize("r,g", [(0.03, 0.03), (0.02, 0.05)])
def test_gordon_rejects_r_le_g(r, g):
    with pytest.raises(ValueError):
        m.gordon_value(5, r, g)


def test_long_duration_cashflows_fall_more():
    growth = [0.0] * 9 + [1000.0]
    value = [100.0] * 10
    g = m.rate_shock_pct(growth, 0.08, 0.01)
    v = m.rate_shock_pct(value, 0.08, 0.01)
    assert g < v < 0
    assert g == pytest.approx((1.08 / 1.09) ** 10 - 1)


def test_beta_and_correlation():
    rng = np.random.default_rng(0)
    mkt = pd.Series(rng.normal(0, 0.01, 500))
    asset = 2 * mkt + 0.0001
    assert m.beta(asset, mkt) == pytest.approx(2.0)
    assert m.correlation(asset, mkt) == pytest.approx(1.0)
