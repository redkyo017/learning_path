# Lab 29 — A paper-trading bot with a kill switch

**Goal:** build the risk layer of a trading bot (target weight to capped orders, daily-loss and file kill switches, JSON audit log) behind a `Broker` interface.   **Time:** ~1.5 h   **Content:** `../../content/day29.md`

## Safety (read before anything else)
- Educational material, not financial advice. **Phase 1 is paper and testnet only. No real money, no live keys.**
- `uv run python -m day29.lab` and `uv run python -m day29.solution` with no arguments use `FakeBroker` and the BTC snapshot. They open no network connection and need no keys. All tests are offline.
- `--venue ccxt|alpaca` is the only path that touches a network, and it is **not required for this lab**. Use it only after you have read `content/day29.md` ("Safety"), created your own Alpaca *paper* account or Binance *spot testnet* account, and put the keys in `labs/.env` (copy `.env.example`). `.env` is gitignored; never commit it, never paste keys into chat, issues or screenshots.
- `CcxtBroker.get_equity` raises `NotImplementedError` on purpose; the bot cannot be built on it until you supply equity yourself (see Explore further).
- The adapters force the safe mode: `CcxtBroker` calls `set_sandbox_mode(True)` and `AlpacaBroker` builds its client with `paper=True`. Do not remove either line. Test keys with trade-only scope; never a key with withdrawal permission.
- Availability depends on where you live and on local law; the content file states the facts as of 2026-10. Paper accounts are for learning, not for deploying capital.

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO methods in the order listed below.
3. After each one, run its tests with the `-k` expression listed below (`uv run pytest day29 -k "<expression>"`).
4. When all pass: `uv run python -m day29.lab` and inspect the printed summary / `.cache/plots/day29.png` and `.cache/day29_bot.jsonl`.

Run every command from the `labs/` folder. Failing tests at the start are expected, except the two adapter tests, which pass because the adapters are given code. Every `step` call logs, so `_log` must work before any `step` test can pass.

## Functions to implement (in order)
1. `Bot._log` — append the record plus an ISO `ts` as one JSON line. (`-k "log_lines"` needs `step` too; implement `step` next)
2. `Bot._flatten` — sell the whole position if there is one. (`-k "kill"`)
3. `Bot.step` — kill checks, clipped weight, capped target, capped order, log. (`-k "buys or clipped or position_cap or order_cap or hold or sells or failed_flatten or non_finite"`)

Given (do not change): `FakeBroker`, `CcxtBroker`, `AlpacaBroker`, `RiskLimits`, `Bot.__init__`, `Bot.new_day`, `main()`.

## Success signal
`uv run pytest day29` — all 14 tests pass (9 in `test_lab.py` for the bot, 2 for the adapters, 3 extra safety tests in `test_safety.py`).

## Explore further (optional)
- `CcxtBroker.get_equity` raises by design, so `Bot(CcxtBroker(...))` fails safe at construction. To wire it you must write an equity function (quote balance + base balance x price). A testnet account has virtual balances, so `get_position` returns the whole base balance and `_flatten` would sell all of it.
- Add a `max_orders_per_day` limit and a test for it.
- Make the kill latch survive restarts: write the `killed` state to disk and read it in `__init__`.
- Swap `momentum_weight` for a 100-day trend and compare the replay log.

## Teardown
Nothing billable is created by the offline lab. If you used `--venue`: stop the bot, revoke/rotate the paper and testnet keys in the Alpaca and Binance testnet dashboards, and delete `labs/.env` if you are done.

Educational material, not financial advice.
