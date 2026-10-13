# Day 3 — Central banks: rate corridor, QE, H.4.1

> Block 1: Money & banking plumbing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 2 ended on a promise: banks create deposits by lending, then find the reserves to settle payments, and reserves are supplied "at the central bank's policy rate". Today you see how. The central bank does not hand out a fixed quantity of money; it runs a balance sheet whose size and pricing steer one overnight interest rate, and every other price in this course (bonds on Day 7, equities and DCF on Day 8, perpetual-futures funding on Day 23) is quoted off that rate. You also learn to read the Fed's weekly balance sheet, which is the cleanest "liquidity" dataset there is, and to avoid the two classic misreadings: QE is not printed money handed to the public, and WALCL is not in the units you think.

## Core concepts

### The central bank's balance sheet

Same notation as Day 1. The Fed is a bank whose customers are banks, the Treasury and foreign central banks.

```
        Federal Reserve
  Assets                       | Liabilities + capital
  Securities (Treasuries, MBS) | Currency in circulation
  Loans (discount window, repo)| Bank reserves (deposits of banks at the Fed)
  FX / gold / other            | Treasury General Account (TGA)
                               | Reverse repo (ON RRP: money funds' cash)
```

Reserves, currency and the TGA are the "base" the system settles in (rung one of Day 1's hierarchy). Two consequences you will use constantly. First, the Fed cannot change one liability without changing something else: if the Treasury moves cash into the TGA, reserves fall. Second, the Fed's total size is an outcome of what it buys plus what the public demands, not a dial on its own.

### Setting the price: corridor vs floor

The Fed steers the effective federal funds rate (a market rate banks trade at; the Fed influences it, it does not dictate it) with administered rates:

- Ceiling: the rate at which the Fed lends against collateral without limit. That is the primary credit rate at the discount window, and since 2021 the standing repo facility (SRF).
- Floor: the rate the Fed pays. Interest on reserve balances (IORB) pays banks; the overnight reverse repo facility (ON RRP) pays money funds and others who cannot earn IORB.

The rate in between depends on how scarce reserves are. Before 2008 reserves were tiny, so banks bid for them every day and the rate wandered inside the corridor (the Fed nudged supply with open-market operations). After 2008 QE made reserves abundant; banks had no reason to trade below what the Fed paid them, so the Fed moved to an "ample reserves" floor system: set IORB and ON RRP, and the market rate sits just under or at them regardless of the exact reserve quantity. Interest on reserves has been paid since late 2008; IORB took that name on 2021-07-29 when it replaced the old IOER and IORR rates, which is why the `IORB` series in FRED begins that day. Pre-2021 charts must use IOER instead. The lab's `overnight_rate` is this picture as one formula: flat at IORB when reserves are at or above a satiation level, climbing toward the ceiling as they fall.

### Open-market operations, QE and QT

An open-market operation (OMO) is the Fed buying or selling securities (outright) or lending against them (repo) to change reserves. Quantitative easing (QE) is OMO at scale and on long bonds, used when the policy rate is stuck near zero. Quantitative tightening (QT) is the reverse: letting securities mature without replacing them.

QE depends on who sells. A pension fund (nonbank) sells $100 of Treasuries:

```
        Federal Reserve
  Assets             | Liabilities
  Treasuries   +100  | Reserves:A  +100

        Bank A
  Assets             | Liabilities
  Reserves     +100  | Deposit:Fund +100

        Pension fund
  Assets             | Liabilities
  Treasuries   -100  |
  Deposit      +100  |
```

The fund swaps a bond for a deposit; its bank is the conduit and gets reserves and a matching new deposit. Reserves and deposits both rise. If instead Bank A itself sells the bond:

```
   Federal Reserve                         Bank A
 Assets          | Liabilities        Assets            | Liabilities
 Treasuries +100 | Reserves:A +100    Reserves   +100   | (nothing)
                                      Treasuries -100
```

One asset is swapped for another; reserves rise, deposits do not. Both cases are your `qe_postings`.

So why is QE not "printing money into the economy"? Reserves are only usable between banks and the Fed; they cannot be lent to you. Broad money (deposits, Day 2) rises only in the nonbank case, and spending rises only if someone then borrows or spends more. What QE reliably does is remove duration (long bonds) from private hands, which lowers long yields and lifts other asset prices (the channel investors care about), and it makes reserves abundant. QT runs the logic backwards, mostly through the TGA: when a Treasury bond matures and the Treasury refinances by selling to the public, buyers pay with deposits, banks pay with reserves, and reserves fall.

### Reading the Fed's data

The [H.4.1 release](https://www.federalreserve.gov/releases/h41/) is the Fed's balance sheet, published weekly, with Wednesday levels. Four FRED series cover most of what you need:

- [`WALCL`](https://fred.stlouisfed.org/series/WALCL): Fed total assets. Units: **millions** of USD, so divide by 1,000 for billions. The snapshot's last value, 6,743,031, is $6.74 trillion.
- [`WRESBAL`](https://fred.stlouisfed.org/series/WRESBAL): reserve balances at the Fed. It is also in millions (2,948,090 is $2.95 trillion), so `main()` divides by 1,000. Check the unit of every series before you plot two together.
- [`RRPONTSYD`](https://fred.stlouisfed.org/series/RRPONTSYD): ON RRP **usage**, in billions of USD per day. It is a quantity, not a rate.
- [`IORB`](https://fred.stlouisfed.org/series/IORB): the interest rate on reserves, percent, from 2021-07-29.

Add [`DFF`](https://fred.stlouisfed.org/series/DFF) (daily effective fed funds, percent) and the [TGA, `WTREGEN`](https://fred.stlouisfed.org/series/WTREGEN) (not in the course snapshot; fetch with `load_fred("WTREGEN", live=True)`). The weekly Wednesday grid is why the lab's `align_weekly` resamples to `W-WED`.

### The State Bank of Vietnam at a glance

The SBV also steers rates, but with a different mix. Its policy rates include a refinancing rate and a rediscount rate (loans against collateral), and it conducts open-market operations with commercial banks. It has also used credit growth quotas (annual caps per bank, Day 2) and intervenes in the foreign-exchange market to guide the dong's reference rate (preview of Day 16). Verify: the refinancing rate was reported unchanged at 4.50% in the first half of 2026 (a secondary source, [DBS via FXStreet](https://www.fxstreet.com/news/vietnam-supportive-stance-as-inflation-risks-recede-dbs-202607071949); the [SBV site](https://www.sbv.gov.vn) could not be reached to confirm, so treat it as unverified as of 2026-10 until you check there).

### Verify (as of 2026-10)

- Target range 3.75 to 4.00 percent, IORB 3.90, ON RRP offering rate 3.75, primary credit 4.00 and standing repo 4.00, all effective 17 September 2026: [Fed implementation note of 16 September 2026](https://www.federalreserve.gov/newsevents/pressreleases/monetary20260916a1.htm). The snapshot agrees: DFF 3.88 and IORB 3.90 on 2026-09-30.
- Fed total assets: $6.74 trillion on 2026-09-30 (WALCL snapshot; peak $8.97 trillion, week of 2022-04-13).
- QT status: runoff ended. The FOMC [announced on 29 October 2025](https://www.federalreserve.gov/monetarypolicy/policy-normalization.htm) that it would stop runoff from 1 December 2025. On 10 December 2025 it [directed the Desk to begin reserve management purchases (RMPs)](https://www.newyorkfed.org/markets/opolicy/operating_policy_251210a), mainly of Treasury bills, to maintain an ample level of reserves: the first schedule was about $40 billion in bills, with purchases starting 12 December 2025, alongside reinvesting all agency principal paydowns into bills. Powell described this as not QE (his press-conference characterisation, not stated on the linked page). The difference is the purpose: QE aims to ease financial conditions by removing duration, RMPs just keep reserves ample as currency and the TGA grow. WALCL has risen from 6,536 (2025-12-03) to 6,743 (2026-09-30). The current monthly pace is not verified (unverified as of 2026-10).
- SBV refinancing rate 4.50 percent: see above (unverified as of 2026-10).

## Worked example

September 2019: the repo-rate spike. Treasury settlement and corporate tax dates pulled cash out of banks on 16 September; the overnight rate jumped. In the snapshot, DFF went from 2.14 on 15 September to 2.25 on the 16th and 2.30 on the 17th, above the then-IOER of 2.10, and reserves (`WRESBAL`) had fallen from about $1.55 trillion in August to $1.39 trillion on 18 September, down about $0.16 trillion after QT and a large TGA build. The market was no longer sitting on the floor.

Use the lab's function with stylised numbers: IORB 2.10, ceiling 2.75 (the primary credit rate at the time: top of the 2.00 to 2.25 range plus 50 basis points), and an illustrative satiation of $2,000 billion:

```python
overnight_rate(1394.1, iorb=2.10, ceiling=2.75, satiation=2000.0)   # about 2.30
overnight_rate(2000.0, iorb=2.10, ceiling=2.75, satiation=2000.0)   # exactly 2.10
```

A satiation of 2,000 is chosen only because it reproduces 2.30; it is a fit, not an estimate, and real satiation is unobservable until the rate misbehaves. The lesson is the shape: nothing changes on the floor until reserves cross a threshold, then the rate responds fast. The real overnight repo rate went beyond even the ceiling (SOFR, a different rate, printed above 5 percent that week; check the series) because banks would not borrow at the discount window for fear of stigma. That is why the Fed created the SRF in 2021: a ceiling that firms actually use. Run `uv run python -m day03.lab` and compare 2019's row (reserves $1.65 trillion, fed funds 1.55 percent at year-end) with the latest one (reserves $2.95 trillion, fed funds 3.88 vs IORB 3.90).

## Exercises

1. With `iorb=3.90, ceiling=4.00, satiation=2500`, what does `overnight_rate` give for reserves of 2,000 and 1,000? What does that say about quantity in a floor system?
   **Hint:** Use the scarce-branch formula `ceiling - (ceiling - iorb) * reserves / satiation`.
   **Solution sketch:** 4.00 - 0.10 * 0.8 = 3.92 at 2,000 and 4.00 - 0.10 * 0.4 = 3.96 at 1,000. In a floor system the rate barely moves until reserves fall well below satiation, and even at 40 percent of satiation it is only six basis points above IORB.

2. Draw the T-accounts when the Fed buys $50 of Treasuries from a hedge fund whose bank is Bank B, then again when it buys them from Bank B itself. Which case adds to the deposit supply?
   **Hint:** Follow Day 2: where do reserves sit and who owes the deposit?
   **Solution sketch:** Hedge fund case: Fed assets Treasuries +50, reserves:B +50; Bank B reserves +50, deposit:fund +50; fund Treasuries -50, deposit +50. Bank case: Bank B reserves +50, Treasuries -50, no deposit. Only the nonbank case adds deposits (broad money); both add reserves.

3. The Treasury sells $200 of bills to money funds and keeps the cash in its TGA at the Fed. Show what happens to the funds' bank, the Fed and reserves. Why can this undo some of QE?
   **Hint:** The buyers pay with deposits; the Treasury's account is at the Fed, not a commercial bank.
   **Solution sketch:** Buyers' deposits fall by 200 at their banks, and the banks' reserves fall by 200; the Fed's TGA liability rises by 200. Fed assets are unchanged, reserves are 200 lower. So when the Treasury rebuilds its account, reserves fall without any Fed decision, the same effect as QT; spending the TGA later reverses it.

4. WALCL reads 6,743,031 on the last snapshot day. State the value in dollars with a sensible unit. What if you assume it is in billions? How does that show up when you plot WALCL against WRESBAL?
   **Hint:** Millions to billions is a factor of 1,000.
   **Solution sketch:** $6,743,031 million = $6,743 billion = $6.74 trillion. Read as billions it would be $6.7 quadrillion, many times world GDP. Plotted next to a series that really is in billions (ON RRP usage), an unconverted WALCL is off by a factor of 1,000, so check every unit.

5. In QT, the Fed lets $60 of Treasuries mature. The Treasury pays from its TGA and then refinances by issuing $60 of new bills to the public. Show the net effect on Fed assets, reserves and deposits.
   **Hint:** First the Treasury pays the Fed from its account; then the public buys bills.
   **Solution sketch:** Fed assets -60 (bond gone), TGA -60 for the payment, then the new bills' buyers pay: deposits -60, reserves -60 at the banks, TGA +60. Net: Fed assets -60, reserves -60, TGA unchanged, deposits -60 at banks. QT shrinks reserves and the public's deposits.

6. Someone says "the Fed printed $4 trillion in QE, so M2 should have risen by $4 trillion". Name three reasons this fails.
   **Hint:** Who sold the bonds, and what are reserves usable for?
   **Solution sketch:** Reserves are not M2 (they are held by banks at the Fed, not the public). Sales by banks add reserves but no deposits. Nonbank sales add deposits one for one, with no multiplication on top, because loans, not reserves, create deposits (Day 2). Compare with the `M2SL` series, which is also in the snapshot.

7. The SBV caps one bank's credit growth at 14 percent but its refinancing rate stays at 4.5 percent. Which tool is a price and which is a quantity? Which does the Fed mostly rely on?
   **Hint:** Compare with the Fed's corridor.
   **Solution sketch:** The refinancing rate is a price; the quota is a quantity rationing loans, regardless of price. The Fed steers a price (rates on reserves) and lets banks decide quantity; quotas are a blunt tool whose downsides (misallocation, shadow lending) are a Day 16 topic.

## Anti-patterns / Common mistakes

- Equating QE with M2 growth. QE creates reserves; M2 counts deposits and cash held by the public. They can diverge for years (Exercise 6).
- Ignoring the TGA. The Treasury's account at the Fed moves hundreds of billions and moves reserves, and so liquidity-driven asset moves, with no change in WALCL (Exercise 3).
- Reading WALCL's units wrong. Millions, not billions; and check WRESBAL in your own snapshot (Exercise 4).
- Treating RRPONTSYD as a rate. It is a volume in billions; the ON RRP rate is a different administered number.
- Plotting IORB before 2021-07-29. It does not exist then; the Fed paid IOER.
- Saying the Fed "sets" the fed funds rate. It sets IORB and ON RRP (and the ceiling rates); the market rate follows.

## Lab

From `economy_monetary_mastery/labs/`: open `day03/README.md`, implement `overnight_rate`, `qe_postings` and `align_weekly` in `day03/lab.py`, then run `uv run pytest day03` until green and `uv run python -m day03.lab` for the summary and `.cache/plots/day03.png`. Expected: all 10 tests pass; the printed table shows reserves peaking in the QE era, ON RRP usage near zero now, and fed funds a hair under IORB.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: if reserves are ample, why can the Fed move the market rate by changing only IORB? Which of its tools would you expect to matter most if reserves became scarce again? Which liability on the Fed's balance sheet did you underestimate before today?
