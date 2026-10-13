# Solution notes — Lab 17

## home_return
Returns multiply: a gain in the asset is itself converted at the new exchange rate. Formula `(1 + a)(1 + f) - 1`. Common mistake: `a + f`, which gives 0.15 instead of 0.155; `test_home_return_compounds` catches it, and the second assertion (+10% asset, -10% FX = -1%) catches sign errors.

## hedged_return
Covered interest parity makes the forward-to-spot ratio `(1 + r_home t)/(1 + r_foreign t)`; selling the foreign currency forward locks that ratio in, so the currency move drops out. Formula `(1 + a)(1 + r_home t)/(1 + r_foreign t) - 1`. Common mistake: swapping home and foreign rates, which flips the sign of the hedge; `test_hedged_return` uses 5% home and 4% foreign, so the swap fails it.

## vnd_returns
Convert prices, not returns. Reindex the FX series onto the price dates, forward-fill holidays, multiply, `pct_change`, drop the first NaN, and name the result `"vnd_return"`. Common mistake: an inner join drops a priced day, and the return across it is lost; `test_vnd_returns_forward_fills_fx_holidays` expects two returns, the last equal to the plain USD +10% because FX did not change.

## net_return
Fee once, FX spread twice (in and out), all multiplicative: `(1 + g)(1 - fee/1e4)(1 - spread/1e4)^2 - 1`. Common mistake: charging the spread once, or subtracting the costs from the return rather than multiplying; `test_net_return` pins the exact product.

## What the output means
On the snapshot SPY compounds at about 14.1% a year in USD and 16.5% in VND since 2010: the dong depreciated about 2.2% a year and added about 2.5 points. The VN-Index compounds at about 7.7% over the same period but excludes dividends, so the comparison overstates SPY's edge. A +10% gross return nets 8.68% after a 20 bp fee and 50 bp spreads each way, and a hedge with VND at 5.9% and USD at 4.5% would have added about 1.3 points. The currency leg helped here because VND had a steady depreciation trend; that is a regime, not a law.
