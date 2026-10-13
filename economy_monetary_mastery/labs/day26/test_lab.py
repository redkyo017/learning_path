import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_psr_basics():
    assert m.probabilistic_sharpe_ratio(0.0, 0.0, 100) == pytest.approx(0.5)
    assert m.probabilistic_sharpe_ratio(0.1, 0.0, 100) < m.probabilistic_sharpe_ratio(0.1, 0.0, 1000)


def test_expected_max_sharpe():
    assert m.expected_max_sharpe(100, 1.0) == pytest.approx(2.53, abs=0.01)
    assert m.expected_max_sharpe(1, 1.0) == 0.0


def test_dsr_penalizes_more_trials():
    few = m.deflated_sharpe_ratio(0.1, 10, 0.001, 1000)
    many = m.deflated_sharpe_ratio(0.1, 1000, 0.001, 1000)
    assert 0 <= many < few <= 1


def test_p_hacking():
    r = m.p_hacking_demo(200, 1000, seed=0)
    assert r["best_in_sample_sharpe"] > 1.0
    assert r["its_out_of_sample_sharpe"] < r["best_in_sample_sharpe"]


def _prices(n=600, seed=3):
    rng = np.random.default_rng(seed)
    idx = pd.bdate_range("2018-01-01", periods=n)
    return pd.Series(100 * np.exp(np.cumsum(rng.normal(0.0002, 0.01, n))), idx)


def test_walk_forward_shape():
    oos, choices = m.walk_forward(_prices(), [20, 60], train=250, test=50)
    assert len(choices) == 7 and set(choices) <= {20, 60}
    assert len(oos) == 350 and oos.index[0] == _prices().index[250]


def test_walk_forward_has_no_leakage():
    p = _prices()
    _, c1 = m.walk_forward(p, [20, 60], 250, 50)
    p2 = p.copy()
    p2.iloc[550:] *= 1.5
    _, c2 = m.walk_forward(p2, [20, 60], 250, 50)
    assert c1 == c2
