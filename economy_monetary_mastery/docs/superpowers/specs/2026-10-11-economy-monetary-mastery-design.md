# Economy, Monetary & Currency Systems Mastery (Phase 1) — Design Spec

**Date:** 2026-10-11
**Location:** `economy_monetary_mastery/`
**Duration:** 30 days, ~3.5 h/day (~105 h total)
**Path type:** Hybrid (theory + runnable Python labs, ~40% of daily time)

## Purpose & Goals

The learner is a software engineer with no prior finance or economics background. They want to
understand how money, central banks, currencies and crypto actually work in the real world, and to
turn that understanding into a working, honest quantitative trading/investing practice across US
stocks/ETFs, Vietnamese stocks and crypto.

Phase 1 is **quant-first, both-sided**: deep enough monetary/macro/crypto understanding to reason about
why prices move, plus a research pipeline that takes a trading idea from hypothesis → backtest → kill
checklist → paper trading. Mastery here means *mechanistic* understanding (you can draw the balance
sheets and write the code) rather than vocabulary.

The unconventional choice is the spine: **follow the money** — every topic is taught as balance-sheet
changes and the price of money (interest rates), with a daily quant skill thread so the trading block
lands on already-built tools. Later goals (systematic investing, deep quant, deep monetary theory) are
tracked as future phases in `ROADMAP.md`, each to get its own spec.

## Success Criteria

By Day 30, without notes, the learner can:

1. Draw the T-account entries for: a bank loan, a deposit transfer between banks, a central bank
   open-market purchase (QE), a repo, and a fiat-backed stablecoin mint/redeem.
2. Explain how a policy-rate change transmits to bond yields, equity valuations, the dollar, USD/VND
   and crypto, and name at least one channel where the textbook story fails.
3. Price a bond, compute duration, and explain why SVB failed using its own numbers.
4. Explain the VND exchange-rate regime (SBV central rate + band), why the impossible trinity binds
   Vietnam, and compute the VND-denominated return of a US ETF, hedged vs unhedged.
5. Explain Bitcoin issuance and UTXOs, Ethereum gas and staking, the three stablecoin designs and why
   Terra failed, and price a swap on a constant-product AMM including impermanent loss.
6. Explain what an order book, spread, market maker, perpetual funding rate and basis trade are.
7. Build a backtest from scratch, identify look-ahead/survivorship/overfitting bias in a given
   backtest, apply costs and position sizing, and compare against buy-and-hold.
8. Run a paper-trading bot (US paper broker or crypto testnet) with logging and a kill switch.
9. Write a personal investment policy statement and a scored prediction journal entry.

## Constraints & Environment

- **Local only.** Python 3.12 managed by `uv`; Jupyter optional. No cloud infrastructure.
- **No real money in Phase 1.** Trading is paper/testnet only. Content explains risk management as a
  core skill and carries a short "educational, not financial advice" note in README and Day 29.
- **Free data only:** FRED public CSV endpoint (no key), yfinance, ccxt public endpoints, vnstock
  (Vietnam), public Ethereum RPC. Every loader caches locally.
- **No credentials in files.** `labs/.env.example` holds placeholders for Alpaca paper and Binance
  testnet keys; `.env` is gitignored.
- **Deterministic tests.** Lab tests read only frozen snapshots in `labs/data/`; network fetches are
  opt-in (`--live`) and write to an ignored cache, never to the snapshots.
- **Time-sensitive facts** (Vietnamese market rules, stablecoin regulation, settlement cycles, rate
  levels, ETF availability) are web-verified during authoring and stamped "as of 2026-10".
- **Git:** authored on scratch branch `authoring/economy_monetary`; never pushed; torn down back to
  `feature/with_currency` as untracked files. No git commands in subagents.

## Strategy (the core design decision)

**Top-1% moves** (become `STRATEGY.md`):

1. **Think in balance sheets.** Every monetary event is a double-entry change. Engineers learn this
   fast because it is state-transition reasoning.
2. **Go to primary data, not commentary.** Fed H.4.1, FRED, SBV releases, raw on-chain data.
3. **Build the mechanism to understand it.** Toy bank, order book, AMM, stablecoin, ~100 lines each.
4. **Try to kill every strategy idea first.** Out-of-sample, costs, multiple-testing penalty
   (deflated Sharpe), buy-and-hold benchmark.
5. **Survive before you profit.** Position sizing, drawdown limits, fractional Kelly before returns.
6. **Use base rates.** Most active traders underperform an index; the index is the bar.
7. **Keep a scored prediction journal.** Probabilistic macro calls, graded for calibration.

**Mistakes that waste 80% of beginners' time** (each mapped to the day that inoculates against it):

| Mistake | Fixed on |
|---|---|
| Starting with chart patterns, indicators, guru content | Day 25–26 (show they fail the kill checklist) |
| Grinding textbook supply curves / IS-LM; the money-multiplier myth | Days 1–3 |
| Fooling yourself with backtests (overfit, look-ahead, survivorship) | Day 26 |
| Ignoring fees, slippage, FX conversion, taxes | Days 17, 27 |
| Watching crypto prices instead of mechanisms; yield without asking its source | Days 21–23 |
| Real money or leverage too early | Days 27, 29 |
| (SWE-specific) building a beautiful platform before evidence of an edge | Day 25, 29 |
| Trading the news instead of expectations ("priced in") | Days 11–12 |

**Rejected alternatives:** *Markets-first* (backtest from Day 1, theory just in time) — engaging but
leaves monetary and crypto understanding shallow, contradicting the deep-comprehension goal.
*Parallel tracks* (independent daily theory + quant blocks) — balanced but the tracks don't reinforce
each other, and the daily context switch costs time.

## Curriculum

Daily budget: ~1.5 h theory, ~1.5 h lab, ~0.5 h exercises + journal. Integration days (6, 12, 18, 24)
run ~3 h: case drill + checkpoint quiz with answer key + journal review. "Quant thread" names the
reusable skill each lab adds; it accumulates into `labs/common/` helpers used in Block 5.

### Block 1 — Money & banking plumbing

| Day | Theory | Lab | Quant thread |
|---|---|---|---|
| 1 | What money is: IOUs, hierarchy of money, T-accounts; uv/pandas setup | T-account engine (`Ledger` with balanced postings) | Load a FRED series with pandas |
| 2 | Banks create money: loans create deposits, reserves, payments, capital vs liquidity | Toy banking system + bank run | Simple and log returns |
| 3 | Central banks: policy-rate corridor, open-market operations, QE/QT, Fed H.4.1 | Fed balance sheet vs reserves vs policy rate | Resampling, aligning frequencies |
| 4 | Inflation: CPI, expectations, Fisher equation, real rates, fiscal vs monetary | Real policy rate and real asset returns | Compounding, CAGR, real returns |
| 5 | Shadow banking: repo, MMFs, eurodollars; 2008, March 2020, SVB 2023 | Rebuild SVB's unrealized losses from duration | Drawdowns, max drawdown |
| 6 | Integration | Case drill + checkpoint quiz; start `journal.md` | — |

### Block 2 — Rates & asset pricing

| Day | Theory | Lab | Quant thread |
|---|---|---|---|
| 7 | Bonds: price/yield, duration, convexity, yield curve, inversion | Bond pricer + yield-curve plot | Vectorized numpy math |
| 8 | Discounting everything: DCF, equity risk premium, what a share is | Rate sensitivity of growth vs value | Correlation, beta |
| 9 | Market structure: order books, market makers, order types, settlement (US T+1, VN T+2), brokers, ETF creation/redemption | Price-time-priority matching engine | Spread and impact as costs |
| 10 | Portfolio theory: diversification, volatility, Sharpe, efficient frontier, factors | 60/40 portfolio + frontier | Covariance, annualization |
| 11 | Business cycle & regimes: GDP, jobs, PMI, central-bank reaction function, "priced in" | Rule-based macro regime classifier | Rolling windows |
| 12 | Integration | Fed-meeting-day simulation + checkpoint quiz | — |

### Block 3 — FX, the dollar & Vietnam

| Day | Theory | Lab | Quant thread |
|---|---|---|---|
| 13 | FX mechanics: quotes, spot/forward, covered & uncovered interest parity, carry | Forward pricer + CIP check | FX return conversion |
| 14 | Dollar system: reserve currency, eurodollars, swap lines, DXY, EM dollar cycles | DXY vs EM currencies | Event windows |
| 15 | Regimes & impossible trinity, capital controls, crises (Asia 1997, Turkey, Argentina) | Trinity scenario simulator | Scenario analysis |
| 16 | Vietnam: SBV tools, VND central rate + band, dollarization, gold, credit quotas; HOSE/HNX/UPCoM, foreign-ownership limits, price limits, market-upgrade status | VN-Index vs USD/VND (vnstock) | Handling limit-move data |
| 17 | Investing across currencies: VND return on US ETFs, hedged vs unhedged, cost overview | VND-denominated SPY returns | Multi-currency P&L |
| 18 | Integration | Cross-currency case drill + checkpoint quiz | — |

### Block 4 — Crypto deep dive

| Day | Theory | Lab | Quant thread |
|---|---|---|---|
| 19 | Bitcoin: hashing, UTXO, proof of work, difficulty, halving, monetary policy as code | Toy blockchain with UTXOs + issuance schedule | Hashing, data integrity |
| 20 | Ethereum: accounts, gas, EVM, proof of stake, L2s | Decode blocks/receipts from raw JSON-RPC (recorded fixtures for tests; no web3 library) | JSON-RPC parsing |
| 21 | Stablecoins: fiat-backed (as shadow banks), crypto-collateralized, algorithmic (Terra), regulation | Peg + death-spiral simulation | Agent-based simulation |
| 22 | DeFi: AMMs, impermanent loss, lending, liquidations, MEV, where yield comes from | Constant-product AMM + IL calculator | Path dependence |
| 23 | Crypto market structure: CEX vs DEX, custody (FTX), perps and funding, basis trade, spot ETFs | Funding-rate and basis analysis (ccxt) | Carry measurement |
| 24 | Integration | Crypto vs fiat monetary-system comparison + checkpoint quiz | — |

### Block 5 — Quant trading

| Day | Theory | Lab | Quant thread |
|---|---|---|---|
| 25 | Research workflow; backtest anatomy | Vectorized backtester from scratch, then cross-check with vectorbt | Signal → position → P&L |
| 26 | How backtests lie: look-ahead, survivorship, overfitting, multiple testing, deflated Sharpe, walk-forward | Break your own strategy; p-hacking demo | Train/test discipline |
| 27 | Costs & risk: fees, slippage, spreads, volatility targeting, fractional Kelly, drawdown control | Add costs and sizing; watch the edge shrink | Risk-adjusted metrics |
| 28 | Strategy families: trend, mean reversion, carry, factors, risk parity | Multi-asset trend + risk-parity portfolio | Portfolio of strategies |
| 29 | Paper trading: architecture, broker abstraction, kill switch, logging | Paper bot (Alpaca paper / Binance testnet) behind a `Broker` interface | Fake broker for tests |
| 30 | Capstone | Idea → kill checklist → paper deployment; personal investment policy statement; Phase 2 plan | — |

## Labs Design

- Each `labs/dayNN/` contains `README.md` (goal, steps, success signal, teardown), `lab.py` (TODO
  stubs with docstrings), `test_lab.py`, `solution.py`, `SOLUTION.md` (walkthrough + why).
- Tests import `lab` by default; `LAB_IMPL=solution pytest dayNN` runs them against the reference.
  Starter stubs raise `NotImplementedError`, so a fresh lab fails cleanly, never with import errors.
- `labs/common/` holds data loaders (`fred`, `prices`, `crypto`, `vn`) that read snapshots by default
  and fetch with `live=True` into `labs/.cache/` (gitignored).
- `labs/data/` holds small frozen CSV/JSON snapshots, created once during authoring by
  `labs/data/snapshot.py` (public endpoints, no keys). Each snapshot records source and fetch date.
- Day 29's bot depends on a `Broker` protocol; tests use `FakeBroker`. Running against Alpaca paper or
  Binance testnet is the learner's step, using their own keys in `.env`.
- Teardown for each lab: no billable resources exist; Day 29's teardown revokes testnet/paper keys.

## Progress Tracking & Roadmap

- `PROGRESS.md`: per-day checkboxes for theory, exercises, lab tests passing, and quiz (integration days).
- `journal.md`: prediction-journal template (claim, probability, date, resolution, Brier score).
- `ROADMAP.md`: Phase 1 (this spec) plus future phases, each with goal, rough scope and status:
  - **Phase 2 — Systematic investor:** asset allocation, rebalancing, tax-aware investing for a VN
    resident holding US and VN assets, IPS refinement.
  - **Phase 3 — Deep quant:** statistical rigor, factor models, execution, live small-capital rollout
    with risk limits.
  - **Phase 4 — Deep monetary theory:** monetary history, MMT/Austrian/monetarist debates, central bank
    digital currencies, international monetary system design.

## Directory Layout

```
economy_monetary_mastery/
├── README.md              # quickstart, block map, day index, "not financial advice" note
├── STRATEGY.md            # top-1% moves + mistakes table
├── ROADMAP.md             # Phase 1–4 with status
├── PROGRESS.md            # per-day checkboxes
├── journal.md             # prediction journal template
├── content/
│   ├── GLOSSARY.md        # plain-English terms
│   └── day01.md … day30.md
├── labs/
│   ├── pyproject.toml     # uv: pandas, numpy, matplotlib, requests, pytest, vectorbt,
│   │                      #     ccxt, yfinance, vnstock, alpaca-py, python-dotenv
│   ├── .env.example       # placeholders only
│   ├── .gitignore         # .env, .cache/
│   ├── conftest.py        # LAB_IMPL switch
│   ├── common/            # loaders, quant helpers; backtest/stats/risk added in Block 5
│   ├── tools/             # verify_labs.py, check_content.py
│   ├── data/              # frozen snapshots + snapshot.py
│   └── day01/ … day30/    # README.md, lab.py, test_lab.py, solution.py, SOLUTION.md
└── docs/superpowers/
    ├── specs/             # this file
    └── plans/
```

Integration days (06, 12, 18, 24, 30) have a lab directory holding the case drill or capstone
scaffold; their quizzes live in the content file with an answer key.

## Content Day Skeleton

```markdown
# Day N — <Title>

> Block X · ~3.5 h (1.5 theory · 1.5 lab · 0.5 exercises/journal) · facts as of 2026-10

## Why this matters
<1 short paragraph tying the topic to real prices or a real event>

## Core concepts
<Body. Balance-sheet (T-account) diagrams wherever money moves. Plain-English first,
then the precise version. Links to primary sources.>

## Worked example
<One real-data or real-event example, step by step>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. ...

## Anti-patterns / Common mistakes
<2–3 bullets>

## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: `pytest labs/dayNN` passes.

## Teardown
<None billable; or key revocation on Day 29>

## Journal prompt
<One probabilistic prediction to log in journal.md>
```

## Verification (authoring time)

- `LAB_IMPL=solution uv run pytest` passes for all 30 labs, offline.
- Starter `lab.py` files fail with `NotImplementedError`, not import or syntax errors.
- Every exercise has a hint and a solution sketch; every lab has README, SOLUTION.md, teardown.
- Repo-wide sweep: no keys, tokens or account IDs; `.env` absent; `.env.example` placeholders only.
- Time-sensitive facts carry "as of 2026-10" and were web-checked.
