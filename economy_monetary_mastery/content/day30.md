# Day 30 — Capstone: idea to paper deployment

> Block 5: Quant trading (integration and capstone). Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Twenty-nine days produced a vocabulary (money, banks, bonds, FX, crypto) and tools (backtester, deflated Sharpe, cost and sizing helpers, a kill-switch bot). Today they are used together once, on one idea, under rules written before the result. The usual outcome is "kill": that is the process working; a checklist exists to stop paper deployment of a curve that only looks good.

The second job is a map. Every market, whether a bank loan, a Treasury bill or a perpetual future, is a claim on someone's promise to pay, priced by discounting, moved by someone who needs to settle.

## Core concepts

### Block 5 in one table

| Day | Question | Tool | What Day 30 reuses |
|---|---|---|---|
| 25 | Can I test a rule honestly? | `backtest`, one-bar lag | the whole pipeline |
| 26 | How much is luck? | PSR, DSR, walk-forward, research log | `dsr`, OOS split, `n_trials` |
| 27 | Does it survive costs and my nerves? | breakeven cost, vol targeting, Kelly | `breakeven_cost_bps`, `max_drawdown` |
| 28 | Who pays me, and when does it fail? | trend, carry, mean reversion, inverse vol | the hypothesis |
| 29 | Can I run it safely? | `Bot`, kill switch, paper accounts | the paper-trade plan |

### The whole course on one page: follow the money

```
Day  1- 6  CLAIMS         Money is an IOU, tracked in T-accounts. Banks create deposits by lending (2).
                          Central banks steer the short rate and the reserve balance sheet (3).
                          Inflation erodes the claim; real rate = nominal - inflation (4).
                          Repo and money funds move the same claims outside banks (5).
Day  7-12  PRICES         A bond is a claim priced by discounting; duration is its rate risk (7).
                          Stocks are discounted cash flows with an equity risk premium (8).
                          Order books and settlement are where a price becomes a trade (9).
                          Diversification and Sharpe turn prices into portfolios (10).
                          Regimes and "priced in" explain why the same news moves markets differently (11).
Day 13-18  CURRENCIES     Every cross-border return is asset return x FX return (13, 17).
                          The dollar is the funding currency (14); the trinity says what a country gives up (15).
                          Vietnam's regime: SBV tools, VND band, access limits (16).
Day 19-24  CRYPTO         The same questions on a new ledger: Bitcoin (19), Ethereum (20), stablecoins as
                          reserve-backed IOUs (21), DeFi as automated market makers and liquidations (22),
                          exchanges, perpetuals, basis and funding (23).
Day 25-29  EVIDENCE       Testing (25), luck (26), costs and size (27), strategy families (28), execution (29).
Day 30     DECISION       Kill checklist -> paper deployment, plus a written policy for real money later.
```

Four questions run through every row: who owes whom (claims), what is it worth today (discounting), what does it cost to move (spread, fees, settlement, FX), and who loses when I win (the counterparty). An idea that cannot answer the last has no edge worth testing.

```
A paper trade, as claims (simulated):   Paper account: Shares +10, Cash -1,000
                                        Market:        Cash +1,000, Shares -10
```

A paper account has no broker risk, FX or market impact, so paper results are an upper bound.

### The kill checklist

Six rules, each a number on the `run_capstone` report, each with a reason:

| Rule | Fails when | Why |
|---|---|---|
| `deflated_sharpe` | `dsr < 0.95` | The best of N variants looks good by luck (Day 26). |
| `oos_decay` | `oos_sharpe < 0.5 * is_sharpe` | A rule that loses more than half its Sharpe on unseen data was probably fitted. |
| `beats_benchmark` | `net_sharpe <= benchmark_sharpe` | Buy-and-hold is free; a rule must beat it after costs on the same dates. |
| `sample_size` | `n_trades < 30` | Fewer than 30 trades cannot separate skill from chance. |
| `drawdown` | `max_drawdown < -0.35` | A fall worse than 35% is one most people abandon (Day 27). |
| `cost_survival` | `breakeven_cost_bps < 2 * assumed_cost_bps` | Costs are estimated, not known; demand a 2x margin (Day 27). |

These thresholds are this course's judgement calls. Their value is that they are fixed before the result is known.

### The pipeline in `run_capstone`

Split the series 60/40 by rows. Choose the lookback with the best gross Sharpe in the first part only, and deflate that Sharpe for the number of lookbacks tried. Re-run the chosen rule with costs and read the out-of-sample Sharpe from the last 40%, against buy-and-hold. This is one train/test split, test block looked at once; walk-forward (Day 26) is heavier. The count of lookbacks is `n_trials`, honest only if the log lists every variant tried.

### The investment policy statement (IPS)

An IPS is a short written contract with yourself: goals, horizon, liquidity needs, the maximum drawdown you can sit through, allocation ranges, a rebalancing rule, rules you will not break, a review date. It is written when calm so that a drawdown has a script.

Vietnam context (facts only, as of 2026-10). Under [Decree 135/2015](https://conventuslaw.com/report/3-things-about-overseas-securities-investment-by/), which Day 16 treats as the operative framework, resident individuals have no general channel to own foreign securities, so the "US ETFs" row of an IPS may be unavailable or restricted for a resident; Day 17 teaches VND-return arithmetic, not the legal route; practical FX limits are unverified as of 2026-10. Crypto is under a five-year licensing pilot (Resolution 05/2025/NQ-CP, Day 23; no issued exchange licence was confirmed). The template therefore asks for a minimum, a maximum and an availability note per bucket, not a recommended split; a licensed adviser and the SBV are the authorities.

## Worked example

Run `uv run python -m day30.solution` (or your `lab.py`). On the snapshots (SPY 2005-01-03 to 2026-09-29, lookbacks 20, 60, 120, 200, 250, 5 bps), `main()` prints:

```
== SPY ==   dsr 0.994  is_sharpe 0.849  oos_sharpe 0.499  net_sharpe 0.499
            benchmark_sharpe 0.788  n_trades 157  max_drawdown -0.255
            breakeven_cost_bps 112.335  assumed_cost_bps 5.000  chosen_lookback 120
            failed checks: ['beats_benchmark']   verdict: kill
```

Reading each line:

- `chosen_lookback 120`: best gross Sharpe on the first 60% of rows (before 2018-01-16, a split date computed outside `main()`). Five lookbacks, so `n_trials = 5`.
- `is_sharpe 0.849`: annualized gross in-sample Sharpe, the flattering maximum of five.
- `dsr 0.994`: the probability that Sharpe beats what the luckiest of five skill-less trials would show. The lookbacks are highly correlated, so the cross-trial variance is small and the deflation mild. Passes.
- `oos_sharpe 0.499`: the same rule on the last 40% of rows, net of 5 bps; about 59% of the in-sample value, so `oos_decay` passes. `net_sharpe` is the same number by construction.
- `benchmark_sharpe 0.788`: buy-and-hold over the same rows (a strong market). `beats_benchmark` fails, the only failure.
- `n_trades 157`: position changes over 21 years, well above 30.
- `max_drawdown -0.255`: worst fall of the costed curve; buy-and-hold fell 55% in 2007 to 2009 (Day 25). Passes.
- `breakeven_cost_bps 112.3` against `assumed_cost_bps 5`: costs could rise 22 times before gross profit vanished (first-order, Day 27). Passes.

The rule reduces drawdown rather than enhancing return, as Day 25 found. If that were the goal, it belongs in the hypothesis before testing, not waived afterwards.

BTC-USD (10 bps, 365-day annualization) picks the 20-day lookback with an in-sample Sharpe of 1.74, which falls to 0.44 out-of-sample (`oos_decay` fails), trails buy-and-hold at 0.47 and draws down 54% (`drawdown` fails): three failures, "kill". SPY's out-of-sample Sharpe at 0, 10 and 25 bps is 0.53, 0.47 and 0.38 against a benchmark of 0.79 (computed outside `main()`; see Exercise 4): costs worsen the verdict but do not cause it.

## Exercises

1. Complete `CAPSTONE.md` for your own idea. Write the Hypothesis section first, then log every variant before running `run_capstone` on the winner.
   **Hint:** start from one family in Day 28 and answer "who pays me and when does it fail" in two sentences; if you cannot, pick another family.
   **Solution sketch:** a complete file has a hypothesis dated before the test, a variants table whose row count equals `n_trials`, the pasted report, six pass/fail marks and a decision. "Kill" names which part of the hypothesis was wrong. "Paper-trade" (the deployment step is Day 29 Exercise 8) names the venue, a size, at least three months, the metrics to compare with the backtest (Sharpe, turnover, realised cost per trade, drawdown) and stop conditions such as a daily-loss limit and a kill file.

2. Write your IPS in `CAPSTONE.md`, with a minimum, a maximum and an availability note for US ETFs, VN equities, crypto and cash.
   **Hint:** take the drawdown figure from what you tolerated in Day 27's sizing exercise, not from a number that sounds brave, and mark any row you cannot legally or practically use.
   **Solution sketch:** check consistency: minimums sum to at most 100% and maximums to at least 100%; the tolerated drawdown must exceed the fall implied by the maximums (a 50% crypto cap with an 80% crypto drawdown breaks a 30% tolerance); the emergency reserve sits in cash; restricted rows show a zero or conditional range with the reason. Add a review date and one "never" rule the Day 29 kill switch also enforces.

3. Resolve every entry in `journal.md` whose date has passed and list the open ones with their resolve dates; then compute your Brier score and one calibration check on the resolved entries.
   **Hint:** Brier is the mean of (p - outcome)^2; a constant 50% forecast scores 0.25.
   **Solution sketch:** p = 0.7 resolving true scores 0.09; p = 0.8 resolving false scores 0.64; the mean is 0.365, worse than a coin. For the bucket check, compare the hit rate of entries with p between 0.6 and 0.8 with their average p; a far lower hit rate means over-confidence. Under about 20 resolved entries, treat the score as a hint.

4. Run `run_capstone` on SPY with `cost_bps` of 0, 10 and 25 (lookbacks 20, 60, 120, 200, 250, as in `main()`). Which values move and which do not?
   **Hint:** call `run_capstone(spy, lookbacks, cost_bps=c)` in a loop and print the dict.
   **Solution sketch:** `oos_sharpe`, `net_sharpe` and `max_drawdown` worsen as cost rises; `dsr`, `is_sharpe`, `n_trades`, `chosen_lookback` and `breakeven_cost_bps` do not, because the lookback is chosen gross of costs and breakeven uses gross returns. At 25 bps `oos_decay` also fails (out-of-sample Sharpe 0.378 against half the in-sample value, 0.4245). The verdict stays "kill" because the benchmark gap already fails.

## Checkpoint quiz

Questions 1 to 12 cover Days 25 to 29; 13 to 15 are cumulative.

1. Why does `position[t]` equal `signal[t-1]`, and what happens to the backtest if you drop the lag?
2. A strategy flips from fully long to fully short. What is the turnover of that flip, and what does it cost at 10 bps?
3. You tried five lookbacks on SPY, then switched to BTC-USD and tried the same five. What `n_trials` do you use for the DSR?
4. Your annualized daily Sharpe is 1.2. What value do you pass as `sr` to `deflated_sharpe_ratio` and why?
5. Why is ordinary k-fold cross-validation a poor fit for return series, and what does walk-forward do instead?
6. Total gross return is 0.85 (sum of daily returns) with total turnover 40. What is the breakeven cost in bps, and if realistic costs are 25 bps, is the margin comfortable?
7. Annualized excess return 8%, volatility 20%. What is full Kelly, and why do practitioners use half or a quarter of it?
8. After a 50% drawdown, what gain restores the peak, and why does that matter for choosing a volatility target?
9. Name one payer and one failure regime for trend following, and one for funding carry.
10. Two assets have volatilities of 10% and 20%. What are their inverse-volatility weights?
11. In `Bot.step`, where do the kill checks run relative to the strategy call, and why?
12. Why is a bot that targets a position safer on retry than one that sends "buy 10"?
13. (Day 2) A bank makes a 100 loan to a borrower who deposits it at the same bank. What changes on the balance sheet, and what did the loan not need first?
14. (Day 4) Nominal yield 5%, expected inflation 3%. What is the approximate real rate, and what is the exact Fisher result?
15. (Day 17) A USD-priced ETF gains 10% while USD/VND rises from 25,000 to 26,000. What is the VND return, and does this tell you whether a resident individual may legally hold the ETF?

## Answer key

1. The close of bar t is known only after it, so the position held in bar t+1 comes from the signal at t. Dropping the lag is look-ahead bias: the rule holds the asset on days it already knows go up, so CAGR is inflated and untradable.
2. Turnover is 2 (sell the long, then sell short), so the cost is 2 x 10 bps = 20 bps of capital per flip, double a flat-to-long entry.
3. Ten, or more if any variant was looked at and discarded: every variant evaluated is a trial, whatever you kept.
4. The per-period Sharpe, about 1.2 / sqrt(252) = 0.076 for daily equity data (sqrt(365) for native daily crypto). The PSR/DSR formula uses per-period units; annualized inputs make everything look near-certain.
5. K-fold can train on data after the test fold, and overlapping labels leak outcomes across the boundary. Walk-forward fits on a past window, trades the next block, slides forward and stitches the test blocks; purging and an embargo are refinements.
6. 0.85 / 40 x 10,000 = 212.5 bps. Against 25 bps there is a large margin (about 8.5x, and above the 2x rule). It is first-order: it ignores compounding and the cost of capital.
7. f* = mu / sigma^2 = 0.08 / 0.04 = 2.0, or 200% invested. Mu is estimated badly and f* scales with it; past about twice Kelly expected growth turns negative. Fractional Kelly trades a little growth for much less variance.
8. A 100% gain (a loss d needs d/(1-d)). Few people hold through deep drawdowns, so choose the volatility target so the historical worst one is a drawdown you pre-committed to survive.
9. Trend: slow adjusters and hedgers or policy-driven buyers pay; fails in sharp reversals and choppy ranges. Funding carry: leveraged longs pay the funding rate; fails when funding turns negative or the exchange fails or liquidates the margin.
10. Weights proportional to 1/vol: 1/0.10 = 10 and 1/0.20 = 5, so 2/3 and 1/3.
11. First, before the strategy runs. A safety check placed after the signal can be skipped by a signal bug. The daily-loss latch also stays set until a human restarts the bot.
12. A target-position bot computes `target - current position` from the broker's state, so a duplicate run finds a delta of zero and holds. "Buy 10" sent twice buys 20.
13. Assets (loan) +100 and liabilities (deposit) +100; the bank did not need a prior deposit before lending.
14. About 2% (5 - 3). Exact: (1.05 / 1.03) - 1 = 1.94%.
15. 1.10 x (26,000 / 25,000) - 1 = 1.10 x 1.04 - 1 = 14.4% in VND. No: it is arithmetic only. Under Decree 135/2015 as treated in Day 16, a resident individual has no general channel to hold foreign securities, so legal access is a separate question for a licensed adviser (unverified as of 2026-10 for practical limits).

## Anti-patterns / Common mistakes

- **Moving the thresholds after seeing the report.** After a failure, kill the idea or write a new hypothesis and log it as a new trial.
- **Headlining the in-sample Sharpe.** It is the maximum of N; report the out-of-sample, net-of-cost number.
- **An incomplete variant log.** Dropped variants still count toward `n_trials`; omitting them makes the DSR optimistic.
- **Treating a pass as a green light for real money.** A pass earns three months of paper trading, not capital (Day 29's limits of paper).
- **An IPS copied from a template.** Ranges must reflect what you can legally hold from Vietnam.
- **Leaving credentials alive.** Paper and testnet keys are still keys; revoke them (Teardown).

## Lab

Open [`labs/day30/README.md`](../labs/day30/README.md). Implement `kill_checklist`, `verdict` and `run_capstone`, run `uv run pytest day30` (9 tests) and `uv run python -m day30.lab` (SPY and BTC-USD reports, plus `.cache/plots/day30.png`). Then work through [`labs/day30/CAPSTONE.md`](../labs/day30/CAPSTONE.md) for your own idea; the pipeline accepts any price series.

## Teardown

- Stop any running bot (Ctrl-C), or create the kill file if a process is still alive.
- If you created Alpaca paper or Binance testnet keys: revoke or rotate them in the dashboards ([Alpaca](https://docs.alpaca.markets/docs/paper-trading), [Binance testnet](https://testnet.binance.vision)) and delete `labs/.env` if you are done.
- Delete `.cache/day29_bot.jsonl` and `.cache/day29_KILL`.
- Archive the journal: from `labs/`, copy it to a dated file (`cp ../journal.md ../journal-archive-YYYY-MM-DD.md`) and start a fresh table for Phase 2, keeping the resolved entries and the calibration review in the archive. Nothing billable remains.

## What next

Tick Day 30 and the quiz box in [`PROGRESS.md`](../PROGRESS.md), then read [`ROADMAP.md`](../ROADMAP.md). Phases 2 to 4 share one entry criterion: the Day 30 capstone passed the kill checklist or was honestly killed, and PROGRESS.md is at least 90% ticked.

- **Phase 2, systematic investor:** allocation, rebalancing and tax for a Vietnam resident, refining the IPS with real constraints.
- **Phase 3, deep quant:** inference, factor models, execution and a small-capital rollout under pre-registered limits.
- **Phase 4, deep monetary theory:** monetary history, competing schools, CBDCs and the international system, with Vietnam as a case study.

Start each by running the building-learning-path workflow with its roadmap section as the brief.

## Journal prompt

Write one number that, if seen during paper trading, makes you stop your idea, and the date you will review the experiment. Put a probability on "this idea passes the same checklist after three months of paper results" and log it.
