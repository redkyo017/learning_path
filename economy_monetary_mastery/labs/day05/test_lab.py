import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_duration_approximation():
    assert m.duration_price_change(100.0, 6.0, 0.02) == pytest.approx(-12.0)
    assert m.duration_price_change(100.0, 6.0, -0.01) == pytest.approx(6.0)


def test_convexity_adjustment():
    # -D*dy*V + 0.5*C*dy^2*V = -12 + 0.8
    assert m.convexity_price_change(100.0, 6.0, 40.0, 0.02) == pytest.approx(-11.2)


def test_equity_after_marking():
    assert m.equity_after_marking(16.0, 15.1) == pytest.approx(0.9)
    assert m.equity_after_marking(16.0, -2.0) == pytest.approx(18.0)


def test_drawdowns():
    p = pd.Series([100.0, 120.0, 90.0, 130.0])
    assert m.drawdown_series(p).tolist() == pytest.approx([0, 0, -0.25, 0])
    assert m.max_drawdown(p) == pytest.approx(-0.25)


def test_max_drawdown_of_monotonic_series_is_zero():
    assert m.max_drawdown(pd.Series([1.0, 2.0, 3.0])) == 0
