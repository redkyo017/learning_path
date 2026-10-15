# Day 5 — Shadow banking: repo, MMFs, SVB 2023

> Block 1: Money & banking plumbing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 2 showed banks as deposit factories and Day 3 showed the Fed pricing their reserves. But a large part of the dollar system does not run through bank deposits at all. Money-market funds, repo markets and offshore dollar balances move trillions daily, with thinner backstops and, historically, runs. Every major recent crisis (2008, March 2020, March 2023) was a failure of this plumbing, not of "the economy". If you hold US bonds, bond ETFs, stablecoins (Day 21) or crypto with leverage (Day 22), you are exposed to the same mechanics.

Today also gives you the two quantitative tools you need to read those events: duration (how much a bond book loses when rates rise) and drawdown (how far an asset falls from its peak). The lab runs both on SVB's real numbers and on TLT, the long-Treasury ETF.

## Core concepts

### Shadow banking: banking without the bank charter

Shadow banking means maturity and liquidity transformation (borrow short and liquid, hold longer or riskier assets) by institutions that are not insured depositories. The pieces:

- Money-market funds (MMFs). Investors hold fund shares valued at about $1 that behave like deposits, but the fund holds T-bills, repo and commercial paper. No deposit insurance; the stable price is a promise backed by asset quality.
- Repo. A cash borrower sells a security and agrees to buy it back tomorrow at a slightly higher price. Economically it is a collateralised overnight loan.
- Broker-dealers and hedge funds, who fund their bond inventories in repo.

A repo trade as T-accounts. A hedge fund posts $100 of Treasuries to a money fund and borrows $98 cash (a 2% haircut, the cushion for price moves):

```
        Money fund                          Hedge fund
  Assets            | Liabilities     Assets             | Liabilities
  Cash        -98   | (fund shares)   Cash         +98   | Repo borrowing +98
  Reverse repo +98  |                 (Treasuries $100 are still its asset,
  (collateral $100) |                  but pledged to the fund)
```

Tomorrow the fund gets back $98 plus a few cents of interest and returns the collateral. The haircut protects the lender: if the fund must sell the bonds, they can fall about 2% before it takes a loss. Repo rates on Treasury collateral are among the most important prices in finance; the Fed's own ON RRP and standing repo facility from Day 3 are repo trades with the Fed on the other side. The weakness is the same as a bank's: lenders can refuse to roll tomorrow. Collateral values fall, haircuts rise, funding disappears, and forced sales push prices down further.

### The eurodollar system (preview of Day 14)

"Eurodollars" are US-dollar deposits held at banks outside the US (London, Singapore, Hong Kong), not under Fed reserve rules. They are the dollar balances that fund most cross-border trade and lending, including to emerging markets. Because those banks cannot create Fed reserves, in stress they borrow dollars from the Fed through central-bank swap lines (below). Day 14 returns to why a stronger dollar tightens conditions for borrowers like Vietnam. For now: the dollar system is bigger than the US banking system.

### Crises as plumbing failures

2008. Repo lenders refused to roll loans against mortgage-linked collateral and raised haircuts; funding evaporated at broker-dealers. Separately, the [Reserve Primary Fund](https://www.cranedata.com/archives/all-articles/3043) "broke the buck" in September 2008: it held Lehman paper, its share price fell below $1 (to $0.97), and money fund investors ran across the industry. Governments guaranteed MMFs and expanded lending facilities.

March 2020. Even the safest collateral, US Treasuries, hit a "dash for cash": funds and foreign holders sold bonds to raise dollars, dealers could not absorb the volume, and Treasury yields rose when they should have fallen. The Fed bought Treasuries at scale and, with the BoC, BoE, BoJ, ECB and SNB, [cut the price of the dollar swap lines and added longer operations](https://www.federalreserve.gov/newsevents/pressreleases/monetary20200315c.htm) so foreign banks could get dollars.

March 2023, SVB: the case study below.

### Duration: interest-rate sensitivity for engineers

A bond pays fixed cash flows. When market yields rise, the present value of those flows falls. The sensitivity is modified duration: roughly "percent price change per 1 percentage point change in yield". A duration of 6 means a bond loses about 6% when yields rise 1 point (and gains about 6% when they fall 1 point). It is the first derivative of price with respect to yield, scaled by price. Dollar form (your `duration_price_change`, with `dy` as a decimal):

```
change in value ≈ - modified_duration * dy * value
```

Price is curved in yield, so the linear estimate overstates losses and understates gains; convexity is the second derivative and corrects it (your `convexity_price_change`):

```
change ≈ - D * dy * V + 0.5 * C * dy² * V
```

Long bonds have higher duration: a 20-year bond might have duration near 15, a 2-year near 2. "Risk-free" Treasuries are free of default risk, not of price risk.

### HTM vs AFS: accounting that hides the mark

US banks classify securities:

- Available for sale (AFS): carried at fair value; unrealised gains and losses go to accumulated other comprehensive income (AOCI), which flows into regulatory capital unless a bank is allowed to opt out. SVBFG, as a Category IV firm (assets of $100-250bn), had elected to exclude AOCI. Its reported CET1 ratio of 12.1% therefore did not reflect about $1.9bn of AFS losses; recognising them would have cut it to 10.4% at 2022:Q4 (Tables 14-15 of the [Fed review](https://www.federalreserve.gov/publications/files/svb-review-20230428.pdf)).
- Held to maturity (HTM): carried at amortised cost; fair value is only disclosed in a note. The bank claims it will never sell, so it ignores interim price moves. Selling even a small part can force the bank to reclassify the entire portfolio.

The accounting changed what was reported, not what was true. If depositors leave, the bank must raise cash, and the only way to do that from an HTM book is to sell at market prices (or borrow against it). The unrealised loss becomes realised at the worst time. HTM is therefore a statement about intent, not safety.

### Quant thread: drawdown

A drawdown is the fall from the running peak: `price / running_max - 1`. Maximum drawdown is the worst one in the sample. It answers "how bad did the hold feel?", which return and volatility hide. It depends on the path, so two assets with the same annual return can have very different maximum drawdowns. You implement `drawdown_series` and `max_drawdown` in the lab. Day 10 builds on them.

## Worked example

### SVB's balance sheet through the lab functions

Silicon Valley Bank (SVB Financial Group, SVBFG) took a flood of venture-capital deposits in 2020-21 and put much of it into long, fixed-rate agency mortgage-backed securities. Numbers at 2022-12-31, from SVBFG's [FY2022 10-K](https://www.sec.gov/Archives/edgar/data/719739/000071973923000021/sivb-20221231.htm): total assets $211.8bn; total deposits $173.1bn; stockholders' equity $16.0bn; HTM securities carried at amortised cost $91.3bn (91,321 million) with a disclosed fair value of $76.2bn (76,169 million).

Step 1, rates. Run `uv run python -m day05.solution`. From the FRED snapshots, the [2-year](https://fred.stlouisfed.org/series/DGS2) went from 0.73% to 4.41% over 2022 and the [10-year](https://fred.stlouisfed.org/series/DGS10) from 1.52% to 3.88% (+2.36 points).

Step 2, the loss. Amortised cost minus fair value is 91.3 - 76.2 = $15.1bn, which is 16.5% of the book. Dividing by the 10-year move gives an implied duration of about 7.0 (`duration_price_change(91.3, 7.0, 0.0236)` is about -15.1bn). The Fed's [post-mortem](https://www.federalreserve.gov/publications/review-of-the-federal-reserves-supervision-and-regulation-of-silicon-valley-bank.htm) states a weighted-average HTM duration of 6.2 years at 2022-12-31 (citing the 10-K); the gap has three plausible causes, all making the realised loss larger than a fixed 6.2-year duration predicts. Mortgage yields rose more than the 10-year Treasury. Much of the book was bought in 2020-21 at low yields, so the yield change since purchase exceeds the end-2021 to end-2022 change. And agency MBS are negatively convex (higher rates slow prepayments and extend the bonds), so duration lengthened as rates rose.

Step 3, equity. `equity_after_marking(16.0, 15.1)` is $0.9bn. The $16.0bn GAAP equity already includes the AFS losses (through AOCI); the HTM mark is the part it leaves out, and that mark alone would have erased about 94% of equity. HTM losses were excluded from both GAAP equity and regulatory capital, and SVBFG's AOCI opt-out hid its AFS losses from the ratios as well, so the capital ratios did not show the problem; it was visible to anyone who read the fair-value footnote.

```
            SVB (2022-12-31, $bn, simplified)
  Assets                      | Liabilities + equity
  HTM securities (cost) 91.3  | Deposits            173.1
     [fair value 76.2]        | Equity               16.0
  AFS securities, loans, cash |
  ... total assets    211.8   | (total incl. other debt 211.8)
```

Step 4, the run. On 2023-03-08 SVBFG announced it had sold [$21bn of AFS securities at an after-tax loss of $1.8bn](https://www.federalreserve.gov/publications/review-of-the-federal-reserves-supervision-and-regulation-of-silicon-valley-bank.htm) and planned a $2.25bn equity raise. That told depositors what the footnote already said. Most deposits were uninsured (above the $250,000 cap), concentrated in one tight-knit industry, and could be withdrawn by app. Withdrawal requests on 2023-03-09 were about [$42bn within eight hours](https://dfpi.ca.gov/wp-content/uploads/sites/337/2023/05/23-05-08-SVB-DFPI-Review-PR.pdf) (the Fed review says "over $40 billion"), about 24% of deposits in a day, with $100bn more expected on March 10. The bank was closed on March 10. The classic recipe: duration mismatch (long fixed assets, demand liabilities), uninsured concentrated funding, and speed.

Step 5, the backstop. On 2023-03-12 the Fed [announced the Bank Term Funding Program (BTFP)](https://www.federalreserve.gov/newsevents/pressreleases/monetary20230312a.htm): loans of up to one year to banks against Treasuries, agency debt and MBS valued at par, not at market. Lending at par removes the need to sell underwater bonds: the Fed took the duration risk on its own balance sheet. The Fed's [program page](https://www.federalreserve.gov/financial-stability/bank-term-funding-program.htm) records that it stopped making new loans on 2024-03-11.

### TLT: the "risk-free" asset that fell by half

The same arithmetic applies to anyone holding long Treasuries. The lab loads TLT (20+ year Treasuries) from the snapshot and measures from 2020-01-01: maximum drawdown about -48.4%, peak 2020-08-04, trough 2023-10-19. Note these are adjusted closes, which include reinvested distributions, so the loss in price terms is slightly larger. No default occurred. Duration did it. This is the lesson of the quant thread: "risk-free" describes credit risk, never price risk.

### Verify (as of 2026-10)

| Constant | Value | Source |
|---|---|---|
| `HTM_AMORTIZED_COST_BN` | 91.3 | 10-K FY2022 balance sheet (91,321m), link above |
| `HTM_FAIR_VALUE_BN` | 76.2 | same line, "fair value of $76,169" |
| `TOTAL_EQUITY_BN` | 16.0 | 10-K Item 1 |
| `DEPOSITS_BN` | 173.1 | 10-K Item 1 |
| `AFS_SOLD_BN`, `AFS_LOSS_BN` | 21, 1.8 (after tax) | Fed review of SVB supervision, 2023-04-28 |
| `WITHDRAWN_MAR9_BN` | 42 | California DFPI review, 2023-05-08; Fed says "over $40 billion" |
| TLT max drawdown | -48.4% | computed from the 2026-09-29 snapshot (`uv run python -m day05.solution`) |

## Exercises

1. A repo: you borrow $95 cash against $100 of Treasuries. What is the haircut? If the bonds fall 8% overnight and you default, who loses and how much?
   **Hint:** The lender's collateral is now worth $92.
   **Solution sketch:** The haircut is 5/100 = 5%. Collateral falls to $92 versus $95 lent, so the lender is short $3 (before interest) unless it can recover from you. A larger haircut or shorter tenor would have covered it. Rising haircuts in a crisis force borrowers to sell, which pushes prices down.

2. Use `duration_price_change` and `convexity_price_change`: a $200 bond position with modified duration 8 and convexity 90. Yields rise 1.5 points, then fall 1.5 points. Report both results for each approximation.
   **Hint:** `dy` is 0.015, not 1.5.
   **Solution sketch:** Duration only: -24 for a rise, +24 for a fall. With convexity the correction is 0.5*90*0.015²*200 = +2.025: -21.975 for the rise, +26.025 for the fall. Convexity helps both ways; the linear estimate overstates the loss and understates the gain.

3. SVB's HTM book was 91.3 of 211.8 total assets and its equity was 16.0. By how much would the fair value of the HTM portfolio need to fall to wipe out equity entirely, as a percentage of its amortised cost?
   **Hint:** Divide 16.0 by the book, not by total assets.
   **Solution sketch:** 16.0/91.3 = 17.5% of the HTM book. The actual gap was 16.5%, so the HTM mark alone, which GAAP equity does not include, came within about a point of wiping out equity. The denominator is the HTM book, not total assets (which would give 7.6%).

4. A friend says "SVB held only government-backed securities, so it was safe". Give a precise rebuttal using credit risk, interest-rate risk and liability structure.
   **Hint:** Separate the asset side from the liability side.
   **Solution sketch:** Credit risk was low (agency MBS and Treasuries), but interest-rate risk was high (duration of 6.2 years on the HTM book against demand deposits). The liabilities were uninsured and concentrated, so the assets had to be liquidated on short notice. A safe asset funded by runnable liabilities is not a safe bank.

5. Compute the drawdown series by hand for prices 50, 80, 60, 70, 40, 90, and name the maximum drawdown and the date index where it occurs.
   **Hint:** Running peak first: 50, 80, 80, 80, 80, 90.
   **Solution sketch:** Drawdowns are 0, 0, -0.25, -0.125, -0.5, 0. The maximum drawdown is -50% at index 4. Recovery to a new high at index 5 resets it to zero, but the max stays -50%; it is a property of the path.

6. Run `max_drawdown` on `IEF`, `AGG` and `SPY` from the snapshot since 2020. Rank them, and explain where TLT's number comes from.
   **Hint:** `load_prices(["IEF","AGG","SPY"])`, filter by date, apply per column.
   **Solution sketch:** Snapshot values since 2020: AGG about -18.4%, IEF about -23.9%, SPY about -33.7% (the March 2020 crash), TLT about -48.4%. Among the bond funds the ranking follows duration: the longer the duration, the greater the fall from the same rate rise. Even the aggregate bond index lost nearly a fifth.

7. The BTFP lent against collateral valued at par. Who bears the interest-rate loss on a bond that is worth 85 but pledged at 100? What incentive problem does it create?
   **Hint:** Think of it as a put option on the bond sold to the Fed.
   **Solution sketch:** The Fed holds collateral worth less than the loan, but the bank remains on the hook for the loan; the Fed is exposed only if the bank defaults. The bank gets cheap liquidity without crystallising its loss, which stops runs but weakens discipline about duration risk.

## Anti-patterns / Common mistakes

- "Treasuries are risk-free." Only default-risk-free. TLT lost about half its value with no default (Exercise 6).
- Ignoring the liability side. A bank's safety depends on who funds it and how fast they can leave; SVB's assets were mostly high-credit-quality (Exercise 4).
- Equating HTM with safe. HTM changes accounting, not market value; the first sale or forced pledge exposes it (Exercise 3).
- Quoting duration in years only. Use it as percent change per percentage point of yield, and convert `dy` to a decimal in code (Exercise 2).
- Using the global maximum for drawdown. Compare with the running peak, never the future one.

## Lab

From `economy_monetary_mastery/labs/`: open `day05/README.md`, implement the five functions in `day05/lab.py`, then run `uv run pytest day05` until green and `uv run python -m day05.lab` for the summary and `.cache/plots/day05.png`. Expected: all 5 tests pass; the summary shows SVB's 15.1bn mark and equity falling to 0.9bn, and TLT's roughly 48% drawdown.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: which of your own holdings (US bond ETFs, bank deposits, stablecoins, margin positions) is exposed to a "runnable" short-term funding source, and what would the haircut or drawdown have to be to hurt? Which part of SVB's story would you have caught from the 10-K footnote alone?
