"""Day 23 lab: perpetual-futures funding, basis and the cash-and-carry trade.

Goal: annualize a funding-rate series, measure futures basis, compute the profit of a
cash-and-carry (long spot, short future) that is held to convergence, and the cash flows of
paying or receiving funding on a perpetual. main() runs a "long spot + short perp" carry on the
Binance BTC snapshot from 2021-01-01, collecting funding and ignoring fees, margin costs,
borrowing and exchange risk.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_crypto_ohlcv, load_funding


def annualized_funding(rates: pd.Series, periods_per_day: int = 3) -> float:
    """Simple (non-compounded) annualized funding: mean rate per period * periods per day * 365.

    Default 3 periods per day matches the 8-hour funding interval. Positive means longs pay shorts.
    """
    # mean rate per period x periods per day x days per year (simple, not compounded)
    return float(rates.mean()) * periods_per_day * 365


def basis_pct(spot: float, future: float) -> float:
    """Basis as a fraction of spot: (future - spot) / spot. Positive = contango."""
    return (future - spot) / spot


def annualized_basis(spot: float, future: float, days: float) -> float:
    """Basis scaled to a year: basis_pct * 365 / days. Raise ValueError if days <= 0."""
    if days <= 0:
        raise ValueError("days must be positive")
    return basis_pct(spot, future) * 365 / days


def cash_and_carry_pnl(spot_entry: float, fut_entry: float, spot_exit: float, fut_exit: float,
                       qty: float) -> float:
    """Profit of long `qty` spot and short `qty` future, in quote currency, before fees/funding.

    Spot leg gains spot_exit - spot_entry; the short future gains fut_entry - fut_exit.
    """
    # the two price moves cancel when futures converge to spot; what is left is the entry basis
    return qty * ((spot_exit - spot_entry) - (fut_exit - fut_entry))


def funding_pnl(notional: float, rates: list[float], side: str) -> float:
    """Total funding cash flow on a perpetual position of fixed `notional`, over the given rates.

    side "short" receives sum(notional * rate) (it pays when rates are negative); side "long"
    pays it, so its result is the negative. Raise ValueError for any other side.
    """
    if side not in ("short", "long"):
        raise ValueError(f"side must be 'short' or 'long', got {side!r}")
    total = notional * sum(rates)
    return total if side == "short" else -total


def main() -> None:
    fund = load_funding()
    spot = load_crypto_ohlcv("BTC/USDT")["close"]
    perp = load_crypto_ohlcv("BTC/USDT:USDT")["close"]

    print("Annualized BTC perp funding (simple, 3 x 365) and share of negative periods, by year")
    for yr, g in fund.groupby(fund.index.year):
        print(f"  {yr}: {annualized_funding(g):+7.1%}   negative periods {float((g < 0).mean()):5.1%}")

    px = pd.concat([spot.rename("spot"), perp.rename("perp")], axis=1).dropna()
    basis = px["perp"] / px["spot"] - 1
    q = basis.quantile([0.05, 0.5, 0.95])
    print(f"Perp - spot daily basis: median {q[0.5]:+.3%}, 5th {q[0.05]:+.3%}, 95th {q[0.95]:+.3%}")

    start = "2021-01-01"
    daily_fund = fund.resample("D").sum()
    d = px.loc[start:].join(daily_fund.rename("fund"), how="inner")
    legs = d["spot"].pct_change() - d["perp"].pct_change()  # long spot, short perp, 1 unit notional each
    carry = (legs.fillna(0.0) + d["fund"]).cumsum()  # per unit of notional, simple, no fees
    hodl = d["spot"] / d["spot"].iloc[0] - 1
    years = (d.index[-1] - d.index[0]).days / 365.25
    print(f"Carry from {start} (funding + leg drift, no fees): {carry.iloc[-1]:+.1%} of notional "
          f"over {years:.1f}y, about {carry.iloc[-1] / years:+.1%}/yr; BTC buy-and-hold {hodl.iloc[-1]:+.0%}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(carry.index, carry * 100, label="carry (funding + leg drift)")
    ax.plot(hodl.index, hodl * 100, label="BTC buy-and-hold", alpha=0.6)
    ax.set_ylabel("% of notional")
    ax.set_title("Short perp + long spot vs BTC (Binance, no fees)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out / "day23.png", dpi=120)
    plt.close(fig)


if __name__ == "__main__":
    main()
