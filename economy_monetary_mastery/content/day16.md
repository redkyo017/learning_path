# Day 16 — Vietnam: SBV tools, VND band, exchanges

> Block 3: FX, the dollar & Vietnam. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Your Vietnamese holdings sit inside three rule systems that the US-centred days barely touch: a central bank that manages the dong's exchange rate day by day, a stock market with hard daily price limits and foreign-ownership caps, and a capital account that is open to money coming in and tightly managed going out. Each one changes what a backtest, a price chart or a "return" means. A stock that closed at its floor three days running was not tradeable at the quoted prices; a dong that "never leaves its band" tells you about the SBV's reaction function, not about market equilibrium.

Day 15 ("Impossible trinity, capital controls, currency crises") gave the framework: a country cannot hold a fixed rate, free capital flows and an independent monetary policy at once. Vietnam's answer is a managed crawl, selective capital controls and a monetary policy that leans on quantity tools as well as rates. Today is that answer in detail, followed by the stock market it shapes.

## Core concepts

### What the State Bank of Vietnam does

The State Bank of Vietnam (SBV) is both central bank and bank regulator, and it also manages the gold market. Its tools, with the verification status as of 2026-10:

- **Policy rates.** A refinancing rate (the price of its loans to banks against collateral) and a rediscount rate. The refinancing rate was cut to 4.50% and the rediscount rate to 3.00% effective 19 June 2023 ([VnEconomy](https://en.vneconomy.vn/sbv-cuts-regulatory-interest-rates-by-0-5.htm), Decision 1123/QD-NHNN); DBS reported the refinancing rate still unchanged at 4.50% in the first half of 2026 ([DBS via FXStreet](https://www.fxstreet.com/news/vietnam-supportive-stance-as-inflation-risks-recede-dbs-202607071949), secondary). A later SBV decision was not found; the SBV's [site](https://www.sbv.gov.vn) is the authority.
- **Open-market operations (OMO).** Short-term lending or paper trades with commercial banks to steer interbank rates, as in Day 3's framework.
- **Reserve requirements.** A share of deposits banks must hold at the SBV (Day 2).
- **Credit growth quotas ("room").** An annual cap per bank on how fast loans may grow, a quantity tool that works even when the policy rate does not move (Day 2). The Prime Minister directed a pilot to abolish it from 2026 ([Vietstock](https://en.vietstock.vn/2025/08/roadmap-outlined-to-abolish-credit-quotas-37-618973.htm)); how far the pilot has gone is unverified as of 2026-10.
- **FX intervention.** Selling or buying dollars to keep the dong inside its band.
- **Gold market management.** Licensing who may make and trade gold bars (below).

The mix matters for an investor: a country with a 4.5% policy rate and a credit quota is steering credit volume directly, so bank loan growth, and therefore property and equity liquidity, can change without any headline rate move.

### The VND regime: central rate, band, crawl

Each working day the SBV publishes a **central rate** (tỷ giá trung tâm) for USD/VND. Commercial banks may buy and sell dollars only within a band around it. The band was widened from ±3% to ±5% in October 2022 ([The Investor](https://theinvestor.vn/central-bank-expands-dollar-trading-band-to-5-d2174.html)); no later change was found as of 2026-10. The mechanics, using the Day 13 quote convention (VND per USD):

```
central rate 25,000  ->  band 23,750 .. 26,250   (lab: sbv_band)
market 26,100  -> |26,100/25,000 - 1| = 4.4%  -> inside the band (lab: within_band)
```

The regime is a **managed crawl**: the central rate is adjusted gradually, with the SBV reacting to the dollar index, regional currencies and reserve levels, rather than a fixed peg or a free float. In 2026 a secondary report put the central rate at VND 25,433 on 6 August ([the-shiv.com](https://the-shiv.com/vietnam-c-bank-weakens-central-exchange-rate-august-06-2026/), unverified as of 2026-10) while the same report put the market rate at 26,235: a market rate more than 3% above the central rate, still inside the band. Banks' dollar selling price can reach the band ceiling; when the market presses on it, the SBV sells reserves or tightens dong liquidity. The central-rate history is not in this course's snapshot, so the lab's band demo uses a 60-day rolling mean of USD/VND as a labelled **proxy**. Because the proxy is built from the market, it can hardly ever show a breach; treat that output as plumbing practice, not evidence.

**Dollarization history.** Through the 1990s and 2000s many Vietnamese held savings in US dollars and gold, and a deposit in dollars was a normal asset. The SBV's tight rules on foreign-currency deposits and loans, plus a positive interest-rate gap between dong and dollar deposits, reduced it, but gold remains a household store of value.

**Reserves and import cover.** FX reserves are the SBV's ammunition. The standard gauge is **import cover**: reserves divided by monthly imports. A common rule of thumb is about three months. Import cover was reported at roughly 2.1 months in September 2025 (CEIC, a secondary aggregator; the SBV does not publish reserves on a fixed schedule), below that rule of thumb, which is one reason the SBV leans on the band and on capital-flow rules. Verify against IMF data before quoting.

### Gold in Vietnam

Gold is a parallel savings system. SJC-brand bars historically carried a **premium** over the converted world price because supply was a state-managed monopoly: in 2026 the premium ranged from roughly VND 15 million to VND 28 million per tael (a tael, or lượng, is about 37.5 grams), for example about VND 17.6 million on 9 May 2026 ([Tuoi Tre](https://news.tuoitre.vn/vietnam-sjc-gold-prices-slide-347-103260131150721124.htm); other dates from the same news outlets, premium figures vary by source and exclude fees).

The 2024 reform came first: the SBV auctioned SJC bars from 19 April 2024 (nine auctions, six completed, 48,500 taels released), then [suspended them in late May](https://vietnamnews.vn/economy/1656363/central-bank-suspends-gold-bar-auctions-announces-market-inspections.html) and, per press reports not re-fetched here, switched to direct sales through four state banks and SJC from 3 June 2024, which narrowed the premium from roughly VND 18 million to about 9.5 million per tael before it widened again in 2025-2026.

Then Decree 232/2025/ND-CP, 26 August 2025, [ended the state monopoly on gold bar production](https://theinvestor.vn/state-monopoly-on-gold-production-eliminated-d16805.html) and made it a licensed activity for commercial banks (VND 50 trillion charter capital) and enterprises (VND 1 trillion); gold transactions of VND 20 million or more per day by one customer must go through a bank account ([Tuoi Tre](https://tuoitre.vn/nld/ending-the-sjc-gold-bar-monopoly-196250828100702764.htm)). The decree took effect on 10 October 2025. By April 2026 the SBV was reviewing [11 licence applications](https://vietnamnews.vn/economy/1779476/sbv-weighs-11-bids-for-gold-bar-licences.html) and no licence had been reported awarded; a gold exchange remained at proposal stage.

Why gold matters beyond jewellery: it is a household savings asset that competes with bank deposits and equities, and Vietnam imports it, so a gold rush spends the dollars the SBV needs for the band. It is a pressure valve on the trinity.

### Capital flows: why the trinity binds

Dollars come in through four channels: **FDI** (factories financed from abroad), **remittances** from overseas Vietnamese, the **trade surplus** (exports exceed imports) and tourism. Dollars leave through imports, profit repatriation, debt service, gold imports and household outflows. When inflows exceed outflows the SBV buys dollars to hold the dong from appreciating and pays for them in dong, which adds to bank reserves:

```
SBV balance sheet (buys USD 100 from a bank at 25,000 VND/USD)
  Assets              | Liabilities
  FX reserves +USD100 | Bank reserves +VND 2,500,000
```

This is the same reserves logic as Day 3: buying FX adds reserves, as QE does. If the SBV does not sterilise (sell paper to take the dong back), the money supply grows. If outflows dominate, the SBV sells reserves, bank reserves fall and liquidity tightens just when the economy may want easing. That is the trinity in action (Day 15): with a managed rate and a loosely open capital account for inflows, monetary independence is partial and depends on keeping reserves ample and capital controls on outflows.

### The stock market

**Exchanges.** HOSE (Ho Chi Minh City) lists the large caps; HNX (Hanoi) lists smaller-cap stocks and also runs the government-bond and derivatives markets; UPCoM is the over-the-counter-style board for unlisted public companies. Indices: **VN-Index** (all HOSE stocks, cap-weighted) and **VN30** (the 30 largest, most liquid). Both are concentrated: a handful of banks, Vingroup-related names and state-owned companies carry a large weight, which is why VN-Index behaves nothing like the broad-based S&P 500.

**Trading mechanics (HOSE, as of 2026-10).** Day 9 covers the KRX system, lot size 100, T+2 settlement and the session structure; the figures below match it. Cycle: ATO opening auction 9:00 to 9:15, continuous matching until 11:30 and from 13:00 to 14:30, ATC closing auction 14:30 to 14:45 ([BSC handbook](https://www.bsc.com.vn/en/trading-session-on-the-market/)); HNX has no opening auction; UPCoM sessions differ and broker confirmation is needed.

| Board | Daily limit vs reference price | Tick (VND) |
|---|---|---|
| HOSE | ±7% | 10 below 10,000; 50 from 10,000 to 49,950; 100 from 50,000 |
| HNX | ±10% | 100 (per broker guides) |
| UPCoM | ±15% | 100 (per broker guides) |

The percentage limits are from [FPTS](https://fpts.com.vn/customer-service/stock-trading/trading-regulations/hnx-trading-regulations) and the BSC handbook; newly listed or resuming stocks get wider bands (HNX up to 30%, UPCoM up to 40% by the same sources, HOSE ±20% on day one per Day 9). The **reference price** is the prior session's closing matched price on HOSE and HNX; on UPCoM it is the volume-weighted average price of the previous day's continuous-matching trades, and on all boards it is adjusted on ex-rights dates (so the lab's `flag_limit_moves(..., "UPCOM")`, which uses the prior close, is a simplification). A limit is not a halt: trading continues, but nobody can trade beyond the floor or ceiling, so the book often has a queue on one side only. Settlement is T+2; a T+1 equity cycle is unverified as of 2026-10 (Day 9). The lab's tick rule rounds the ceiling down and the floor up to the tick at the raw price, so the actual limit is never wider than 7%.

**Foreign ownership limits (FOL).** Foreign holders may own only up to a cap on each company. Historically the cap was 49% of shares for most listed companies and 30% for banks. Under Decree 155/2020 the cap follows the company's registered business lines: 50% in conditional sectors with no specific cap, up to 100% in unrestricted sectors unless the charter sets a lower figure ([Mondaq](https://www.mondaq.com/shareholders/1173264/note-about-the-stock-markets-maximum-foreign-ownership-ratio-in-vietnam)). For banks the general cap is 30% of charter capital, with a single strategic foreign holder capped at 20%; Decree 69/2025 (effective 19 May 2025) lifts the 30% to 49% only for the duration of an approved compulsory-transfer plan, and excludes banks more than 50% state-owned, so large state banks such as VCB are not covered ([Vietnam News](https://vietnamnews.vn/economy/1694298/foreign-ownership-at-acquirers-of-weak-banks-to-rise-to-49.html)). The per-stock cap and current usage must be read from each issuer's disclosure; the lab's `foreign_room` shows the arithmetic. When a stock hits its cap, foreigners can only buy from other foreigners, often at a **premium** to the domestic price: "room" has a price.

**Retail dominance and margin.** Individual investors do most of the trading value, and margin lending by brokers is large relative to equity. That makes the market flow-driven: leverage amplifies falls, margin calls cluster at limit-down days, and a limit-locked stock cannot be sold at the quoted price to meet them.

**ETFs.** Domestic ETFs track VN30 and other indices; the US-listed VNM (VanEck Vietnam ETF, Day 9) gives foreign access. Details of fees and holdings were not retrieved: unverified as of 2026-10.

**Classification status.** FTSE Russell [announced in October 2025](https://www.lseg.com/en/media-centre/press-releases/ftse-russell/2025/ftse-russell-country-classification-september-2025) that Vietnam moves from frontier to secondary emerging effective 21 September 2026, [reconfirmed on 7 April 2026](https://theinvestor.vn/ftse-russell-confirms-vietnams-market-status-upgrade-to-secondary-emerging-from-sept-21-d18799.html); [Vietnam News](https://vietnamnews.vn/economy/1800133/foreign-inflows-offer-support-after-upgrade-but-macro-factors-remain-key.html) reported it in force from 21 September 2026. Brokers describe phased investability weights from September 2026 through 2027 ([ACBS](https://acbs.com.vn/acbsmedia/2026/04/Flashnote-Vietnam-Market-Upgrade-2026Apr.pdf), secondary). MSCI's review of [24 June 2026 again left Vietnam off its upgrade watch list](https://vietnamnews.vn/economy/1784056/msci-keeps-viet-nam-off-upgrade-watch-list.html) ([The Investor](https://theinvestor.vn/vietnam-left-off-msci-watch-list-despite-market-reforms-d19394.html) agrees), so Vietnam remains a frontier market in MSCI's framework; press reports cite foreign ownership limits as the largest obstacle and the non-prefunding mechanism as transitional pending a central counterparty (press, not the MSCI document).

**Investing access for a Vietnamese resident (facts only).** Domestic stocks go through a local securities company's account. Under Decree 135/2015, which remains the operative framework, resident individuals have no general channel to own foreign securities: the main route reported is employee share or bonus-share plans of a foreign employer, while entrusted investment abroad is open to resident organisations ([Conventus Law](https://conventuslaw.com/report/3-things-about-overseas-securities-investment-by/), 2016). Decree 103/2026 on outward investment (effective 3 April 2026) was reported to exclude securities and funds; its text was not retrieved. Practical FX limits for individuals are unverified as of 2026-10; the SBV or a licensed adviser is the authority. Deposit insurance: the cap is now VND 350 million per person per institution (principal plus interest) under Circular 05/2026/TT-NHNN, effective 13 July 2026 ([Bao Nghe An](https://baonghean.vn/en/chinh-thuc-nang-han-muc-bao-hiem-tien-gui-len-350-trieu-dong-10344498.html)); it was VND 125 million under Decision 32/2021 ([DIV](https://www.div.gov.vn/raising-deposit-insurance-coverage-limit-enhancing-depositor-protection-en)).

## Worked example

A HOSE stock closes at a reference price of 25,000 VND, which sits in the 50-VND tick bracket. It then falls to the floor for three sessions. Use `price_limits(ref, "HOSE")`:

| Day | Reference | Raw floor (-7%) | Floor after rounding up to tick | Cumulative |
|---|---|---|---|---|
| 1 | 25,000 | 23,250 | 23,250 | -7.0% |
| 2 | 23,250 | 21,622.5 | 21,650 | -13.4% |
| 3 | 21,650 | 20,134.5 | 20,150 | -19.4% |

Three consecutive floors cost 19.4% (each step is 7% of a lower price, and the tick rounding gives a few VND back). On each day the ceiling for the next session is higher than the last close: day 1's close allows up to 24,850 on day 2. The point for backtests: if your data shows these three closes and your strategy "sold at the close of day 1", the quote was a locked floor and nobody was selling to you at 23,250 unless a buyer joined the queue. The lab flags such days with `flag_limit_moves`.

With the lab's snapshot data the flag needs care: Vietcap closes are dividend/split-adjusted, so they rarely equal a tick price, and the exact-limit count is zero for FPT, HPG and VCB. `main()` therefore also prints a tolerance count (moves of at least 6.5%): HPG 59 days (1.4%), VCB 31 (0.7%), FPT 24 (0.6%) over 4,175 days. That is an approximation. A faithful limit detector needs unadjusted closes and the actual reference prices.

## Exercises

1. The central rate is 25,433 VND per USD and the band is ±5%. Between which rates may banks trade, and is a market rate of 26,235 inside it?
   **Hint:** `sbv_band`, then compare using `abs(market/central - 1)`.
   **Solution sketch:** The band is 24,161.35 to 26,704.65. The market rate deviates by 26,235/25,433 - 1 = 3.15%, so it is inside; the ceiling is about 470 VND above it.

2. A HOSE stock has a reference price of 60,000 VND. What are its floor, ceiling and tick? Then repeat for a 9,800 VND stock.
   **Hint:** 60,000 is in the 100-VND tick bracket; for the second stock check which tick applies at the raw floor and raw ceiling separately.
   **Solution sketch:** First stock: floor 55,800, ceiling 64,200, tick 100. Second stock: raw floor 9,114 and raw ceiling 10,486; the floor uses tick 10 and rounds up to 9,120, while the ceiling uses tick 50 and rounds down to 10,450.

3. Why does `price_limits` use `round(ref*(1±limit), 6)` before flooring and ceiling?
   **Hint:** Try `12000 * 1.15` in Python for an UPCoM stock.
   **Solution sketch:** It prints 13799.999999999998, not 13800. Without rounding, the ceiling floors to 13,700 (one tick too low); with `round(..., 6)` it is 13,800. Rounding to six decimals removes the noise without altering real values.

4. A bank has 1,000 million shares outstanding and a 30% foreign cap; foreigners hold 280 million. How much room remains? If the cap rises to 49% (the temporary Decree 69/2025 case for acquirers), how does room change?
   **Hint:** `max(0, cap*total - foreign)`.
   **Solution sketch:** At 30% the room is 20 million shares; at 49% it is 210 million. A move in the cap changes the supply of "foreign-eligible" shares far more than it changes price directly, which is where room premiums come from.

5. A backtest buys any stock whose close hits the ceiling and sells next day, assuming the close price fills. What is wrong, and how would you adjust it?
   **Hint:** Think about who can sell to you at a ceiling.
   **Solution sketch:** At a ceiling there are mostly buyers in the queue and few sellers, so a market participant cannot obtain shares at that price. Remove limit-locked days from the entry set, or fill only the share of the queue you could realistically get; use the flagged days to test sensitivity.

6. Dollars flow into Vietnam at a rate of USD 1 billion a month beyond what the economy absorbs. Draw the SBV T-account if it buys all of it at 25,000 and explain the monetary consequence.
   **Hint:** Reserves rise on the liability side.
   **Solution sketch:** FX reserves +USD 1 billion (VND 25 trillion at 25,000) as an asset, and bank reserves +VND 25 trillion as a liability. Bank lending capacity rises unless the SBV sterilises by issuing bills; sterilising absorbs the dong but costs interest.

## Anti-patterns / Common mistakes

- **Ignoring limit-locked days in backtests.** A close at the floor or ceiling is not a price at which you could trade. Flag those days and either skip them or model a partial fill.
- **Treating VN-Index like the S&P 500.** VN-Index is concentrated in banks, property and state-owned companies, is retail- and margin-driven, and was at 11.9 times earnings on 31 July 2026 (VDSC, Day 8) with a drawdown near 45% in the snapshot. Do not carry US factor or valuation intuitions across without checking.
- **Ignoring FOL "room" premiums.** A stock that looks cheap to a foreign buyer may have no room, and the premium to buy room is a real cost. Check the foreign ownership ratio before assuming you can buy.
- **Reading the band as a forecast.** A USD/VND series that stays within ±5% of the central rate says the SBV defended the band, not that the market was in equilibrium.
- **Quoting adjusted closes as historical prints.** Vietcap series are dividend/split-adjusted; use them for returns, not for reconstructing a day's limit.

## Lab

From `economy_monetary_mastery/labs/`: open `day16/README.md`, implement `sbv_band`, `within_band`, `hose_tick`, `price_limits`, `flag_limit_moves` and `foreign_room` in `day16/lab.py`, then run `uv run pytest day16` until green and `uv run python -m day16.lab` for the summary and `.cache/plots/day16.png`. Expected: 13 tests pass (6 functions); VN-Index CAGR about 7.6% with a 45% drawdown, and the band output is labelled as a proxy.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: write down one rule from today (a limit, a cap or a settlement date) that would change how you size or exit a Vietnamese position, and one dated, checkable claim about it (for example: the HOSE band stays at ±7% through a given date, or the SBV central rate stays within a stated range). Say what evidence would prove you wrong.
