import pandas as pd
import pytest

import common.data as data


@pytest.fixture
def snap(tmp_path, monkeypatch):
    monkeypatch.setattr(data, "DATA_DIR", tmp_path)
    (tmp_path / "fred").mkdir()
    (tmp_path / "fred" / "DFF.csv").write_text("date,DFF\n2024-01-01,5.33\n2024-01-02,5.31\n")
    (tmp_path / "prices").mkdir()
    (tmp_path / "prices" / "SPY.csv").write_text("date,close\n2024-01-02,470.0\n2024-01-03,468.0\n")
    (tmp_path / "prices" / "TLT.csv").write_text("date,close\n2024-01-02,98.0\n2024-01-03,99.0\n")
    return tmp_path


def test_load_fred_from_snapshot(snap):
    s = data.load_fred("DFF")
    assert s.name == "DFF" and len(s) == 2 and s.dtype == float


def test_load_prices_wide(snap):
    df = data.load_prices(["SPY", "TLT"])
    assert list(df.columns) == ["SPY", "TLT"]
    assert df.loc["2024-01-03", "TLT"] == 99.0


def test_load_prices_single_string(snap):
    assert list(data.load_prices("SPY").columns) == ["SPY"]


def test_missing_snapshot_message(snap):
    with pytest.raises(FileNotFoundError) as e:
        data.load_fred("NOPE")
    msg = str(e.value)
    assert "NOPE" in msg and "live=True" in msg


def test_normalize_vn_prices():
    stock = pd.Series([95.5, 96.0, 97.2])          # thousands of VND
    index = pd.Series([1250.3, 1260.1, 1270.0])     # points
    assert data.normalize_vn_prices(stock, "FPT").tolist() == [95500.0, 96000.0, 97200.0]
    assert data.normalize_vn_prices(index, "VNINDEX").tolist() == [1250.3, 1260.1, 1270.0]
    already = pd.Series([95500.0, 96000.0])
    assert data.normalize_vn_prices(already, "FPT").tolist() == [95500.0, 96000.0]
