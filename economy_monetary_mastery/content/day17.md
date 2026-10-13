# Day 17 — Investing across currencies: VND returns, hedging

> Block 3: FX, the dollar & Vietnam. Facts as of 2026-10. Educational, not financial advice. Tax statements are general descriptions of public rules, not personal tax advice.

## Why this matters

**Scope note on access.** This day teaches the arithmetic of cross-currency returns, using SPY as the example series. It is not a statement that the route is open to an ordinary resident individual. Under [Decree 135/2015](https://conventuslaw.com/report/3-things-about-overseas-securities-investment-by/), resident Vietnamese individuals generally cannot invest in foreign securities; the exception described there is bonus-share schemes offered to Vietnamese citizens employed by foreign organisations. Entrusted overseas investment is for resident organisations, and Decree 103/2026 on outward investment (effective 3 April 2026) is reported to exclude securities and fund investment (not independently confirmed here). Everything below on costs and taxes describes a lawful holder, for example a participant in a foreign employer's share plan. State the legal position as of the sources used; it can change, and Day 16 covers the Vietnamese framework. The same arithmetic applies to a foreign investor in Vietnamese stocks, and to Vietnam-listed ETFs for a domestic investor, where the currency leg is absent.

A VND-based holder of a US asset such as SPY, where such holding is lawful (see the note above), holds two positions at once: the S&P 500, and a long USD/VND position. The statement of account shows dong, so the second position is not optional and not visible until it moves. Days 13 to 16 built the pieces (quotes, forwards, interest parity, the dollar system, the SBV band). Today they turn into a portfolio question: what return does the holder actually receive in the currency spent, what can be done about the currency leg, and what do the frictions of crossing a border take back?

On the snapshot, SPY compounded at 14.08% a year in USD from January 2010 to September 2026. In VND it compounded at 16.54%. The 2.46 points came from the dong sliding against the dollar by about 2.2% a year. That gift is neither guaranteed nor free: it is the reverse of a cost that a US-dollar saver pays when the dong appreciates, and it shows up only because VND has depreciated steadily. A plan that counts it as part of the equity return is a plan that assumes the SBV never changes course.

## Core concepts

### Your return is asset return times currency return

Returns multiply. If the asset gains `a` in its own currency and the foreign currency moves `f` against your home currency (both as decimals, with `f` measured in home currency per foreign unit), then:

```
(1 + home return) = (1 + a) (1 + f)         (your home_return)
```

So +10% in the asset and +5% for USD against VND is +15.5%, not +15%. A +10% asset with USD down 10% is -1%, not 0%. The cross term `a * f` is small for daily data and matters for decade-long data, which is why you compound instead of adding. The same logic gives a clean decomposition of a CAGR: `(1 + CAGR_VND) = (1 + CAGR_USD)(1 + CAGR_FX)`. The `main()` check line in the lab confirms it to the second decimal.

To restate a USD price series in dong, multiply the price by the USD/VND rate on the same date and then take returns. Two practical points (your `vnd_returns`):

- **Dates do not line up.** US markets and the FX series have different holidays. Reindex FX onto the price dates and carry the last known rate forward. Dropping mismatched days instead silently skips returns and misstates volatility.
- **Do not convert returns, convert prices.** Taking the USD daily return and adding the FX daily return is the additive mistake in disguise.

The same view applies in reverse. A US-dollar investor buying a Vietnamese stock sees `(1 + a_VND)(1 + f)` where `f` is VND against USD, currently a negative number on average. Vietnamese equities have to outrun the dong's depreciation before they beat a US index.

### The VND-based investor's view of US assets

Look at the daily series. Over 2015 to 2025, VND depreciated in most years (about +5.3% USD/VND in 2015, +3.8% in 2018, +3.7% in 2022, +5.1% in 2024 on year-end closes) and was roughly flat in others (2017, 2019 to 2021). Two things follow:

- **FX is a steady, small, one-directional tailwind** for US assets held by a VND saver, at about 2% a year, with year-to-year noise of a few points. That is about the size of the interest differential from Day 13 (5.9% VND against 4.5% USD gives a forward discount for VND near 1.3%), and a little more. The historical depreciation is roughly in line with uncovered interest parity on average, not clearly above it.
- **The tailwind has a tail.** The SBV manages the central rate and the band (Day 16), and the dong has been stable relative to other emerging-market currencies, so VND moves in steps and policy episodes rather than in random daily noise. The risk is a regime change (a one-time revaluation, or a sharp move in a crisis such as the cases in Day 15), not volatility. Correlation of `VND=X` returns with SPY, EEM and VNM is about 0 daily over the whole snapshot (2010 to 2026) and about +0.04 (EEM) and +0.08 (VNM) on month-end returns over the same window. Restricted to 2015 onward, month-end correlations are -0.29 (EEM) and -0.33 (VNM), but that is one sub-sample, not a stable relationship. Yahoo `VND=X` quotes can be stale or sparse, which pushes measured correlation toward zero, so treat these as rough. There is no reliable evidence here that the dong weakens in sell-offs.

### Hedging: what the hedge costs or pays

To hedge a USD asset you sell USD forward against VND. By covered interest parity (Day 13) the forward price already contains the interest differential, so a hedge **locks in the home rate instead of the foreign rate**:

```
hedged return = (1 + a) (1 + r_home t) / (1 + r_foreign t) - 1      (your hedged_return)
```

For a VND investor with the Day 13 inputs (r_home 5.9%, r_foreign 4.5%) the hedge adds about +1.3%, because the forward sells USD at a premium to spot. For a euro or yen investor, whose home rate is below the dollar rate, the same hedge costs 1% to 5% a year. That sign is the single most useful fact about hedging: the cost is the interest differential, taken by whoever is long the high-rate currency. Hedging is never "free" and never "insurance with no premium"; it exchanges currency risk for the interest gap.

```
 VND investor, SPY +10%, USD/VND flat                 Hedged       Unhedged
 Asset return in USD                                  +10.0%       +10.0%
 FX move on the USD leg                               locked       0.0%
 Forward points (VND 5.9% vs USD 4.5%)                +1.3%        --
 Return in VND                                        about 11.5%  10.0%
```

Do not stop there. Check three real-world frictions before concluding the hedge is worth doing:

- **Access.** The onshore forward market is dealt between banks and corporates; a lawful individual holder (see the scope note) has no obvious retail route to it, and typical foreign brokers do not offer a hedged share class. Whether and how an individual can hedge a USD position at a reasonable cost is unverified as of 2026-10; assume it cannot be done cheaply.
- **Dealer margin.** Banks quote forwards with a spread on top of the CIP level, so the realized pickup is smaller than the arithmetic above.
- **The comparison that matters.** Historical depreciation (about 2.2% a year since 2010) was of similar size to today's 1.3% gap, though past gaps differed (Day 13), so hedging would likely have changed the average modestly and removed variance. The decision is about variance, not expected return.

**When hedging is worth it.** Rule of thumb for any home currency: bonds usually yes, equities debatable. A bond's return is a few percent a year; a currency move of 5% to 10% swamps it, so the unhedged currency leg dominates the risk. A stock's return has 15% to 20% annual volatility; the currency move is a smaller share of the risk, and a foreign currency tends to rise when global equities fall (a natural cushion for a home investor that is long the dollar). A hedged equity holding gives up that cushion. Whether VND provides it is not established by the snapshot (see the correlations above).

### Costs that compound

A round trip crosses the currency border twice. Your `net_return` models the simplest case: one brokerage fee on the position and the FX spread paid on each conversion:

```
net = (1 + gross) (1 - fee) (1 - spread)^2 - 1
```

With a 20 bp fee and a 50 bp spread each way, a +10% gross becomes +8.68%: about 1.3 points lost, 13% of the profit. For a small gain or a short holding period the bill can be the whole return. Spread assumptions are illustrative.

Costs a VND-based holder of US securities would face, where such holding is lawful:

- **FX conversion spreads** on every VND to USD and back. They are often the largest line and are rarely itemised.
- **Brokerage and platform fees**, plus minimums. Custody or inactivity fees on some platforms.
- **Fund fees.** SPY's expense ratio is shown in the fund's prospectus; this is already inside the adjusted-close series.
- **US withholding tax on dividends.** The [IRS](https://www.irs.gov/individuals/international-taxpayers/federal-income-tax-withholding-and-reporting-on-other-kinds-of-us-source-income-paid-to-nonresident-aliens) describes the default for US-source dividends paid to nonresident aliens as withholding at 30% or a lesser tax treaty rate, claimed by filing Form W-8BEN with the withholding agent. The IRS [list of income tax treaties](https://www.irs.gov/businesses/international-businesses/united-states-income-tax-treaties-a-to-z) does not include Vietnam, so no reduced treaty rate appears available to Vietnamese residents as of 2026-10 (a lawful holder, such as an employee-plan participant, would deal with the plan administrator's W-8BEN process). On a stock yielding 1.3%, 30% withholding costs about 0.4% a year, a permanent drag that compounds.
- **Vietnamese tax on securities sold.** The [KPMG summary](https://assets.kpmg.com/content/dam/kpmg/vn/pdf/2026/01/new-pit-law-en.pdf) of the Personal Income Tax Law 109/2025/QH15 (passed 10 December 2025, effective 1 July 2026) lists securities transfer at 0.1% of the transfer price of each transaction ([also reported here](https://conventuslaw.com/report/vietnam-personal-income-tax-on-capital-and-securities-transfers-from-regulatory-updates-to-ma-implications/)) (sale value, not gain, charged on each sale). The rule is described for Vietnamese securities sold on an exchange; the implementing decree was still in draft in the sources used. How income from US securities held under a foreign employer's plan is declared and taxed in Vietnam is unverified as of 2026-10 and needs a Vietnamese tax adviser.
- **Other US rules.** The US may apply other rules (such as estate tax on US-situs assets) to nonresident aliens; those are not covered here.

On a Vietnamese stock the 0.1% is charged on a sale price, so it behaves like a small extra spread. At 0.1% each sale and a typical 0.15% to 0.3% brokerage on each side, round-trip cost can reach about 0.5%, which punishes frequent trading far more than long holding.

### Home bias and diversification across currencies

Most investors hold more of their home market than a global weighting would suggest. For a Vietnamese saver the case for holding foreign assets is the same as any diversification argument (Day 10), where lawful (see the scope note): VN-Index and the S&P 500 are different economies, rate regimes and currencies. The currency leg changes the arithmetic in two ways:

- It **adds return** on average when the home currency depreciates, and **subtracts** when it appreciates. Over 2010 to 2026 the average effect for a VND holder of USD assets was positive.
- It **adds risk**, but of an odd kind. Since the dong is managed, its measured volatility against the dollar is low and arrives in jumps.

A practical frame: spending needs are in dong, so the home bias that matters is liability matching. Currency exposure should match what you will spend it on.

## Worked example

SPY, 2015-01-02 to 2025-12-31, as one VND-based investor sees it (Yahoo adjusted close; Yahoo `VND=X`; both from the snapshot; table computed outside `main()`):

```
                          Start       End         Change     CAGR (11.0 y)
SPY (USD, adj. close)     169.27      676.64      +299.7%    13.4%
USD/VND                   21,063      26,225      +24.5%     2.0%
SPY in VND                3.566m      17.745m     +397.7%    15.7%
```

Checks:

- Decompose: `(1 + 2.997)(1 + 0.2451) - 1 = 3.977`, that is +397.7%, the same as pricing SPY in VND directly. As CAGR, `1.134 x 1.020 = 1.157`.
- The FX leg is about 2 of the 15.7 points a year, or about 13% of the VND return. It would turn negative if USD/VND fell.
- Costs: assume 20 bp fee and 50 bp spread each way. A single round trip subtracts about 1.2 points of value from the final amount, which is small on a +398% gain but large on a one-year +10% gain. Cost drag is a per-trade, not a per-year, number, so it matters most for frequent trading.
- Compare with the home market: over the full snapshot to 2026-09, SPY in VND compounds at 16.54% versus 7.66% for the VN-Index, but the VN-Index figure is a **price index without dividends**, so the gap is overstated by the dividend yield. The two are also over different regimes: the VN-Index fell hard in 2022. Neither number is a forecast.

Run `uv run python -m day17.lab` after implementing the functions to reproduce the 2010 to 2026 line from the opening section.

## Exercises

1. **Compounding currency.** A US fund returns +8% in USD in a year while USD/VND rises from 25,000 to 26,000. What is the VND return? What would it be if USD/VND fell to 24,000?
   **Hint:** compute the FX return first, then multiply.
   **Solution sketch:** FX = 26,000 / 25,000 - 1 = +4%, so 1.08 x 1.04 - 1 = +12.32%. For 24,000, FX = -4%, so 1.08 x 0.96 - 1 = +3.68%. A 4-point FX swing moves the VND result by 8.6 points; the asset return is only part of the story.

2. **What a hedge pays.** A VND investor holds a US bond fund returning +4.5% in USD. The 12-month VND rate is 5.9%, the USD rate 4.5%. What is the hedged return in VND? What would the hedge cost a euro investor if the euro rate were 2.0%?
   **Hint:** use `hedged_return` with the home rate in the numerator.
   **Solution sketch:** 1.045 x 1.059 / 1.045 - 1 = 5.9%, equal to the home rate: a hedged bond earns the home deposit rate regardless of the bond, which is the point of CIP. For the euro investor the same bond hedges to 1.045 x 1.02 / 1.045 - 1 = 2.0%, giving up 2.5 points of USD yield; that is the hedge cost.

3. **Cost drag.** An ETF returns a gross +6% over one year. Fee 20 bp, FX spread 50 bp each way. Compute the net return and the share of profit lost. Repeat with a 100 bp spread.
   **Hint:** use `net_return`; share lost = (gross - net) / gross.
   **Solution sketch:** 1.06 x 0.998 x 0.995^2 - 1 = about +4.73%, 21% of the profit lost. At a 100 bp spread the net is 1.06 x 0.998 x 0.99^2 - 1 = about +3.68%, 39% lost. The spread, paid twice, is the lever to check first.

4. **Withholding arithmetic.** A US stock yields 2% in dividends and the withholding rate for a non-resident without a treaty is 30%. What is the yearly drag, and what is the difference after 20 years on a 6% price return, ignoring other costs?
   **Hint:** the drag is 2% x 30% = 0.6% a year; compare (1.08)^20 with (1.074)^20 where 8% is the total return.
   **Solution sketch:** 8% total return becomes 7.4%. 1.08^20 = 4.66 and 1.074^20 = 4.17, so the final wealth is about 10% lower. Small annual costs compound; verify whether the rate you pay is the default or a treaty rate.

5. **Forward-fill on holidays.** `prices` has dates Jan 2, 3 and 4; `fx` has only Jan 2 and 3. Why does `vnd_returns` return two values and not one, and what would break if you used `dropna` after an inner join?
   **Hint:** count the dates that survive each method.
   **Solution sketch:** Reindex plus ffill keeps three priced dates and gives two returns (Jan 3, Jan 4) with Jan 4 using the Jan 3 rate. An inner join keeps two dates and one return, and the Jan 4 gain is lost; on a long series every holiday would turn two days of return into one multi-day step with a skipped return.

6. **Unhedged versus hedged risk (judgment).** For a VND saver, rank these by how much hedging reduces risk: a US Treasury fund, a US equity index fund, a Vietnamese stock held by a USD investor. Which hedge has a cost that goes the other direction?
   **Hint:** compare the currency move with the asset's own volatility.
   **Solution sketch:** Treasury fund first (a small asset return against a large relative FX move); equity index second (currency is a smaller share of total variance, plus any dollar cushion in sell-offs, which the snapshot does not firmly establish); the third depends on the investor. A USD investor hedging VND exposure sells VND forward and pays the differential, the reverse of the VND saver's pickup.

## Anti-patterns / Common mistakes

- **Comparing returns in different currencies.** SPY at +14% in USD against a VN stock at +12% in VND is not a comparison. Restate both in one currency, then compare, and say which one.
- **Ignoring FX conversion spreads on every round trip.** The spread is paid when you buy and again when you sell. Modeling it once halves the cost.
- **Assuming hedging is free.** The hedge returns the interest differential, in one direction or the other. For a VND saver it may pay; for most other home currencies it costs. Dealer margins make it worse than the arithmetic.
- **Treating past depreciation as a return source, or adding returns instead of multiplying.** About 2.2% a year of dong depreciation lifted USD assets in VND. It depends on SBV policy and could vanish.

## Lab

`labs/day17/`. Implement `home_return`, `hedged_return`, `vnd_returns` and `net_return`. Then run `uv run python -m day17.lab` to restate SPY in VND, split the CAGR into asset and currency, and compare with the VN-Index. See `labs/day17/README.md`.

## Teardown

Nothing billable is created. The lab reads frozen snapshots only; `.cache/plots/day17.png` is a local file you can delete.

## Journal prompt

List every lawful holding you have or could have with a foreign-currency leg (see the scope note), including a domestic ETF as the no-FX comparison. For each, write the currency you will spend it in, the round-trip cost you would pay (spread, fee, tax) and whether you would rather hedge, and say what would have to be true about the dong for your answer to change.
