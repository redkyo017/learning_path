import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
O = m.Order


def test_resting_orders_and_spread():
    ob = m.OrderBook()
    assert ob.submit(O("b1", "buy", 10, 99.0)) == []
    assert ob.submit(O("s1", "sell", 5, 101.0)) == []
    assert (ob.best_bid(), ob.best_ask(), ob.spread()) == (99.0, 101.0, 2.0)


def test_empty_book():
    ob = m.OrderBook()
    assert ob.best_bid() is None and ob.best_ask() is None and ob.spread() is None


def test_crossing_limit_trades_at_resting_price():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 5, 100.0))
    assert ob.submit(O("b1", "buy", 5, 101.0)) == [m.Trade("b1", "s1", 100.0, 5)]
    assert ob.best_ask() is None and ob.best_bid() is None


def test_partial_fill_rests_remainder():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 5, 100.0))
    assert ob.submit(O("b1", "buy", 8, 100.0)) == [m.Trade("b1", "s1", 100.0, 5)]
    assert ob.depth("buy") == [(100.0, 3)]


def test_time_priority_at_same_price():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 3, 100.0))
    ob.submit(O("s2", "sell", 3, 100.0))
    assert ob.submit(O("b1", "buy", 4, 100.0)) == [m.Trade("b1", "s1", 100.0, 3),
                                                   m.Trade("b1", "s2", 100.0, 1)]
    assert ob.depth("sell") == [(100.0, 2)]


def test_sell_side_crossing():
    ob = m.OrderBook()
    ob.submit(O("b1", "buy", 2, 100.0))
    ob.submit(O("b2", "buy", 2, 99.0))
    assert ob.submit(O("s1", "sell", 3, 99.0)) == [m.Trade("b1", "s1", 100.0, 2),
                                                   m.Trade("b2", "s1", 99.0, 1)]


def test_market_order_sweeps_levels_and_discards_remainder():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 2, 100.0))
    ob.submit(O("s2", "sell", 3, 101.0))
    trades = ob.submit(O("b1", "buy", 10))
    assert [(t.price, t.qty) for t in trades] == [(100.0, 2), (101.0, 3)]
    assert ob.depth("sell") == [] and ob.depth("buy") == []
    assert m.average_fill_price(trades) == pytest.approx(100.6)


def test_depth_aggregates_best_first():
    ob = m.OrderBook()
    for oid, q, p in [("a", 1, 99.0), ("b", 2, 98.0), ("c", 3, 99.0)]:
        ob.submit(O(oid, "buy", q, p))
    assert ob.depth("buy") == [(99.0, 4), (98.0, 2)]


@pytest.mark.parametrize("order", [O("x", "buy", 0, 100.0), O("x", "hold", 1, 100.0),
                                   O("x", "buy", -2, 100.0)])
def test_invalid_orders_rejected(order):
    with pytest.raises(ValueError):
        m.OrderBook().submit(order)
