import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_forward_rate_cip():
    assert m.forward_rate(25000, 0.05, 0.04, 1.0) == pytest.approx(25000 * 1.05 / 1.04)
    assert m.forward_rate(25000, 0.05, 0.04, 0.25) == pytest.approx(
        25000 * 1.0125 / 1.01)


def test_forward_points_sign():
    assert m.forward_points(25000, 0.05, 0.04, 1.0) > 0   # higher quote rate → forward premium
    assert m.forward_points(25000, 0.03, 0.04, 1.0) < 0


def test_cip_deviation():
    fair = m.forward_rate(25000, 0.05, 0.04, 1.0)
    assert m.cip_deviation_bp(25000, fair, 0.05, 0.04, 1.0) == pytest.approx(0.0)
    assert m.cip_deviation_bp(25000, fair * 1.001, 0.05, 0.04, 1.0) == pytest.approx(10.0)


def test_carry_trade():
    assert m.carry_trade_return(25000, 25000, 0.05, 0.04, 1.0) == pytest.approx(0.01)
    # target currency depreciates 5% (25,000 → 26,250 per USD): carry wiped out
    assert m.carry_trade_return(25000, 26250, 0.05, 0.04, 1.0) == pytest.approx(-0.04)


def test_fx_return():
    assert m.fx_return(25000, 26250) == pytest.approx(0.05)


def test_bad_time():
    with pytest.raises(ValueError):
        m.forward_rate(25000, 0.05, 0.04, -1)
