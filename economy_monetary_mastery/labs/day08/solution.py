"""Day 08 solution: discounting everything -- present value, Gordon growth, equity duration, beta.

Goal: value a stream of cash flows (pv_cashflows), price a perpetuity growing at g
(gordon_value, equity_duration), see why far-away cash flows fall most when the discount
rate rises (rate_shock_pct), and measure co-movement (beta, correlation). main() applies
this to growth (IWF) vs value (IWD) ETFs against the 10y yield in 2022. Implement the six
TODO functions; the rest is given.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred, load_prices


def pv_cashflows(cashflows: list[float], rate: float) -> float:
    """Present value of `cashflows` discounted at `rate` (decimal per year).

    The k-th cash flow (k = 1, 2, ...) arrives at t = k years: PV = sum(cf_k / (1 + rate)**k).
    """
    # enumerate(..., start=1): the first cash flow is one year away, not at t=0
    return sum(cf / (1 + rate) ** k for k, cf in enumerate(cashflows, start=1))


def gordon_value(next_cf: float, r: float, g: float) -> float:
    """Gordon growth value of a perpetuity whose next cash flow is `next_cf`, growing at g forever.

    value = next_cf / (r - g). Raises ValueError if r <= g (the sum diverges).
    """
    if r <= g:
        raise ValueError(f"need r > g, got r={r}, g={g}")
    return next_cf / (r - g)


def equity_duration(r: float, g: float) -> float:
    """Duration (in years) of a growing perpetuity: 1 / (r - g). Raises ValueError if r <= g."""
    # V = CF/(r-g) so dV/dr = -V/(r-g): the % price change per unit of r is 1/(r-g)
    if r <= g:
        raise ValueError(f"need r > g, got r={r}, g={g}")
    return 1.0 / (r - g)


def rate_shock_pct(cashflows: list[float], rate: float, shock: float) -> float:
    """Fractional change in present value when the discount rate moves from `rate` to `rate + shock`.

    Returns pv(rate + shock) / pv(rate) - 1 (negative for a positive shock).
    """
    return pv_cashflows(cashflows, rate + shock) / pv_cashflows(cashflows, rate) - 1


def beta(asset: pd.Series, market: pd.Series) -> float:
    """Beta of `asset` returns to `market` returns: cov(asset, market) / var(market).

    Align the two series on their index and drop missing rows first; use ddof=1 for both
    the covariance and the variance.
    """
    # align first: a misaligned pair silently gives a wrong (or NaN) beta
    df = pd.concat([asset, market], axis=1, keys=["a", "m"]).dropna()
    return float(df["a"].cov(df["m"]) / df["m"].var(ddof=1))


def correlation(a: pd.Series, b: pd.Series) -> float:
    """Pearson correlation of two return series (pandas aligns on the index)."""
    return float(a.corr(b))


def _monthly_returns(s: pd.Series) -> pd.Series:
    return s.resample("ME").last().pct_change().dropna()


def main() -> None:
    px = load_prices(["IWF", "IWD", "SPY"]).dropna()
    y10 = load_fred("DGS10").dropna()
    ret = px.apply(_monthly_returns)
    dy = y10.resample("ME").last().diff().dropna()  # monthly change in the 10y yield, pct points
    windows = {"2010-2019": ("2010-01-01", "2019-12-31"), "2022": ("2022-01-01", "2022-12-31")}

    print("Monthly returns: beta to SPY and correlation with monthly change in 10y yield")
    for label, (a, b) in windows.items():
        r = ret.loc[a:b]
        d = dy.loc[a:b]
        print(f"  {label}:")
        for t in ("IWF", "IWD"):
            print(f"    {t}: beta {beta(r[t], r['SPY']):.2f}, corr with d(10y) {correlation(r[t], d):+.2f}")

    yr = px.loc["2021-12-31":"2022-12-31"]
    tot = yr.iloc[-1] / yr.iloc[0] - 1
    print(f"2022 total return: IWF {tot['IWF']:.1%}, IWD {tot['IWD']:.1%}, SPY {tot['SPY']:.1%}")
    print(f"  10y yield: {y10[:'2021-12-31'].iloc[-1]:.2f}% -> {y10[:'2022-12-30'].iloc[-1]:.2f}%")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day08.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    rel = (px["IWF"] / px["IWD"]).loc["2015-01-01":]
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(rel.index, rel / rel.iloc[0], color="tab:blue", label="IWF / IWD (growth vs value)")
    ax.set_ylabel("relative performance (start = 1)")
    ax2 = ax.twinx()
    y = y10.loc["2015-01-01":]
    ax2.plot(y.index, y.values, color="tab:red", alpha=0.6, label="10y yield (%)")
    ax2.set_ylabel("10y yield (%)")
    ax.set_title("Growth vs value against the 10y yield")
    fig.legend(loc="upper left", bbox_to_anchor=(0.1, 0.9))
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
