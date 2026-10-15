# Solution notes — Day 02

## `Bank.lend`
Key idea: a loan is a new asset and a new liability created together: `loans += amount`, `deposits += amount`. Reserves and equity do not move, which is the whole point against the money-multiplier story.
Formula: `loans' = loans + a`, `deposits' = deposits + a`.
Common mistake: also subtracting `amount` from reserves (the "lend out the reserves" picture). `test_lending_creates_deposits_without_using_reserves` checks reserves stay at 10.

## `capital_ratio` and `liquidity_ratio`
Key idea: two one-liners that measure different things: loss-absorbing buffer against the loan book, and immediately payable cash against deposits.
Formula: `equity / loans`; `reserves / deposits`.
Common mistake: dividing equity by deposits or total assets. `test_ratios` expects 10/90 for both on the textbook bank (they coincide there, so check the denominators carefully).

## `bank_run`
Key idea: work on a deepcopy. For each wave, `need = frac * deposits`. Pay `min(need, reserves)` from reserves. Any shortfall is raised by selling loans of book value `x = shortfall / (1 - h)`, which yields `x(1-h)` cash and loses `x*h` of equity. If `x` exceeds the loans held, sell them all and leave the unpaid remainder in deposits. Then `deposits -= paid`. Status is "insolvent" if equity <= 0 or the shortfall went unpaid; stop at the first such state.
Formula: `x = (need - reserves)/(1-h)`, `equity -= x*h`, `deposits -= paid` (equal to `need` unless loans ran out).
Common mistake: selling `shortfall` of loans at book (forgetting the haircut gross-up), or subtracting the loss from deposits instead of equity. `test_large_run_forces_fire_sale_and_stops_at_insolvency` expects loans 40, deposits 45, equity -5; `test_identity_holds_every_step_and_input_not_mutated` catches a wrong side and also mutation of the input.

## `simple_returns` and `log_returns`
Key idea: `pct_change().dropna()` and `np.log(p / p.shift(1)).dropna()`.
Formula: `p_t/p_{t-1} - 1`; `ln(p_t/p_{t-1})`.
Common mistake: forgetting `dropna()` (a leading NaN), or taking `np.log(p.pct_change())`. `test_returns` checks the values and that log returns sum to `ln(0.99)`.

## What the output means
For the textbook bank, a 50% run is survived at a 10% haircut (the bank takes two waves and ends with equity 3.6) but not at 30% (insolvent in the first wave, equity -5) or 50% (equity -25). The exact tipping point for a single 50% wave is a 22.2% haircut. For SPY, the mean daily simple return (about 0.048%) is higher than the mean log return (about 0.041%) by roughly half the daily variance, yet compounding the simple returns and exponentiating the summed log returns give the same total growth (about 844% on the snapshot, adjusted close, to 2026-09-29): the two views agree on wealth and differ only in how they average.
