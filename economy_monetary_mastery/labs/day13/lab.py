"""Day 13 lab: FX mechanics -- forwards, covered interest parity, carry.

Goal: price a forward from spot and two interest rates (forward_rate, forward_points), measure how
far a quoted forward sits from the no-arbitrage level (cip_deviation_bp), and compute the realized
return of a carry trade and of simply holding a currency (carry_trade_return, fx_return).
Convention: `spot` is QUOTE-currency units per 1 BASE-currency unit (USD/VND = 25,000 means
1 USD = 25,000 VND). Rates are simple annual decimals; `t` is in years. main() prices a 1-year
USD/VND forward from assumed deposit rates and compares it with what VND actually did.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_prices

# Assumed 12-month deposit rates (annual, decimal), as of 2026-10; see content/day13.md.
R_VND = 0.059   # Vietcombank 12m VND counter rate
R_USD = 0.045   # roughly the US 1-year Treasury yield (FRED DGS1)


def forward_rate(spot: float, r_quote: float, r_base: float, t: float) -> float:
    """No-arbitrage (covered interest parity) forward: spot * (1 + r_quote*t) / (1 + r_base*t).

    `spot` is quote units per 1 base unit. Raise ValueError if t <= 0.
    """
    raise NotImplementedError("TODO: S*(1+r_q t)/(1+r_b t), ValueError if t <= 0")


def forward_points(spot: float, r_quote: float, r_base: float, t: float) -> float:
    """Forward points: forward_rate(...) - spot, in quote units. Positive = base currency at a forward premium."""
    raise NotImplementedError("TODO: forward_rate(...) - spot")


def cip_deviation_bp(spot: float, forward: float, r_quote: float, r_base: float, t: float) -> float:
    """How far a quoted `forward` is from the CIP-fair forward, in basis points of the fair forward.

    (forward / fair - 1) * 10,000. Zero means no arbitrage; positive means the quoted forward is richer than fair.
    """
    raise NotImplementedError("TODO: (forward / forward_rate(...) - 1) * 1e4")


def carry_trade_return(spot_start: float, spot_end: float, r_invest: float, r_fund: float, t: float) -> float:
    """Unhedged carry trade return per 1 unit of funding currency.

    Borrow 1 unit of the funding currency (repay 1 + r_fund*t), convert to the investment currency at
    `spot_start`, deposit at r_invest, convert back at `spot_end`. Both spots are investment-currency
    per funding-currency. Return = spot_start*(1 + r_invest*t)/spot_end - (1 + r_fund*t).
    """
    raise NotImplementedError("TODO: S0*(1+ri t)/S1 - (1+rf t)")


def fx_return(spot_start: float, spot_end: float) -> float:
    """Return of holding the BASE currency, in quote terms: spot_end / spot_start - 1."""
    raise NotImplementedError("TODO: spot_end / spot_start - 1")


def main() -> None:
    px = load_prices(["VND=X"]).iloc[:, 0].dropna()
    spot = float(px.iloc[-1])
    t = 1.0
    fwd = forward_rate(spot, R_VND, R_USD, t)
    pts = forward_points(spot, R_VND, R_USD, t)
    print(f"USD/VND spot {spot:,.0f} on {px.index[-1].date()} (VND per USD)")
    print(f"Assumed 12m rates: VND {R_VND:.1%}, USD {R_USD:.1%}")
    print(f"1y CIP forward {fwd:,.0f} -> points {pts:+,.0f} ({pts / spot:+.2%}); the forward implies VND at a {pts / spot:.2%} discount")
    print(f"Quoted forward 0.5% above fair would be a {cip_deviation_bp(spot, fwd * 1.005, R_VND, R_USD, t):.0f} bp CIP deviation")

    # UIP test: realized change over the following ~1 year (252 trading days) vs the constant forward premium.
    d = px[px.index >= "2015-01-01"]
    realized = pd.Series(
        [fx_return(a, b) for a, b in zip(d.values[:-252], d.values[252:])], index=d.index[:-252])
    prem = pts / spot
    print(f"Realized 1y USD/VND change since 2015: mean {realized.mean():+.2%}, "
          f"min {realized.min():+.2%}, max {realized.max():+.2%} ({len(realized)} overlapping windows)")
    print(f"Forward premium {prem:+.2%}; realized change exceeded it in {(realized > prem).mean():.0%} of windows")
    carry = pd.Series(
        [carry_trade_return(a, b, R_VND, R_USD, t) for a, b in zip(d.values[:-252], d.values[252:])],
        index=realized.index)
    print(f"Hypothetical borrow-USD / hold-VND carry at today's rates, per 1 USD: mean {carry.mean():+.2%}, "
          f"worst {carry.min():+.2%}, losing windows {(carry < 0).mean():.0%} (ignores spreads and capital controls)")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day13.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4))
    ax1.plot(d.index, d.values)
    ax1.scatter([d.index[-1] + pd.Timedelta(days=365)], [fwd], color="red", zorder=3, label="1y forward")
    ax1.set_title("USD/VND spot and the 1y forward")
    ax1.legend()
    ax2.plot(realized.index, realized.values * 100, label="realized next-12m change")
    ax2.axhline(prem * 100, color="red", linestyle="--", label="forward premium (constant)")
    ax2.set_ylabel("%")
    ax2.set_title("What the forward 'predicted' vs what happened")
    ax2.legend()
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
