# Day 12 — Block 2 integration: Fed-meeting simulation, quiz

> Block 2: Rates & asset pricing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Block 2 gave you five lenses on one object, the price of an asset. A bond price is a stream of cash flows discounted at a rate (Day 7). A share is a longer, riskier stream discounted at that rate plus a premium (Day 8). Trades happen in an order book with a spread and a settlement lag (Day 9). A portfolio is judged by return per unit of risk, and diversification is what makes it cheap (Day 10). And markets move on news relative to what was already expected, within a business-cycle backdrop (Day 11). An FOMC meeting is the one scheduled event where all five fire at once: the rate path changes the discount rate, bonds reprice first, equities follow through their duration, spreads widen into the announcement, correlations shift, and the whole move is the surprise, not the decision. Today you build the meter that turns a futures price into "what was expected", walk a real meeting through it, and take the checkpoint quiz.

## Core concepts

### Recap map: Days 7 to 11

```
 policy rate path (Day 3/6)
      |  sets the discount rate
      v
 bond price = PV of coupons, duration says how much it moves   (Day 7)
      |  same arithmetic, longer and riskier cash flows
      v
 share price = PV of earnings, discounted at rate + ERP         (Day 8)
      |  you buy it through a book, pay spread, settle T+1/T+2  (Day 9)
      v
 portfolio: return, volatility, correlation, Sharpe              (Day 10)
      |  all of it conditional on the regime and on surprises   (Day 11)
      v
 Day 12: one event, FOMC day, where every layer moves together
```

One sentence per day. Day 7: price falls when yield rises, duration measures how fast. Day 8: value is discounted cash flow, and long-duration cash flows suffer most from a rate rise. Day 9: the price you get is what your order walks into. Day 10: diversification across imperfectly correlated assets is the free lunch. Day 11: regimes group growth and inflation, and prices move on actual minus expected.

### How an FOMC meeting works

The Federal Open Market Committee (12 voters) meets eight times a year ([2026 calendar](https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm)): 27-28 January, 17-18 March, 28-29 April, 16-17 June, 28-29 July, 15-16 September, 27-28 October and 8-9 December. As of 2026-10 two meetings remain, 27-28 October and 8-9 December. March, June, September and December also publish the Summary of Economic Projections.

- **Statement (2:00 pm ET on day two).** The target range, the vote and any dissents, a few sentences on the economy and the balance of risks.
- **Dot plot (SEP meetings only).** Each participant's anonymous projection of the policy rate at the end of each year. The *median* dot is the headline. It is a set of individual forecasts, not a commitment.
- **Press conference (2:30 pm).** The chair explains and answers questions. Because it adds tone to the statement, the market often trades twice: once on the 2:00 pm text and again on the chair's words.
- **Minutes (three weeks later).** A detailed record of the discussion; they reveal how close a decision was and what was floated.

Remember Day 3: the Fed steers the effective rate into the target range with IORB and ON RRP, it does not set the market rate directly. The September 2026 decision shows it: the target range became 3.75 to 4.00 on 16 September 2026 with IORB at 3.90 ([Fed implementation note](https://www.federalreserve.gov/newsevents/pressreleases/monetary20260916a1.htm)), and in the snapshot the effective rate (`DFF`) moved from 3.63 to 3.88 the next day.

### Reading what the market expects: the futures idea

Fed funds futures settle on the *average* effective fed funds rate over their month, quoted as `100 - rate`. A price of 95.75 therefore says "the market expects the month to average 4.25". The CME's FedWatch tool is this computation, dressed up; the lab does it in five lines.

Two wrinkles, both in the lab:

- **The average mixes before and after.** If the meeting is on day 16 of a 30-day month, 15 days are at the old rate. To get the rate expected *after* the meeting you strip out the old-rate days: `new = (avg * D - current * (day - 1)) / (D - day + 1)`. If the meeting is near the month's end there are few new-rate days, and one basis point of price noise becomes many basis points of implied rate (Exercise 4).
- **Probability of a step.** With 25 bp steps, `(implied - current) / 0.25` is the expected number of steps. 4.50 current and 4.3125 implied is -0.75: 75% odds of one cut (a simplification: it treats the market as pricing only 0 or 1 step).

Then the key move, from Day 11: **surprise = actual - expected**. If the Fed cuts 25 bp when a 75% chance of a cut was priced, the surprise is `-25 - (-0.75 * 25) = -6.25` bp, mildly dovish. If it holds, it is `0 + 18.75 = +18.75` bp: a *hawkish hold*, even though nothing "moved". Multiply by an asset's sensitivity (percent move per bp of surprise) and you get a first-order expected reaction. Real reactions also include the *path*: the dot plot and the chair's words reprice meetings months ahead, which this one-meeting meter cannot see. That gap is the whole story of the worked example.

### Why the same shock moves different assets differently

- **Front-end yields (2-year)** track the expected policy path over the next two years, so they react most to anything that changes the next few meetings.
- **Long yields (10-year)** are that path averaged over ten years plus a term premium: they react to the path, to inflation worries and to supply. A "higher for longer" message lifts the 2-year more; a message that the neutral rate is higher lifts the 10-year too.
- **Equities** respond through the discount rate (Day 8) and growth expectations; long-duration growth shares fall most when yields jump.
- **The dollar** rises when US rates are expected to stay higher relative to other countries. Bitcoin tends to trade like a long-duration equity on these days, an observed tendency, not a law.
- **Spreads and depth (Day 9)** widen into the 2:00 pm print: market makers pull quotes, so the cost of trading the minute of the announcement is much higher than usual.
- **Correlations (Day 10)** jump: stocks and bonds that normally diversify can fall together when the shock is about rates (2022 is the pattern).

## Worked example

The FOMC meeting of **18 December 2024**, a real "hawkish cut". All market levels below are from the course snapshot (FRED `DGS2`, `DGS10`, Yahoo SPY adjusted close and `DX-Y.NYB`); SPY is the ETF, not the index.

**Decision.** The Committee [lowered the target range by 25 bp to 4.25 to 4.50 percent](https://www.federalreserve.gov/newsevents/pressreleases/monetary20241218a.htm), the third consecutive cut, by 11 votes to 1: Beth Hammack dissented, preferring to hold at 4.50 to 4.75. The cut was widely expected ([CNBC coverage](https://www.cnbc.com/2024/12/18/fed-rate-decision-december-2024-.html); the exact FedWatch probability on the eve is unverified as of 2026-10, no archived figure in the sources used). Run it through the lab meter: if the market priced an illustrative 95 percent chance of the 25 bp cut, the surprise on the decision alone is `-25 - (-0.95 * 25) = -1.25` bp, essentially nothing.

**The news was in the dots.** The [December projections](https://www.federalreserve.gov/monetarypolicy/fomcprojtabl20241218.htm) put the median year-end 2025 rate at 3.9 percent, against 3.4 percent in September: from four cuts in 2025 to two. The 2026 median rose from 2.9 to 3.4 and the longer-run median from 2.9 to 3.0. A cut that was priced in came with a path repricing of about 50 bp in a year.

**The tape (snapshot, daily closes):**

```
 date        2y     10y    10y-2y   SPY close   DXY
 2024-12-17  4.25   4.40   0.15     590.66      106.96
 2024-12-18  4.35   4.50   0.15     573.06      108.03
 2024-12-19  4.32   4.57   0.25     572.88      108.41
 2024-12-20  4.30   4.52   0.22     579.76      107.62
```

- **Decision day (18 Dec).** 2y +10 bp, 10y +10 bp, SPY -2.98 percent, DXY +1.00 percent. The equity drop was the biggest daily fall of the month in the snapshot; the dollar surged, as a higher US rate path would suggest.
- **Next day (19 Dec).** 2y -3 bp but 10y +7 bp, so the 10y-2y spread went from 15 to 25 bp (steepening); SPY -0.03 percent (flat), DXY +0.35 percent. The effective fed funds rate stepped down from 4.58 to 4.33 in the snapshot, the mechanical result of the decision.
- **Two days.** 2y +7 bp, 10y +17 bp.

What to take away: the decision (-25 bp) was fully priced, the market moved anyway, and it moved on the *path*. Both ends rose 10 bp on the day; over the next day the long end kept rising while the 2y gave some back, as the "fewer cuts, sticky inflation" message sank in.

**The simulation.** `uv run python -m day12.lab` runs three hypothetical meetings through the meter (a priced-in cut, a hawkish hold, a dovish surprise) and prints a "meeting-day tape". The lab gets the one-meeting surprise right and misses the path, which is why a real desk watches both.

## Exercises

1. Run the lab on the "Hawkish hold" scenario by hand: futures price 95.59, current rate 4.50, meeting on day 16 of 30, the Fed holds. Find the implied post-meeting rate, the cut probability, the surprise and the expected SPY and TLT moves with sensitivities -0.10 and -0.25 percent per bp.
   **Hint:** Month average = 100 - price; 15 days precede the meeting.
   **Solution sketch:** Average 4.41; post-meeting rate = (4.41 x 30 - 4.50 x 15) / 15 = 4.32; probability = (4.32 - 4.50) / 0.25 = -0.72, i.e. 72% cut odds; surprise = 0 - (-0.72 x 25) = +18 bp; SPY = 18 x -0.10 = -1.8%, TLT = 18 x -0.25 = -4.5%. A hold is hawkish when a cut was priced.

2. Explain a "hawkish cut" using 18 December 2024. Why can the Fed cut and stocks fall 3%? What does the lab's one-meeting surprise miss?
   **Hint:** Compare the surprise on the decision with the change in the median 2025 dot.
   **Solution sketch:** The cut itself was priced (surprise about zero), but the 2025 median moved from 3.4 to 3.9 and the 2026 median from 2.9 to 3.4: fewer cuts ahead means a higher discount rate over the next years, and long-duration equities fall (Day 8). The lab prices one meeting; the market prices the whole path.

3. Predict the 2y versus 10y reaction if the dot plot median for next year rises 50 bp with no change to the longer-run median. Then compare with 18-19 December 2024.
   **Hint:** The 2-year covers the next eight or so meetings; the 10-year averages across a decade and adds a term premium.
   **Solution sketch:** The 2y should rise by the most, because the shift sits entirely inside its horizon, and the curve flattens (or inverts further). If instead the longer-run dot also rises, the 10y moves with it. In Dec 2024 both rose 10 bp on the day (so no flattening), and the 10y added 7 bp more next day while the 2y gave back 3, a steepening. Reality is messier than the rule because inflation fears and Treasury supply also feed the long end.

4. A meeting falls on the 29th of a 30-day month. How many days at the new rate does the month average contain, and what does a 1 bp error in the futures price do to the implied post-meeting rate?
   **Hint:** New-rate days = D - day + 1; the error is divided by the share of the month after the meeting.
   **Solution sketch:** 2 days (the 29th and 30th). Implied rate = (avg x 30 - current x 28) / 2, so a 1 bp error in avg becomes 15 bp in the implied rate and swings the "probability" by 0.6. Use the *next* month's contract for end-of-month meetings, which is what real tools do.

## Checkpoint quiz

Answer without looking back first, then check the key. Fifteen questions across Days 7 to 11 (plus today's meter).

1. (Day 7) A bond has modified duration 7. Yields rise by 50 bp. Estimate the percentage price change.
2. (Day 7) You use duration alone to estimate a big yield move in both directions. Which way is the estimate biased, and why?
3. (Day 7) What does it mean for the 10-year minus 2-year spread to invert, and what does the 2022-2024 episode warn about using it?
4. (Day 8) A share pays 2 next year, the discount rate is 8 percent and growth is 3 percent forever. Value it with the Gordon model.
5. (Day 8) Raise the discount rate to 9 percent in question 4. What is the percentage change, and what is the lesson?
6. (Day 8) Why do long-duration growth shares fall more than value shares when rates jump?
7. (Day 9) A market buy of 10 meets asks 100.00 x 6 and 100.10 x 8. What is the average fill?
8. (Day 9) You sell US shares and Vietnamese shares on Thursday, no holidays. When does cash arrive in each?
9. (Day 9) An ETF trades at a premium to NAV. Who acts, and what do they do?
10. (Day 10) Two assets each have 20 percent volatility and zero correlation. What is the volatility of a 50/50 portfolio?
11. (Day 10) A strategy returns 8 percent with 12 percent volatility; the risk-free rate is 2 percent. Sharpe ratio?
12. (Day 10) Why is a minimum-variance portfolio more robust than a maximum-Sharpe one?
13. (Day 11) Expected payrolls change is 0.2 million with a surprise standard deviation of 0.1 million; the actual is 0.3 million. What is the surprise z-score, and why does it matter more than the 0.3?
14. (Day 11) In a growth/inflation regime scheme, what regime is "growth falling, inflation rising"?
15. (Day 12) Current rate 4.50, implied post-meeting 4.3125, the Fed cuts 25 bp. What are the cut odds priced, and the surprise?

## Answer key

1. About -3.5 percent (-duration x change in yield = -7 x 0.005). It is a first-order estimate.
2. It understates the price gain when yields fall and overstates the loss when they rise, because price is convex in yield (Day 7's second derivative). The actual price is higher than the linear estimate either way.
3. Short rates above long rates: the market expects falling short rates or recession. The 2022-2024 inversion lasted far longer than usual before any recession, so it is a warning with a long and variable lag, not a timer.
4. 2 / (0.08 - 0.03) = 40.
5. 2 / (0.09 - 0.03) = 33.33, a 16.7 percent fall for a 1-point rise in the discount rate. The denominator is r - g, so small changes in r matter a lot when r - g is small.
6. More of their value sits in distant cash flows, so they have longer equity duration and a larger present-value loss per rate increase (Day 8 treated shares as long bonds).
7. (6 x 100.00 + 4 x 100.10) / 10 = 100.04.
8. US T+1: Friday. Vietnam T+2: Monday (the following business day after Friday).
9. An authorized participant: buys the underlying basket, delivers it to the issuer, receives new ETF shares and sells them at the higher price, which pushes the premium down.
10. 20 x sqrt(0.5^2 + 0.5^2) = 14.1 percent. Zero correlation cuts risk with no loss of average return.
11. (8 - 2) / 12 = 0.5.
12. Mean returns are estimated with large error while variances and covariances are far better estimated; a max-Sharpe optimizer amplifies the noisy means, a minimum-variance one ignores them.
13. z = (0.3 - 0.2) / 0.1 = 1.0, one standard deviation above consensus. Prices move on actual minus expected, so a 0.3 that was expected to be 0.3 moves nothing.
14. Stagflation.
15. 75 percent odds of a cut ((4.3125 - 4.50) / 0.25 = -0.75); surprise = -25 - (-0.75 x 25) = -6.25 bp, mildly dovish.

## Anti-patterns / Common mistakes

- **Treating the decision as the news.** A priced-in cut is not an event (Exercise 2); the path is.
- **Trading the first minute.** Spreads are wide and the 2:00 pm move can reverse during the 2:30 pm press conference.
- **Reading the dot plot as a promise.** It is a median of individual forecasts, revised at each SEP meeting.
- **Using a futures price from a month-end meeting.** The adjustment divides noise by a tiny denominator (Exercise 4).
- **Assuming one sensitivity forever.** Reactions to rate news change across regimes (Day 11).
- **Calling the effective rate "set" by the Fed.** It steers it with IORB and ON RRP (Day 3).

## Lab

From `economy_monetary_mastery/labs/`: open `day12/README.md`, implement `implied_rate`, `meeting_adjusted_implied`, `move_probability`, `surprise_bp` and `asset_reaction_pct` in `day12/lab.py`, then run `uv run pytest day12` until green and `uv run python -m day12.lab` for the meeting-day tape and `.cache/plots/day12.png`. Expected: all 6 tests pass; the printed table shows a priced-in cut with a surprise under 1 bp, a hawkish hold at about +18 bp and a dovish surprise at about -31 bp. The scenarios and sensitivities are hypothetical.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

Write three dated claims about the next FOMC decision (27-28 October 2026, [calendar](https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm)) with a probability for each, such as: the target range after the meeting; whether there is a dissent; whether the 2-year yield rises that day. Before looking at market pricing, write your own number, then compute the market's with the lab meter and note where you disagree. After the meeting, score yourself. Resolve any due entries and add a row to the Calibration review table in `journal.md`.
