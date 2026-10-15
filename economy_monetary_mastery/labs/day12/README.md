# Lab 12 — The meeting-day tape (Block 2 integration)

**Goal:** turn a fed funds futures price into market-implied odds for an FOMC decision, then into a surprise and an expected asset move.   **Time:** ~1.5 h   **Content:** `../../content/day12.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day12 -k "<expression>"`).
4. When all pass: `uv run python -m day12.lab` and inspect the printed summary / `.cache/plots/day12.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list.

## Functions to implement (in order)
1. `implied_rate` — the month's average expected rate is 100 minus the futures price. (`-k "test_implied_rate"`)
2. `meeting_adjusted_implied` — back the post-meeting rate out of the day-weighted month average; reject a meeting day outside the month. (`-k "meeting_adjustment or bounds"`)
3. `move_probability` — signed odds of a one-step move, clipped to [-1, 1]. (`-k "move_probability"`)
4. `surprise_bp` — actual move minus expected move, in basis points. (`-k "surprise"`)
5. `asset_reaction_pct` — surprise times sensitivity. (`-k "reaction"`)

## Success signal
`uv run pytest day12` — all 6 tests pass.

## Explore further (optional)
- Change `meeting_day` in the "Priced-in cut" scenario to 30 and watch how fragile the implied odds become when only one or two days of the month follow the meeting.
- Replace the hypothetical sensitivities with your own estimates: regress daily SPY returns on the change in DGS2 on FOMC days (dates from the Fed calendar).
- Call `load_fred("DGS2", live=True)` for newer data (writes to `.cache/` only).

## Teardown
Nothing billable is created.
