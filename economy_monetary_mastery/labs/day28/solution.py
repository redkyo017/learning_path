"""Day 28 lab: strategy families.

Goal: build the building blocks of the main systematic strategy families (time-series trend,
z-score mean reversion, inverse-volatility sizing, cross-sectional momentum) and a blender for
strategy return streams, then compare a trend sleeve, a cross-sectional momentum sleeve and their
50/50 blend against equal-weight buy-and-hold on a mixed ETF + BTC universe.

Contract: every function uses information up to and including row t; common.backtest lags it.
Calendar note: ETFs trade ~252 days a year, BTC-USD 365. main() joins everything on common
weekday dates (inner join) and annualises portfolio metrics with 252 on that calendar.
Educational code, not financial advice.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from common.backtest import backtest
from common.data import load_prices
from common.quant import cagr, max_drawdown, sharpe

TICKERS = ["SPY", "EFA", "EEM", "TLT", "IEF", "GLD", "BTC-USD"]
COST_BPS = 5.0  # one-way cost per unit of turnover (assumption for the lab, not a quote)
PPY = 252       # periods per year on the common weekday calendar



def trend_signal(prices: pd.DataFrame, lookback: int) -> pd.DataFrame:
    """Time-series momentum per column: the sign (-1, 0, +1) of the trailing `lookback`-bar return.

    Uses prices up to and including row t (the caller lags it). Rows without a full lookback
    window (NaN return) get 0.
    """

    # sign() of NaN is NaN; fillna(0) turns the warm-up rows into "no position".
    return np.sign(prices / prices.shift(lookback) - 1).fillna(0.0)


def mean_reversion_signal(prices: pd.Series, window: int, z_entry: float) -> pd.Series:
    """Z-score mean reversion: -1 if z > z_entry, +1 if z < -z_entry, else 0.

    z = (price - rolling mean) / rolling std over `window` bars (std with ddof=1). Bars without a
    full window, or with std == 0, give NaN z and therefore signal 0. Not yet lagged.
    """

    mean = prices.rolling(window).mean()
    std = prices.rolling(window).std()  # ddof=1 by default
    z = (prices - mean) / std.where(std > 0)  # std == 0 -> NaN z -> no signal
    # Comparisons with NaN are False, so warm-up and flat windows give 0.
    return (z < -z_entry).astype(float) - (z > z_entry).astype(float)


def inverse_vol_weights(returns: pd.DataFrame, window: int) -> pd.DataFrame:
    """Risk-parity-style weights: proportional to 1 / rolling std of each column, rows sum to 1.

    Rows without a full `window` of returns are dropped (the first row kept is at position window-1).
    """

    inv = 1.0 / returns.rolling(window).std()
    return inv.div(inv.sum(axis=1), axis=0).dropna()


def cross_sectional_momentum(prices: pd.DataFrame, lookback: int, top_n: int) -> pd.DataFrame:
    """Hold the `top_n` best trailing performers, equal weight 1/top_n each, everything else 0.

    Rank by the trailing `lookback`-bar return, best first; ties are broken by column order. Rows
    with any NaN trailing return (no history yet) are all 0.
    """

    trailing = prices / prices.shift(lookback) - 1
    # Rank 1 = best performer; method="first" breaks ties by column order.
    rank = trailing.rank(axis=1, ascending=False, method="first")
    w = (rank <= top_n).astype(float) / top_n
    # Rows with any NaN trailing return have no valid ranking: stay in cash.
    return w.where(trailing.notna().all(axis=1), 0.0)


def combine_strategies(returns: pd.DataFrame, weights: dict[str, float]) -> pd.Series:
    """Blend strategy return streams: sum over k of weights[k] * returns[k].

    Raises ValueError if any key of `weights` is not a column of `returns`.
    """

    missing = [k for k in weights if k not in returns.columns]
    if missing:
        raise ValueError(f"unknown strategies: {missing}")
    return sum(returns[k] * v for k, v in weights.items())



def _sleeve(prices: pd.DataFrame, weights: pd.DataFrame) -> pd.Series:
    """Portfolio return of per-asset positions: backtest each asset with its weight as the signal."""
    w = weights.reindex(prices.index).fillna(0.0)
    rets = pd.DataFrame({c: backtest(prices[c], w[c], COST_BPS)["strat_ret"] for c in prices})
    return rets.sum(axis=1)


def _row(name: str, r: pd.Series) -> str:
    eq = (1 + r).cumprod()
    return (f"  {name:<22} CAGR {cagr(eq):7.2%}  Sharpe {sharpe(r, periods_per_year=PPY):5.2f}  "
            f"MaxDD {max_drawdown(eq):7.2%}")


def main() -> None:
    prices = load_prices(TICKERS).dropna()  # inner join: dates where every asset has a price
    prices = prices[prices.index.dayofweek < 5]
    rets = prices.pct_change().dropna()
    print(f"universe {list(prices.columns)}")
    print(f"common weekday calendar {prices.index[0].date()} -> {prices.index[-1].date()}, "
          f"{len(prices)} rows; metrics annualised with {PPY} (BTC weekends dropped, so a BTC "
          f"Friday-to-Monday return spans 3 days)")

    iv = inverse_vol_weights(rets, 60)
    trend_w = trend_signal(prices, 120).reindex(iv.index).fillna(0.0) * iv
    csm_w = cross_sectional_momentum(prices, 120, 3)

    trend_r = _sleeve(prices, trend_w)
    csm_r = _sleeve(prices, csm_w)
    start = iv.index[0]
    sleeves = pd.DataFrame({"trend": trend_r, "csmom": csm_r}).loc[start:]
    sleeves["blend"] = combine_strategies(sleeves, {"trend": 0.5, "csmom": 0.5})
    sleeves["buy&hold EW"] = rets.mean(axis=1).loc[start:]

    print(f"\nafter {COST_BPS:.0f} bps/turnover cost, from {start.date()} (trend 120d long/short x "
          f"1/vol(60d); csmom 120d top 3):")
    for c in sleeves:
        print(_row(c, sleeves[c]))
    print(f"\ncorrelation trend vs csmom daily returns: {sleeves['trend'].corr(sleeves['csmom']):.2f}")
    print(f"correlation blend vs buy&hold: {sleeves['blend'].corr(sleeves['buy&hold EW']):.2f}")

    fig, ax = plt.subplots(figsize=(8, 4))
    (1 + sleeves).cumprod().plot(ax=ax)
    ax.set_yscale("log")
    ax.set_title("Strategy families vs equal-weight buy & hold")
    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out / "day28.png", dpi=110)
    print(f"saved {out / 'day28.png'}")


if __name__ == "__main__":
    main()
