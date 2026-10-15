# Lab 26 — How backtests lie

**Goal:** quantify selection bias with PSR/DSR, reproduce p-hacking on pure noise, and build a leak-free walk-forward test.   **Time:** ~1.5 h   **Content:** `../../content/day26.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day26 -k "<expression>"`).
4. When all pass: `uv run python -m day26.lab` and inspect the printed summary / `.cache/plots/day26.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. The first three functions are also published as `common/stats.py` (Day 30 imports them); `uv run pytest common/tests/test_stats.py` checks that copy. All Sharpe inputs to PSR/DSR are per-period, not annualized. Educational code, not financial advice.

## Functions to implement (in order)
1. `probabilistic_sharpe_ratio` — probability the true Sharpe beats a benchmark, given sample length, skew and kurtosis. (`-k "psr"`)
2. `expected_max_sharpe` — the Sharpe you expect from the luckiest of N skill-less trials. (`-k "expected_max"`)
3. `deflated_sharpe_ratio` — PSR measured against that luck benchmark. (`-k "dsr"`)
4. `p_hacking_demo` — search noise, pick the best column, re-test it on the second half. (`-k "p_hacking"`)
5. `walk_forward` — pick the lookback on each training window, trade it on the next block. (`-k "walk_forward"`; also needs `momentum_signal` and `backtest` from `common.backtest`, already imported)

## Success signal
`uv run pytest day26` — all 6 tests pass.

## Explore further (optional)
- Run `p_hacking_demo` for seeds 0 to 20 and plot out-of-sample Sharpe against in-sample Sharpe; the cloud should centre on zero.
- Add BTC-USD to `main()` and compare its DSR with SPY's.
- Make `walk_forward` leak on purpose (choose using `prices.iloc[i-train:i+test]`) and watch the OOS Sharpe on SPY rise from 0.76 to about 1.06. The given leakage test does not catch this; write a stronger one (see Exercise 5).

## Teardown
Nothing billable is created.
