# Solution notes — Lab 26

## probabilistic_sharpe_ratio
**Idea:** the observed Sharpe is an estimate with sampling error; PSR is the probability that the true Sharpe exceeds a benchmark, accounting for sample length and fat or skewed tails. **Formula:** `Phi((sr - sr_b) * sqrt(n - 1) / sqrt(1 - skew*sr + (kurtosis - 1)/4 * sr**2))` with `Phi = NormalDist().cdf`; kurtosis is raw (3 for a normal). **Common mistake:** passing an annualized Sharpe (the formula is per-period) or excess kurtosis; `test_psr_basics` checks the 0.5 anchor and that more observations raise PSR.

## expected_max_sharpe
**Idea:** among N trials with no skill, the best Sharpe is not zero; it grows slowly with N. **Formula:** `sqrt(var) * ((1-g)*inv_cdf(1-1/N) + g*inv_cdf(1-1/(N*e)))`, g = 0.5772156649, and 0.0 for N = 1 (inv_cdf(0) would raise). **Common mistake:** forgetting the N = 1 branch or using `1/N` in place of `1/(N*e)` in the second term; `test_expected_max_sharpe` pins 2.53 for N = 100, variance 1.

## deflated_sharpe_ratio
**Idea:** the same PSR, but the bar to beat is the luck benchmark instead of zero. **Formula:** `PSR(sr, expected_max_sharpe(n_trials, sr_variance), n_obs, skew, kurtosis)`. **Common mistake:** mixing units (annualized sr with a per-period variance); `test_dsr_penalizes_more_trials` requires DSR to fall as trials rise and stay in [0, 1], and `common/tests/test_stats.py` requires DSR with one trial to equal PSR against zero.

## p_hacking_demo
**Idea:** with enough pure-noise strategies, one looks great in the first half and is ordinary in the second. **Steps:** `rng.normal(0, 0.01, (n_days, n_strategies))`, first-half annualized `sharpe` per column, `argmax`, then that column's Sharpe on the second half. **Common mistake:** ranking on the whole sample, or reporting the best out-of-sample column; the test needs in-sample above 1.0 and out-of-sample below it.

## walk_forward
**Idea:** at each window the lookback is chosen from the training slice only, then traded on the next `test` bars. **Details:** windows start at `i = train` and step by `test` while `i + test <= len(p)`; the OOS block comes from a backtest on `p.iloc[:i+test]` so the 200-day signal has history, sliced to `[i, i+test)`. NaN Sharpe maps to -inf and strict `>` keeps the first lookback on ties. **Common mistake:** selecting on the test block, or on data past `i`; `test_walk_forward_has_no_leakage` multiplies the last 50 prices by 1.5 and requires every earlier choice to stay identical. `test_walk_forward_shape` pins 7 windows and 350 OOS bars.

## What the output means
On pure noise, the best of 10, 100 and 1000 strategies shows an annualized in-sample Sharpe of 1.24, 1.84 and 2.11, and the same strategies score -0.43, 0.81 and -0.82 on the unseen half: the in-sample number is the maximum of noise, and the out-of-sample number is what is left. On SPY (2005 to 2026) the five lookbacks have full-sample Sharpe between 0.64 and 0.82, best at 60 days; walk-forward, which re-picks every 126 days from the previous 756, earns an out-of-sample Sharpe of 0.76 over 4,662 days, slightly below the hindsight pick but well within the spread, and it switches lookback often (the chosen value hops between 20 and 250). The DSR of the best lookback rounds to 1.000 because the five lookbacks are highly correlated, so the Sharpe variance across them is tiny and the luck benchmark is near zero, and because the full-sample t-statistic of a 0.82 Sharpe over 21 years is large. That does not prove SPY momentum is an edge worth trading (Day 25 showed it mainly cuts drawdown); it says that five variants of one idea on 21 years of a rising asset is not a multiple-testing problem. Counting every variant ever tried, across signals and assets, is.
