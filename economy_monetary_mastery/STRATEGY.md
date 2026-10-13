# Strategy

This course makes one unconventional choice: **follow the money**. Every topic is taught as a change in balance sheets plus the price of money (interest rates), and every day adds one reusable quant skill, so the trading block lands on tools you already built. The goal is mechanistic understanding: you can draw the T-accounts and write the code. Vocabulary is a by-product.

## The seven moves

**1. Think in balance sheets.** Every monetary event is a double-entry change: assets, liabilities, equity, always balanced. A software engineer already reasons in state transitions, so this is learned fast. Example: on Day 2 you post a bank loan as one transaction (the bank's asset "loan" up, its liability "deposit" up) and watch deposits get created with no prior saving. Day 1's `Ledger` refuses unbalanced postings, so you cannot misunderstand it quietly.

**2. Go to primary data, not commentary.** Commentary is a lossy, opinionated compression of data you can read yourself. Read the Fed's H.4.1 release, FRED series, SBV releases, raw on-chain data. Example: on Day 3 you plot the Fed's balance sheet (WALCL) against bank reserves (WRESBAL) and the policy rate, and find for yourself that QE and the rate are separate levers. Day 20 decodes raw Ethereum JSON-RPC instead of trusting a block explorer.

**3. Build the mechanism to understand it.** A toy version, about 100 lines, teaches more than a chapter. Example: Day 9's price-time-priority matching engine makes "spread", "liquidity" and "market order" concrete; Day 22's constant-product AMM makes impermanent loss a number you computed, not a slogan. The same applies to the toy bank (Day 2), stablecoin (Day 21) and blockchain (Day 19).

**4. Try to kill every strategy idea first.** The default state of a backtest is "wrong". Demand out-of-sample results, include costs, penalize for how many variants you tried (deflated Sharpe), and compare against buy-and-hold. Example: Day 26's p-hacking demo searches random noise until it finds a strategy with a beautiful Sharpe ratio, then shows it dying out of sample. After that you will distrust your own best result, which is the point.

**5. Survive before you profit.** Drawdowns are asymmetric: a 50% loss needs a 100% gain. Position sizing, drawdown limits and fractional Kelly come before any return target. Example: Day 27 starts from a strategy with a pleasant gross curve, adds fees, slippage and volatility-targeted sizing, and you watch the edge shrink; Day 29's bot ships with a kill switch before it ships with a strategy.

**6. Use base rates.** Most active traders underperform a cheap index fund after costs, and most published "edges" decay once found. Your prior for any new idea should be "this will not work". The index is the bar. Example: Day 10 builds a 60/40 portfolio and Day 25 uses buy-and-hold as the mandatory benchmark; an idea earns attention only by beating it net of costs and by more than luck would explain.

**7. Keep a scored prediction journal.** Opinions you never score never improve. Write falsifiable, dated claims with a probability, resolve them, and compute the Brier score; check calibration (do your 70% calls come true about 70% of the time?). Example: every content file ends with a journal prompt (Day 1: where will the fed funds rate be at a date; Day 12: FOMC claims), and each integration day reviews your hit rate. This is the cheapest feedback loop in the course, and it is the same habit that separates forecasters from commentators.

## Mistakes that waste 80% of beginners' time

| Mistake | Fixed on | What to do instead |
|---|---|---|
| Starting with chart patterns, indicators, guru content | Days 25-26 | Run any pattern through the kill checklist: out-of-sample, costs, benchmark. Most fail. |
| Grinding textbook supply curves / IS-LM; believing the money-multiplier myth | Days 1-3 | Learn the balance sheets: loans create deposits, reserves settle payments, the central bank sets the price of reserves. |
| Fooling yourself with backtests (overfitting, look-ahead, survivorship) | Day 26 | Lag every signal, use point-in-time universes, hold out data you never touch, count every variant you tried. |
| Ignoring fees, slippage, FX conversion, taxes | Days 17, 27 | Model costs in the first backtest, convert everything to your home currency (VND), and treat gross returns as fiction. |
| Watching crypto prices instead of mechanisms; chasing yield without asking its source | Days 21-23 | Ask who pays the yield and what breaks it: issuance, leverage, funding rates, or someone else's loss. |
| Real money or leverage too early | Days 27, 29 | Paper and testnet only; add a kill switch; earn the right to size up with evidence, not conviction. |
| (SWE-specific) building a beautiful platform before any evidence of an edge | Days 25, 29 | Write the ugly vectorized backtest first; automate only what already survived the kill checklist. |
| Trading the news instead of expectations ("priced in") | Days 11-12 | Compare outcomes with what was expected; the surprise moves prices, the headline does not. |

## Why not the traditional path

Two common routes were considered and rejected.

*Textbook-first* (macro and monetary theory for weeks, trading last) feels rigorous but front-loads supply and demand curves, IS-LM and the money multiplier, which describes a world of reserve-constrained banks that does not exist. It also postpones all hands-on work, so motivation fades before you touch data. The course instead teaches the operational plumbing that actually matters (Days 1-3) and keeps theory tied to a lab the same day.

*Markets-first* (backtest from Day 1, theory just in time) is engaging but leaves monetary and crypto understanding shallow, contradicting the goal of deep comprehension. You would learn to run backtests without knowing why yields, the dollar and liquidity move prices, and you would be the beginner most likely to fool yourself with one.

A third option, parallel tracks (independent daily theory and quant blocks), was also rejected: the tracks do not reinforce each other, and the daily context switch costs time. The follow-the-money spine solves that by making each lab apply the day's theory and add one quant skill, so by Block 5 the tools are built and the only new content is the research discipline.

## How to use the 3.5 hours

| Slot | What | Rule |
|---|---|---|
| 1.5 h | Theory | Read actively. Redraw each T-account on paper before looking at the answer. Open the primary-source links. |
| 1.5 h | Lab | Run `uv run pytest dayNN` first; the failures are your to-do list. Implement one function at a time. |
| 0.5 h | Exercises + journal | Attempt exercises before reading hints; then write the day's journal entry with a probability. |

**One question per day into `journal.md`.** At the end of each day write down the one thing you still cannot explain or predict, as a question or a dated claim. Revisit the questions at integration days: the ones still open are your real study list, and the ones you resolved are your proof of progress.

**When to peek at solutions.** After 25 minutes stuck on one function, read the relevant part of `SOLUTION.md` or `solution.py` (`LAB_IMPL=solution uv run pytest dayNN` shows the reference passing). Then close it and rewrite the function yourself from memory. Peeking is fine; copying without rewriting is the failure mode.

**Integration days (6, 12, 18, 24, 30; Day 30 is also the capstone)** are about 3 h: do the case drill, take the quiz closed-book, score it against the key, then review your journal calibration. Tick `PROGRESS.md` honestly; a tick without a passing lab is worthless to the one person who reads it.
