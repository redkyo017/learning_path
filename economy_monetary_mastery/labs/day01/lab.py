"""Day 01 lab: money as balance sheets.

Goal: build a tiny double-entry ledger (BalanceSheet), use it to move a deposit between two
banks (transfer_deposit), and parse the raw FRED CSV format (parse_fred_csv) so you can read
the effective federal funds rate. Implement the three TODO functions; the rest is given.
"""
import io
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import snapshot_path

TOLERANCE = 1e-9


class UnbalancedError(ValueError):
    """Raised when a ledger entry would make assets differ from liabilities + equity."""


class BalanceSheet:
    """One agent's balance sheet. Equity is the liability-side key "equity" (the residual)."""

    def __init__(self, owner: str):
        self.owner = owner
        self.assets: dict[str, float] = {}
        self.liabilities: dict[str, float] = {}

    def apply(self, assets: dict | None = None, liabilities: dict | None = None) -> None:
        """Apply signed deltas to asset and liability lines (equity is a liability key).

        Add each delta to the existing line (a missing line counts as 0). The entry must
        balance: sum of asset deltas == sum of liability deltas (within 1e-9). If it does
        not, raise UnbalancedError BEFORE changing anything, so a rejected entry leaves
        the sheet untouched.
        """
        raise NotImplementedError("TODO: compare delta sums first, then mutate with dict.get(k, 0) + v")

    def total_assets(self) -> float:
        return sum(self.assets.values())

    def total_liabilities(self) -> float:
        """Total of the liability side, including equity."""
        return sum(self.liabilities.values())


def transfer_deposit(payer_bank: BalanceSheet, payee_bank: BalanceSheet, amount: float,
                     payer: str, payee: str) -> None:
    """Move `amount` of deposit money from payer (at payer_bank) to payee (at payee_bank).

    Deposits are liabilities named "deposit:<name>". Interbank settlement is in reserves:
    the payer's bank loses reserves and a deposit liability; the payee's bank gains both.
    If payer_bank has fewer reserves than `amount`, raise ValueError and change nothing.
    """
    raise NotImplementedError("TODO: check reserves, then call apply on both banks")


def parse_fred_csv(text: str) -> pd.Series:
    """Parse FRED CSV text into a float Series with a DatetimeIndex.

    The first column is the date, whatever its header (FRED now writes `observation_date`;
    older files say `DATE`). The second column holds the values and its header is the
    series ID: use it as the Series name. FRED marks missing observations with ".":
    treat them as NaN and drop them.
    """
    raise NotImplementedError("TODO: read_csv(na_values=['.']), rename first column, set index, dropna")


def main() -> None:
    text = snapshot_path("fred", "DFF.csv").read_text()
    dff = parse_fred_csv(text)
    last_date, last = dff.index[-1], dff.iloc[-1]
    year_ago = dff.loc[:last_date - pd.DateOffset(years=1)].iloc[-1]
    print(f"Effective fed funds rate on {last_date.date()}: {last:.2f}% (percent per year)")
    print(f"One year earlier: {year_ago:.2f}%  ->  change {last - year_ago:+.2f} percentage points")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day01.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(9, 4))
    dff.loc["2000":].plot(ax=ax)
    ax.set_title("Effective federal funds rate (DFF), percent")
    ax.set_ylabel("percent")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
