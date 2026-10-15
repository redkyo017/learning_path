# Day 29 — Paper trading: broker abstraction, kill switch

> Block 5: Quant trading. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

**Not financial advice; paper only in Phase 1.** Nothing in this course recommends a trade, a broker, an exchange or a position size. Phase 1 uses simulated money only: Alpaca paper accounts, the Binance spot testnet and an in-memory fake broker. Whether you may legally hold a given account, and whether trading suits you at all, are your own questions; see the availability facts below and Day 16.

Engineers find the strategy easy and the plumbing deadly. A backtest (Days 25 to 28) is a pure function from prices to a number. A bot is a long-running process that talks to a stranger's API, holds keys that can move money, runs across restarts and time zones, and can lose its whole account while you sleep. The usual failure is not a bad signal but a loop that re-submits an order, a stale price, a leaked key or an unreconciled position. Today you build the part that refuses to do dumb things: target weights turned into capped orders, a kill switch that flattens and stays off, and a log that lets you reconstruct what happened.

## Core concepts

### Bot architecture: one pass through the loop

```
data -> signal -> target -> risk checks -> orders -> reconciliation -> logs
```

- **Data.** Latest price and the history the strategy needs. Fetch once per decision and use that one price everywhere, so the target, the order size and the log agree.
- **Signal.** A pure function `history -> weight`. Today's lab uses a long/flat 50-day momentum rule: weight 1 if the last close is above the close 50 days ago, else 0. The bot treats it as untrusted: the weight is clipped to [0, 1].
- **Target.** Desired position in units: `min(w * equity, max_position_notional) / price`.
- **Risk checks.** Kill file, daily-loss limit, position cap, order cap, minimum order size. These run before the strategy is allowed to matter.
- **Orders.** The difference `target - current position`, clipped to the order cap, as a market order. A market order is a promise to trade at whatever price exists; Day 27 covered what that costs.
- **Reconciliation.** After submitting, ask the broker what you actually own and compare with what the bot believes. Brokers reject, partially fill and delay. The lab's `Bot` reads the position fresh from the broker each step rather than tracking it in a variable, which is the cheap form of reconciliation.
- **Logs.** One JSON line per decision with timestamp, symbol, action, side, quantity, price and equity. Append-only, so a crash cannot damage earlier lines.

### Idempotency and restarts

A bot that targets a **position** is naturally idempotent: run `step` twice with the same inputs and the second pass finds `delta = 0` and holds (the lab's `test_hold_when_at_target`). A bot that sends "buy 10" is not: a retry after a timeout buys 20. Rules that follow:

- Express intent as a target and compute the difference from the broker's current position, never from your own counter.
- After a crash, start by reading broker state (positions, open orders) and the last log line, then decide. Never assume the process stopped cleanly.
- The kill latch is in memory in the lab, so a restart forgets it; a real bot persists it, for example as the kill file.

### Clock and timezone

Three clocks are in play. US equity markets trade 09:30 to 16:00 America/New_York, which is 20:30 to 03:00 Vietnam time (ICT, UTC+7) during US daylight saving time (about March to early November) and 21:30 to 04:00 otherwise. Crypto trades 24/7 on UTC day boundaries for daily candles. Your laptop is on ICT.

- Log in UTC (the lab uses `datetime.now(timezone.utc).isoformat()`) and convert only for display.
- "Daily loss" needs a defined day. In the lab, `new_day()` resets the start-of-day equity; a US-equity bot would call it at the New York open, a crypto bot at 00:00 UTC. Pick one and write it down.
- Do not schedule against ICT clock times. The US/ICT offset changes by one hour twice a year when the US switches daylight saving, while Vietnam does not. Use a market-calendar library or the broker's clock endpoint.

### Why the broker is an interface, and why tests use a fake

The `Broker` Protocol has four methods: `get_price`, `get_position`, `get_equity`, `submit_order`. `FakeBroker` implements them in memory (cash, positions and prices held in dicts); `AlpacaBroker` and `CcxtBroker` implement them over HTTP. Benefits: tests are fast and offline; you can force a price crash to test the kill switch, which no paper account allows; and the code path that decides cannot depend on which venue it is. The cost is optimism: instant fills at the quoted price (see "Limits of paper trading").

### Safety

**Kill switches.** Three layers, cheapest first:

- *Max position / max order.* `max_position_notional` caps exposure; `max_order_notional` caps one order, so a huge jump in target is approached over several steps (`test_order_cap_spreads_over_steps`). A `min_order_notional` stops the bot from churning dust-sized trades.
- *Daily-loss limit.* If equity falls below `day_start_equity * (1 - max_daily_loss)`, flatten and stop. The latch is deliberate: after a kill, a human decides when to restart.
- *Kill file.* Creating a file named `KILL` next to the bot stops it from a second terminal, without signals or code edits.

Kill checks come first in `step`, before the strategy is even called. A safety rule that runs after the signal can be skipped by a signal bug.

**Paper versus live endpoints.** The same library talks to both; only a flag or URL differs. In the given adapters, `CcxtBroker` calls `set_sandbox_mode(True)` immediately on the exchange object, and `AlpacaBroker` builds its client with `paper=True`. Never remove those. The [ccxt manual](https://github.com/ccxt/ccxt/wiki/manual) says sandbox mode applies only where the exchange offers a testnet, that sandbox keys are separate from production keys, and that the call belongs right after creating the exchange object. A paper key on a live endpoint simply fails; a live key on a paper-flag bug trades real money.

**Secrets.**

- Keys live in `labs/.env`, loaded by python-dotenv; `.env` is gitignored and `.env.example` holds placeholders only. Never commit, paste into chat, or print keys in logs.
- Scope: create keys with trade-only permission. A key that can withdraw turns a leaked file into an emptied account. Spot testnet and paper keys have nothing to steal, which is the point of using them first.

**Rate limits.** Brokers throttle requests (and ban abusive clients). A bot that polls price in a tight loop or retries failures without backoff will hit limits and then stall at the worst moment. Poll at the strategy's cadence, and treat HTTP 429 as "slow down", not "retry now".

### Limits of paper trading

- **No market impact.** Simulated orders do not move the price or consume depth; Day 27's slippage does not apply unless you add it.
- **Optimistic fills.** Paper engines usually fill near the quoted price, instantly, in full; real fills cross the spread, queue and sometimes fail.

How long to paper trade before risking money is a Phase 3 criterion in this course, not a number to take from today: run the bot unattended for months, compare logged fills with the prices you would have got, trigger the kill switch on purpose, and write down the failure modes.

### Setting up paper accounts (your own accounts, no keys in this repo)

These steps create *your* accounts. Never share keys; put them only in `labs/.env`.

**Alpaca paper.**

1. Go to [Alpaca's paper trading documentation](https://docs.alpaca.markets/docs/paper-trading) and sign up for a **Paper Only Account** with an email address. That page says anyone globally can create one, free, with a simulated $100,000 balance and no funding. Non-US availability is confirmed for paper-only accounts as of 2026-10; availability of Alpaca live brokerage accounts by country was not retrieved and is unverified as of 2026-10.
2. In the dashboard, open the paper account and generate an API key and secret. The paper endpoint is `https://paper-api.alpaca.markets`.
3. Put them in `labs/.env` as `ALPACA_API_KEY` and `ALPACA_SECRET_KEY`.
4. Adapter check (as of 2026-10): the lab's `AlpacaBroker` uses `TradingClient`, `StockHistoricalDataClient`, `StockLatestTradeRequest`, `MarketOrderRequest`, `OrderSide` and `TimeInForce`; all import cleanly on alpaca-py 0.44.0 (checked 2026-10-11), and the [alpaca-py trading docs](https://alpaca.markets/sdks/python/trading.html) show `TradingClient(..., paper=True)` and `MarketOrderRequest`.

**Binance spot testnet.**

1. Open the [Spot Test Network](https://testnet.binance.vision). Per that site, you log in with a GitHub account, then generate an API key; testnet balances are virtual and cannot be moved in or out.
2. The REST base is `https://testnet.binance.vision/api`. The site states that the testnet is periodically reset to a blank state (reported roughly monthly, with no notice), which erases orders and balances; your keys may need regenerating after a reset.
3. Put the key in `labs/.env` as `BINANCE_TESTNET_API_KEY` and `BINANCE_TESTNET_SECRET`. In ccxt 4.5.x (the version in this lab's environment) `binance` has a testnet URL set that `set_sandbox_mode(True)` switches to (`https://testnet.binance.vision/api/v3` for spot); sandbox keys differ from production keys.
4. **Equity gap (by design).** `CcxtBroker.get_equity` raises `NotImplementedError`, so `Bot(CcxtBroker(...))` fails at construction, before any order: that is the safe failure. (Its message tells you to supply quote balance + position × price yourself.) Note that a testnet account comes with virtual balances, so `get_position` returns the whole base balance and `_flatten` would sell all of it, not just what the bot bought.

**Vietnam note (facts only).** Vietnamese resident individuals have no general channel to hold foreign securities under Decree 135/2015, as Day 16 explains, so opening a *live* US brokerage account may be restricted for you; check the rules and a licensed adviser. Paper accounts hold no real assets and are for learning the mechanics. Binance's own availability for Vietnam residents on live trading is unverified as of 2026-10; the testnet involves no real funds.

The lab's `--venue ccxt|alpaca` option only builds the adapter after loading `.env`. It is optional, runs only after you read the README Safety section, and is not needed for any test.

## Worked example

One replayed stretch of the bot's own log from the lab (BTC/USDT snapshot, start equity 10,000, 15% daily-loss limit, 50-day momentum, `max_position_notional` unlimited, prices in USD). Each line is a day:

```
day  price      momentum  position(BTC)  equity   action
 3   122,232    1         0 -> 0.0818    10,000   order buy 0.0818  (target 1.0 x 10,000 / 122,232)
 4   122,391    1         0.0818         10,013   hold             (target 0.08181 = position)
10   112,774    1         0.0818          9,226   hold             (-7.7% from entry; limit is 15% of day-start equity)
11   110,644    0         0.0818 -> 0     9,052   order sell 0.0818 (weight fell to 0, target 0)
```

Money movement at the fake broker for the day-3 buy (T-account, USD):

```
              FakeBroker (your paper account)
  Assets                         | Liabilities / Equity
  Cash       10,000 -> 0         | Paper equity   10,000
  BTC pos.   0 -> 0.0818 x 122,232 = 10,000
```

At day 10 the position lost value but `new_day()` resets the start-of-day equity each morning, so the 15% limit measures one day's change, not the drawdown since entry. If the price had fallen 20% in one day, `equity < day_start_equity * 0.85` would hold, `_flatten` would sell 0.0818 BTC, the log would record `"action": "killed"` and every later call would return `killed` without orders. The logged JSON for the day-4 hold looks like:

```
{"ts": "2026-10-11T06:57:29.15+00:00", "symbol": "BTC", "action": "hold", "side": null, "qty": 0.0, "price": 122391.0, "equity": 10013.0}
```

The full 365-day replay made 23 orders and 342 holds, ending near 9,874 against 7,051 for buy-and-hold, with no fees or slippage modelled; Day 27 showed that 23 orders (about 11 to 12 round trips) would not be free.

## Exercises

1. A strategy returns a weight of 1.7 on a 10,000 account with a price of 100 and no caps. How many units does the bot hold after one step, and why not 170?
   **Hint:** the clip happens before the target is computed.
   **Solution sketch:** The weight is clipped to 1.0, so the target is 10,000 / 100 = 100 units. A weight above 1 would mean leverage, which the bot refuses by design; the clip makes strategy bugs unable to borrow.

2. With `max_position_notional = 2,000` and a weight of 0.5 on 10,000 at price 100, what is the target? Now add `max_order_notional = 500`: how many steps to reach it?
   **Hint:** target is `min(w * equity, cap) / price`.
   **Solution sketch:** `min(5,000, 2,000) / 100 = 20` units. At 500 notional per order the bot buys 5 units a step, so 4 steps (20 / 5). The test `test_order_cap_spreads_over_steps` uses a different cap and checks the same mechanism.

3. Equity is 10,000 at the start of the day and `max_daily_loss = 0.2`. At what equity is the bot killed? What happens at exactly 8,000?
   **Hint:** the condition is a strict less-than.
   **Solution sketch:** The floor is 10,000 x 0.8 = 8,000. At 7,999 the kill fires; at exactly 8,000 it does not (`equity < floor`). Using `<=` would kill at the floor itself; whichever you choose, pin it with a test.

4. The bot is long 50 units at 100, killed by the daily-loss rule, and the price then recovers 30%. Does the bot trade again? Design the manual restart.
   **Hint:** `killed` is a latch.
   **Solution sketch:** No; every later `step` returns `killed` without orders, which is correct: a recovery is not evidence the problem is fixed. Restart means a human deletes the kill file (if used), builds a fresh `Bot` or calls `new_day()` and clears the flag after reading the log. Document who may do it and when.

5. Your bot crashes between submitting an order and writing the log line. After restart the log shows no order. How does the position-targeting design protect you, and what extra step would you add?
   **Hint:** compare what the broker says with what the log says.
   **Solution sketch:** The bot reads the position from the broker, so the next step computes the correct delta from reality, not from the log. Add a startup reconciliation that lists broker positions and open orders, compares with the last log line and logs any mismatch before trading. Client order IDs would also prevent duplicate submissions on retry.

6. The US market opens at 09:30 New York time. At what Vietnam time is that in mid-July and in mid-December, and why can a fixed ICT cron job go wrong?
   **Hint:** New York is UTC-4 in summer and UTC-5 in winter; ICT is UTC+7 all year.
   **Solution sketch:** July: 13:30 UTC = 20:30 ICT. December: 14:30 UTC = 21:30 ICT. A cron job fixed at 20:30 ICT would run an hour before the open in winter. Schedule against the exchange calendar in New York time, log in UTC.

7. List three ways the FakeBroker fill is more favourable than a real fill, and add one to the fake (a flat 0.1% slippage on every order). Which tests would you change?
   **Hint:** price used, size filled, timing.
   **Solution sketch:** It fills at the quoted price (no spread), in full (no partial fills) and instantly (no latency or rejection). Slippage means `px = price * (1 + 0.001)` on buys and `(1 - 0.001)` on sells. Check which tests still pass, and why: with a zero-slippage default both exact-equity tests (`test_buys_to_target_weight`, the kill-switch test) pass as written, and with non-zero slippage they need a tolerance, which is the argument for making slippage a constructor parameter.

8. (Optional) Run the bot once a day on an Alpaca paper account. Write the script and the kill-switch test.
   **Hint:** the schedule lives outside `step`; use a PAPER key from `labs/.env`, run after the US close.
   **Solution sketch:** build and step the bot once per day (cron or launchd, mind Exercise 6), then `touch KILL` and rerun to confirm it flattens and stays off. Vietnamese residents face limits on foreign securities (Decree 135/2015), so keep it paper-only.

   ```python
   bot = Bot(AlpacaBroker(key, secret), strategy,
             RiskLimits(max_position_notional=1_000, max_order_notional=250, max_daily_loss=0.02),
             Path("log.jsonl"), Path("KILL"))
   print(bot.step("SPY", history))  # daily closes to date; paper key only
   ```

## Anti-patterns / Common mistakes

- **Running untested code against live keys.** First run on the fake, then on paper, with the safety adapters; a typo in order sizing is a free lesson on paper and an expensive one live.
- **Keys with withdrawal permission.** A trading bot needs trade permission only. Withdrawal-enabled keys in a `.env` make a leaked file an emptied account.
- **No reconciliation of actual versus expected positions.** A bot that trusts its own counter diverges from the broker after the first rejection, partial fill or manual trade. Read the broker's position every step and alarm on mismatch.
- **Kill switch that can be bypassed.** A check after the strategy call, or a latch that auto-resets, is a suggestion, not a switch.

## Lab

Open `labs/day29/README.md` (it has a **Safety** section before the steps). Implement `Bot._log`, `Bot._flatten` and `Bot.step`, then run `uv run pytest day29` (14 tests: 11 in `test_lab.py` and 3 in `test_safety.py`; the two adapter tests pass from the start) and `uv run python -m day29.lab`, which replays the BTC snapshot through `FakeBroker` and writes `.cache/plots/day29.png` and `.cache/day29_bot.jsonl`. The `--venue` option is optional and paper/testnet only.

## Teardown

- Stop the bot (Ctrl-C), and create the kill file if any process is still running.
- If you created Alpaca paper or Binance testnet keys: revoke or rotate them in the respective dashboards ([Alpaca](https://docs.alpaca.markets/docs/paper-trading), [Binance testnet](https://testnet.binance.vision)), then delete `labs/.env` if you are done. Testnet balances reset periodically and hold no real value; paper accounts can be deleted in the Alpaca dashboard.
- Delete `.cache/day29_bot.jsonl` and `.cache/day29_KILL` if you no longer need them. Nothing billable remains.

## Journal prompt

Write down the three rules that must be impossible to bypass in your own bot, where each one is enforced (which function, before or after the strategy call), and what a human has to do to restart after each. Then note one thing the fake broker made look easy that you expect to be harder on a paper account.
