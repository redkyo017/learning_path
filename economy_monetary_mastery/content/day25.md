# Day 25 — Research workflow and backtest anatomy

> Block 5: Quant trading. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Block 5 asks one question in five forms: does a trading rule make money after you account for luck, costs and risk, and would you know if it did not? A backtest is a program that replays history through a rule. It is easy to write and easy to fool yourself with, which is why this day builds one in about fifteen lines and spends most of the words on the process around it.

For a software engineer the pull is to build a platform: event bus, order manager, plugin system. That is the wrong first project. Edges in liquid markets are small and mostly competed away (Day 9: someone is on the other side of every trade), so the scarce resource is a defensible hypothesis, not infrastructure. The course uses pandas for the vectorized core and optionally [vectorbt](https://vectorbt.dev/) as a cross-check, and keeps the whole thing under a page of code. Day 26 shows how backtests lie, Day 27 adds costs and sizing, Day 28 surveys strategy families, and Day 30 turns one idea into a paper deployment; all of them import the function you write today.

## Core concepts

### The research workflow

```
hypothesis -> data -> signal -> position -> P&L -> evaluation -> kill or keep
```

1. **Hypothesis, written first.** One paragraph: why should this work, who is on the other side of the trade and why are they willing to lose, what would falsify it. For momentum: investors under-react to news, so trends persist; and trend followers are paid for taking the other side of the urgency of hedgers and forced sellers. Writing it before looking at results is the only protection against inventing the story after the chart.
2. **Data.** Prices adjusted for splits and dividends, survivorship considered (Day 26).
3. **Signal.** A number computed from information available at the close of bar t.
4. **Position.** What you hold during bar t+1, derived from the signal.
5. **P&L.** Position times return, minus costs.
6. **Evaluation.** Metrics against a benchmark, on data not used to design the rule.
7. **Kill or keep.** Set the kill criterion in advance. Most ideas die here, and that is the process working.

### Signals, positions, weights

A **signal** is a forecast or a rank (for example "trailing return is positive"). A **position** is what you actually hold (0 or 1 shares, or a fraction of capital). A **weight** is position size as a share of the portfolio. Keeping them separate lets you change sizing (Day 27) without touching the idea. In this lab the position is 0 or 1, meaning flat or fully invested.

### The one-bar lag

You observe the close of bar t, compute the signal, and can act no earlier than the next bar. So `position[t] = signal[t-1]`. Skipping this lag is **look-ahead bias**: the rule trades on a price it could not have known when it decided. It is the most common bug in amateur backtests and always flatters the result, sometimes enormously.

### Vectorized versus event-driven

A **vectorized** backtest computes signals, positions and returns as whole-array operations: fast, short, easy to audit, but it assumes you can trade the closing price in any size at a fixed cost. An **event-driven** backtest replays bars (or ticks) one at a time through the same code a live system would use, modeling order books, partial fills and latency. It is slower and bigger, and it is the right tool only when execution details are the strategy. For daily-bar ideas on liquid assets, vectorized is enough and has fewer places to hide bugs.

### Turnover and costs

**Turnover** is the amount of position traded: `|position[t] - position[t-1]|`. Going from flat to fully invested is turnover 1; flipping from +1 to -1 is 2. The lab charges `cost = turnover * cost_bps / 1e4` each bar, where one basis point (bp) is 0.01%. Ten bps on a one-way trade is a reasonable placeholder for liquid ETFs; Day 27 treats real costs properly.

### Metrics

| Metric | Meaning | In `common.quant` |
|---|---|---|
| CAGR | compound annual growth rate | `cagr` |
| Volatility | annualized standard deviation of returns | `annualize_vol` |
| Sharpe | mean excess return / volatility, annualized | `sharpe` |
| Max drawdown | worst peak-to-trough fall of equity | `max_drawdown` |
| Turnover | position traded per year, a cost driver | `turnover.sum() / years` |
| Hit rate | share of days (or trades) with positive return | `(ret > 0).mean()` |

The **benchmark** is buy-and-hold of the same asset. A strategy that earns 7% is good or bad depending on whether holding the asset earned 5% or 11%, and at what drawdown.

### Time-series momentum: the story and the evidence

**Time-series momentum** (trend following) goes long an asset when its own past return is positive and stays out (or short) when it is negative. The economic story has two legs. Behavioral: information diffuses slowly and investors anchor, so prices under-react at first and drift in the direction of news. Risk-premium: trend followers tend to buy what hedgers and forced sellers are dumping, and are paid for taking the other side of their urgency. The classic evidence is [Moskowitz, Ooi and Pedersen (2012), "Time series momentum", Journal of Financial Economics](https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum): across 58 futures and forwards (equity indices, currencies, commodities, bonds), an asset's own 12-month return predicted its next-month return, the effect persisted for about a year and then partly reversed. That is evidence for a diversified futures portfolio from 1965 onward (the paper's sample start), not a promise for one ETF over any window.

### The engineer trap

Building a platform before having an edge feels productive and teaches nothing about markets. The sequence that works is: hypothesis in a note, thirty lines of pandas, a benchmark, an out-of-sample check, and only then infrastructure (Day 29). Use pandas for the logic and vectorbt as an independent second implementation.

## Worked example

SPY (adjusted close, snapshot 2005-01-03 to 2026-09-29), hypothesis written first: "SPY under-reacts to bad macro news, so when it is below its level 200 trading days ago it tends to keep falling; stepping aside should cut drawdowns at the cost of some return. Falsified if max drawdown is not materially lower than buy-and-hold." Signal: `momentum_signal(spy, 200)`. Position: that signal lagged one bar. Results from `main()`:

| | CAGR | Vol | Sharpe | Max drawdown |
|---|---|---|---|---|
| Buy and hold | 10.9% | 18.9% | 0.64 | -55.2% |
| 200-day momentum, 0 bps | 7.6% | 12.6% | 0.64 | -33.6% |
| 200-day momentum, 10 bps | 7.1% | 12.6% | 0.60 | -35.3% |

The rule is invested about 79% of days and switches 103 times in 21 years (about 5 switches a year). Over the 2007-10 to 2009-03 slide (2007-10-09 to 2009-03-09) SPY lost 55.2% and the rule 16.6%; over 2022-01 to 2022-10 the figures were -24% and -13%. The crash-window and hit-rate figures are computed outside `main()`; see Exercise 5 for the same pattern on sub-periods. The hypothesis survives: drawdown fell by about a third. The Sharpe did not improve, and CAGR fell by 3 points, so this is risk reduction bought with return. A hit rate is nearly useless here (55.3% positive days in market versus 55.0% for buy-and-hold): trend rules win by avoiding large losses, not by being right often.

Honest caveats (all computed outside `main()`, at 10 bps, using the Exercise 4 and 5 recipes): the 200-day lookback was chosen from convention, and the five-point scan gives Sharpe 0.58 (50), 0.61 (100), 0.66 (150), 0.60 (200), 0.63 (250) at 10 bps (0.69, 0.69, 0.72, 0.64, 0.65 at 0 bps). A scan every 10 days from 50 to 250 ranges 0.48 to 0.77 at 10 bps (0.56 to 0.82 at 0 bps), and 200 days sits in the lower half, so the result is not tuned, but the spread shows how much a parameter choice can move Sharpe. Sub-periods differ (0 bps): Sharpe 0.50 vs 0.46 (rule vs hold) in 2005-2014 and 0.76 vs 0.82 in 2015-2026. On BTC-USD, annualizing with 365 days, buy-and-hold has Sharpe 0.99 and max drawdown -83%; the rule at 10 bps has Sharpe 1.06 and max drawdown -68%, with CAGR 53.0% vs 54.2%.

```
Position/return timeline (the lag)
 bar:        t-1     t      t+1
 close seen:        P_t
 signal:            s_t
 held over:                 pos = s_t   earns r_(t+1)
```

**Cross-check with vectorbt.** `main()` feeds the same trades to `vbt.Portfolio.from_signals(close, entries, exits, fees=..., init_cash=1.0, size=inf, freq="1D")`. vectorbt fills at the close of the bar where the signal sits, so entries and exits derived from the lagged position must be moved back one bar; done that way, final equity matches to four decimals at zero cost and to about 0.02 at 10 bps (the lab subtracts the cost additively from the next bar's return, while vectorbt deducts it multiplicatively at the fill, so the per-entry gap is about c*r + c^2 for fee rate c and bar return r, and its sign follows r). Without that shift the two disagree by 2 units of equity, a reminder that the lag convention is the whole game.

**Verified as of 2026-10:** the installed vectorbt is 1.1.2 (`uv run python -c "import vectorbt as vbt; print(vbt.__version__)"`); `Portfolio.from_signals` accepts `close, entries, exits, size, fees, init_cash, freq` in that installed version (checked via `inspect.signature`). API reference: [vectorbt Portfolio docs](https://vectorbt.dev/api/portfolio/base/).

## Exercises

1. Write the hypothesis paragraph for 200-day momentum on BTC-USD before running anything. Name who is on the other side.
   **Hint:** think about who buys late in a crypto rally and who sells into a crash.
   **Solution sketch:** retail trend-chasing and leveraged liquidations create persistent moves; the counterparty is the late seller who capitulates and the leveraged long who is forced out; falsify it if the drawdown does not shrink or the result vanishes at 10 bps.
2. Run `backtest` with the signal not lagged (replace `signal.shift(1)` by `signal`) on SPY. By how much does CAGR rise, and why is that number meaningless?
   **Hint:** the unlagged rule holds the asset on the day that makes it go up.
   **Solution sketch:** CAGR jumps far above buy-and-hold because the position is chosen using the same bar's return; it is look-ahead and cannot be traded.
3. Compute annual turnover (`turnover.sum() / years`) for the SPY rule and the CAGR of the rule at 0, 25, 50 and 100 bps. Does any cost level make it match buy-and-hold CAGR?
   **Hint:** loop `cost_bps` over 0, 25, 50, 100 and compare CAGR with the benchmark.
   **Solution sketch:** annual turnover is about 4.7; CAGR falls roughly 0.5 points per 10 bps, and the rule is already below buy-and-hold CAGR at zero cost, so costs only widen the gap; its case is drawdown, not return.
4. Scan lookbacks 50, 100, 150, 200, 250 on SPY and print Sharpe. What should you conclude from a flat profile versus a sharp peak?
   **Hint:** a robust idea should not depend on one parameter.
   **Solution sketch:** a flat profile suggests the effect is not a fitted artifact; a sharp peak means the best value is probably noise; never report only the winner (Day 26).
5. Split SPY at 2015-01-01. Compare Sharpe of the rule and buy-and-hold in each half.
   **Hint:** use `bt.loc[a:b, "strat_ret"]` with `common.quant.sharpe`.
   **Solution sketch:** the rule's edge over the benchmark is small and changes sign between halves, which argues for modest conclusions; the drawdown benefit is the stable part.
6. Run `backtest` with a -1/+1 signal (it already handles it). What is the turnover of going from long to short?
   **Hint:** turnover is `|position.diff()|`.
   **Solution sketch:** the flip costs 2 units of turnover (sell the long, then sell short), so costs double for the same switch.

## Anti-patterns / Common mistakes

- **Same-bar execution.** Trading the close that generated the signal. Always lag one bar.
- **Optimizing the lookback on the full sample.** The winning parameter embeds knowledge of the future. Fix the rule from theory, or choose parameters on an earlier period and test on a later one.
- **No benchmark.** A 7% CAGR means nothing without buy-and-hold at the same period and drawdown.
- **Writing the hypothesis after the result.** Any pattern can be explained once seen.
- **Platform before edge.** Weeks on infrastructure for a rule that dies in a ten-line test.
- **Ignoring costs and first-row turnover.** Entering from cash is a trade; a NaN in the first turnover row silently poisons the equity curve.

## Lab

Open [`labs/day25/README.md`](../labs/day25/README.md). Implement `momentum_signal` and `backtest` in `lab.py` and run `uv run pytest day25`. `main()` runs 200-day momentum on SPY and BTC-USD at 0 and 10 bps, prints metrics against buy-and-hold, cross-checks with vectorbt, and saves `.cache/plots/day25.png`. The finished functions live in `labs/common/backtest.py`, verified by `uv run pytest common/tests/test_backtest.py`.

## Teardown

Nothing billable is created. The lab only reads frozen snapshots; no broker, no key, no order.

## Journal prompt

Write a three-line hypothesis for one trading idea you have heard of: why it should work, who loses, and the single result that would make you drop it. Put it in the journal before running any code.
