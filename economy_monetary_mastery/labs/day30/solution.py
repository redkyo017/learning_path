"""Day 30 solution: the capstone kill checklist.

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
import numpy as np
import pandas as pd

from common.backtest import backtest, momentum_signal
from common.data import load_prices
from common.quant import max_drawdown
from common.risk import breakeven_cost_bps
from common.stats import deflated_sharpe_ratio

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
    missing = [k for k in REQUIRED_KEYS if k not in r]
    if missing:
        raise ValueError(f"report is missing keys: {', '.join(missing)}")
    # Order matters: the test (and your CAPSTONE.md table) lists failures in this order.
    rules = [
        ("deflated_sharpe", r["dsr"] < 0.95),
        ("oos_decay", r["oos_sharpe"] < 0.5 * r["is_sharpe"]),
        ("beats_benchmark", r["net_sharpe"] <= r["benchmark_sharpe"]),
        ("sample_size", r["n_trades"] < 30),
        ("drawdown", r["max_drawdown"] < -0.35),
        ("cost_survival", r["breakeven_cost_bps"] < 2 * r["assumed_cost_bps"]),
    ]
    return [name for name, failed in rules if failed]


def verdict(r: dict) -> str:
    """Return "paper-trade" if kill_checklist(r) is empty, otherwise "kill"."""
    return "kill" if kill_checklist(r) else "paper-trade"


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
    cut = int(len(prices) * split)
    is_idx = prices.index[:cut]
    oos_idx = prices.index[cut:]
    root = np.sqrt(periods_per_year)

    def per_period_sharpe(ret: pd.Series) -> float:
        sd = ret.std(ddof=1)
        return float(ret.mean() / sd) if sd > 0 else 0.0

    # 1. Search lookbacks on the in-sample slice only, gross of costs. The signal at t uses prices
    #    up to t, so slicing the full-series backtest to IS rows leaks nothing from the future.
    is_sr = {}
    for lb in lookbacks:
        gross = backtest(prices, momentum_signal(prices, lb), cost_bps=0.0)["strat_ret"]
        is_sr[lb] = per_period_sharpe(gross.loc[is_idx])
    best = max(is_sr, key=is_sr.get)

    # 2. Deflate the winner's IS Sharpe for the number of lookbacks tried.
    variance = float(pd.Series(list(is_sr.values())).var(ddof=1))
    if np.isnan(variance):  # a single lookback has no cross-trial variance
        variance = 1e-6
    dsr = deflated_sharpe_ratio(is_sr[best], len(lookbacks), variance, len(is_idx))

    # 3. Full run with costs; OOS slices give the honest numbers.
    bt = backtest(prices, momentum_signal(prices, best), cost_bps=cost_bps)
    gross_full = bt["strat_ret"] + bt["cost"]
    return {
        "chosen_lookback": best,
        "dsr": float(dsr),
        "is_sharpe": is_sr[best] * root,
        "oos_sharpe": per_period_sharpe(bt["strat_ret"].loc[oos_idx]) * root,
        "net_sharpe": per_period_sharpe(bt["strat_ret"].loc[oos_idx]) * root,
        "benchmark_sharpe": per_period_sharpe(bt["asset_ret"].loc[oos_idx]) * root,
        "n_trades": int((bt["turnover"] > 0).sum()),
        "max_drawdown": float(max_drawdown(bt["equity"])),
        "breakeven_cost_bps": float(breakeven_cost_bps(gross_full, bt["turnover"])),
        "assumed_cost_bps": float(cost_bps),
    }


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
