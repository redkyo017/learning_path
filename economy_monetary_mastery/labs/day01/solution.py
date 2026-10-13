"""Day 01 reference solution: money as balance sheets.

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
        assets, liabilities = assets or {}, liabilities or {}
        # Check first: a rejected entry must not leave half an entry behind.
        diff = sum(assets.values()) - sum(liabilities.values())
        if abs(diff) > TOLERANCE:
            raise UnbalancedError(f"{self.owner}: assets change by {sum(assets.values())}, "
                                  f"liabilities by {sum(liabilities.values())}")
        for k, v in assets.items():
            self.assets[k] = self.assets.get(k, 0) + v
        for k, v in liabilities.items():
            self.liabilities[k] = self.liabilities.get(k, 0) + v

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
    if payer_bank.assets.get("reserves", 0) < amount:
        raise ValueError(f"{payer_bank.owner} has too few reserves to settle {amount}")
    # Both entries balance on their own: reserves and deposits move together at each bank.
    payer_bank.apply(assets={"reserves": -amount}, liabilities={f"deposit:{payer}": -amount})
    payee_bank.apply(assets={"reserves": amount}, liabilities={f"deposit:{payee}": amount})


def parse_fred_csv(text: str) -> pd.Series:
    """Parse FRED CSV text into a float Series with a DatetimeIndex.

    The first column is the date, whatever its header (FRED now writes `observation_date`;
    older files say `DATE`). The second column holds the values and its header is the
    series ID: use it as the Series name. FRED marks missing observations with ".":
    treat them as NaN and drop them.
    """
    df = pd.read_csv(io.StringIO(text), na_values=["."])
    series_id = df.columns[1]
    df = df.rename(columns={df.columns[0]: "date"})  # header name varies: observation_date / DATE
    df["date"] = pd.to_datetime(df["date"])
    return df.set_index("date")[series_id].astype(float).dropna().rename(series_id)


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
