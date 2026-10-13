import itertools

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_trinity_only_all_three_violates():
    for combo in itertools.product([True, False], repeat=3):
        assert m.trinity_violation(*combo) == all(combo)


def test_peg_breaks_when_reserves_would_cross_floor():
    assert m.defend_peg(100.0, [30.0, 30.0, 30.0], floor=20.0) == (3, [70.0, 40.0])


def test_peg_survives():
    assert m.defend_peg(100.0, [10.0, 10.0], floor=20.0) == (None, [90.0, 80.0])


def test_inflows_rebuild_reserves():
    assert m.defend_peg(50.0, [-20.0, 40.0], floor=20.0) == (None, [70.0, 30.0])


def test_rate_to_defend_uip():
    assert m.rate_to_defend(0.05, 0.20) == pytest.approx(0.26)


def test_import_cover():
    assert m.import_cover_months(90.0, 30.0) == pytest.approx(3.0)
    with pytest.raises(ValueError):
        m.import_cover_months(90.0, 0.0)
