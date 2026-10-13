# Lab 21 — Stablecoins: vault liquidations, the Terra spiral and reserve coverage

**Goal:** compute when a crypto-collateralised stablecoin vault dies, how an algorithmic peg unwinds, and how well a fiat-backed one is covered.   **Time:** ~1.5 h   **Content:** `../../content/day21.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day21 -k "<expression>"`).
4. When all pass: `uv run python -m day21.lab` and inspect the printed summary / `.cache/plots/day21.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Educational, not financial advice.

## Functions to implement (in order)
1. `max_mint` — largest debt a vault can carry. (`-k "cdp_math"`)
2. `liquidation_price` — collateral price at which the vault hits the minimum ratio. (`-k "cdp_math"`)
3. `liquidations` — (step, vault) events along a price path, once per vault. (`-k "liquidations"`)
4. `terra_spiral` — burn UST, mint LUNA, reprice, stop on collapse. (`-k "terra or spiral"`)
5. `reserve_coverage` — reserves over supply, with a guard for zero supply. (`-k "reserve_coverage"`)

## Success signal
`uv run pytest day21` — all 6 tests pass.

## Explore further (optional)
- Change `MIN_RATIO` to 1.3 or 2.0 in `main()` and see how many vaults survive May-June 2022.
- Feed `terra_spiral` a smaller first redemption (0.5%) and find the starting UST/LUNA-cap ratio at which it stops collapsing.
- Load `load_crypto_ohlcv("ETH/USDT")` for 2020-03-01..2020-03-31 and test which vaults at 1.5-2.0x would have been liquidated on Black Thursday.

## Teardown
Nothing billable is created.
