# Solution notes — Lab 15

## trinity_violation
The trinity says a country can have at most two of: fixed exchange rate, free capital flows, independent monetary policy. The test is therefore true only when all three flags are true: `all((fixed_fx, open_capital, independent_policy))`. Common mistake: returning `any` or counting "at least two"; the test enumerates all eight combinations and catches it.

## defend_peg
Walk the outflows with a 1-indexed counter. If `reserves - out < floor`, return `(step, path)` without recording the failing step; otherwise subtract, append, continue. Return `(None, path)` if the loop ends. Formula: `reserves_k = reserves_{k-1} - out_k`. Common mistakes: 0-indexed steps, recording the breaking step in the path, or using `<=` (reserves exactly at the floor still hold). Tests: the 3-step break expects `(3, [70, 40])`; the inflow test checks that negative outflows add reserves.

## rate_to_defend
Uncovered interest parity: to hold the currency, the domestic rate must offset expected depreciation, `(1 + r_foreign)(1 + d) - 1`. Common mistake: the additive shortcut `r_foreign + d` (0.25 instead of 0.26). The test uses `approx(0.26)`, so the additive version fails.

## import_cover_months
`reserves / monthly_imports`, raising `ValueError` when imports are zero or negative. Common mistake: letting `ZeroDivisionError` escape or returning infinity; the test requires `ValueError`.

## What the output means
In the stylized scenarios, Thailand-style reserves break at step 5 and Argentina-style at step 6, while the Turkey-style path holds because an early inflow and a larger cushion above the floor absorb the outflows. The rates needed to hold the pegs (36.5%, 57.5%, 31.2%) are far above the foreign 5%: that is the price of credibility when depreciation is expected, and in practice such rates damage banks and public finances, which is why they are often not credible. Import cover looks comfortable (7.6, 5.0, 3.0 months) in two cases even though the peg breaks, because cover measures import financing, not the stock of short-term claims that can flee. The numbers are stylized, not historical data.
