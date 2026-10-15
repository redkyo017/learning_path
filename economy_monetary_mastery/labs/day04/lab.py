"""Day 04 lab: inflation, real rates and compounding.

Goal: turn a CPI level series into year-over-year inflation (yoy_inflation), apply the
exact Fisher equation (real_rate), and master compounding (compound, cagr, real_cagr,
years_to_double). Implement the six TODO functions; main() is given and uses them on the
FRED snapshots (CPI, fed funds) and SPY.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred, load_prices
from common.quant import cagr as price_cagr


def yoy_inflation(cpi: pd.Series, periods: int = 12) -> pd.Series:
    """Year-over-year inflation (decimal) from a monthly CPI level series.

    Percentage change over `periods` observations (12 for monthly data), with the leading
    NaNs dropped: len(result) == len(cpi) - periods. Do not forward-fill missing values.
    Caveat: this is row-based and assumes a gap-free monthly index (reindex gaps first).
    """
    raise NotImplementedError("TODO: cpi.pct_change(periods, fill_method=None).dropna()")


def real_rate(nominal, inflation):
    """Exact Fisher real rate: (1 + nominal) / (1 + inflation) - 1.

    Both inputs are decimals (0.05 = 5%) and may be floats or aligned pandas Series; the
    result has the same type. This is not the approximation nominal - inflation.
    """
    raise NotImplementedError("TODO: (1 + nominal) / (1 + inflation) - 1")


def compound(value: float, rate: float, years: float) -> float:
    """Future value of `value` growing at annual `rate` (decimal) for `years` years."""
    raise NotImplementedError("TODO: value * (1 + rate) ** years")


def cagr(start_value: float, end_value: float, years: float) -> float:
    """Compound annual growth rate: (end / start) ** (1 / years) - 1.

    Raise ValueError if start_value <= 0 or years <= 0.
    """
    raise NotImplementedError("TODO: validate inputs, then (end/start) ** (1/years) - 1")


def real_cagr(nominal: float, inflation: float) -> float:
    """Inflation-adjusted annual growth from a nominal and an inflation rate (decimals).

    Same exact Fisher form as real_rate, for scalars: (1 + nominal) / (1 + inflation) - 1.
    """
    raise NotImplementedError("TODO: (1 + nominal) / (1 + inflation) - 1")


def years_to_double(rate: float) -> float:
    """Exact years for money to double at annual `rate` (decimal): ln 2 / ln(1 + rate).

    Compare with the rule of 72 (72 / rate in percent).
    """
    raise NotImplementedError("TODO: math.log(2) / math.log(1 + rate)")


def main() -> None:
    cpi = load_fred("CPIAUCSL")          # index level, monthly (lags ~1 month)
    dff = load_fred("DFF") / 100.0       # daily effective fed funds, percent -> decimal
    # The snapshot has no 2025-10-01 row (the 2025 shutdown). yoy_inflation is row-based, so
    # put CPI on a full monthly calendar first: the missing month becomes NaN and is dropped,
    # instead of silently shifting every later "12 rows back" comparison by one month.
    infl = yoy_inflation(cpi.asfreq("MS"))
    policy = dff.resample("MS").mean()   # monthly mean, labelled on the 1st like CPI
    df = pd.concat({"policy": policy, "infl": infl}, axis=1, sort=True).dropna()
    df["real"] = real_rate(df.policy, df.infl)
    df = df[df.index >= "1960-01-01"]

    lo, hi = df.real.idxmin(), df.real.idxmax()
    print("Real policy rate = monthly mean fed funds vs CPI YoY (exact Fisher), since 1960")
    print(f"  most negative: {df.real.min():+.2%} in {lo:%Y-%m} (policy {df.policy[lo]:.2%}, CPI {df.infl[lo]:.2%})")
    print(f"  most positive: {df.real.max():+.2%} in {hi:%Y-%m} (policy {df.policy[hi]:.2%}, CPI {df.infl[hi]:.2%})")
    print(f"  latest ({df.index[-1]:%Y-%m}): policy {df.policy.iloc[-1]:.2%}, CPI {df.infl.iloc[-1]:.2%}, real {df.real.iloc[-1]:+.2%}")

    spy = load_prices("SPY")["SPY"].dropna()
    spy = spy[spy.index >= "2005-01-01"]
    nominal = price_cagr(spy)  # price series is dividend-adjusted, so this is total return
    years = (spy.index[-1] - spy.index[0]).days / 365.25
    c = cpi[(cpi.index >= spy.index[0] - pd.offsets.MonthBegin(1)) & (cpi.index <= spy.index[-1])]
    infl_cagr = cagr(c.iloc[0], c.iloc[-1], (c.index[-1] - c.index[0]).days / 365.25)
    print(f"SPY since {spy.index[0].date()} ({years:.1f}y): nominal CAGR {nominal:.2%}, "
          f"CPI CAGR {infl_cagr:.2%}, real CAGR {real_cagr(nominal, infl_cagr):.2%}")
    print(f"Doubling time at 7%: exact {years_to_double(0.07):.2f}y vs rule of 72 {72 / 7:.2f}y")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day04.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(9, 4.5))
    ax.plot(df.index, df.real * 100, linewidth=1, label="Real policy rate (%)")
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_ylabel("percent")
    ax.set_title("Real policy rate: monthly fed funds vs CPI YoY (exact Fisher)")
    ax.legend(loc="upper left", fontsize=8)
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
