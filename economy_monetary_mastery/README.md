# Economy, Money & Markets: Phase 1

A 30-day course (~3.5 h/day, ~105 h) for a software engineer with no finance background. The spine is "follow the money": every topic is taught as balance-sheet changes and the price of money (interest rates), so you can draw the T-accounts and write the code rather than recite vocabulary. Each day pairs theory with a Python lab, and a quant skill built in the labs accumulates into helpers you use in Block 5 to take a trading idea from hypothesis to backtest, kill checklist and paper trading. Markets covered: US stocks/ETFs, Vietnamese stocks, crypto.

## Not financial advice

This course is educational, not financial advice. Phase 1 uses no real money: trading is paper or testnet only. Past performance and backtests do not predict future results, and most of Block 5 exists to show you why.

## Quickstart

```bash
brew install uv
cd labs && uv sync
uv run pytest day01          # expect failures: that is your to-do list
uv run python -m day01.lab   # after implementing day01; on stubs this raises NotImplementedError
```

`labs/.python-version` pins CPython 3.12; `uv sync` fetches it if needed. Run every lab command from `labs/`.

## How a day works

| Time | Activity | Where |
|---|---|---|
| 1.5 h | Theory | the day's file in `content/` (`dayNN.md`) |
| 1.5 h | Lab: make the failing tests pass | `labs/dayNN/` (README.md has the steps) |
| 0.5 h | Exercises + one journal entry | end of the day's content file, `journal.md` |

Tick the day's boxes in `PROGRESS.md`. Integration days (6, 12, 18, 24, 30; Day 30 is also the capstone) run ~3 h: case drill, checkpoint quiz with answer key, journal review. Day 30 is the capstone.

## Block map

| Block | Days | Goal |
|---|---|---|
| 1. Money & banking plumbing | 1-6 | Draw the balance sheets of money creation, central banks and shadow banking; explain SVB with its own numbers. |
| 2. Rates & asset pricing | 7-12 | Price bonds and equities as discounted cash flows; understand market structure, portfolio theory and regimes. |
| 3. FX, the dollar & Vietnam | 13-18 | Reason about exchange rates, the dollar system and the VND regime; compute hedged vs unhedged VND returns on US ETFs. |
| 4. Crypto deep dive | 19-24 | Understand Bitcoin, Ethereum, stablecoins, DeFi and crypto market structure as mechanisms, not price charts. |
| 5. Quant trading | 25-30 | Build a backtester, break your own strategy, add costs and sizing, run a paper bot, write your investment policy statement. |

## Day index

| Day | Title | Lab |
|---|---|---|
| 01 | [What money is: IOUs and T-accounts](content/day01.md) | [labs/day01/](labs/day01/) |
| 02 | [Banks create money: loans create deposits](content/day02.md) | [labs/day02/](labs/day02/) |
| 03 | [Central banks: rate corridor, QE, H.4.1](content/day03.md) | [labs/day03/](labs/day03/) |
| 04 | [Inflation, real rates and the Fisher equation](content/day04.md) | [labs/day04/](labs/day04/) |
| 05 | [Shadow banking: repo, MMFs, SVB 2023](content/day05.md) | [labs/day05/](labs/day05/) |
| 06 | [Block 1 integration: case drill and quiz](content/day06.md) | [labs/day06/](labs/day06/) |
| 07 | [Bonds: price, yield, duration, yield curve](content/day07.md) | [labs/day07/](labs/day07/) |
| 08 | [Discounting everything: DCF and equity risk premium](content/day08.md) | [labs/day08/](labs/day08/) |
| 09 | [Market structure: order books and settlement](content/day09.md) | [labs/day09/](labs/day09/) |
| 10 | [Portfolio theory: diversification, Sharpe, frontier](content/day10.md) | [labs/day10/](labs/day10/) |
| 11 | [Business cycle, regimes and "priced in"](content/day11.md) | [labs/day11/](labs/day11/) |
| 12 | [Block 2 integration: Fed-meeting simulation, quiz](content/day12.md) | [labs/day12/](labs/day12/) |
| 13 | [FX mechanics: quotes, forwards, interest parity](content/day13.md) | [labs/day13/](labs/day13/) |
| 14 | [The dollar system: reserve currency, eurodollars](content/day14.md) | [labs/day14/](labs/day14/) |
| 15 | [Impossible trinity, capital controls, currency crises](content/day15.md) | [labs/day15/](labs/day15/) |
| 16 | [Vietnam: SBV tools, VND band, exchanges](content/day16.md) | [labs/day16/](labs/day16/) |
| 17 | [Investing across currencies: VND returns, hedging](content/day17.md) | [labs/day17/](labs/day17/) |
| 18 | [Block 3 integration: cross-currency drill and quiz](content/day18.md) | [labs/day18/](labs/day18/) |
| 19 | [Bitcoin: UTXO, proof of work, halving](content/day19.md) | [labs/day19/](labs/day19/) |
| 20 | [Ethereum: accounts, gas, EVM, proof of stake](content/day20.md) | [labs/day20/](labs/day20/) |
| 21 | [Stablecoins: fiat-backed to algorithmic collapse](content/day21.md) | [labs/day21/](labs/day21/) |
| 22 | [DeFi: AMMs, impermanent loss, liquidations](content/day22.md) | [labs/day22/](labs/day22/) |
| 23 | [Crypto market structure: CEX, perps, basis](content/day23.md) | [labs/day23/](labs/day23/) |
| 24 | [Block 4 integration: crypto vs fiat quiz](content/day24.md) | [labs/day24/](labs/day24/) |
| 25 | [Research workflow and backtest anatomy](content/day25.md) | [labs/day25/](labs/day25/) |
| 26 | [How backtests lie: bias and overfitting](content/day26.md) | [labs/day26/](labs/day26/) |
| 27 | [Costs and risk: slippage, sizing, Kelly](content/day27.md) | [labs/day27/](labs/day27/) |
| 28 | [Strategy families: trend, carry, risk parity](content/day28.md) | [labs/day28/](labs/day28/) |
| 29 | [Paper trading: broker abstraction, kill switch](content/day29.md) | [labs/day29/](labs/day29/) |
| 30 | [Capstone: idea to paper deployment](content/day30.md) | [labs/day30/](labs/day30/) |

## Checking yourself

- `uv run pytest dayNN` runs the tests against your own `labs/dayNN/lab.py`. Starter stubs raise `NotImplementedError`, so a fresh lab fails cleanly.
- `LAB_IMPL=solution uv run pytest dayNN` runs the same tests against the reference `solution.py`. Peeking is allowed after an honest attempt (see `STRATEGY.md`).
- `uv run python tools/check_content.py` validates the content files (structure, exercises with hints and solution sketches, links).

## Data

Lab tests read only frozen snapshots in `labs/data/`: FRED public CSVs, Yahoo Finance prices, Binance public crypto data, Vietnamese stock and index data from the public Vietcap (VCI) chart API, and one recorded Ethereum block. Loaders in `labs/common/` use snapshots by default; pass `live=True` to fetch fresh data into `labs/.cache/` (gitignored, never touches the snapshots). Sources, ranges and units are in [labs/data/MANIFEST.md](labs/data/MANIFEST.md).

## Files

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
│   ├── pyproject.toml     # uv project and dependencies
│   ├── .env.example       # placeholders only
│   ├── .gitignore         # .env, .cache/
│   ├── conftest.py        # LAB_IMPL switch
│   ├── common/            # loaders, quant helpers; backtest/stats/risk added in Block 5
│   ├── tools/             # verify_labs.py, check_content.py
│   ├── data/              # frozen snapshots + snapshot.py + MANIFEST.md
│   └── day01/ … day30/    # README.md, lab.py, test_lab.py, solution.py, SOLUTION.md
└── docs/superpowers/
    ├── specs/             # design spec
    └── plans/
```
