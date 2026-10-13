import numpy as np
import pandas as pd
import pytest

from common import quant


@pytest.fixture
def p():
    return pd.Series([100.0, 120.0, 90.0, 130.0],
                     index=pd.date_range("2020-01-01", periods=4, freq="D"))


def test_returns(p):
    assert quant.simple_returns(p).tolist() == pytest.approx([0.2, -0.25, 130 / 90 - 1])
    assert quant.log_returns(p).sum() == pytest.approx(np.log(1.3))


def test_drawdown(p):
    assert quant.drawdown_series(p).tolist() == pytest.approx([0, 0, -0.25, 0])
    assert quant.max_drawdown(p) == pytest.approx(-0.25)


def test_cagr_uses_calendar_time():
    s = pd.Series([100.0, 200.0], index=pd.to_datetime(["2010-01-01", "2020-01-01"]))
    years = (s.index[-1] - s.index[0]).days / 365.25
    assert quant.cagr(s) == pytest.approx(2 ** (1 / years) - 1)


def test_vol_and_sharpe():
    r = pd.Series([0.01, -0.005] * 126)
    assert quant.annualize_vol(r) == pytest.approx(r.std(ddof=1) * np.sqrt(252))
    assert quant.sharpe(r) == pytest.approx(r.mean() / r.std(ddof=1) * np.sqrt(252))
    rf = 0.0252
    ex = r - rf / 252
    assert quant.sharpe(r, rf=rf) == pytest.approx(ex.mean() / ex.std(ddof=1) * np.sqrt(252))


def test_equity_curve():
    assert quant.equity_curve(pd.Series([0.1, -0.1])).tolist() == pytest.approx([1.1, 0.99])


def test_dataframe_support(p):
    df = pd.DataFrame({"a": p, "b": p * 2})
    assert list(quant.max_drawdown(df)) == pytest.approx([-0.25, -0.25])
