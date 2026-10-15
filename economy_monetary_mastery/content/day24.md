# Day 24 — Block 4 integration: crypto vs fiat quiz

> Block 4: Crypto deep dive. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Days 1 to 5 built the fiat picture: money as IOUs ranked by how reliably they settle ([Day 1](day01.md)), banks creating deposits by lending ([Day 2](day02.md)), central banks steering rates and backstopping liquidity ([Day 3](day03.md)), inflation ([Day 4](day04.md)) and the shadow-banking plumbing that runs without a backstop ([Day 5](day05.md)). Days 19 to 23 rebuilt the same machine from code: a native asset, a programmable platform, dollar-pegged tokens, exchanges and lenders as contracts, and the company-run venues where most trading happens.

Today puts the two side by side with one question: for each system, who issues, by what rule, who catches a failure, and who ends up holding the loss? Every claim has to be traced to a balance sheet or a rule.

## Core concepts

### Recap map: Days 19 to 23

```
Day 19  Native asset         Bitcoin: UTXO ledger, proof of work, fixed issuance schedule
Day 20  Programmable layer   Ethereum: accounts, gas, EIP-1559 burn, proof of stake
Day 21  Money-like claims    Stablecoins: fiat-backed, crypto-collateralised, algorithmic
Day 22  Financial services   DeFi: AMM x*y=k, impermanent loss, lending, MEV
Day 23  Market structure     CEX custody, perps and funding, basis, ETFs
```

Each layer sits on the one before, and failures travel the same way: a stablecoin or exchange failure hits DeFi and prices at once.

Key numbers (details in the day files): Bitcoin subsidy 3.125 BTC since block 840,000 (April 2024), next halving at block 1,050,000 (about April 2028), about 20.10 million BTC issued at tip height 970,883, per [Day 19](day19.md); Ethereum on Fusaka, 60 million gas limit, base fee moves at most 12.5% per block, staking yield about 2.6% to 3.8% ([Day 20](day20.md)); stablecoins about $304 billion under GENIUS and MiCA ([Day 21](day21.md)); impermanent loss -5.7% at a 2x move ([Day 22](day22.md)); perp funding and basis ([Day 23](day23.md)).

### Side-by-side

| | Fiat (central bank + banks) | Bitcoin | Ethereum (ETH) | Fiat-backed stablecoin |
|---|---|---|---|---|
| Issuer | Central bank issues reserves and cash; commercial banks issue deposits by lending ([Day 2](day02.md)) | Nobody; the protocol pays a subsidy to whichever miner finds a block | Nobody; the protocol issues ETH to validators and burns the base fee | A private company, against dollars it receives |
| Supply rule | Discretion within a mandate: rates, QE/QT, bank lending; no fixed path ([Day 3](day03.md)) | Fixed schedule in code: 50 BTC halved every 210,000 blocks | Protocol issuance minus burn; changes by upgrade and by fee demand | One token per dollar deposited (redemption burns it); no money creation beyond reserves |
| Lender of last resort | Central bank discount window and emergency facilities; deposit insurance ([Day 2](day02.md)) | None | None | None; at most a regulator-ordered rescue of the bank holding reserves (March 2023) |
| Settlement finality | Legal finality in reserves at the central bank ([Day 1](day01.md)) | Probabilistic; about 6 blocks (an hour) by convention | Economic finality after two epochs, about 13 minutes | Finality of the chain it runs on, plus redemption risk at the issuer |
| Censorship resistance | Low: accounts can be frozen, sanctions apply | High at protocol level; exchanges and ETFs are not | High at protocol level; some block builders filter sanctioned addresses | Low: issuers can blacklist and freeze addresses |
| Failure modes | Bank runs, insolvency, inflation, currency crises ([Day 2](day02.md), [Day 4](day04.md), [Day 5](day05.md)) | Security-budget decline, key loss, custody failure, 51% attack | Contract bugs, staking-queue runs, validator concentration | Run on reserves, bank failure, depeg, regulation |
| Who holds the risk | Depositors up to the insurance limit, then shareholders and taxpayers | Holders alone | Holders, plus anyone in a contract that fails | Token holders (last redeemer loses), then the issuer's creditors |

Read the table as a hierarchy of promises. Fiat deposits are promises backed by an institution with a backstop. Bitcoin promises nothing to anyone and has no backstop: the rule is the product. Stablecoins promise a dollar without a backstop, the structure of the money-market fund in [Day 5](day05.md), so they inherit its run risk. The lender-of-last-resort box is empty at every crypto layer.

### Where the comparison is fair and where it is not

- *Supply rule.* Bitcoin's issuance is a known, falling schedule; M2 results from central-bank and bank decisions. A fixed supply does not fix a price: price needs demand, which moves with liquidity, sentiment and leverage.
- *Unit of account.* Wages, rent and taxes are still quoted in dollars or dong, and a money that swings 50% in a year is a poor unit of account whatever its supply rule.
- *Backstop.* Fiat's backstop has a price (inflation, bailouts, [Day 4](day04.md)). No backstop means no bailout and no relief for the holder who is wrong.
- *Censorship resistance and sovereignty.* Real properties, valued differently under capital controls (Vietnam, [Day 16](day16.md)) than without them. They are not return drivers.

## Worked example

**2020 to 2022 as a natural experiment.** All figures were computed outside `main()` from the M2SL, CPIAUCSL, DFF, WALCL and Binance BTC/USDT snapshots (`main()` prints only the issuance table).

*Phase 1: the surge (2020 to early 2021).* Effective fed funds fell to 0.15% on 20 March 2020 and about 0.05% by 30 April and the Fed's balance sheet grew from about $4.2 trillion to a peak of about $9.0 trillion in April 2022 (WALCL). M2 year-on-year growth peaked at 26.8% in February 2021 (24.5% in December 2020). Bitcoin's issuance was unaffected (scheduled inflation 2.5% in 2020), yet it closed 2020 at about $28,900 against about $7,200 a year earlier (up roughly 300%) and reached about $67,500 on 8 November 2021 (Binance daily close, the cycle high in the snapshot).

*Phase 2: the turn (2022).* CPI inflation peaked at 9.0% year-on-year in June 2022 ([CPIAUCSL](https://fred.stlouisfed.org/series/CPIAUCSL)). Fed funds went from 0.08% in March 2022 to 5.33% by August 2023. M2 stopped growing: year-on-year growth was about -1.0% in December 2022 and reached -4.6% in April 2023, the lowest year-on-year reading in the snapshot, which starts in 1959. Bitcoin fell about 64% in calendar 2022 (about $46,200 to about $16,500) and about 77% from that November 2021 close to the 21 November 2022 low of about $15,800.

```
          M2 YoY (Dec)   CPI YoY (Dec)   BTC (year-end close)
2020         +24.5%          1.3%        28,924   (+302%)
2021         +12.5%          7.2%        46,217   (+60%)
2022          -1.0%          6.4%        16,542   (-64%)
2023          -2.4%          3.3%        42,284   (+156%)
```

*Phase 3: deleveraging.* Higher rates ended the cheap-leverage era, and the failures followed the structures of Days 21 to 23:

- **Terra/UST (May 2022).** No redeemable reserves behind the dollar, a subsidised ~20% yield, a reflexive spiral ([Day 21](day21.md)).
- **Celsius (June to July 2022).** A lender that deployed customer deposits; it [paused withdrawals on 12 June 2022 and filed for Chapter 11 on 13 July](https://fortune.com/crypto/2022/07/13/celsius-files-bankruptcy-chapter-11-withdrawals/) (maturity transformation with no backstop, [Day 5](day05.md)).
- **FTX (November 2022).** Exchange balances backed by assets lent out or marked at the operator's own price ([Day 23](day23.md)).

Each failed because liabilities could be called on demand while assets were illiquid or overvalued, with no lender of last resort or deposit insurance: the SVB pattern of March 2023 ([Day 5](day05.md)) without the rescue.

*What the data support.* In 2020 to 2021, rising liquidity coincided with a huge BTC rally; in 2022, with CPI at 40-year highs, liquidity tightened and BTC fell hard. One episode is one observation, not a model: BTC traded as a high-beta liquidity asset in this cycle, not as something that tracks consumer prices.

**Lab link.** The lab compares only *issuance*. On the snapshot, BTC's scheduled inflation was 2.48% in 2020 against 24.5% M2 growth, and 0.83% in 2025 against 4.04%. Bitcoin's rate is below M2 growth in every year from 2019 to 2025 except 2022 and 2023, when M2 shrank. `YEAR_HEIGHTS` came from the [mempool.space block-timestamp API](https://mempool.space/api/v1/mining/blocks/timestamp/1609459200) (last block before 00:00 UTC on each 1 January, read 2026-10-11; for example 663,912 for 1 January 2021). The latest M2SL value is 23,342.8 billion USD for August 2026 ([FRED M2SL](https://fred.stlouisfed.org/series/M2SL)), matching the snapshot. The BTC column assumes 52,560 blocks a year; real years ran about 52,700 to 63,400 blocks.

One data note: the 2025 US government shutdown left some monthly FRED series without an October 2025 observation (CPIAUCSL and UNRATE; M2SL is complete). Row-based `pct_change(12)` would silently compare the wrong months across such a gap, so the lab reindexes to a full month-start calendar first.

## Exercises

1. **A stablecoin's bank fails.** A fiat-backed issuer has 100 tokens outstanding, backed by 80 of T-bills and 20 of deposits at Bank X. Bank X fails; the 20 is an uninsured claim worth, say, 70% in recovery. Draw the issuer's T-account before and after, and say what the last 20 redeemers receive if everyone redeems at once.
   **Hint:** redeem in order: the T-bills pay the first 80 tokens in full; compare what is left with the tokens still outstanding.
   **Solution sketch:** before, assets 100 (T-bills 80, deposit 20) against tokens 100. After, the deposit is worth 14, so assets are 94 against 100 tokens. The first 80 redeemers get $1 each from T-bills; the last 20 tokens share 14, about $0.70 each. The loss falls on the last holders unless the issuer has equity. In March 2023 the same shape (about $3.3 billion of roughly $40 billion stuck at SVB) pushed USDC to about $0.87 until the authorities protected SVB depositors. Compare the bank-run mechanics of [Day 2](day02.md) and [Day 5](day05.md).
   ```
        Issuer, before            |  Issuer, after Bank X fails
   T-bills   80 | Tokens 100      |  T-bills   80 | Tokens 100
   Bank X    20 |                 |  Bank X    14 |  Equity   -6
   ```

2. **Argue both sides: "BTC is an inflation hedge".** Use the snapshot data: BTC year-end closes (28,924 in 2020, 46,217 in 2021, 16,542 in 2022, 42,284 in 2023), CPI year-on-year (1.3% in December 2020, 7.2% in 2021, 6.4% in 2022, 3.3% in 2023) and M2 growth.
   **Hint:** a hedge must go up when inflation goes up; ask whether the sign of BTC's move matches the sign of inflation's move in each year, and what a single-cycle sample can prove.
   **Solution sketch:**
   - For: fixed schedule; 2020 to 2021 M2 surge came with a large BTC rally, and over 2020 to 2023 the price rose far more than the price level.
   - Against: in 2022, when inflation was highest (CPI 9.0% in June), BTC fell 64%; in 2023, as inflation cooled, BTC rose 156%. The correlation was with liquidity and rates, not with CPI.
   - Verdict: no evidence of a short-horizon CPI hedge in this sample; a long-horizon claim cannot be tested on about 15 years of data. A fixed supply is neither necessary (TIPS and real assets hedge without one) nor sufficient.

3. **Halving straddle.** The lab computes `btc_annual_inflation(823_785)` for 1 January 2024. The next 52,560 blocks straddle the April 2024 halving at block 840,000. Compute the new supply in the window and the rate, then explain why the 2024 row (1.10%) is higher than the 2025 row (0.83%) even though both are "post-halving".
   **Hint:** split the window into blocks before and after 840,000.
   **Solution sketch:** blocks before the halving: 840,000 - 823,785 = 16,215 at 6.25 BTC = 101,343.75 BTC; blocks after: 52,560 - 16,215 = 36,345 at 3.125 BTC = 113,578.1 BTC; total about 214,922 BTC on a supply of about 19.586 million, so 1.10%. The 2025 window sits entirely in the 3.125 era (52,560 x 3.125 = 164,250 BTC on about 19.80 million), so 0.83%.

4. **Map the failures.** For Terra, Celsius, FTX and Silicon Valley Bank, name the rung of the hierarchy of money the liability sat on, the structural flaw, and whether any backstop existed.
   **Hint:** reuse the questions "what is promised, what backs it, who is first in line, who stands behind it".
   **Solution sketch:**
   - Terra: a $1 promise backed by a sister token; reflexive; no backstop.
   - Celsius: deposit-like IOUs deployed into risky positions; no backstop, Chapter 11.
   - FTX: exchange balances lent to an affiliate; no backstop, bankruptcy.
   - SVB: deposits backed by long securities with unrealised losses; the authorities protected all depositors on 12 March 2023.
   - Pattern: the crypto cases are the SVB case without the rescue.

## Checkpoint quiz

1. Where does Bitcoin sit on the hierarchy of money from Day 1, and how does that differ from a bank deposit?
2. What is the current block subsidy, since which block, and when is the next halving?
3. Using the lab's formula, what is Bitcoin's annual scheduled inflation at block 840,000?
4. Why does the 21 million cap actually come to slightly less, and what enforces it?
5. How does finality differ between Bitcoin, Ethereum and a central-bank payment?
6. Ethereum's base fee after a completely full block: by how much does it change, and who receives the base fee?
7. Is ETH staking yield (about 2.6% to 3.8%) a risk-free rate? Name two risks it carries.
8. Why is a fiat-backed stablecoin structurally like a money-market fund, and what happened to USDC in March 2023?
9. What do the GENIUS Act and MiCA both prohibit an issuer from paying, and what do they require of reserves?
10. Why did TerraUSD collapse while a fully reserved stablecoin did not?
11. A pool holds 100 X and 10,000 Y. A trader sells 10 X with no fee. How much Y do they get, and what is the impermanent loss when the price ratio doubles?
12. Name the two ways a sandwich attack can be limited by the victim.
13. When perp funding is positive, who pays whom, and what does a 2% premium on a 90-day future imply for annualized basis?
14. You hold 1 BTC on an exchange. What is it on the exchange's balance sheet, and what did FTX show?
15. Which of the following has a lender of last resort: a commercial bank deposit, bitcoin, a stablecoin, an exchange balance?

## Answer key

1. In the "priced, not promised" tier with securities: it is nobody's liability and never converts at par into a higher rung. A deposit is a bank liability redeemable into central-bank money one for one ([Day 1](day01.md), [Day 19](day19.md)).
2. 3.125 BTC per block, since block 840,000 (April 2024). The next halving is at block 1,050,000, about April 2028, to 1.5625 BTC ([Day 19](day19.md)).
3. 52,560 x 3.125 / 19,687,500, about 0.83% a year.
4. Subsidies are integers in satoshis and halve by right shift, rounding down, so the total is 20,999,999.9769 BTC. Nodes enforce the rule; changing it needs most participants to agree ([Day 19](day19.md)).
5. Bitcoin: probabilistic, falling with each confirmation. Ethereum: economic finality after two epochs (about 13 minutes). Central bank: legal finality once reserves settle ([Day 1](day01.md), [Day 20](day20.md)).
6. It rises 12.5% (an empty block cuts it 12.5%). The base fee is burned, removed from supply; only the tip goes to the validator ([Day 20](day20.md)).
7. No. It is paid in ETH so it carries price risk, plus slashing, smart-contract risk (for liquid staking tokens) and an exit queue measured in weeks ([Day 20](day20.md)).
8. Both are par claims backed by short Treasury bills and cash, redeemable on demand with no backstop, so the last redeemer bears the loss. USDC fell to about $0.87 in March 2023 when $3.3 billion of about $40 billion in reserves was stuck at SVB ([Day 21](day21.md)).
9. Interest or yield paid by the issuer to holders; both require reserves of at least 1:1 in liquid assets ([Day 21](day21.md)). GENIUS rulemaking is still pending as of 2026-10.
10. UST had no redeemable reserves behind it, only a swap into newly minted LUNA, so redemptions diluted the collateral and the spiral fed itself ([Day 21](day21.md)).
11. dy = 10,000 x 10 / 110 = 909.09 Y. Impermanent loss at r = 2 is about -5.7% ([Day 22](day22.md)).
12. A low slippage tolerance (the transaction reverts if the price moves too far) and private order flow (a protected endpoint instead of the public mempool) ([Day 22](day22.md)).
13. Longs pay shorts. 2% x 365/90 is about 8.1% a year ([Day 23](day23.md)).
14. An unsecured liability of the exchange: you hold an IOU. FTX had lent customer balances out against illiquid assets, so a run exposed the gap ([Day 23](day23.md)).
15. Only the commercial bank deposit (central-bank facilities plus deposit insurance, [Day 2](day02.md)). Bitcoin has no issuer; stablecoin and exchange balances have no public backstop, as March 2023 and November 2022 showed.

## Anti-patterns / Common mistakes

- **Comparing the supply rule and calling it the return.** The lab compares issuance only; price depends on demand.
- **Quoting a single episode as proof.** 2020 to 2022 is one cycle in one regime.
- **Using row-based growth across a data gap.** `pct_change(12)` on a series with a missing month compares the wrong dates; reindex first.
- **Assuming a halving date.** The halving is a block height (1,050,000); its date is an estimate that moves with hashrate.

## Lab

From `economy_monetary_mastery/labs/`:

```
uv run pytest day24                          # the four functions, red at the start
uv run python -m day24.lab                   # table of BTC inflation vs M2 growth, 2013-2026
```

Implement `btc_supply`, `btc_annual_inflation`, `m2_growth` and `compare_issuance` in `labs/day24/lab.py` (see `labs/day24/README.md`). `main()` prints the comparison table against the `M2SL` snapshot and saves `labs/.cache/plots/day24.png`. `labs/day24/SOLUTION.md` has notes once you are done.

## Teardown

Nothing billable is created. The lab reads frozen snapshots only; no key, wallet or network access is needed.

## Journal prompt

Pick one holding in your own portfolio (a stock, an ETF, a coin or a bank deposit). Write down who issued the claim, what stands behind it, who would be first in line to lose in a run, and which entry of the side-by-side table it is closest to. Resolve any due entries and add a row to the Calibration review table in `journal.md`.
