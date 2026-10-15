# Lab 11 — Solution notes

## classify_regime
Take `diff(lag)` of each series, call a series "up" when its diff is strictly greater than 0, and map (growth_up, inflation_up) to reflation (T,T), goldilocks (T,F), stagflation (F,T) or deflation (F,F). Drop rows where either diff is NaN, which removes the first `lag` rows and any gaps. Common mistake: using `>= 0` (flat becomes rising) or building the boolean masks before dropping NaN, because `NaN > 0` is False and would silently label missing months "deflation". The tests check the exact five labels, the start date (`IDX[3]`) and that flat inflation in the first row gives goldilocks.

## rolling_zscore
Formula: `(s - s.rolling(w).mean()) / s.rolling(w).std(ddof=1)`. The first `w - 1` values are NaN. Common mistake: `ddof=0` or a centred window. For `[1,2,3]` the std is 1, so the third z-score is exactly 1; the test also counts two NaNs.

## surprise_z
Formula: `(actual - expected) / std`. Raise `ValueError` for `std <= 0` before dividing, otherwise zero returns inf and a negative std flips the sign. The test checks 1.0 for (0.3, 0.2, 0.1) and the exception for 0.

## regime_mean_returns
Join the returns frame with the regime labels on their shared dates (inner join), `groupby` the regime column and take the mean. Common mistake: a left join that leaves NaN regimes, or a groupby on an unaligned array. The test uses five dates, so the means are 0.01, 0.02 and the average of the three stagflation months, -0.02.

## What the output means
On the snapshot, the 1990-2026 months split almost evenly between the four regimes (roughly a quarter each). From 2005 the same-month table shows SPY averaging about 2.0% in goldilocks months against 0.4% in stagflation, TLT slightly negative in stagflation, and gold's best average in the "deflation" box, a reminder that the labels describe direction, not level. The table is contemporaneous, so it contains look-ahead: shifting regimes forward one month cuts the goldilocks SPY average to about 1.1% a month and makes stagflation negative for stocks. The 2025-10 CPI gap is reindexed to NaN in `main()`, so two months drop out instead of being mislabelled. The latest labelled month is August 2026; the table has only a few dozen months per regime and is a description of the past, not a forecast.
