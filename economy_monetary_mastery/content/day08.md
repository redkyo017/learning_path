# Day 8 — Discounting everything: DCF and equity risk premium

> Block 2: Rates & asset pricing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 7 showed a bond is a list of fixed cash flows divided down by a yield, and that duration measures how much its price moves when the yield moves. Today's idea is that a share, a building, a bitcoin-mining farm and a Vietnamese bank are the same object: a claim on future cash, priced by dividing that cash by a discount rate. The discount rate is the common factor behind almost every asset price. When the Fed moves, or inflation expectations move, every price moves, but not equally. Far-away cash flows fall most. That one fact is the main mechanism behind why Russell 1000 Growth lost about 29% in 2022 while Russell 1000 Value lost under 8%, and why bonds and stocks fell together that year (sector mix mattered too; see the worked example).

If you invest across US ETFs, Vietnamese stocks and crypto (Days 16-17 for Vietnam and currencies, Days 19-23 for crypto), you need this to answer two questions: what the price pays for, and which rate move hurts it? The lab implements present value, the Gordon growth formula, equity "duration", beta and correlation, then runs them on growth (IWF) and value (IWD) ETFs through 2022.

## Core concepts

### What a share is

A share is a residual claim: ownership of what is left of a firm's cash after creditors (Day 2's banks, Day 7's bondholders) are paid. Cash reaches the shareholder in two ways:

- Dividends: cash paid out.
- Buybacks: the firm uses cash to repurchase shares, so each remaining share owns a larger slice. This is a payout too, only taxed and timed differently.

Earnings are the accounting profit; they are not cash in your pocket, but over long periods they feed the payouts. Two ratios you will see everywhere:

```
P/E            = price / earnings per share         (years of earnings you pay for)
earnings yield = earnings per share / price = 1 / (P/E)
```

An S&P 500 forward P/E of 19 is an earnings yield of 1/19 = 5.3%. The earnings yield is the right thing to compare with a bond yield, since both are "return per dollar paid". Note that a share, unlike a bond, has no maturity and no promised payment: both the amount and the timing are uncertain, and that uncertainty is what the extra return (the equity risk premium) pays for.

### DCF in one page

Discounted cash flow (DCF) values any asset in three steps:

1. Forecast the cash flows the asset will pay to its owner: CF1, CF2, ... 
2. Pick a discount rate r: what you could earn elsewhere on something of similar risk. It is built from the risk-free rate plus a risk premium.
3. Add up each cash flow divided by (1+r) once for every year you wait:

```
PV = CF1/(1+r)  +  CF2/(1+r)^2  +  CF3/(1+r)^3  + ...
```

That is your `pv_cashflows` (the first cash flow arrives at t=1). One honest warning: in real analyst models most of the value often sits in the terminal value, the lump after the explicit forecast, so the "forecast" is mostly an assumption about the distant future.

### The Gordon growth model

If cash flows grow at a constant rate g forever, the infinite sum collapses:

```
V = next_cf / (r - g)          requires r > g
```

Example: a company paying a dividend of 5 next year, with dividends growing 3% and required return 8%, is worth 5 / 0.05 = 100. The same formula in terms of a ratio: P/CF = 1/(r-g). So a high P/E can mean r is low, g is high, or both. When r <= g the sum does not converge; the model has no answer, and your `gordon_value` must raise `ValueError`. The model is a way to think, not a precise forecaster: the answer is hypersensitive to r - g. Move r from 8% to 7% and the value above goes from 100 to 125.

### Equity duration: shares as long bonds

Differentiate the Gordon value with respect to r and divide by V:

```
percent change in V per unit change in r  ≈  -1 / (r - g)       (your equity_duration)
```

With r = 8%, g = 3% the duration is 1/0.05 = 20 years. That is longer than a 10-year Treasury and comparable with the longest bonds. Shares behave like long-duration bonds with uncertain coupons. The higher the growth rate (the nearer g is to r), the longer the duration. A growth stock earning little today and a lot in 15 years has almost all its value in distant cash flows, so its effective duration is far above a mature, high-payout "value" stock. This is why the discount rate is the price of money: whatever you buy, you are buying a stream of future dollars, and the rate decides what they weigh today.

### Equity risk premium (ERP), roughly

The ERP is the extra return investors demand for shares over risk-free bonds. A rough, current-looking version:

```
ERP ≈ earnings yield − real yield
```

A forward earnings yield of about 5.2% (P/E 19.2) minus a real Treasury yield of about 2.9% (the 10-year nominal 5.29% minus the 5-year breakeven inflation 2.36% in the snapshot; the mismatch in maturity makes this approximate) gives roughly 2.3 points. That is thin compared with the long-run averages most valuation studies quote (no long-run series is sourced here), which tells you stocks are priced for either solid earnings growth or low required returns; it does not tell you when that changes. Treat the number as a thermometer, not a signal.

### Why a rate move hits every asset

Every asset in the series (Treasuries, stocks, houses, gold less so, crypto through liquidity) has the discount rate in its denominator. A change in the risk-free rate moves r for all of them at once; a change in the risk premium moves r for the risky ones. The common factor is why diversifying across assets does less in a rate shock than the names suggest. The spread is not equal: sensitivity scales with duration. In 2022 the [10-year Treasury yield](https://fred.stlouisfed.org/series/DGS10) rose from 1.52% to 3.88%. In the snapshot, IWF (iShares Russell 1000 Growth) fell 29.3% and IWD (Russell 1000 Value) fell 7.8%; SPY fell 18.2% (adjusted closes, so total return).

### Beta and correlation

Beta is the slope of an asset's returns on the market's returns:

```
beta = cov(asset, market) / var(market)
```

Beta 1.5 means the asset moves 1.5% for a 1% market move, on average. Correlation rescales the slope into a number between -1 and 1 that ignores volatility: `corr = beta * (vol_market / vol_asset)`.

Both are estimates from a window of history, and both change with the regime (the dominant source of shocks). When growth surprises drive markets, stocks rise as yields rise: positive stock-yield correlation. When inflation or the Fed drives markets, stocks fall as yields rise, and stocks and bonds fall together. Snapshot, monthly returns of SPY vs TLT (long Treasuries): correlation about -0.5 in 2010-2019, about +0.5 in 2022, and about +0.6 over 2023 to September 2026. The "bonds hedge stocks" rule was a feature of the 2000s-2010s regime (inflation low and stable, Day 4), not a law.

### Vietnamese equities (preview of Day 16)

The same machinery applies, with a different r: VND rates, the dong's depreciation risk (Days 16-17) and a thinner, retail-dominated market with foreign-ownership limits. VN-Index valuation is often quoted as trailing P/E and is highly sensitive to a few heavyweights. Reported P/E depends on methodology and on a few heavyweights such as VIC. [BNEWS, citing VDSC](https://bnews.vn/vn-index-ve-p-e-11-9-lan-vdsc-du-bao-vung-1-638-1-999-diem/431860.html) (8 Aug 2026), puts the VN-Index at 11.9x at the 31 July 2026 close (1,735.8, matching the snapshot), against a historical mean of 14.1x and median of 14x; excluding VIC it is about 10x. Earlier, [MBS research](https://www.mbs.com.vn/?p=21813) had the index at 15.8x on 25 December 2025 (3-year average 13.6x, 2021 peak 21.0x; 13.5x excluding VIC), and ACBS about 17.3x at year-end (different methodology). No confirmed October 2026 figure exists in the sources used; unverified as of 2026-10. The snapshot closed 2026-09-30 at 1,768.6, versus a snapshot-close high of 1,927.9 on 18 May 2026. Day 16 returns to this with sector and limit-hit detail.

## Worked example

### Shock 8% to 9% on two cash-flow profiles

Two assets each pay out over 10 years. The "value" asset pays 100 a year. The "growth" asset pays nothing for nine years, then 1,000 at the end of year 10. Raise the discount rate from 8% to 9%.

```
                     PV at 8%    PV at 9%    change
  value  (100 x10)   671.01      641.77      -4.36%
  growth (1000 @10)  463.19      422.41      -8.80%
```

Run it:

```python
growth = [0.0] * 9 + [1000.0]
value = [100.0] * 10
rate_shock_pct(growth, 0.08, 0.01)   # -0.0880 = (1.08/1.09)**10 - 1
rate_shock_pct(value, 0.08, 0.01)    # -0.0436
```

Why: a single cash flow at year n is worth 1/(1+r)^n, so its percent change under a shock is (1.08/1.09)^n - 1, roughly -n x 0.9%. A flow at year 10 is hit by about 10 "units" of 0.9%; the value asset's cash is spread over years 1-10, so its PV-weighted average arrival is nearer year 5, and its hit is about half. Duration is, in effect, that PV-weighted average arrival time.

Now the same on the Gordon model: with CF = 5, r = 8%, g = 3% the value is 100 and the duration is 20. Raise r by 1 point to 9%: value = 5/0.06 = 83.3, a fall of 16.7% (the linear estimate, 20 x 1% = 20%, overstates it; convexity again, as on Day 7).

### 2022 in the lab

Run `uv run python -m day08.solution`. From the snapshots, monthly returns:

```
2010-2019:  IWF beta 1.03, corr with monthly change in 10y yield +0.39
            IWD beta 0.99, corr +0.52
2022:       IWF beta 1.10, corr -0.60
            IWD beta 0.89, corr -0.55
2022 total return: IWF -29.3%, IWD -7.8%, SPY -18.2%;  10y yield 1.52% -> 3.88%
```

In the decade after 2010 yields tended to rise with good news, so the correlation was positive for both. In 2022 the sign flipped for both; the larger fall of the growth ETF is consistent with its longer duration, but the near-identical correlations (-0.60 vs -0.55) do not isolate duration from beta (1.10 vs 0.89) or from sector mix (value held energy, which rose; growth held mega-cap tech, which lost earnings multiple). One year and 12 monthly points cannot separate these. The 2022 numbers describe one regime, not a parameter.

### Verify (as of 2026-10)

| Item | Value | Source |
|---|---|---|
| S&P 500 forward 12-month P/E | 19.2 (25 Sep 2026); 5-year average 19.8, 10-year average 19.0; about 19.0-19.5 through Sep | [FactSet Earnings Insight, 25 Sep 2026](https://advantage.factset.com/hubfs/Website/Resources%20Section/Research%20Desk/Earnings%20Insight/EarningsInsight_092526.pdf) |
| VN-Index P/E | 11.9x at 31 Jul 2026 close (mean 14.1x, median 14x; ex-VIC about 10x); 15.8x on 25 Dec 2025 (MBS; 3-year average 13.6x, 2021 peak 21.0x, ex-VIC 13.5x); no confirmed October 2026 figure | [BNEWS/VDSC, 8 Aug 2026](https://bnews.vn/vn-index-ve-p-e-11-9-lan-vdsc-du-bao-vung-1-638-1-999-diem/431860.html) (fetched); [MBS](https://www.mbs.com.vn/?p=21813) (search excerpt only; page blocks automated fetch); current value unverified as of 2026-10 |
| 10y yield, 5y breakeven (30 Sep 2026) | 5.29%, 2.36% | FRED [DGS10](https://fred.stlouisfed.org/series/DGS10), [T5YIE](https://fred.stlouisfed.org/series/T5YIE) snapshots |

## Exercises

1. Use `pv_cashflows`: a bond-like asset pays 60, 60 and 1,060 at t = 1, 2, 3. Find its PV at 5%, then at 6%, and the percent change.
   **Hint:** The last cash flow is 1,060, the coupon plus the principal.
   **Solution sketch:** At 5% the PV is about 1,027.23; at 6% about 1,000.00 (a 6% coupon bond priced at par). The change is about -2.65%, so its effective duration is about 2.7 years, a bit under its 3-year maturity because the coupons arrive early.

2. A stock pays a dividend of 3 next year, expected to grow 4% forever, with required return 9%. Value it, then show what happens to the value if r falls to 8%.
   **Hint:** `gordon_value(3, r, g)`; the model's duration is 1/(r-g).
   **Solution sketch:** 3 / 0.05 = 60 at 9%; 3 / 0.04 = 75 at 8%. A one-point drop in r lifts the value by 25%, matching the 20-year duration (1/0.05) only roughly: the linear estimate says +20% and convexity makes the true gain bigger. The sensitivity is why stock prices react so violently to small rate changes when r - g is small.

3. Show why `gordon_value(5, 0.05, 0.05)` must raise rather than return a number. What is a sensible reaction when an analyst's spreadsheet gives r just barely above g?
   **Hint:** Compute the value at r - g = 0.001.
   **Solution sketch:** At r - g = 0.001 the value is 5,000, a thousand times the next cash flow; at r = g it is infinite. Such an answer says the inputs are inconsistent (no firm outgrows the economy forever), not that the asset is priceless. Use a finite fade period then a lower terminal growth (at most the long-run growth of nominal GDP), instead.

4. Find the duration of two stocks: a mature utility with r = 7%, g = 2%, and a growth stock with r = 9%, g = 7%. If rates rise 1 point for both (r up by 0.01), estimate the percent price change for each, linear and exact Gordon.
   **Hint:** `equity_duration` for both; exact value is proportional to 1/(r-g).
   **Solution sketch:** Utility: duration 20, so the linear estimate is -20%; exact change is 0.05/0.06 - 1 = -16.7%. Growth stock: duration 50 (linear -50%); exact is 0.02/0.03 - 1 = -33.3% (the linear estimate is much too large because convexity is huge at that duration). Same rate move, double the damage, because r - g is much narrower.

5. Earnings yield vs bond yield. The S&P 500 has a forward P/E of 19.2 and the 10-year yield is 5.29%, with 5-year breakeven inflation at 2.36%. Compute the earnings yield, the rough real yield and the rough ERP. What would a P/E of 25 imply, holding the real yield?
   **Hint:** Earnings yield = 1/(P/E). Real yield = nominal − breakeven.
   **Solution sketch:** 1/19.2 = 5.21%; real yield about 5.29 − 2.36 = 2.93%; ERP about 2.3 points. At P/E 25 the earnings yield is 4.0% and the ERP about 1.1 points. It is a rough gauge because it mixes a 10-year yield with a 5-year breakeven and uses forward earnings estimates that are often too high.

6. Run `beta` and `correlation` on the lab for SPY vs TLT monthly returns in 2010-2019, 2022 and 2023 onwards (use `load_prices(["SPY","TLT"])`, resample to month-end, `pct_change`). What does the sign change imply for a 60/40 portfolio?
   **Hint:** Slice the monthly DataFrame by year range before applying the functions.
   **Solution sketch:** About -0.5, +0.5 and +0.6 by correlation. A negative correlation lets bonds offset equity losses; a positive one means both fall in an inflation or Fed-hawkish shock (2022: SPY -18%, TLT far worse). The hedge worked in the growth-shock regime and failed in the discount-rate regime.

7. VDSC put the VN-Index P/E at 11.9x on 31 July 2026, versus a historical mean of 14.1x; MBS had it at 15.8x in December 2025 against a 3-year average of 13.6x. What would a P/E-only reading say each time, and what two other things must you check before calling it expensive or cheap?
   **Hint:** What drives P/E in the Gordon model, besides the "price" itself?
   **Solution sketch:** A P/E-only reading says about 16% above average in December 2025 (15.8 vs 13.6) and about 16% below the mean in July 2026 (11.9 vs 14.1), yet the index closed near 1,784 (31 Dec 2025) and 1,736 (31 Jul 2026), almost the same level, so the P/E gap came from earnings growth, index composition and the two sources' methodology, not from price. P/E is 1/(r−g)-like, so check first the discount rate (VND rates and dong risk; if r fell, a higher P/E is justified), and second earnings growth and composition (excluding VIC it was 13.5x in December and about 10x in July). A P/E is a ratio of two uncertain things, not a value.

## Anti-patterns / Common mistakes

- "Low P/E = cheap." A low P/E can mean high required return r, low or negative growth g, or earnings that are about to fall. In Gordon terms P/E ~ 1/(r−g) scaled by payout; low P/E is equally the signature of a bad business (Exercises 2, 7).
- Ignoring that the discount rate is the price of money. A "cheap" growth stock at a 4% rate can be expensive at 5.3%; the cash flows did not change, the denominator did (Worked example, Exercise 4).
- Extrapolating one regime's correlation. The stock-bond correlation was about -0.5 in 2010-2019 and about +0.5 in 2022; building a portfolio on either number as a constant is a bet on the regime (Exercise 6).
- Using an exact-looking DCF answer. When r − g is small, small input errors become huge value errors (Exercise 3). Show a range.
- Computing beta on unaligned series or with mixed `ddof`; both give silently wrong numbers.

## Lab

From `economy_monetary_mastery/labs/`: open `day08/README.md`, implement the six functions in `day08/lab.py`, then run `uv run pytest day08` until green and `uv run python -m day08.lab` for the summary and `.cache/plots/day08.png`. Expected: all 6 tests pass; the summary shows IWF and IWD betas and their correlations with the 10-year yield change flipping sign between 2010-2019 and 2022.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: which of your holdings (a US growth ETF, a Vietnamese bank stock, bitcoin) has most of its value in cash flows or adoption far in the future? Estimate its duration, and write down how many percent you would expect it to fall if the discount rate rose one point.
