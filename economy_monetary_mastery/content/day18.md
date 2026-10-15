# Day 18 — Block 3 integration: cross-currency drill and quiz

> Block 3: FX, the dollar & Vietnam. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Days 13 to 17 built five tools: how a currency is quoted and what a forward is, why the dollar sits at the centre of the system, which exchange-rate regimes exist and how they break, how Vietnam runs its own version, and how a return changes when it crosses a border. Today they meet in one table. A scorecard puts SPY, a Vietnamese ETF, the VN-Index, gold and bitcoin side by side, all in a common currency, over a common period, with the same four numbers each. 

**Scope note, as in Day 17.** The "in VND" rows are cross-currency arithmetic: what a holder of dong would have seen if the position had been held. Under [Decree 135/2015](https://conventuslaw.com/report/3-things-about-overseas-securities-investment-by/), resident Vietnamese individuals have no general legal channel to own foreign securities, so the table says nothing about what an individual may do. It is a measurement exercise.

## Core concepts

### Recap map: from quotes to cross-currency returns

```
Day 13  quotes + CIP/UIP      price of a currency; the forward = arithmetic, not a forecast
   |
Day 14  dollar system         why most prices, debts and reserves are in USD; strong-dollar stress for EM
   |
Day 15  regimes + trinity     float / band / peg; fixed rate + open capital + own policy: pick two
   |
Day 16  Vietnam               SBV tools, +-5% band, capital flows, exchanges, FOL, FTSE status
   |
Day 17  cross-currency return (1 + a)(1 + f) - 1; hedge locks the home rate; costs compound
   |
Day 18  scorecard             all of it, on one table
```

- **A quote is quote-per-base.** USD/VND 25,969 means 1 USD costs 25,969 VND. Prices convert by multiplying, never by adding returns.
- **The forward is priced by interest rates.** `F = S(1 + r_quote t)/(1 + r_base t)`. With VND at 5.9% and USD at 4.5% the one-year forward is about 26,317, which is VND weaker by 1.34%. That is arithmetic. As a forecast it is weak: realized one-year changes since 2015 ran from -3.7% to +9.8%, averaging +1.78%, so the dong roughly follows UIP on average with large dispersion.
- **The dollar is the funding and safe-asset currency.** Its share of allocated reserves was 57.13% in 2026Q1 ([IMF COFER](https://data.imf.org/en/news/imf%20data%20brief%20july%201)). In panics it rises, and EM borrowers with dollar debt suffer.
- **Vietnam sits between corners.** A managed crawl with a ±5% band ([The Investor](https://theinvestor.vn/central-bank-expands-dollar-trading-band-to-5-d2174.html)), partial capital controls and partly independent policy. The refinancing rate was cut to 4.50% in June 2023 ([VnEconomy](https://en.vneconomy.vn/sbv-cuts-regulatory-interest-rates-by-0-5.htm)) and was reported unchanged in the first half of 2026 (secondary; unverified beyond that as of 2026-10). Deposit insurance covers VND 350 million per person per institution since 13 July 2026 ([Bao Nghe An](https://baonghean.vn/en/chinh-thuc-nang-han-muc-bao-hiem-tien-gui-len-350-trieu-dong-10344498.html)). FTSE Russell's upgrade to secondary emerging is in force from 21 September 2026 ([LSEG](https://www.lseg.com/en/media-centre/press-releases/ftse-russell/2025/ftse-russell-country-classification-september-2025)).
- **Your return is asset times currency.** SPY compounded at 14.08% in USD and 16.54% in VND from 2010: the dong's slide of about 2.2% a year added the difference.

### The four scorecard numbers

For a price series `p` with simple returns `r`:

```
CAGR   = (p_end / p_start) ^ (1 / years) - 1          growth rate; how fast the money compounded
vol    = std(r) * sqrt(252)                           how bumpy: annualized standard deviation
Sharpe = mean(r) / std(r) * sqrt(252)                 return per unit of vol, risk-free rate set to 0
maxDD  = min(p / running_max(p) - 1)                  worst peak-to-trough loss
```

CAGR says what you got, vol how bumpy it was, Sharpe how efficiently, the drawdown what the worst point cost. A table with all four shows that bitcoin's CAGR came with a loss of more than four-fifths from a peak.

Two conventions to state out loud. First, the risk-free rate is zero here, which is a simplification: a Sharpe against a 5.9% VND deposit rate would be lower for every row. Second, on a common-date panel each return spans the gap between shared dates (weekends included), so the right annualization factor is observations per year, about 242 here (2,838 dates over 11.7 years); 252 is therefore defensible and inflates every row's vol by about 2% equally. The BTC panel vol (0.679) is slightly higher than its native 365-day figure (0.668), which applies only to BTC's own 7-day series.

### Putting different currencies on one footing

Everything must be in one unit before comparison. The scorecard converts the USD-quoted assets (SPY, VNM, GLD, BTC-USD) by multiplying each price by USD/VND on the same date, carrying the last rate forward over FX holidays. The VN-Index is already in dong but is measured in index points, a price index without dividends, so its CAGR is understated against total-return series by about the dividend yield. SPY appears twice, in USD and in VND; the difference is the currency leg.

## Worked example

`uv run python -m day18.solution` on the frozen snapshot (Yahoo closes through 2026-09-29, Vietcap for the VN-Index), common dates from 2015-01-05 to 2026-09-29, 2,838 rows:

```
                   cagr   vol  sharpe  max_drawdown
BTC-USD (VND)     0.658 0.679   1.117        -0.824
SPY (VND)         0.159 0.193   0.896        -0.337
SPY (USD)         0.139 0.178   0.850        -0.337
GLD (VND)         0.127 0.177   0.794        -0.259
VN-Index (points) 0.106 0.187   0.656        -0.453
VNM (VND)         0.025 0.249   0.228        -0.507
```

Reading it row by row.

- **Currency leg.** SPY in VND beats SPY in USD by 2.0 points of CAGR (15.9% against 13.9%), roughly the dong's depreciation since 2015. The drawdown is the same, -33.7%, because the worst stretch is the March 2020 crash, when USD/VND barely moved. Vol is slightly higher in VND (19.3% against 17.8%): the dong added a little variation, not much, which fits a managed currency.
- **VN-Index against SPY in VND.** 10.6% against 15.9%, with a 45% drawdown against 34%. The VN-Index figure excludes dividends, so the gap is overstated by the yield; the regimes differ too, since the VN-Index fell hard in 2022.
- **VNM.** A USD-listed ETF on Vietnam, restated in VND, compounded at 2.5%. Its gap to the VN-Index is not a currency effect (the dong depreciated, which helps it); it comes from fees, the portfolio's composition and foreign-ownership limits that cap what a foreign-listed fund can hold (Day 16).
- **Gold.** 12.7% in VND with the shallowest drawdown (-25.9%) and the lowest vol (17.7%).
- **Bitcoin.** Highest Sharpe at 1.12, highest CAGR at 65.8%, and an 82% drawdown. The Sharpe is a single path of a young asset.

### What the scorecard does not tell you

- **The period decides the order.** Computed outside `main()` by setting `START` (see README Explore): from 2020-01-01 gold moves to first on Sharpe (0.98), ahead of bitcoin (0.97); from 2022-01-01 (same method) gold leads at 1.16, with SPY in VND second (0.90) and bitcoin down to 0.57. A ranking is a statement about one window, not about the assets.
- **Survivorship of the chosen assets.** The names are SPY, gold and bitcoin because they are famous today. The scorecard does not include the assets that were also on the shelf in 2015 and are now small or gone. Picking winners after the fact makes any asset class look like a good idea.
- **One path, no confidence interval.** A Sharpe of 0.90 against 0.85 is noise on one 11-year path (Day 10). Costs, taxes and limit-locked days are also absent.
- **The currency leg is a regime, not a constant.** The 2-point gift in SPY in VND exists because VND depreciated. It would be a loss in a revaluation, and the SBV's reaction function, not a market equilibrium, sets it (Day 16).

For `hedge_decision` with a VND holder of USD assets, both inputs are negative: the "cost" is negative (the hedge pays about 1.3%) and the expected USD "depreciation" is negative (the USD is expected to rise), so the rule says stay unhedged on expected value; hedging remains a variance decision (Day 17).

## Exercises

1. A VND investor holds a position worth the equivalent of SPY. Over a year SPY gains 10% in USD and USD/VND rises 5%, from 25,969 to about 27,267 (the dong weakens). Compare unhedged and hedged returns, using VND 5.9% and USD 4.5% for the hedge. Then repeat with the dong strengthening 5%.
   **Hint:** `home_return` for unhedged, `hedged_return` for hedged; the FX move is the USD's change in VND terms.
   **Solution sketch:** Dong weakens: unhedged (1.10)(1.05) - 1 = 15.5%; hedged 1.10 x 1.059 / 1.045 - 1 = 11.5%, so the hedge gave up about 4 points because the dong fell. Dong strengthens 5%: unhedged 1.10 x 0.95 - 1 = 4.5%; hedged is still 11.5%, so the hedge was worth about 7 points. The hedge swaps the currency outcome for the interest differential (+1.3% for VND against USD); it is a variance decision, as in Day 17.

2. Explain why USD/VND rarely leaves its band, and name what would make it leave.
   **Hint:** The band is a rule the SBV defends, not a market equilibrium; think of Day 15's trinity and Day 16's reserves.
   **Solution sketch:** The SBV sets the central rate daily and sells dollars (or tightens dong liquidity) when the market presses on the ceiling, with the ±5% limit on bank dealing doing the rest. A series that stays inside the band says the SBV defended it. What would break it: reserves too thin to keep selling (import cover was reported near 2.1 months in 2025, secondary, versus a three-month rule of thumb); a sustained reversal of the inflows that supply dollars (FDI, remittances, the trade surplus); a left-side dollar-smile episode with a global panic; a gold rush that spends the same dollars; or a loss of confidence in the dong.

3. A news item reads: "SBV raises refinancing rate 50 bp" (4.50% to 5.00%). Predict the direction of the effect on VND, the VN-Index and deposit rates, with reasoning.
   **Hint:** Use Day 16's tools (policy rate, OMO, the band, quotas) and Day 13's CIP logic. Ask first which rate is operative at the margin.
   **Solution sketch:** VND: the dong rate (5.9%) is already above the USD rate (4.5%), so a hike widens the gap and makes dong deposits more attractive, supporting spot VND. By CIP the forward discount on VND widens too (USD/VND forward points rise, so selling USD forward pays more than 1.3%). The size is small: the band and capital controls mean the SBV sets the path, so expect a signal more than a re-pricing. The refinancing rate is a collateralised standing facility rarely used at the margin; the operative rates are OMO and interbank rates, which the SBV steers alongside it. VN-Index: a higher rate raises discount rates and borrowing costs for a retail- and margin-driven market (Day 8: equity value falls as r rises; Day 16), so the direction is negative for equities, with banks ambiguous (funding cost up, loan growth possibly capped by credit room). Deposit rates: 12-month deposit rates (about 5.9% at the counter) already sit above the 4.50% refinancing rate, so it is not the binding constraint and the move works mainly as a signal for OMO and interbank rates; deposit rates rise modestly and with a lag, and the amount is less than the full 50 bp. Magnitudes depend on liquidity, credit quotas and inflation, not on the headline.

4. Why can a scorecard that ranks gold first from 2022 and bitcoin first from 2015 not settle which to hold?
   **Hint:** Two windows, two answers (set `START` in `lab.py` to 2020 or 2022 and re-run).
   **Solution sketch:** Each ranking is one path on a chosen window. A Sharpe difference of a few tenths over a few years is not statistically distinguishable, and the picked assets were chosen with hindsight. The useful question is what each asset did in different regimes (inflation shock, USD rally, panic), not who won.

## Checkpoint quiz

Answer without looking back first, then check the key. Fifteen questions across Days 13 to 17.

1. (Day 13) USD/VND spot is 25,000; one-year VND rate 6%, USD rate 4%. What is the one-year forward by covered interest parity?
2. (Day 13) A dealer quotes that forward at 25,600. What is the CIP deviation in basis points, and what trade follows?
3. (Day 13) Does the forward predict the future spot? Say what the snapshot's history of USD/VND one-year changes shows.
4. (Day 13) A carry trade earns a 1% rate gap and the investment currency falls 5%. Approximate result, and what name does the risk pattern carry?
5. (Day 14) Name three reasons the dollar is the world's reserve currency, with the 2026Q1 reserve share.
6. (Day 14) What is the dollar smile, and why does a strong dollar hurt emerging-market borrowers?
7. (Day 14) You study the dollar around seven FOMC dates. Name two event-study pitfalls.
8. (Day 15) State the impossible trinity and say which corner Hong Kong gives up.
9. (Day 15) You expect a 20% depreciation and the foreign rate is 5%. What domestic rate makes holding the currency fair under UIP, and why not 25%?
10. (Day 15) Why is "three months of import cover" an insufficient reserve test?
11. (Day 16) The central rate is 25,000 and the band is ±5%. What is the allowed range, and is 26,100 inside it?
12. (Day 16) A HOSE stock has a reference price of 25,000 VND. What are today's limits, and why is a close at the floor not a tradable price?
13. (Day 16/17) What is the FTSE Russell status change and its date, and can a resident Vietnamese individual freely buy US ETFs?
14. (Day 17) SPY gains 10% in USD and USD/VND rises 5%. What is the VND return unhedged, and roughly what hedged (VND 5.9%, USD 4.5%)?
15. (Day 17/18) Round trip with 20 bp fee and 50 bp FX spread each way: net return on a +10% gross? And why does SPY in VND beat SPY in USD in the scorecard?

## Answer key

1. F = 25,000 x 1.06 / 1.04 = about 25,481. VND, the higher-rate currency, trades at a forward discount (USD/VND is higher forward).
2. 25,600 / 25,481 - 1 = about +47 bp. The quote is above fair: sell USD forward at 25,600, buy USD spot with borrowed funds and lock the gap; trading pushes the quote back to fair.
3. No. The forward is a price for locking a rate. In the snapshot, one-year USD/VND changes since 2015 averaged +1.78% against a forward premium of 1.34%, but ranged from -3.7% to +9.8%: roughly UIP on average, large dispersion.
4. About -4% (the 1% gap minus the 5% fall). The pattern is "picking up nickels in front of a steamroller": small steady income, rare large losses, negative skew (August 2024, [BIS](https://www.bis.org/publications/bulletin-90-market-turbulence-and-carry-trade-unwind-august-2024.pdf)).
5. Invoicing in dollars, dollar debt, reserves held in dollars, and the depth of the Treasury market. The dollar was 57.13% of allocated reserves in 2026Q1.
6. The dollar rises in global panic and when the US outperforms, and is weaker in calm global growth. EM borrowers owe dollars and earn local currency, so a rising dollar raises both debt burden and funding cost.
7. Overlapping windows, look-ahead in choosing dates, cherry-picking, few events (wide error bar), and timing within the day (the Fed's broad index uses noon rates, so the reaction shows on day +1).
8. A country cannot have a fixed exchange rate, free capital flows and an independent monetary policy at once. Hong Kong keeps the fixed rate and open capital and gives up independent policy.
9. (1.05)(1.20) - 1 = 26%. Not 25%, because the rate and the expected move compound.
10. Runs come from short-term capital, not trade. The Greenspan-Guidotti rule (reserves at least equal short-term external debt) is the more important test in a crisis.
11. 23,750 to 26,250; 26,100 deviates by 4.4% and is inside.
12. Floor 23,250 and ceiling 26,750 (±7%). At the floor there are mostly sellers and few buyers, so nobody can sell at that price without queuing; adjusted closes are also not literal prices.
13. FTSE Russell moves Vietnam from frontier to secondary emerging, in force from 21 September 2026. Under Decree 135/2015 resident individuals have no general channel for foreign securities, apart from employee share plans of a foreign employer; the table's "in VND" rows are arithmetic.
14. Unhedged (1.10)(1.05) - 1 = 15.5%. Hedged 1.10 x 1.059 / 1.045 - 1 = about 11.5%.
15. Net = 1.10 x 0.998 x 0.995^2 - 1 = about 8.68%. SPY in VND beat SPY in USD by about 2 points of CAGR because USD/VND rose by about that much a year (the dong depreciated); the gap reverses if the dong strengthens.

## Anti-patterns / Common mistakes

- **Reading a ranking as a forecast.** The table is a single window of past data. The order changes with the start date.
- **Comparing a price index with total-return series.** The VN-Index excludes dividends and understates its own total return.
- **Treating the "in VND" rows as an investment menu.** They are arithmetic, not net of costs, and not a legal route (Decree 135/2015).

## Lab

From `economy_monetary_mastery/labs/`: open `day18/README.md`, implement `to_vnd_prices`, `scorecard` and `hedge_decision` in `day18/lab.py`, then run `uv run pytest day18` until green and `uv run python -m day18.lab` for the sorted table and `.cache/plots/day18.png`. Expected: 5 tests pass (3 functions); the output shows the six rows above, SPY (VND) ahead of SPY (USD).

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: which row of the scorecard would you have most wanted to hold in 2015, and which part of that row (asset, currency, or window) did you not control? Then write one dated, checkable claim (for example: SPY in VND will beat the VN-Index over the next three years) and what evidence would prove you wrong. Resolve any due entries and add a row to the Calibration review table in `journal.md`.
