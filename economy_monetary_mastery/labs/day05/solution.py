"""Day 05 lab: duration, mark-to-market and drawdowns, through SVB's 2022 balance sheet.

Goal: price the interest-rate sensitivity of a bond book (duration_price_change,
convexity_price_change), see what marking unrealized losses does to equity
(equity_after_marking), and measure the worst peak-to-trough fall of a price series
(drawdown_series, max_drawdown). Implement the five TODO functions; the rest is given.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_fred, load_prices

# SVB Financial Group, balance sheet at 2022-12-31 (US$ billions).
# Sources (checked 2026-10-11):
#  - FY2022 Form 10-K, balance sheet: HTM securities "at amortized cost ... (fair value of $76,169)"
#    = 91,321 million; Item 1: total deposits $173.1bn, stockholders' equity $16.0bn.
#    https://www.sec.gov/Archives/edgar/data/719739/000071973923000021/sivb-20221231.htm
#  - Fed, Review of the Federal Reserve's Supervision and Regulation of SVB (2023-04-28):
#    $21bn of AFS securities sold for a $1.8bn after-tax loss (announced 2023-03-08); "over $40
#    billion" of deposits lost on 2023-03-09.
#    https://www.federalreserve.gov/publications/review-of-the-federal-reserves-supervision-and-regulation-of-silicon-valley-bank.htm
#  - California DFPI (2023-05-08): about $42bn of withdrawal requests within eight hours on 2023-03-09.
#    https://dfpi.ca.gov/wp-content/uploads/sites/337/2023/05/23-05-08-SVB-DFPI-Review-PR.pdf
HTM_AMORTIZED_COST_BN = 91.3  # 10-K: 91,321 million
HTM_FAIR_VALUE_BN = 76.2      # 10-K: 76,169 million
TOTAL_EQUITY_BN = 16.0        # 10-K Item 1
AFS_SOLD_BN = 21.0            # Fed review: sale announced 2023-03-08
AFS_LOSS_BN = 1.8             # Fed review (after-tax loss on the AFS sale)
DEPOSITS_BN = 173.1           # 10-K Item 1: $173.1bn
WITHDRAWN_MAR9_BN = 42.0      # DFPI: withdrawal requests on 2023-03-09 (Fed: "over $40bn")


def duration_price_change(value: float, mod_duration: float, dy: float) -> float:
    """First-order change in a bond position's value for a yield change `dy` (decimal, 0.02 = +2 pts).

    Modified duration is the % price change per 1 percentage point (0.01) of yield, scaled so
    that change = -mod_duration * dy * value. Returns the change in value (negative when yields rise).
    """
    return -mod_duration * dy * value


def convexity_price_change(value: float, mod_duration: float, convexity: float, dy: float) -> float:
    """Second-order change in value: the duration term plus the convexity correction.

    change = -mod_duration * dy * value + 0.5 * convexity * dy**2 * value. Convexity always
    helps the holder, so it makes a loss smaller and a gain bigger.
    """
    # Taylor expansion of price in yield: first order (duration) + second order (convexity).
    return -mod_duration * dy * value + 0.5 * convexity * dy**2 * value


def equity_after_marking(equity: float, unrealized_loss: float) -> float:
    """Book equity if unrealized losses were recognised: equity - unrealized_loss.

    A negative `unrealized_loss` is an unrealized gain and raises equity.
    """
    return equity - unrealized_loss


def drawdown_series(prices: pd.Series) -> pd.Series:
    """Fractional distance below the running peak at every date (0 at a new high, else negative).

    drawdown_t = price_t / max(price_0..price_t) - 1.
    """
    # cummax is the running peak; the ratio to it is the fractional distance below it.
    return prices / prices.cummax() - 1


def max_drawdown(prices: pd.Series) -> float:
    """The worst (most negative) drawdown of the series; 0 for a series that never falls."""
    return drawdown_series(prices).min()


def main() -> None:
    dgs2, dgs10 = load_fred("DGS2").dropna(), load_fred("DGS10").dropna()
    d1, d2 = pd.Timestamp("2021-12-31"), pd.Timestamp("2022-12-30")
    print("Treasury yields (%), end-2021 -> end-2022:")
    for name, s in (("2y", dgs2), ("10y", dgs10)):
        a, b = s[:d1].iloc[-1], s[:d2].iloc[-1]
        print(f"  {name}: {a:.2f} -> {b:.2f}  ({b - a:+.2f} pts)")
    dy10 = (dgs10[:d2].iloc[-1] - dgs10[:d1].iloc[-1]) / 100.0

    loss = HTM_AMORTIZED_COST_BN - HTM_FAIR_VALUE_BN
    implied_d = (loss / HTM_AMORTIZED_COST_BN) / dy10
    print(f"SVB HTM book: cost {HTM_AMORTIZED_COST_BN} fair {HTM_FAIR_VALUE_BN} -> unrealized loss "
          f"{loss:.1f}bn ({loss / HTM_AMORTIZED_COST_BN:.1%}); implied duration {implied_d:.1f} (10y move)")
    check = duration_price_change(HTM_AMORTIZED_COST_BN, implied_d, dy10)
    print(f"  duration formula on the same book: {check:.1f}bn")
    print(f"  equity {TOTAL_EQUITY_BN}bn -> {equity_after_marking(TOTAL_EQUITY_BN, loss):.1f}bn after marking HTM;"
          f" withdrawals on 9 Mar were {WITHDRAWN_MAR9_BN / DEPOSITS_BN:.0%} of deposits")

    tlt = load_prices("TLT")["TLT"].dropna()
    tlt = tlt[tlt.index >= "2020-01-01"]
    dd = drawdown_series(tlt)
    print(f"TLT max drawdown since 2020: {max_drawdown(tlt):.1%}, trough {dd.idxmin().date()}, "
          f"peak {tlt[:dd.idxmin()].idxmax().date()}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day05.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.fill_between(dd.index, dd.values * 100, 0, color="tab:red", alpha=0.4)
    ax.set_ylabel("drawdown from running peak (%)")
    ax.set_title("TLT (20y+ Treasuries) drawdown since 2020")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
