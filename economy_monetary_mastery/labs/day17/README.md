# Lab 17 — Investing across currencies: VND returns, hedging and costs

**Goal:** restate a USD asset in VND, price what a forward hedge adds, and subtract round-trip costs.   **Time:** ~1.5 h   **Content:** `../../content/day17.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day17 -k "<expression>"`).
4. When all pass: `uv run python -m day17.lab` and inspect the printed summary / `.cache/plots/day17.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Convention: returns are decimals; `fx_ret` is the foreign currency's change in home-currency terms; `VND=X` is VND per USD.

## Functions to implement (in order)
1. `home_return` — (1 + asset)(1 + fx) - 1. (`-k "home_return"`)
2. `hedged_return` — asset return with the forward premium locked in. (`-k "hedged_return"`)
3. `vnd_returns` — daily returns of a USD series priced in VND, FX forward-filled on holidays. (`-k "vnd_returns"`)
4. `net_return` — gross return after one fee and two FX spreads. (`-k "net_return"`)

## Success signal
`uv run pytest day17` — all 5 tests pass.

## Explore further (optional)
- Change `FEE_BPS` and `FX_SPREAD_BPS` in `lab.py` and find the gross return at which net return is zero.
- Add `TLT` to `main()` and compare how much of its VND return comes from the currency leg.
- Call `load_prices(["VND=X"], live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
