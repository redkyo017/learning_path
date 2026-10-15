# Day 27 — Costs and risk: slippage, sizing, Kelly

> Block 5: Quant trading. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

A gross backtest is fiction. Every trade pays someone: the broker, the exchange, the market maker whose spread you cross, and the tax authority. A rule that earns 8 basis points (bps, hundredths of a percent) per trade before costs and pays 10 is a donation. Costs are the one part of the backtest you can estimate with confidence, so they are the first filter, applied before any clever statistics.

The second half of the day is about staying in the game. Sizing decides whether a real edge survives its own bad stretch. A 50% loss needs a 100% gain to recover; at 10x leverage a 10% fall ends the account. This is Strategy move 5, "survive before you profit", and Day 29's bot will ship with a kill switch before it ships with a strategy. Both halves use the Day 25 `backtest` and feed Day 30's capstone through `common/risk.py`.

## Core concepts

### The cost stack

Everything between the gross signal and the money you keep:

| Layer | What it is | Where it comes from |
|---|---|---|
| Commission | Broker fee per share, per order, or percent of value | Broker schedule |
| Spread | Half the bid-ask gap paid on each market order | Order book, Day 9 |
| Slippage / impact | Price moving against you while you trade; grows with size relative to depth | Day 9: walking the book |
| Borrow | Fee to short a stock | Prime broker |
| Funding | Perp funding rate paid or received every 8 hours when long or short the perpetual | Day 23 |
| FX | Conversion between VND and USD, both ways, plus any hedge cost | Day 17 |
| Taxes | On sale proceeds or gains, by jurisdiction | Local law |

Spread is the cost people forget. Crossing a 2 bps spread costs 1 bp in and 1 bp out. Impact is the cost people underestimate: the Day 9 matching engine shows that a market order larger than the top of the book fills at worse and worse prices. For the long-only daily strategies in this course, a flat "bps per unit of turnover" is a fair first model; it lumps commission, spread and impact into one number.

Funding deserves a sentence of its own. A strategy long BTC through a perpetual swap pays funding when the market is long-heavy (Day 23), a cost that accrues per bar rather than per trade. It never shows up in turnover-based cost models, so it has to be added separately.

### Turnover and the breakeven test

Turnover is the sum of absolute position changes. Entering from cash is 1 unit, flipping from long to short is 2. Total cost is `turnover x cost per unit`. The **breakeven cost** is the cost per unit that makes the total gross return zero:

```
breakeven_bps = sum(gross returns) / sum(turnover) * 10,000
```

This is a first-order filter (it ignores compounding), and it is the first test a strategy must pass: compare it with a realistic cost. If breakeven is 8 bps and honest costs are 10 to 30 bps, stop there. If it is 170 bps, costs are not the binding problem and risk is.

A high Sharpe ratio on a high-turnover rule is a warning, not a result: Sharpe is computed on whatever returns you feed it, so feed it net returns (anti-pattern 1 below).

### Typical costs, as of 2026-10

Treat these as orders of magnitude to plug into the cost ladder, not as recommendations. Rate cards change and depend on volume, account and channel; check the broker before relying on them.

- **IBKR Pro, US equities, Tiered plan:** USD 0.0035 per share up to 300,000 shares a month, USD 0.35 minimum per order, plus exchange, clearing and regulatory pass-through fees; the Fixed plan is USD 0.005 per share with a USD 1.00 minimum. These figures come from [IBKR's commissions page](https://www.interactivebrokers.com/en/pricing/commissions-stocks.php) as summarised by 2026 reviews such as [BrokerChooser](https://brokerchooser.com/broker-reviews/interactive-brokers-review/interactive-brokers-fees); the official page blocked an automated fetch, so confirm the numbers on it directly. For a 100-share order in SPY (last snapshot close about USD 764, so about USD 76,400 of value) the USD 0.35 minimum is about 0.05 bps; with pass-through fees and the spread, commission is well under 1 bp of the cost.
- **Vietnamese brokers, listed equities:** a [2026-08 comparison article on topi.vn](https://topi.vn/phi-giao-dich-chung-khoan.html) lists online commissions of roughly 0.1% to 0.25% of trade value (for example TCBS 0.1%, VNDS and MAS 0.15%, VPS and HSC 0.2%, SSI 0.25%), i.e. 10 to 25 bps per side, 20 to 50 bps for a round trip. This is a secondary source; broker rates vary by channel, trade size and promotion. A separate stock-exchange fee exists but no confirmed current figure was found in the sources used (unverified as of 2026-10). The same article states a 0.1% personal income tax on the sale value, charged to the seller only: another 10 bps on every round trip, so 30 to 60 bps all-in (about 40 bps at a mid-priced broker, as in Exercise 1).
- **Spot crypto taker fees:** [Binance's fee schedule](https://www.binance.com/en/fee/schedule) lists 0.100% maker and 0.100% taker for a regular user, 0.075% when paying with BNB. Coinbase Advanced's entry tier is reported at 0.60% taker and 0.40% maker, falling with 30-day volume (see the [Coinbase fee comparison](https://www.bitget.com/amp/academy/12560603879597), a third-party summary, so check its own page).

The pattern: a round trip costs 30 to 60 bps at a Vietnamese broker including the sale tax (about 40 bps at a mid-priced one), about 20 bps on Binance spot (0.1% each way), and well under 1 bp of commission on a US equity ETF at IBKR before spread. A rule that trades weekly can live with that; a rule that trades daily cannot.

### Position sizing

Sizing turns a signal into a position. Three common rules:

1. **Fixed fractional.** Risk a fixed fraction of equity per position (for example 1% of capital lost if the stop is hit). Simple, scales down after losses and up after gains, needs a defined stop distance.
2. **Volatility targeting.** Scale exposure so the portfolio's volatility stays near a target: `weight = target_vol / recent_vol`, capped by a maximum leverage. High volatility means smaller positions. This is what `vol_target_weights` does, with the weight lagged one bar so it only uses past returns. It does not create edge; it keeps the ride roughly constant, which is why it often cuts drawdowns.
3. **Kelly.** The leverage that maximizes long-run growth of capital. For a continuous return stream with annualized excess return `mu` and volatility `sigma`, `f* = mu / sigma^2`. With mu = 8% and sigma = 20% that is 0.08 / 0.04 = 2.0, meaning 200% invested.

### Why full Kelly is reckless

Kelly assumes you know `mu` and `sigma`. You do not: you estimate them from a finite sample, and `mu` is estimated badly (its standard error over 20 years of daily data is large compared with the number itself). Because `f*` is proportional to `mu`, an overestimated `mu` means over-leverage, and growth falls on the far side of the peak faster than it rises on the near side. Over-betting past roughly twice Kelly gives negative expected growth; betting more than Kelly always gives a worse long-run result than betting Kelly and a rougher ride. Full Kelly also implies drawdowns of 50% or more are routine, even when the inputs are right.

Practitioners use fractional Kelly (half or a quarter), accepting a small growth loss for much less variance and for protection against an overestimated edge. `fractional_kelly` makes this one multiplication. `main()` prints the full, half and quarter Kelly on SPY's historical numbers; the full figure is far above anything a sane account would run.

### Risk of ruin and leverage

Risk of ruin is the probability of hitting a loss you cannot recover from or tolerate. It grows quickly with bet size: risking 10% of capital on each of a series of fair coin flips, a run of seven losses (a loss of about 52% of capital) has roughly even odds within about 200 flips and is near-certain within about 1,000. Leverage multiplies both returns and volatility but also converts a drawdown into a margin call: a 3x position in an asset that falls 33% is gone, even if the asset later recovers. Ruin is absorbing; once there you cannot average out.

### Drawdown control

A **drawdown** is the fall from the running peak: `equity / equity.cummax() - 1`. The arithmetic is asymmetric: a loss of d needs a gain of d/(1-d) to recover (10% needs 11.1%, 20% needs 25%, 50% needs 100%).

A **drawdown brake** cuts exposure once the drawdown passes a threshold and restores it on recovery. `drawdown_brake` returns a scale series, lagged one bar so a bar's loss cannot change its own position. A brake is a blunt tool: it limits depth but sells low and re-risks late, so it often reduces the maximum drawdown only modestly while giving up return. Its main value is behavioral and operational: a rule written before the loss.

Psychology matters because the strategy is run by a person. Most people abandon a plan in the middle of a deep drawdown, locking in the loss. The test of a sizing rule is the drawdown you will actually hold through, not the one the backtest shows. Choose the volatility target so the historical worst drawdown is one you pre-committed to survive.

### Portfolio-level risk limits (what Day 29's bot will enforce)

- Max position size per asset, as a share of equity.
- Max gross leverage across the portfolio.
- Max daily loss: halt trading for the day if breached.
- Max drawdown from peak: flatten and stop (the kill switch).
- Max order size relative to recent volume (impact guard).
- Order-rate limit and a stale-data check (no trading on old prices).

These are checks in code, run before every order, not guidelines.

## Worked example

Rule: buy SPY at the close after any down day, hold one day (long/flat), on the snapshot 2005-01-03 to 2026-09-29. Run `uv run python -m day27.solution` and read section (e):

```
reversal at 0 bps    CAGR   9.49%  vol 14.38%  Sharpe  0.70  maxDD -21.35%
reversal at 5 bps    CAGR   2.77%  vol 14.39%  Sharpe  0.26  maxDD -30.77%
reversal at 20 bps   CAGR -15.04%  vol 14.50%  Sharpe -1.05  maxDD -97.11%
breakeven 8.0 bps; 2755 units of turnover
```

Gross, it looks fine: a CAGR somewhat below buy-and-hold (9.5% against 10.9%, the first row of section (a)) with a far shallower drawdown (-21% against -55%). The catch is turnover: 2,755 units over 21 years, about 130 a year. At 5 bps most of the edge is gone; at 20 bps (a realistic all-in figure for retail trading) it loses 15% a year and nearly all the capital. The breakeven of 8 bps said so before any chart was drawn.

Contrast with the Day 25 rule, 200-day momentum, from section (a) and (b):

```
0 bps   CAGR 7.56%  Sharpe 0.64  maxDD -33.64%
20 bps  CAGR 6.54%  Sharpe 0.57  maxDD -36.97%
50 bps  CAGR 5.02%  Sharpe 0.45  maxDD -41.74%
breakeven 171 bps; 103 units of turnover
```

Same data, same cost ladder, opposite verdict. Slow rules survive costs; fast rules need execution quality that a retail account does not have.

Sizing at 5 bps (section c/d): plain momentum has max drawdown -34.5%; targeting 10% volatility with a 1.5x cap cuts it to -17.4% with CAGR 6.5% and Sharpe 0.68; the drawdown brake (20% threshold, half size) only reaches -29.9%. Section (f) prints the Kelly values: full 3.40x, half 1.70x, quarter 0.85x on SPY's historical mean and volatility (risk-free rate not subtracted).

A T-account for one round trip shows where the money goes (a Vietnamese stock bought and sold at the same price, VND 100,000,000 notional, 0.15% commission each way and the 0.1% seller tax, so 40 bps in total):

```
        Your brokerage account (VND)
  Assets                      | Liabilities & equity
  Buy:  Stock  +100,000,000   | Equity (commission)       -150,000
        Cash   -100,150,000   |
  Sell: Cash    +99,750,000   | Equity (commission + tax) -250,000
        Stock  -100,000,000   |
```

## Exercises

1. A strategy earns 12 bps gross per round trip (turnover 2 per round trip). What is its breakeven cost per unit of turnover, and does it survive a Vietnamese broker's 15 bps commission per side plus 10 bps sale tax?
   **Hint:** breakeven is gross divided by turnover; add all the costs of one round trip.
   **Solution sketch:** breakeven is 12 / 2 = 6 bps per unit of turnover. Round-trip cost is 15 + 15 + 10 = 40 bps against a 12 bps gross return, so it loses 28 bps per round trip. It does not survive. (Arithmetic done by hand; not printed by `main()`.)

2. With mu = 6% and sigma = 15%, compute full Kelly and half Kelly. If the true mu is 3%, what leverage would the true Kelly give, and what does that say about full-Kelly sizing?
   **Hint:** use `mu / sigma^2`.
   **Solution sketch:** full Kelly is 0.06 / 0.0225 = 2.67x, half is 1.33x. With true mu = 3%, Kelly is 1.33x, so full Kelly on the optimistic estimate is twice the true optimum, in the over-betting region where growth falls fast. Half Kelly on the optimistic estimate lands on the true optimum. (Hand arithmetic; `kelly_fraction` reproduces it.)

3. Run `vol_target_weights` on SPY returns with target 10% and cap 1.5, then 1.0. How often does the cap bind, and what happens to the volatility?
   **Hint:** compare `w` with the cap and compute `annualize_vol` of `w * asset_ret`.
   **Solution sketch:** SPY's volatility is usually above 10%, so the weight is mostly below 1; with target 10% the cap binds only when realized volatility is below target/cap, about 6.7% for cap 1.5 (below 10% for cap 1.0), which happens only in the calmest stretches. A lower cap leaves volatility below target in those periods. The point is that the cap, not the target, sets the worst-case leverage.

4. A 3x leveraged position has an asset fall 20% then rise 20% (a 4% net fall). What happens to the equity, and what rebalancing issue does it show?
   **Hint:** apply 3x to each return, multiplying in sequence.
   **Solution sketch:** day one is -60%, day two is +60% on the remaining 40%, so equity ends at 0.4 x 1.6 = 0.64, a 36% loss while the asset lost 4%. Leverage compounds the path, not just the endpoints, so volatility drag grows with the square of leverage. (Hand arithmetic.)

5. Sweep the `drawdown_brake` threshold over 10%, 15%, 20% and 25% on the 5 bps momentum equity. Is the maximum drawdown monotone in the threshold, and what does that say about the brake?
   **Hint:** loop over thresholds and compute `max_drawdown` of the braked returns.
   **Solution sketch:** deeper thresholds act later, so maximum drawdown is usually worse, but the pattern is not guaranteed monotone because the brake can fire just before a rebound. Do not pick the best threshold: choose one in advance by the loss you would hold through (Day 26).

6. Add a daily funding cost of 0.01% for a long BTC perpetual position and recompute breakeven for a rule that is long half the time. Why does turnover-based breakeven miss it?
   **Hint:** funding accrues per held bar, not per trade.
   **Solution sketch:** the cost is 0.01% x days held, about 3.65% a year if held all year (hand arithmetic), so a rule long half the time pays about 1.8% a year (0.01% x 365 x 0.5); it scales with time in market, so it should be subtracted from the gross return as a holding cost before computing the breakeven. A turnover-only measure treats a position held for a year the same as one held a day.

## Anti-patterns / Common mistakes

- **Sharpe without costs.** A gross Sharpe on a high-turnover rule measures the market's mood, not what you would keep. Report net Sharpe at a cost level you can defend, and the breakeven next to it.
- **Full Kelly.** Treating an estimated `mu` as known and betting the formula. Use fractional Kelly or volatility targeting with a hard cap.
- **Martingale averaging down.** Doubling after each loss to "get back to even" has a high win rate and an unbounded loss; it ends at the margin limit or the account balance. Size by risk, not by the need to recover.
- **Costs as a constant.** Costs rise in stress (spreads widen, impact grows), exactly when the drawdown brake and stops fire.
- **Ignoring taxes and FX.** Sale tax, conversion spreads (Day 17) and withholding all sit between the strategy and your VND balance.
- **Lookahead in the sizing.** A volatility weight that includes today's return, or a brake that sees today's drawdown, flatters the result. Lag both.

## Lab

Open [`labs/day27/README.md`](../labs/day27/README.md). Implement `kelly_fraction`, `fractional_kelly`, `vol_target_weights`, `breakeven_cost_bps` and `drawdown_brake` in `lab.py` and run `uv run pytest day27`. `main()` runs 200-day momentum on SPY at 0, 5, 20 and 50 bps, prints the breakeven, compares vol targeting and the brake, shows the one-day reversal worked example and the Kelly values, and saves `.cache/plots/day27.png`. The two shared functions live in `labs/common/risk.py` (`uv run pytest common/tests/test_risk.py`).

## Teardown

Nothing billable is created. The lab only reads frozen snapshots; no broker, no key, no order.

## Journal prompt

Write down the largest drawdown you would hold through without touching the plan, as a percent of your portfolio, and the volatility target that would keep the backtest's worst case inside it. Date it, and re-read it the first time a position is down by half that amount.
