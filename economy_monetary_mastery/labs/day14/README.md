# Lab 14 — The dollar system: event studies and dollar beta

**Goal:** build a small event-study toolkit and use it on the broad dollar around the 2022 Fed hikes, then measure how strongly five emerging-market currencies move with the dollar.   **Time:** ~1.5 h   **Content:** `../../content/day14.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day14 -k "<expression>"`).
4. When all pass: `uv run python -m day14.lab` and inspect the printed summary / `.cache/plots/day14.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `event_window` — cumulative-return window around each event date; skip events that are missing or too close to the data edges. (`-k "event_window or skipped"`)
2. `average_path` — row-wise mean of the window across events. (`-k "average_path"`)
3. `dollar_beta` — slope of each EM FX series on the broad dollar, cov/var with ddof=1. (`-k "dollar_beta"`)

## Success signal
`uv run pytest day14` — all 4 tests pass.

## Explore further (optional)
- Recompute `dollar_beta` for 2022 only and for 2006-2012 only; which currencies change most, and why might the broad-dollar index itself contain the currency you regress (hint: Mexico)?
- Add the three 2023-2024 FOMC dates you choose yourself, then add a "placebo" set of seven random trading days. How different is the placebo average path from the hike path?
- Call `load_fred("DTWEXBGS", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
