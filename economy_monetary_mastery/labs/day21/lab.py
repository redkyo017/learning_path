"""Day 21 lab: how three stablecoin designs die.

Goal: implement the arithmetic behind a crypto-collateralised stablecoin (max_mint,
liquidation_price, liquidations), the reflexive mint-and-burn loop of an algorithmic
stablecoin (terra_spiral) and the coverage ratio of a fiat-backed one (reserve_coverage).
Implement the five TODO functions; the rest is given. main() runs a vault book through
ETH's May-June 2022 price path and a stylised Terra-like spiral.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from common.data import load_crypto_ohlcv

MIN_RATIO = 1.5  # a Maker-style minimum collateral ratio (150%)


def max_mint(collateral_value: float, min_ratio: float) -> float:
    """Largest stablecoin debt a vault can carry: collateral_value / min_ratio.

    Example: 150 of collateral at a 1.5 minimum ratio supports 100 of debt.
    """
    raise NotImplementedError("TODO: collateral_value / min_ratio")


def liquidation_price(collateral_amount: float, debt: float, min_ratio: float) -> float:
    """Collateral price at which the vault hits the minimum ratio: debt * min_ratio / amount.

    Example: 1 ETH backing 1000 of debt at 1.5 is liquidated at a price of 1500.
    """
    raise NotImplementedError("TODO: debt * min_ratio / collateral_amount")


def liquidations(vaults: list[dict], prices: list[float], min_ratio: float) -> list[tuple[int, int]]:
    """Walk the price path and return (price_step, vault_index) for each liquidation.

    Each vault dict has `amount` (collateral units) and `debt`. A vault is liquidated at
    the first step where amount * price / debt < min_ratio, and only once. Steps are
    0-based positions in `prices`. Output is ordered by step, then by vault index.
    Vaults with debt <= 0 are never liquidated.
    """
    raise NotImplementedError("TODO: scan steps; skip vaults already liquidated")


def terra_spiral(ust_supply: float, luna_supply: float, luna_price: float,
                 redemption_fracs: list[float]) -> list[dict]:
    """Simulate a mint-and-burn peg: each step, a fraction of UST is redeemed for LUNA.

    For step i (1-based) with fraction f: R = f * ust_supply (UST burned, worth R dollars of
    newly minted LUNA at the current price). mcap_after = luna_price * luna_supply - R.
    - If mcap_after <= 0: record status "collapsed", luna_price 0.0, ust_supply -= R, and stop.
    - Otherwise minted = R / luna_price; luna_supply += minted; luna_price = mcap_after / luna_supply;
      ust_supply -= R; status "ok".
    Return one dict per step with keys: step, status, ust_supply, luna_supply, luna_price.
    """
    raise NotImplementedError("TODO: burn UST, mint LUNA at the old price, reprice from market cap")


def reserve_coverage(reserves: float, supply: float) -> float:
    """Reserves divided by stablecoin supply (1.0 = fully backed at face value).

    Raise ValueError if supply <= 0.
    """
    raise NotImplementedError("TODO: reserves / supply; ValueError if supply <= 0")


def main() -> None:
    eth = load_crypto_ohlcv("ETH/USDT")["close"]["2022-05-01":"2022-07-01"]
    prices = [float(p) for p in eth.values]
    p0 = prices[0]
    # Six vaults of 10 ETH, opened at the first close with different starting collateral ratios.
    ratios = [1.6, 1.75, 2.0, 2.5, 3.0, 4.0]
    vaults = [{"amount": 10.0, "debt": 10.0 * p0 / r} for r in ratios]
    print(f"ETH/USDT close {eth.index[0].date()} -> {eth.index[-1].date()}: {p0:,.0f} -> {prices[-1]:,.0f} "
          f"(low {min(prices):,.0f} on {eth.idxmin().date()})")
    for i, v in enumerate(vaults):
        print(f"  vault {i}: debt {v['debt']:,.0f}, opened at {ratios[i]:.2f}x, "
              f"liquidation price {liquidation_price(v['amount'], v['debt'], MIN_RATIO):,.0f}")
    events = liquidations(vaults, prices, MIN_RATIO)
    print("Liquidation timeline:")
    for step, idx in events:
        print(f"  {eth.index[step].date()} (step {step}): vault {idx} liquidated at ETH {prices[step]:,.0f}")
    if not events:
        print("  none")
    print(f"  {len(events)} of {len(vaults)} vaults liquidated")

    # Stylised Terra-like spiral (not Terra's exact numbers). The start is deliberately past the
    # tipping point (UST $18bn > LUNA cap $17bn) to compress the dynamics; real LUNA cap was higher.
    fracs = [0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.15, 0.20, 0.25, 0.30, 0.40, 0.50, 0.60, 0.70]
    path = terra_spiral(18_000.0, 340.0, 50.0, fracs)  # UST $18bn, LUNA 340m at $50 (cap $17bn < UST)
    print("Stylised spiral (UST in $m, LUNA in m):")
    for s in path:
        print(f"  step {s['step']:>2}: {s['status']:<9} UST {s['ust_supply']:>9,.0f}  "
              f"LUNA supply {s['luna_supply']:>9,.0f}  LUNA price {s['luna_price']:>7.2f}")
    print(f"Fiat-backed contrast: reserve_coverage(98, 100) = {reserve_coverage(98.0, 100.0):.2f}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day21.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(1, 2, figsize=(11, 4))
    ax[0].plot(eth.index, prices, color="tab:blue")
    for v in vaults:
        ax[0].axhline(liquidation_price(v["amount"], v["debt"], MIN_RATIO), color="tab:red", alpha=0.25)
    ax[0].set_title("ETH/USDT close with vault liquidation prices")
    ax[0].tick_params(axis="x", rotation=30)
    steps = [0] + [s["step"] for s in path]
    ax[1].plot(steps, [50.0] + [s["luna_price"] for s in path], color="tab:orange", label="LUNA price")
    ax[1].set_xlabel("redemption step")
    ax[1].set_ylabel("LUNA price ($)")
    ax2 = ax[1].twinx()
    ax2.plot(steps, [340.0] + [s["luna_supply"] for s in path], color="tab:purple", label="LUNA supply (m)")
    ax2.set_ylabel("LUNA supply (m)")
    ax[1].set_title("Stylised Terra-like spiral")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
