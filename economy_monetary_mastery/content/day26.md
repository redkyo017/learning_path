# Day 26 — How backtests lie: bias and overfitting

> Block 5: Quant trading. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Yesterday's backtester turns any idea into an equity curve in fifteen lines. That is the problem: if testing is nearly free, the number of ideas you try is limited only by patience, and the best-looking result of many tries is mostly luck. A backtest does not report what a strategy will earn. It reports what the strategy would have earned on one particular history, after a human chose the strategy partly by looking at that same history.

For a software engineer the closest analogy is tuning a flaky test until it passes: the green check no longer says the code is correct. This day is the statistics of that failure. You will learn the standard list of biases (the "bias zoo"), a formula that deflates a Sharpe ratio for the number of things you tried, a test layout that respects time, and a habit (the research log) that makes the correction possible. Day 27 adds realistic costs and sizing, and Day 30 imports today's `common.stats` functions to judge a paper-trading candidate.

## Core concepts

### The bias zoo

Each of these makes a backtest look better than reality. They compound.

- **Look-ahead bias.** The rule uses information that did not exist when the trade was decided. Day 25's one-bar lag and its `test_no_lookahead` exist for exactly this. Subtler forms: using a fundamentals number before its release date, or adjusting for a split that had not yet happened.
- **Survivorship bias.** The universe contains only companies and coins that are still alive. Delisted, bankrupt and dead-coin histories are missing, and they are the losers. This course's snapshots are a clean example: the tickers in `labs/data` (SPY, the Vietnamese blue chips, BTC and ETH) were chosen because they exist and matter in 2026. A momentum study run on "today's top 30 coins" starts from a list that already knows which coins won. Index ETFs such as SPY are less affected because the index itself drops losers on a rule and the fund tracked it live, but any hand-picked list of single names is affected.
- **Selection bias and multiple testing.** Try 100 variants, report the best. The best of 100 noise strategies looks like skill. This is the main subject of the day.
- **Data snooping.** The same history is reused by the whole research community. Even if you test one idea, ten thousand people have tested neighbouring ones on the same S&P 500 series, and the ideas that survived to publication are the lucky ones. Your single test inherits their selection.
- **Overfitting through parameters.** Every free parameter (lookback, threshold, stop level) is a dial that can be turned until the past fits. A rule with six dials can describe almost any 20-year chart.
- **Regime dependence.** A rule that worked in a falling-rate, rising-equity world (2009 to 2021) can be a different animal when rates rise. Sub-period checks (Day 25's 2005-2014 vs 2015-2026 split) are the cheap test.
- **Unrealistic fills.** Trading at the close, in any size, at no cost. Day 9 showed that every trade has a counterparty and a spread; thin books, queue position and market impact eat the paper edge. Day 27 puts numbers on it.
- **Ignoring limit-locked days.** On Vietnamese exchanges a stock can hit its daily price band (Day 16) and stay there: the backtest shows a fill at the closing price, but nobody could sell. The backtest trades on days where the market was in practice closed to you. Note that the snapshot closes are dividend and split adjusted, so limit-hit detection from them is approximate.

### Sharpe ratio and the luck problem

The Sharpe ratio is mean return divided by volatility. Measured from a finite sample it is itself an estimate with an error bar, and the error bar is wide. For daily data, a year of observations gives a standard error on the annualized Sharpe of roughly 1; in a one-year sample a strategy with a true Sharpe of 0 shows an annualized Sharpe above +1 roughly one time in six. Now pick the best of 200 such strategies: the expected best is near 2.8 (`expected_max_sharpe(200, 1.0)` in units of one standard error) with no skill at all.

### PSR: the probability the Sharpe is real

The **Probabilistic Sharpe Ratio** (PSR) answers "given this sample length and these return shapes, how likely is the true Sharpe to exceed a benchmark?" With per-period Sharpe `sr`, benchmark `sr_b`, `n` observations, skewness and raw kurtosis:

```
PSR = Phi( (sr - sr_b) * sqrt(n - 1) / sqrt(1 - skew*sr + (kurtosis - 1)/4 * sr^2) )
```

`Phi` is the standard normal cumulative distribution. Longer samples raise it (the `sqrt(n-1)`), negative skew and fat tails lower it (they widen the error bar). The units matter: `sr` here is per-period, not annualized. Divide an annualized daily Sharpe by `sqrt(252)` before using it.

### DSR: deflate for how many things you tried

If you tried `N` strategies, the benchmark is not zero but the Sharpe you would expect from the luckiest of `N` skill-less trials. For trial Sharpes with variance `v`:

```
E[max SR] = sqrt(v) * ( (1 - g) * Phi^-1(1 - 1/N) + g * Phi^-1(1 - 1/(N*e)) ),   g = 0.5772 (Euler-Mascheroni)
DSR = PSR(sr, sr_b = E[max SR])
```

The **Deflated Sharpe Ratio** (DSR) is PSR against that bar, and it is the probability that the winner's true Sharpe beats what luck alone would deliver. It was introduced in [Bailey and López de Prado (2014), "The Deflated Sharpe Ratio: Correcting for Selection Bias, Backtest Overfitting and Non-Normality", Journal of Portfolio Management 40(5), 94-107](https://papers.ssrn.com/abstract=2460551). The honest question behind the formula is "how many things did you try?", and the formula cannot be applied without an honest answer. Note that `v` is the cross-trial variance of Sharpe, so ten near-identical variants deflate far less than ten unrelated ones.

### Train, test, walk-forward

The minimum defence is a split: fit on the past, evaluate on a later block you did not touch. Two rules: the test block is looked at once, and any tuning after seeing it turns it into training data. A single split wastes data and depends on where the cut falls, so the time-series refinement is **walk-forward**: choose parameters on a training window, trade the next test block, slide forward, and stitch the test blocks into one out-of-sample curve. The lab does this for momentum lookbacks (train 756 days, test 126), re-choosing the lookback each window.

Why not ordinary k-fold cross-validation? Standard k-fold does not shuffle by default, but it still trains on folds that come after the test fold. In time series that leaks: neighbouring days are correlated, and labels built from overlapping future returns (a 20-day-forward return shares 19 days with its neighbour) mean a training sample can contain part of the test outcome. The fixes are to keep folds in time order, **purge** training observations whose label window overlaps the test fold, and add an **embargo**, a gap after the test fold before training resumes, so serial correlation cannot carry information across the boundary. Walk-forward is the simpler default in this course, an opinion rather than a theorem; combinatorial purged cross-validation (López de Prado, *Advances in Financial Machine Learning*) is the heavier alternative that uses more of the data.

### Most published factors do not replicate

The same logic applies to the finance literature itself. [Harvey, Liu and Zhu (2016), "... and the Cross-Section of Expected Returns", Review of Financial Studies 29(1), 5-68](https://academic.oup.com/rfs/article/29/1/5/1843824) catalogued 316 factors proposed in published work and argued that, given how many had been tested, a new factor should clear a t-statistic of about 3.0, not the conventional 2.0, so many claimed discoveries are likely false. [Hou, Xue and Zhang (2020), "Replicating Anomalies", Review of Financial Studies 33(5), 2019-2133](https://ideas.repec.org/a/oup/rfinst/v33y2020i5p2019-2133..html) re-ran 452 anomalies with value-weighted returns and NYSE breakpoints (which reduce the weight of tiny, illiquid stocks) and found about 65% fail the usual t of 1.96, and 82% fail a stricter multiple-testing hurdle of 2.78. In plain English: a large part of what was published as "this characteristic predicts returns" depended on microcaps, equal weighting or luck, and where the effect survives it is smaller than first reported. This is contested: Chen (2022, preprint, revised 2025) bounds the false-discovery rate and argues most claimed findings are statistically true, even if smaller than first reported ([arXiv 2206.15365](https://arxiv.org/pdf/2206.15365)). The practical reading holds either way: expect any published or self-discovered edge to shrink.

### The research log and the n_trials honesty rule

DSR needs `N`, and memory is a poor counter. Keep a log with one line per variant you evaluate, including the ones you abandoned after a glance: date, idea, parameters, data window, headline metric. Count every row in `N`. A parameter scan of five lookbacks is five trials; switching to a different asset because the first looked bad is more; "I'll just try the 100-day too" is one more. The rule is that a variant you looked at is a trial, whether or not you kept it. A log that omits the failures is the same bug as survivorship bias, applied to yourself.

## Worked example

`main()` runs the lab in three parts. Part one is the p-hacking demo: `n` strategies of pure noise (daily returns normal with mean 0, st. dev. 1%), 1,000 days, seed 0. Rank them on the first 500 days, take the winner, then look at the same strategy on the last 500 days. Annualized Sharpe:

| Strategies tried | Best in-sample | Same strategy out-of-sample |
|---|---|---|
| 10 | 1.24 | -0.43 |
| 100 | 1.84 | 0.81 |
| 1000 | 2.11 | -0.82 |

Every strategy has a true Sharpe of exactly zero. The in-sample column is the maximum of noise and rises with the number tried; the out-of-sample column is what is left once the luck is gone, and it scatters around zero (the 0.81 is itself noise). Report only the left column and a noise generator looks like a Sharpe-2 fund.

Part two is walk-forward on SPY (snapshot 2005-01-03 to 2026-09-29) with lookbacks 20, 60, 120, 200 and 250 days. Full-sample Sharpe values are 0.72, 0.82, 0.71, 0.64 and 0.65: the best in hindsight is the 60-day at 0.82. Walk-forward re-picks every 126 days from the previous 756 and earns an out-of-sample Sharpe of 0.76 over 4,662 days. It is a little below the hindsight pick and inside the spread of the five, which is what an honest estimate looks like: the 0.82 was the best of five and slightly flattering. The chosen lookback hops between 20 and 250 from window to window, a sign that the five are close substitutes and the "best" one is not stable. This is the same flat profile Day 25 recommended checking.

Part three is DSR of the 60-day rule with the five lookbacks as the five trials. Both PSR and DSR print as 1.000. That is correct and instructive: five highly correlated variants have tiny Sharpe variance, so the luck benchmark is nearly zero, and a 0.82 Sharpe over 21 years is statistically strong in its own right. DSR is not saying SPY trend-following is a money machine (Day 25 found it mainly cuts drawdown, not improves Sharpe); it says five lookbacks of one idea is not a multiple-testing problem. The deflation bites when `N` is large and the trials differ. For the same 0.82 Sharpe and a cross-trial Sharpe spread of 0.05 annualized (computed outside main(); see Exercise 3), the DSR is still about 0.998 at N = 10,000, which shows how strong a 21-year, 0.82 Sharpe is on a single series. The shorter and noisier your data, the faster DSR collapses: with `sr = 0.1`, `sr_variance = 0.001` and 1,000 observations (the lab test's numbers, per-period units), 10 trials give a DSR near 0.94 and 1,000 trials near 0.46 (computed outside main(); see Exercise 2).

```
Where the Sharpe goes
   observed best Sharpe  =  true skill  +  selection luck (grows with N)  +  sampling noise
   DSR asks:  after subtracting the luck term for N trials, is skill still > 0 ?
```

## Exercises

1. Run `p_hacking_demo(100, 1000, seed)` for seeds 0 to 19 and compute the average in-sample and out-of-sample Sharpe of the winners.
   **Hint:** loop over seeds and take `np.mean` of each key.
   **Solution sketch:** the in-sample mean is about 1.8 and the out-of-sample mean about 0.2 (near 0 up to noise), because every strategy has zero true Sharpe; the gap is the selection bias; it is the same gap the DSR formula tries to estimate.
2. Compute `deflated_sharpe_ratio(0.1, N, 0.001, 1000)` for N = 1, 10, 100, 1000. Plot DSR against N.
   **Hint:** N = 1 should equal `probabilistic_sharpe_ratio(0.1, 0.0, 1000)`.
   **Solution sketch:** DSR falls monotonically from about 0.999 at N = 1 to about 0.46 at N = 1000; the curve is flat for small N and steep later, which is why a handful of variants hardly matters but a grid search with thousands does.
3. A strategy has an annualized Sharpe of 0.82 over 21 years of daily data. Convert to per-period, then compute its PSR against 0 and its DSR for N = 5, 100, 1000 using a per-period Sharpe variance equal to `(0.05 / sqrt(252))**2`.
   **Hint:** per-period Sharpe is annualized divided by `sqrt(252)`; n_obs is about 5,470 (the SPY snapshot).
   **Solution sketch:**
   - PSR is essentially 1.000 because 0.82 over 21 years is a t-statistic near 3.8
   - DSR stays above 0.99 for every N listed because the benchmark `E[max SR]` is tiny when the Sharpe spread is only 0.05
   - increase the spread to 0.5 and N to 1000 and the DSR drops sharply, so the variance input matters as much as N
4. Add a fourth part to `main()` that runs `walk_forward` with train 504 and test 63 instead of 756 and 126. Does the OOS Sharpe change much?
   **Hint:** reuse the same `lookbacks`.
   **Solution sketch:** window sizes are themselves parameters; if the answer swings widely, the walk-forward result is not robust; report a few settings fixed in advance, not the best.
5. Make `walk_forward` leak by choosing the lookback with `prices.iloc[i-train:i+test]`. How much does the OOS Sharpe on SPY rise? The given `test_walk_forward_has_no_leakage` does not catch this leak; write a stronger test that does.
   **Hint:** perturb only one test block, with a random path that continues from the last training price, and check that the choice for that same window does not change.
   **Solution sketch:**
   - the leaky OOS Sharpe on SPY rises from 0.76 to about 1.06 (computed outside main()), because selection now sees the block it is graded on
   - the given test passes anyway: only the last window can see the inflated bars, and a level jump moves both long lookbacks' Sharpe the same way
   - the stronger check replaces `prices.iloc[i:i+test]` with a random walk (plus a random drift) and rescales later prices to stay continuous; the correct function returns the same choice for window k, the leaky one changes it for some seed (verified on a 600-bar series with lookbacks 20 and 60, train 250, test 50, 20 seeds per window)

6. Start a research log for this course: one row per variant you have run in Days 25 to 27, including parameter scans. What is your `N` so far?
   **Hint:** count every lookback in a scan as a row.
   **Solution sketch:** `N` is the number of rows, not the number of ideas; include assets tried and abandoned; reuse it as `n_trials` on Day 30.
7. Name which bias in the zoo applies to (a) a backtest of 30 Vietnamese stocks picked in 2026 by market cap, run from 2012; (b) a daily-close strategy on a stock that regularly hits its limit-down; (c) a model tuned on 2020-2021 crypto data.
   **Hint:** match each to the zoo list.
   **Solution sketch:**
   - (a) survivorship, because 2026 market-cap leaders exclude names that fell out or delisted
   - (b) limit-locked days and unrealistic fills, because the exit price was not available
   - (c) regime dependence and overfitting, because one bull-market regime cannot validate it

## Anti-patterns / Common mistakes

- **Tuning on the test set.** Looking at the test block, adjusting the rule and re-testing turns the test block into training data. Decide the test protocol before the first run and use it once.
- **Reporting only the best variant.** Without the number of variants tried, the headline Sharpe cannot be interpreted. Report N, the full table, and the DSR.
- **Survivorship-biased universes.** "The current top 30" is a list built with hindsight. Use point-in-time membership, or state the limitation next to every result.
- **Treating a flat DSR of 1.000 as proof.** It means multiple testing is not the weak point. Costs, regime and fills still can be.
- **Mixing units.** PSR and DSR take per-period Sharpe. An annualized input gives answers that look confident and are wrong.
- **Shuffled k-fold on time series.** Folds that train on the future of the test fold leak. Keep order, purge and embargo.

## Lab

Open [`labs/day26/README.md`](../labs/day26/README.md). Implement `probabilistic_sharpe_ratio`, `expected_max_sharpe`, `deflated_sharpe_ratio`, `p_hacking_demo` and `walk_forward` in `lab.py` and run `uv run pytest day26`. `main()` prints the p-hacking table, the SPY walk-forward comparison, and the DSR of the best lookback, and saves `.cache/plots/day26.png`. The first three functions are published as `labs/common/stats.py`, verified by `uv run pytest common/tests/test_stats.py`, and Day 30 imports them.

## Teardown

Nothing billable is created. The lab only reads frozen snapshots; no broker, no key, no order.

## Journal prompt

Open a research log today and back-fill every variant you have run so far in Block 5. Write the total as your `N`, and write one sentence on which bias in the zoo your most promising result is most exposed to.
