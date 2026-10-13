"""Day 22 lab: a constant-product AMM (x*y=k), impermanent loss, and a sandwich attack.

Goal: build the Uniswap-v2-style pool (price, k, swaps with a fee that stays in the pool), compute
impermanent loss from a price ratio, compare LP value with simply holding, and measure what a
sandwich bot extracts from a victim swap. Pool reserves x (token X, e.g. ETH) and y (token Y,
e.g. USDT); price is y per x. main() opens a fee-free LP at the first ETH/USDT close of the
Binance snapshot (2021-01-01 onward) and tracks LP vs hold value over time.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from common.data import load_crypto_ohlcv


class ConstantProductPool:
    """Constant-product pool holding x of token X and y of token Y, with a proportional fee.

    The fee is taken from the input and stays in the pool, so k = x*y grows with every swap.
    """

    def __init__(self, x: float, y: float, fee: float = 0.003):
        self.x = x
        self.y = y
        self.fee = fee

    def price(self) -> float:
        """Marginal price of X in units of Y (y per x): y / x."""
        raise NotImplementedError("TODO: y / x")

    def k(self) -> float:
        """The invariant product x * y."""
        raise NotImplementedError("TODO: x * y")

    def swap_x_for_y(self, dx: float) -> float:
        """Sell dx of X into the pool; return the Y received and update reserves.

        Raise ValueError if dx <= 0. Only dx*(1-fee) is priced; the full dx joins the reserves.
        """
        raise NotImplementedError("TODO: eff = dx*(1-fee); dy = y*eff/(x+eff); x += dx; y -= dy")

    def swap_y_for_x(self, dy: float) -> float:
        """Sell dy of Y into the pool; return the X received and update reserves.

        Raise ValueError if dy <= 0. Mirror image of swap_x_for_y.
        """
        raise NotImplementedError("TODO: mirror of swap_x_for_y")


def impermanent_loss(price_ratio: float) -> float:
    """Impermanent loss of a 50/50 constant-product LP versus holding, for r = new_price / old_price.

    Returns a fraction (<= 0): LP value / hold value - 1.
    """
    raise NotImplementedError("TODO: 2*sqrt(r)/(1+r) - 1")


def lp_vs_hold(x0: float, y0: float, new_price: float) -> tuple[float, float]:
    """Fee-free (LP value, hold value) in Y units once the pool price moves to new_price.

    The pool starts with x0, y0; arbitrage moves its reserves to the new price keeping k fixed.
    """
    raise NotImplementedError("TODO: k=x0*y0; x1=sqrt(k/p); y1=sqrt(k*p); lp=x1*p+y1; hold=x0*p+y0")


def sandwich(x: float, y: float, fee: float, victim_dx: float, attacker_dx: float) -> dict:
    """Simulate a sandwich on a victim's x->y swap.

    Returns {"attacker_profit_x", "victim_dy", "victim_dy_no_attack"}. Baseline: a fresh pool and
    only the victim swap. Attack: a fresh pool; attacker sells attacker_dx of X for Y (got_y); the
    victim swaps; the attacker sells got_y back for X (back_x). Profit = back_x - attacker_dx.
    """
    raise NotImplementedError("TODO: two fresh pools; baseline victim only; attack front/victim/back")


def main() -> None:
    df = load_crypto_ohlcv("ETH/USDT")
    close = df["close"].loc["2021-01-01":]
    p0 = float(close.iloc[0])
    x0, y0 = 100.0, 100.0 * p0  # a 100 ETH / 50-50 position at the starting price
    lp, hold = [], []
    for p in close:
        a, b = lp_vs_hold(x0, y0, float(p))
        lp.append(a)
        hold.append(b)
    il = lp[-1] / hold[-1] - 1
    years = (close.index[-1] - close.index[0]).days / 365.25
    breakeven_apr = -il / years
    print(f"ETH/USDT {close.index[0]:%Y-%m-%d} -> {close.index[-1]:%Y-%m-%d}: {p0:,.0f} -> {close.iloc[-1]:,.0f} "
          f"(ratio {close.iloc[-1] / p0:.2f})")
    print(f"  LP value {lp[-1]:,.0f} vs hold {hold[-1]:,.0f} USDT; impermanent loss {il:.1%}")
    print(f"  formula check: {impermanent_loss(close.iloc[-1] / p0):.1%}")
    print(f"  fee APR needed to offset it over {years:.1f} years: {breakeven_apr:.1%} of hold value per year (simple)")
    s = sandwich(1_000.0, 1_000.0 * p0, 0.003, victim_dx=50.0, attacker_dx=100.0)
    print(f"  sandwich on a 50 ETH swap (pool 1,000 ETH): attacker {s['attacker_profit_x']:+.3f} ETH, "
          f"victim gets {s['victim_dy']:,.0f} vs {s['victim_dy_no_attack']:,.0f} USDT")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(close.index, hold, label="hold")
    ax.plot(close.index, lp, label="LP (fee-free)")
    ax.set_ylabel("USDT")
    ax.set_title("ETH/USDT: LP vs hold from 2021-01-01")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out / "day22.png", dpi=120)
    plt.close(fig)


if __name__ == "__main__":
    main()
