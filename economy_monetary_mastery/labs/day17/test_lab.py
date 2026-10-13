import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_home_return_compounds():
    assert m.home_return(0.10, 0.05) == pytest.approx(0.155)
    assert m.home_return(0.10, -0.10) == pytest.approx(-0.01)


def test_hedged_return():
    assert m.hedged_return(0.10, 0.05, 0.04) == pytest.approx(1.10 * 1.05 / 1.04 - 1)


def test_vnd_returns():
    idx = pd.to_datetime(["2024-01-02", "2024-01-03"])
    r = m.vnd_returns(pd.Series([100.0, 110.0], idx), pd.Series([25000.0, 25500.0], idx))
    assert r.name == "vnd_return"
    assert r.tolist() == pytest.approx([1.1 * 1.02 - 1])


def test_vnd_returns_forward_fills_fx_holidays():
    idx = pd.to_datetime(["2024-01-02", "2024-01-03", "2024-01-04"])
    fx = pd.Series([25000.0, 25500.0], pd.to_datetime(["2024-01-02", "2024-01-03"]))
    r = m.vnd_returns(pd.Series([100.0, 110.0, 121.0], idx), fx)
    assert len(r) == 2
    assert r.iloc[-1] == pytest.approx(0.10)


def test_net_return():
    expected = 1.10 * (1 - 0.0020) * (1 - 0.0050) ** 2 - 1
    assert m.net_return(0.10, 20, 50) == pytest.approx(expected)
