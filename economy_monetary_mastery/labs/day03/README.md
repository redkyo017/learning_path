# Lab 03 — Central banks: the rate corridor, QE and the H.4.1 series

**Goal:** model how reserve scarcity moves the overnight rate, post the T-accounts of QE, and align Fed balance-sheet data weekly.   **Time:** ~1.5 h   **Content:** `../../content/day03.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day03 -k "<expression>"`).
4. When all pass: `uv run python -m day03.lab` and inspect the printed summary / `.cache/plots/day03.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `overnight_rate` — flat at IORB when reserves are ample, climbing linearly to the ceiling as reserves fall to zero. (`-k "floor or scarce or never or negative"`)
2. `qe_postings` — the T-account changes of a QE purchase from a nonbank vs from a bank. (`-k "qe or entity or unknown"`)
3. `align_weekly` — put daily, weekly and monthly series on one Wednesday grid. (`-k "align"`)

## Success signal
`uv run pytest day03` — all 10 tests pass (9 test functions, one parametrized twice).

## Explore further (optional)
- Add a `satiation` fit: find the value that makes `overnight_rate` match DFF in Sept 2019 and discuss why it is only illustrative.
- Plot reserves divided by WALCL to see how much of the balance sheet is "reserves" vs other liabilities.
- Call `load_fred("WALCL", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
