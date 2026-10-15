"""Day 02 lab: banks create money, and can be run.

Goal: model a bank balance sheet where lending creates deposits (Bank.lend), measure its
capital and liquidity ratios, simulate a bank run with fire sales (bank_run), and compute
simple vs log returns (simple_returns, log_returns). Implement the six TODO functions;
the rest is given.
"""
import copy
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from common.data import load_prices


@dataclass
class Bank:
    """A bank balance sheet: reserves + loans = deposits + equity."""
    name: str
    reserves: float
    loans: float
    deposits: float
    equity: float

    def lend(self, amount: float) -> None:
        """Make a loan of `amount`: the bank creates a new deposit for the borrower.

        Loans and deposits both rise by `amount`; reserves and equity do not change.
        """
        raise NotImplementedError("TODO: loans += amount and deposits += amount")

    def capital_ratio(self) -> float:
        """Equity divided by loans (a simple leverage-style capital ratio)."""
        raise NotImplementedError("TODO: equity / loans")

    def liquidity_ratio(self) -> float:
        """Reserves divided by deposits (how much of the deposits can be paid out at once)."""
        raise NotImplementedError("TODO: reserves / deposits")


def bank_run(bank: Bank, withdrawal_fractions: list[float], fire_sale_haircut: float) -> list[dict]:
    """Simulate successive withdrawal waves against a copy of `bank`.

    For step k (1-indexed): need = frac * deposits; pay min(need, reserves) from reserves.
    Any shortfall is met by selling loans with book value x = shortfall / (1 - haircut),
    which raises x * (1 - haircut) cash and books a loss x * haircut against equity. If
    x exceeds the loans held, sell all loans (raising loans * (1 - haircut)); the unpaid
    remainder of the shortfall stays as deposits. Then deposits -= paid in total.
    Append {"step", "reserves", "loans", "deposits", "equity", "status"}; status is
    "insolvent" if equity <= 0 or the shortfall was not fully paid, else "ok". Stop after
    the first "insolvent" state. The input bank must not be mutated.
    """
    raise NotImplementedError("TODO: deepcopy, loop over fractions, pay from reserves then fire-sell loans")


def simple_returns(prices: pd.Series) -> pd.Series:
    """Simple returns p_t / p_{t-1} - 1, with the leading NaN dropped."""
    raise NotImplementedError("TODO: prices.pct_change().dropna()")


def log_returns(prices: pd.Series) -> pd.Series:
    """Log returns ln(p_t / p_{t-1}), with the leading NaN dropped."""
    raise NotImplementedError("TODO: np.log(prices / prices.shift(1)).dropna()")


def main() -> None:
    textbook = Bank("textbook", reserves=10.0, loans=90.0, deposits=90.0, equity=10.0)
    print(f"Textbook bank: capital ratio {textbook.capital_ratio():.3f}, "
          f"liquidity ratio {textbook.liquidity_ratio():.3f}")
    haircuts = [0.1, 0.3, 0.5]
    terminal = {}
    for h in haircuts:
        states = bank_run(textbook, [0.5, 0.5], fire_sale_haircut=h)
        terminal[h] = states[-1]
        s = states[-1]
        print(f"50% run, haircut {h:.0%}: step {s['step']} {s['status']:9s} reserves {s['reserves']:.1f} "
              f"loans {s['loans']:.1f} deposits {s['deposits']:.1f} equity {s['equity']:.1f}")

    spy = load_prices("SPY")["SPY"]
    simple, logr = simple_returns(spy), log_returns(spy)
    print(f"SPY daily mean: simple {simple.mean():.5%}, log {logr.mean():.5%} "
          f"(gap {simple.mean() - logr.mean():.5%} ~ half the variance)")
    print(f"SPY total: compounded simple {(1 + simple).prod() - 1:.1%}, exp(sum of log) - 1 "
          f"{np.exp(logr.sum()) - 1:.1%}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day02.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar([f"{h:.0%}" for h in haircuts], [terminal[h]["equity"] for h in haircuts])
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_xlabel("fire-sale haircut")
    ax.set_ylabel("equity after the run")
    ax.set_title("Textbook bank, 50% run: equity vs haircut")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
