import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
S = pd.Series(np.arange(100.0, 120.0), index=pd.date_range("2024-01-01", periods=20, freq="D"))


def test_event_window_values():
    w = m.event_window(S, [pd.Timestamp("2024-01-06")], before=2, after=2)
    assert list(w.index) == [-2, -1, 0, 1, 2]
    assert list(w.columns) == [pd.Timestamp("2024-01-06")]
    assert w.iloc[:, 0].tolist() == pytest.approx(
        [103 / 105 - 1, 104 / 105 - 1, 0.0, 106 / 105 - 1, 107 / 105 - 1])


def test_events_out_of_range_or_missing_are_skipped():
    w = m.event_window(S, [pd.Timestamp("2024-01-01"), pd.Timestamp("2025-01-01"),
                           pd.Timestamp("2024-01-10")], before=2, after=2)
    assert list(w.columns) == [pd.Timestamp("2024-01-10")]


def test_average_path():
    w = m.event_window(S, [pd.Timestamp("2024-01-06"), pd.Timestamp("2024-01-10")], 1, 1)
    avg = m.average_path(w)
    assert avg.loc[0] == 0.0
    assert avg.loc[1] == pytest.approx(((106 / 105 - 1) + (110 / 109 - 1)) / 2)


def test_dollar_beta():
    rng = np.random.default_rng(1)
    usd = pd.Series(rng.normal(0, 0.005, 300))
    em = pd.DataFrame({"a": 1.5 * usd, "b": -0.5 * usd})
    assert m.dollar_beta(em, usd).tolist() == pytest.approx([1.5, -0.5])
