# Solution notes — Day 07

## `bond_price`
Key idea: a bond is a list of dated cash flows, and its price is their present value at the yield to maturity. With semiannual pay there are `n = round(years * freq)` periods, a coupon `c = face * coupon_rate / freq` in each, and the face value on top of the last one. Each period is discounted at `ytm / freq`.
Formula: `sum(c / (1 + y/f) ** k for k in 1..n) + face / (1 + y/f) ** n`.
Common mistake: discounting by the annual yield instead of the per-period yield, or using `years` rather than `n` as the exponent. `test_known_price` expects 95.7349 for the 5% bond at 6%; `test_par_and_zero` expects par when coupon equals yield and `100 / 1.02**20` for the zero.

## `macaulay_duration`
Key idea: weight each payment's time `t_k = k / freq` by its share of the price. The result is the "centre of mass" of the cash flows, in years, so a zero-coupon bond's duration equals its maturity.
Formula: `sum(t_k * PV_k) / price`, where `PV_k` includes the face value in period `n`.
Common mistake: measuring `k` in periods rather than years (a factor of 2 off for semiannual bonds), or forgetting the face value in the last cash flow. `test_zero_coupon_durations_and_convexity` expects exactly 10 for the zero; `test_coupon_bond_duration_below_maturity` catches a bond whose duration is not less than its maturity.

## `modified_duration`
Key idea: differentiate price with respect to yield and divide by price: the result is the Macaulay duration divided by one period's growth factor. It reads as "percent price change per 1.00 (100 percentage points) of yield".
Formula: `macaulay / (1 + ytm/freq)`.
Common mistake: dividing by `1 + ytm` instead of `1 + ytm/freq`. The zero-coupon test expects `10 / 1.02`, and `test_duration_predicts_small_moves` compares a one-basis-point repricing with `-D * P * 0.0001`.

## `convexity`
Key idea: the second derivative of price with respect to yield, scaled by price. It is positive for plain bonds: price is a convex function of yield, so the duration straight line understates the price at any large yield move.
Formula: `sum(CF_k * t_k * (t_k + 1/freq) / (1 + y/f) ** (k + 2)) / price`.
Common mistake: using exponent `k + 1` (that is the first-derivative form) or omitting the `+ 1/freq` term. The zero-coupon test expects `10 * 10.5 / 1.02**2`.

## `curve_slope`
Key idea: slope is long minus short, row by row. pandas aligns on the index, and a day where either yield is missing (a holiday in one series) yields NaN, which is dropped.
Formula: `(long - short).dropna()`.
Common mistake: subtracting in the wrong order (the sign of every inversion flips) or leaving NaNs, which silently break a run. `test_inversions` pins the values `[0.5, -0.1, -0.2, 0.3, -0.4]`.

## `inversion_periods`
Key idea: one pass over the series. A negative value opens a run if none is open; a non-negative value closes it; the last run must be closed after the loop. A zero slope is not inverted.
Formula: runs of consecutive rows with `slope < 0`, reported as `(first_timestamp, last_timestamp)`.
Common mistake: forgetting to flush an open run at the end of the series (the final `(2024-01-05, 2024-01-05)` in the test) or reporting the first non-negative day as the end. `test_inversions` checks both runs.

## What the output means
The price table shows the bond's convex price/yield curve: 100 at 4%, about 92.2 at 5% and 85.1 at 6%. The first percentage point costs 7.8 and the next costs 7.1, so each additional point costs a little less. Modified duration 8.18 says "about 8.2% per point", an overestimate of the loss for rises and an underestimate of the gain for falls, which is what convexity of 79 repairs. On the snapshot, 10y minus 2y was inverted (at least 20 trading days) in 2000, early 2006, August 2006 to March 2007, and 2022-24; the last run, 537 trading days with a trough of -1.08 pp, is the longest and deepest since 1990 (the 2019 inversion was shorter than 20 days). The four curve snapshots show the cycle: mildly inverted in December 2006, flat between 2y and 10y (with 3m above both) in August 2019, deeply inverted in July 2023 (3m 5.55, 10y 3.97), and in the latest row a normal upward slope again (4.20 / 4.88 / 5.29).
