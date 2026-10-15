# Solution notes — Lab 22

## ConstantProductPool.price / k
**Idea:** the pool's marginal price of X in Y is the ratio of reserves; k is their product. **Formula:** `price = y/x`, `k = x*y`. **Common mistake:** returning x/y (inverted price). `test_swap_no_fee` asserts a price of 100 for 100 X and 10,000 Y.

## swap_x_for_y / swap_y_for_x
**Idea:** the trader's input after the fee, `eff = dx*(1-fee)`, is what gets priced so that `(x+eff)*(y-dy) = x*y`, giving `dy = y*eff/(x+eff)`. The full `dx` (fee included) is added to the reserves, so k rises by the fee. **Formula:** `dy = y*dx*(1-f)/(x+dx*(1-f))`. **Common mistake:** adding only `eff` to the reserve, which silently pays the fee to nobody and keeps k flat; `test_fee_grows_k_and_reverse_swap` requires k to grow. Another is forgetting the `ValueError` for non-positive input (`test_invalid_swaps`). The y->x swap is the mirror image.

## impermanent_loss
**Idea:** with the starting price normalised to 1 and one unit of X, the LP is worth `2*sqrt(r)` after the price moves to r while holding is worth `1+r`. **Formula:** `IL = 2*sqrt(r)/(1+r) - 1`. Symmetric in r and 1/r. **Common mistake:** returning a positive number or using r instead of sqrt(r); the parametrized test expects -0.2 for r=4 and r=0.25.

## lp_vs_hold
**Idea:** arbitrage keeps the pool at the market price with k unchanged, so the reserves become `x1 = sqrt(k/p)`, `y1 = sqrt(k*p)`; LP value is `x1*p + y1` while holding is `x0*p + y0`. **Common mistake:** valuing the LP at the old reserves. The test (400 vs initial price 100) expects LP 40,000 and hold 50,000.

## sandwich
**Idea:** run two fresh pools. Baseline: only the victim swaps. Attack: the attacker sells X first (lowering the price of X), the victim sells at the worse price, then the attacker sells the Y back for X. Profit in X is `back_x - attacker_dx`. **Common mistake:** reusing one pool for baseline and attack, which contaminates the comparison. With no fee the attacker profits and the victim gets less; with a 0.3% fee and a 0.01 X victim the two fees exceed the tiny price move and the profit is negative; the two sandwich tests pin both cases.

## What the output means
On the 2021-01-01 to 2026-09-30 Binance snapshot ETH rose from about 729 to 2,686 USDT (ratio about 3.68). A fee-free 50/50 LP ends about 18% below simply holding the starting ETH and USDT, matching the closed form. Spread over about 5.7 years that is roughly 3% of position value per year in fees that the pool would have to earn just to break even (a simple, non-compounded estimate; it divides the end-point IL evenly over time and ignores fee compounding and the actual path of volume). Real pools earned fees on top, so the verdict depends on volume per unit of liquidity, which this lab does not have. The sandwich line shows that a single large swap in a thin pool hands a bot several ETH.
