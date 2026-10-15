import pandas as pd
import pytest

from common import fetch
from common.fetch import parse_fred_text, parse_vci_chart


def test_parse_fred_text_new_header_and_missing_dots():
    text = "observation_date,DFF\n2024-01-01,5.33\n2024-01-02,.\n2024-01-03,5.31\n"
    s = parse_fred_text(text, "DFF")
    assert s.name == "DFF"
    assert isinstance(s.index, pd.DatetimeIndex)
    assert list(s.values) == [5.33, 5.31]


def test_parse_fred_text_old_header():
    s = parse_fred_text("DATE,X\n2020-01-01,1.5\n", "X")
    assert s.iloc[0] == 1.5


def test_parse_vci_chart():
    payload = [{"symbol": "VNINDEX", "c": [1660.7, 1666.48],
                "t": ["1758844800", "1759104000"], "o": [1, 2], "h": [1, 2], "l": [1, 2]}]
    s = parse_vci_chart(payload, "VNINDEX")
    assert s.name == "VNINDEX" and s.dtype == float
    assert s.index.name == "date"
    assert list(s.index) == [pd.Timestamp("2025-09-26"), pd.Timestamp("2025-09-29")]
    assert s.tolist() == [1660.7, 1666.48]


def test_parse_vci_chart_missing_symbol():
    with pytest.raises(ValueError, match="FPT"):
        parse_vci_chart([{"symbol": "VNINDEX", "c": [1.0], "t": ["1758844800"]}], "FPT")


def test_parse_vci_chart_vn_midnight_and_utc_midnight_same_date():
    # 2025-09-29 00:00 +07 == 2025-09-28 17:00 UTC; 2025-09-29 00:00 UTC; both -> 2025-09-29
    vn_mid = 1759104000 - 7 * 3600
    payload = [{"symbol": "X", "c": [1.0, 2.0], "t": [str(vn_mid), str(1759104000)]}]
    s = parse_vci_chart(payload, "X")
    assert list(s.index) == [pd.Timestamp("2025-09-29")]


def test_vn_pages_backwards_when_capped(monkeypatch):
    day = 86400
    base = int(pd.Timestamp("2026-09-30", tz="UTC").timestamp())
    all_t = [base - i * day for i in range(30)][::-1]  # 30 daily bars, ascending
    calls = []

    def fake_post(url, json=None, **kw):
        calls.append(json["to"])
        eligible = [t for t in all_t if t <= json["to"]]
        chunk = eligible[-10:]  # server caps at 10 bars per request

        class R:
            def raise_for_status(self): pass
            def json(self_): return ([{"symbol": "X", "t": [str(t) for t in chunk],
                                       "c": [float(t % 1000) for t in chunk]}] if chunk else [])
        return R()

    monkeypatch.setattr(fetch.requests, "post", fake_post)
    s = fetch.vn("X", start="2026-09-01", end="2026-09-30")
    assert len(calls) >= 3
    assert s.index.min() == pd.Timestamp("2026-09-01") and s.index.is_monotonic_increasing
    assert s.index.is_unique
