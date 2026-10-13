"""Day 26 lab: how backtests lie.

Goal: measure the damage done by trying many things. Implement the Probabilistic Sharpe Ratio (PSR),
the expected best Sharpe among N skill-less trials, and the Deflated Sharpe Ratio (DSR) of Bailey and
Lopez de Prado (2014); then reproduce the p-hacking effect on pure noise, and build a leak-free
walk-forward test of momentum lookbacks. All PSR/DSR Sharpe inputs are per-period (not annualized).
main() runs the p-hacking demo, walk-forward momentum on SPY, and the DSR of the best lookback.
"""
import math
from pathlib import Path
from statistics import NormalDist

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from common.backtest import backtest, momentum_signal
from common.data import load_prices
from common.quant import sharpe

EULER_GAMMA = 0.5772156649
_N = NormalDist()


def probabilistic_sharpe_ratio(sr: float, sr_benchmark: float, n_obs: int,
                               skew: float = 0.0, kurtosis: float = 3.0) -> float:
    """Probability that the true Sharpe exceeds `sr_benchmark`, given an observed per-period `sr`.

    PSR = Phi((sr - sr_b) * sqrt(n_obs - 1) / sqrt(1 - skew*sr + (kurtosis - 1)/4 * sr**2)).
    `kurtosis` is the raw (non-excess) kurtosis, 3.0 for a normal. Sharpe inputs are per-period.
    """
    raise NotImplementedError("TODO: Phi((sr - sr_b)*sqrt(n-1)/sqrt(1 - skew*sr + (kurt-1)/4*sr**2)) via NormalDist().cdf")


def expected_max_sharpe(n_trials: int, sr_variance: float) -> float:
    """Expected maximum Sharpe among `n_trials` independent skill-less trials (per-period units).

    E[max] = sqrt(sr_variance) * ((1 - g) * Phi^-1(1 - 1/N) + g * Phi^-1(1 - 1/(N*e))), g = 0.5772156649.
    Returns 0.0 when n_trials == 1.
    """
    raise NotImplementedError("TODO: sqrt(var)*((1-g)*inv_cdf(1-1/N) + g*inv_cdf(1-1/(N*e))); 0.0 if N == 1")


def deflated_sharpe_ratio(sr: float, n_trials: int, sr_variance: float, n_obs: int,
                          skew: float = 0.0, kurtosis: float = 3.0) -> float:
    """PSR of `sr` against the benchmark `expected_max_sharpe(n_trials, sr_variance)`.

    With n_trials == 1 the benchmark is 0 and DSR equals PSR against zero. Per-period units.
    """
    raise NotImplementedError("TODO: PSR with sr_benchmark = expected_max_sharpe(n_trials, sr_variance)")


def p_hacking_demo(n_strategies: int, n_days: int, seed: int) -> dict:
    """Search pure noise for the best strategy and show it does not survive out of sample.

    Draw returns rng.normal(0, 0.01, (n_days, n_strategies)) with np.random.default_rng(seed); split the
    rows in half; compute the annualized common.quant.sharpe of each column on the first half; pick the
    argmax. Return {"best_in_sample_sharpe": ..., "its_out_of_sample_sharpe": ...} where the second value
    is that same column's Sharpe on the second half (both annualized, as floats).
    """
    raise NotImplementedError("TODO: simulate noise, rank columns on first half, report the winner on both halves")


def walk_forward(prices: pd.Series, lookbacks: list[int], train: int, test: int) -> tuple[pd.Series, list[int]]:
    """Walk-forward momentum: re-pick the lookback on each training window, trade it on the next block.

    For i = train, train+test, ... while i + test <= len(prices): choose the lookback maximizing
    sharpe(backtest(p.iloc[i-train:i], momentum_signal(p.iloc[i-train:i], lb))["strat_ret"]) (NaN -> -inf,
    ties -> first). The out-of-sample block is
    backtest(p.iloc[:i+test], momentum_signal(p.iloc[:i+test], lb))["strat_ret"].iloc[i:i+test]
    (signals may use history before i; only the choice must not see data from i on).
    Returns (concatenated OOS strat_ret, list of chosen lookbacks, one per window).
    """
    raise NotImplementedError("TODO: loop windows; pick best lookback on train slice; stitch OOS blocks")


def main() -> None:
    print("p-hacking on pure noise (annualized Sharpe, 1000 days, seed 0):")
    for n in (10, 100, 1000):
        r = p_hacking_demo(n, 1000, seed=0)
        print(f"  {n:>5} strategies: best in-sample {r['best_in_sample_sharpe']:5.2f} -> "
              f"same strategy out-of-sample {r['its_out_of_sample_sharpe']:5.2f}")

    p = load_prices(["SPY"])["SPY"].dropna()
    lookbacks = [20, 60, 120, 200, 250]
    oos, choices = walk_forward(p, lookbacks, train=756, test=126)
    full = {lb: backtest(p, momentum_signal(p, lb))["strat_ret"] for lb in lookbacks}
    full_sr = {lb: sharpe(r) for lb, r in full.items()}
    best_lb = max(full_sr, key=full_sr.get)
    print(f"\nSPY {p.index[0].date()} -> {p.index[-1].date()}, lookbacks {lookbacks}")
    print("  full-sample Sharpe: " + "  ".join(f"{lb}d {s:.2f}" for lb, s in full_sr.items()))
    print(f"  best full-sample: {best_lb}d at {full_sr[best_lb]:.2f}; walk-forward OOS Sharpe "
          f"{sharpe(oos):.2f} over {len(oos)} days; chosen lookbacks {choices}")

    # DSR of the best full-sample lookback, treating the 5 lookbacks as the 5 trials (per-period units).
    per = pd.Series({lb: r.mean() / r.std(ddof=1) for lb, r in full.items()})
    r = full[best_lb]
    dsr = deflated_sharpe_ratio(per[best_lb], 5, float(per.var(ddof=1)), len(r),
                                float(r.skew()), float(r.kurt()) + 3.0)
    psr = probabilistic_sharpe_ratio(per[best_lb], 0.0, len(r), float(r.skew()), float(r.kurt()) + 3.0)
    print(f"  PSR vs 0: {psr:.3f}; DSR with 5 trials: {dsr:.3f}")

    fig, ax = plt.subplots(figsize=(8, 4))
    ((1 + oos).cumprod()).plot(ax=ax, label="walk-forward OOS")
    full[best_lb].loc[oos.index].add(1).cumprod().plot(ax=ax, label=f"{best_lb}d (best in hindsight)")
    p.loc[oos.index].pct_change().fillna(0).add(1).cumprod().plot(ax=ax, label="buy & hold", alpha=0.6)
    ax.set_yscale("log")
    ax.set_title("SPY momentum: walk-forward vs hindsight pick")
    ax.legend()
    out = Path(__file__).resolve().parents[1] / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out / "day26.png", dpi=110)
    print(f"\nsaved {out / 'day26.png'}")


if __name__ == "__main__":
    main()
