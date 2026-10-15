"""Day 10 reference solution (lab.py with every TODO implemented).

Day 10 lab: portfolio theory -- volatility, Sharpe, portfolio variance, minimum variance, the frontier.

Goal: measure risk and risk-adjusted return (annualize_vol, sharpe), build a portfolio's return
series (portfolio_returns), compute its volatility from a covariance matrix (portfolio_vol),
find the minimum-variance mix (min_variance_weights) and trace the two-asset frontier
(frontier_two_asset). main() compares 100/0, 60/40 and 60/30/10 portfolios built from SPY, IEF
and GLD. Implement the six TODO functions; the rest is given.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from common.data import load_prices
from common.quant import cagr, equity_curve, max_drawdown


def annualize_vol(returns: pd.Series, periods: int = 252) -> float:
    """Annualized volatility: sample standard deviation (ddof=1) of `returns` times sqrt(periods)."""
    # Sample std (ddof=1), scaled by sqrt(periods): variance adds over time, so vol scales with sqrt.
    return float(returns.std(ddof=1) * np.sqrt(periods))


def sharpe(returns: pd.Series, rf: float = 0.0, periods: int = 252) -> float:
    """Annualized Sharpe ratio. `rf` is the ANNUAL risk-free rate (decimal).

    Excess return per period = returns - rf / periods; Sharpe = mean(excess) / std(excess, ddof=1) * sqrt(periods).
    """
    # Convert the annual rf to a per-period rate first; then it is just mean/std of the excess.
    ex = returns - rf / periods
    return float(ex.mean() / ex.std(ddof=1) * np.sqrt(periods))


def portfolio_returns(returns: pd.DataFrame, weights) -> pd.Series:
    """Return series of a portfolio rebalanced to fixed `weights` every period.

    `weights` is a sequence aligned with the columns of `returns`. Result: returns @ weights,
    a Series on the same index.
    """
    # Fixed weights every period = daily rebalancing; a matrix-vector product does it in one line.
    return returns @ np.asarray(weights, dtype=float)


def portfolio_vol(weights, cov) -> float:
    """Portfolio standard deviation sqrt(w' C w) for weight vector `weights` and covariance matrix `cov`.

    Same time unit as `cov` (annual cov gives annual vol). Clip the variance at 0 before the
    square root so rounding noise never produces NaN.
    """
    # Variance is the quadratic form w'Cw; clip tiny negative rounding noise (e.g. -1e-18).
    w = np.asarray(weights, dtype=float)
    return float(np.sqrt(max(w @ np.asarray(cov, dtype=float) @ w, 0.0)))


def min_variance_weights(cov) -> np.ndarray:
    """Fully-invested (weights sum to 1) minimum-variance weights, shorting allowed.

    w = inv(C) @ 1 / (1' inv(C) 1).
    """
    # Lagrange solution of min w'Cw s.t. sum(w)=1. Solve a linear system rather than forming inv(C) twice.
    c = np.asarray(cov, dtype=float)
    x = np.linalg.solve(c, np.ones(len(c)))
    return x / x.sum()


def frontier_two_asset(mu, cov, n: int = 101) -> pd.DataFrame:
    """Two-asset frontier: DataFrame with columns w1, ret, vol and n rows.

    w1 = linspace(0, 1, n) is the weight on asset 0 (asset 1 gets 1 - w1); ret = w1*mu[0] + (1-w1)*mu[1];
    vol = sqrt(w1^2 var0 + (1-w1)^2 var1 + 2 w1 (1-w1) cov01), clipped at 0 before the sqrt.
    """
    # Two-asset variance: w1^2 s0^2 + w2^2 s1^2 + 2 w1 w2 cov01. A negative cov01 is what bends the curve left.
    c = np.asarray(cov, dtype=float)
    w1 = np.linspace(0.0, 1.0, n)
    w2 = 1.0 - w1
    ret = w1 * mu[0] + w2 * mu[1]
    var = w1**2 * c[0, 0] + w2**2 * c[1, 1] + 2 * w1 * w2 * c[0, 1]
    return pd.DataFrame({"w1": w1, "ret": ret, "vol": np.sqrt(np.clip(var, 0.0, None))})


def _stats(r: pd.Series) -> tuple[float, float, float, float]:
    eq = equity_curve(r, start=1.0)
    eq.loc[r.index[0] - pd.Timedelta(days=1)] = 1.0
    eq = eq.sort_index()
    return cagr(eq), annualize_vol(r), sharpe(r), max_drawdown(eq)


def main() -> None:
    px = load_prices(["SPY", "IEF", "GLD"]).dropna()
    rets = px.pct_change().dropna()
    print(f"Sample: {rets.index[0].date()} -> {rets.index[-1].date()}, {len(rets)} daily returns")

    ports = {
        "100/0 SPY": [1.0, 0.0, 0.0],
        "60/40 SPY/IEF": [0.6, 0.4, 0.0],
        "60/30/10 SPY/IEF/GLD": [0.6, 0.3, 0.1],
    }
    curves = {}
    print(f"{'portfolio':<22}{'CAGR':>8}{'vol':>8}{'Sharpe':>8}{'maxDD':>9}")
    for name, w in ports.items():
        r = portfolio_returns(rets[["SPY", "IEF", "GLD"]], w)
        c, v, s, dd = _stats(r)
        curves[name] = equity_curve(r)
        print(f"{name:<22}{c:>8.1%}{v:>8.1%}{s:>8.2f}{dd:>9.1%}")

    sub = rets[["SPY", "IEF"]]
    mu = (sub.mean() * 252).to_numpy()
    cov = (sub.cov() * 252).to_numpy()
    fr = frontier_two_asset(mu, cov)
    wmv = min_variance_weights(cov)
    print(f"SPY/IEF correlation {sub['SPY'].corr(sub['IEF']):+.2f}; "
          f"min-variance weights SPY {wmv[0]:.0%} / IEF {wmv[1]:.0%}, vol {portfolio_vol(wmv, cov):.1%}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day10.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4))
    ax1.plot(fr["vol"], fr["ret"], color="tab:blue")
    ax1.scatter([np.sqrt(cov[0, 0]), np.sqrt(cov[1, 1])], mu, color="black", zorder=3)
    ax1.set_xlabel("annual volatility")
    ax1.set_ylabel("annual mean return (arithmetic)")
    ax1.set_title("SPY/IEF frontier from sample statistics")
    for name, c in curves.items():
        ax2.plot(c.index, c.values, label=name)
    ax2.set_yscale("log")
    ax2.set_title("Growth of 1 (daily rebalanced)")
    ax2.legend()
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
