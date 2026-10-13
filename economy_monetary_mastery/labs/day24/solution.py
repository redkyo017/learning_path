"""Day 24 lab: crypto vs fiat as monetary systems -- compare issuance rates.

Goal: put Bitcoin's scheduled issuance and the US M2 money stock on one axis. Implement
btc_supply (Day 19's closed-form supply, in satoshis), btc_annual_inflation (next year's new coins
over the current supply), m2_growth (year-on-year growth of a monthly series) and compare_issuance
(one row per year: BTC inflation at 1 January against M2 growth in December of that year).
main() prints the comparison table for 2013-2026 against the M2SL snapshot and plots both lines.
Limits: 52,560 blocks a year is the 10-minute ideal (real years ran about 52,700 to 63,400 blocks); M2 is a
stock of deposits and cash, not "base money"; the two numbers measure supply growth, not value.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred

BTC = 100_000_000
HALVING_INTERVAL = 210_000
MAX_HALVINGS = 64

# Approximate block height at 00:00 UTC on 1 January: the last block with a timestamp before that
# instant, from the mempool.space API (GET /api/v1/mining/blocks/timestamp/<unix time>), read
# 2026-10-11. Cross-check any value on a block explorer; +/- 1,000 blocks is more than enough here.
YEAR_HEIGHTS: dict[int, int] = {
    2013: 214_562, 2014: 277_995, 2015: 336_860, 2016: 391_181, 2017: 446_032,
    2018: 501_960, 2019: 556_458, 2020: 610_690, 2021: 663_912, 2022: 716_598,
    2023: 769_786, 2024: 823_785, 2025: 877_258, 2026: 930_340,
}


def btc_supply(height: int) -> int:
    """Total satoshis issued by blocks 0..height-1 (same definition as Day 19's total_supply).

    Subsidy is 50 BTC, shifted right once per completed 210,000-block era, 0 after 64 eras.
    Must be closed form per era: do not loop over every height.
    """
    # Each complete era issues 210,000 * subsidy; the unfinished era issues rem * its subsidy.
    height = min(height, MAX_HALVINGS * HALVING_INTERVAL)
    full, rem = divmod(height, HALVING_INTERVAL)
    total = sum(HALVING_INTERVAL * ((50 * BTC) >> e) for e in range(full))  # at most 64 terms
    if full < MAX_HALVINGS:
        total += rem * ((50 * BTC) >> full)
    return total


def btc_annual_inflation(height: int, blocks_per_year: int = 52_560) -> float:
    """Fraction of new supply created over the next `blocks_per_year` blocks, from `height`.

    (btc_supply(height + blocks_per_year) - btc_supply(height)) / btc_supply(height).
    """
    now = btc_supply(height)
    return (btc_supply(height + blocks_per_year) - now) / now


def m2_growth(m2: pd.Series) -> pd.Series:
    """Year-on-year growth of a monthly series (12 rows back), NaN rows dropped.

    Use pct_change(12, fill_method=None).dropna(). Callers must give a complete monthly index;
    main() reindexes to month starts first so a missing month cannot shift the comparison.
    """
    # fill_method=None: never forward-fill a gap; a NaN stays NaN and drops out.
    return m2.pct_change(12, fill_method=None).dropna()


def compare_issuance(year_heights: dict[int, int], m2: pd.Series) -> pd.DataFrame:
    """One row per year in `year_heights` (index = year, ascending as given).

    Columns, in order: "btc_inflation" = btc_annual_inflation(year_heights[year]);
    "m2_growth" = the YoY M2 growth value at the last month (December) of that year,
    NaN if the series does not reach that December.
    """
    g = m2_growth(m2)
    december = g[g.index.month == 12]
    by_year = pd.Series(december.values, index=december.index.year)
    years = list(year_heights)
    return pd.DataFrame(
        {
            "btc_inflation": [btc_annual_inflation(year_heights[y]) for y in years],
            # reindex gives NaN for years whose December is not in the (growth) series
            "m2_growth": by_year.reindex(years).to_numpy(),
        },
        index=years,
    )


def main() -> None:
    m2 = load_fred("M2SL")
    # Monthly FRED series can lack a month (e.g. the Oct-2025 shutdown gap in other series); reindex
    # to a full month-start calendar so pct_change(12) always compares the same month a year apart.
    m2 = m2.asfreq("MS")
    print(f"M2SL snapshot: {len(m2)} months, latest {m2.index[-1]:%Y-%m} = {m2.iloc[-1]:,.1f} bn USD "
          f"(missing months: {int(m2.isna().sum())})")
    df = compare_issuance(YEAR_HEIGHTS, m2)
    show = df.assign(btc_supply_m=[btc_supply(YEAR_HEIGHTS[y]) / BTC / 1e6 for y in df.index])
    print("year  BTC inflation (1 Jan, next 52,560 blocks)  M2 growth (Dec YoY)  BTC supply (m)")
    for y, r in show.iterrows():
        g = "n/a (year not over)" if pd.isna(r.m2_growth) else f"{r.m2_growth:7.2%}"
        print(f"{y}  {r.btc_inflation:>38.2%}  {g:>19}  {r.btc_supply_m:>14.3f}")
    last = df.dropna().iloc[-1]
    print(f"Latest full year {int(df.dropna().index[-1])}: BTC {last.btc_inflation:.2%} vs M2 {last.m2_growth:.2%}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day24.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot(df.index, df.btc_inflation * 100, marker="o", label="BTC scheduled inflation")
    ax.plot(df.index, df.m2_growth * 100, marker="s", label="US M2 growth (Dec YoY)")
    ax.set_ylabel("% per year")
    ax.set_title("Issuance: Bitcoin schedule vs US M2")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
