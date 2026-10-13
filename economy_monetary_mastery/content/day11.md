# Day 11 — Business cycle, regimes and "priced in"

> Block 2: Rates & asset pricing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Days 7-10 gave you the pricing machinery: a price is future cash divided by a discount rate, and risk is what you measure with volatility and correlation. Today asks what moves the inputs. Cash flows depend on how fast the economy grows; discount rates depend on inflation and on what the central bank does about it. Both arrive as scheduled data releases, and each release is a small experiment in whether the market was already ready for the number.

The idea you need to carry out of today is that markets price the path of growth and inflation, not their level. A great jobs report can send stocks down, and a terrible one can send them up, because only the difference between the number and what was expected is news. Without that, you will read headlines as signals, buy the wrong thing after good news, and misread the 2022 selloff: inflation was not "high" on the day stocks fell, it was higher than forecast.

The lab labels every month since 1990 with one of four growth/inflation regimes, then measures what SPY, TLT and GLD did in each. It is a descriptive table, honestly: a way to see how different the same assets behave when the macro backdrop changes, not a forecast.

## Core concepts

### Macro data that moves markets

Five families of releases do most of the work. Dates are US conventions; check the official calendars ([BLS schedule](https://www.bls.gov/schedule/news_release/), [BEA schedule](https://www.bea.gov/news/schedule)) because they shift.

```
Release            What it measures                        When (typical)               Revised?
GDP                output, quarterly annualised            advance ~1 month after Q     twice, then yearly
Payrolls/UNRATE    jobs added; share unemployed            first Friday, prior month    yes, next 2 months
CPI                consumer price level (YoY, MoM, core)   ~mid-month, prior month      seasonal factors only
PMIs (ISM, S&P)    survey: >50 expanding, <50 shrinking    1st-3rd business day         rarely
Retail sales       consumer spending, nominal              ~mid-month, prior month      yes
```

Three things to internalise. First, almost everything is about last month or last quarter, so markets treat it as a clue about now, and surveys (PMIs) are used as a faster, noisier clue. Second, many numbers are revised: the first payroll print is a draft, and revisions of tens of thousands of jobs are normal. A strategy that backtests on the revised series is trading on data nobody had on the day. Third, the series you have in the lab (INDPRO for output, CPIAUCSL for prices) are monthly, and the 2025 US government shutdown left the 2025-10 CPI observation missing. Row-based `pct_change(12)` would then compare the wrong months, so `main()` reindexes to a full monthly calendar first and the affected months simply drop out.

### The business cycle

The economy alternates between expansion and contraction. A recession in the National Bureau of Economic Research (NBER) definition is "a significant decline in economic activity that is spread across the economy and lasts more than a few months" ([NBER](https://www.nber.org/research/business-cycle-dating)). It is not the textbook "two quarters of negative GDP". The NBER Business Cycle Dating Committee works retrospectively and often announces a peak or trough many months after it happened. As of 2026-10 the latest dates in its chronology are a peak in February 2020 and a trough in April 2020, so by that official record the US has been in expansion since April 2020; no newer announcement appears in the NBER chronology.

Because NBER is late by design, people use real-time indicators. The best known is the Sahm rule: a recession has likely begun when the three-month average of the unemployment rate rises 0.50 percentage points or more above its lowest three-month average of the previous 12 months ([FRED SAHMREALTIME](https://fred.stlouisfed.org/series/SAHMREALTIME)). The latest FRED reading was 0.00 points for September 2026 (updated 2026-10-02), far below the 0.50 trigger. It is one rule that has fired close to the start of past recessions; it is a thermometer, not a forecast, and sample size is a few dozen events at most.

### Four regimes

Growth and inflation can each be rising or falling. That gives four boxes:

```
                    inflation rising        inflation not rising
growth rising       reflation               goldilocks
growth not rising   stagflation             deflation
```

`classify_regime` decides "rising" by direction only: the change over the last `lag` months (default 3) is strictly positive. Flat counts as not rising. A word on labels: they describe direction, not level. Inflation of 3.4% that is slipping from 3.8% is "not rising", so the lab can print "deflation" while prices are still climbing at an uncomfortable pace. Also note the regime flips often (the snapshot flips between stagflation, reflation and deflation across 2026), so treat a regime as a weather report for the last few months.

Rough tendencies people cite (they are tendencies from small samples, not laws): equities do best in goldilocks; commodities and gold do relatively better when inflation is rising; long bonds do best when both growth and inflation fall; stagflation is the worst box for both stocks and bonds because rising inflation pushes yields up while growth weakens profits. There are only a few distinct episodes of each regime, and the "months" column in the lab shows the counts. That is why a table of averages can mislead.

### The central-bank reaction function

Central banks respond to data with a rule of thumb, which markets try to predict. The Taylor rule is the classic sketch:

```
policy rate  ≈  r* + inflation + 0.5·(inflation − target) + 0.5·output_gap
with r* ≈ 2%, target 2%, output_gap in % of potential output
```

If inflation is 4%, target 2% and the economy is at potential (gap 0), the sketch gives 2 + 4 + 1 + 0 = 7%. Real policy never follows this exactly (the Fed has two mandates, looks at core measures and forecasts, and r* is unobservable), but the direction is the lesson: hotter inflation or a stronger economy raises the expected policy rate. Remember the Day 3-5 plumbing: the effective fed funds rate is a market rate the Fed steers into a target range with its administered rates, not one it sets directly. What a bond or stock price needs is the expected path of that rate over the next years, because that is what goes into the discount rate from Day 8. Hence "markets price the path, not the level": a rate of 5% that was expected is old news; a rate of 4% that was expected to be 3% is bad news.

### "Priced in" and surprises

A price is the market's current average expectation. When a number arrives, the change in price reflects only the part nobody expected:

```
price move  ≈  sensitivity × (actual − expected)
```

Expected means the consensus: the median forecast of economists surveyed before the release (Bloomberg, Reuters, and others publish it). To compare surprises across releases, divide by a typical size:

```
surprise_z = (actual − expected) / std of past surprises       (your surprise_z)
```

A CPI of 0.3% against a 0.2% consensus with a typical miss of 0.1 is a +1 sigma surprise. `rolling_zscore` is a related tool: it standardises a series against its own last `window` observations, so you can tell whether today's reading is unusual for recent history.

The 2022 example. US CPI inflation peaked at about 9% year-on-year in June 2022 (the snapshot's CPIAUCSL series gives 9.0%). Investors knew inflation was high all year. What hurt on specific days was prints above consensus: the August 2022 CPI report ([BLS](https://www.bls.gov/cpi/)) published on 13 September 2022 came in hotter than forecast (core +0.6% against +0.3% expected) and the S&P 500 fell 4.3% that day, its largest one-day drop since June 2020 ([NBC News market report](https://www.nbcnews.com/business/markets/stock-market-open-to-close-september-13-rcna47504)). High inflation was priced in; the extra tenth was not, because it raised the expected path of policy rates and that raised discount rates for everything. Over calendar 2022, SPY fell about 18% and TLT about 31% on snapshot closes (price-based, adjusted): stocks and long bonds fell together, the same-direction move Day 7's duration explains.

## Worked example

`uv run python -m day11.lab` (after you implement it, or `solution` for the reference) prints the regime table. On the snapshot, with INDPRO YoY as growth, CPIAUCSL YoY as inflation, regimes since 1990 and same-month returns from 2005:

```
regime       months    SPY     TLT     GLD
deflation        74   0.97%   0.32%   1.64%
goldilocks       54   1.98%   0.93%   0.95%
reflation        65   0.65%   0.26%   0.98%
stagflation      64   0.41%  -0.20%   0.12%
```

Read it in order. Goldilocks has the best average stock month (about 2.0%) and a strong bond month. Stagflation is the weakest for everything: SPY 0.41%, TLT negative, gold nearly flat. Gold's best average is in deflation, which is surprising against the usual "gold is the inflation hedge" story and a warning about sample size and about what the label means (growth is falling; inflation is merely not rising). The regime shares over 1990-2026 are close to equal (roughly a quarter each), which is a useful check that the classifier is not degenerate.

Two honest limits. First, the table is contemporaneous: June's regime uses June's data, which was published in July, so no real investor could have known the box when the month started. A tradable version would shift the regime forward one month (Exercise 6). Second, the CPI gap: `main()` reindexes to a full calendar, so months whose three-month change touches the missing 2025-10 value (2025-10 and 2026-01) are dropped instead of mislabelled.

The current regime on the snapshot (August 2026, the latest with both series) is printed by `main()`. Treat it as the last quarter's direction, not a call on the next.

## Exercises

1. Classify by hand. Growth YoY over six months: 2, 3, 4, 4, 3, 2. Inflation YoY: 5, 4, 3, 3, 4, 5. With `lag = 3`, what is the regime in months 4, 5 and 6?
   **Hint:** compare each value with the one three positions earlier; "up" needs a strictly positive difference.
   **Solution sketch:** growth diffs are 4-2=+2 (month 4), 3-3=0 (month 5), 2-4=-2 (month 6); inflation diffs are 3-5=-2, 4-4=0, 5-3=+2. Month 4 is goldilocks (growth up, inflation not); month 5 is deflation (both flat, so both not rising); month 6 is stagflation (growth down, inflation up).

2. Use `rolling_zscore` with `window = 3` on INDPRO YoY readings 1.0, 1.4, 1.2, 2.0. What is the last z-score, and what does it say?
   **Hint:** the last window is 1.4, 1.2, 2.0; use the sample standard deviation.
   **Solution sketch:** mean 1.533, deviations -0.133, -0.333, 0.467, sample variance = (0.0178 + 0.1111 + 0.2178)/2 = 0.1733, std 0.416; z = (2.0 - 1.533)/0.416 ≈ 1.12. The latest reading is a bit over one standard deviation above its recent average: noticeable, not extreme.

3. The consensus for monthly core CPI is +0.3%, the actual is +0.5%, and past surprises have a standard deviation of 0.1. Compute `surprise_z`. If equities fall 1.2% on the day, what is the implied sensitivity per sigma, and what would you expect if the actual were +0.3%?
   **Hint:** surprise in sigma, then divide the price move by it.
   **Solution sketch:** z = (0.5 - 0.3)/0.1 = 2.0. Sensitivity ≈ -1.2% / 2 = -0.6% per sigma. At +0.3% the surprise is zero, so a first guess for the CPI-driven move is about zero: bad-looking inflation can be priced in. One day proves little; the estimate is only reliable averaged over many releases.

4. Taylor sketch: inflation 3.4%, target 2%, output gap -1%, r* = 2%. What rate does the rule suggest, and why is it unreliable to copy it as a forecast of the Fed?
   **Hint:** plug into `r* + π + 0.5(π − 2) + 0.5·gap`.
   **Solution sketch:** 2 + 3.4 + 0.7 - 0.5 = 5.6%. Weaknesses: r* is unobservable, the gap is estimated and revised, the Fed targets core PCE rather than this CPI, and it weighs forecasts and financial stability. Use it for direction (hotter data pushes the expected rate up), not level.

5. The lowest of the 3-month average unemployment rates over the previous 12 months is 3.8%. The latest three monthly readings are 4.3, 4.4 and 4.5. Does the Sahm rule fire? What if the latest three were 4.1, 4.2 and 4.1?
   **Hint:** average the latest three, then subtract the 12-month minimum of 3-month averages.
   **Solution sketch:** (4.3 + 4.4 + 4.5)/3 = 4.40, and 4.40 - 3.8 = 0.60, which is at least 0.50, so it fires. For 4.1, 4.2, 4.1 the average is 4.13 and the gap is 0.33, so it does not fire. Averaging three months and comparing with a 12-month low is what stops a one-month wiggle from triggering it.

6. Fix the look-ahead in `main()`'s table. Shift the regime series forward one month with `reg.shift(1, freq="MS")` before calling `regime_mean_returns`, and compare with the same-month table.
   **Hint:** you want last month's published regime to explain this month's returns.
   **Solution sketch:** the shifted table is the version a real investor could act on, since last month's data were published before this month's returns. On the snapshot the goldilocks SPY average falls from about 2.0% to about 1.1% a month, and stagflation turns slightly negative for stocks (about -0.2%) while gold does best there (about 1.4%): part of the same-month edge was the data and the returns being measured together. If an edge disappears when you remove the look-ahead, it was not an edge.

7. Explain why reindexing CPI to a full monthly calendar matters, using the 2025-10 gap. What would `pct_change(12)` on the raw rows do?
   **Hint:** with one row missing, "12 rows back" is 13 months back.
   **Solution sketch:** after the missing month, every raw-row `pct_change(12)` compares a month with the one 13 months earlier until the data end, so YoY figures are quietly wrong. After reindexing, the gap is NaN, only the genuinely affected months drop out, and nothing is silently misaligned.

## Anti-patterns / Common mistakes

- Trading headlines. A headline says "inflation hot" or "jobs strong"; the market reacts to actual versus expected, usually within seconds, and you are late. Read the consensus and the revision, not the adjective.
- Treating regime tables as forecasts. Four boxes, a handful of episodes each, and a label that only describes recent direction. Averages hide that the best and worst months of each regime overlap heavily.
- Ignoring revisions and release lags. Payrolls and GDP are revised; a backtest that uses today's revised numbers on yesterday's date uses information nobody had. Always ask when each point was first published.
- Reading levels as news. "Inflation at 3.4% is high" is not a trade if consensus expected 3.4%. Ask what the market expects the path of rates to be.
- Forgetting data gaps. A missing month plus a row-based `diff` or `pct_change` quietly compares the wrong dates.

## Lab

Work in `labs/day11/`. Implement `classify_regime`, `rolling_zscore`, `surprise_z` and `regime_mean_returns` in `lab.py` (README lists the `-k` expression for each), then run `uv run python -m day11.lab` from `labs/`. Inspect the printed regime table and `labs/.cache/plots/day11.png`, where background colours show the regime in each month. The lab's `main()` reindexes the monthly series first, so the output survives the 2025-10 CPI gap.

## Teardown

Nothing billable is created. The plot lives in the gitignored `labs/.cache/`.

## Journal prompt

Pick the last data release you remember moving a market (CPI, payrolls or a central-bank meeting). Write down what the consensus was, what the actual number was, and how asset prices moved. Was the move explained by the surprise, or only by the headline? What would you have needed to know in advance to have acted on it?
