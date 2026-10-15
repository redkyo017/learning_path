import pytest

from common.stats import deflated_sharpe_ratio, expected_max_sharpe, probabilistic_sharpe_ratio


def test_reference_stats():
    assert probabilistic_sharpe_ratio(0.0, 0.0, 50) == pytest.approx(0.5)
    assert expected_max_sharpe(100, 1.0) == pytest.approx(2.53, abs=0.01)
    assert deflated_sharpe_ratio(0.1, 1, 0.001, 1000) == pytest.approx(
        probabilistic_sharpe_ratio(0.1, 0.0, 1000))
