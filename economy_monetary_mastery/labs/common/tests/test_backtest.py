import pandas as pd
import pytest

from common.backtest import backtest, momentum_signal


def test_reference_backtest():
    idx = pd.bdate_range("2024-01-01", periods=3)
    p = pd.Series([100.0, 101.0, 102.0], idx)
    assert backtest(p, pd.Series(1.0, idx), 10)["equity"].iloc[-1] == pytest.approx(
        1.009 * 102 / 101)
    assert momentum_signal(pd.Series([1.0, 2.0, 3.0]), 1).tolist() == [0.0, 1.0, 1.0]


def test_signal_index_is_aligned_to_prices():
    idx = pd.bdate_range("2024-01-01", periods=5)
    p = pd.Series([100.0, 101.0, 102.0, 103.0, 104.0], idx)
    sig = pd.Series(1.0, idx.delete(2)).reindex(idx.delete(2))  # missing middle date
    sig.loc[idx[0] - pd.Timedelta(days=3)] = 1.0  # extra earlier date
    sig = sig.sort_index()
    bt = backtest(p, sig, cost_bps=10)
    assert bt.index.equals(p.index)
    assert not bt.isna().any().any()
    assert bt["turnover"].iloc[1] == 1.0 and bt["cost"].iloc[1] == pytest.approx(0.001)
