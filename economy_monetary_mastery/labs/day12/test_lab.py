import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_implied_rate():
    assert m.implied_rate(95.75) == pytest.approx(4.25)


def test_meeting_adjustment_recovers_post_meeting_rate():
    # 15 days at 4.50 then 15 days at 4.25 average to 4.375
    assert m.meeting_adjusted_implied(4.375, 4.50, 16, 30) == pytest.approx(4.25)


def test_move_probability():
    assert m.move_probability(4.50, 4.3125) == pytest.approx(-0.75)
    assert m.move_probability(4.50, 4.50) == pytest.approx(0.0)
    assert m.move_probability(4.50, 4.00) == pytest.approx(-1.0)  # clipped
    assert m.move_probability(4.50, 4.625) == pytest.approx(0.5)


def test_surprise():
    assert m.surprise_bp(-25, -0.75) == pytest.approx(-6.25)
    assert m.surprise_bp(-25, -1.0) == pytest.approx(0.0)  # fully priced in
    assert m.surprise_bp(0, -0.75) == pytest.approx(18.75)  # a "hawkish hold"


def test_reaction():
    assert m.asset_reaction_pct(-6.25, -0.1) == pytest.approx(0.625)


def test_meeting_day_bounds():
    with pytest.raises(ValueError):
        m.meeting_adjusted_implied(4.4, 4.5, 31, 30)
