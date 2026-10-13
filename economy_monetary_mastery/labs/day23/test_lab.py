import math

import pandas as pd
import pytest

from common.data import load_funding
from common.labimpl import load_impl

m = load_impl(__file__)


def test_annualized_funding():
    assert m.annualized_funding(pd.Series([0.0001] * 9)) == pytest.approx(0.0001 * 3 * 365)


def test_basis():
    assert m.basis_pct(100.0, 102.0) == pytest.approx(0.02)
    assert m.annualized_basis(100.0, 102.0, 90) == pytest.approx(0.02 * 365 / 90)
    with pytest.raises(ValueError):
        m.annualized_basis(100.0, 102.0, 0)


def test_cash_and_carry_locks_basis_at_convergence():
    assert m.cash_and_carry_pnl(100.0, 102.0, 110.0, 110.0, 1.0) == pytest.approx(2.0)
    assert m.cash_and_carry_pnl(100.0, 102.0, 80.0, 80.0, 2.0) == pytest.approx(4.0)


def test_funding_pnl():
    rates = [0.0001, -0.00005, 0.0002]
    assert m.funding_pnl(10_000.0, rates, "short") == pytest.approx(2.5)
    assert m.funding_pnl(10_000.0, rates, "long") == pytest.approx(-2.5)
    with pytest.raises(ValueError):
        m.funding_pnl(10_000.0, rates, "flat")


def test_snapshot_funding_is_sane():
    v = m.annualized_funding(load_funding())
    assert math.isfinite(v) and -1.0 < v < 2.0
