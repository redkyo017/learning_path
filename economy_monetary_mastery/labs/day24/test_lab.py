import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
BTC = 100_000_000


def test_btc_supply_at_halvings():
    assert m.btc_supply(840_000) == 19_687_500 * BTC
    assert m.btc_supply(630_000) == 18_375_000 * BTC


def test_btc_inflation():
    assert m.btc_annual_inflation(840_000) == pytest.approx(52_560 * 3.125 / 19_687_500)
    assert m.btc_annual_inflation(630_000) == pytest.approx(52_560 * 6.25 / 18_375_000)


def m2_series():
    idx = pd.date_range("2019-01-01", periods=36, freq="MS")
    return pd.Series(100 * 1.06 ** (np.arange(36) / 12), idx)


def test_m2_growth():
    g = m.m2_growth(m2_series())
    assert len(g) == 24 and g.tolist() == pytest.approx([0.06] * 24)


def test_compare_issuance():
    df = m.compare_issuance({2020: 630_000, 2021: 680_000}, m2_series())
    assert list(df.columns) == ["btc_inflation", "m2_growth"]
    assert list(df.index) == [2020, 2021]
    assert df.loc[2020, "m2_growth"] == pytest.approx(0.06)
    assert df.loc[2020, "btc_inflation"] == pytest.approx(52_560 * 6.25 / 18_375_000)
