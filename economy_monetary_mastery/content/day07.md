# Day 7 — Bonds: price, yield, duration, yield curve

> Block 2: Rates & asset pricing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Every asset you own is priced by discounting future cash flows at some rate, and the government bond yield is the base rate underneath all of them. Day 5 introduced duration through Silicon Valley Bank's losses; today is the full treatment: what a bond is, why its price moves opposite to its yield, how to measure that sensitivity (duration) and its curvature (convexity), and what the shape of the yield curve says about the economy. For you as a software engineer, a bond is the cleanest financial object there is: a function from a list of dated payments and one number (the yield) to a price. If you can read that function, you can read stock valuation (Day 8, DCF), mortgage rates, bank risk and the "risk-free rate" in every Sharpe ratio. The lab builds the function and runs it on 36 years of Treasury data.

## Core concepts

### A bond is a stream of cash flows

A bond is a loan split into tradable pieces. The issuer promises fixed payments on fixed dates: a **coupon** every period, and the **face value** (par, usually 100 in this course) back at **maturity**. A US Treasury note with a 4% coupon and 10 years left pays 2.00 per 100 of face every six months for 20 periods, plus 100 at the end.

```
period k:   1     2     3    ...   19     20
cash:       2     2     2    ...    2    2 + 100
```

The **price** is the sum of those payments, each discounted back to today at the market's required yield. The **yield to maturity** (YTM) is the single discount rate that makes the sum equal the price. With `y` the annual yield, `f` payments per year and `n = years * f` periods:

```
price = sum over k=1..n of  c / (1 + y/f)^k   +   face / (1 + y/f)^n        c = face * coupon_rate / f
```

Quoting convention: Treasuries pay semiannually, so the yield is a "bond-equivalent" annual rate `y` and each period earns `y/2`. That is `freq=2` in the lab.

### Price and yield move in opposite directions

Fixed payments discounted at a higher rate are worth less. When market yields rise, existing bonds fall in price until their yield matches new issues; when yields fall, they rise. The common phrase "bond prices and yields move together" is wrong; they move opposite (see Anti-patterns).

Three rates are easy to confuse:

- **Coupon rate**: set at issue, fixed, relative to face. It never changes.
- **Yield to maturity**: today's market return if you hold to maturity and reinvest at the same yield. It changes every second.
- **Current yield**: annual coupon divided by current price. It ignores the pull to par, so it is only a rough guide.

When coupon equals yield, the bond trades at par. When the coupon is below the yield, the price is below par (a discount bond); when above, at a premium. A 3% coupon, 10-year bond at a 5% yield costs 84.41; its coupon rate is 3%, its current yield is 3.55% (3 / 84.41) and its YTM is 5%. The gap between current yield and YTM is the 15.59 of price the bond will gain by maturity.

A **zero-coupon bond** pays only the face at maturity, so it sells at a deep discount and its whole return is the accretion to par. A 10-year zero at 5% (semiannual) costs `100 / 1.025^20 = 61.03`. Treasury **STRIPS** are zeros made by separating the coupons and principal of notes; Treasury bills (up to one year) are zeros by design. Zeros are the purest interest-rate instruments, which is why the maths below is simplest on them.

### Duration: the first derivative

If you treat price as a function `P(y)`, the sensitivity is its derivative. Divide by price and flip the sign and you get **modified duration**:

```
D_mod = -(1/P) * dP/dy          =>   dP/P  ≈  -D_mod * dy
```

Read it as "percent price change per 1.00 of yield change", or more usefully, per 1 percentage point: a duration of 8 means about 8% loss per +1 point. This is a **linearisation**: the tangent line to the price/yield curve at today's yield, the same idea as a first-order Taylor expansion.

**Macaulay duration** is the same idea with a physical meaning: the PV-weighted average time at which you receive the cash. Each payment at time `t_k = k/f` is weighted by its share of the price:

```
D_mac = sum( t_k * PV_k ) / P          D_mod = D_mac / (1 + y/f)
```

Think of the cash flows as masses on a beam; Macaulay duration is where it balances. Consequences:

- A zero-coupon bond has duration equal to its maturity (all the mass sits at the end). A coupon bond's duration is always shorter than its maturity because early coupons pull the balance point left.
- Duration rises with maturity and falls with coupon and with yield. A 30-year 4% bond at a 4% yield has modified duration about 17.4; a 2-year, about 1.9.

Duration is the number to compare across bonds. A 30-year bond is risky because its duration is about nine times a 2-year note's.

### Convexity: the second derivative

The price/yield curve is not a line; it bends upward (it is convex). The tangent line sits below the curve everywhere except at the touching point. **Convexity** is the second derivative scaled by price:

```
C = (1/P) * d²P/dy²      dP/P  ≈  -D_mod * dy  +  ½ * C * dy²
```

Engineering view: duration is velocity, convexity is acceleration. For small moves the first term dominates (the lab test uses one basis point, 0.01%). For large moves the curvature matters, and it always helps the holder: for a plain bond, a fall in yield gains more than a rise of the same size loses. That asymmetry is valuable, so investors pay for convexity (longer bonds and zeros have more of it). Callable bonds and mortgage-backed securities have **negative convexity** because the borrower can refinance when rates fall, capping the upside: one reason mortgage rates and MBS behave oddly.

### The yield curve

Plot the yields of Treasuries of different maturities against maturity and you have the **yield curve**. [FRED](https://fred.stlouisfed.org/series/DGS10) publishes constant-maturity yields: `DGS3MO`, `DGS2`, `DGS10` and more.

Two ideas explain its level at each maturity:

- **Expectations**: a 10-year yield is roughly the average of expected short rates over ten years. If the market expects the Fed to cut, long yields sit below short ones.
- **Term premium**: extra yield investors demand for locking money in and bearing duration risk (inflation surprises, supply). The premium is positive on average but varies, and has even been negative for stretches.

So `10y yield ≈ average expected policy rate + term premium`. The NY Fed publishes a model-based [term premium estimate](https://www.newyorkfed.org/research/data_indicators/term-premia-tabs).

Shapes:

- **Normal (upward)**: long yields above short ones. Typical in expansions.
- **Flat**: little difference; often a late-cycle or transition shape.
- **Inverted**: short yields above long ones; markets expect lower policy rates ahead or the Fed has pushed short rates well above neutral.

Policy steers the short end (Day 3: the Fed steers the effective rate into its target range); markets set the long end. An inversion is mostly short rates being held high.

### Inversion as a recession signal, and the 2022-2024 debate

The slope (10y minus 2y, or 10y minus 3m) went negative before each US recession since the 1970s. The NY Fed's [recession probability model](https://www.newyorkfed.org/research/capital_markets/ycfaq) uses 10y minus 3m and explains the logic: tight money flattens the curve, tight money slows the economy, and a market that expects cuts pushes long yields down. Banks borrow short and lend long, so an inverted curve squeezes their margins and lending; that is a causal channel, not only a forecast.

The record has caveats:

- The signal is **coincidental in timing**: the lead from first inversion to the NBER-dated recession start has ranged from several months to over two years. It says "risk is elevated", not "sell in March".
- The sample is small: roughly eight recessions since the 1960s, and 2020 was a pandemic, not a curve story.

**2022-2024.** The 10y minus 2y spread first went negative on [FRED's T10Y2Y](https://fred.stlouisfed.org/series/T10Y2Y) on 2022-04-01 and stayed mostly inverted for over two years; in the lab's snapshot the sustained run starts on 2022-07-06 and the deepest point is -1.08 percentage points. The spread's final negative close was **2024-09-05**, and it has been positive since 2024-09-06 (checked against FRED data). Then the debate: the standard indicator fired but, per [NBER's dating table](https://www.nber.org/research/data/us-business-cycle-expansions-and-contractions) (latest peak: February 2020) and FRED's `USREC` flag (0 through 2026-09), no recession had been dated by October 2026. Explanations offered:

- **The curve was distorted** by quantitative tightening, term-premium changes and unusual inflation uncertainty.
- **Fiscal support and strong household balance sheets** (fixed-rate mortgages, excess savings) blunted the rate shock.
- **Not yet:** the lag has been long before.
- **Different regime**: policy rates were raised to fight inflation, not to cool an overheated cycle.

One false alarm, or a very long lag, does not refute the mechanism, but the signal is not a timing tool. Recessions have often begun around the **un-inversion**, when short rates fall fast in response to weakness.

### Who issues and who buys: Treasuries

The US Treasury sells bills, notes and bonds through regular [auctions](https://www.treasurydirect.gov/auctions/):

- **Bills**: 4 weeks to 52 weeks, zero-coupon, sold at a discount.
- **Notes**: 2, 3, 5, 7 and 10 years, semiannual coupons.
- **Bonds**: 20 and 30 years, semiannual coupons.
- Also TIPS (inflation-indexed, see Day 4) and floating-rate notes. See [TreasuryDirect](https://www.treasurydirect.gov/marketable-securities/).

Primary dealers must bid; others bid competitively (a yield) or non-competitively (take the result). All winners pay one price, set by the highest accepted yield. A weak auction (a "tail": the result yields more than expected) pushes yields up.

Holders: the Federal Reserve (via QE, shrinking under QT), foreign official and private investors (Treasury's [TIC data](https://ticdata.treasury.gov/resource-center/data-chart-center/tic/Documents/slt_table5.html) lists holders by country), mutual funds and money-market funds (large buyers of bills, Day 5), banks, pension funds, insurers and households. Price-insensitive buyers (central banks) and price-sensitive ones (hedge funds) react differently to supply. See Treasury's [debt overview](https://fiscaldata.treasury.gov/americas-finance-guide/national-debt/).

### Vietnamese government bonds (VGB), briefly

Vietnam's Government bonds are issued mostly via auctions on the Hanoi Stock Exchange ([HNX](https://hnx.vn/en-gb/)), by the State Treasury, in maturities from 5 to 30 years. The main holders are domestic banks, insurers and the social security fund; foreign and retail participation is small and the secondary market is much thinner than the US one. The maths is identical; liquidity is not. Current VGB yield levels: unverified as of 2026-10.

## Worked example

Price the lab's bond by hand: face 100, coupon 5%, yield 6%, 5 years, semiannual. So `c = 2.5`, `y/f = 3%`, `n = 10`.

```
discount factors 1.03^-k:   k=1 0.9709   k=2 0.9426   k=3 0.9151   k=4 0.8885   k=5 0.8626
                            k=6 0.8375   k=7 0.8131   k=8 0.7894   k=9 0.7664   k=10 0.7441
sum of 10 factors = 8.5302    coupons PV = 2.5 * 8.5302 = 21.325
principal PV = 100 * 0.7441 = 74.409                       price = 95.735
```

By code (the lab's `bond_price(100, 0.05, 0.06, 5, 2)` returns 95.7349):

```python
sum(2.5 / 1.03**k for k in range(1, 11)) + 100 / 1.03**10
```

Now the sensitivity. The solution gives Macaulay duration 4.472 years and modified duration `4.472 / 1.03 = 4.341`; convexity 22.30. For a 1 basis point (0.0001) rise in yield:

```
duration estimate:  -4.341 * 95.735 * 0.0001 = -0.04156
exact repricing:    bond_price(...,0.0601) - 95.7349 = -0.04155
```

They agree to three significant figures, which is what `test_duration_predicts_small_moves` checks. Now a big move, +3 points (to 9%): exact price 84.17; the duration estimate gives `95.735 * (1 - 4.341 * 0.03) = 83.27` (off by 0.9); adding the convexity term `½ * 22.30 * 0.03² = +0.0100` of price gives 84.23 (off by 0.05). For a fall of 1 point: exact 100.00 versus duration-only 99.89 and with convexity 99.998. That shows what convexity buys: two-term accuracy even for large moves.

From the code: `uv run python -m day07.lab` also prints the 10y 4% bond at yields 1-8% (100.00 at 4%, 92.21 at 5%, 85.12 at 6%) and the 10y minus 2y inversion runs since 1990. On the snapshot, the curve was inverted on 2023-07-31 (3m 5.55, 2y 4.88, 10y 3.97) and had a normal slope on the last day, 2026-09-30 (3m 4.20, 2y 4.88, 10y 5.29).

**Verify (as of 2026-10).** FRED's constant-maturity series on 2026-10-08, the latest available: [3m 4.23](https://fred.stlouisfed.org/series/DGS3MO), [2y 4.75](https://fred.stlouisfed.org/series/DGS2), [10y 5.22](https://fred.stlouisfed.org/series/DGS10). Shape: upward, 10y minus 2y +0.47, 10y minus 3m +0.99; the curve is not inverted. The 2022-2024 inversion ended with the final negative T10Y2Y close on 2024-09-05 (the spread was around zero for two weeks before it).

## Exercises

1. **Hand-pricing.** Price a 2-year, 4% coupon, semiannual bond at a 5% yield, then price a 10-year zero at 5%. **Hint:** four coupons of 2 plus face for the first; one cash flow for the second; per-period yield is 2.5%. **Solution sketch:** the 2y bond is 98.12 (below par because coupon < yield); the 10y zero is `100 / 1.025^20 = 61.03`. Check both with `bond_price`.

2. **Current yield vs YTM.** A 10-year, 3% coupon bond trades at 84.41 when the market yield is 5%. Compute the current yield and explain why it understates the return. **Hint:** current yield uses only the coupon. **Solution sketch:** current yield is 3 / 84.41 = 3.55%, below the 5% YTM because it ignores the 15.59 gain from discount to par over ten years; it would overstate the return for a premium bond.

3. **Duration vs reality.** A 30-year 4% bond at a 4% yield has modified duration 17.38. Estimate the price after a 1-point rise to 5% with duration alone, then compare with the exact price. **Hint:** `P * (1 - D * dy)` with `dy = 0.01`. **Solution sketch:** duration alone predicts 82.62; the exact price is 84.55. The gap of about 1.9 is the convexity term (positive, so the line understates the price) and shows why duration alone is unsafe for big moves in long bonds.

4. **Reading the slope.** Using the test's series (10y: 4.5, 4.0, 3.9, 4.4, 3.5; 2y: 4.0, 4.1, 4.1, 4.1, 3.9), compute the slope and the inversion periods by hand. **Hint:** subtract 2y from 10y per day, then mark negatives. **Solution sketch:** slope is 0.5, -0.1, -0.2, 0.3, -0.4; the inverted runs are days 2-3 and day 5, so two periods, the second with a single observation.

5. **Which spread?** On 2026-09-30 (3m 4.20, 2y 4.88, 10y 5.29) compute 10y minus 2y and 10y minus 3m, and say what shape each describes. **Hint:** simple subtraction in percentage points. **Solution sketch:** 0.41 and 1.09, both positive. The curve is upward-sloping; the 3m-to-2y piece (+0.68) is steeper than the 2y-to-10y piece, so the front end is steeper than the long end: no near-term cuts are priced.

6. **Immunisation intuition.** A pension owes 100 in exactly 5 years. You can hold a 5-year zero or a 10-year 5% coupon bond. Which one has less interest-rate risk to that liability and why? **Hint:** compare each asset's duration with 5 years. **Solution sketch:** the 5-year zero has duration exactly 5, matching the liability, so a parallel yield shift changes asset and liability values by the same percentage. The 10-year coupon bond has duration of about 8.0 years at 5% (the coupons pull it below 10 but it stays above 5), so it loses more than the liability when yields rise, though it would gain more when they fall.


## Anti-patterns / Common mistakes

- **"Bond prices and yields move together."** They move opposite. Mixing them up is the most common beginner error and it flips every P&L sign. The fix: price = present value of fixed payments, discounted at the yield.
- **Ignoring convexity for big moves.** Duration is a tangent line. For +300 bp the estimate above is off by about 1% of price; for a 30-year bond it is far worse (Exercise 3).
- **Reading inversion as a timing tool.** The lead time ranges from months to two years or more, 2022-2024 was a long inversion without a dated recession by 2026-10, and the sample is about eight recessions. Use it as a risk gauge, not a trigger.
- **Treating "risk-free" as "price-risk-free".** Treasuries have no default risk in dollars, but a 30-year bond fell sharply in 2022 (Day 5's SVB lesson). Check duration, not rating.
- **Confusing coupon, current yield and YTM.** Only YTM is comparable across bonds (Exercise 2).

## Lab

From `economy_monetary_mastery/labs/`: open `day07/README.md`, implement the six functions in `day07/lab.py` (`bond_price`, `macaulay_duration`, `modified_duration`, `convexity`, `curve_slope`, `inversion_periods`), then run `uv run pytest day07` until green and `uv run python -m day07.lab`. Expected: all 6 tests pass; the printed summary shows the 10y 4% bond at 100.00 at a 4% yield and 85.12 at 6%, modified duration 8.18, four 10y-2y inversion runs since 1990 (2000, early 2006, 2006-07, 2022-24), and four curve snapshots; the plot is saved to `.cache/plots/day07.png`.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: if your own portfolio's discount rate rose by one percentage point tomorrow, which of your holdings (cash, bonds, US stocks, VN stocks, crypto) would lose most, and what is that holding's rough duration? Do you hold anything whose payments are fixed in nominal dong or dollars? And what would you have to see in the curve for you to change a decision, rather than just feel worried?
