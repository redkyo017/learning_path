# Day 21 — Stablecoins: fiat-backed to algorithmic collapse

> Block 4: Crypto deep dive. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

A stablecoin is a token that promises to be worth one dollar, the same promise a bank deposit or money-fund share makes ([Day 1](day01.md) hierarchy). Stablecoins are the cash leg of crypto trading, DeFi collateral, and a way to hold dollars without a US bank. At roughly $300 billion outstanding they are a large cash market in their own right. Each design raises one question: what stands behind the dollar, and who is paid first if it is not enough?

Three designs cover almost everything, and each has a distinct failure mode:

- Fiat-backed (USDT, USDC): an issuer holds dollar assets against tokens. Failure mode: a run on reserves (USDC, March 2023).
- Crypto-collateralised (DAI, now rebranded USDS, from MakerDAO/Sky): users lock volatile crypto in a smart contract and borrow dollars against it. Failure mode: a liquidation cascade ("Black Thursday", March 2020).
- Algorithmic (TerraUSD, UST): no assets stand behind the dollar, only a promise that a sister token can be minted. Failure mode: a reflexive spiral (May 2022).

If you hold stablecoins as crypto cash or lend them for yield, you are a creditor of one of these structures. For a Vietnam-based investor they are also a dollarisation channel outside the State Bank of Vietnam's FX band ([Day 16](day16.md)).

## Core concepts

### A stablecoin is a narrow-bank or money-fund liability

[Day 5](day05.md) described money-market funds: shares valued at about $1, backed by T-bills and repo, with no deposit insurance, and run-prone because the first to redeem gets $1 while the last may not. A fiat-backed stablecoin is the same object with a different wrapper. The bank analogue is a narrow bank: deposits backed only by reserves or Treasuries, no loans.

A mint: Alice wires $1,000; the issuer buys T-bills; tokens are created. Issuers usually redeem directly only with verified institutional customers; everyone else sells on an exchange, where the price can deviate from $1.

```
        Issuer (mint of 1,000 tokens)
  Assets              | Liabilities
  Cash at bank  +1000 | Stablecoin tokens +1000
        (then cash -1000, T-bills +1000)

        Alice
  Assets                      | Liabilities
  Bank deposit        -1000   |
  Stablecoin tokens   +1000   |
```

Redemption reverses it: the issuer sells $1,000 of T-bills, wires the cash and burns the tokens.

```
        Issuer (redemption of 1,000 tokens)        Alice
  Assets          | Liabilities              Assets            | Liabilities
  T-bills  -1000  | Tokens  -1000            Tokens    -1000   |
                                             Bank deposit +1000|
```

If assets fall below liabilities, the last holder to redeem takes the loss:

```
        Issuer (after $3.3bn of $40bn reserve is stuck at a failed bank)
  Assets                     | Liabilities
  Reserves reachable   36.7  | Tokens outstanding 40.0
  Cash at failed bank   3.3  |   (market price falls to price the 3.3 at a haircut)
```

### Design 1: fiat-backed (USDT, USDC)

- Composition. Mostly Treasury bills, overnight repo and cash at banks. The US [GENIUS Act](https://www.paulhastings.com/insights/crypto-policy-tracker/the-genius-act-a-comprehensive-guide-to-us-stablecoin-regulation) (below) writes this into law for US-regulated issuers; before it, composition was a disclosure choice. Tether has also held non-Treasury assets; the shares are in its own attestations and not reproduced here.
- Attestation versus audit. An attestation is an accountant's report that the issuer's stated reserves existed on a given date. It is not an audit and does not test controls or whether reserves were pledged elsewhere.
- Redemption gates. Tokens can trade at $0.99 and still be "redeemable at $1" for a customer you are not.
- Concentration. USDC fell to about $0.87-0.88 on 10-12 March 2023, after [Circle disclosed](https://www.coindesk.com/business/2023/03/11/circle-confirms-33b-of-usdcs-cash-reserves-stuck-at-failed-silicon-valley-bank) that $3.3 billion of roughly $40 billion in reserves was stuck at Silicon Valley Bank, the bank that [Day 5](day05.md) took apart. The peg returned after the US Treasury, Fed and FDIC announced on 12 March that SVB depositors would be protected ([CNBC](https://www.cnbc.com/2023/03/11/stablecoin-usdc-breaks-dollar-peg-after-firm-reveals-it-has-3point3-billion-in-svb-exposure.html)). A stablecoin with 92% of reserves untouched was run because the stuck 8% had an unknown recovery value.

Size, dated: as of 10 October 2026 [Stablecoin Beat](https://stablecoinbeat.com/charts/market-cap/) reports USDT about $184.1 billion, USDC about $72.9 billion, total stablecoins about $303.8 billion.

### Design 2: crypto-collateralised (DAI/USDS)

A vault (a collateralised debt position, CDP) works like a margin loan in a smart contract. You lock ETH, mint dollar tokens up to a limit, and anyone can liquidate the vault if the ratio falls below the minimum: to borrow $100 you lock at least $150.

```
        Vault (user locks 10 ETH at $2,000, mints at 150% minimum)
  Assets                        | Liabilities
  ETH collateral  $20,000       | Stablecoin debt  $13,333  (= 20,000 / 1.5, the maximum)
                                | Equity buffer     $6,667
```

The formulas the lab implements: `max_mint = collateral_value / min_ratio`, and `liquidation_price = debt * min_ratio / collateral_amount`. Minting the maximum means liquidation at 13,333 x 1.5 / 10 = $2,000 (immediately); minting $10,000 moves it to $1,500.

Liquidation is an auction: the protocol sells collateral to repay debt, with a penalty. On Black Thursday, 12 March 2020, ETH fell sharply, the network was congested, gas fees spiked and some keeper bots could not transact. Some liquidation auctions cleared at zero DAI bids, leaving a shortfall later covered by newly minted MKR. Sizes vary by definition: [The Block](https://www.theblock.co/post/61797/maker-foundation-class-action-lawsuit-black-thursday) cites about $2 million of undercollateralised debt, other analyses about $8.3 million of collateral sold for 0 DAI. Overcollateralisation protects against price falls only if liquidation works when everyone needs it at once.

After 2020 Maker added USDC as collateral, so part of "decentralised" DAI inherited USDC's reserve risk: the March 2023 depeg dragged DAI to about $0.90 too ([The Block](https://www.theblock.co/news/markets/2023-03-11-usdc-and-dai-remain-at-about-0-90-following-circles-disclosure-of-funds-at-svb-218993)).

### Design 3: algorithmic (TerraUSD / LUNA)

UST had no dollar assets behind it. The promise: you can always burn 1 UST and receive $1 worth of LUNA, and burn $1 worth of LUNA to receive 1 UST. If UST trades below $1, arbitrageurs buy cheap UST, burn it for $1 of LUNA, and sell the LUNA. That should lift UST. But the LUNA they receive is newly minted, so LUNA supply grows when UST is under pressure, and LUNA's price is what backs the promise.

This is reflexive: the collateral is a claim on the thing whose value depends on confidence in the peg. A lower LUNA price means more LUNA minted per redeemed dollar, so more dilution and a lower price again. When UST outstanding approaches LUNA's market capitalisation, the promise cannot be honoured and holders know it. That is a run.

Terra also paid a fixed target yield of about 20% through the Anchor protocol, funded partly by subsidy ([Bloomberg's explainer](https://www.bloomberg.com/graphics/2022-crypto-luna-terra-stablecoin-explainer/); the SEC's amended complaint alleges Anchor advertised 19-20%, an allegation not a finding). The yield bought demand; it was not earned from assets. In early May 2022 withdrawals began (around 7 May), the peg broke, LUNA fell from about $87 on 5 May to a tiny fraction of a cent by 13 May according to one [academic paper](https://www.sciencedirect.com/science/article/abs/pii/S1544612322005359) (other sources differ on the lows), and tens of billions of dollars of market value disappeared. The lab model understates the pain, as panic also sold LUNA directly.

### Where stablecoin yield comes from

- T-bill income. A fiat-backed issuer earns the Treasury rate on its reserves. On $184 billion of USDT, a few percent a year is billions of dollars. The issuer keeps it; holders typically get nothing. GENIUS and MiCA both bar the issuer from paying interest; whether an exchange may pass yield through is unverified as of 2026-10.
- DeFi lending demand. Borrowers (leveraged traders) pay interest to lenders. That yield exists because someone is borrowing dollars to bet on crypto, and it disappears when they stop or get liquidated.
- Subsidy or token emissions. Terra's Anchor is the example. If the yield exceeds what the underlying assets earn and nobody explains the gap, the gap is being paid by new money or by token dilution.

### Regulation, as of 2026-10

**United States: GENIUS Act.** Signed on 18 July 2025. Key reserve provisions in the enacted law ([Paul Hastings summary](https://www.paulhastings.com/insights/crypto-policy-tracker/the-genius-act-a-comprehensive-guide-to-us-stablecoin-regulation); secondary sources disagree on some details, so check the statute text, Pub. L. 119-27):

- Reserves of at least 1:1: US currency, deposits at insured institutions, Treasury bills (and notes or bonds) with 93 days or less to maturity, overnight repo against such securities, and government money-market funds. Segregated; no rehypothecation, except a narrow carve-out to post reserves as collateral for repo. Summaries disagree on whether the repo limit is overnight or seven days.
- Monthly public disclosure of reserve composition, certified by the CEO and CFO, with an accountant's examination; issuers above $50 billion also need audited annual financial statements.
- No interest or yield paid by the issuer to holders; a published redemption policy.
- Reserves sit outside the issuer's bankruptcy estate; holders get a priority claim.

Status: the Act takes effect on the earlier of 18 months after enactment (about 18 January 2027) or 120 days after final implementing rules. Agencies missed the one-year rulemaking deadline (18 July 2026). The OCC [released a proposed rule on 25 February 2026](https://www.occ.gov/news-issuances/news-releases/2026/nr-occ-2026-9.html) and its head said in August that a final rule is planned for November 2026 (press report: [PYMNTS](https://www.pymnts.com/legal/2026/occ-races-the-clock-to-finish-genius-act-stablecoin-rules/)); the FDIC has an [April 2026 proposal](https://www.federalregister.gov/documents/2026/04/10/2026-06974/genius-act-requirements-and-standards-for-fdic-supervised-permitted-payment-stablecoin-issuers-and). Treasury's federal/state threshold rule: status unverified as of 2026-10. Rules are mostly still proposals.

**European Union: MiCA.** The rules for e-money tokens (EMTs, stablecoins referencing one official currency) and asset-referenced tokens (ARTs) have applied since 30 June 2024 (date from secondary sources; check [Regulation (EU) 2023/1114](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32023R1114)). EMT holders may redeem at par and issuers may not pay interest (recitals 67-68). Per secondary sources, Article 54 requires EMT issuers to hold at least 30% of funds received in separate accounts at credit institutions; the 60% figure for significant tokens comes from the EBA's draft liquidity standards under Articles 36(4) and 45 (unverified). As of 1 September 2026 the EBA counted 39 EMTs issued and no authorised ART ([EBA response to the Commission's review consultation](https://www.eba.europa.eu/sites/default/files/2026-09/12cb4f01-0d51-46bf-a561-165ac486698f/EBA%20response%20to%20EC%20targeted%20consultation%20on%20MiCA%20review.pdf)).

**Vietnam.** Vietnam's Law on Digital Technology Industry was passed in June 2025 and is reported to take effect on 1 January 2026, defining crypto assets separately from securities and CBDCs (single secondary source: [Cointelegraph via TradingView](https://tr.tradingview.com/news/cointelegraph:69dee2c91094b:0-how-vietnam-is-using-crypto-to-fix-its-fatf-reputation); check the official text). [Government Resolution 05/2025/NQ-CP](https://english.luatvietnam.vn/resolution-no-05-2025-nq-cp-dated-september-09-2025-of-the-government-on-piloting-the-crypto-asset-market-in-vietnam-410830-doc1.html) (9 September 2025) opens a five-year pilot: service providers need a Ministry of Finance licence and VND 10,000 billion of charter capital, up to five providers, foreign ownership of a provider capped at 49%, and offering, issuing, trading and payment are conducted in VND (Article 4.7). Assets must be backed by real underlying assets and cannot be securities or fiat (Article 5); the text as read does not mention stablecoins. Crypto is not legal tender and payment use is barred under earlier rules (any change: unverified as of 2026-10). Holding USDT via foreign exchanges is a grey zone; licensed domestic venues are only being set up.

### Stablecoins and dollarisation pressure

Where a currency is weak, savers want dollars. In Vietnam that has meant gold and cash dollars ([Day 16](day16.md)); stablecoins add a third route that crosses borders at near-zero cost and bypasses the SBV's FX band. A saver swapping VND for USDT peer-to-peer moves dollar demand off the official market, onto a price that can differ from the band rate. At scale this is dollarisation: domestic money demand falls, the central bank loses some control, and capital flight is easier..

## Worked example

The lab's Terra function, step by step. Start: 100 UST outstanding, 10 LUNA at $50, so LUNA's market cap is $500, 5 times the UST. Each step, half of the remaining UST is redeemed.

Step 1: R = 0.5 x 100 = 50 UST burned. Market cap after = 50 x 10 - 50 = 450. Minted LUNA = 50 / 50 = 1. LUNA supply = 11. New price = 450 / 11 = $40.91. UST left = 50.

Step 2: R = 0.5 x 50 = 25. Market cap after = 40.91 x 11 - 25 = 425. Minted = 25 / 40.91 = 0.611. Supply = 11.611. New price = 425 / 11.611 = $36.60. UST left = 25.

The price falls $9.09, then $4.31, then $2.09, because the UST redeemed shrinks. This is the benign case: UST is 20% of LUNA's cap. Now change the start to 1,000 UST, 10 LUNA at $60 (cap $600, less than the UST outstanding) and redeem 20% per step for five steps (the lab's `test_spiral_accelerates`). The price falls every step, and on step 5 the redemption exceeds the remaining market cap, so `mcap_after <= 0`, the step is recorded as `collapsed` with price 0, and the loop stops. The small-scale version is `test_terra_collapse_stops`: 100 UST, LUNA cap $50, redeem 60 gives mcap_after = 50 - 60 = -10.

`main()` runs the same logic with stylised numbers ($18 billion of UST against $17 billion of LUNA at $50) for 14 redemption steps. The start is deliberately past the tipping point to compress the dynamics; the real pre-collapse LUNA cap was roughly 1.5-2x UST (about $30 billion against $18 billion; cap figure unverified). It shows mechanics, not a replay. the price falls from $50 to near zero by step 12 and step 13 collapses. It also walks six ETH vaults opened on 1 May 2022 at 1.6x to 4.0x through ETH/USDT closes to 1 July: the lowest ratios go on 7 to 11 May, the 4.0x vault at the 18 June low of $995. All six are liquidated: 400% collateral does not survive a 65% fall.

## Exercises

1. A vault holds 5 ETH at $3,000 and the protocol's minimum ratio is 1.5. How much can be minted at most, and at what ETH price is the vault liquidated if the user mints that maximum? Then repeat for a user who mints only $6,000.
   **Hint:** `max_mint(collateral_value, min_ratio)` and `liquidation_price(amount, debt, min_ratio)`.
   **Solution sketch:** Collateral value is $15,000, so the maximum is $10,000, and the liquidation price is 10,000 x 1.5 / 5 = $3,000 (immediately). With $6,000 of debt it is 6,000 x 1.5 / 5 = $1,800, a 40% fall.

2. Why does `liquidations` report each vault only once even if the price falls below the threshold on many days?
   **Hint:** What happens to a vault's collateral after liquidation?
   **Solution sketch:** After liquidation the collateral is sold and the debt repaid, so the vault no longer exists. Without a "done" set, a low price path reports the same vault every step.

3. An issuer has $98 of reserves against $100 of tokens (`reserve_coverage` = 0.98). If every holder redeems at once, what does the last holder get, and why does that make the first redeemers rational?
   **Hint:** First come, first served at $1 until reserves run out.
   **Solution sketch:** Paid first come first served, the first 98 tokens get $1 each and the last 2 get nothing (pro rata in bankruptcy: 98 cents). Being early is worth up to 2%, so redeeming first is rational even if the gap looks small; that is a run.

4. In `terra_spiral(100, 10, 50, [0.5, 0.5])`, compute step 2's LUNA price and explain why the price falls less on step 2 than on step 1.
   **Hint:** Use the worked example values.
   **Solution sketch:** Step 2 gives $36.60 against $40.91 after step 1. Each step removes R dollars of cap and spreads what remains over more coins: R is $50 on step 1 and $25 on step 2, and supply is larger on step 2, so the fall is smaller. Halving a shrinking UST base means each redemption is smaller; the spiral deepens only when redemptions grow relative to the remaining cap.

5. A lending protocol offers 12% on USDC while T-bills yield 4%. List two places the extra 8% could come from and one question you would ask before depositing.
   **Hint:** Who is paying, and what do they risk?
   **Solution sketch:** Leveraged borrowers paying for dollars (it vanishes in a liquidation wave), or token emissions or a subsidy (it ends with new money). Ask how borrowers are liquidated and whether the reward is paid in the protocol's own token.

6. A Vietnamese saver compares USDT bought on a foreign exchange, a USD time deposit (where permitted), and gold. List the issuer or legal risk for each.
   **Hint:** Use the three designs and Day 16's dollarisation channels.
   **Solution sketch:** USDT carries reserve and redemption risk, attestation instead of audit, and unclear legal status at home. The deposit carries bank credit risk and SBV rules. Gold carries price risk and the premium over world gold.

## Anti-patterns / Common mistakes

- **"1 stablecoin = 1 dollar always."** The peg is a promise with a price, set by reserve quality, who can redeem, and liquidity. USDC reached $0.87 in March 2023 and DAI about $0.90 with it; UST went to near zero.
- **Ignoring redemption gates and who can redeem.** Primary redemption is often for large verified customers; a retail holder sells on a market that can sit below $1 for days.
- **Taking yield without asking its source.** Name the line on a balance sheet that pays it: T-bill income, borrower interest, or a subsidy. If you cannot, assume the last.

## Lab

From `economy_monetary_mastery/labs/`: open `day21/README.md`, implement `max_mint`, `liquidation_price`, `liquidations`, `terra_spiral` and `reserve_coverage` in `day21/lab.py`, then run `uv run pytest day21` until green and `uv run python -m day21.lab` for the summary and `.cache/plots/day21.png`. Expected: 6 tests pass; all six sample vaults are liquidated on the May-June 2022 ETH path and the stylised spiral ends in a collapsed step.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: name the stablecoin you hold or might hold, say which of the three designs it is and what its worst-case failure would look like for you, and state one dated, checkable claim about it (for example: its reserve report next month shows at least 99% in Treasuries, or its market cap stays above a stated level through a date). Say what evidence would prove you wrong.
