import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_swap_no_fee():
    p = m.ConstantProductPool(100.0, 10_000.0, fee=0.0)
    assert p.price() == pytest.approx(100.0)
    dy = p.swap_x_for_y(10.0)
    assert dy == pytest.approx(10_000 - 1_000_000 / 110)
    assert (p.x, p.y) == (pytest.approx(110.0), pytest.approx(1_000_000 / 110))
    assert p.k() == pytest.approx(1_000_000)


def test_fee_grows_k_and_reverse_swap():
    p = m.ConstantProductPool(100.0, 10_000.0)
    k0 = p.k()
    p.swap_x_for_y(10.0)
    assert p.k() > k0
    dx = p.swap_y_for_x(500.0)
    assert dx > 0 and p.k() > k0


def test_invalid_swaps():
    p = m.ConstantProductPool(100.0, 10_000.0)
    with pytest.raises(ValueError):
        p.swap_x_for_y(0.0)
    with pytest.raises(ValueError):
        p.swap_y_for_x(-1.0)


@pytest.mark.parametrize("r,il", [(1.0, 0.0), (4.0, -0.2), (0.25, -0.2)])
def test_impermanent_loss(r, il):
    assert m.impermanent_loss(r) == pytest.approx(il)


def test_lp_vs_hold():
    lp, hold = m.lp_vs_hold(100.0, 10_000.0, 400.0)
    assert hold == pytest.approx(50_000.0) and lp == pytest.approx(40_000.0)


def test_sandwich_profits_without_fees_and_hurts_victim():
    r = m.sandwich(100.0, 10_000.0, 0.0, victim_dx=10.0, attacker_dx=5.0)
    assert r["attacker_profit_x"] > 0
    assert r["victim_dy"] < r["victim_dy_no_attack"]


def test_sandwich_unprofitable_for_tiny_victim_with_fees():
    r = m.sandwich(100.0, 10_000.0, 0.003, victim_dx=0.01, attacker_dx=5.0)
    assert r["attacker_profit_x"] < 0
