"""Day 27 solution: costs, sizing and risk.

Goal: measure how fast transaction costs eat a strategy (breakeven cost), and implement the sizing
rules that keep it alive: Kelly (and why fractional), volatility targeting and a drawdown brake.
main() runs 200-day momentum on SPY (frozen snapshot) at 0, 5, 20 and 50 bps, prints the breakeven
cost, then compares vol targeting and the drawdown brake with the plain rule in one table.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from common.backtest import backtest, momentum_signal
from common.data import load_prices
from common.quant import annualize_vol, cagr, max_drawdown, sharpe


def kelly_fraction(mu: float, sigma: float) -> float:
    """Continuous-time Kelly leverage f* = mu / sigma^2 (mu, sigma annualized excess return and vol).

    Raise ValueError if sigma <= 0.
    """
    if sigma <= 0:
        raise ValueError("sigma must be positive")
    # Maximizing expected log growth g(f) = f*mu - f^2*sigma^2/2 gives f* = mu / sigma^2.
    return mu / sigma**2


def fractional_kelly(mu: float, sigma: float, fraction: float = 0.5) -> float:
    """`fraction` times full Kelly (half Kelly by default)."""
    # Growth is flat-topped near f*, so giving up half the leverage costs little growth
    # but cuts the damage from a wrong mu estimate.
    return fraction * kelly_fraction(mu, sigma)


def vol_target_weights(returns: pd.Series, target_vol: float, window: int, max_leverage: float,
                       periods: int = 252) -> pd.Series:
    """Exposure that scales a return stream to `target_vol` (annualized), lagged one bar.

    weight[t] = target_vol / (rolling std over `window` bars up to t-1 * sqrt(periods)), clipped to
    [0, max_leverage]; warm-up bars get 0.0.
    """
    realised = returns.rolling(window).std() * np.sqrt(periods)
    # shift(1): the weight for bar t may only use returns up to t-1.
    return (target_vol / realised).shift(1).clip(0, max_leverage).fillna(0.0)


def breakeven_cost_bps(gross_returns: pd.Series, turnover: pd.Series) -> float:
    """Cost per unit of turnover, in bps, that drives total gross return to zero.

    sum(gross_returns) / sum(turnover) * 1e4; float('inf') if total turnover is 0.
    """
    total_turnover = float(turnover.sum())
    if total_turnover == 0:
        return float("inf")  # nothing to charge a cost on
    return float(gross_returns.sum()) / total_turnover * 1e4


def drawdown_brake(equity: pd.Series, threshold: float = 0.2, reduced: float = 0.5) -> pd.Series:
    """Position scale: `reduced` while the drawdown is deeper than `threshold`, else 1.0, lagged one bar.

    drawdown = equity / equity.cummax() - 1; the scale applied at bar t uses information up to t-1.
    """
    dd = equity / equity.cummax() - 1
    raw = np.where(dd < -threshold, reduced, 1.0)
    # shift(1): today's drawdown can only change tomorrow's position.
    return pd.Series(raw, index=equity.index).shift(1).fillna(1.0)


def _row(name: str, ret: pd.Series, ppy: int = 252) -> str:
    eq = (1 + ret).cumprod()
    return (f"{name:<34} CAGR {cagr(eq):7.2%}  vol {annualize_vol(ret, ppy):6.2%}  "
            f"Sharpe {sharpe(ret, periods_per_year=ppy):5.2f}  maxDD {max_drawdown(eq):7.2%}")


def main() -> None:
    p = load_prices(["SPY"])["SPY"].dropna()
    sig = momentum_signal(p, 200)
    print(f"SPY {p.index[0].date()} -> {p.index[-1].date()}: 200-day momentum, long/flat")

    print("\n(a) cost ladder")
    bh = p.pct_change().fillna(0.0)
    print(" ", _row("buy & hold", bh))
    gross = backtest(p, sig, 0.0)
    for bps in (0, 5, 20, 50):
        bt = backtest(p, sig, bps)
        print(" ", _row(f"{bps} bps per unit of turnover", bt["strat_ret"]))
    be = breakeven_cost_bps(gross["strat_ret"], gross["turnover"])
    print(f"\n(b) breakeven cost: {be:.0f} bps per unit of turnover "
          f"({gross['turnover'].sum():.0f} units of turnover in total)")

    print("\n(c)/(d) sizing at 5 bps (cost charged on the change in exposure)")
    asset, pos = gross["asset_ret"], gross["position"]
    cost = 5.0

    def net(exposure: pd.Series) -> pd.Series:
        t = exposure.diff().abs()
        t.iloc[0] = abs(exposure.iloc[0])
        return exposure * asset - t * cost / 1e4

    base = net(pos)
    w = vol_target_weights(asset, 0.10, 20, 1.5)
    vt = net(pos * w)
    # Approximation: the brake reads the unbraked equity path, not the equity it would itself produce.
    brake = drawdown_brake((1 + base).cumprod())
    braked = net(pos * brake)
    rows = {"plain momentum": base, "vol target 10% (cap 1.5x)": vt, "drawdown brake (20% / 0.5x)": braked}
    for name, r in rows.items():
        print(" ", _row(name, r))

    print("\n(e) worked example: buy SPY after every down day (1-day reversal), long/flat")
    rev = (p.pct_change() < 0).astype(float)
    rg = backtest(p, rev, 0.0)
    for bps in (0, 5, 20):
        print(" ", _row(f"reversal at {bps} bps", backtest(p, rev, bps)["strat_ret"]))
    print(f"  breakeven {breakeven_cost_bps(rg['strat_ret'], rg['turnover']):.1f} bps; "
          f"{rg['turnover'].sum():.0f} units of turnover")

    mu, sigma = asset.mean() * 252, asset.std() * np.sqrt(252)  # SPY buy-and-hold, rf not subtracted
    print(f"\n(f) Kelly on SPY buy-and-hold: mu {mu:.1%}, sigma {sigma:.1%} -> full {kelly_fraction(mu, sigma):.2f}x, "
          f"half {fractional_kelly(mu, sigma):.2f}x, quarter {fractional_kelly(mu, sigma, 0.25):.2f}x")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(9, 4))
    for name, r in rows.items():
        (1 + r).cumprod().plot(ax=ax, label=name)
    ax.set_yscale("log")
    ax.set_title("SPY 200d momentum: sizing rules at 5 bps")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out / "day27.png", dpi=110)
    print(f"\nsaved {out / 'day27.png'}")


if __name__ == "__main__":
    main()
