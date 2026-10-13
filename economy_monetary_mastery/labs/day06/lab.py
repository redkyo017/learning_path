"""Day 06 lab: the plumbing dashboard (Block 1 integration).

Goal: combine Days 1-5 into one monthly table: the Fed's balance sheet and reserves (Day 3),
the policy rate (Day 3), CPI inflation (Day 4) and the real policy rate (Day 4), then label
each month restrictive, neutral or accommodative. Implement the two TODO functions; the
rest is given.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred

COLUMNS = ["fed_assets_busd", "reserves_busd", "policy_rate", "cpi_yoy", "real_rate"]


def plumbing_dashboard(fed_assets_musd: pd.Series, reserves_busd: pd.Series,
                       policy_rate_pct: pd.Series, cpi_index: pd.Series) -> pd.DataFrame:
    """Build the monthly (month-end index) plumbing dashboard.

    Inputs: Fed assets in MILLIONS of USD (weekly), reserves in BILLIONS of USD (weekly),
    the policy rate in PERCENT (daily) and a monthly CPI index level.
    Columns, in order, all as plain numbers: fed_assets_busd (billions), reserves_busd
    (billions), policy_rate (decimal), cpi_yoy (decimal, 12-month change of the month-end
    index), real_rate (exact Fisher: (1+policy)/(1+cpi_yoy)-1).
    Level series use the monthly mean; CPI uses the last value of the month. Drop months
    where any column is missing.
    """
    raise NotImplementedError("TODO: resample('ME'), convert units, yoy CPI, Fisher, concat + dropna")


def stance(real_rate: float, band: float = 0.01) -> str:
    """Label a real policy rate: "restrictive" above +band, "accommodative" below -band,
    otherwise "neutral" (a rate exactly on the band edge is neutral)."""
    raise NotImplementedError("TODO: compare real_rate with +band and -band")


CASE_POINTS = ["2008-12", "2013-06", "2020-04", "2022-06"]


def main() -> None:
    walcl = load_fred("WALCL")            # millions of USD
    # WRESBAL is stored in MILLIONS of USD in the snapshot,
    # while plumbing_dashboard expects billions, so convert here.
    wresbal = load_fred("WRESBAL") / 1000
    dff = load_fred("DFF")                # percent
    cpi = load_fred("CPIAUCSL")           # index level, monthly (lags the other series)

    df = plumbing_dashboard(walcl, wresbal, dff, cpi)
    df["stance"] = [stance(r) for r in df["real_rate"]]

    print("Last 12 months (assets/reserves $bn, rates %):")
    tail = df.tail(12)
    for ts, r in tail.iterrows():
        print(f"  {ts:%Y-%m}: assets {r.fed_assets_busd:6.0f} | reserves {r.reserves_busd:5.0f} | "
              f"policy {r.policy_rate*100:4.2f} | CPI {r.cpi_yoy*100:4.2f} | "
              f"real {r.real_rate*100:5.2f} | {r.stance}")
    print("Case points:")
    for label in CASE_POINTS + ["latest"]:
        row = df.iloc[-1] if label == "latest" else df.loc[label].iloc[0]
        when = df.index[-1] if label == "latest" else df.loc[label].index[0]
        print(f"  {when:%Y-%m}: real rate {row.real_rate*100:6.2f}% -> {row.stance}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day06.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(2, 2, figsize=(11, 7))
    df["fed_assets_busd"].plot(ax=ax[0, 0], title="Fed total assets ($bn)")
    df["reserves_busd"].plot(ax=ax[0, 1], title="Reserve balances ($bn)")
    (df[["policy_rate", "cpi_yoy"]] * 100).plot(ax=ax[1, 0], title="Policy rate vs CPI YoY (%)")
    (df["real_rate"] * 100).plot(ax=ax[1, 1], title="Real policy rate (%)")
    ax[1, 1].axhline(0, color="black", linewidth=0.8)
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
