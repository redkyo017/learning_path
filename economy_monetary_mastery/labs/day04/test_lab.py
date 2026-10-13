import math

import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_yoy_inflation():
    idx = pd.date_range("2020-01-01", periods=25, freq="MS")
    cpi = pd.Series(100 * 1.02 ** (np.arange(25) / 12), index=idx)
    yoy = m.yoy_inflation(cpi)
    assert len(yoy) == 13
    assert yoy.tolist() == pytest.approx([0.02] * 13)


def test_real_rate_exact_fisher():
    assert m.real_rate(0.05, 0.03) == pytest.approx(1.05 / 1.03 - 1)
    s = m.real_rate(pd.Series([0.05, 0.01]), pd.Series([0.03, 0.04]))
    assert s.tolist() == pytest.approx([1.05 / 1.03 - 1, 1.01 / 1.04 - 1])


def test_compound_and_cagr_are_inverses():
    assert m.compound(100, 0.07, 10) == pytest.approx(100 * 1.07 ** 10)
    assert m.cagr(100, 200, 10) == pytest.approx(2 ** 0.1 - 1)
    assert m.cagr(100, m.compound(100, 0.07, 10), 10) == pytest.approx(0.07)


def test_real_cagr():
    assert m.real_cagr(0.08, 0.03) == pytest.approx(1.08 / 1.03 - 1)


def test_years_to_double():
    assert m.years_to_double(0.07) == pytest.approx(math.log(2) / math.log(1.07))


def test_cagr_rejects_bad_inputs():
    with pytest.raises(ValueError):
        m.cagr(0, 100, 5)
    with pytest.raises(ValueError):
        m.cagr(100, 200, 0)
