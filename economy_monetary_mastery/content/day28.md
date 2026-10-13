# Day 28 — Strategy families: trend, carry, risk parity

> Block 5: Quant trading. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Days 25 to 27 gave you a backtester, a list of ways it lies, and a cost model. What is still missing is the question that comes first in real life: *what should I even test?* Almost every systematic strategy sold or published belongs to a handful of families, and each family is a bet on someone else being forced, scared or slow. If you can say who is on the other side of the trade and why they accept a bad price, you have an economic reason to expect the edge to persist. If you cannot, you have a pattern in a chart, and Day 26 told you what those are worth.

For a software engineer the useful mental model is a small library of well-understood components. Each family has an input (prices, rates, funding), a failure mode, and a capacity limit, much as each data structure has complexity bounds. Today you build five of those components, wire two sleeves into a portfolio, and measure how much a blend actually helps. It is the last building block before Day 29 (paper trading) and Day 30 (the integration project).

## Core concepts

### The test for every family: who pays you, and why?

A return is a transfer. Somebody has to lose it or knowingly give it up. For each family below, ask three things: the **payer** (who is on the other side), the **failure regime** (when the payer stops paying or the trade gets crowded), and the **capacity** (how much money can run before the edge disappears).

### Trend / time-series momentum

Go long an asset whose trailing return is positive, short or flat when negative, decided asset by asset against its own history. The lab's `trend_signal` is the sign of the trailing return.

- **Payer:** investors who adjust slowly (anchoring, gradual repricing of news) and hedgers or policy-driven buyers who trade for reasons other than profit. Trends also come from feedback: price moves attract flows that push price further.
- **Failure regime:** sharp reversals and choppy, range-bound markets. The rule is late at turning points and pays for that lateness in whipsaws. Expect long flat or negative stretches.
- **Capacity:** high in liquid futures and large ETFs; lower in small stocks and coins.
- **Source:** [Moskowitz, Ooi and Pedersen (2012), "Time series momentum"](https://doi.org/10.1016/j.jfineco.2011.11.003), *Journal of Financial Economics* 104(2), 228-250, document it across dozens of futures markets (bibliographic details checked against Crossref as of 2026-10).

### Cross-sectional momentum

Rank a universe by trailing return and hold the winners (and, in the academic version, short the losers). The lab's `cross_sectional_momentum` holds the top N with weight 1/N each.

- **Payer:** the same slow adjustment, plus investors who sell winners too early or hold losers too long (the disposition effect).
- **Failure regime:** "momentum crashes" when a beaten-down market rebounds violently and the previous losers lead; also any day the winners are crowded.
- **Capacity:** moderate. It turns over a lot, so costs (Day 27) bite.
- **Source:** [Jegadeesh and Titman (1993)](https://doi.org/10.1111/j.1540-6261.1993.tb04702.x), "Returns to Buying Winners and Selling Losers", *Journal of Finance* 48(1), 65-91.

### Mean reversion

Fade extremes: sell when price is far above its recent average, buy when far below (`mean_reversion_signal`, a z-score rule).

- **Payer:** you are paid for supplying liquidity to impatient sellers and buyers, the same role as a market maker (Day 9).
- **Failure regime:** a regime change that is not noise. A stock that is down 20% because of fraud does not revert; you bought into a trend. Losses are large and sudden, gains small and frequent, so leverage turns a modest win rate into ruin.
- **Capacity:** low to moderate, and it needs cheap, fast execution.
- **Vietnam:** daily price limits (HOSE +-7%, Day 16) cut the rule in two ways. A move beyond the band is spread over days, so the z-score never reaches a clean entry, and a stock stuck at the floor cannot be bought or sold at the printed close. Settlement at T+2 and foreign ownership limits (FOL) make short holding periods and short selling harder still. Closes in the snapshot are adjusted, so limit-hit detection is approximate (Day 16).

### Carry

Hold the asset that pays you to hold it and fund it with the one that costs you. Carry is return you earn if prices do not move.

- **FX carry (Day 13):** borrow the low-rate currency, hold the high-rate one. Covered interest parity says the forward price removes this gain; carry is the *uncovered* version, where you skip the hedge and accept the exchange-rate risk. **Payer:** commonly attributed to hedgers and central banks who pay a premium for currency safety or stability (see Koijen et al. below). **Failure regime:** the "stairs up, elevator down" crash, when funding currencies spike during a risk-off episode and high-yielders collapse together; Day 13's example is the August 2024 yen carry unwind.
- **Crypto funding carry (Day 23):** hold spot and short the perpetual future when funding is positive, collecting the payment from leveraged longs. **Payer:** leveraged speculators who pay a premium to be long. **Failure regime:** funding turns negative or the exchange fails; the position needs margin that can be liquidated in a spike, and the cash sits on a venue (counterparty risk, Day 23).
- **Capacity:** large in major FX; limited in crypto by the size of the leverage appetite.
- **Source:** [Koijen, Moskowitz, Pedersen and Vrugt (2018), "Carry"](https://doi.org/10.1016/j.jfineco.2017.11.002), *Journal of Financial Economics* 127(2), 197-225, define carry as the return with unchanged prices and compute it across asset classes.

### Value

Buy what is cheap against a fundamental anchor (earnings, book value, long-run average real exchange rate) and short what is expensive.

- **Payer:** investors who extrapolate recent growth and overpay for stories, and those forced to sell cheap assets. Value is slow money's compensation for tolerating long underperformance.
- **Failure regime:** years of underperformance when growth stocks keep winning; cheap can stay cheap or be cheap for a reason.
- **Capacity:** high, because turnover is low.
- **Source:** [Asness, Moskowitz and Pedersen (2013), "Value and Momentum Everywhere"](https://doi.org/10.1111/jofi.12021), *Journal of Finance* 68(3), 929-985, find both premia in several asset classes and a negative correlation between them, which is why they are paired. Value is not coded in this lab because it needs fundamentals data the snapshot lacks.

### Risk parity / inverse volatility

Not a source of return but a sizing rule: weight each asset by 1/volatility so each contributes comparable risk, instead of by capital. The lab's `inverse_vol_weights` is the simple version (it ignores correlations).

- **Payer:** nobody in particular. It rests on the observation that low-volatility assets such as bonds have often earned compensation per unit of risk, while equity-heavy portfolios get nearly all their risk from stocks.
- **Failure regime:** a joint selloff of stocks and bonds (2022, when Day 10's 60/40 SPY/IEF mix fell 16.4%), because leveraged versions also lose on the bond side. Unlevered inverse-vol, as here, just holds more of whatever was quiet.
- **Capacity:** very high.

### Diversifying across strategies versus across assets

Ten correlated assets are still one bet. Different *strategies* on the same assets can have returns that are far less correlated: historically, trend has tended to do well in extended crises where value and carry suffer, and the reverse in calm markets (Moskowitz, Ooi and Pedersen 2012; Asness, Moskowitz and Pedersen 2013 report the negative value-momentum correlation). What matters is the correlation of the **return streams**, not the stories. Measure it before blending (`combine_strategies` takes the streams); the anti-pattern is blending on narrative. In expectation, a blend of two sleeves with similar Sharpe and correlation below 1 has a higher Sharpe than either alone, and a smaller drawdown because their bad periods only partly overlap.

### Simple beats clever, and the role of rebalancing and costs

With one history and few independent crises, every parameter you add is a dial for overfitting (Day 26). A trend rule with one lookback, an inverse-vol weight with one window and a top-N rank have roughly three dials in total. Complexity costs you twice: it is harder to verify, and it trades more. Turnover is the link to Day 27: a rule that flips daily on noise pays the spread each time, while monthly rebalancing cuts cost but reacts late. The right frequency is the one where the signal's decay time is longer than the rebalancing interval, and where cost per trade is small against the edge per trade.

### Which families suit a learner with US, VN and crypto access

- **US ETFs:** trend, cross-sectional momentum and inverse-vol sizing across liquid ETFs are practical and cheap. Capacity is irrelevant at personal size, but lot size and fees are not.
- **Vietnam:** trend on the index or large caps is feasible; mean reversion is hampered by price limits, T+2 and FOL (above). Resident individuals' access to foreign securities is restricted under Decree 135/2015, which Day 16 treats as the operative framework; practical rules for individuals are unverified as of 2026-10, so check with a licensed adviser. This may rule out the US ETF half of this lab for some readers, in which case the VN and crypto sleeves are the available ones.
- **Crypto:** trend works on a 24/7 market; funding carry is available but carries exchange and liquidation risk. Crypto annualises with 365, not 252.

## Worked example

The lab builds a universe of SPY, EFA, EEM, TLT, IEF, GLD and BTC-USD. The ETFs trade about 252 days a year and BTC trades every day, so `main()` keeps only the weekday dates on which every asset has a price (an inner join), and annualises with 252 on that common calendar. A BTC Friday-to-Monday return then spans three days. This keeps one clock for the whole portfolio; for a pure BTC series you would use 365.

Two sleeves are run, each through `common.backtest` per asset with the weight as the signal (so the one-bar lag applies) and 5 bps cost per unit of turnover, an assumption for the lab:

- **Trend:** the sign of the 120-day return times the 60-day inverse-vol weight. It can be short.
- **Cross-sectional momentum:** top 3 by 120-day return, 1/3 each.

Then the 50/50 blend (`combine_strategies`) and equal-weight buy-and-hold. Output of `uv run python -m day28.solution` (2014-12 to 2026-09):

```text
  trend                  CAGR   4.49%  Sharpe  0.61  MaxDD -13.98%
  csmom                  CAGR  24.27%  Sharpe  1.14  MaxDD -40.51%
  blend                  CAGR  14.50%  Sharpe  1.15  MaxDD -21.60%
  buy&hold EW            CAGR  16.30%  Sharpe  1.15  MaxDD -32.43%

correlation trend vs csmom daily returns: 0.36
correlation blend vs buy&hold: 0.62
```

Reading it honestly:

- The reported window starts when the 60-day inverse-vol weights exist, but the 120-day trend and momentum signals are still warming up, so both sleeves sit in cash for roughly the first 60 rows while buy-and-hold is invested. That slightly flatters their drawdowns and lowers their CAGR.
- The blend matches buy-and-hold's Sharpe with about a third less drawdown, which is the diversification benefit, but it earned a lower CAGR than either buy-and-hold or momentum alone. A blend is a way to lower regret, not to guarantee a higher return.
- The trend sleeve looks weak because inverse-vol weights sum to at most 1 and it was often short or flat: it is low-risk, not poor. Rescaling it to a target volatility (Day 27) would make the comparison fair.
- The momentum sleeve's edge is flattered. Seven hand-picked survivors, one of which is BTC, is exactly the survivorship and selection bias of Day 26, and all of it is in-sample. Treat these as a demonstration of the code, not as a forecast.
- The trend/momentum correlation of 0.36 is meaningful but well below 1; it is the number that justifies blending, and the only way to know it is to measure it.

## Exercises

1. Write the weights `inverse_vol_weights` returns for two assets with daily volatility 2% and 1%. **Hint:** invert, then normalise. **Solution sketch:** 1/0.02 = 50 and 1/0.01 = 100, total 150, so the weights are 1/3 and 2/3; the calmer asset gets double the capital and both contribute equal risk (1/3 x 2% = 2/3 x 1%).
2. A mean-reversion rule with a 20-day window fades z beyond 2. Prices were 10.0 for 19 days, then 12.0. Compute the sign and explain why it is a short. **Hint:** compute mean and std with ddof=1 first. **Solution sketch:** the mean is 10.1 and the std about 0.447, so z is about 4.2, above 2, so the signal is -1 (sell, expecting reversion). The same code at 8.0 gives +1.
3. Show with `cross_sectional_momentum` on three assets that tie-breaking by column order matters. **Hint:** feed identical price columns and print the result for `top_n=1`. **Solution sketch:** with identical columns every rank is a tie, `method="first"` gives rank 1 to the earliest column, so weights are [1, 0, 0]; a tie-break that looked at the values would be arbitrary and make results change when columns are reordered.
4. Run trend with lookbacks 60, 120 and 250 in `main()` and record the blend's Sharpe for each. Which one would you report, and what does Day 26 say about reporting the best? **Hint:** count how many variants you tried. **Solution sketch:** report all three or pre-register one before looking; picking the best of three on the same history carries a selection penalty, and the honest check is a walk-forward test or a deflated Sharpe with the number of trials.
5. Explain in two or three sentences why FX carry and crypto funding carry are the same trade in different markets. **Hint:** identify the payer, the position and the tail risk in each. **Solution sketch:** the FX carry trade holds the higher-yielding currency, whose forward trades at a discount under interest parity, so the unhedged position keeps the interest gap if spot does not move; the funding trade holds spot against a short perp that trades at a premium, and collects it (Day 23). The payer is the leveraged or hedging party, and the tail risk is a sudden unwind.
6. A learner in Vietnam wants a mean-reversion strategy on HOSE stocks held for one day. Give three reasons it is harder than in the US. **Hint:** think of Day 16 and Day 9. **Solution sketch:** daily price limits (+-7% on HOSE) truncate moves so extremes persist over several days and a locked stock cannot be traded; T+2 settlement means shares bought are not available to sell immediately; FOL and liquidity limits can block foreign buyers and make the spread wider than the backtest assumes.
7. Two sleeves each have Sharpe 0.8. Describe what the blend's Sharpe does as their correlation goes from 1 to 0 to -1, and which `main()` print line tells you the real value. **Hint:** a portfolio's variance falls as correlation falls. **Solution sketch:** at correlation 1 the blend equals either sleeve (Sharpe 0.8); lower correlation cuts blend volatility at the same mean, so Sharpe rises, up to about 1.13 at 0 (0.8 x sqrt(2)) and without limit as correlation approaches -1. The line "correlation trend vs csmom daily returns" gives the measured value.

## Anti-patterns / Common mistakes

- **Mixing families without measuring correlation.** Two strategies that both buy rising BTC are one strategy. Compute `returns.corr()` on the sleeves before assigning weights.
- **Mean reversion with leverage.** The payoff profile is many small wins and rare large losses. Leverage plus a regime change ends the account. Cap size and use a stop that is not the signal.
- **Ignoring capacity.** A strategy that worked at small size on a thin coin or small-cap stock may be your own price impact at larger size. Check turnover against average volume (Day 27).
- **Counting a universe chosen with hindsight.** The seven tickers in the lab are known survivors. Ranking them tells you about survivors.
- **Annualising a mixed calendar with one number.** ETFs 252, crypto 365. Decide the portfolio clock first, and use 365 for stand-alone crypto series.
- **Treating value, carry or trend as a law.** Each is a risk premium with a drawdown regime. If you cannot sit through the failure regime, you will not collect the premium.

## Lab

`labs/day28/`. Implement `trend_signal`, `mean_reversion_signal`, `inverse_vol_weights`, `cross_sectional_momentum` and `combine_strategies`, then run `uv run python -m day28.lab` to build the two sleeves and the blend on the mixed universe. Details in `labs/day28/README.md`.

## Teardown

Nothing billable is created.

## Journal prompt

For each of trend, carry, mean reversion and value, write one sentence naming the payer and one naming the regime in which you would stop trusting it. Which of the four could you hold through a three-year drought, and which would you abandon?
