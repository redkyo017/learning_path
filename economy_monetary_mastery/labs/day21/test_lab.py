import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_cdp_math():
    assert m.max_mint(150.0, 1.5) == pytest.approx(100.0)
    assert m.liquidation_price(1.0, 1000.0, 1.5) == pytest.approx(1500.0)


def test_liquidations_each_vault_once():
    vaults = [{"amount": 1.0, "debt": 1000.0}, {"amount": 1.0, "debt": 500.0}]
    assert m.liquidations(vaults, [2000.0, 1400.0, 700.0, 600.0], 1.5) == [(1, 0), (2, 1)]


def test_terra_step():
    s = m.terra_spiral(100.0, 10.0, 50.0, [0.5])
    assert len(s) == 1
    assert s[0]["step"] == 1 and s[0]["status"] == "ok"
    assert s[0]["ust_supply"] == pytest.approx(50.0)
    assert s[0]["luna_supply"] == pytest.approx(11.0)
    assert s[0]["luna_price"] == pytest.approx(450.0 / 11.0)


def test_terra_collapse_stops():
    s = m.terra_spiral(100.0, 10.0, 5.0, [0.6, 0.5])
    assert len(s) == 1 and s[0]["status"] == "collapsed" and s[0]["luna_price"] == 0.0


def test_spiral_accelerates():
    s = m.terra_spiral(1000.0, 10.0, 60.0, [0.2] * 5)
    prices = [x["luna_price"] for x in s]
    assert all(b < a for a, b in zip(prices, prices[1:]))


def test_reserve_coverage():
    assert m.reserve_coverage(98.0, 100.0) == pytest.approx(0.98)
    with pytest.raises(ValueError):
        m.reserve_coverage(1.0, 0.0)
