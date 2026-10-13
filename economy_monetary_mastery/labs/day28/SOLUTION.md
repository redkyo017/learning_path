# Solution notes — Lab 28

## trend_signal
Sign of `p / p.shift(lookback) - 1`; `np.sign` of NaN is NaN, so `fillna(0)` makes warm-up rows flat. Formula: sign(P_t / P_{t-L} - 1). Common mistake: `.diff(lookback)` without the sign, or leaving NaN; `test_trend_signal` catches it with `assert s.iloc[:10].eq(0).all().all()` (NaN warm-up) and `assert s.iloc[20].tolist() == [1, 0, -1]` (the flat asset must give exactly 0).

## mean_reversion_signal
Rolling mean and std (ddof=1, the pandas default); z = (p - mean) / std; short above `z_entry`, long below `-z_entry`. A zero std must give NaN, not infinity. Formula: z_t = (P_t - mean_W) / std_W. Common mistake: using `ddof=0` or forgetting the full-window requirement; the test's last bar has z of about 4.2, and the first 19 bars must be 0.

## inverse_vol_weights
`inv = 1 / returns.rolling(w).std()`, then divide each row by its sum and `dropna()`. Weights w_i = (1/s_i) / sum_j (1/s_j). Common mistake: normalising before dropping, or weighting by variance instead of volatility. `test_inverse_vol_weights` catches it with `assert w.index[0] == IDX[9]` (first kept row), the `pytest.approx([1 / 3, 2 / 3])` check on the last row (vols of 2:1), and the row-sum check.

## cross_sectional_momentum
Trailing return per column, then rank each row descending with `method="first"` (ties go to the earlier column), weight 1/top_n where rank <= top_n, and force rows with any NaN to 0. Common mistake: ranking NaN rows (NaN ranks as NaN, which compares False, but a partially filled row would still pick winners); the test checks the first 5 rows are all 0 and that top 2 gives `[0.5, 0.5, 0.0]`.

## combine_strategies
Raise `ValueError` for any weight key that is not a column, then `sum(returns[k] * v)`. Common mistake: silently ignoring a misspelt key, which makes a blend look diversified when it is not; `test_combine_strategies` checks the error.

## What the output means
On the 2014-12 to 2026-09 common weekday calendar (trend 120-day sign x 1/vol, 5 bps cost), the trend sleeve is a low-risk, low-return stream (CAGR 4.49%, Sharpe 0.61, max drawdown -13.98%) because its weights sum to at most 1 and it can be short. Cross-sectional momentum is far more aggressive (CAGR 24.27%, max drawdown -40.51%); the universe is seven hand-picked survivors including BTC, so its edge is flattered by survivorship and a single asset's run, not evidence of a free lunch. The 50/50 blend roughly matches buy-and-hold's Sharpe (1.15 vs 1.15) with a smaller drawdown (-21.60% vs -32.43%), and the trend/momentum correlation of 0.36 shows the two sleeves are related but not duplicates. Numbers are in-sample on one history and should be read with Day 26 in mind.
