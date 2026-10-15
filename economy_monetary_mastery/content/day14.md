# Day 14 — The dollar system: reserve currency, eurodollars

> Block 3: FX, the dollar & Vietnam. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 13 treated an exchange rate as a price between two currencies. The dollar is not one currency among many: it is the unit most of the world prices, borrows and saves in. When US rates rise or investors get scared, the whole system feels it, whether or not the country has any trade with America. Your USD/VND quote, every US ETF you hold, the USDT in your crypto account and the cost of credit in emerging markets all sit on top of this system.

Two ideas matter today. First, the dollar is a *funding* currency as much as a trading currency: a huge stock of dollar debt is owed by borrowers who do not earn dollars, so a stronger dollar tightens financial conditions worldwide. Second, "the dollar" has no single price. Which index you look at changes the story, and the standard tool for asking "what does the dollar do when X happens?" is the event study, whose traps are as important as its mechanics. The lab builds one.

## Core concepts

### Why the dollar is the reserve currency

A reserve currency is one that other countries hold, invoice in and borrow in. Four reinforcing reasons:

- **Invoicing.** Most trade is priced in a few "dominant" currencies, and the dollar dominates. In the Gopinath et al. data the dollar's share as an invoicing currency is about 4.7 times its share of world imports, while the euro's is close to 1 ([NBER, Dominant Currency Paradigm](https://www.nber.org/system/files/working_papers/w22943/w22943.pdf)). One estimate: a 1% broad dollar rise cuts the volume of trade among the rest of the world by about 0.6% within a year ([NBER, Global Trade and the Dollar](https://www.nber.org/system/files/working_papers/w23988/w23988.pdf)).
- **Debt.** Non-bank borrowers outside the US owe roughly $13 trillion in dollar credit ([Atlanta Fed, 2024](https://www.atlantafed.org/-/media/documents/research/publications/policy-hub/2024/05/15/02--offshore-dollar-and-us-policy.pdf); [BIS Quarterly Review, Dec 2022](https://www.bis.org/publ/qtrpdf/r_qt2212h.htm) puts it at $13.4 trillion at end-March 2022 and adds that dollar debt hidden in FX swaps and forwards may be as large again). No newer BIS total was confirmed in the sources used.
- **Reserves.** Central banks keep their safety buffer mostly in dollars. The IMF's COFER data put the dollar at [57.13% of allocated reserves in 2026Q1, up from 56.42%](https://data.imf.org/en/news/imf%20data%20brief%20july%201) (total reserves $13.10 trillion). A Central Banking report gives about 56.7% for 2026Q2 on 2026-09-30; the IMF's own Q2 release was not confirmed in the sources used. The share was near 71% in 1999-2000; the drift is down, and much of a quarter's move is valuation (Exercise 6).
- **A deep, safe market to hold them in.** US Treasuries are the largest, most liquid pool of safe assets, with a legal system that enforces claims on them. Day 7's yield curve sits on this foundation. No other market lets a reserve manager sell billions in a day without moving the price.

Valéry Giscard d'Estaing, then French finance minister, called the benefits an **exorbitant privilege** in the 1960s: the US borrows cheaply, runs persistent deficits financed by foreign buyers of Treasuries, and, because its external liabilities are in its own currency, a falling dollar does not raise the real burden of its debt.

### Eurodollars: dollars outside the US

A **eurodollar** has nothing to do with the euro. It is a US-dollar deposit held at a bank *outside* the United States (or at a foreign branch), a market that began in London in the 1950s. The dollar itself never leaves the US banking system: what changes is who owes whom.

```
Step: a Japanese exporter is paid $100 and deposits it at a London bank.

        London Bank                                  US correspondent bank
  Assets          | Liabilities                 Assets | Liabilities
  Claim on US     | Deposit:                    Cash   | Deposit:
  bank  +100      |   Exporter +100                    |   London Bank +100
```

The London bank can lend the $100 to a Brazilian firm, and the dollar balance at the US correspondent moves again. Offshore banks have no Fed account of their own, so in a panic they cannot simply borrow from it. Modern offshore dollar credit is mostly bonds and FX swaps rather than deposits, but the principle is the same.

The **global dollar funding structure** therefore has a hole in its roof. Non-US banks fund dollar loans by borrowing dollars short-term, often in the FX swap market from Day 13 (borrow euros, swap into dollars, roll every few months). When confidence falls, the swap market demands a premium, the cross-currency basis widens, and borrowers must find dollars or sell assets. Raising dollars means *buying* dollars, which strengthens the dollar and worsens the squeeze.

### Fed swap lines and the FIMA repo facility

The Fed is the only institution that can create dollars, so in a squeeze it lends them to other central banks. In a **swap line** the foreign central bank hands the Fed its own currency at today's rate and gets dollars, with a reversal at the same rate later, so the Fed carries no exchange-rate risk:

```
Step 1: ECB draws $50bn, giving euros at today's rate; ECB then lends the dollars to euro-area banks.

        Fed                                      ECB
  Assets        | Liabilities               Assets            | Liabilities
  Euros         | Reserve balance:          Claim on euro-    | Euros owed to
   (from ECB)   |   ECB +50bn               area banks (USD)  |   Fed (swap)
```

As of 2026-10 the [Fed lists five central banks with standing swap lines](https://www.federalreserve.gov/monetarypolicy/central-bank-liquidity-swaps.htm): the Bank of Canada, the Bank of England, the Bank of Japan, the European Central Bank and the Swiss National Bank. In March 2020 the Fed also opened temporary lines with nine more central banks (including Brazil, South Korea and Mexico); the Fed page describes them as extended only through December 31, 2021, so treat them as lapsed. Most emerging economies, including Vietnam, have no line at all (Day 16 returns to what that means for Vietnam).

The **FIMA repo facility** covers the others: foreign central banks holding Treasuries at the New York Fed can swap them for dollars overnight rather than sell them into a falling market. The [Fed describes it](https://www.federalreserve.gov/monetarypolicy/fima-repo-facility.htm) as temporary from March 2020 and standing since July 28, 2021. It matters because forced Treasury sales by reserve managers would push US yields up in exactly the wrong moment.

### The dollar smile

The dollar tends to rise in two opposite situations and fall in the middle:

```
dollar value
 high |  *                              *
      |    *                          *
 low  |        *   *   *   *   *    *
      +-------------------------------------
        US/global     steady global     US outperforms
        panic          growth           (rates, growth)
```

On the left, crises send money into the dollar as a safe haven and dollar funding gets scarce. In the middle, calm global growth lets money chase returns elsewhere and the dollar weakens. On the right, a strong US economy and high US rates pull money in. It is a stylised pattern, not a law, with few episodes: the left side is 2008 and March 2020, the right side 2014-2015 and 2022. In the lab's data the broad index rose about 4% (91.4 to 94.9) in the 2013 taper tantrum, and rose about 11% from end-2021 to its 2022-09-26 peak of 128.5.

### Strong-dollar cycles and EM stress

EM borrowers owe dollars and earn local currency, so a rising dollar raises their debt burden and their funding cost at once. The pattern: capital leaves EM, currencies fall, dollar debt gets heavier, central banks defend with rate hikes, growth suffers. Day 15 covers crises; markers in the lab data (local currency per USD):

- **1980s:** the Volcker rate hikes, the dollar peak of 1985 and the Latin American debt crisis (before the lab's broad-index data begins).
- **1997:** the Korean won went from about 915 per dollar on 1997-10-01 to 1,960 on 1997-12-23 (FRED DEXKOUS), a near-doubling in under three months.
- **2013 taper tantrum:** when the Fed signalled it would slow bond purchases, the Brazilian real fell from 2.01 to 2.32 per dollar between 2013-05-01 and 2013-09-05 and the Indian rupee from 53.7 to 68.8 by 2013-08-28, while the *broad* dollar index rose only about 4% (91.4 to 94.9). EM stress can be large when the headline dollar barely moves.
- **2022:** the fastest US hikes in 40 years. Broad dollar +11% to its September peak, but the year-end picture was mixed: by December 30, the Korean won was 6.0% weaker per dollar, the rupee 11.2% weaker, while the Brazilian real and Mexican peso were each about 5% *stronger*. Dollar strength is not one trade.

### Dollar indices: DXY versus the broad index

The **DXY** (ICE US Dollar Index, 1973) is a geometric average against six currencies with fixed weights: euro 57.6%, yen 13.6%, pound 11.9%, Canadian dollar 9.1%, krona 4.2%, franc 3.6% ([summary of the ICE basket](https://en.wikipedia.org/wiki/US_Dollar_Index)). It has changed once (1999) and contains no yuan or peso. The Fed's **broad dollar index** ([FRED DTWEXBGS](https://fred.stlouisfed.org/series/DTWEXBGS), daily, base January 2006 = 100) weights 26 currencies by trade: in the [2026 weights](https://www.federalreserve.gov/releases/h10/weights/) the euro area is 21.0%, Mexico 14.8%, Canada 12.8%, China 10.9%, UK 5.2%, Japan 5.2%. So a 1% euro move shifts DXY about 0.58% but the broad index only about 0.21%, and the peso is nearly invisible to DXY yet bigger than the yen in the broad index. Use DXY for the dollar against rich-world currencies, the broad index for the dollar against US trading partners.

### Event studies: the method

An **event study** answers "what do prices do around dated events?" without a model. Steps: list the event dates; for each, take a window of relative days (`-before..after`); express each window as the cumulative return versus the event day (so day 0 = 0); then average across events. The lab's `event_window` and `average_path` do exactly this.

Pitfalls:

- **Overlapping events.** If windows overlap, the same price move is counted twice and the "independent" events are not independent. The 2022 hike dates are 6-9 weeks apart and ±20-day windows touch only slightly; weekly events with ±20-day windows would not be usable.
- **Look-ahead.** The event list must be fixed by a rule known at the time. "FOMC decision days" is a rule; "the 7 days the dollar jumped" is not.
- **Cherry-picking.** Choosing a convenient window, or only the events that fit the story, makes any pattern appear. Fix the dates and windows before looking.
- **Few events.** Seven events give a wide error bar; report the standard error.
- **Timing within the day.** The FOMC statement comes at 2 pm New York time, but the Fed's broad index is built from noon rates, so the immediate reaction shows up on day +1, not day 0. Match the window to the series.
- **Anticipation.** Markets move before the event if it is expected (Day 11's "priced in"). A flat day 0 does not mean no effect.

## Worked example

Did the broad dollar react to the Fed's 2022 hikes? The seven decisions, from the [Fed's FOMC calendar](https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm) (decision day is the second day of the meeting) and the [target-range history](https://www.federalreserve.gov/monetarypolicy/openmarket.htm): 2022-03-16, 05-04, 06-15, 07-27, 09-21, 11-02, 12-14. (The Fed's rate table lists the next day as the effective date, so dates shifted by one day are a common copying error.) The lab runs `event_window(DTWEXBGS, events, 20, 20)` and averages:

```
trading days from decision    -20     -10      -5      -1       0      +1     +10     +20
average broad dollar vs day 0  -1.4%   -0.5%   -0.6%   +0.0%    0.0%   -0.0%   -0.7%   -0.6%
```

Read it carefully. The index was 1.4% *lower* 20 trading days before the decision: the dollar rose into the hikes. From day 0 to day +1 the average is flat (the hikes were expected, and the noon fixing on day 0 predates the announcement). Twenty trading days later it is 0.6% lower than on the decision day, but the individual outcomes at day +20 range from -4.2% (November) to +1.8% (September), only 3 of 7 are positive, and the standard error of the mean is about 0.8%. A t-statistic below 1 is no evidence of a systematic reaction in either direction. The reading is the "priced in" one from Day 11: the dollar rallied as markets priced the *path* of hikes, then gave back some as the path flattened.

Second output, the dollar beta of daily changes in local-currency-per-USD against the broad dollar, 2006-2026:

```
KRW +1.06   BRL +1.68   INR +0.56   THB +0.58   MXN +1.57
```

A beta of 1.68 for BRL means that when the broad dollar rises 1% in a day the real weakens, on average, 1.68%. These betas are averages over calm and stress, and the peso beta is partly mechanical because Mexico is 14.8% of the broad index. In 2022 alone the betas were lower for KRW (0.70), BRL (1.34), INR (0.40) and MXN (1.19); THB was 0.93.

## Exercises

1. A 1% rise of the euro against the dollar (all else equal): approximately how much does DXY fall, and how much the broad index (using the weights above)?
   **Hint:** each index moves by its euro weight times the euro move.
   **Solution sketch:** DXY falls about 0.576 x 1% = 0.58%; the broad index about 0.21 x 1% = 0.21%, because the euro area is 21.0% of the trade weights. The broad index is less than half as sensitive; DXY is a bet on the euro.

2. A series is 100, 102, 101, 104, 103, 107 on consecutive days and the event is the third day (101). Compute the window with `before=2, after=2` by hand.
   **Hint:** value[pos+k] / value[pos] - 1; day 0 is 0.
   **Solution sketch:** days -2..+2 give 100/101-1 = -0.99%, 102/101-1 = +0.99%, 0%, 104/101-1 = +2.97%, 103/101-1 = +1.98%. The sixth value (107) is outside the window.

3. BRL has a dollar beta of 1.68. The broad dollar rises 2% in a week and BRL starts at 5.00 per USD. Where does the beta predict BRL ends, and give two reasons the real number could differ.
   **Hint:** the beta is on percent changes of local-per-USD.
   **Solution sketch:** +2% x 1.68 = +3.36%, so 5.00 x 1.0336 = 5.17 per USD. The outcome differs because the beta is an average that shifts with the regime (2022 alone: 1.34), and Brazil-specific news moves BRL independently.

4. The seven day +20 outcomes after the 2022 hikes are -0.5%, -1.2%, +1.5%, +0.2%, +1.8%, -4.2%, -2.2%. A colleague reports "the dollar fell after Fed hikes" using only the three events with large declines. What is wrong, and what would you report?
   **Hint:** report four things: all events, the mean, the spread, the count.
   **Solution sketch:** Choosing events after seeing outcomes is cherry-picking. Report all seven: mean -0.64%, standard deviation about 2.1%, standard error 0.8%, 3 positive of 7. That does not reject "no effect". A claim needs a rule fixed beforehand and more events.

5. A Korean bank holds $100 bn of dollar loans funded by 3-month FX swaps rolled every quarter. In a stress the cross-currency basis moves from -20 bp to -70 bp annualised. By how much does its annual funding cost change, and what does a Fed swap line do about it?
   **Hint:** annual cost = notional x basis change.
   **Solution sketch:** Extra cost = $100 bn x 0.50% = $0.5 bn a year if the move persisted. Korea has no standing line, so the bank must find dollars in the market or from the Bank of Korea's reserves; with a line, the central bank would lend dollars at a fixed rate and limit the premium (the 2020 temporary lines are the precedent).

6. COFER shows a 57.13% dollar share of $13.10 trillion of reserves. If the dollar falls 5% against all other currencies and nobody trades, what is the new share?
   **Hint:** dollar assets stay fixed in dollars; non-dollar assets are worth 5% more in dollar terms.
   **Solution sketch:** Dollar assets 7.48 trillion; non-dollar 5.62 x 1.05 = 5.90; total 13.38; share 55.9%, down 1.2 points with no selling. A falling share can be mostly valuation.

7. Lab extension: recompute `dollar_beta` on 2006-2012 and 2013-2026 and compare. What changes, and which alternative explanation do you rule out by using the same function on both?
   **Hint:** slice the returns frame by date before the call.
   **Solution sketch:** Betas are close in both halves: BRL 1.82 vs 1.58, MXN 1.39 vs 1.72, KRW 1.13 vs 1.01, THB 0.37 vs 0.75, INR 0.67 vs 0.47. The link is stable for BRL, MXN and KRW, less so for THB and INR. One function and definition rules out a method difference.

## Anti-patterns / Common mistakes

- Treating DXY as "the dollar". It is 57.6% euro and omits China and Mexico; the broad index is the better measure of trade-weighted dollar strength (Exercise 1).
- Ignoring offshore dollar debt. A country with a trade surplus and no US exports can still be squeezed by a dollar rise through its borrowers' dollar liabilities (Eurodollars section).
- Cherry-picking event dates or windows. Fix the rule first, report all events, show the error bar (Exercise 4).
- Reading a flat day 0 to +1 as "no effect". An anticipated event moves prices earlier (the dollar rose into the hikes).
- Assuming one dollar beta for all conditions. Betas shift between calm and stress, and some currencies are managed (Exercise 7).

## Lab

From `economy_monetary_mastery/labs/`: open `day14/README.md`, implement the three functions in `day14/lab.py`, then run `uv run pytest day14` until green and `uv run python -m day14.lab` for the summary and `.cache/plots/day14.png`. Expected: all 4 tests pass; the summary shows the average broad-dollar path around the seven 2022 FOMC hikes and the five dollar betas above.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: list which of your holdings (a US ETF, a Vietnamese stock, a coin) would suffer most in a "left side of the smile" dollar panic, and whether any of them is itself funded or priced in dollars through the Day 13 channels. Then write down the rule you would fix in advance before testing any dollar-and-X relationship.
