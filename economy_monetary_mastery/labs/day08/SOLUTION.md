# Solution notes — Day 08

## `pv_cashflows`
Key idea: money later is worth less now; each cash flow is divided by (1+r) once per year it waits.
Formula: `sum(cf / (1 + rate) ** k for k, cf in enumerate(cashflows, start=1))`.
Common mistake: `enumerate` from 0, which treats the first cash flow as arriving today and overstates PV by (1+r). `test_pv` pins the t=1 convention.

## `gordon_value`
Key idea: a cash flow growing at g forever, discounted at r, is a geometric series that sums to `next_cf / (r - g)` when r > g. When r <= g the series diverges, so the model has no answer.
Formula: `next_cf / (r - g)`; raise `ValueError` if `r <= g`.
Common mistake: using the current rather than next cash flow, or returning `inf`/a negative number for r <= g. `test_gordon_and_duration` gives 5/(0.08-0.03) = 100 and `test_gordon_rejects_r_le_g` covers r == g and r < g.

## `equity_duration`
Key idea: with V = CF/(r-g), a 1-point rise in r changes V by about 1/(r-g) percent per point. A 5% spread (r-g) means 20 years of duration, longer than a 30-year Treasury bond's.
Formula: `1 / (r - g)`; same `ValueError` guard.
Common mistake: forgetting the guard, or confusing it with the P/E. The test expects exactly 20 for (0.08, 0.03).

## `rate_shock_pct`
Key idea: reprice the same cash flows at the new rate and compare. Cash flows far in the future shrink most because they are compounded by (1+r) many more times.
Formula: `pv(cf, rate + shock) / pv(cf, rate) - 1`.
Common mistake: subtracting from `rate` instead of adding, or returning the dollar change instead of the fraction. The test requires growth < value < 0 and the closed form (1.08/1.09)^10 - 1.

## `beta`
Key idea: beta is the slope of asset returns on market returns: how many percent the asset moves per 1% market move. It needs the two series aligned on dates; pandas does that on concat.
Formula: `cov(a, m) / var(m)`, both with ddof=1 (mixing `np.cov`'s ddof=1 with `np.var`'s default ddof=0 gives a beta that is off by n/(n-1)).
Common mistake: ddof mismatch, or not aligning. With `asset = 2*mkt + 0.0001` the test demands 2.0 within pytest's relative tolerance, and a ddof mismatch on 500 points is off by 0.2%, far outside pytest's default tolerance (1e-6 relative).

## `correlation`
Key idea: correlation is beta rescaled by the ratio of volatilities; it is bounded in [-1, 1] and ignores scale.
Formula: `a.corr(b)`.
Common mistake: using `np.cov` (not scaled). The test expects 1.0 for a perfectly linear pair.

## What the output means
In 2010-2019 growth (IWF) and value (IWD) both had a beta near 1 to SPY, and their monthly returns were positively correlated with the monthly change in the 10-year yield (about +0.4 and +0.5): yields rose when growth looked good. In 2022 the sign flipped to about -0.6 and -0.55: the yield was driven by inflation and Fed tightening, so higher yields meant lower prices. IWF's beta rose to 1.10 and IWD's fell to 0.89, and over the year the 10-year went from 1.52% to 3.88% while IWF lost 29.3% against IWD's 7.8%. Growth stocks have more of their value in distant cash flows, so they behave like longer-duration bonds. All of these are one-year, 12-observation (2022) estimates, so treat the 2022 numbers as illustrative, not stable parameters.
