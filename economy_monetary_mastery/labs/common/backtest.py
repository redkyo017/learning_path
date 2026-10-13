"""Reference vectorized backtester (Day 25). Days 26, 27, 28 and 30 import these.

Contract: position = signal lagged one bar; turnover first row = |position[0]|;
cost = turnover * cost_bps / 1e4.
"""
import pandas as pd


def momentum_signal(prices: pd.Series, lookback: int) -> pd.Series:
    """Time-series momentum signal: 1.0 if the trailing `lookback`-bar return is > 0, else 0.0.

    Bars without a full lookback window (NaN return) get 0.0. The signal at bar t uses prices up
    to and including bar t only; it is NOT yet lagged (backtest does that).
    """
    # Trailing return over `lookback` bars; comparison with NaN is False, so warm-up bars become 0.0.
    return (prices / prices.shift(lookback) - 1 > 0).astype(float)

def backtest(prices: pd.Series, signal: pd.Series, cost_bps: float = 0.0) -> pd.DataFrame:
    """Vectorized long/flat backtest with a one-bar execution lag and proportional costs.

    Returns a DataFrame indexed like `prices` with columns
    ["asset_ret", "position", "turnover", "cost", "strat_ret", "equity"]:
    position = signal.shift(1).fillna(0); asset_ret = prices.pct_change().fillna(0);
    turnover = |position.diff()| with the first row = |position[0]|; cost = turnover*cost_bps/1e4;
    strat_ret = position*asset_ret - cost; equity = (1 + strat_ret).cumprod().
    """
    # The one-bar lag is the whole point: today's signal is traded at tomorrow's return.
    position = signal.reindex(prices.index).shift(1).fillna(0.0).astype(float)
    asset_ret = prices.pct_change().fillna(0.0)
    turnover = position.diff().abs()
    turnover.iloc[0] = abs(position.iloc[0])  # entering from cash counts as turnover
    cost = turnover * cost_bps / 1e4
    strat_ret = position * asset_ret - cost
    equity = (1 + strat_ret).cumprod()
    return pd.DataFrame({"asset_ret": asset_ret, "position": position, "turnover": turnover,
                         "cost": cost, "strat_ret": strat_ret, "equity": equity})
