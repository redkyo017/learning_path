# Lab 05 — Shadow banking and SVB: duration, mark-to-market and drawdowns

**Goal:** turn a rate rise into a dollar loss on a bond book, see how it eats equity, and measure drawdowns.   **Time:** ~1.5 h   **Content:** `../../content/day05.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day05 -k "<expression>"`).
4. When all pass: `uv run python -m day05.lab` and inspect the printed summary / `.cache/plots/day05.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `duration_price_change` — first-order value change from a yield move. (`-k "duration_approximation"`)
2. `convexity_price_change` — adds the second-order convexity term. (`-k "convexity"`)
3. `equity_after_marking` — equity minus unrealized losses. (`-k "equity"`)
4. `drawdown_series` — distance below the running peak. (`-k "drawdowns"`)
5. `max_drawdown` — the worst of those. (`-k "drawdowns or monotonic"`)

## Success signal
`uv run pytest day05` — all 5 tests pass.

## Explore further (optional)
- Run `max_drawdown` on `IEF`, `AGG`, `SPY` and compare with TLT.
- Change the end date of the yield window in `main()` to 2023-03-08 and recompute SVB's implied loss.
- Call `load_fred("DGS10", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
