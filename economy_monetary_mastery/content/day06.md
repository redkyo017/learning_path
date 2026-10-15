# Day 6 — Block 1 integration: case drill and quiz

> Block 1: Money & banking plumbing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Five days of parts: IOUs, bank deposits, the central bank, inflation, runs. Today you wire them into one machine and prove you can use it. The goal is a reflex: when you see a headline ("Fed ends QT", "bank X sees outflows", "real yields up"), you can say which balance sheets move, in which order, and which price is the messenger. The lab builds the Block 1 dashboard: Fed assets, reserves, policy rate, CPI and the real rate on one monthly table, with a stance label. Then you test yourself with a case drill, a quiz and the first three entries in your prediction journal.

## Core concepts

### The recap map: Days 1 to 5 as one chain

```
 Day 1  Issuer hierarchy      reserves/cash > bank deposits > money-fund claims/repo > securities
   |     (who promises to pay whom, at par?)
 Day 2  Bank money creation   loan +X  <->  deposit +X ; payments settle in reserves ;
   |     limits = capital, liquidity, demand (not "reserves first")
 Day 3  Reserves + corridor   the Fed supplies reserves, pays IORB (floor), lends at ceiling ;
   |     QE/QT and the TGA move reserves ; effective fed funds follows
 Day 4  Inflation + real rate nominal rate -> real rate = (1+i)/(1+pi) - 1 ; expectations (breakevens) ;
   |     compounding turns a rate into a purchasing-power path
 Day 5  Shadow banking + runs repo/MMFs fund markets ; duration + uninsured funding break banks ;
         the Fed backstops with lending at par (BTFP) and swap lines
```

Money is a promise (1). Banks make the most common promise by lending (2). Those promises settle on the central bank's ledger, whose price and quantity the Fed steers (3). Whether that price is tight or loose is measured against inflation, not in nominal terms (4). And promises that look like deposits but sit outside the insured system, or sit inside a bank with a maturity mismatch, can be run on (5). Each link has a function you wrote on its day: the T-account postings, the lending and run models, `overnight_rate`, `real_rate`, `max_drawdown`.

### Three questions to ask of any money event

- Whose balance sheet changes first, and what is the matching entry? (If you cannot balance it, you do not understand it.)
- Which settlement asset is involved: central-bank money, a deposit, or a claim that is only promised to be convertible?
- What price is the messenger (policy rate, repo rate, yield, haircut), and in real or nominal terms?

### What the dashboard measures

`plumbing_dashboard` combines the series you met on Day 3 and Day 4 into five monthly columns. Units are the whole game here, so write them down: `WALCL` is **millions** of USD (the lab divides by 1,000); `WRESBAL` is **millions** in the course snapshot too, so `main()` converts it to billions *before* calling the function, which expects billions; `DFF` and CPI inflation are percent in the data and decimals in the dashboard. The `real_rate` column is the exact Fisher rate from Day 4, and `stance` turns it into a label with a band of one percentage point.

One limitation to remember: the label looks only at the *price* of money. A year with a flat 0 percent policy rate and a balance sheet that grows by $2 trillion is "neutral" or "accommodative" by this label, yet the quantity channel did most of the work. The worked example makes that concrete.

## Worked example

March 2020, week by week, on the dashboard's inputs. Weeks end Wednesday (the H.4.1 day from Day 3); Fed assets and reserves in $ billions, from the snapshot.

| Week ending | Fed assets | Reserves | What happened |
|---|---|---|---|
| 2020-02-26 | 4,159 | 1,626 | Calm baseline. |
| 2020-03-04 | 4,242 | 1,699 | The FOMC cut by 0.5 point on 3 March ([press release](https://www.federalreserve.gov/newsevents/pressreleases/monetary20200303a.htm)); DFF fell from 1.59 to 1.09. |
| 2020-03-11 | 4,312 | 1,745 | 10-year yield hit 0.54 on 9 March (flight to safety), TLT (adjusted close) peaked at about 140. |
| 2020-03-18 | 4,668 | 1,896 | Emergency cut to a 0 to 0.25 range and at least $500 billion of Treasuries plus $200 billion of agency MBS ([15 March](https://www.federalreserve.gov/newsevents/pressreleases/monetary20200315a1.htm)); DFF 0.25. |
| 2020-03-25 | 5,254 | 2,187 | Purchases "in the amounts needed" ([23 March](https://www.federalreserve.gov/newsevents/pressreleases/monetary20200323b.htm)); swap lines widened to more central banks on 19 March ([press release](https://www.federalreserve.gov/newsevents/pressreleases/monetary20200319b.htm)). |
| 2020-04-01 | 5,812 | 2,534 | Balance sheet up about $1.65 trillion in five weeks. |

Read it with the Day 5 lens. In the week of 9 to 18 March the Treasury market did the opposite of a safe haven: the 10-year yield rose from 0.54 to 1.18 and TLT fell 15.7 percent from its 9 March peak to 18 March. Holders were selling the most liquid asset they had to raise dollars, a dash for cash, and dealers' balance sheets could not absorb it. The Fed's answer was to be the buyer and to lend dollars abroad through swap lines. The trough in SPY came on 23 March, down 33.7 percent from 19 February, the same day the Fed went to open-ended purchases.

What a $100 purchase from a pension fund does to balance sheets (Exercise 1 extends it to four):

```
   Federal Reserve
 Assets          | Liabilities
 Treasuries +100 | Reserves:A +100

        Bank A
 Assets          | Liabilities
 Reserves   +100 | Deposit:Fund +100

     Pension fund
 Assets          | Liabilities
 Treasuries -100 |
 Deposit    +100 |
```

Then the dashboard row for April 2020: assets $6,298 billion, reserves $2,895 billion, policy rate 0.05 percent, CPI inflation 0.31 percent, real rate -0.26 percent, label "neutral". The label is right about price (a real rate near zero) and silent about the huge quantity expansion. That gap is the lesson: always read the balance-sheet columns beside the stance.

The other case points from `main()` complete the picture: December 2008 +0.18 percent real (neutral, deflationary), June 2013 -1.59 percent (accommodative), June 2022 -7.13 percent (a 1.2 percent policy rate against 9.0 percent inflation), latest month (August 2026) +0.27 percent (neutral; this predates the September 2026 move of the target range to 3.75 to 4.00 percent, because September CPI is not yet out). October 2025 has no CPI print in the snapshot (the 2025 government shutdown cancelled that release), so `plumbing_dashboard` drops that month rather than filling it.

## Exercises

1. Draw every T-account when the Fed buys $100bn of Treasuries from a pension fund. Use four balance sheets: the Fed, the fund's bank (Bank A), the pension fund, and the Treasury. State which accounts change and which do not.
   **Hint:** Day 3 nonbank case; the fourth balance sheet is the borrower, ask what changed for it.
   **Solution sketch:** Fed: assets Treasuries +100, liabilities reserves:A +100. Bank A: assets reserves +100, liabilities deposit:fund +100. Pension fund: assets Treasuries -100 and deposit +100, no liability change. Treasury: nothing changes in its debt total (it still owes 100 of bonds, now to the Fed instead of the fund); future interest it pays the Fed flows back to the Treasury as Fed remittances. Net: reserves +100, deposits +100, the public holds less duration. Had Bank A been the seller, no deposit would exist.

2. Explain why reserves fell during 2022 and stayed around $3 trillion in 2023 even though the policy rate rose from 0.1 to over 5 percent. Name three liabilities of the Fed or the Treasury involved.
   **Hint:** Reserves are a residual of the Fed's balance sheet identity: assets minus other liabilities.
   **Solution sketch:** QT shrank assets, so liabilities shrank; the Treasury rebuilt its TGA at the Fed (a liability that competes with reserves); and ON RRP, the Fed's liability to money funds, absorbed cash when it paid more than other short rates. In the snapshot, monthly average reserves go from $3.89 trillion in January 2022 to $3.05 trillion in October 2022, while ON RRP usage rises from about $1.6 to $2.3 trillion by late 2022. From mid-2023 RRP usage drains (about $2.2 trillion in May 2023 to $1.5 trillion in September), cushioning reserves against QT, so reserves hold near $3.2 trillion. The policy rate is a price; reserves are a quantity determined by balance-sheet arithmetic.

3. A mock bank has reserves 10, Treasuries 20 and loans 70 (total assets 100), deposits 90 and equity 10. A run takes 30 percent of deposits. Is it a liquidity or a solvency event? Then redo it for a bank with reserves 5, Treasuries 5, loans 90, deposits 90, equity 10, if loans only sell at 80 cents on the dollar.
   **Hint:** Compare cash you can raise quickly with outflows, and check equity after the forced sales.
   **Solution sketch:** Outflow is 0.30 * 90 = 27. Bank 1 raises 10 + 19.6 = 29.6 (Treasuries sold at a 2 percent haircut; 30 at par), which covers it, with no loss to equity: pure liquidity stress, survived. Bank 2 has only 10 of liquid assets, so it needs 17 more from loans; at 0.8 it must sell 21.25 face value of loans and books a loss of 4.25, which is 42.5 percent of its equity (4.7 percent of its loans). Equity falls from 10 to 5.75 and it still faces 63 of deposits with no liquidity: a liquidity event is becoming a solvency event. A lender of last resort (Bagehot, Day 2: lend freely, at a penalty rate, against good collateral) lets the bank borrow instead of fire-selling; if it lends against the loans at par, as the BTFP did (Day 5), the 4.25 loss is avoided.

4. The dashboard says "restrictive" in late 2023 and "neutral" in April 2020, but the Fed was doing more in April 2020. Propose one extra column that fixes this and say which FRED series feeds it.
   **Hint:** Think quantity, and keep the unit consistent.
   **Solution sketch:** Add a balance-sheet change column, `fed_assets_busd.diff(12)`, the 12-month change in Fed assets, from `WALCL` divided by 1,000. In April 2020 it is about +$2.4 trillion ($6,298 billion against $3,933 billion in April 2019). Alternatively use the 12-month change in reserves from `WRESBAL`. A stance then has two coordinates (price and quantity), not one.

## Checkpoint quiz

Answer without looking back first, then check the key. Fifteen questions across Days 1 to 5.

1. (Day 1) Rank by reliability of settlement at par: a money-fund share, bank reserves, a Treasury bill, a commercial-bank deposit.
2. (Day 1) Alice banks with Bank A, Bob with Bank B. Alice pays Bob $30. Write the entries on both banks.
3. (Day 2) A bank approves a $50 loan. What are the two entries, and how much reserve did it need first?
4. (Day 2) The US reserve requirement ratio is 0 percent. Why is the textbook "money multiplier" still wrong, not just inactive?
5. (Day 2) A bank has assets 100 and liabilities 95, but only 5 of cash. Illiquid, insolvent, both or neither?
6. (Day 2) Which Basel III rule is aimed at a 30-day run, and which at funding 30-year mortgages with overnight money?
7. (Day 3) The Fed buys $100 of Treasuries from Bank A itself. What changes in deposits and in reserves?
8. (Day 3) `WALCL` reads 6,743,031. State it in dollars, and say what is wrong with plotting it directly next to ON RRP usage.
9. (Day 3) The Treasury raises $200 of bills from money funds and parks it at the Fed. What happens to reserves?
10. (Day 3) With ample reserves, which Fed rate acts as the floor, and what is the target range for fed funds in force on 17 September 2026?
11. (Day 4) Nominal 5 percent, inflation 3 percent. Exact real rate, and why is the shortcut `5 - 3` less accurate at 50 percent inflation?
12. (Day 4) At 7 percent, compare the rule of 72 with the exact doubling time.
13. (Day 4) A five-year breakeven (`T5YIE`) rises from 2.0 to 2.5 percent. What does it say, and is it a forecast?
14. (Day 5) A money fund lends $98 cash against $100 of Treasuries in an overnight repo. What is the haircut, and who bears the risk if the borrower defaults?
15. (Day 5) A bank's bond book with duration 6 sees yields rise 2 percentage points. Estimate the price change. Does classifying the bonds as held-to-maturity change the economic loss?

## Answer key

1. Reserves, then bank deposit, then money-fund share, then T-bill (securities are priced, not promised). Reserves settle everything; deposits are promised convertible into reserves; fund shares target par without a guarantee.
2. Bank A: reserves -30, deposit:Alice -30. Bank B: reserves +30, deposit:Bob +30. Settlement is in reserves at the central bank, exactly Day 1's transfer.
3. Loans +50 (asset), deposit:borrower +50 (liability). None up front: reserves are found afterwards to settle payments, so the loan creates the deposit.
4. Causality is reversed: banks lend first and borrow reserves later at the policy rate; loans are limited by capital, demand and profitability, not by a reserves-to-deposit ratio.
5. Solvent (equity 5) but illiquid (cash 5 against deposits 95, assuming the liabilities are deposits). If withdrawals today exceed 5 it cannot pay. A run can force fire sales that destroy the 5 of equity and make it insolvent too.
6. LCR (30-day high-quality liquid asset buffer) for the 30-day run; NSFR (one-year stable funding) for the maturity mismatch.
7. Reserves +100 at Bank A; Bank A's Treasuries -100; deposits unchanged. Only nonbank sales create deposits.
8. $6,743,031 million is $6.74 trillion. ON RRP usage is already in billions, so an unconverted WALCL is 1,000 times too large on the same axis.
9. Depends where the funds' cash sits: if it comes out of bank deposits, reserves fall 200; if it comes out of ON RRP, ON RRP falls 200 and reserves are unchanged (2023's pattern). Either way the TGA rises 200.
10. IORB (with ON RRP just below it for nonbanks). Target range 3.75 to 4.00 percent, IORB 3.90, from the [Fed implementation note of 16 September 2026](https://www.federalreserve.gov/newsevents/pressreleases/monetary20260916a1.htm), effective 17 September.
11. 1.05 / 1.03 - 1 = 1.94 percent. The shortcut gives 2.00. The gap is the cross-term and it grows with inflation: at 50 percent inflation and 60 percent nominal, exact is 6.7 percent, not 10.
12. Rule of 72: 72 / 7 = 10.3 years. Exact: ln 2 / ln 1.07 = 10.24 years. Close at moderate rates, increasingly off at very low or very high rates.
13. Market-implied expected average inflation over five years, plus a risk premium, rose by 0.5 point: the market now prices higher inflation (or a bigger inflation-risk premium). One move does not show expectations are unanchored, and it is a market price, not a forecast.
14. Haircut 2 percent (100 - 98 over 100). If the borrower defaults the lender keeps the collateral and bears the risk of selling it for less than 98; the bigger the haircut, the more cushion.
15. About -6 * 2 = -12 percent. No: HTM changes the accounting, not the cash value; if depositors force a sale the loss is realised (Day 5).

## Prediction journal: your first three claims

Start `journal.md` (course root) with three dated claims. The format: claim, probability, resolution source and date. You will score them in Day 30 with the Brier score, `(p - outcome)^2` averaged, lower is better; 0.25 is what always saying 50 percent earns.

- Claim 1: DFF on 2027-03-31 is below its 2026-09-30 value of 3.88 percent. Probability 50 percent. Resolves with [FRED DFF](https://fred.stlouisfed.org/series/DFF). Reason: DFF stood at 4.09 on 2025-09-30 and 3.88 a year later, but the snapshot shows DFF stepping up from 3.63 to 3.88 on 2026-09-17, after the 16 September 2026 decision to a 3.75 to 4.00 range. Inflation is 3.35 percent and rising from its 2026 low, so the claim is a coin-flip.
- Claim 2: US CPI inflation (YoY, [CPIAUCSL](https://fred.stlouisfed.org/series/CPIAUCSL)) for December 2026 is above 3.0 percent. Probability 60 percent. The snapshot's August 2026 reading is 3.35 percent; the claim is a persistence bet.
- Claim 3: Every weekly `WRESBAL` reading up to 2027-03-31 is above $2.7 trillion. Probability 75 percent. The latest is $2.95 trillion, QT has ended (Day 3), and the Fed says it wants ample reserves.

Explain each in a sentence: what would make you wrong, and which Day 1 to 5 mechanism you are betting on.

## Anti-patterns / Common mistakes

- Reading `stance` as the whole story. It is price only (Exercise 4).
- Feeding `plumbing_dashboard` a reserves series in millions. The function takes billions; the snapshot is in millions, so convert before calling.
- Mixing frequencies by `join` without resampling. Weekly, daily and monthly series need one month-end grid first.
- Using the nominal rate as the stance. A 5 percent policy rate with 9 percent inflation is loose, not tight.
- Treating a liquidity run as proof of insolvency (or the reverse) without checking the T-account (Exercise 3).

## Lab

From `economy_monetary_mastery/labs/`: open `day06/README.md`, implement `stance` and `plumbing_dashboard` in `day06/lab.py`, then run `uv run pytest day06` until green and `uv run python -m day06.lab` for the last twelve months, the five case points and `.cache/plots/day06.png`. Expected: all 6 tests pass; the case points print as accommodative in 2013 and 2022 and neutral in 2008, 2020 and the latest month.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: which of the five days changed your mental model of money most, and what picture or T-account would you now draw to explain it to a colleague? Which quiz question did you get wrong, and what did you misread: a unit, a direction of causality, or a definition? Add your three dated claims to `journal.md`.
