# Day 4 — Inflation, real rates and the Fisher equation

> Block 1: Money & banking plumbing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 3 ended on the policy rate. A rate in isolation tells you nothing, because what a saver or borrower cares about is purchasing power: how much stuff the money buys when it comes back. That is the real rate, nominal minus inflation, and it is the true price of money. Every later day leans on it: bond yields (Day 7), equity valuation (Day 8), why gold and crypto sell as "inflation hedges" (Days 18 and 24). It also corrects a habit engineers bring from software: comparing numbers that are denominated in different units. A dollar in 1980 and a dollar in 2020 are different units. Today you learn to measure inflation, convert nominal to real, and compound correctly.

## Core concepts

### Measuring inflation: CPI, PCE, core

Inflation is the rate of change of a price index. Three indices matter.

- **CPI** (consumer price index, [BLS](https://www.bls.gov/cpi/)): what urban households pay, from a fixed-ish basket. Weights come from the Consumer Expenditure Survey: housing (rent plus owners' equivalent rent) is roughly a third of the basket, then transport, food, medical care and the rest. Prices are collected monthly; the FRED series `CPIAUCSL` is the seasonally adjusted headline level.
- **PCE** (personal consumption expenditures price index, [BEA](https://www.bea.gov/data/personal-consumption-expenditures-price-index)): built from business sales data, with a broader scope (it includes spending paid by employers and government, such as health insurance) and weights that update as people switch products. Housing weighs less. The Fed targets PCE, and usually reads it a little lower than CPI.
- **Core**: either index excluding food and energy, whose prices swing on weather and geopolitics. Core is a better predictor of next year's inflation, but you eat and drive, so headline is what you actually pay.

Why an index can mislead:

- **Substitution.** If beef doubles and you switch to chicken, a fixed basket overstates your cost increase. PCE adjusts for this faster than CPI.
- **Quality.** A 2026 phone at the same price is a better phone. Statisticians try to adjust, but quality is hard to price, so measured inflation can be too high or too low.
- **Housing.** Rent and owners' equivalent rent are survey- and imputation-based and lag market rents by many months. In 2021-2022 market rents jumped long before CPI shelter did, which is part of why CPI stayed high into 2023.

### Where inflation comes from

Four drivers, which interact:

- **Demand-pull**: too much spending chasing limited goods and services.
- **Cost-push**: input costs rise (oil, wages, shipping, a supply shock) and firms pass them on.
- **Expectations**: if everyone expects 4%, wage contracts and price lists are set with 4% in them, and it happens. This is the self-fulfilling part.
- **Money and credit growth**: on Day 2 you saw that loans create deposits. Fast credit growth finances demand. Money matters through spending, not by existing.

The test case is 2010-2019 versus 2021. Between 2010 and 2019 the Fed ran QE and reserves swelled (Day 3), yet CPI stayed mostly below 2%. QE created reserves, which only banks can hold; broad money and spending grew slowly because households and firms were deleveraging and banks were not lending aggressively. In 2021 the pipe was different: governments sent cheques and enhanced benefits **directly to households** (new deposits in public hands), while supply was hit by lockdown-era shortages, shipping and then the energy shock of 2022. Demand soared against a damaged supply side. Same central-bank tool, different channel, different result.

### Fiscal vs monetary policy, and fiscal dominance

Monetary policy is the central bank moving interest rates and its balance sheet. Fiscal policy is the government's taxing and spending. They interact through the Treasury's debt: the government issues bonds, and the central bank's rates determine what that debt costs to carry. **Fiscal dominance** is when debt and deficits get so large that the central bank cannot raise rates enough to fight inflation without making the government's finances unsustainable, so in practice policy is bent to protect the Treasury. The mechanism is not "the printing press"; it is that a credible inflation fighter must be willing to let the government pay high interest, and a dominated one is not. Watch it as a risk, not a fact: the Fed's mandate is independent of the Treasury, and whether the US is near that line is exactly what bond markets argue about.

### Expectations and anchoring

What people expect shapes what happens. **Anchored** expectations means the public believes the central bank will bring inflation back to target, so a price shock does not drag wages and prices up with it. The market-implied measure is the **breakeven**: the difference between the nominal Treasury yield and the yield on an inflation-protected bond (TIPS) of the same maturity. FRED's [`T5YIE`](https://fred.stlouisfed.org/series/T5YIE) is the 5-year breakeven. Breakevens contain a risk premium and liquidity noise, so read them as an indicator, not a forecast. In the snapshot the 5-year breakeven peaked at 3.39% in April 2022 and ended September 2026 at 2.36%.

### The Fisher equation: exact vs approximate

If you lend 1 unit at nominal rate `i` and prices rise by `pi`, you get back `1 + i` units that each buy `1/(1 + pi)` as much:

```
1 + r = (1 + i) / (1 + pi)        exact
r ≈ i - pi                        approximation (fine when both are small)
```

At 5% and 3%, exact is 1.94%, approximate 2.00%. At 20% and 15%, exact is 4.35%, approximate 5.00%, and at 100% inflation and 120% interest the approximation is far off. The lab uses the exact form. The real rate is the true price of money: it is what borrowing really costs and what saving really earns. A **negative real rate** (inflation above the rate you earn) is a hidden tax on savers and a subsidy to debtors, paid without any bill. A Vietnamese saver with a one-year deposit at 5% when CPI runs at 6% earns about -0.9% in real terms, while the borrower who locked a fixed rate gains; the same savings, held as gold or property, might have kept their value. (Numbers illustrative; check the latest deposit rates at your bank.)

### Compounding, CAGR and the rule of 72

Growth multiplies: `FV = PV (1 + r)^t`. CAGR is its inverse, the constant annual rate that connects two values:

```
CAGR = (end / start)^(1/years) - 1
doubling time = ln 2 / ln(1 + r)            exact
doubling time ≈ 72 / (r in percent)         rule of 72
```

At 7%, exact doubling takes 10.24 years and the rule of 72 says 10.29. The rule is good between about 4% and 12%; at 50% it says 1.4 years while the exact answer is 1.71. Average returns and CAGR differ: +50% then -50% averages 0% but leaves you at 75 from 100, a CAGR of -13.4%. Always compare investments by CAGR over the same horizon, and in real terms: `real CAGR = (1 + nominal CAGR) / (1 + inflation CAGR) - 1`.

### Verify (as of 2026-10)

- US CPI: the [BLS release for August 2026](https://www.bls.gov/news.release/cpi.nr0.htm) shows headline CPI up 3.4% over the 12 months (not seasonally adjusted) and core CPI up 2.4%. The lab's `CPIAUCSL` snapshot gives about 3.35% YoY for August once it is reindexed to a full monthly calendar, consistent with BLS. The snapshot has no October 2025 observation (missing in the 2025 shutdown), and a row-based 12-period change across that gap would compare August 2026 with July 2025 and wrongly show 3.7%.
- US PCE: the [BEA release of 2026-09-30](https://www.bea.gov/news/2026/personal-income-and-outlays-august-2026) puts August PCE inflation at 3.4% YoY and core PCE at 3.0% YoY. Core PCE above core CPI is an unusual ordering (PCE normally reads lower); one hypothesis, untested here, is that the two indices weight housing and other components differently while those prices move.
- Fed target: 2% PCE inflation over the longer run ([Federal Reserve](https://www.federalreserve.gov/faqs/economy_14400.htm)).
- Vietnam: CPI rose 5.08% YoY in September 2026 (4.52% average over nine months, core 4.26% over nine months), per [VNA / National Statistics Office](https://en.vietnamplus.vn/vietnams-cpi-rises-452-in-first-nine-months-of-2026-post353045.vnp).
- Vietnam target: about 4.5% for 2026 under National Assembly Resolution 244/2025/QH15, reported as "around" or "below" 4.5% (the cited [VTV piece](https://english.vtv.vn/news/inflationary-risk-persists-as-vietnam-targets-cpi-below-45-in-2026-experts-2026020313491129.htm) says below). Either way, the nine-month average is at the line.

## Worked example

Question: what did holding cash at the policy rate earn after inflation? Take $100 earning the effective fed funds rate daily from January 2021 to December 2022, then January 2024 to December 2025. Fed funds is a rate the Fed steers; money-market funds and T-bills track it closely, so it is a fair proxy for "cash". Using the snapshots (DFF compounded daily; CPI is the `CPIAUCSL` index, December of the prior year to December):

| Period | Nominal | CPI over the period | Real |
|---|---|---|---|
| 2021-2022 | +1.8% (about 0.9%/yr) | +14.0% (about 6.8%/yr) | -10.7% |
| 2024-2025 | +9.8% (about 4.8%/yr) | +5.6% (about 2.8%/yr) | +4.0% |

```
 $100 of cash, Jan 2021
 start      100.00 nominal  ->  100.00 real
 end 2022   101.79 nominal  ->   89.26 real (in Jan-2021 dollars: 101.79 / 1.1404)
```

In the first window cash lost about a tenth of its purchasing power despite "earning interest": a hidden tax on savers, the very thing Fisher predicts. In the second, the same cash gained 4% real. You can see why the Fed had to hold rates above inflation to bring it down (Day 3's tool, today's measure). Run `uv run python -m day04.lab` to see the whole series: the lowest real policy rate since 1960 is about -7.7% (March 2022), the highest about +8.6% (June 1981). The latest month is near zero. Also compare with SPY: since 2005 its adjusted price grew 10.9% a year nominal, about 8.1% real after 2.6% CPI. Equities have historically been the asset that stayed ahead of inflation over decades, but not in every year.

## Exercises

1. A deposit pays 6% and CPI is 4%. Compute the exact and approximate real rates. How big is the error?
   **Hint:** Exact is `1.06 / 1.04 - 1`; approximate is `0.06 - 0.04`.
   **Solution sketch:** Exact 1.923%, approximate 2.000%, error 0.077 percentage points. Small at low inflation, which is why the approximation survives in textbooks.

2. Redo exercise 1 with a nominal rate of 80% and inflation of 60% (an episode of high inflation). What does the approximation claim and what is true?
   **Hint:** Same formulas, bigger numbers.
   **Solution sketch:** Exact `1.80 / 1.60 - 1 = 12.5%`; approximate 20%. The approximation overstates by more than half, which is why it is an anti-pattern in high-inflation countries.

3. Money doubles in 15 years. What is the CAGR? Compare with 72 / 15 and discuss.
   **Hint:** Use `2^(1/15) - 1`.
   **Solution sketch:** `2^(1/15) - 1 = 4.73%`; the rule of 72 says 4.8%. Both are close, so the shortcut is fine in this range.

4. An investment went from 100 to 150 in 4 years while prices rose from 100 to 118 over the same four years. What are the nominal, inflation and real CAGRs?
   **Hint:** CAGR twice, then the Fisher division.
   **Solution sketch:** Nominal `1.5^0.25 - 1 = 10.67%`; inflation `1.18^0.25 - 1 = 4.22%`; real `1.1067 / 1.0422 - 1 = 6.19%`. Ending real wealth is 150 / 1.18 = 127.1, which is `1.0619^4`.

5. Your friend says "my 2000 portfolio returned 8% a year in Vietnam, and my father's 1990 portfolio returned 12% in US dollars, so he did better." Name the problem and what you would compute instead.
   **Hint:** Currencies and decades have different inflation, and nominal rates are in different units.
   **Solution sketch:** Compare real returns in a common unit: deflate each by its own country's CPI (or convert to one currency and deflate), over equal horizons and with the same risk. If a 12% rate fell in a 5% inflation decade and 8% fell in a 9% one, the 8% is actually negative.

6. A fund has years of +50% and -50%. What is its average annual return and its CAGR?
   **Hint:** Multiply the growth factors, then take the square root.
   **Solution sketch:** Average 0%. Factors `1.5 * 0.5 = 0.75`, so CAGR `0.75^0.5 - 1 = -13.4%`. Arithmetic average overstates what you hold.

7. 5-year breakeven is 2.36% and the 5-year nominal Treasury yields about 5.0% (the snapshot has 4.88% at 2 years and 5.29% at 10 years). What real yield does a 5-year TIPS pay, and what does a rise in breakeven to 3% say?
   **Hint:** Breakeven is nominal minus TIPS (real) yield.
   **Solution sketch:** TIPS real yield about 2.6% (5.0 - 2.36, approximate). A breakeven of 3% means the market prices 3% average inflation (plus premium); if actual inflation beats it, TIPS beat nominals.

## Anti-patterns / Common mistakes

- Comparing nominal returns across decades. A 10% year in 1980 and a 10% year in 2015 are different things; deflate first (Exercise 5).
- Using the approximate Fisher equation at high inflation. Subtraction is only a small-number shortcut (Exercise 2).
- "Printing money always causes inflation." QE in 2010-2019 created reserves that did not reach spending; 2021 combined direct transfers with a supply shock. The channel matters.
- Using row-based `pct_change(12)` across a gap in the data. The snapshot has no October 2025 CPI row, so 12 rows back lands 13 months back after the gap; reindex to a full monthly calendar first.
- Averaging returns instead of compounding them (Exercise 6).
- Treating breakevens as a pure forecast. They contain risk and liquidity premia.
- Reading one index as "the" inflation. CPI, PCE, core and local CPI (Vietnam) answer different questions; say which.

## Lab

From `economy_monetary_mastery/labs/`: open `day04/README.md`, implement the six functions in `day04/lab.py` (`yoy_inflation`, `real_rate`, `compound`, `cagr`, `real_cagr`, `years_to_double`), then run `uv run pytest day04` until green and `uv run python -m day04.lab` for the summary and `.cache/plots/day04.png`. Expected: all 6 tests pass; the printed summary shows a real policy rate near -7.7% in March 2022, +8.6% in June 1981, and SPY's real CAGR near 8%.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: what did your own savings earn in real terms last year, in the currency you hold them in? Which of the four drivers of inflation matters most for Vietnam right now? And where in your own thinking have you been comparing nominal numbers?
