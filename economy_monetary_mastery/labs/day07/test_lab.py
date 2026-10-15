import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_known_price():
    assert m.bond_price(100, 0.05, 0.06, 5, 2) == pytest.approx(95.7349, abs=1e-3)


def test_par_and_zero():
    assert m.bond_price(100, 0.04, 0.04, 10) == pytest.approx(100)
    assert m.bond_price(100, 0.0, 0.04, 10, 2) == pytest.approx(100 / 1.02 ** 20)


def test_zero_coupon_durations_and_convexity():
    assert m.macaulay_duration(100, 0.0, 0.04, 10, 2) == pytest.approx(10)
    assert m.modified_duration(100, 0.0, 0.04, 10, 2) == pytest.approx(10 / 1.02)
    assert m.convexity(100, 0.0, 0.04, 10, 2) == pytest.approx(10 * 10.5 / 1.02 ** 2)


def test_duration_predicts_small_moves():
    p0 = m.bond_price(100, 0.05, 0.05, 10)
    p1 = m.bond_price(100, 0.05, 0.0501, 10)
    approx = -m.modified_duration(100, 0.05, 0.05, 10) * p0 * 0.0001
    assert (p1 - p0) == pytest.approx(approx, rel=1e-3)


def test_coupon_bond_duration_below_maturity():
    assert m.macaulay_duration(100, 0.05, 0.05, 10) < 10


def test_inversions():
    idx = pd.date_range("2024-01-01", periods=5, freq="D")
    slope = m.curve_slope(pd.Series([4.5, 4.0, 3.9, 4.4, 3.5], idx),
                          pd.Series([4.0, 4.1, 4.1, 4.1, 3.9], idx))
    assert slope.tolist() == pytest.approx([0.5, -0.1, -0.2, 0.3, -0.4])
    assert m.inversion_periods(slope) == [
        (pd.Timestamp("2024-01-02"), pd.Timestamp("2024-01-03")),
        (pd.Timestamp("2024-01-05"), pd.Timestamp("2024-01-05")),
    ]
