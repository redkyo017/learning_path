# Lab 15 — Impossible trinity, capital controls, currency crises

**Goal:** encode the trinity, simulate reserves running down under a peg, and price the interest rate needed to hold it.   **Time:** ~1.5 h   **Content:** `../../content/day15.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day15 -k "<expression>"`).
4. When all pass: `uv run python -m day15.lab` and inspect the printed summary / `.cache/plots/day15.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Scenario numbers in `main()` are stylized, not historical data.

## Functions to implement (in order)
1. `trinity_violation` — true only when a regime claims fixed FX, open capital and independent policy together. (`-k "trinity"`)
2. `defend_peg` — spend reserves per period; return the 1-indexed break step (or None) and the reserve path before the break. (`-k "peg or inflows"`)
3. `rate_to_defend` — compounded UIP rate that offsets expected depreciation. (`-k "rate_to_defend"`)
4. `import_cover_months` — reserves divided by monthly imports; reject non-positive imports. (`-k "import_cover"`)

## Success signal
`uv run pytest day15` — all 6 tests pass.

## Explore further (optional)
- Add a fourth scenario with large short-term external debt: raise `floor` to the debt due within a year and watch the break step move earlier (the Greenspan–Guidotti idea).
- Make outflows grow when the policy rate is raised (a flight-from-the-currency effect) and see when "defend with rates" backfires.
- Plot import cover per scenario against the 3-month rule of thumb.

## Teardown
Nothing billable is created.
