# Lab 22 — A constant-product AMM, impermanent loss and a sandwich attack

**Goal:** build an x*y=k pool, measure impermanent loss against holding, and quantify what a sandwich bot extracts.   **Time:** ~1.5 h   **Content:** `../../content/day22.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day22 -k "<expression>"`).
4. When all pass: `uv run python -m day22.lab` and inspect the printed summary / `.cache/plots/day22.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Price is always Y per X; the pool keeps the swap fee inside its reserves. Educational code, not financial advice.

## Functions to implement (in order)
1. `ConstantProductPool.price` and `.k` — marginal price y/x and the invariant x*y. (`-k "swap_no_fee"`; both are asserted at the start of that test, which needs the swap too)
2. `ConstantProductPool.swap_x_for_y` — sell X, receive Y; fee stays in the pool. (`-k "swap_no_fee or fee_grows or invalid"`)
3. `ConstantProductPool.swap_y_for_x` — the mirror swap. (`-k "fee_grows or invalid"`)
4. `impermanent_loss` — fractional loss of an LP versus holding for a price ratio. (`-k "impermanent_loss"`)
5. `lp_vs_hold` — fee-free LP and hold values after a price move. (`-k "lp_vs_hold"`)
6. `sandwich` — attacker profit and victim shortfall. (`-k "sandwich"`)

`price` and `k` have no test of their own: `test_swap_no_fee` fails until `price`, `k` and `swap_x_for_y` are all done.

## Success signal
`uv run pytest day22` — all 9 tests pass (3 parametrized impermanent-loss cases).

## Explore further (optional)
- Plot impermanent loss against price ratio from 0.1 to 10 and mark where fees of 0.3% on a given daily volume would offset it.
- Find the smallest `victim_dx` at which a sandwich with `attacker_dx=5` turns profitable at a 0.3% fee.
- Change `main()` to start the LP at a later date and see how IL depends on the start price.

## Teardown
Nothing billable is created.
