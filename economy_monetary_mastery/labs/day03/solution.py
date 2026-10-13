"""Day 03 solution: the central bank's balance sheet, the rate corridor and QE.

Goal: model how the overnight rate depends on reserve scarcity (overnight_rate), write
the T-account postings of a QE purchase from a bank vs a nonbank (qe_postings), and align
mixed-frequency FRED series on a weekly (Wednesday) grid (align_weekly). Implement the
three TODO functions; the rest is given.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred


def overnight_rate(reserves: float, iorb: float, ceiling: float, satiation: float) -> float:
    """Overnight interbank rate (percent) as a function of aggregate reserves (billions).

    Ample reserves (reserves >= satiation): a floor system, the rate sits at `iorb`.
    Scarce reserves: the rate climbs linearly toward `ceiling` (the discount window /
    standing repo rate) as reserves fall to zero:
        ceiling - (ceiling - iorb) * reserves / satiation
    Raise ValueError if reserves < 0.
    """
    if reserves < 0:
        raise ValueError("reserves cannot be negative")
    if reserves >= satiation:  # floor system: banks have no reason to bid above IORB
        return iorb
    # scarce: each missing dollar of reserves is worth a little more, up to the ceiling at zero
    return ceiling - (ceiling - iorb) * reserves / satiation


def qe_postings(amount: float, seller: str) -> dict[str, dict[str, dict[str, float]]]:
    """T-account changes when the central bank buys `amount` of Treasuries.

    Returns {entity: {"assets": {...}, "liabilities": {...}}}. seller is "nonbank" or "bank".
    - nonbank: central_bank assets {"treasuries": +a}, liabilities {"reserves:bank": +a};
      bank assets {"reserves": +a}, liabilities {"deposit:seller": +a};
      seller assets {"treasuries": -a, "deposit": +a}, liabilities {}.
    - bank: central_bank as above; bank assets {"reserves": +a, "treasuries": -a},
      liabilities {}; there is no "seller" entry.
    Raise ValueError for any other seller. Every entity's changes must balance.
    """
    if seller not in ("nonbank", "bank"):
        raise ValueError(f"seller must be 'bank' or 'nonbank', got {seller!r}")
    a = float(amount)
    central_bank = {"assets": {"treasuries": a}, "liabilities": {"reserves:bank": a}}
    if seller == "bank":
        # swap one asset (Treasuries) for another (reserves): no deposit is created
        return {"central_bank": central_bank,
                "bank": {"assets": {"reserves": a, "treasuries": -a}, "liabilities": {}}}
    # nonbank seller: the bank is the conduit, it books new reserves AND a new deposit
    return {"central_bank": central_bank,
            "bank": {"assets": {"reserves": a}, "liabilities": {"deposit:seller": a}},
            "seller": {"assets": {"treasuries": -a, "deposit": a}, "liabilities": {}}}


def align_weekly(series: dict[str, pd.Series]) -> pd.DataFrame:
    """Put mixed-frequency series on one weekly grid (weeks ending Wednesday, the H.4.1 day).

    Resample each series to "W-WED" taking the last value in the week, concat as columns in
    the input key order, sort the index, forward-fill gaps (monthly -> weekly) and drop rows
    where any series has not started yet.
    """
    weekly = {k: s.resample("W-WED").last() for k, s in series.items()}
    # union index, so a monthly point lands in its own week and is carried forward
    return pd.concat(weekly, axis=1, sort=True).sort_index().ffill().dropna()


def _at_year_end(df: pd.DataFrame, year: int) -> pd.Series:
    return df[df.index.year == year].iloc[-1]


def main() -> None:
    walcl = load_fred("WALCL") / 1000.0  # FRED reports millions of USD; convert to billions
    wresbal = load_fred("WRESBAL") / 1000.0  # WRESBAL is millions USD: /1000 -> billions
    dff = load_fred("DFF")               # percent
    iorb = load_fred("IORB")             # percent; only exists from 2021-07-29 (IOER before that)
    rrp = load_fred("RRPONTSYD")         # billions USD of ON RRP *usage*, not a rate

    # IORB would cut the aligned history to 2021+ (dropna), so build two frames.
    hist = align_weekly({"walcl": walcl, "wresbal": wresbal, "dff": dff, "rrp": rrp})
    recent = align_weekly({"walcl": walcl, "wresbal": wresbal, "dff": dff, "iorb": iorb, "rrp": rrp})

    print("Year-end (last weekly obs): WALCL $bn | reserves $bn | fed funds % | ON RRP usage $bn")
    for year in (2008, 2014, 2019, 2022):
        r = _at_year_end(hist, year)
        print(f"  {year}: {r.walcl:8.0f} | {r.wresbal:7.0f} | {r.dff:5.2f} | {r.rrp:7.1f}")
    last = recent.iloc[-1]
    print(f"  latest ({recent.index[-1].date()}): {last.walcl:8.0f} | {last.wresbal:7.0f} | "
          f"{last.dff:5.2f} | {last.rrp:7.1f}   (IORB {last.iorb:.2f}%)")
    peak = hist.walcl.idxmax()
    print(f"Balance-sheet peak: ${hist.walcl.max():,.0f}bn on {peak.date()}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day03.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(9, 4.5))
    ax.plot(hist.index, hist.walcl, label="Fed total assets (WALCL, $bn)")
    ax.plot(hist.index, hist.wresbal, label="Reserve balances (WRESBAL, $bn)")
    ax.set_ylabel("$ billions")
    ax2 = ax.twinx()
    ax2.plot(hist.index, hist.dff, color="black", linewidth=1, label="Effective fed funds (DFF, %)")
    ax2.plot(recent.index, recent.iorb, color="tab:red", linewidth=1, label="IORB (%, from 2021-07; IOER before)")
    ax2.set_ylabel("percent")
    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, loc="upper left", fontsize=8)
    ax.set_title("Fed balance sheet and reserves vs the policy rate")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
