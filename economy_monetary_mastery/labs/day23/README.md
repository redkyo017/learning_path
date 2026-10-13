# Lab 23 — Funding, basis and the cash-and-carry trade

**Goal:** annualize perpetual funding and futures basis, and compute the profit of a hedged cash-and-carry.   **Time:** ~1.5 h   **Content:** `../../content/day23.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day23 -k "<expression>"`).
4. When all pass: `uv run python -m day23.lab` and inspect the printed summary / `.cache/plots/day23.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Rates are fractions per funding period (0.0001 = 0.01%). Educational code, not financial advice.

## Functions to implement (in order)
1. `annualized_funding` — mean funding rate x periods per day x 365. (`-k "annualized_funding or snapshot"`; the snapshot test also runs it on real BTC data)
2. `basis_pct` and `annualized_basis` — (F-S)/S and its annualization; `ValueError` for days <= 0. (`-k "test_basis"`; both are asserted in that one test)
3. `cash_and_carry_pnl` — long spot, short future profit. (`-k "cash_and_carry"`)
4. `funding_pnl` — funding cash flow for a short or long perp; `ValueError` for another side. (`-k "funding_pnl"`)

## Success signal
`uv run pytest day23` — all 5 tests pass.

## Explore further (optional)
- Split the carry in `main()` by year and see which years paid for the risk.
- Subtract a 0.04% taker fee on entry and exit for each leg and see what that costs over one year of holding.
- Refresh the snapshot with `live=True` (public endpoints only) and compare the latest funding with the snapshot.

## Teardown
Nothing billable is created.
