"""Day 16 lab: Vietnam -- the SBV band, exchange price limits and foreign room.

Goal: compute the +/-5% USD/VND trading band around a central rate (sbv_band, within_band), the
daily price floor and ceiling of a Vietnamese stock under tick rounding (hose_tick, price_limits),
flag days that closed at a limit (flag_limit_moves), and the foreign-ownership room left in a
company (foreign_room). main() runs these on VN-Index, FPT, HPG, VCB and USD/VND snapshots.
Caveats: Vietcap closes are dividend/split-adjusted, so limit-hit detection on them is
approximate; SBV central-rate history is not in the snapshot, so the band demo uses a labelled
60-day rolling-mean PROXY, not the real central rate.
"""
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_prices, load_vn
from common.quant import cagr, drawdown_series, max_drawdown

# Daily limits and tick by exchange (rules as of 2026-10; see content/day16.md).
LIMITS = {"HOSE": 0.07, "HNX": 0.10, "UPCOM": 0.15}


def sbv_band(central_rate: float, band: float = 0.05) -> tuple[float, float]:
    """Trading band around the SBV central rate: (central*(1-band), central*(1+band))."""
    # Symmetric band around the daily central rate.
    return (central_rate * (1 - band), central_rate * (1 + band))


def within_band(market: pd.Series, central: pd.Series, band: float = 0.05) -> pd.Series:
    """Boolean Series: True where abs(market/central - 1) <= band (aligned on the index)."""
    # Inclusive edges: a rate exactly on the band edge is still allowed.
    return (market / central - 1).abs() <= band


def hose_tick(price: float) -> int:
    """HOSE tick size in VND: 10 below 10,000; 50 from 10,000 to 49,950; 100 at 50,000 and above."""
    if price < 10_000:
        return 10
    if price < 50_000:
        return 50
    return 100


def price_limits(ref_price: float, exchange: str) -> tuple[int, int]:
    """(floor, ceiling) in VND for a reference price. HOSE 7% (HOSE ticks), HNX 10% and UPCOM 15%
    (both tick 100). Exchange is case-insensitive; anything else raises ValueError.

    raw = round(ref*(1 +/- limit), 6); ceiling rounds DOWN and floor rounds UP to the tick that
    applies at the raw price. Return ints.
    """
    key = exchange.upper()
    if key not in LIMITS:
        raise ValueError(f"unknown exchange {exchange!r}; expected HOSE, HNX or UPCOM")
    limit = LIMITS[key]
    tick_of = hose_tick if key == "HOSE" else (lambda _p: 100)
    # round(..., 6) removes float noise: 12000*1.15 is 13799.999999999998, which would floor to 13,700 instead of 13,800.
    raw_up = round(ref_price * (1 + limit), 6)
    raw_dn = round(ref_price * (1 - limit), 6)
    tu, td = tick_of(raw_up), tick_of(raw_dn)
    ceiling = math.floor(raw_up / tu) * tu   # round inward: never above the true 7/10/15%
    floor = math.ceil(raw_dn / td) * td
    return int(floor), int(ceiling)


def flag_limit_moves(close: pd.Series, exchange: str) -> pd.Series:
    """Boolean Series: element 0 False; for t >= 1, True if close[t] equals the floor or ceiling
    price_limits(close[t-1], exchange) would give."""
    vals = close.tolist()
    flags = [False]
    for prev, cur in zip(vals[:-1], vals[1:]):
        lo, hi = price_limits(prev, exchange)
        flags.append(cur == lo or cur == hi)
    return pd.Series(flags, index=close.index)


def foreign_room(cap_pct: float, foreign_shares: float, total_shares: float) -> float:
    """Shares a foreign investor can still buy: max(0, cap_pct*total_shares - foreign_shares)."""
    # Never negative: above the cap there is simply no room.
    return max(0.0, cap_pct * total_shares - foreign_shares)


def main() -> None:
    vni = load_vn("VNINDEX").dropna()
    print(f"VN-Index {vni.index[0].date()} -> {vni.index[-1].date()}: {vni.iloc[0]:,.0f} -> {vni.iloc[-1]:,.0f} points")
    trough = drawdown_series(vni).idxmin()
    peak = vni[:trough].idxmax()  # same peak-to-trough episode as the percentage
    print(f"  CAGR {cagr(vni):.2%}; max drawdown {max_drawdown(vni):.1%}: {vni[peak]:,.0f} on {peak.date()} -> "
          f"{vni[trough]:,.0f} on {trough.date()} ({vni[peak] - vni[trough]:,.0f} points)")

    print("Limit-hit days on HOSE (closes are dividend/split-adjusted, so the count is approximate):")
    for sym in ["FPT", "HPG", "VCB"]:
        px = load_vn(sym).dropna()
        flags = flag_limit_moves(px, "HOSE")
        near = px.pct_change().abs() >= 0.065  # adjusted closes rarely land exactly on a tick: use a tolerance too
        print(f"  {sym}: exact-limit {int(flags.sum())}, |move| >= 6.5% {int(near.sum())} of {len(px)} days ({near.mean():.2%})")

    fx = load_prices(["VND=X"]).iloc[:, 0].dropna()
    fx = fx[fx.index >= "2015-01-01"]
    proxy = fx.rolling(60).mean()  # PROXY: SBV central-rate history is not in the snapshot
    ok = within_band(fx, proxy).where(proxy.notna())
    print(f"USD/VND vs a +/-5% band around a 60-day rolling-mean PROXY (not the SBV central rate): "
          f"{ok.dropna().astype(bool).mean():.1%} of days inside since 2015")
    lo, hi = sbv_band(float(proxy.iloc[-1]))
    print(f"  latest proxy {proxy.iloc[-1]:,.0f} -> band {lo:,.0f} to {hi:,.0f}; market {fx.iloc[-1]:,.0f}")
    print(f"foreign_room(49%, 400m of 1,000m shares) = {foreign_room(0.49, 400, 1000):.0f}m shares")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day16.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    both = pd.concat([vni.rename("vni"), fx.rename("fx")], axis=1, sort=True).dropna()
    fig, ax1 = plt.subplots(figsize=(9, 4))
    ax1.plot(both.index, both["vni"], color="tab:blue")
    ax1.set_ylabel("VN-Index (points)")
    ax2 = ax1.twinx()
    ax2.plot(both.index, both["fx"], color="tab:red", alpha=0.7)
    ax2.set_ylabel("USD/VND")
    ax1.set_title("VN-Index vs USD/VND")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
