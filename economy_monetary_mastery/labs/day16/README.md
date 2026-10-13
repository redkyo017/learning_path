# Lab 16 — Vietnam: the SBV band, exchange price limits and foreign room

**Goal:** compute the ±5% USD/VND band, the daily floor and ceiling of a Vietnamese stock under tick rounding, flag limit-locked days, and measure foreign-ownership room.   **Time:** ~1.5 h   **Content:** `../../content/day16.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day16 -k "<expression>"`).
4. When all pass: `uv run python -m day16.lab` and inspect the printed summary / `.cache/plots/day16.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Two data caveats apply to `main()`: Vietcap stock closes are dividend/split-adjusted, so limit-hit detection on them is approximate, and the SBV central-rate history is not in the snapshot, so the band demo uses a labelled 60-day rolling-mean proxy.

## Functions to implement (in order)
1. `sbv_band` — `(central*(1-band), central*(1+band))`. (`-k "sbv_band"`)
2. `within_band` — True where the market rate is inside the band around the central rate. (`-k "within_band"`)
3. `hose_tick` — HOSE tick size bracket for a price. (`-k "hose_tick"`)
4. `price_limits` — `(floor, ceiling)` with tick rounding for HOSE, HNX, UPCOM; unknown exchange raises `ValueError`. (`-k "price_limits or unknown_exchange"`)
5. `flag_limit_moves` — True on days the close equals the floor or ceiling implied by the previous close. (`-k "flag_limit"`)
6. `foreign_room` — shares still available to foreigners, never negative. (`-k "foreign_room"`)

## Success signal
`uv run pytest day16` — all 13 tests pass (6 functions, some parametrized).

## Explore further (optional)
- Swap the 60-day proxy in `main()` for a 20-day or 120-day mean and see how often USD/VND leaves the band; then explain why a proxy built from the market itself can never show a true breach.
- Add a stock you hold to `main()` and count days with a move of at least 6.5% against the exact-limit count.
- Call `load_vn("FPT", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.

Educational material, not financial advice.
