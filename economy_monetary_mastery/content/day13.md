# Day 13 — FX mechanics: quotes, forwards, interest parity

> Block 3: FX, the dollar & Vietnam. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Every position you hold has a currency leg. A US ETF bought from Vietnam is a bet on the S&P 500 and on USD/VND at the same time; a Vietnamese stock is a bet on the company and on VND; a coin priced in USDT is a bet on the coin and on the dollar. Block 2 priced assets in one currency. Block 3 asks what happens when money crosses a border, and today is the plumbing: how a price is quoted, what a forward is, why a forward is not a forecast, and what a "carry trade" really earns.

Two ideas carry the whole block. First, **covered interest parity** (CIP) is an accounting identity enforced by arbitrage: the forward exchange rate is pinned by two interest rates and the spot rate, so it contains no opinion about the future. Second, **uncovered interest parity** (UIP), the claim that high-yield currencies must depreciate enough to cancel their yield, mostly fails among freely floating currencies. That failure is what has historically paid the carry trade, and its tail risk is the reason the profit can vanish in a week, as it did in August 2024.

## Core concepts

### Quotes: base, quote, and "which currency am I long?"

A currency pair is written BASE/QUOTE and the price is **how many units of the quote currency one unit of the base costs**. USD/VND = 25,969 means 1 USD = 25,969 VND. This is the convention in this course's code: `spot` is quote units per 1 base unit.

- **Direct vs indirect.** From a Vietnamese point of view, USD/VND is a *direct* quote (domestic currency per foreign unit, the way Vietcombank displays it). EUR/USD is an indirect quote for a Vietnamese reader. The labels flip with whose home you pick, so skip them and always read BASE/QUOTE.
- **Pips.** The fourth decimal in most pairs (EUR/USD 1.1000 to 1.1001 is one pip, 0.0001); the second decimal for JPY pairs. USD/VND has no pips in practice; traders quote whole dong.
- **Long/short drill.** Buying a pair means buying the base and selling the quote. Buy USD/JPY at 150: you are *long USD, short JPY*. The pair rising means the base is getting more expensive, so you win. Always answer three questions: which currency do I own, which do I owe, and which way does the quoted number need to move for me to win?

Holding the base currency returns `spot_end / spot_start - 1` (your `fx_return`). If USD/VND goes 25,000 to 26,250, a USD holder gains 5% in VND terms, and a VND holder has lost: in USD terms VND fell from 1/25,000 to 1/26,250 USD, a 4.76% loss. Direction errors here are the most common FX bug.

### Spot, forward and swap

- **Spot:** exchange now, settle in two business days (T+2; USD/CAD and a few others settle T+1).
- **Outright forward:** agree today a rate for exchange at a future date. No money moves until then.
- **FX swap:** two legs at once, buy USD spot and sell USD forward (or the reverse). It is a collateralised loan in disguise: you borrow one currency against another. Banks use swaps to borrow dollars; the forward points are the interest differential.

The **forward points** are `F - S`. If points are positive the base currency trades at a *forward premium*.

### Covered interest parity: the forward is arithmetic

Take 1 USD. Path A: lend it in the US at r_USD for t. Path B: convert it to VND at spot S, lend the VND at r_VND for t, and *lock in the conversion back* with a forward F. A risk-free outcome must be the same on both paths, or someone prints money. With simple rates:

```
(1 + r_USD t)  =  S (1 + r_VND t) / F
        =>  F  =  S (1 + r_quote t) / (1 + r_base t)          (your forward_rate)
```

The currency with the higher interest rate trades at a forward *discount* (it is cheaper forward). USD/VND rises forward, VND weakens, because VND pays more. The forward points are the exact price of the rate gap, not a bet.

If a dealer quotes the forward below fair, you can harvest the gap. Numbers (the worked example's `S` = 25,969, rates VND 5.9%, USD 4.5%, 1 year; fair F about 26,317; dealer quotes 26,200):

```
Step 0: borrow 1 USD at 4.5%         you owe 1.045 USD at T
Step 1: sell 1 USD spot at 25,969    you hold 25,969 VND
Step 2: deposit VND at 5.9%          you hold 27,501 VND at T
Step 3: buy 1.045 USD forward @26,200  cost 27,379 VND at T
        Net at T: +122 VND, no market risk

           You (arbitrageur), at T
  Assets                | Liabilities
  VND deposit  27,501   | USD loan 1.045 (= 27,379 VND at the forward)
  Net  +122 VND         |
```

Your own buying of the forward pushes the quote back toward 26,317. In normal markets with zero frictions the gap closes in milliseconds. `cip_deviation_bp` measures the leftover as `(F_quoted / F_fair - 1) * 10,000`.

### CIP deviations since 2008: the dollar-funding-cost signal

Before 2008 the identity held to within a few basis points between major currencies. Since then it has *not*, especially for EUR/USD and USD/JPY: the **cross-currency basis** is persistently negative, meaning that borrowing dollars through the FX swap market costs more than the plain interest differential implies. The reasons are not "free money": arbitrage needs balance sheet, and post-crisis bank regulation (leverage ratios, quarter-end reporting) makes balance sheet scarce, while global demand for dollar hedges is large ([BIS Quarterly Review, September 2016, on the cross-currency basis](https://www.bis.org/publ/qtrpdf/r_qt1609e.htm)). Read the basis as a **price of dollar funding**: when it widens sharply (March 2020, year-ends), the world is short of dollars and the Fed's swap lines (a lender-of-last-resort tool for dollars) become relevant. The next day builds on this for the dollar.

### UIP and the forward premium puzzle

UIP says: expected depreciation of the high-rate currency equals the interest gap, so the carry earns nothing on average. If that held, forward = expected spot. Decades of data say otherwise (the "forward premium puzzle", Fama 1984): high-yield currencies on average do *not* depreciate by the forward discount, and sometimes appreciate; Fama found a negative slope coefficient where UIP predicts one. Proposed explanations include a time-varying risk premium, crash risk (carry earns a premium for bearing rare large losses) and the peso problem (a feared devaluation that rarely arrives, so the sample looks too calm). A forward is therefore a price for locking an exchange rate, **not an unbiased forecast**. Treating it as one is anti-pattern 2 below.

### The carry trade

Borrow in a low-rate (funding) currency, convert and lend in a high-rate (investment) currency, unhedged. Return per 1 unit of funding currency:

```
carry = S0 (1 + r_invest t) / S1  -  (1 + r_fund t)         (your carry_trade_return)
```

with `S0`, `S1` expressed as investment-currency per funding-currency. If spot does not move, you pocket the rate gap (1% in the test). If the investment currency drops 5% you lose about 4%: the test pins `-0.04`. The usual summary is that carry is **"picking up nickels in front of a steamroller"**: small, steady income, then a rare large loss when high-yield currencies fall together as risk appetite collapses. Its returns are negatively skewed, and a Sharpe ratio computed from calm years flatters it (Day 10).

The best recent example: the yen carry unwind of August 2024. After the Bank of Japan's July hike and weak US data, the yen jumped, leveraged positions funded in yen were cut, and on 5 August Japan's TOPIX fell 12% in one session while the VIX spiked to levels last seen in 2020 ([BIS Bulletin No 90](https://www.bis.org/publications/bulletin-90-market-turbulence-and-carry-trade-unwind-august-2024.pdf)). The BIS notes the spike was amplified by deleveraging and margin increases. The lesson is not that yen funding is uniquely dangerous; it is that carry positions are crowded, leveraged, and exit through the same door.

### Market structure: OTC, dealers, size

FX has no exchange. It is an **over-the-counter** market: a handful of large dealer banks quote to each other and to clients, with electronic platforms and non-bank liquidity providers on top. The [BIS Triennial Central Bank Survey](https://www.bis.org/statistics/rpfx25_fx.htm) reports $9.6 trillion of average daily turnover in April 2025, up 28% from 2022 (net-net basis; preliminary at publication, 30 September 2025). The US dollar is on one side of 89.2% of trades. FX swaps, not spot, are the largest instrument (about $4.0 trillion a day, roughly 42% of the total, in the [BIS table](https://www.bis.org/statistics/rpfx25_fx.htm); see also [The Full FX](https://thefullfx.com/fx-turnover-hits-9-6-trillion-in-bis-triennial-survey/)): most turnover is funding and hedging, not speculation. The consequence for you: retail quotes include a dealer spread, and what looks like "the" exchange rate is one dealer's price.

## Worked example

A VND/USD forward from deposit rates, using the snapshot `prices/VND_X.csv` (Yahoo, VND per USD, last close 2026-09-29: **25,969**).

Inputs (as of 2026-10): VND 12-month deposit **5.9%** at the counter at Vietcombank, matching BIDV and VietinBank, per [24hmoney](https://24hmoney.vn/lai-suat-gui-ngan-hang/vietcombank) and [Vietbao](https://vietbao.vn/gui-tiet-kiem-vietcombank-thang-102026-lai-suat-cao-nhat-6nam-609969.html); online and promotional rates were quoted from 5.0% to about 7.4% by different sources, so this is a rough number, not a firm quote. USD 12-month **about 4.5%**: the 1-year Treasury yield was 4.44% on 8 October 2026 and ranged about 4.1-4.6% through September ([FRED DGS1](https://fred.stlouisfed.org/series/DGS1)). A Vietnamese bank's USD deposit rate for individuals is much lower and was not verified, so the Treasury yield is used as the USD leg. Headline sanity check for spot: on 10 October 2026 the SBV central rate was 25,629 with a ±5% band, Vietcombank sold USD at about 26,070 ([Vietbao](https://vietbao.vn/ty-gia-usd-hom-nay-1010-ty-gia-trung-tam-o-muc-25629-dongusd-610730.html)); the Yahoo series sits between them.

```
F = 25,969 * (1 + 0.059) / (1 + 0.045) = 25,969 * 1.01340 = 26,317
points = +348 VND  (+1.34%)
```

`uv run python -m day13.lab` prints exactly this, then compares with history. Realized one-year changes in USD/VND since 2015 averaged **+1.78%** but ranged from -3.7% to +9.8% over 2,806 overlapping windows; the constant forward premium of 1.34% was exceeded in 55% of them. A borrow-USD / hold-VND carry at these rates would have averaged about **-0.4%**, lost in 55% of windows and -8% at worst (before spreads; real onshore access is limited by capital controls). Read this carefully. On average the realized depreciation (1.78%) is close to the 1.34% premium, so this is roughly UIP on average, with large dispersion: as a point forecast the forward is poor (outcomes from -3.7% to +9.8%). The negative mean carry reflects a managed, steadily depreciating VND. The history also applies today's 1.4-point rate gap to 2015-2026, when actual gaps differed (USD rates were near zero for years), so treat it as illustrative only, not a backtest.

## Exercises

1. You buy USD/JPY at 150.00. Which currency are you long? What is your percentage gain or loss if it falls to 142.00, and how many pips (2nd decimal) is that?
   **Hint:** Buying the pair buys the base. `fx_return(150, 142)`.
   **Solution sketch:** Long USD, short JPY. The return is 142/150 - 1 = -5.33%. In JPY pips that is 800 pips (8.00 yen). The quote number fell, so the base lost value.

2. With S = 25,969 and VND 5.9%, USD 4.5%, compute the 6-month forward and its points.
   **Hint:** t = 0.5; use simple interest.
   **Solution sketch:** F = 25,969 * 1.0295 / 1.0225 = 26,147; points +178, about +0.69%. Half the 1-year gap, roughly: points scale about linearly with t at these small rates.

3. The market quotes the 1-year USD/VND forward at 26,000 while CIP says 26,317. Compute the deviation in bp and describe the arbitrage.
   **Hint:** `(F/F_fair - 1) * 1e4`; the quoted forward is cheap or rich?
   **Solution sketch:** 26,000/26,317 - 1 = -1.2%, about -120 bp. USD is cheap forward, so borrow USD, sell it spot, deposit VND, and buy USD forward at 26,000 to repay: a locked profit of about 1.2% of notional. In practice such a gap would persist only if capital controls or balance-sheet limits stop the trade, which is exactly what a CIP deviation signals.

4. You fund in USD at 4.5% and invest in a currency X at 9.5% for a year. Spot is 20 X per USD. What spot at year end gives zero return, and what is the loss if X weakens to 22?
   **Hint:** `carry = S0 (1 + ri)/S1 - (1 + rf)`.
   **Solution sketch:** Break-even S1 = 20 * 1.095 / 1.045 = 20.96, meaning X can lose about 4.6% against the dollar before the 5-point yield gap is eaten. At 22: 20 * 1.095 / 22 - 1.045 = 0.9955 - 1.045 = -4.95%. Five points of yield offset a 4.6% fall; a fall of about 9% (S1 = 22) costs about five points net.

5. The 1-year forward for USD/VND is 26,317 (+1.34% above spot). One year later spot is 25,300. Did "the forward predict" anything? Compare the outcomes of (a) hedging with the forward and (b) staying unhedged for a Vietnamese investor who must pay USD 10,000 in a year.
   **Hint:** Compare VND cost: 10,000 * F vs 10,000 * S1.
   **Solution sketch:** Hedging costs 263.2 million VND; unhedged costs 253.0 million VND. The unhedged side won by 10.2 million, but the forward was a price for certainty, not a forecast; you can only call it right or wrong in hindsight. Also note the opposite outcome, S1 = 27,000, would favor the hedge by 6.8 million.

6. BIS reports $9.6 trillion average daily FX turnover and USD on one side of 89.2% of trades. What daily USD-involved turnover does that imply, and why do currency shares sum to 200%?
   **Hint:** 0.892 * 9.6; every trade has two currencies.
   **Solution sketch:** About $8.6 trillion a day involves the dollar. Shares sum to 200% because each trade has two sides; the dollar's 89.2% is the share of trades that have USD on one side. The number says the dollar is the vehicle currency: VND to EUR typically goes VND-USD-EUR in two legs.

7. Run `main()` with `R_VND = 0.04` and `R_USD = 0.045`. What happens to the forward points and to the carry history, and what does the sign flip mean?
   **Hint:** If r_quote < r_base, the points are negative.
   **Solution sketch:** The forward falls below spot (VND at a forward premium) and the "carry" borrowing USD to hold VND turns into a negative carry before any FX move. The historical mean carry falls by the 1.9-point change in the rate gap, from about -0.4% to about -2.3%. This shows that the points depend purely on the rate inputs, so they say nothing about where USD/VND will actually go.

## Anti-patterns / Common mistakes

- **Mixing up quote direction.** Reading USD/VND as VND/USD flips every sign. Write BASE/QUOTE and "units of quote per 1 base" before any calculation, and test your formula with a rate gap that has an obvious sign.
- **Treating the forward as a forecast.** Forward = spot adjusted for two interest rates. It tells you the cost of locking a rate, not where spot will be (UIP fails among floaters; the forward premium puzzle).
- **Ignoring crash risk in carry.** A smooth equity curve of yield pickup hides the left tail (August 2024). Size carry for the loss, not the average, and remember financing, margin and spread costs.
- **Comparing rates in the wrong units.** Simple annual rates with a year fraction, not mixed percent and decimals, and the same compounding on both legs.
- **Assuming CIP holds for VND.** Capital controls and SBV intervention mean offshore non-deliverable forwards and onshore deposits can disagree; this chapter's formula is the frictionless benchmark.

## Lab

From `economy_monetary_mastery/labs/`: open `day13/README.md`, implement the five functions in `day13/lab.py`, then run `uv run pytest day13` until green and `uv run python -m day13.lab` for the summary and `.cache/plots/day13.png`. Expected: all 6 tests pass; the summary shows the 26,317 forward on spot 25,969 and the realized-vs-forward comparison above.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: write the currency exposure of your three largest holdings (which currency each is really a bet on), and say whether you would want any of those exposures hedged. If a hedge would cost the interest differential of today's forward points, would you pay it?
