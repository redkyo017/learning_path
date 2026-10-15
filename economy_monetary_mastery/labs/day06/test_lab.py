import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


@pytest.fixture
def inputs():
    weekly = pd.date_range("2022-01-05", "2024-02-28", freq="W-WED")
    daily = pd.date_range("2022-01-01", "2024-02-29", freq="D")
    fed = pd.Series(8_000_000.0, index=weekly)
    res = pd.Series(3_000.0, index=weekly)
    rate = pd.Series(5.0, index=daily)
    cpi = pd.Series(100 * 1.03 ** (np.arange(26) / 12),
                    index=pd.date_range("2022-01-01", periods=26, freq="MS"))
    return fed, res, rate, cpi


def test_columns_units_and_length(inputs):
    df = m.plumbing_dashboard(*inputs)
    assert list(df.columns) == ["fed_assets_busd", "reserves_busd", "policy_rate",
                                "cpi_yoy", "real_rate"]
    assert len(df) == 14
    assert df.index[0] == pd.Timestamp("2023-01-31")
    row = df.iloc[0]
    assert row["fed_assets_busd"] == pytest.approx(8000)
    assert row["reserves_busd"] == pytest.approx(3000)
    assert row["policy_rate"] == pytest.approx(0.05)
    assert row["cpi_yoy"] == pytest.approx(0.03)
    assert row["real_rate"] == pytest.approx(1.05 / 1.03 - 1)


def test_no_nans(inputs):
    assert not m.plumbing_dashboard(*inputs).isna().any().any()


@pytest.mark.parametrize("r,expected", [(0.02, "restrictive"), (0.005, "neutral"),
                                        (-0.03, "accommodative"), (0.01, "neutral")])
def test_stance(r, expected):
    assert m.stance(r) == expected
