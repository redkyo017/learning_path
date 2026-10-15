import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.date_range("2020-01-31", periods=8, freq="ME")


def regimes():
    growth = pd.Series([1, 2, 3, 4, 3, 2, 1, 0], IDX, dtype=float)
    infl = pd.Series([1, 1, 1, 1, 2, 3, 4, 5], IDX, dtype=float)
    return m.classify_regime(growth, infl)


def test_classify_regime():
    r = regimes()
    assert r.index[0] == IDX[3]
    assert r.tolist() == ["goldilocks", "reflation", "stagflation", "stagflation",
                          "stagflation"]


def test_flat_inflation_counts_as_not_rising():
    assert regimes().iloc[0] == "goldilocks"


def test_rolling_zscore():
    z = m.rolling_zscore(pd.Series([1.0, 2.0, 3.0, 4.0, 5.0]), 3)
    assert z.isna().sum() == 2
    assert z.iloc[2] == pytest.approx(1.0)


def test_surprise_z():
    assert m.surprise_z(0.3, 0.2, 0.1) == pytest.approx(1.0)
    with pytest.raises(ValueError):
        m.surprise_z(0.3, 0.2, 0.0)


def test_regime_mean_returns():
    rets = pd.DataFrame({"spy": [0.01, 0.02, -0.01, -0.03, -0.02]}, index=IDX[3:])
    out = m.regime_mean_returns(rets, regimes())
    assert out.loc["goldilocks", "spy"] == pytest.approx(0.01)
    assert out.loc["reflation", "spy"] == pytest.approx(0.02)
    assert out.loc["stagflation", "spy"] == pytest.approx(-0.02)
