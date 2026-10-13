"""Day 14 lab: the dollar system -- event studies and dollar beta.

Goal: measure how currencies and the broad dollar behave around dated events. event_window cuts a
window of cumulative returns (relative to the event day) around each event date, average_path
averages those windows across events, and dollar_beta regresses emerging-market FX changes on
broad-dollar changes. main() runs the broad dollar (DTWEXBGS) around the seven 2022 FOMC
rate-hike decisions and prints each EM currency's dollar beta. All FX series here are LOCAL
currency per USD, so a rise means the dollar strengthened. Implement the three TODO functions.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred

# FOMC decision days (second day of the meeting) at which the target range was raised in 2022.
# Source: federalreserve.gov FOMC calendar and monetary policy page; verified 2026-10.
FOMC_HIKES_2022 = [pd.Timestamp(d) for d in (
    "2022-03-16", "2022-05-04", "2022-06-15", "2022-07-27",
    "2022-09-21", "2022-11-02", "2022-12-14")]
EM_SERIES = {"KRW": "DEXKOUS", "BRL": "DEXBZUS", "INR": "DEXINUS", "THB": "DEXTHUS", "MXN": "DEXMXUS"}


def event_window(series: pd.Series, events: list, before: int, after: int) -> pd.DataFrame:
    """Cumulative-return window around each event date.

    For each event Timestamp (in the order given) find its integer position `pos` in `series.index`
    (the date must be present exactly). Skip the event if it is missing, or if `pos - before < 0`,
    or `pos + after >= len(series)`. Result: index = relative day -before..after, one column per
    KEPT event (column label = the event Timestamp), values = series[pos+k] / series[pos] - 1.
    """
    raise NotImplementedError("TODO: get_loc in try/except KeyError; skip out-of-range; value[pos+k]/value[pos]-1")


def average_path(window: pd.DataFrame) -> pd.Series:
    """Average across events (columns) of an event window: the row-wise mean, indexed by relative day."""
    raise NotImplementedError("TODO: window.mean(axis=1)")


def dollar_beta(em_returns: pd.DataFrame, usd_returns: pd.Series) -> pd.Series:
    """Slope of each column of `em_returns` on `usd_returns`: cov(em, usd) / var(usd), both ddof=1.

    Returns a Series indexed by the column names. Inputs are aligned on the same index.
    """
    raise NotImplementedError("TODO: per column cov/var with ddof=1")


def main() -> None:
    usd = load_fred("DTWEXBGS")
    win = event_window(usd, FOMC_HIKES_2022, before=20, after=20)
    path = average_path(win)
    print(f"Broad dollar around {win.shape[1]} FOMC hikes of 2022 (kept of {len(FOMC_HIKES_2022)}):")
    print(f"  average path: day -20 {path.loc[-20]:+.2%}, day -1 {path.loc[-1]:+.2%}, "
          f"day +1 {path.loc[1]:+.2%}, day +20 {path.loc[20]:+.2%}")
    print("  day +20 by event: " + ", ".join(f"{c:%m-%d} {v:+.1%}" for c, v in win.loc[20].items()))

    px = pd.concat({k: load_fred(v) for k, v in EM_SERIES.items()}, axis=1, sort=True)
    both = pd.concat([px, usd.rename("USD")], axis=1, sort=True).dropna()  # inner join: drop holiday gaps
    rets = both.pct_change().dropna()
    beta = dollar_beta(rets[list(EM_SERIES)], rets["USD"])
    print(f"Dollar beta of daily FX changes (local per USD on broad dollar), {rets.index[0].date()} "
          f"to {rets.index[-1].date()}:")
    for k, b in beta.items():
        print(f"  {k}: {b:+.2f}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day14.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(7, 4))
    for c in win.columns:
        ax.plot(win.index, win[c] * 100, color="lightgray", lw=1)
    ax.plot(path.index, path * 100, color="tab:blue", lw=2.5, label="average of 7 hikes")
    ax.axvline(0, color="black", lw=0.8)
    ax.set_xlabel("trading days from FOMC decision")
    ax.set_ylabel("broad dollar, % vs. decision day")
    ax.set_title("Broad dollar around 2022 FOMC hikes")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
