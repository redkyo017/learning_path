# Lab 30 — Capstone: idea to paper deployment

**Goal:** implement the six-rule kill checklist and the capstone pipeline, run it on SPY and BTC-USD, then take one idea of your own through `CAPSTONE.md`.   **Time:** ~1.5 h   **Content:** `../../content/day30.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day30 -k "<expression>"`).
4. When all pass: `uv run python -m day30.lab` and inspect the printed summary / `.cache/plots/day30.png`.
5. Copy `CAPSTONE.md` (keep the original as the template), paste the report into its Report section, and complete the other sections for your own idea.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. `run_capstone` takes an optional `periods_per_year` (252 for equities, 365 for native daily crypto), which `main()` sets per asset. Educational code, not financial advice.

## Functions to implement (in order)
1. `kill_checklist` — names of the failed rules, in a fixed order; `ValueError` listing missing keys. (`-k "good or each_rule or missing"`)
2. `verdict` — `"paper-trade"` when the checklist is empty, else `"kill"`. (`-k "good or each_rule"`)
3. `run_capstone` — in-sample lookback search, costed full run, out-of-sample slices, deflated Sharpe. (`-k "run_capstone"`)

## Success signal
`uv run pytest day30` — all 9 tests pass.

## Explore further (optional)
- Add a third asset (ETH-USD, or `VNM` for a shorter history) and compare verdicts. Count it as a new trial in your log.
- Change `split` from 0.6 to 0.5 and 0.7 and see which rules flip; a verdict that depends on the cut is fragile.
- Run with `cost_bps` of 0, 10 and 25 and watch `net_sharpe` move while `breakeven_cost_bps` does not.

## Teardown
Nothing billable is created. If you set up Alpaca paper or Binance testnet keys on Day 29 and are not continuing, revoke them in the dashboards and delete `labs/.env`; then archive your `journal.md` (copy it with the date in the file name).
