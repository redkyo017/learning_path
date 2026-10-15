"""Day 17 lab: investing across currencies -- VND-based returns, hedging and costs.

Goal: turn a USD asset return into the return a VND-based investor feels (home_return, vnd_returns),
price what a currency hedge adds or removes (hedged_return), and subtract the round-trip costs that
compound against you (net_return). main() restates SPY in VND since 2010, splits the CAGR into asset
and currency parts, and compares SPY-in-VND with the VN-Index.
Convention: returns are simple decimals (0.10 = +10%); fx_ret is the change of the foreign currency
in HOME terms (USD/VND up 5% = +0.05 for a VND investor). VND_X is VND per USD.
Caveat: VN-Index is a price index (no dividends) while SPY here is dividend-adjusted, so that
comparison flatters SPY by roughly the dividend yield.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_prices, load_vn
from common.quant import cagr

FEE_BPS = 20        # assumed one-way brokerage/platform fee, basis points
FX_SPREAD_BPS = 50  # assumed one-way FX conversion spread, basis points


def home_return(asset_ret: float, fx_ret: float) -> float:
    """Return in home currency: (1 + asset_ret) * (1 + fx_ret) - 1.

    `fx_ret` is the foreign currency's change measured in home currency.
    """
    # Returns multiply, they do not add: the +5% FX move also applies to the +10% gain.
    return (1 + asset_ret) * (1 + fx_ret) - 1


def hedged_return(asset_ret: float, r_home: float, r_foreign: float, t: float = 1.0) -> float:
    """Return of the asset with its currency risk hedged forward, in home currency.

    (1 + asset_ret) * (1 + r_home*t) / (1 + r_foreign*t) - 1. The hedge locks the forward premium,
    so you earn the home rate instead of the foreign one.
    """
    # CIP: forward/spot = (1 + r_home t)/(1 + r_foreign t); selling the foreign currency forward locks it in.
    return (1 + asset_ret) * (1 + r_home * t) / (1 + r_foreign * t) - 1


def vnd_returns(usd_prices: pd.Series, usdvnd: pd.Series) -> pd.Series:
    """Daily simple returns of a USD price series restated in VND, named "vnd_return".

    Align `usdvnd` to the price dates (forward-fill FX holidays), multiply, pct_change, drop the first NaN.
    """
    fx = usdvnd.reindex(usd_prices.index).ffill()   # a missing FX print carries the last known rate
    vnd = usd_prices * fx
    return vnd.pct_change().dropna().rename("vnd_return")


def net_return(gross: float, fee_bps: float, fx_spread_bps: float) -> float:
    """Round-trip net return: (1+gross) * (1 - fee) * (1 - spread)**2 - 1, with bps converted to decimals.

    The fee is charged once on the way out; the FX spread is paid twice (VND to USD, then back).
    """
    fee = fee_bps / 1e4
    spread = fx_spread_bps / 1e4
    return (1 + gross) * (1 - fee) * (1 - spread) ** 2 - 1


def main() -> None:
    px = load_prices(["SPY", "EEM", "VNM", "VND=X"])
    fx = px["VND=X"].dropna()
    vnindex = load_vn("VNINDEX")
    start = pd.Timestamp("2010-01-04")

    spy = px["SPY"].dropna()
    spy = spy[spy.index >= start]
    fxs = fx.reindex(spy.index).ffill().dropna()
    spy = spy.loc[fxs.index]
    spy_vnd = spy * fxs

    years = (spy.index[-1] - spy.index[0]).days / 365.25
    c_usd = cagr(spy)
    c_vnd = cagr(spy_vnd)
    c_fx = cagr(fxs)
    print(f"SPY since {spy.index[0].date()} to {spy.index[-1].date()} ({years:.1f} y)")
    print(f"  USD CAGR {c_usd:.2%} | USD/VND CAGR {c_fx:+.2%} | VND CAGR {c_vnd:.2%} (check {(1 + c_usd) * (1 + c_fx) - 1:.2%})")
    print(f"  FX added {c_vnd - c_usd:+.2%} per year to a VND investor")

    both = pd.concat([spy_vnd.rename("spy_vnd"), vnindex.rename("vnindex")], axis=1, sort=True).dropna()
    by = (both.index[-1] - both.index[0]).days / 365.25
    print(f"SPY in VND CAGR {cagr(both['spy_vnd']):.2%} vs VN-Index (price only) {cagr(both['vnindex']):.2%}")
    print(f"Round trip on a +10% gross: net {net_return(0.10, FEE_BPS, FX_SPREAD_BPS):.2%}")
    print(f"Hedged SPY year at +10% (VND 5.9%, USD 4.5%): {hedged_return(0.10, 0.059, 0.045):.2%}"
          f" vs unhedged with flat FX {home_return(0.10, 0.0):.2%}")

    series = {"SPY (USD)": spy, "SPY in VND": spy_vnd, "VN-Index": vnindex}
    for tk in ("EEM", "VNM"):
        s = px[tk].dropna()
        f = fx.reindex(s.index).ffill().dropna()
        series[f"{tk} in VND"] = (s.loc[f.index] * f)
    df = pd.concat(series, axis=1, sort=True)
    df = df[df.index >= "2015-01-01"].dropna()
    reb = df / df.iloc[0] * 100
    fig, ax = plt.subplots(figsize=(9, 5))
    reb.plot(ax=ax, logy=True)
    ax.set_title("Rebased to 100 (log), all in VND unless marked USD")
    out = Path(__file__).resolve().parent.parent / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig.savefig(out / "day17.png", dpi=110, bbox_inches="tight")


if __name__ == "__main__":
    main()
