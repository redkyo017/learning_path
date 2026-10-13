# Lab 10 — Solution notes

## annualize_vol
Daily returns have a standard deviation; independent daily shocks add in variance, so the standard deviation over `periods` days is the daily one times sqrt(periods). Formula: `std(ddof=1) * sqrt(periods)`. Common mistake: `ddof=0` (numpy's default) or multiplying by `periods` instead of its square root. The test compares with `r.std(ddof=1) * sqrt(252)`, so both slips fail it.

## sharpe
Convert the annual risk-free rate to a per-period rate (`rf / periods`), subtract it from every return, then take mean over sample std and scale by sqrt(periods). Formula: `mean(r - rf/p) / std(r - rf/p, ddof=1) * sqrt(p)`. Common mistake: subtracting the annual rf from daily returns, or forgetting it entirely. The `rf=0.0252` case in `test_vol_and_sharpe` catches both.

## portfolio_returns
A portfolio held at fixed weights and rebalanced each period earns, each period, the weighted sum of the asset returns: `returns @ weights`. Common mistake: using a Python loop that returns a list, or `weights * returns` without summing. The test checks the exact values `[0.05, 0.1]` on a two-row frame.

## portfolio_vol
Variance of a weighted sum is the quadratic form `w' C w`; volatility is its square root. The off-diagonal covariances are where diversification lives. Clip at zero so a perfect hedge cannot return NaN from -1e-18. Common mistake: `sum(w**2 * var)`, which assumes zero correlation. The test uses diagonal covariance, so check yourself with a correlated example too.

## min_variance_weights
Minimising `w' C w` subject to `sum(w) = 1` gives `w = C^-1 1 / (1' C^-1 1)`. Shorting is allowed, so weights can be negative or above one. Common mistake: normalising by the wrong thing so weights do not sum to 1; the test asserts `sum == 1` and the exact `[0.2, 0.8]` (inverse-variance weights for uncorrelated assets).

## frontier_two_asset
`w1 = linspace(0, 1, n)`; return is linear in `w1`, variance is `w1^2 var0 + (1-w1)^2 var1 + 2 w1 (1-w1) cov01`. With covariance equal to minus the variance (correlation -1) the 50/50 mix has zero volatility, which is the textbook perfect hedge. Common mistake: `arange` instead of `linspace` (wrong length or end point) or forgetting the clip so tiny negative variance gives NaN. The test checks 101 rows, endpoints exactly 0 and 1, and zero vol at the midpoint.

## What the output means
On the snapshot (2005-01 to 2026-09, daily rebalanced) SPY alone returned about 10.9% a year with 18.9% volatility and a -55% maximum drawdown (Sharpe 0.64 with rf = 0). The 60/40 SPY/IEF mix gave up 2.6 points of CAGR for 8 points less volatility and a -31% drawdown, lifting the Sharpe ratio to 0.78: diversification bought risk reduction faster than it cost return. Adding 10% gold nudged both CAGR and Sharpe up. The SPY/IEF correlation is -0.28 over the whole sample, and the minimum-variance mix is mostly bonds (about 17% SPY). That correlation is an average over regimes; Day 10's content shows it was about -0.41 before 2020, about -0.05 in 2020-2026 and positive in 2022, which is the main limit of everything here.
