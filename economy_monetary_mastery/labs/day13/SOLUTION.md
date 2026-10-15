# Lab 13 — Solution notes

## forward_rate
Lend 1 base unit at r_base for t, or convert it to S quote units and lend those at r_quote for t; if both end in the same place there is no arbitrage, so the forward converts the two maturity values into each other. Formula: `S * (1 + r_quote*t) / (1 + r_base*t)`. Common mistake: swapping the two rates (a quote-direction error) or dividing by `r_base` without the 1. The first test uses r_quote > r_base and the 3-month case `1.0125/1.01`, which fail on a swap. `t <= 0` must raise `ValueError`, which `test_bad_time` checks with `t = -1`.

## forward_points
Points are `forward - spot`, in quote units. A higher quote rate gives a positive number: the base currency trades at a forward premium. Common mistake: subtracting in the wrong order. `test_forward_points_sign` has one positive and one negative case.

## cip_deviation_bp
Compare the quoted forward with the fair one as a ratio and scale to basis points: `(forward / fair - 1) * 10,000`. Common mistake: dividing by spot (which mixes the interest differential into the deviation) or forgetting the factor 10,000. The test passes the fair forward (expects 0) and 0.1% above it (expects 10.0).

## carry_trade_return
Borrow 1 funding unit (owe `1 + r_fund*t`), convert to `S0` investment units, earn `1 + r_invest*t`, convert back at `S1`. Formula: `S0*(1 + r_invest*t)/S1 - (1 + r_fund*t)`. Common mistake: using `S1/S0`, which is the wrong direction when spot is quoted as investment-currency per funding-currency. The depreciation case (25,000 to 26,250) gives `25000*1.05/26250 = 1.00`, so the result is `1.00 - 1.04 = -0.04`; a flipped ratio gives a different number and fails.

## fx_return
`spot_end / spot_start - 1`: holding the base currency gains when its price in quote units rises. Common mistake: returning the quote currency's return (`start/end - 1`). The test expects +5% for 25,000 to 26,250.

## What the output means
On the snapshot, spot is 25,969 VND per USD (2026-09-29). With VND at 5.9% and USD at 4.5% the 1-year CIP forward is about 26,317, +348 points or +1.34%. That is not a forecast; it is the price that removes arbitrage. Realized one-year moves since 2015 averaged +1.78% but ranged from -3.7% to +9.8%, so a borrow-USD / hold-VND carry would have had a mean of about -0.4% at today's rates and lost in 55% of windows, with a worst case near -8%. On average the realized depreciation is close to the forward premium (roughly UIP on average), but the dispersion is large, so the forward is a poor point forecast. The negative mean carry reflects a managed, steadily depreciating VND, and carry in a currency with a policy-set band behaves more like a short option on an administrative decision than a free yield. The history applies today's rate gap to 2015-2026, when actual gaps differed, so it is illustrative only.
