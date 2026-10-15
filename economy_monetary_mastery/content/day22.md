# Day 22 — DeFi: AMMs, impermanent loss, liquidations

> Block 4: Crypto deep dive. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Decentralized finance (DeFi) rebuilds exchanges and lenders as smart contracts (Day 20) that anyone can call and nobody can pause for you. The interesting part is not the novelty but the compression: an exchange needs no matching engine, a lender needs no credit officer, and both are small enough to implement in a lab. They also expose risks that a brokerage account hides: your counterparty is code, prices come from oracles, and every pending transaction is visible to bots that can reorder it.

Three questions organise the day. How does a pool quote a price with no order book, and what does it cost the people who fund it? Where does DeFi "yield" actually come from? And who captures the value in the gap between submitting a transaction and having it included in a block? You will implement the pool, compute impermanent loss on real ETH/USDT history, and measure a sandwich attack to the unit.

## Core concepts

### AMMs versus order books

Day 9 described the order book: buyers and sellers post limit orders, a matching engine pairs them, and the price is the last match. That design needs many cheap updates per second, which a blockchain cannot afford (Day 20: every state change costs gas). An **automated market maker (AMM)** replaces the book with a pool of two tokens and a rule. Anyone can deposit both tokens as a **liquidity provider (LP)**; traders swap against the pool rather than against another person.

| | Order book (Day 9) | Constant-product AMM |
|---|---|---|
| Liquidity from | market makers posting quotes | LPs depositing a pool |
| Price | last matched order | ratio of reserves, moved by trades |
| Quote updates | continuous, cheap off-chain | only when someone trades |
| Cost to trade | spread plus fees | price impact plus fee |
| Always quotes a price | no (book can be empty) | yes, at any size, at a worsening price |

### x*y = k

A pool holds `x` of token X (say ETH) and `y` of token Y (say USDT). The rule is that a swap must leave the product unchanged: `(x + dx) * (y - dy) = x * y = k`. Solving for what a trader receives for selling `dx`:

```
dy = y * dx / (x + dx)
```

The **marginal price** of X is `y / x`. Selling X raises x and lowers y, so the price of X falls; the pool never runs out of Y because the price of Y rises without bound as y approaches zero. The trader pays the average price `dy / dx`, which is worse than the marginal price: the difference is **price impact**, roughly `dx / (x + dx)` of the trade, so impact grows with trade size relative to pool depth. Example: pool 100 X / 10,000 Y (price 100). Selling 10 X returns `10,000 - 1,000,000/110 = 909.09` Y, an average price of 90.91, 9.1% below the quoted 100.

```
        Pool (before)            Trader sells 10 X, no fee
  X: 100   | Y: 10,000        X: 110 | Y: 9,090.91      k = 1,000,000
  trader:  X -10, Y +909.09
```

### LP fees

Uniswap-style pools charge a fee on the input, and the fee stays in the pool. In the lab, only `dx * (1 - fee)` is priced but the whole `dx` is added to reserves, so `k` grows with every swap. LPs own a share of the reserves, so the growth in `k` is their income, collected when they withdraw. A 0.3% fee on a 10 X swap adds about 0.03 X to the pool.

### Concentrated liquidity (Uniswap v3)

In v2-style pools liquidity is spread over prices from zero to infinity, so most of it is never used. Uniswap v3 lets an LP pick a price range and supplies liquidity only inside it, as if the pool were much deeper there. The same capital then earns far more fees per dollar while the price stays in range, but the position holds only one token once the price exits, earns nothing, and has amplified impermanent loss. Each position is a custom bet on a price range, closer to a market maker's quote than a passive deposit.

### Uniswap versions and fee tiers (as of 2026-10)

Uniswap v3 launched in 2021 with standard fee tiers of 0.05%, 0.30% and 1%, plus a 0.01% tier added later; governance can enable more ([Uniswap docs, fees](https://developers.uniswap.org/docs/get-started/concepts/fees)). Uniswap v4 went live on mainnet at the end of January 2025 (sources give 30 or 31 January; see [The Defiant](https://thedefiant.io/news/defi/uniswap-labs-launches-v4-bringing-major-upgrades-to-its-dex) and the [DWF Labs summary](https://www.dwf-labs.com/research/457-what-s-new-in-uniswap-v4-three-key-changes-and-two-new-protocols)). v4 removes fixed tiers: a pool creator sets any fee from 0% to 100% in 0.0001% steps, or attaches a **hook** contract that changes the fee dynamically per swap ([same docs page](https://developers.uniswap.org/docs/get-started/concepts/fees)). In the sources used, v4 is the latest numbered version; whether a successor is announced was not checked and is unverified as of 2026-10. v2, v3 and v4 pools all coexist, and the 0.3% default in this lab is the v2 fee and the typical v3 mid-tier.

### Impermanent loss

An LP holds a 50/50 mix that automatically sells whatever is going up and buys whatever is going down. Take a pool with `k = x*y`, start price `p0`, and let the market price move to `p = r * p0`. Arbitrageurs trade until the pool price equals the market price, giving reserves `x1 = sqrt(k/p)` and `y1 = sqrt(k*p)`. With the start price normalised to 1 (so x0 = y0 = 1 in value terms):

```
LP value  = x1*p + y1 = 2*sqrt(k*p)        -> 2*sqrt(r)
Hold value = x0*p + y0                       -> 1 + r
IL = 2*sqrt(r)/(1 + r) - 1
```

It is zero at `r = 1`, symmetric for `r` and `1/r`, and always negative: r = 2 gives -5.7%, r = 4 (or 0.25) gives -20%, r = 10 gives -42%. The loss is "impermanent" only because it vanishes if the price returns; if the LP leaves at the new price it is real. The intuition: an LP is **short volatility**. They sell the winner and buy the loser along the path, so any large move in either direction leaves them with less than holding. The fees are the premium they collect for selling that option, and the question for every pool is whether `fees > IL` ([Day 7 convexity](day07.md) is the same shape seen from the other side: the LP's payoff is concave).

### Lending protocols

Aave and Compound pool deposits into a market per asset. Anyone can deposit and earn interest; anyone can borrow, but only against **collateral worth more than the loan** (over-collateralised), because there are no identities to chase. Each asset has a loan-to-value limit; a position whose health factor (collateral value times liquidation threshold divided by debt) falls below 1 can be **liquidated**: a third party repays part of the debt and receives the collateral at a discount, the bonus. This is the same CDP mechanism as the stablecoin vaults of [Day 21](day21.md); the difference is that the borrowed asset is a pool deposit rather than a newly minted coin.

Interest rates are set by **utilisation**, `U = borrowed / deposited`. The rate curve is gentle until a kink near 80-90% and then very steep, so scarce liquidity is priced to lure depositors back:

```
borrow rate = base + slope1 * U               (U below kink)
borrow rate = base + slope1*kink + slope2*(U - kink)/(1 - kink)   (above)
supply rate = borrow rate * U * (1 - reserve factor)
```

```
        Aave market (ETH collateral, USDC borrowed)
  Assets (user)           | Liabilities (user)
  aETH collateral +10 ETH | USDC debt  +15,000
  (health factor falls as ETH falls; at < 1 a liquidator repays debt
   and takes collateral plus a bonus)
```

### MEV: front-running, sandwiches and arbitrage

Pending transactions sit in a public mempool before inclusion. **Maximal extractable value (MEV)** is the profit available to whoever orders transactions in a block (Day 20: validators and the builders they use). Three flavours:

- **Arbitrage:** when the pool price drifts from other venues, a bot trades it back. This is the mechanism that keeps AMM prices honest, and it is the source of the LP's impermanent loss.
- **Front-running:** copying a profitable pending transaction with a higher tip so it lands first.
- **Sandwiching:** see below.

A **sandwich** attacks a swap: the bot trades the same direction just before the victim (pushing the price against them), the victim fills at the worse price, and the bot reverses right after, pocketing the difference (in the lab all trades sell X, so the attacker front-runs by selling X). The victim's loss is the pool-price impact the bot added. The defences are **slippage tolerance** (the maximum worse price the victim's transaction accepts before reverting), which bounds how much a bot can push; and **private order flow** (sending the transaction to a builder through a protected endpoint so it never appears in the public mempool). A slippage tolerance of 5% or 50% is a signed invitation to extract up to that amount.

### Where DeFi yield comes from, and what can go wrong

Every yield has a source. Trading fees are paid by traders to LPs. Borrowing interest is paid by borrowers to depositors, ultimately for leverage. **Token emissions** are newly minted governance tokens paid to users: that is dilution paid by holders of the token, not income earned from outside. A displayed 40% APY that is 3% fees and 37% emissions is a marketing budget with an expiry date. Staking yield (Day 20) is a fourth source: issuance plus fees for securing the chain.

Risk sits in layers: **smart-contract bugs** (code is law until it is wrong), **oracle manipulation** (lenders read prices from somewhere; a manipulated price liquidates innocent positions or lets an attacker borrow against inflated collateral), **bridges** (a wrapped asset is only as good as the contract custodying the original; bridge hacks are among the largest losses in crypto), **governance** (a token vote can change risk parameters or drain a treasury), and the **stablecoin layer** beneath nearly everything (Day 21).

As a size marker, [DefiLlama's chain TVL API](https://api.llama.fi/v2/historicalChainTvl) showed total DeFi **total value locked** of about $92 billion on 2026-10-11, versus a peak of about $177 billion on 2021-11-09 (read from the same series). TVL counts deposits at market prices, so it moves with ETH and not only with usage; the order of magnitude is tens of billions of dollars, comparable to a large regional bank's balance sheet.

## Worked example

The lab's no-fee sandwich: a pool of 100 X and 10,000 Y (price 100), a victim selling 10 X, an attacker with 5 X.

```
Baseline (victim alone):      victim receives 909.09 Y

Attack:
 1. Attacker sells 5 X   -> receives 476.19 Y.  Pool: X 105 | Y 9,523.81
 2. Victim sells 10 X    -> receives 828.16 Y.  Pool: X 115 | Y 8,695.65
 3. Attacker sells 476.19 Y -> receives 5.9707 X. Pool: X 109.03 | Y 9,171.84
 Attacker profit: 5.9707 - 5 = +0.9707 X (about 97 Y at the starting price)
 Victim shortfall: 909.09 - 828.16 = 80.93 Y (8.9% worse)
```

Value moved from the victim to the attacker through the pool's curve. With a 0.3% fee the same trade gives the attacker +0.935 X and the victim 826.01 Y instead of 906.61: the fee trims but does not stop it. Shrink the victim to 0.01 X and the attacker's two 0.3% fees on a 5 X round trip (about 0.03 X in total) exceed the tiny price move, so the profit is negative, -0.028 X: bots ignore small swaps.

The IL numbers on real data: from the first ETH/USDT close of 2021-01-01 (about 729) to 2026-09-30 (about 2,686), the ratio is 3.68. `impermanent_loss(3.68)` is -18.1%: a fee-free LP ends with 279,847 USDT of value versus 341,492 for holding. Spread over 5.7 years that is about 3.1% of position value per year the pool's fees would need to pay just to break even. The ETH/USDT data come from the Binance snapshot, and fees are not in the data, so the lab cannot say whether a given pool did that.

## Exercises

1. Pool: 200 ETH and 400,000 USDT, fee 0.3%. What is the marginal price, the average price for selling 20 ETH, and the price impact?
   **Hint:** `eff = 20 * 0.997`; `dy = y*eff/(x+eff)`; compare `dy/20` with y/x.
   **Solution sketch:** marginal price 2,000; eff = 19.94; dy = 400,000 * 19.94 / 219.94 = 36,264.43; average 1,813.2, about 9.3% below marginal (about 0.3% fee plus about 9.0% impact).

2. An LP deposits at ETH = 2,000. ETH goes to 4,000 and fees earned equal 3% of the initial deposit. Is the LP ahead of holding? What about if ETH falls to 500?
   **Hint:** IL for r = 2 is -5.7%; for r = 0.25 it is -20%.
   **Solution sketch:** at r = 2 the loss is 5.7%, so 3% of fees leaves the LP 2.7% behind holding. At r = 0.25 the loss is 20%, so the LP is 17% behind. Fees would need to be several times larger to offset a halving or quartering.

3. A market has deposits of 100M USDC and loans of 90M. What is utilisation, and why would a lender protocol raise the borrow rate steeply here?
   **Hint:** U = borrowed / deposited; think about withdrawals.
   **Solution sketch:** U = 90%. Only 10M is liquid, so a rush of withdrawals could fail; the steep slope above the kink raises borrowing cost and the supply rate, to pull in deposits and push repayments.

4. A user deposits 10 ETH at 3,000 USDC and borrows 15,000 USDC. The liquidation threshold is 80%. At what ETH price does the health factor reach 1?
   **Hint:** health = collateral value * 0.8 / debt.
   **Solution sketch:** collateral 30,000 * 0.8 / 15,000 = 1.6 now. Health is 1 when 10 * P * 0.8 = 15,000, so P = 1,875, a 37.5% fall. This is an inverse form of Day 21's minimum-ratio test (liquidation threshold 0.8 corresponds to a collateral/debt ratio of 1.25, vs Day 21's 1.5 minimum).

5. A pool of 100 X / 10,000 Y has a fee of 0.3%. A victim sells 10 X with slippage tolerance 1%. Can the attacker in the worked example still sandwich with 5 X?
   **Hint:** the victim's transaction reverts if the received Y is below 99% of the quote at submission.
   **Solution sketch:** the quote is 906.61, so the floor is about 897.54. The 5 X attack leaves the victim 826 Y, below the floor, so the swap reverts instead of filling. An attacker front-running 1 X still leaves the victim 889.6 Y (reverts), but 0.5 X leaves 898.03 Y (fills) for a profit of only about 0.10 X; tight slippage caps extraction at small amounts.

6. A farm advertises 60% APY on a pool. Describe the questions you would ask before depositing.
   **Hint:** split yield into fee, borrow and emission sources, and ask about impermanent loss and exit liquidity.
   **Solution sketch:** what share of the 60% is trading fees versus a token emission; what is that token's price trend and unlock schedule; what is the pool's expected IL for the asset pair's volatility; how deep is exit liquidity; has the contract been audited and who holds the admin keys.

## Anti-patterns / Common mistakes

- **APY screenshots without a source of yield.** A number with no decomposition into fees, interest and emissions is not a return; emissions are dilution.
- **Ignoring impermanent loss.** Comparing the LP's token count or fee income to deposited dollars hides the comparison that matters: LP value versus holding.
- **Maximum slippage tolerance.** Setting 50% or "auto" on a thin pool lets a sandwich bot take most of the price impact; use a tight tolerance or private order flow.
- **Treating TVL as safety or usage.** TVL is deposits at market price; it rises with the token price and fell by half after the 2021 peak.
- **Confusing the lab's fee-free model with a real LP.** Real LPs collect fees and pay gas to deposit and withdraw.

## Lab

Open [`labs/day22/README.md`](../labs/day22/README.md). Implement the pool, `impermanent_loss`, `lp_vs_hold` and `sandwich` in `lab.py` and run `uv run pytest day22`. `main()` opens an LP at the first price of the ETH/USDT snapshot (2021-01-01 onward), tracks LP versus hold value, prints the final IL and the break-even fee APR, runs a sandwich on a 50 ETH swap, and saves `.cache/plots/day22.png`.

## Teardown

Nothing billable is created. The lab only reads frozen snapshots; no wallet, no key, no real-money transaction.

## Journal prompt

Pick one DeFi yield you have seen advertised. Write down the three sources it could be coming from, estimate the share of each, and say what price move of the underlying asset would turn it negative after impermanent loss.
