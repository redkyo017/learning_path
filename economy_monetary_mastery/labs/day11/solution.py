"""Day 11 lab: business cycle, macro regimes and "priced in".

Goal: label each month with a growth/inflation regime (classify_regime), standardise a series against
its own recent history (rolling_zscore), turn a data surprise into standard deviations (surprise_z)
and tabulate average asset returns per regime (regime_mean_returns). main() uses INDPRO year-on-year
as growth and CPIAUCSL year-on-year as inflation, then joins monthly SPY, TLT and GLD returns.
Implement the four TODO functions; the rest is given.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred, load_prices

REGIME_COLORS = {"goldilocks": "#9be29b", "reflation": "#ffd27f",
                 "stagflation": "#ff9b9b", "deflation": "#9bc4ff"}


def classify_regime(growth: pd.Series, inflation: pd.Series, lag: int = 3) -> pd.Series:
    """Label each period with a growth/inflation regime from the DIRECTION of both series.

    "Up" means `series.diff(lag) > 0` (strictly: flat counts as not rising). Mapping
    (growth_up, inflation_up): (True, True) -> "reflation"; (True, False) -> "goldilocks";
    (False, True) -> "stagflation"; (False, False) -> "deflation". Periods where either diff is
    NaN (the first `lag` rows, or gaps) are dropped, so the result's index starts `lag` rows in.
    """
    # Compare the change over `lag` periods with zero; a NaN diff must drop the row, not become "down".
    g, i = growth.diff(lag), inflation.diff(lag)
    df = pd.concat({"g": g, "i": i}, axis=1).dropna()
    g_up, i_up = df["g"] > 0, df["i"] > 0  # strict: flat is not rising
    out = pd.Series("deflation", index=df.index)
    out[g_up & i_up] = "reflation"
    out[g_up & ~i_up] = "goldilocks"
    out[~g_up & i_up] = "stagflation"
    return out


def rolling_zscore(s: pd.Series, window: int) -> pd.Series:
    """Rolling z-score: (s - rolling mean) / rolling sample std (ddof=1) over `window` periods.

    The first `window - 1` values are NaN.
    """
    roll = s.rolling(window)
    return (s - roll.mean()) / roll.std(ddof=1)


def surprise_z(actual: float, expected: float, std: float) -> float:
    """Standardised surprise: (actual - expected) / std. Raises ValueError if std <= 0."""
    if std <= 0:
        raise ValueError("std must be positive")
    return (actual - expected) / std


def regime_mean_returns(returns: pd.DataFrame, regimes: pd.Series) -> pd.DataFrame:
    """Average return of each column of `returns` within each regime.

    Inner-join `returns` with `regimes` on the index (dates present in both), then group by the
    regime label and take the mean. Result: index = regime names present, columns = returns columns.
    """
    df = returns.join(regimes.rename("regime"), how="inner")  # dates in both only
    return df.groupby("regime").mean()


def _monthly(series_id: str) -> pd.Series:
    """Load a monthly FRED series on a full month-start calendar (gaps become NaN)."""
    s = load_fred(series_id)
    return s.reindex(pd.date_range(s.index.min(), s.index.max(), freq="MS"))


def main() -> None:
    # The 2025 shutdown left CPIAUCSL without a 2025-10 value; reindexing makes that month NaN so
    # pct_change(12) and diff(lag) never silently compare the wrong months.
    growth = _monthly("INDPRO").pct_change(12, fill_method=None) * 100
    infl = _monthly("CPIAUCSL").pct_change(12, fill_method=None) * 100
    reg = classify_regime(growth, infl)
    reg = reg[reg.index >= "1990-01-01"]
    print(f"Regimes: {reg.index[0].date()} -> {reg.index[-1].date()}, {len(reg)} months")
    print("Share of months:", ", ".join(f"{k} {v:.0%}" for k, v in reg.value_counts(normalize=True).items()))

    px = load_prices(["SPY", "TLT", "GLD"]).dropna()
    mret = px.resample("ME").last().pct_change().dropna()
    mret.index = mret.index.to_period("M").to_timestamp()  # month-end -> month-start, to match FRED dates
    table = regime_mean_returns(mret, reg)
    n = reg.reindex(mret.index).dropna().value_counts()
    table.insert(0, "months", n.reindex(table.index))
    print("Mean monthly return by regime (same-month, 2005+):")
    print(table.to_string(float_format=lambda x: f"{x:.2%}" if abs(x) < 1 else f"{x:.0f}"))
    print(f"Current regime ({reg.index[-1]:%Y-%m}): {reg.iloc[-1]}")
    print(f"Latest INDPRO YoY {growth.dropna().iloc[-1]:.1f}%, CPI YoY {infl.dropna().iloc[-1]:.1f}%")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day11.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(11, 4))
    ax.plot(growth.loc["1990":].index, growth.loc["1990":].values, color="black", lw=1, label="INDPRO YoY %")
    ax.plot(infl.loc["1990":].index, infl.loc["1990":].values, color="tab:red", lw=1, label="CPI YoY %")
    for t, name in reg.items():
        ax.axvspan(t, t + pd.offsets.MonthBegin(1), color=REGIME_COLORS[name], alpha=0.5, lw=0)
    ax.legend(loc="upper left")
    ax.set_title("Growth/inflation regimes (green goldilocks, orange reflation, red stagflation, blue deflation)")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
