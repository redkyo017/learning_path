"""Day 30 lab: the capstone kill checklist.

Goal: turn one trading idea into a decision. Implement the six-rule kill checklist, the
paper-trade/kill verdict, and run_capstone, which picks a momentum lookback in-sample, tests it
out-of-sample with costs, and deflates the in-sample Sharpe for the number of lookbacks tried.
main() runs the pipeline on the SPY and BTC-USD snapshots and prints each report. Educational
code, not financial advice; nothing here touches a broker.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.backtest import backtest, momentum_signal  # noqa: F401  (used by run_capstone)
from common.data import load_prices
from common.quant import max_drawdown, sharpe  # noqa: F401
from common.risk import breakeven_cost_bps  # noqa: F401
from common.stats import deflated_sharpe_ratio  # noqa: F401

REQUIRED_KEYS = ("dsr", "is_sharpe", "oos_sharpe", "net_sharpe", "benchmark_sharpe", "n_trades",
                 "max_drawdown", "breakeven_cost_bps", "assumed_cost_bps")


def kill_checklist(r: dict) -> list[str]:
    """Return the names of the kill rules that `r` fails, in this order (empty list = all pass).

    - "deflated_sharpe":  dsr < 0.95
    - "oos_decay":        oos_sharpe < 0.5 * is_sharpe
    - "beats_benchmark":  net_sharpe <= benchmark_sharpe
    - "sample_size":      n_trades < 30
    - "drawdown":         max_drawdown < -0.35
    - "cost_survival":    breakeven_cost_bps < 2 * assumed_cost_bps

    Raises ValueError naming every key of REQUIRED_KEYS that is missing from `r`.
    """
    raise NotImplementedError("TODO: check missing keys, then apply the six rules in order")


def verdict(r: dict) -> str:
    """Return "paper-trade" if kill_checklist(r) is empty, otherwise "kill"."""
    raise NotImplementedError("TODO: empty checklist -> 'paper-trade', else 'kill'")


def run_capstone(prices: pd.Series, lookbacks: list[int], cost_bps: float, split: float = 0.6,
                 periods_per_year: int = 252) -> dict:
    """Run the research pipeline on one price series and return a report dict.

    cut = int(len(prices) * split). In-sample (IS) = rows before cut; out-of-sample (OOS) = rows
    from cut on. For each lookback, backtest the momentum signal with no costs and take the
    annualized Sharpe of strat_ret on the IS slice; choose the best (`chosen_lookback`). Rerun the
    chosen lookback on the full series with `cost_bps`; OOS slices of that run give `oos_sharpe`
    and `net_sharpe` (both net of costs). `is_sharpe` is the gross IS Sharpe of the chosen
    lookback; `benchmark_sharpe` is buy-and-hold on the OOS asset returns.
    `dsr` = deflated_sharpe_ratio(per-period IS Sharpe of the chosen lookback,
    n_trials=len(lookbacks), sr_variance=variance (ddof=1) of the per-period IS Sharpes across
    lookbacks, or 1e-6 if that is NaN, n_obs=len(IS)).
    `n_trades` = count of rows with non-zero turnover in the full run; `max_drawdown` of the
    full-run equity; `breakeven_cost_bps` from the full-run gross returns and turnover;
    `assumed_cost_bps` = cost_bps. Sharpe annualization uses `periods_per_year` (365 for native
    daily crypto, 252 for equities). The dict holds every key in REQUIRED_KEYS plus
    "chosen_lookback".
    """
    raise NotImplementedError("TODO: IS lookback search, full run with costs, OOS slices, DSR")


def main() -> None:
    prices = load_prices(["SPY", "BTC-USD"]).dropna(how="all")
    cases = [("SPY", 5.0, 252), ("BTC-USD", 10.0, 365)]
    lookbacks = [20, 60, 120, 200, 250]
    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    for ax, (name, cost, ppy) in zip(axes, cases):
        p = prices[name].dropna()
        r = run_capstone(p, lookbacks, cost_bps=cost, periods_per_year=ppy)
        failed = kill_checklist(r)
        print(f"\n== {name}  ({p.index[0].date()} to {p.index[-1].date()}, {cost:g} bps, "
              f"{ppy} periods/yr) ==")
        for k in REQUIRED_KEYS + ("chosen_lookback",):
            v = r[k]
            print(f"  {k:20s} {v:.3f}" if isinstance(v, float) else f"  {k:20s} {v}")
        print(f"  failed checks: {failed or 'none'}")
        print(f"  verdict: {verdict(r)}")
        cut = int(len(p) * 0.6)
        bt = backtest(p, momentum_signal(p, r["chosen_lookback"]), cost_bps=cost)
        oos = slice(cut, None)
        ax.plot((1 + bt["strat_ret"].iloc[oos]).cumprod(), label="strategy (net, OOS)")
        ax.plot((1 + bt["asset_ret"].iloc[oos]).cumprod(), label="buy and hold (OOS)")
        ax.set_title(f"{name}: {verdict(r)}")
        ax.legend()
    fig.tight_layout()
    fig.savefig(out / "day30.png", dpi=120)
    print("\nCopy each report into CAPSTONE.md (section 'Report'). Figure: .cache/plots/day30.png")


if __name__ == "__main__":
    main()
