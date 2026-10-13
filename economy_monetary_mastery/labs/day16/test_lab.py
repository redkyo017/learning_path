import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_sbv_band():
    assert m.sbv_band(25000) == pytest.approx((23750.0, 26250.0))


def test_within_band():
    idx = pd.date_range("2024-01-01", periods=3, freq="D")
    central = pd.Series([24000.0] * 3, idx)
    market = pd.Series([24500.0, 25300.0, 22700.0], idx)
    assert m.within_band(market, central).tolist() == [True, False, False]


@pytest.mark.parametrize("price,tick", [(9_990, 10), (10_000, 50), (49_950, 50), (50_000, 100)])
def test_hose_tick(price, tick):
    assert m.hose_tick(price) == tick


@pytest.mark.parametrize("ref,exchange,expected", [
    (25_000, "HOSE", (23_250, 26_750)),
    (10_250, "HOSE", (9_540, 10_950)),
    (10_250, "HNX", (9_300, 11_200)),
    (10_000, "UPCOM", (8_500, 11_500)),
])
def test_price_limits(ref, exchange, expected):
    assert m.price_limits(ref, exchange) == expected


def test_unknown_exchange():
    with pytest.raises(ValueError):
        m.price_limits(10_000, "NYSE")


def test_flag_limit_moves():
    close = pd.Series([25_000.0, 26_750.0, 27_000.0, 25_150.0])
    assert m.flag_limit_moves(close, "HOSE").tolist() == [False, True, False, True]


def test_foreign_room():
    assert m.foreign_room(0.49, 400, 1000) == pytest.approx(90)
    assert m.foreign_room(0.30, 300, 1000) == pytest.approx(0)
