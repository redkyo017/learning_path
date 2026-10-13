"""Reference risk helpers (Day 27). Day 30 imports breakeven_cost_bps only."""
import numpy as np
import pandas as pd


def vol_target_weights(returns: pd.Series, target_vol: float, window: int, max_leverage: float,
                       periods: int = 252) -> pd.Series:
    """Exposure that scales a return stream to `target_vol` (annualized), lagged one bar.

    weight[t] = target_vol / (rolling std of returns up to t-1 * sqrt(periods)), clipped to
    [0, max_leverage]; warm-up bars (no full window) get 0.0.
    """
    realised = returns.rolling(window).std() * np.sqrt(periods)
    return (target_vol / realised).shift(1).clip(0, max_leverage).fillna(0.0)


def breakeven_cost_bps(gross_returns: pd.Series, turnover: pd.Series) -> float:
    """Cost per unit of turnover, in bps, that drives total gross return to zero.

    sum(gross) / sum(turnover) * 1e4; inf if there is no turnover.
    """
    t = float(turnover.sum())
    if t == 0:
        return float("inf")
    return float(gross_returns.sum()) / t * 1e4
