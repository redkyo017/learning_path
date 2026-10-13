"""Reference PSR / DSR (Bailey and Lopez de Prado, 2014). Days 26 and 30 import these.

All Sharpe ratios are per-period (not annualized). Uses statistics.NormalDist, no scipy.
"""
import math
from statistics import NormalDist

EULER_GAMMA = 0.5772156649
_N = NormalDist()


def probabilistic_sharpe_ratio(sr: float, sr_benchmark: float, n_obs: int,
                               skew: float = 0.0, kurtosis: float = 3.0) -> float:
    """Probability that the true Sharpe exceeds `sr_benchmark`, given an observed per-period `sr`.

    PSR = Phi((sr - sr_b) * sqrt(n_obs - 1) / sqrt(1 - skew*sr + (kurtosis - 1)/4 * sr**2)).
    `kurtosis` is the raw (non-excess) kurtosis, 3.0 for a normal. Sharpe inputs are per-period.
    """
    if n_obs < 2:
        raise ValueError(f"n_obs must be at least 2, got {n_obs}")
    radicand = 1 - skew * sr + (kurtosis - 1) / 4 * sr ** 2
    if radicand <= 0:
        raise ValueError(f"PSR variance term is {radicand:.4g} <= 0 for sr={sr}, skew={skew}, "
                         f"kurtosis={kurtosis}; the skew/kurtosis inputs are not jointly feasible")
    denom = math.sqrt(radicand)
    return _N.cdf((sr - sr_benchmark) * math.sqrt(n_obs - 1) / denom)


def expected_max_sharpe(n_trials: int, sr_variance: float) -> float:
    """Expected maximum Sharpe among `n_trials` independent skill-less trials (per-period units).

    E[max] = sqrt(sr_variance) * ((1 - g) * Phi^-1(1 - 1/N) + g * Phi^-1(1 - 1/(N*e))), g = 0.5772156649.
    Returns 0.0 when n_trials == 1.
    """
    if sr_variance < 0:
        raise ValueError(f"sr_variance must be non-negative, got {sr_variance}")
    if n_trials <= 1:
        return 0.0
    g = EULER_GAMMA
    return math.sqrt(sr_variance) * ((1 - g) * _N.inv_cdf(1 - 1 / n_trials)
                                     + g * _N.inv_cdf(1 - 1 / (n_trials * math.e)))


def deflated_sharpe_ratio(sr: float, n_trials: int, sr_variance: float, n_obs: int,
                          skew: float = 0.0, kurtosis: float = 3.0) -> float:
    """PSR of `sr` against the benchmark `expected_max_sharpe(n_trials, sr_variance)`.

    With n_trials == 1 the benchmark is 0 and DSR equals PSR against zero. Per-period units.
    """
    benchmark = expected_max_sharpe(n_trials, sr_variance)
    return probabilistic_sharpe_ratio(sr, benchmark, n_obs, skew, kurtosis)
