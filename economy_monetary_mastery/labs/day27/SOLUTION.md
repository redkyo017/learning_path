# Solution notes — Lab 27

## kelly_fraction
**Idea:** the leverage that maximizes long-run log growth. With growth rate g(f) = f*mu - f^2*sigma^2/2, the maximum is at f = mu/sigma^2. **Formula:** `mu / sigma**2`, with `ValueError` when sigma <= 0. **Common mistake:** returning `inf` or `nan` for zero volatility instead of raising, or passing percent instead of decimals; `test_kelly` expects 0.08/0.2^2 = 2.0 and a `ValueError` for sigma 0.

## fractional_kelly
**Idea:** scale full Kelly down because mu is estimated, not known, and growth is flat near the top. **Formula:** `fraction * kelly_fraction(mu, sigma)`. **Common mistake:** recomputing the formula and forgetting the sigma check; delegating keeps one place for it. `test_kelly` expects 1.0 for the default half.

## vol_target_weights
**Idea:** hold less when recent volatility is high and more when it is low, so the stream's volatility stays near the target. **Formula:** `(target_vol / (returns.rolling(window).std() * sqrt(periods))).shift(1).clip(0, max_leverage).fillna(0)`. **Common mistakes:** omitting `shift(1)` (the weight then uses today's return, a look-ahead), forgetting the cap (near-zero volatility gives huge leverage), or using 252 for a 365-day asset. `test_vol_target_weights` compares against the exact lagged expression and requires zeros in the warm-up; `test_vol_target_caps_leverage` feeds near-zero volatility and expects 2.0.

## breakeven_cost_bps
**Idea:** total gross return divided by total turnover is the cost per unit traded at which net return is zero. **Formula:** `gross.sum() / turnover.sum() * 1e4`, `inf` if the turnover sum is 0. **Common mistake:** dividing by the number of bars or trades instead of summed turnover (a flip counts 2); the test uses turnover 1, 0, 2 against gross 0.01, 0, 0.02 and expects 100 bps, plus `inf` for zero turnover. This is an additive first-order approximation (it ignores compounding), good enough as a filter.

## drawdown_brake
**Idea:** cut exposure after the equity curve has fallen more than a threshold from its peak, and restore it on recovery. **Formula:** `dd = eq/eq.cummax() - 1`; `raw = np.where(dd < -threshold, reduced, 1.0)`; `pd.Series(raw, eq.index).shift(1).fillna(1.0)`. **Common mistake:** no lag (the brake would act on the very bar whose loss triggered it); `test_drawdown_brake_is_lagged` expects `[1, 1, 1, 0.5, 0.5]`: the 25% drawdown appears on bar 2 but the scale drops only on bar 3, and the recovery to 1.3 appears on bar 4 but is not applied until bar 5 (outside the series).

## What the output means
On SPY 200-day momentum (2005-01-03 to 2026-09-29) costs of 5, 20 and 50 bps per unit of turnover cut CAGR from 7.6% to 7.3%, 6.5% and 5.0%: a slow signal with about 103 units of turnover over 21 years is cheap to trade, and its breakeven cost is about 171 bps. The contrast is the one-day reversal rule (buy after any down day): Sharpe 0.70 gross, 0.26 at 5 bps and negative at 20 bps, because 2,755 units of turnover give a breakeven of only about 8 bps. Sizing changes the shape, not the edge: targeting 10% volatility (cap 1.5x) lowers maximum drawdown from about -34% to about -17% at some CAGR cost, and the drawdown brake helps less (about -30%) because it reacts after the damage and re-risks late. Full Kelly on SPY's historical mean and volatility is about 3.4x leverage, which no one should run; half and quarter Kelly are still 1.7x and 0.85x of an estimate that is itself noisy.
