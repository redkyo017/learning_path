# Day 1 — What money is: IOUs and T-accounts

> Block 1: Money & banking plumbing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Every later day is a balance-sheet change plus a price. If you can draw who owes whom before and after an event, banks, central banks, bonds, stablecoins and FX stop being vocabulary and become bookkeeping you can code. Today you build the notation (the T-account) and the habit (every money event touches at least two balance sheets), then run your first lab.

## Core concepts

### Money is a transferable IOU

An IOU is a promise: "I owe you X." Money is an IOU that other people accept as payment for their own debts, so it can be passed along instead of being collected. A bank deposit is the bank's IOU to you. A banknote is the central bank's IOU to whoever holds it. A Treasury bill is the government's IOU. They differ in who the issuer is, how safe the promise is, and how easily a stranger accepts it.

### The hierarchy of money

Perry Mehrling's "money view" (canonical source: "The Inherent Hierarchy of Money", 2013; see his [BU lecture page](https://sites.bu.edu/perry/lectures/mb-lectures/section-1/1-the-four-prices-of-money/) and the [LPE primer](https://lpeproject.org/blog/promises-all-the-way-down-a-primer-on-the-money-view/)) ranks IOUs by how reliably they settle other IOUs at face value:

```
  Most reliable (settles everything)
  1. Central-bank money      (reserves, held by banks only, and cash/banknotes)
  2. Bank deposits           (commercial-bank liability; what households and firms use)
  3. Money-market claims     (money-market fund shares, repo, commercial paper)
  4. Securities              (Treasuries, bonds, stocks: price moves, not par)
  Least reliable (priced, not promised)
```

Each rung above securities is a promise to pay the rung above at par; securities are only convertible at a market price. The "money-market claims" rung is this course's simplification: Mehrling's core hierarchy is currency/reserves > deposits > securities (with gold above currency internationally). A deposit is promised to be convertible into reserves one-for-one, so when you pay someone at a different bank, the banks settle in reserves. When the promise is doubted (a bank run, a money-fund "breaking the buck"), the lower rung trades at a discount until someone higher up steps in. Days 2, 3 and 5 are about exactly that.

The money view in one sentence: the payment system is a network of balance sheets, and money is the stuff that flows along the links between them.

### Aside: the textbook functions of money

- Unit of account: prices are quoted in it (USD, VND).
- Medium of exchange: you can settle debts with it.
- Store of value: it holds purchasing power over time (imperfectly; Day 4).

Treat this as a checklist, not the lesson. The lesson is who owes whom.

### The T-account and double entry

A T-account is a balance sheet drawn as a T. Assets (what the holder owns or is owed) go on the left. Liabilities (what the holder owes) and equity go on the right.

```
        Bank A
  Assets        | Liabilities + Equity
  Reserves  20  | Deposit:Alice   90
  Loans     80  | Equity          10
  ----------------------------------
  Total    100  | Total          100
```

The rule: every entry changes the two sides by the same amount, so assets = liabilities + equity always holds. Equity is the residual: what is left for the owners after the liabilities are paid, `equity = assets - liabilities`. If the loans lose value, equity absorbs the loss first; if equity goes negative, the bank is insolvent (Day 5 uses this to explain SVB).

Your deposit is an asset to you and a liability to the bank. That mirror is why "every money event touches at least two balance sheets": one party's asset is another party's liability, and a payment changes both. Cash fits the same rule: a banknote is an asset to you and a liability of the central bank.

### Who can issue what

- Government (Treasury): issues bonds and bills, which are securities at the bottom of the hierarchy. It spends and taxes through accounts at the central bank (Day 3).
- Central bank: issues reserves and cash. Only it can create reserves (Day 3).
- Commercial banks: issue deposits, mostly by lending (Day 2).
- Stablecoin issuers: issue tokens promising par redemption in dollars, backed by reserve assets. They sit around rung three of the hierarchy and are the subject of Day 21.

Preview: Day 2 shows a loan creating a deposit, Day 3 shows how the central bank prices and supplies reserves, and Day 21 asks which rung a stablecoin really is.

### Setup walkthrough (do this once)

1. Install `uv`. On macOS: `brew install uv`. On Linux or macOS without Homebrew: `curl -LsSf https://astral.sh/uv/install.sh | sh`. On Windows, use the PowerShell installer. Source: the [uv installation docs](https://docs.astral.sh/uv/getting-started/installation/) (checked 2026-10; `uv --version` printed 0.12.10 here).
2. In a terminal: `cd economy_monetary_mastery/labs`, then `uv sync`. This reads `pyproject.toml`, fetches CPython 3.12 if you lack it, and builds a `.venv` with pandas, matplotlib and the rest. It needs the network once.
3. Run the tests: `uv run pytest day01`. Six failures are the correct starting state.
4. Run everything from `labs/`. `uv run` uses the project environment, so you never activate a venv by hand.

Reading a failure. Pytest prints the failing test, the code around the failing line, and an `E` line with the exception. Right now the `E` line says `NotImplementedError: TODO: ...`: that function is still a stub. Once you implement it, an `E` line such as `assert 100 == 150` means your logic is wrong (left is your value, right is expected), and an `UnbalancedError` or `KeyError` points at a missing case. Fix one function, then run only its tests with `-k` (for example `uv run pytest day01 -k transfer`).

`LAB_IMPL=solution` etiquette. `LAB_IMPL=solution uv run pytest day01` runs the same tests against the reference answer, to check that the tests and your environment are fine, and to compare after you have a working version. Make an honest attempt first, read the solution's idea in `SOLUTION.md`, then close the loop by writing your own. Copying the file teaches you nothing the test will notice.

### How to read FRED

[FRED](https://fred.stlouisfed.org/) (Federal Reserve Bank of St. Louis) hosts economic time series. Before using one, check four things on its series page:

- Units: [DFF](https://fred.stlouisfed.org/series/DFF), the effective federal funds rate, is in percent (3.88 means 3.88% per year), not a fraction.
- Frequency: DFF is daily; others are weekly, monthly (with a publication lag) or quarterly.
- Seasonal adjustment and index base: many series are indexes (CPI) or levels in millions or billions.
- Missing values: the raw CSV writes a single `.` for a missing observation (holidays, unpublished days). Parse it as NaN and drop it, or every number turns into a string.

The CSV download has a header row with the date column named `observation_date` and the value column named by the series ID, for example `observation_date,DFF`. Older files used `DATE`. A request to `https://fred.stlouisfed.org/graph/fredgraph.csv?id=DFF` returned the `observation_date` header on 2026-10-11 (verified as of 2026-10). The frozen snapshot in this repo says `date,DFF` because it was re-written, which is why your parser must take the first column whatever it is called.

## Worked example

Alice (at Bank A) pays Bob (at Bank B) $15. Start: Bank A holds $20 of reserves and $80 of loans, owes Alice $90 and has $10 equity. Bank B holds $5 of reserves and has $5 equity. Bob has no deposit yet.

Before:

```
        Bank A                              Bank B
  Assets       | Liabilities          Assets       | Liabilities
  Reserves  20 | Deposit:Alice  90    Reserves   5 | Equity       5
  Loans     80 | Equity         10
```

The payment is an instruction to Bank A: "debit Alice, credit Bob's account at Bank B". Bank A pays by sending reserves to Bank B (in the US, over Fedwire at the Fed). Four lines change, one per T-account side:

```
        Bank A                              Bank B
  Assets       | Liabilities          Assets       | Liabilities
  Reserves -15 | Deposit:Alice -15    Reserves +15 | Deposit:Bob  +15
```

After:

```
        Bank A                              Bank B
  Assets       | Liabilities          Assets       | Liabilities
  Reserves   5 | Deposit:Alice  75    Reserves  20 | Deposit:Bob  15
  Loans     80 | Equity         10                  | Equity        5
```

Check: Bank A 85 = 75 + 10; Bank B 20 = 15 + 5. Both still balance. Total deposits in the system are unchanged (90 became 75 + 15), total reserves are unchanged (20 + 5 = 25), but reserves moved from A to B. If Bank A had held only $10 of reserves, it could not settle: it would have to borrow reserves or sell assets first. That is the rule your `transfer_deposit` enforces by raising `ValueError`. Alice's payment was a transfer of an IOU from the second rung of the hierarchy, settled on the first.

## Exercises

1. Draw the T-accounts for a cash withdrawal at an ATM: you take $100 out of your deposit at Bank A. Which rung of the hierarchy do you end up holding?
   **Hint:** Bank A pays out cash it holds as an asset. A vault of cash counts alongside reserves for the bank.
   **Solution sketch:** Bank A: assets, cash -100; liabilities, Deposit:you -100. You: assets, deposit -100, cash +100. Both balance. You now hold a central-bank liability (banknotes) instead of a bank liability, so you moved up the hierarchy. Bank A later replenishes its cash by swapping reserves for banknotes at the central bank.

2. Is a bank deposit money? For whom?
   **Hint:** Ask who treats it as final payment, and who can only pay with it through a bank.
   **Solution sketch:** For households and firms, yes: it is accepted at par and spendable. For banks settling with each other, no: they settle in reserves, so a deposit is a claim on the bank, one rung below reserves. Mehrling's point is that "money" depends on whose balance sheet you stand on.

3. Find series DFF on FRED and state its units, frequency and the last value in the snapshot.
   **Hint:** Open the series page and read the "Units" and "Frequency" lines under the title. Then run `uv run python -m day01.lab`.
   **Solution sketch:** Percent, daily (7-day week). The snapshot's last value is 3.88 on 2026-09-30, which means 3.88% per year, not 3.88 basis points or 0.0388 of anything. The one-year change is -0.21 percentage points, not -0.21%.

4. Bank C has assets of 500 (reserves 50, loans 450), deposits of 460 and equity of 40. Loans worth 60 default entirely. Draw the T-account after the loss. Is the bank solvent?
   **Hint:** Write off the asset side and let equity take the residual.
   **Solution sketch:** Assets fall to 440; deposits stay at 460 because depositors are still owed; equity becomes 440 - 460 = -20. Liabilities exceed assets, so the bank is insolvent. A loss equal to 12% of total assets (13.3% of loans) wiped out an equity cushion of 8% of assets. This is why capital matters (Day 5).

5. Alice pays Bob $15 but both use the same bank. Draw the T-account. What changes compared with the worked example?
   **Hint:** Where does Bob's deposit sit, and do reserves need to move?
   **Solution sketch:** One balance sheet: Deposit:Alice -15, Deposit:Bob +15. Assets do not change and no reserves move. The bank only re-labels who it owes. A payment inside one bank is bookkeeping; a payment across banks needs settlement on the layer above.

6. Write a three-line test of your own for `BalanceSheet.apply`: one that adds an asset and a liability together, and one where the entry is off by 1e-12. Which should pass?
   **Hint:** The tolerance is 1e-9 so floating-point noise does not raise.
   **Solution sketch:** The balanced entry passes. The 1e-12 difference also passes, because floats such as 0.1 + 0.2 do not sum exactly. A difference of 0.01 must raise. Compare with a tolerance, never with `==`.

## Anti-patterns / Common mistakes

- "Banks lend out deposits." A bank lending does not take your deposit and hand it to a borrower; the loan creates a new deposit at the same time (Day 2). Thinking in terms of a pot of savings gets the causality backwards.
- "Money = cash." Cash is a small slice of money. Most of what people call money is deposits, which exist only as bank liabilities, and most large settlement happens in reserves that no household ever sees.
- Reading charts without checking units. A rate in percent versus a fraction, a series in millions versus billions, a daily versus a monthly frequency, an index with a base year: each gives a number that looks plausible and is wrong by a factor. Read the series page first.

## Lab

Open `labs/day01/README.md` and follow the steps. In order: `BalanceSheet.apply`, `transfer_deposit`, `parse_fred_csv`. Success is `uv run pytest day01` with all 6 tests passing, then `uv run python -m day01.lab` printing the latest DFF and its one-year change and saving `.cache/plots/day01.png`.

## Teardown

Nothing billable is created. The only files written are the plot in `labs/.cache/plots/`, which is gitignored.

## Journal prompt

In `journal.md`: what will the effective fed funds rate (DFF) be on 2026-12-31? Write a range and a probability that the value lands inside it (for example "3.50-3.90, 70%"), plus two sentences on why. Look at the snapshot's last value (3.88 on 2026-09-30) and the past year's change first. On Day 30, record its status; it resolves on 2026-12-31.
