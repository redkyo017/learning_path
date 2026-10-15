# Day 2 — Banks create money: loans create deposits

> Block 1: Money & banking plumbing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 1 gave you the notation. Today you use it on the most misunderstood balance-sheet event in finance: a bank making a loan. Get this right and the rest of Block 1 follows: why the central bank steers a price instead of rationing a quantity (Day 3), why banks fail (Day 5), and why credit growth is something a state may cap (Vietnam, below). You also meet the first piece of quant plumbing you will reuse for 28 more days: simple versus log returns.

## Core concepts

### Loans create deposits

The folk story says: savers deposit money, the bank lends most of it out, the borrower spends it. The [Bank of England's 2014 Q1 Quarterly Bulletin, "Money creation in the modern economy"](https://www.bankofengland.co.uk/quarterly-bulletin/2014/q1/money-creation-in-the-modern-economy), says it runs the other way: most of the money in circulation is bank deposits, and banks create them by lending. When a bank approves a $20 loan, it does not look for $20 of someone's savings. It adds a loan to the asset side and a new deposit, owed to the borrower, to the liability side. Both sides grow by 20 in one step.

```
        Bank A
  Assets        | Liabilities + Equity
  Loans    +20  | Deposit:Carol  +20
  (reserves unchanged, equity unchanged)
```

Nobody else's balance sheet changed. The deposit is new money: an IOU of the bank that other people will accept as payment (Day 1, rung two of the hierarchy). It disappears when the loan is repaid: repayment shrinks both sides again.

### Why the money multiplier is backwards

The textbook "money multiplier" says: reserves come first, the reserve requirement is r, so $1 of reserves supports $1/r of deposits. That chain has the causality reversed. Banks lend first and find reserves afterwards (reserves are supplied by the central bank at its policy rate, Day 3). In the US it cannot even be a binding rule: the Federal Reserve [reduced reserve requirement ratios to 0 percent, effective 26 March 2020](https://www.federalreserve.gov/monetarypolicy/reservereq.htm), so there is no required ratio to multiply by.

### What actually limits lending

If not reserves, then what? Five things:

- Capital: losses on loans come out of equity, and regulators require a minimum equity buffer. More loans need more equity.
- Regulation: capital, liquidity and (in some countries) quantity limits, see below.
- Demand for credit: someone creditworthy must want the loan at the offered rate.
- Profitability: the loan must earn more than the bank's funding cost plus expected losses.
- Payment outflows: the borrower will spend the new deposit, usually to a customer of another bank, which must be settled in reserves (next section). A bank that lends faster than its rivals bleeds reserves and must borrow them.

### Payments between banks settle in central-bank reserves

If Carol spends her $20 at a shop banking with Bank B, Bank A must pay Bank B in reserves, exactly the Day 1 transfer. After it, Bank A has 20 less reserves and 20 less deposits, and Bank B has 20 more of each. If everybody's customers pay each other in similar amounts, the flows net out and little reserve is needed. If A grows faster than the system, A pays out more than it receives and must find reserves, by borrowing them from other banks or the central bank. How reserves are created and priced is Day 3.

### Capital versus liquidity: insolvent is not the same as illiquid

- Insolvent: assets are worth less than liabilities, so equity is negative. The bank is broke on paper.
- Illiquid: assets are worth more than liabilities in the long run but cannot be turned into cash quickly enough to meet today's withdrawals.

The key point of the run model below: forced selling turns the second into the first. Two ratios in the lab capture each side. `capital_ratio = equity / loans` is a simplified leverage-style measure (real Basel ratios divide by risk-weighted assets). `liquidity_ratio = reserves / deposits` shows what fraction of deposits can be paid right now.

### Basel III in plain English

The Basel Committee (hosted by the [BIS](https://www.bis.org/bcbs/basel3.htm)) writes the global bank standards. Three to know:

- CET1 (Common Equity Tier 1): the highest-quality capital, mostly shareholders' equity and retained earnings, measured against risk-weighted assets. Basel III sets a [minimum of 4.5 percent plus a 2.5 percent capital conservation buffer, 7 percent in total](https://www.bis.org/press/p100912a.pdf). Inside the buffer a bank may keep operating but must restrict dividends and bonuses. Supervisors add further requirements for large banks.
- LCR (Liquidity Coverage Ratio): a bank must hold enough high-quality liquid assets (reserves, government bonds) to cover its expected net cash outflows over a 30-day stress. It is a rule against the 3-day run.
- NSFR (Net Stable Funding Ratio): the bank's stable, long-dated funding must cover the stability needs of its assets over one year. It is a rule against funding 30-year mortgages with overnight money.

### Bank runs: how illiquidity becomes insolvency

A bank promises depositors par on demand, but its loans are long and cannot be called back. If depositors fear others will withdraw, it is rational to withdraw first. The bank pays from reserves; when they run out it must sell loans at a discount (a fire sale, because the buyer knows the seller is desperate). The discount is a loss, which comes out of equity. Less equity makes depositors more nervous. The run is self-fulfilling: a bank that was solvent at book value can be killed by the run itself.

Three public tools break the loop:

- Deposit insurance: if small depositors are guaranteed, they have no reason to run. In the US, the [FDIC insures deposits to at least $250,000 per depositor, per ownership category, per bank](https://www.fdic.gov/resources/deposit-insurance/understanding-deposit-insurance/index.html). In Vietnam, the cap is [VND 350 million per depositor per institution](https://baonghean.vn/en/chinh-thuc-nang-han-muc-bao-hiem-tien-gui-len-350-trieu-dong-10344498.html) (principal plus interest) under Circular 05/2026/TT-NHNN, effective 13 July 2026; it was [125 million VND](https://div.gov.vn/deposit-insurance-coverage-limit-increased-to-125-million-vnd-en) under Decision 32/2021/QD-TTg from 12 December 2021. The limit can change, so re-check before relying on it.
- Lender of last resort: the central bank lends to a solvent but illiquid bank against collateral (in the US via the [discount window](https://www.federalreserve.gov/monetarypolicy/discountrate.htm)). Bagehot's rule (Walter Bagehot, *Lombard Street*, 1873): lend freely, at a penalty rate, against good collateral. Freely stops the run; a penalty rate keeps banks from using it as cheap funding; good collateral protects the lender.
- Capital and liquidity rules (previous sections), applied before trouble starts.

### Vietnam aside: "room tín dụng"

The State Bank of Vietnam (SBV) does not rely only on prices. Each year it sets a credit growth target for the banking system and has allocated a "room tín dụng" (credit room) to domestic commercial banks, an upper limit on how fast each one's loans may grow. It is a quantity cap, a deliberate regulatory limit on lending alongside capital rules, unlike a price such as the policy rate. A bank that hit its room had to slow lending even with capital and demand. The system is being wound down: [Vietstock reports](https://en.vietstock.vn/2025/08/roadmap-outlined-to-abolish-credit-quotas-37-618973.htm) that the Prime Minister directed the SBV on 6 August 2025 to design a roadmap and pilot abolishing the quota from 2026 for institutions meeting strict criteria, and that quotas were already lifted for foreign banks, joint-venture banks and non-bank credit institutions by early 2025 (see also [Vietnam News](https://vietnamnews.vn/economy/1723030/banking-industry-to-remove-credit-quota-policy-from-2026.html)). Whether and how the 2026 pilot has been implemented is unverified as of 2026-10. No quota figures are given because they change every year; Day 16 covers the SBV in detail.

### Quant thread: simple versus log returns

For prices `p`, the simple return is `p_t / p_{t-1} - 1` and the log return is `ln(p_t / p_{t-1})`.

- Log returns add over time: `ln(p_T/p_0) = sum of the daily log returns`. Total growth is `exp(sum) - 1`. That makes multi-period statistics (mean, variance, regression) tidy.
- Simple returns add across assets: a portfolio's one-period return is the weighted sum of its assets' simple returns. Log returns do not do that.
- Simple returns multiply over time: `(1+r1)(1+r2) - 1`. A +50% day followed by -50% leaves you down 25%, not flat.
- For small moves they nearly coincide: `ln(1+r) ~ r - r^2/2`. The mean simple return exceeds the mean log return by about half the variance, the gap you will see in the lab output for SPY.

Rule of thumb for the course: log returns for time-series math, simple returns for portfolio weights.

## Worked example

The lab's textbook bank: reserves 10, loans 90, deposits 90, equity 10. Check: 10 + 90 = 90 + 10. Capital ratio 10/90 = 11.1 percent; liquidity ratio 10/90 = 11.1 percent.

Start:

```
        Textbook bank
  Assets        | Liabilities + Equity
  Reserves  10  | Deposits    90
  Loans     90  | Equity      10
  Total    100  | Total      100
```

A run: 50 percent of depositors demand cash, with a 30 percent fire-sale haircut on loans.

- Step 1, need: 0.5 x 90 = 45.
- Step 2, pay from reserves: all 10 of reserves. Shortfall: 45 - 10 = 35.
- Step 3, sell loans. To raise 35 cash at 30 percent off, sell loans with book value x where x(1 - 0.3) = 35, so x = 50. The bank gives up 50 of loans (book) and receives 35. Loss = 50 x 0.3 = 15.
- Step 4, pay 45 in total, so deposits fall by 45 (90 to 45). Equity falls by the loss (10 to -5).

After:

```
        Textbook bank
  Assets        | Liabilities + Equity
  Reserves   0  | Deposits    45
  Loans     40  | Equity      -5
  Total     40  | Total       40
```

The identity holds (0 + 40 = 45 - 5). Equity is -5, so the bank is insolvent: the run turned a bank that looked fine (equity 10) into a failed one, even though the first 45 depositors were paid in full. The remaining 45 of deposits are backed by only 40 of loans. This is why the lab's `bank_run` stops at the first insolvent state, and `main()` reruns the same run at 10, 30 and 50 percent haircuts. At 10 percent the first wave costs a loss of 3.9 (equity 6.1) and the bank survives both waves; at 30 percent it fails in the first.

## Exercises

1. Find the haircut at which a 50 percent run makes this bank exactly insolvent (equity = 0).
   **Hint:** The shortfall is 35 whatever the haircut. The loss is x times h with x = 35/(1 - h).
   **Solution sketch:** Set 10 = 35h/(1 - h), so 10 - 10h = 35h, h = 10/45 = 2/9, about 22.2 percent. Check: x = 35/(7/9) = 45 of loans sold (below the 90 held), loss = 45 x 2/9 = 10, equity 0. Any haircut above 22.2 percent leaves the bank insolvent after one wave.

2. Bank A (10 reserves, 90 loans, 90 deposits, 10 equity) lends 8 to Carol, who immediately pays Dave at Bank B. Draw A's balance sheet after the loan and after settlement. What are the capital and liquidity ratios?
   **Hint:** Lending touches no reserves; the payment does.
   **Solution sketch:** After the loan: loans 98, deposits 98, reserves 10. After settling 8 to Bank B: reserves 2, deposits 90, loans 98, equity 10 (check: 2 + 98 = 90 + 10). Capital ratio 10/98 = 10.2 percent; liquidity ratio 2/90 = 2.2 percent. The loan was free to make; paying for it cost reserves, which is why payment outflows limit lending.

3. How large a first withdrawal wave can the textbook bank pay without selling any loans? What if the wave is 20 percent, with a 10 percent fire-sale haircut?
   **Hint:** Compare the wave to reserves divided by deposits.
   **Solution sketch:** Reserves 10 against deposits 90 covers 10/90 = 11.1 percent, which is the liquidity ratio. At 20 percent the need is 18, the shortfall is 8, and at a 10 percent haircut it must sell 8/0.9 = 8.9 of loans at a loss of 0.89. Equity is 9.11.

4. A stock rises 50 percent, then falls 50 percent. Compute the total simple return, each log return and the sum of the log returns. What is the average simple return?
   **Hint:** Use prices: 100, 150, 75.
   **Solution sketch:** Total simple return: 75/100 - 1 = -25 percent. Log returns: ln 1.5 = +0.405 and ln 0.5 = -0.693, summing to -0.288 = ln 0.75, and exp(-0.288) - 1 = -25 percent. The average simple return is 0, yet you lost 25 percent: averaging simple returns overstates growth, while log returns add correctly.

5. A Vietnamese saver has 300 million VND in one bank and 80 million VND in another. How much is insured, and what changes if both are at the same bank?
   **Hint:** The limit is per depositor per credit institution, principal plus interest.
   **Solution sketch:** Two banks: 300 + 80 = 380 million VND, all insured, because each amount is below the VND 350 million per-institution cap. One bank: the 380 million is combined, so 350 million is insured and 30 million is uninsured. Under the old 125 million cap the same saver would have had 205 million insured across two banks and 125 million at one. Check the current limit first, since it can change.

6. With a simple capital ratio floor of 10 percent (equity / loans), how many more loans can the textbook bank make before it hits the floor? What does it need to lend 30 more?
   **Hint:** Loans can be at most equity / 0.10.
   **Solution sketch:** Maximum loans = 10/0.10 = 100, so only 10 more. For loans of 120 it needs equity of 12, so 2 more equity from shareholders or retained profits. This is a simplified ratio; Basel risk-weights assets, but the logic (equity caps the balance sheet) is the same.

## Anti-patterns / Common mistakes

- "The money multiplier": believing reserves cause deposits at a fixed ratio. Banks lend first and settle after; the binding limits are capital, risk appetite, demand and regulation.
- "Reserves are lent out": reserves are the settlement balances banks hold at the central bank. They move between banks and the central bank (for example when customers withdraw cash or the Treasury's account changes), and households never hold them, so they cannot be lent to households; what banks lend is new deposit money.
- Confusing capital with reserves: equity is on the liability side (a claim of owners, a loss buffer); reserves are on the asset side (cash-like holdings). A bank can have plenty of capital and no liquidity, or vice versa. Capital absorbs losses; reserves meet withdrawals.
- Averaging simple returns over time: the result overstates compound growth. Use log returns or compound the simple ones.

## Lab

Open `labs/day02/README.md`. In order: `Bank.lend`, the two ratios, `bank_run`, then the two return functions. Success is `uv run pytest day02` with all 6 tests passing, then `uv run python -m day02.lab` printing the run outcomes at three haircuts and SPY's mean simple versus log return, and saving `.cache/plots/day02.png`.

## Teardown

Nothing billable is created. The only file written is the plot in `labs/.cache/plots/`, which is gitignored.

## Journal prompt

In `journal.md`: pick one bank you use. In two sentences, explain what would have to happen for it to face a run, and which of the three public tools (deposit insurance, lender of last resort, capital and liquidity rules) would protect you most. Then add one honest line: do you now believe "banks lend out my deposits"? What changed?
