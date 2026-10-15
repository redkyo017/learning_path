"""Day 07 lab: bonds, duration, convexity and the yield curve.

Goal: price a bond as a stream of discounted cash flows (bond_price), measure its
sensitivity to yields (macaulay_duration, modified_duration, convexity), and find
yield-curve inversions in FRED data (curve_slope, inversion_periods). Implement the six
TODO functions; main() is given and uses them on the DGS3MO / DGS2 / DGS10 snapshots.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred


def bond_price(face: float, coupon_rate: float, ytm: float, years: float, freq: int = 2) -> float:
    """Price of a plain coupon bond.

    Cash flows: c = face * coupon_rate / freq at k = 1..n where n = round(years * freq),
    plus face at k = n. Discount each at (1 + ytm / freq) ** k. All rates are decimals
    (0.05 = 5%). Zero coupon_rate gives a zero-coupon bond.
    """
    raise NotImplementedError("TODO: sum of c / (1+y/f)**k for k=1..n, plus face / (1+y/f)**n")


def macaulay_duration(face: float, coupon_rate: float, ytm: float, years: float, freq: int = 2) -> float:
    """Macaulay duration in years: the PV-weighted average time of the cash flows.

    sum over k of (k / freq) * PV_k, divided by the bond price.
    """
    raise NotImplementedError("TODO: sum((k/freq) * PV_k) / price")


def modified_duration(face: float, coupon_rate: float, ytm: float, years: float, freq: int = 2) -> float:
    """Modified duration: Macaulay / (1 + ytm / freq). Percent price change per 1.00 of yield change."""
    raise NotImplementedError("TODO: macaulay_duration(...) / (1 + ytm/freq)")


def convexity(face: float, coupon_rate: float, ytm: float, years: float, freq: int = 2) -> float:
    """Convexity (in years squared), the second-derivative term of price vs yield.

    sum over k of CF_k * t_k * (t_k + 1/freq) / (1 + ytm/freq) ** (k + 2), divided by the
    price, where t_k = k / freq.
    """
    raise NotImplementedError("TODO: sum(CF_k * t_k * (t_k + 1/f) / (1+y/f)**(k+2)) / price")


def curve_slope(long: pd.Series, short: pd.Series) -> pd.Series:
    """Yield-curve slope: long yield minus short yield, aligned on the index.

    Rows missing in either series are dropped. Negative means inverted.
    """
    raise NotImplementedError("TODO: (long - short).dropna()")


def inversion_periods(slope: pd.Series) -> list[tuple[pd.Timestamp, pd.Timestamp]]:
    """Contiguous runs where slope < 0, as inclusive (start, end) index timestamps.

    A zero or positive value ends a run. A run of a single observation gives (t, t).
    Observations are consecutive rows of the series (not calendar days).
    """
    raise NotImplementedError("TODO: scan the series, open a run on slope<0, close it otherwise")


def main() -> None:
    # 1. Price/yield curve of a 10y 4% bond.
    ytms = [y / 100 for y in range(1, 9)]
    prices = [bond_price(100, 0.04, y, 10) for y in ytms]
    print("Price of a 10y 4% semiannual bond by yield:")
    for y, p in zip(ytms, prices):
        print(f"  yield {y:.0%}: {p:7.2f}")
    print(f"  at 4%: modified duration {modified_duration(100, 0.04, 0.04, 10):.2f}, "
          f"convexity {convexity(100, 0.04, 0.04, 10):.1f}")

    # 2. Inversions of 10y - 2y since 1990.
    d3m, d2, d10 = load_fred("DGS3MO"), load_fred("DGS2"), load_fred("DGS10")
    slope = curve_slope(d10, d2)
    slope = slope[slope.index >= "1990-01-01"]
    runs = inversion_periods(slope)
    print("10y-2y inversions since 1990 lasting >= 20 trading days:")
    for a, b in runs:
        n = int(((slope.index >= a) & (slope.index <= b)).sum())
        if n >= 20:
            print(f"  {a.date()} -> {b.date()}  ({n} trading days, min {slope[a:b].min():+.2f} pp)")

    # 3. Curve snapshots.
    dates = ["2006-12-29", "2019-08-30", "2023-07-31"]
    curve = pd.concat({"3m": d3m, "2y": d2, "10y": d10}, axis=1, sort=True).dropna()
    picks = [curve.index[curve.index.searchsorted(pd.Timestamp(d), side="right") - 1] for d in dates]
    picks.append(curve.index[-1])
    print("Curve (3m / 2y / 10y):")
    for t in picks:
        r = curve.loc[t]
        print(f"  {t.date()}: {r['3m']:.2f} / {r['2y']:.2f} / {r['10y']:.2f}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day07.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 4.2))
    a1.plot([y * 100 for y in ytms], prices)
    a1.set_xlabel("yield (%)")
    a1.set_ylabel("price")
    a1.set_title("10y 4% bond: price vs yield (convex)")
    for t in picks:
        r = curve.loc[t]
        a2.plot([0.25, 2, 10], [r["3m"], r["2y"], r["10y"]], marker="o", label=str(t.date()))
    a2.set_xscale("log")
    a2.set_xlabel("maturity (years, log)")
    a2.set_ylabel("yield (%)")
    a2.set_title("Treasury curve on four dates")
    a2.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
