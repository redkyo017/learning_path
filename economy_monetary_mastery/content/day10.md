# Day 10 — Portfolio theory: diversification, Sharpe, frontier

> Block 2: Rates & asset pricing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 8 priced one asset by discounting its cash flows. Today's question is what happens when you hold several. The answer is the most useful result in investing for a non-professional: combining assets whose returns do not move in lockstep lowers risk without lowering expected return by the same amount. That is the closest thing to a free lunch in finance, and it is why a Vietnamese stock investor who also holds US index ETFs and a little bitcoin is not simply "taking three bets".

It also comes with a warning you will need on every later day: the inputs (volatility, correlation, expected return) are estimated from a short, noisy past, and correlations shift with the economic regime. In 2008 US Treasuries hedged stocks; in 2022 they did not. The lab gives you the standard toolkit (annualised volatility, Sharpe ratio, portfolio variance, minimum-variance weights, the two-asset frontier) and applies it to SPY, IEF and GLD so you can see the effect, and its limits, on real data.

## Core concepts

### Risk as volatility, and why that is only a convention

Finance measures risk as **volatility**: the standard deviation of returns. Daily returns are roughly independent, so variance adds across days and standard deviation scales with the square root of time:

```
annual vol = daily std (ddof=1) * sqrt(252)        (your annualize_vol)
```

A daily standard deviation of 1.2% is about 1.2 * 15.9 = 19% a year. The convention is popular because it is easy to compute and, for a portfolio, it decomposes cleanly (below).

- It treats up and down moves alike. You do not mind a surprise gain.
- It assumes a bell curve. Real returns have fat tails: days of -5% or worse happen far more often than a normal distribution allows.
- Humans feel **drawdowns** (peak-to-trough loss), not standard deviations. SPY's volatility in the lab sample is 19%, but the thing that makes people sell is the -55% drawdown of 2007-2009. Two portfolios with the same volatility can have very different worst losses.
- It says nothing about permanent loss (a bankrupt company), liquidity, or the risk that your plan fails because you cannot hold through a fall.

Use volatility for arithmetic and drawdown for honesty. Report both.

### Diversification: the arithmetic

For two assets with weights w1, w2 (summing to 1), volatilities s1, s2 and correlation rho, the portfolio variance is:

```
var = w1^2 s1^2 + w2^2 s2^2 + 2 w1 w2 rho s1 s2        (matrix form: w' C w, your portfolio_vol)
```

Expected return is just the weighted average of the two returns, but volatility is **not** the weighted average, because of the last term. Take two assets each with 20% vol, held 50/50:

```
rho = +1   ->  vol = 20.0%   (no benefit: same as either asset)
rho =  0   ->  vol = 14.1%   (sqrt(0.02))
rho = -1   ->  vol =  0.0%   (a perfect hedge)
```

Any correlation below +1 pulls portfolio volatility below the weighted average of the parts, while the expected return stays at the weighted average. That gap is the "free lunch" (Harry Markowitz, [Portfolio Selection, 1952](https://www.jstor.org/stable/2975974)). It is free in the sense that you give up no expected return, not in the sense that it is guaranteed: the benefit depends entirely on correlations that you have to estimate and that change.

In the matrix form `w' C w`, C is the covariance matrix (annual units for annual vol). With many assets there are far more covariance terms than variance terms, so a portfolio of 30 stocks is mostly a bet on how they co-move, not on how each one wobbles. Diversification removes **idiosyncratic** risk (one firm's bad quarter) but cannot remove **market** risk (everything falling together). Day 8's beta is the exposure to that shared part.

### Sharpe ratio

Return per unit of risk, after subtracting what a risk-free deposit would pay:

```
Sharpe = mean(r - rf) / std(r - rf) * sqrt(252)        (daily data, rf converted to daily = rf/252)
```

A Sharpe of 0.3 means the asset earned 0.3 percentage points of annual excess return per percentage point of annual volatility. Rough scale: long-run equity indices have sat around 0.3-0.5 over many decades with the risk-free rate (Day 7's bills) subtracted; the table below reads higher (0.64, with rf = 0) because 2005-2026 was a strong period for US stocks (the 3-month Treasury yield was 4.2% at the end of this lab's data, see [FRED DGS3MO](https://fred.stlouisfed.org/series/DGS3MO)); 1.0 sustained over decades is exceptional; claims of 3+ in a backtest are almost always an error or an overfit. The lab's `main()` uses rf = 0 for simplicity; that overstates each Sharpe by about rf / vol, more for a low-volatility mix like 60/40 than for stocks. With rf near 2% the table reads about 0.55 for SPY and 0.61 for 60/40, so the ranking survives; compare portfolios, not absolute levels.

Sharpe is scale-free, so you can lever or de-lever a high-Sharpe portfolio to hit the volatility you want. Its weakness is the one above: it uses volatility, so it ignores skew and tail risk. A strategy that sells insurance has a beautiful Sharpe until the day it does not.

### The efficient frontier and the capital market line

Plot every possible mix of your assets by volatility (x) and expected return (y). The **efficient frontier** is the upper-left edge: for each level of risk, the highest expected return available. Everything below it is dominated. The leftmost point is the **minimum-variance portfolio**; for fully invested weights it has a closed form:

```
w_minvar = inv(C) * 1 / (1' * inv(C) * 1)        (your min_variance_weights)
```

For uncorrelated assets that is just weights proportional to 1/variance: the calmer asset gets more. In the lab test, variances 0.04 and 0.01 give weights 20% / 80%.

Add a risk-free asset and the picture simplifies. The best risky portfolio is the one where a straight line from the risk-free rate touches the frontier (it has the highest Sharpe ratio). You then hold that portfolio plus cash or borrowing: the line is the **capital market line**, and "how much risk" becomes a single dial, the cash weight. The theory's punchline is that everyone should hold the same risky mix and differ only in the dial. In practice the "same risky mix" is approximated by a broad market index, which is the bridge to the next sections.

### Why estimates break the optimiser

The frontier is computed from expected returns, volatilities and correlations. Volatilities and covariances are estimated far better than means from a few years of daily data (they are second moments, with many observations behind them), though correlations still shift by regime: the whole-sample SPY/IEF figure of -0.28 mixes about -0.41 before 2020 with about -0.05 in 2020-2026 and +0.19 in 2022. **Mean returns are the worst-estimated input.** The standard error of an annual mean return is roughly vol / sqrt(years): with 19% vol and 20 years of data it is about 4 percentage points, the same size as the entire equity risk premium. You can see the instability in the snapshot: SPY's annualised mean daily return was about 6.6% in 2005-2012, 14.5% in 2013-2019 and 16.3% in 2020-2026; IEF's was 6.7%, 2.4% and about 0%.

An optimiser that maximises return per unit of risk treats those estimates as truth and loads up on whatever looked best in the sample, which is then the most likely to disappoint. This "error maximiser" behaviour is why practitioners prefer inputs that are estimated better: minimum-variance uses only the covariance matrix (no mean returns), and DeMiguel, Garlappi and Uppal found that [naive 1/N weights were hard for optimised portfolios to beat out of sample](https://doi.org/10.1093/rfs/hhm075) (2009). Minimum variance is less fragile, not immune: it still rests on an estimated covariance, it can take extreme or negative weights (your function allows shorting), it is a low-return corner rather than the best answer for a return target, and its advantage grows with fewer assets and more data.

### Factors in plain English

Instead of thinking in assets, think in the characteristics that explain why some assets earn more than others. The standard list (from the [Fama-French data library](https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html) and later work):

- **Market**: owning stocks at all versus cash. The biggest source of return and of risk.
- **Size**: small companies have historically earned more than large ones, with more risk.
- **Value**: cheap stocks (low price relative to book value or earnings, Day 8's low P/E) versus expensive ones.
- **Momentum**: recent winners have tended to keep winning over months, then reverse.
- **Quality**: profitable, low-debt, stable-earnings firms.

A **factor ETF** is nothing mystical: it is a rules-based portfolio (for example "hold the 100 cheapest large caps, weighted by size") that holds those stocks for you. Day 8's IWD (value) and IWF (growth) are simple versions. Factors earn their premium partly as pay for bearing risk and partly through investor behaviour, and each can underperform for a decade, so a factor tilt is a bet that needs patience.

### Index investing and the base-rate argument

Every active manager is trying to beat the market, but before costs the average dollar must earn the market return (active winners are other investors' losers), so after costs the average active dollar earns less. S&P's [SPIVA U.S. Scorecard, year-end 2025](https://www.spglobal.com/spdji/en/documents/spiva/spiva-us-year-end-2025.pdf) measures this: **89.93% of all U.S. large-cap funds underperformed the S&P 500 over 15 years** (78.78% over the single year 2025; 85.59% over 10 years). Funds that disappeared are counted, which is the correction for survivorship that most casual comparisons miss. Past winners also rarely repeat: the same publisher's [persistence scorecard](https://www.spglobal.com/spdji/en/spiva/article/us-persistence-scorecard/) finds little persistence among top performers.

So the **bar every strategy must beat** is a cheap, broad index fund held for the same period, after fees, taxes and your own behaviour. Days 25-30 use that bar to judge backtests. This is a base rate, not a proof: some managers do beat it, and beating the index over a long horizon is far rarer than the marketing implies.

## Worked example

The lab compares three portfolios of SPY (US stocks), IEF (7-10 year Treasuries) and GLD (gold), rebalanced daily to fixed weights, from January 2005 to September 2026 (your `portfolio_returns`, with rf = 0):

```
portfolio              CAGR    vol   Sharpe   max drawdown
100/0   SPY           10.9%  18.9%    0.64      -55.2%
60/40   SPY/IEF        8.3%  10.9%    0.78      -31.4%
60/30/10 SPY/IEF/GLD   9.1%  11.3%    0.83      -31.2%
```

Giving up 2.6 points of CAGR for 8 points less volatility and 24 points less drawdown lifted the Sharpe ratio: the diversification gap above, in numbers. The reason is the SPY/IEF correlation of -0.28 over the whole sample, and the minimum-variance mix of the two is about 17% SPY / 83% IEF (volatility 5.6%), at the far-left tip of the frontier.

Now the two years that test the claim. Calendar returns, SPY vs a 60/40 SPY/IEF mix:

```
            SPY     IEF     60/40    SPY-IEF correlation (daily)
2008      -36.8%  +17.9%   -16.7%        -0.47
2022      -18.2%  -15.2%   -16.4%        +0.19
```

In 2008 the 60/40 mix lost less than half of what stocks did, because bonds rose when stocks fell (a growth shock: rates fell, Day 7). In 2022 the mix barely helped, losing 16.4% against 18.2%, because the shock was inflation and rising rates (Day 8's discount-rate regime): stocks and bonds fell together. Its worst drawdown that year was -20.7% against -24.5% for SPY. Same portfolio, same weights, opposite experience. Correlation is a property of the regime, not of the assets.

Rebalancing moves money from the winner to the loser. Start with 100 at 60/40, let stocks gain 10% and bonds stay flat, then restore the target:

```
            Your portfolio (target 60 / 40)
  Before:   Stocks 66.0 | Bonds 40.0 | total 106.0   (stocks now 62.3%)
  Trade:    sell Stocks 2.4  ->  buy Bonds 2.4
  After:    Stocks 63.6 | Bonds 42.4 | total 106.0   (60 / 40 again)
```

Daily rebalancing in the lab is a modelling simplification; real portfolios rebalance monthly or on a threshold, and taxes and spreads matter.

## Exercises

1. Two assets each have 20% annual volatility and are held 50/50. Compute portfolio volatility for correlations +1, +0.5, 0 and -1.
   **Hint:** var = 0.25 * 0.04 + 0.25 * 0.04 + 2 * 0.25 * rho * 0.04.
   **Solution sketch:** variance = 0.02 + 0.02 * rho, so vol = 20.0% at +1, 17.3% at +0.5, 14.1% at 0, and 0% at -1. Most of the gain arrives between rho = 1 and rho = 0.5-0; the last bit needs a real hedge, which is rare.

2. Fund A returned 9% with 15% volatility; Fund B returned 7% with 8% volatility; the risk-free rate is 4%. Which has the higher Sharpe ratio? What would you hold if you want 15% volatility?
   **Hint:** Sharpe = (return - rf) / vol; leverage scales return and vol together.
   **Solution sketch:** A: 5/15 = 0.33; B: 3/8 = 0.375. B is better per unit of risk. Scaling B by 15/8 = 1.875x (borrowing 87.5% at 4%) gives 4% + 1.875 * 3% = 9.6% at 15% vol, beating A.

3. Two uncorrelated assets have volatilities 20% and 10%. Find the minimum-variance weights and portfolio volatility.
   **Hint:** For uncorrelated assets, w1 = var2 / (var1 + var2).
   **Solution sketch:** w1 = 0.01 / 0.05 = 20%, w2 = 80%. Variance = 0.04 * 0.04 + 0.01 * 0.64 = 0.0016 + 0.0064 = 0.008, vol about 8.9%, lower than the 10% of the calmer asset alone. A volatile asset can reduce portfolio risk even though it is riskier on its own.

4. A fund shows a daily return standard deviation of 1.2%. Annualise it, and say what is wrong with annualising the standard deviation of monthly returns by multiplying by 252.
   **Hint:** Variance adds over independent periods; standard deviation scales with the square root.
   **Solution sketch:** 1.2% * sqrt(252) = 19.0%. For monthly data the factor is sqrt(12), not 252, so multiplying by the number of days would overstate the figure by a factor of 252 / sqrt(12) = 73. The factor always matches the data frequency, which is why `annualize_vol` takes `periods`.

5. You hold 50% BTC and 50% ETH. Volatilities are 60% and 70%; the correlation is 0.8. Compute portfolio volatility and compare with the average of the two. Is this "diversified"?
   **Hint:** Use the two-asset variance formula with rho = 0.8.
   **Solution sketch:** var = 0.25 * 0.36 + 0.25 * 0.49 + 2 * 0.25 * 0.8 * 0.6 * 0.7 = 0.09 + 0.1225 + 0.168 = 0.3805, so vol is 61.7% versus an average of 65%: a 3-point saving. Two correlated crypto assets are one bet in two wrappers. Real diversification would pair them with something of low correlation (Days 13-24).

6. Using the lab, compute SPY and IEF annualised mean and volatility separately for 2005-2012, 2013-2019 and 2020-2026 (`px.pct_change()` then slice). For each window find the minimum-variance weights and the maximum-Sharpe weights (rf = 0, shorting allowed). How far does each move?
   **Hint:** Max-Sharpe weights are proportional to inv(C) @ mu, normalised to sum to 1 (the lab has no max-Sharpe function; write it in three lines). Min-variance uses only C.
   **Solution sketch:** Min-variance SPY weights are about 18%, 22% and 13%: stable. Max-Sharpe SPY weights are about 18%, 39% and 101% (with -1% IEF) as SPY's mean goes 6.6%, 14.5%, 16.3%: the answer swings from mostly bonds to all stocks on the means alone. That is the noisy-means argument in numbers; prefer min-variance or simple weights when you cannot defend your return forecasts.

7. SPIVA says 89.93% of US large-cap funds underperformed the S&P 500 over 15 years. If you pick one fund at random from the start, what is the chance it beat the index? What two things would make you doubt the result for your own holding?
   **Hint:** The complement; think about what S&P measures and what you hold.
   **Solution sketch:** About 10%. Doubt it if your holdings are not US large caps (SPIVA shows other categories, with similar but not identical rates), or if the comparison index is not your real alternative (for example an equal-weight or Vietnamese index). Also, 15 years is one period and the figure changes with each scorecard. The conclusion that survives is "cheap broad index is hard to beat after costs".

## Anti-patterns / Common mistakes

- Optimising on sample means. The frontier built from the past 10 years of means will pick last decade's winners (Exercise 6). Prefer minimum variance, equal weights, or return estimates you can defend with an economic argument.
- "Diversified" across correlated assets. Ten US tech stocks, or BTC plus ETH, behave as one position (Exercise 5). Count independent sources of risk, not tickers.
- Ignoring that correlations jump in crises. Stock-bond correlation went from -0.47 in 2008 to +0.19 in 2022, and almost all risky assets rise in correlation together in a panic. Stress-test with the worst regime, not the average one.
- Calling volatility "risk" and stopping. Report the maximum drawdown and ask whether you could hold through it (Worked example).
- Quoting a Sharpe ratio without the sample length, risk-free rate and costs. A 2-year Sharpe has a huge error bar.

## Lab

From `economy_monetary_mastery/labs/`: open `day10/README.md`, implement the six functions in `day10/lab.py`, then run `uv run pytest day10` until green and `uv run python -m day10.lab` for the summary and `.cache/plots/day10.png`. Expected: all 5 tests pass; the summary shows the 100/0, 60/40 and 60/30/10 table above and the SPY/IEF minimum-variance weights.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: list your three biggest holdings and write down which regime (growth shock, inflation shock, liquidity squeeze) would hurt each, then say whether any two of them would fall together. If they would, you hold fewer independent bets than you thought.
