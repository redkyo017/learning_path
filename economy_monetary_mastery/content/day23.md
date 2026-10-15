# Day 23 — Crypto market structure: CEX, perps, basis

> Block 4: Crypto deep dive. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Most crypto trading does not happen on a blockchain. It happens on company-run exchanges whose internal ledgers are databases, and by traded volume the biggest market on those exchanges is typically not spot but perpetual futures. If you hold coins "on an exchange", you hold an IOU, which puts you back on the hierarchy of money from [Day 1](day01.md): a claim on a private balance sheet, ranked by how surely it settles into the asset above it. If you trade a perpetual, you pay or receive a periodic cash flow (funding) that keeps the contract near spot, and that flow is a directly observable gauge of leveraged-long demand.

Three questions organise the day. Where do your coins actually sit, and what did FTX show about that? How does a contract with no expiry stay tied to spot, and who pays whom? And what does the "cash-and-carry" trade earn, what does it risk, and why is "free money" the wrong description? You will annualize real Binance funding, measure basis, and price one quarter of the trade from the snapshot.

## Core concepts

### Centralized versus decentralized venues

A **centralized exchange (CEX)** such as Binance, OKX or Coinbase is a company. It takes your deposit, credits a number in its own database, matches orders off-chain at high speed and settles trades by editing that database. A **decentralized exchange (DEX)** is a smart contract ([Day 22](day22.md)): you keep your keys, trades settle on-chain, and the price is set by a pool rather than a matching engine. The trade-off is speed, depth and leverage (CEX) against custody and transparency (DEX).

| | CEX | DEX ([Day 22](day22.md)) |
|---|---|---|
| Who holds assets | the operator | your wallet / the contract |
| Matching | order book ([Day 9](day09.md)), off-chain | pool formula, on-chain |
| Leverage and perps | deep, up to very high leverage | exists, thinner |
| Main risk | operator failure, fraud, freeze | contract bug, oracle, MEV |
| Rules and recourse | company terms plus licensing | code |

### Custody: an exchange balance is an IOU

When you deposit 1 BTC, the BTC goes to the exchange's wallets and your account shows "1 BTC". The T-account makes the claim visible:

```
        Exchange                                  You
  Assets            | Liabilities         Assets                  | Liabilities
  BTC in wallets +1 | Customer BTC +1     Own-wallet BTC -1       |
                                          Claim on exchange +1    |
```

Your claim is an unsecured liability of the exchange, the same structure as a bank deposit ([Day 2](day02.md)) but without deposit insurance or a central-bank backstop. It stays whole only if the exchange keeps at least as many real coins as it owes. Two ideas help you check that:

- **Proof of reserves** shows the exchange controls certain wallets holding X coins. It says nothing about what it owes, so it shows only one side of the balance sheet.
- **Proof of solvency** adds the liability side (usually via a cryptographic commitment to every customer balance) and shows assets are at least liabilities. Even this misses off-book borrowing and is only as good as the audit around it.

**FTX (November 2022)** is the case study. FTX and Alameda filed for Chapter 11 bankruptcy on 11 November 2022 ([law-firm summary](https://www.dgslaw.com/news-events/dgs-legal-alert-ftx-trading-and-alameda-research-fall-into-chapter-11)) after customers asked for withdrawals it could not meet. Customer deposits had been lent or used by its sister trading firm, Alameda Research, so the liabilities (customer balances) stayed on one side while the assets were illiquid or token holdings valued at a price FTX itself influenced. Run on a balance-sheet gap, exactly as in [Day 5](day05.md): when assets cannot be turned into cash at par quickly, withdrawal demand exposes the gap. The lesson is structural, not about one person: a custodian that rehypothecates client assets and holds illiquid collateral is a leveraged bank without regulation.

### Perpetual futures

A **dated future** is a contract to buy or sell at a set price on a set date. The CME, a regulated US derivatives exchange, lists cash-settled bitcoin futures (launched December 2017, per the [CME press release](https://www.cmegroup.com/media-room/press-releases/2017/12/01/cme_group_self-certifiesbitcoinfuturestolaunchdec18.html)), and its price converges to spot on expiry, which is what pins it. A **perpetual future** (perp) has no expiry, so it needs another mechanism to stay near spot.

- **Mark price** is the reference used for margin and liquidation, usually built from an index of spot prices from several venues so a single thin trade cannot trigger liquidations.
- **Funding rate** is a periodic payment between longs and shorts. When the perp trades above the index, the rate is positive and longs pay shorts; when below, shorts pay longs. This makes holding the crowded side costly and pulls the perp toward spot.
- **Funding interval.** Binance settles funding every 8 hours (00:00, 08:00, 16:00 UTC) by default, but may change a contract's interval, and since 2025-05-02 a contract that hits its funding cap or floor moves to hourly settlement, later reverting to 4-hourly ([Binance FAQ](https://www.binance.com/en/support/faq/introduction-to-binance-futures-funding-rates-360033525031)). OKX also settles every 8 hours by default, with 1, 2 or 4 hours for specific contracts ([OKX help](https://www.okx.com/help/perps-funding-fee-mechanism)). Always read the interval for the specific contract; the lab's `periods_per_day` argument exists for this reason. The snapshot is the 8-hour BTC/USDT series.

Money moves like this when funding is positive, for a 10,000 USDT position and rate 0.01%:

```
        Long account                 Short account
  Margin  | funding paid -1       Margin  | funding received +1
```

**Leverage** means controlling notional N with margin M, leverage N/M. The **liquidation engine** closes your position when margin falls under the maintenance level. If the price gaps past the bankruptcy point before the position closes, the loss exceeds your margin. Exchanges first use an **insurance fund**, then **auto-deleveraging (ADL)**, which closes profitable opposite positions at the bankruptcy price. So the winning side of a trade can be forced out by the exchange's risk system, another counterparty exposure that a bank account does not have.

### Why funding is usually positive

Spot buyers are limited by cash; perp buyers can lever up. In a rising or optimistic market, demand for leveraged long exposure exceeds demand for short exposure, the perp trades at a premium, and longs pay shorts. In the snapshot, annualized BTC funding averaged about 31% in 2021 (the leveraged boom), then fell to about 4% in 2022, partly because 22% of the funding periods were negative. Negative stretches follow sell-offs, when shorts dominate. The sign flips; the typical level stays above zero.

### Basis and the cash-and-carry

**Basis** is future minus spot, as a fraction of spot. A market where the future is above spot is in **contango**. **Annualized basis** scales it to a year: a 2% premium on a 90-day future is 2% × 365/90 = 8.1% a year.

The **cash-and-carry** (basis) trade buys spot and sells the same size of future (or perp). The two price moves cancel, so profit is the basis captured at entry plus any funding:

```
   t0                         at expiry (futures converge)
 Buy spot   100  (long)       spot 110: +10
 Sell fut   102  (short)      fut  110: -8      net = +10 - 8 = +2 = entry basis
```

With a dated future the gain is locked if both legs are held to expiry. With a perp the gain is the funding collected, and the risk is that funding falls or turns negative. The risks that make it not "free money":

- the short leg needs margin; a big price rise can liquidate it even though the spot leg is up, forcing you to post more collateral, or lose the hedge;
- both legs sit with exchanges (or an exchange plus a custodian), so counterparty failure ends the trade;
- fees, borrowing costs and the opportunity cost of tied-up capital reduce the yield; and
- funding can turn negative for long periods.

### Spot bitcoin and ether ETFs

Exchange-traded funds that hold the coin directly moved crypto exposure into brokerage accounts. The SEC approved spot bitcoin products on 10 January 2024 (see [Day 19](day19.md)) and spot ether products reached trading on 23 July 2024 ([Mayer Brown on the May rule approvals](https://www.mayerbrown.com/zh-hans/insights/publications/2024/05/sec-approves-listings-of-spot-ether-etfs-waiting-is-the-hardest-part); [Baker McKenzie on the 23 July launch](https://blockchain.bakermckenzie.com/2024/07/23/ethereum-etfs-to-start-trading-today-in-the-united-states/)). At first they could create and redeem shares only for **cash**: an authorised participant (AP) paid cash and the issuer bought coins. On 29 July 2025 the SEC approved **in-kind** creations and redemptions, where the AP delivers or receives the coins directly ([SEC press release](https://www.sec.gov/newsroom/press-releases/2025-101-sec-permits-kind-creations-redemptions-crypto-etps)). That removes the issuer's trading step and can lower costs, and the same day the SEC approved options on certain spot bitcoin ETPs. The market-structure effect: a regulated, custody-backed route for institutions and advisers; ETF flows become a visible demand series; the coins sit with a small set of custodians (more concentration, less exchange-IOU risk for the holder); and the basis trade has a regulated leg, since ETF shares and CME futures can be hedged against each other.

### Crypto for a Vietnam-based investor

This is a legal-status summary, not advice; check current rules before acting. As of 2026-10, per the sources below: Resolution 05/2025/NQ-CP (9 September 2025) set up a five-year pilot of a regulated crypto-asset market, and Ministry of Finance Decision 96/QĐ-BTC opened applications for exchange licences from 20 January 2026 ([Viet Nam News](https://vietnamnews.vn/economy/1764223/applications-for-licences-of-crypto-asset-exchanges-to-be-accepted.html)). The stated minimum paid-in capital is VND 10 trillion (about US$380 million), with at least 65% from institutional investors. No licence issued was confirmed in the sources used; a later Viet Nam News piece described firms positioning to qualify ([Viet Nam News](https://vietnamnews.vn/economy/1777642/big-capital-alliances-race-to-build-crypto-asset-exchanges.html)). The status of any individual licence is therefore unverified as of 2026-10. Reports also describe Decree 284/2026 (issued 16 July 2026, effective 1 September 2026) with administrative fines for domestic investors who trade outside licensed providers, but sources differ on the amounts and say enforcement may follow only after the first licence ([The Block](https://theblock.co/post/408980/vietnam-new-unlicensed-crypto-trading-fines-on-par-drunk-driving-penalties); [Luat Viet Nam](https://luatvietnam.vn/legal-updates/vietnam-fines-crypto-traders-up-to-usd-1900-for-using-unlicensed-platforms-892-110629-article.html)). These are reported, not confirmed against the decree text here; check the Ministry of Finance. The price mechanics above are separate from the legal question of which venues a Vietnamese resident may use; for the wider picture see [Day 16](day16.md) (Vietnam, exchanges) and [Day 15](day15.md) (capital controls).

## Worked example

One quarter of a cash-and-carry on the snapshot: Q1 2021, from 2021-01-01 to 2021-03-31, one BTC.

- Spot close 29,331.69 → 58,740.55. Binance BTC/USDT:USDT perp close 29,337.16 → 58,807.24. BTC doubled.
- Price legs: `cash_and_carry_pnl(29331.69, 29337.16, 58740.55, 58807.24, 1.0)` = (58,740.55 − 29,331.69) − (58,807.24 − 29,337.16) = 29,408.86 − 29,470.08 = **−61.22**. The entry basis was +5.47 and the exit basis +66.69 (a perp premium at the quarter-end close), so the legs lost 61.22.
- Funding: 270 eight-hour rates in the quarter sum to 0.1634 (16.34%). A short of notional 29,337.16 receives `funding_pnl(29337.16, rates, "short")` ≈ **+4,793.76**.
- Net ≈ 4,793.76 − 61.22 = **+4,732.54** on 29,331.69 of spot capital: about **16.1% in a quarter**, roughly 65% simple annualized (× 365/90), before fees and with the short notional held fixed at entry.

The caveat is the point. The price doubled, so the short perp lost about 29,470 on paper and needed margin posted from somewhere. Held at a fixed size with idle collateral, it would have been liquidated by the rally in many setups; the spot leg's gain is not available as margin on the exchange. 2021 was the peak: annualized funding that year was about 31% on average, and the same trade in Q1 2023 earned only about 2% for the quarter (funding sum 0.0202 over 270 periods). Compare lab output: a fee-free carry from 2021 earned about 62% of notional over 5.7 years (about 11% a year, simple) against +185% for holding BTC.

## Exercises

1. A 30-day future trades at 51,000 against spot 50,000. Compute basis and annualized basis, using 365 days.
   **Hint:** basis is a fraction of spot; scale by 365/days.
   **Solution sketch:** basis = 1,000/50,000 = 2.0%; annualized = 2.0% × 365/30 = 24.3%. It is a simple annualization, not compounded.

2. Perp funding is +0.01% every 8 hours. What is the simple annualized figure, and what does a long with 10,000 notional pay per day?
   **Hint:** three periods a day and 365 days.
   **Solution sketch:** 0.0001 × 3 × 365 = 10.95% a year. Per day a 10,000 long pays 10,000 × 0.0001 × 3 = 3.00; the short receives 3.00.

3. You do a cash-and-carry: buy 2 BTC at 40,000, sell 2 BTC future at 41,000. At expiry both are 36,000. Compute the P&L and say what it depends on.
   **Hint:** each leg separately, then net.
   **Solution sketch:** spot leg 2 × (36,000 − 40,000) = −8,000; future leg 2 × (41,000 − 36,000) = +10,000; net +2,000 = 2 × entry basis of 1,000. It depends on the entry basis (and cost of carry), not on direction.

4. An exchange shows a proof of reserves of 100,000 BTC. Can you conclude it is solvent?
   **Hint:** which side of the balance sheet is missing?
   **Solution sketch:** no. Reserves are assets only. Customer liabilities could be 150,000 BTC, or the wallets could be pledged elsewhere. You need liabilities (proof of solvency) and ideally an independent audit; the FTX gap was on exactly that side.

5. A funding-carry short has margin 20% of notional and a mark price 15% above entry. What is the rough state of the short leg, and what is the fix?
   **Hint:** a short loses as price rises; compare loss with margin.
   **Solution sketch:** the short has lost 15% of notional, leaving about 5% of margin before maintenance requirements; liquidation is close if maintenance margin is, say, 0.5 to 1% of notional (exchange-specific; check the contract), because the cushion above it is about 4 to 4.5% of notional, so a further rise of that size triggers it. The fix is to post more margin (from outside the spot leg, because that is held elsewhere), cut the position, or size the trade with lower leverage from the start.

6. For a Vietnam-based investor, list three questions to ask before using any exchange, given the pilot framework above.
   **Hint:** legal status, custody and tax.
   **Solution sketch:** is the venue licensed under the pilot or offshore; where are customer assets held and is there a solvency attestation; how are gains reported for tax. The pilot status is unverified as of 2026-10, so check the Ministry of Finance for the current list.

## Anti-patterns / Common mistakes

- **Leverage as a strategy.** Leverage multiplies both outcomes and adds a liquidation boundary. A position can be right and still be closed.
- **"Funding is free money."** The carry earns for taking exchange counterparty risk, the margin and liquidation risk on the short leg, and the risk that funding turns negative. Quote it net of fees and capital tied up.
- **Keeping assets on exchanges.** A balance is an IOU. Hold only trading working capital there; a proof of reserves is not a proof of solvency.
- **Treating annualized funding as a forecast.** The snapshot ranges from about 31% (2021) to about 3% (2026 to date). It is a regime-dependent rate, not a constant.
- **Ignoring the contract's interval.** Funding may be 8-hourly, 4-hourly or hourly; annualizing with the wrong periods per day misstates the yield by a multiple.

## Lab

Open [`labs/day23/README.md`](../labs/day23/README.md). Implement `annualized_funding`, `basis_pct`, `annualized_basis`, `cash_and_carry_pnl` and `funding_pnl` in `lab.py` and run `uv run pytest day23`. `main()` loads the Binance BTC funding and the spot and perp daily closes, prints annualized funding and the share of negative periods by year, the perp-minus-spot basis distribution and a fee-free "short perp + long spot" carry from 2021, and saves `.cache/plots/day23.png`.

## Teardown

Nothing billable is created. The lab only reads frozen snapshots; no account, no key, no exchange order.

## Journal prompt

Pick one exchange or product you use or are considering. Write down what you actually own (an asset or an IOU), what would make that claim fail, and what level of funding or basis you would need to be paid for taking the counterparty and liquidation risks.
