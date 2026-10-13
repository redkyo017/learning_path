"""Day 25 lab: a vectorized backtester from scratch.

Goal: turn a price series and a signal into an equity curve without look-ahead. A signal observed
at the close of bar t can only be traded from bar t+1, so position = signal lagged one bar; P&L is
position * asset return minus a cost charged on turnover (change in position) in basis points.
main() runs 200-day momentum on SPY and BTC-USD (frozen snapshots) at 0 and 10 bps, prints
common.quant metrics against buy-and-hold, and cross-checks with vectorbt if it is installed.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_prices
from common.quant import annualize_vol, cagr, max_drawdown, sharpe


def momentum_signal(prices: pd.Series, lookback: int) -> pd.Series:
    """Time-series momentum signal: 1.0 if the trailing `lookback`-bar return is > 0, else 0.0.

    Bars without a full lookback window (NaN return) get 0.0. The signal at bar t uses prices up
    to and including bar t only; it is NOT yet lagged (backtest does that).
    """
    raise NotImplementedError("TODO: (prices / prices.shift(lookback) - 1 > 0).astype(float), NaN -> 0")

def backtest(prices: pd.Series, signal: pd.Series, cost_bps: float = 0.0) -> pd.DataFrame:
    """Vectorized long/flat backtest with a one-bar execution lag and proportional costs.

    Returns a DataFrame indexed like `prices` with columns
    ["asset_ret", "position", "turnover", "cost", "strat_ret", "equity"]:
    position = signal.reindex(prices.index).shift(1).fillna(0); asset_ret = prices.pct_change().fillna(0);
    turnover = |position.diff()| with the first row = |position[0]|; cost = turnover*cost_bps/1e4;
    strat_ret = position*asset_ret - cost; equity = (1 + strat_ret).cumprod().
    """
    raise NotImplementedError("TODO: lag signal one bar, charge cost on turnover, compound strat_ret")

def _metrics(name: str, equity: pd.Series, ret: pd.Series, ppy: int = 252) -> str:
    return (f"{name:<22} CAGR {cagr(equity):7.2%}  vol {annualize_vol(ret, ppy):6.2%}  "
            f"Sharpe {sharpe(ret, periods_per_year=ppy):5.2f}  maxDD {max_drawdown(equity):7.2%}")


def _vectorbt_check(prices: pd.Series, bt: pd.DataFrame, cost_bps: float) -> None:
    """Cross-check final equity against vbt.Portfolio.from_signals (skips if vectorbt is missing)."""
    try:
        import vectorbt as vbt
    except Exception as exc:  # not installed or incompatible
        print(f"  vectorbt cross-check skipped ({type(exc).__name__}: {exc})")
        return
    pos = bt["position"] > 0
    # position[t] = 1 means "hold through bar t's return", i.e. buy at the close of bar t-1.
    # vectorbt fills at the close of the bar where the signal sits, so move each event back one bar.
    entries = (pos & ~pos.shift(1, fill_value=False)).shift(-1, fill_value=False)
    exits = (~pos & pos.shift(1, fill_value=False)).shift(-1, fill_value=False)
    pf = vbt.Portfolio.from_signals(prices, entries, exits, fees=cost_bps / 1e4, init_cash=1.0,
                                    size=float("inf"), freq="1D")
    vbt_final = float(pf.value().iloc[-1])
    ours = float(bt["equity"].iloc[-1])
    print(f"  vectorbt final {vbt_final:.4f} vs ours {ours:.4f} (diff {vbt_final - ours:+.4f})")


def main() -> None:
    px = load_prices(["SPY", "BTC-USD"])
    fig, axes = plt.subplots(2, 1, figsize=(9, 7))
    for ax, name in zip(axes, px.columns):
        p = px[name].dropna()
        sig = momentum_signal(p, 200)
        ppy = 365 if name.endswith("-USD") else 252  # crypto trades every day
        print(f"\n{name}: {p.index[0].date()} -> {p.index[-1].date()}, {len(p)} bars")
        # Buy-and-hold benchmark is invested from day 1 (no lag), so use raw returns.
        bh_ret = p.pct_change().fillna(0)
        bh_eq = (1 + bh_ret).cumprod()
        print(" ", _metrics("buy & hold", bh_eq, bh_ret, ppy))
        for bps in (0, 10):
            bt = backtest(p, sig, cost_bps=bps)
            print(" ", _metrics(f"200d momentum {bps}bps", bt["equity"], bt["strat_ret"], ppy),
                  f" in-out switches {bt['turnover'].sum():.0f}")
            _vectorbt_check(p, bt, bps)
            if bps == 10:
                bt["equity"].plot(ax=ax, label="momentum 10bps")
        bh_eq.plot(ax=ax, label="buy & hold", alpha=0.7)
        ax.set_yscale("log")
        ax.set_title(f"{name}: 200-day momentum vs buy-and-hold")
        ax.legend()
    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out / "day25.png", dpi=110)
    print(f"\nsaved {out / 'day25.png'}")


if __name__ == "__main__":
    main()
