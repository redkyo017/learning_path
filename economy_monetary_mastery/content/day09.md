# Day 9 — Market structure: order books and settlement

> Block 2: Rates & asset pricing. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Block 1 was about money. Block 2 is about the places where money is swapped for assets, and the first thing a software engineer should know is that "the price" does not exist. There is a best bid, a best ask, a queue of orders behind each, and a chain of intermediaries that move your cash and shares days later. The price in an app is the last trade or the mid; the price you get is whatever your order walks into. For small orders in big names the gap is a rounding error; for big orders and thin names it is the largest cost you pay, and it is invisible in most backtests. Today you build the matching engine, measure that cost, and learn the plumbing underneath: who the intermediaries are, what the order types do, when settlement happens, and why an ETF trades near the value of what it holds.

## Core concepts

### Who is who

- **Exchange**: the venue with the order book and the matching rules (NYSE, Nasdaq; in Vietnam the Ho Chi Minh Stock Exchange, HOSE, and the Hanoi exchange, HNX).
- **Broker**: your agent. It takes your order, checks your cash or shares, routes it, and keeps your account records. Your app (Interactive Brokers, Schwab, a Vietnamese securities firm) is a broker.
- **Market maker**: a firm that posts bids and asks continuously and earns the spread for taking the other side, carrying inventory risk. It widens the spread when volatility is high or when it fears a better-informed counterparty.
- **Clearing house (CCP) and depository**: after the trade, the clearing house becomes the buyer to every seller and seller to every buyer, nets the obligations and guarantees completion; the depository records who owns the shares. In the US that is the DTCC (NSCC for clearing, DTC for custody). In Vietnam it is the VSDC, the Vietnam Securities Depository and Clearing Corporation.

The order lifecycle, from app tap to settlement:

```
 You tap "buy 10"     Broker           Exchange / venue        Clearing + depository
 ----------------> risk checks, ----> order book matches ----> trade is novated to the CCP,
                   routes order        (price-time priority)    netted, settles on T+1 (US)
                                       a Trade is printed       or T+2 (Vietnam): cash moves
                                                                one way, shares the other
```

Until settlement you hold a claim, not final ownership.

### The order book

An order book is two sorted queues. **Bids** are buy limit orders; the highest is the **best bid**. **Asks** are sell limit orders; the lowest is the **best ask**. The **spread** is `ask - bid`; the **mid** is their average; **depth** is the quantity resting at each price. Matching follows **price-time priority**: the best price trades first, and among equal prices the oldest order goes first. A trade always happens at the *resting* order's price: whoever was in the book first sets the price, the incoming order "takes" it.

A **marketable** limit order (a buy at or above the best ask) trades immediately; a non-marketable one rests and **provides liquidity**.

### Order types and when each one hurts

| Type | What it says | When it hurts you |
|---|---|---|
| Market | Fill me now at whatever the book offers | Thin book or fast market: you walk up the book and pay slippage; in a gap you can fill far from the last price |
| Limit | Fill me at this price or better | May not fill at all; you miss the move you wanted, and fills cluster when the market moves against you (adverse selection) |
| Stop (stop-market) | Becomes a market order when price touches the stop | Triggers in a flash crash or gap and fills far below the stop |
| Stop-limit | Becomes a limit order when price touches the stop | May never fill if price gaps through the limit, leaving you holding the position the stop was meant to exit |
| IOC (immediate-or-cancel) | Fill what you can now, cancel the rest | Partial fills; you must handle the remainder yourself |
| FOK (fill-or-kill) | Fill all now or nothing | Fails more often; a good tool for a precise all-or-none size |

### Spread, depth, slippage, market impact

- **Spread** is the toll for immediacy. In basis points, `(ask - bid) / mid * 10,000`. A stock quoted 99.90 / 100.00 has a 10 bp spread; crossing it for a round trip costs about 10 bp.
- **Depth** is how much you can trade before the price moves. A narrow spread with a thin book is a trap.
- **Slippage** is the gap between the price you expected (usually the mid at the decision time) and the average price you got: `avg_fill / mid - 1`. Half the spread is the floor for a market order; the rest is depth.
- **Market impact** is the part that persists: your order *moves* the market, because other participants infer information from it and replenish quotes at new prices. Impact grows with order size relative to typical volume, roughly like a power of size less than one, not linearly. Empirically the cost rises with the square root of size, a power below one. The Lab's curve is a toy version: it rises, but its slope flattens because that book holds more shares at each deeper level.

Consequences: the quoted close is one auction print, not a price you can trade at; costs scale with a strategy's *turnover*; and liquidity is not constant, since spreads widen at the open, in news and in crashes, exactly when you most want to trade.

### Settlement: T+1 in the US, T+2 in Vietnam

Settlement is the exchange of cash for shares. The US moved from T+2 to **T+1** (one business day after the trade) on 28 May 2024, per the [SEC announcement](https://www.sec.gov/news/press-release/2024-62); a sale on Monday settles Tuesday.

Vietnamese stocks settle on **T+2** as of 2026-10 (secondary market guides; an official SSC or VSDC statement on a T+1 equity cycle was not found, so treat T+1 as unverified as of 2026-10). Two recent reforms matter more than the headline cycle:

- **KRX trading system.** HOSE moved to the Korea Exchange-built system on [5 May 2025](https://vietnamnews.vn/economy/1717047/krx-system-officially-goes-live.html), after more than a decade of delays.
- **No pre-funding for foreign institutions.** Ministry of Finance [Circular 68/2024](https://en.vneconomy.vn/no-pre-funding-required-for-foreign-institutional-investors-to-purchase-vietnamese-stock-from-november-2.htm) (effective 2 November 2024) lets foreign *institutional* investors place buy orders without the full cash in the account; the securities firm assesses their payment risk and bears the shortfall if they fail to pay. Circular 18/2025/TT-BTC adds operating detail for the KRX system ([summary](https://ata-legal.com/circular-no-18-2025-tt-btc-detailed-guidance-on-non-prefunding-stock-transactions-by-foreign-institutional-investors)). [Circular 08/2026/TT-BTC](https://blogs.duanemorris.com/vietnam/2026/02/09/vietnam-securities-market-removal-of-pre-funding-requirement-what-you-must-know/) (issued 3 February 2026) effectively removes the 100% pre-funding requirement, lets foreign investors route orders through overseas brokers, and suspends violators from the mechanism for seven trading days ([Vietstock](https://en.vietstock.vn/2026/02/new-rules-ease-foreign-access-to-vietnam-equities-36-629111.htm)). It targeted FTSE Russell's criteria, and FTSE Russell [announced](https://www.lseg.com/en/media-centre/press-releases/ftse-russell/2025/ftse-russell-country-classification-september-2025) in October 2025 the move to Secondary Emerging effective 21 September 2026, [reconfirmed](https://theinvestor.vn/ftse-russell-confirms-vietnams-market-status-upgrade-to-secondary-emerging-from-sept-21-d18799.html) in April 2026 ([Vietnam News](https://vietnamnews.vn/economy/1800133/foreign-inflows-offer-support-after-upgrade-but-macro-factors-remain-key.html) reported it in force from 21 September 2026).

Vietnam's market mechanics, per the [HOSE trading rules as summarised by HSC](https://www.hsc.com.vn/en/transaction-regulations/hsx-trading-regulations.html):

- Board lot: **100 shares**; odd lots (1 to 99) trade as limit orders only, in continuous matching (some broker guides also list the auctions).
- Sessions: **ATO** (opening auction) 09:00 to 09:15, continuous matching 09:15 to 11:30 and 13:00 to 14:30, **ATC** (closing auction) 14:30 to 14:45. No amending or cancelling during ATO and ATC.
- Daily price band ±7% of the reference price on HOSE (±20% on a first trading day). At the ceiling or floor the book often has a queue on one side only.
- Tick size: 10 VND below 10,000 VND, 50 VND from 10,000 to 49,950, 100 VND at 50,000 and above; ETFs 10 VND.

### Payment for order flow (PFOF)

In the US, many retail brokers route market orders to wholesalers (large market makers) that pay the broker a small fee per share for the flow. The wholesaler profits because retail flow is, on average, less informed than institutional flow, and it promises execution at or inside the best quoted prices. The conflict is that the broker is paid by the party on the other side of your trade. For small orders in liquid stocks PFOF is usually a minor cost; for large or illiquid orders use a limit order.

### ETFs: creation, redemption and why price ≈ NAV

An ETF is a fund whose shares trade on an exchange. The **NAV** (net asset value) per share is the value of the holdings, divided by shares outstanding. The price you see on the exchange is set by supply and demand for the ETF *shares*, but arbitrage ties it to NAV through **authorized participants (APs)**, large market makers with a contract with the issuer:

- If the ETF trades at a **premium** (price above NAV), an AP buys the underlying basket, delivers it to the issuer, and receives new ETF shares (a *creation*), then sells the shares at the higher price and pockets the gap.
- If it trades at a **discount**, the AP buys ETF shares cheaply, hands them to the issuer, and receives the basket (a *redemption*), then sells the basket for more.

```
 Creation when ETF price (50.40) > NAV (50.00), unit = 1 share for illustration
        Authorized participant                        ETF issuer
  Assets              | Liabilities           Assets             | Liabilities
  (1) buy basket: Cash -50.00, Basket +50.00
  (2) deliver:    Basket -50.00, ETF share +50.40    Basket +50.00  | ETF share issued +50.00
                                  equity +0.40 (AP marks share at market)
  (3) sell share: ETF share -50.40, Cash +50.40  -> cash 50.00 -> 50.40, profit 0.40 before costs
```

That trade is the force that shrinks the premium. The mechanism is weaker when the underlying market is closed, illiquid or restricted: a US-listed fund holding Vietnamese stocks trades while Vietnam is closed, so its NAV is stale and premium/discount can be large.

Vietnam and Vietnam-related examples:

- **VNM** is the ticker of the VanEck Vietnam ETF (US-listed). It is *not* Vinamilk, whose HOSE ticker is also VNM. The US fund buys Vietnamese equities, so the closing premium or discount reflects Vietnam's stale prices (issuer fact sheet for expense ratio and holdings count not retrieved: unverified as of 2026-10).
- **E1VFVN30** (the DCVFMVN30 ETF, Dragon Capital's VN30 fund, listed on HOSE) tracks the VN30 index of the 30 largest, most liquid HOSE stocks, per this [fund overview](https://www.finhay.com.vn/en/co-nen-dau-tu-quy-etf-dcvfmvn30-e1vfvn30).
- **FUEVFVND** (the [DCVFMVN Diamond ETF](https://finance.vietstock.vn/FUEVFVND-quy-etf-dcvfmvn-diamond.htm?languageid=2)) tracks the VN Diamond index and is marketed as a way for foreign investors to get exposure to stocks whose foreign-ownership room is full.

## Worked example

Walk a 10-share market buy through a two-level book. The resting orders:

```
 ASKS (sellers)                       BIDS (buyers)
   100.10   x 8   (s2)                   99.90   x 5   (b1)
   100.00   x 6   (s1)                   99.80   x 7   (b2)
```

Best bid 99.90, best ask 100.00, spread 0.10, mid 99.95. A market buy of 10 arrives:

1. Best ask is 100.00 with 6 shares. Fill 6 at 100.00 (trade `b -> s1, 100.00, 6`). The level is empty and is deleted. 4 shares remain.
2. The next ask is 100.10 with 8 shares. Fill 4 at 100.10 (trade `-> s2, 100.10, 4`). 4 shares remain at that level.

Average fill: `(6 * 100.00 + 4 * 100.10) / 10 = 1000.40 / 10 = 100.04`. Slippage against the mid: `100.04 / 99.95 - 1 = 9.0 bp`. About half of that (5 bp) is the half-spread you pay for immediacy; the rest is depth: the book ran out at the first price.

What the book looks like after:

```
 ASKS:   100.10 x 4 (s2)          BIDS:  99.90 x 5, 99.80 x 7
 Best ask moved from 100.00 to 100.10: the spread widened from 0.10 to 0.20.
```

Had you sent a *limit* buy of 10 at 100.00, the first 6 would trade and the other 4 would rest as a new bid at 100.00. Market: certain execution, uncertain price. Limit: certain price, uncertain execution.

On the lab's random book (mid 100.00, 1-cent levels, seed 42), the same idea at scale: a 100-share market buy slips 1.0 bp (half of a 2-cent spread), 2,000 shares slip about 2.3 bp, and 8,000 shares slip about 6.1 bp.

## Exercises

1. A book has asks 100.00 x 4, 100.20 x 3, 100.50 x 10 and a best bid of 99.90. A market buy of 12 arrives. Compute the trades, the average fill price and the slippage in bp against the mid.
   **Hint:** Walk the levels in ascending price order, taking the whole level while the order is bigger; the mid is (99.90 + 100.00) / 2.
   **Solution sketch:** Trades: 4 at 100.00, 3 at 100.20, 5 at 100.50. Cost = 400.00 + 300.60 + 502.50 = 1,203.10; average = 1,203.10 / 12 = 100.258. Mid is 99.95, so slippage = 100.258 / 99.95 - 1 = 30.8 bp. The first 5 bp is the half-spread; the other 26 bp are depth.

2. With the same book, you instead send a limit buy of 8 at 100.10. What trades, what rests, and what are the new best bid, best ask and spread?
   **Hint:** A limit order only trades against asks at or below its limit.
   **Solution sketch:** It trades 4 at 100.00 (the ask at 100.20 is above the limit, so the order stops there). The remaining 4 shares rest as a bid at 100.10. New best bid 100.10, best ask 100.20, spread 0.10. You paid 100.00 on the filled part but may never fill the other 4.

3. A strategy earns 8% a year before costs and makes 50 round trips a year (buy then sell) in a stock with a 10 bp spread. It trades with market orders. What is its return after spread cost?
   **Hint:** One round trip crosses the spread twice, paying half-spread each time, so the cost is the full spread per round trip. Ignore fees and impact.
   **Solution sketch:** 50 round trips at 10 bp each cost 500 bp, 5% a year, so net is about 3%, assuming full position size each time (cost scales with the fraction of capital traded). Doubling turnover removes the profit. Backtests that fill at the close or mid pay none of this, which is the anti-pattern in the list below.

4. You sell US shares on Thursday 4 June and Vietnamese shares on Thursday 4 June (a normal business week, no holidays). On which dates does cash arrive in each case?
   **Hint:** Count business days after the trade date; weekends do not count.
   **Solution sketch:** US (T+1): Friday 5 June. Vietnam (T+2): Monday 8 June (Friday is T+1, Monday is T+2). Public holidays push both dates out.

5. An ETF trades at 50.40 while its NAV is 50.00. Describe what an authorized participant does, who profits, and why the premium shrinks. What changes if NAV is stale because the underlying market is closed?
   **Hint:** Think creation: buy the basket cheap relative to the ETF share, deliver, receive shares, sell.
   **Solution sketch:** The AP buys the underlying basket for 50.00, delivers it to the issuer, receives one ETF share (worth 50.40) and sells it, keeping 0.40 minus trading costs. Selling the ETF and buying the basket narrows the gap. If the underlying market is closed, the AP cannot price or hedge the basket, so the premium can persist until it opens; compare to an estimated NAV, not the stale one.

6. A Vietnamese stock has a reference price of 60,000 VND. What is its HOSE ceiling and floor today, the minimum tick, and the cost of one board lot? How many board lots can you buy with 5.5 million VND?
   **Hint:** Band is ±7%; the tick depends on the price bracket; a lot is 100 shares.
   **Solution sketch:** Ceiling 64,200 VND, floor 55,800 VND. Tick for prices at or above 50,000 VND is 100 VND (about 16.7 bp of 60,000), so even a one-tick spread is a visible cost. One board lot costs 6,000,000 VND, which exceeds 5.5 million, so you can buy zero board lots; you can buy up to 91 shares as an odd lot, with limit orders only.

## Anti-patterns / Common mistakes

- **Market orders in illiquid names.** A thin book turns a market order into a walk up the ladder (Exercise 1). Use a limit order sized against visible depth.
- **Ignoring the spread in backtests.** Filling at mid or close pays zero cost; a high-turnover strategy can flip from profitable to loss-making once you charge the spread (Exercise 3).
- **Assuming you trade at the close price.** The close is an auction print (ATC in Vietnam, the closing cross in the US). A market order sent late in the day does not get it.
- **Treating a stop as a guarantee.** It is a trigger; the fill can be far worse.
- **Reading VN closes in the course data as raw prints.** They are dividend/split-adjusted, fine for returns, wrong as a price you would have paid.
- **Trading an ETF at the open with a market order.** Spreads and premiums are widest in the first minutes.

## Lab

From `economy_monetary_mastery/labs/`: open `day09/README.md`, implement `best_bid`, `best_ask`, `spread`, `depth`, `submit` and `average_fill_price` in `day09/lab.py`, then run `uv run pytest day09` until green and `uv run python -m day09.lab` for the cost curve and `.cache/plots/day09.png`. Expected: 11 tests pass; slippage rises from 1.0 to about 6.1 bp.

## Teardown

Nothing billable is created. The plot lives in `labs/.cache/plots/` (gitignored).

## Journal prompt

In three sentences: pick one asset you trade or intend to trade and find its quoted bid/ask spread in bp at a quiet time and just after the open. What does a round trip cost relative to the return you hope for? Add one dated, checkable claim to your journal about spreads or premiums (for example: the spread on a ticker stays below some bp on a given date).
