# Solution notes — Day 21

## `max_mint(collateral_value, min_ratio)`
Key idea: a vault must keep collateral value at least `min_ratio` times debt, so the largest debt is `collateral_value / min_ratio`. Formula: `debt_max = value / ratio`. Common mistake: multiplying instead of dividing (150 x 1.5 = 225). `test_cdp_math` checks 150 at 1.5 gives 100.

## `liquidation_price(collateral_amount, debt, min_ratio)`
Key idea: solve `amount * P / debt = min_ratio` for the price. Formula: `P = debt * min_ratio / amount`. Common mistake: forgetting the ratio and returning `debt / amount` (the break-even price, not the liquidation price). `test_cdp_math` checks 1 unit backing 1,000 at 1.5 gives 1,500.

## `liquidations(vaults, prices, min_ratio)`
Key idea: walk the price path with steps in the outer loop and vaults in the inner loop, so output is naturally ordered by step then vault index. Record a vault when `amount * price / debt < min_ratio` (strict) and add it to a done set so it is reported once. Skip vaults with `debt <= 0` to avoid division by zero. Common mistake: reporting every low-price step, or looping vaults in the outer loop and returning events in the wrong order. `test_liquidations_each_vault_once` has a price path that stays low after the first liquidation.

## `terra_spiral(ust_supply, luna_supply, luna_price, redemption_fracs)`
Key idea: each step burns `R = frac * ust` UST and mints R dollars of LUNA at the old price. Market cap after is `price * luna - R`. If that is <= 0, record `collapsed` with price 0 and stop; otherwise `minted = R / price`, `luna += minted`, `price = mcap_after / luna`, `ust -= R`. Common mistake: dividing the old market cap by the new supply (which ignores the redeemed dollars) or minting at the new price. `test_terra_step` pins the 450/11 price; `test_terra_collapse_stops` pins the stop; `test_spiral_accelerates` checks prices fall.

## `reserve_coverage(reserves, supply)`
Key idea: coverage is `reserves / supply`; below 1.0 someone takes a loss. Raise `ValueError` for non-positive supply rather than returning infinity. Common mistake: dividing before the guard. `test_reserve_coverage` checks 0.98 and the error.

## What the output means
On the snapshot ETH/USDT path (2,825 on 1 May 2022 to 1,060 on 1 July, with a low of 995 on 18 June), all six sample vaults are liquidated: those opened at 1.6x to 2.0x go in the first two weeks, 2.5x and 3.0x in June, and the 4.0x vault only at the 18 June low. Overcollateralisation buys time, not safety. The stylised Terra spiral starts deliberately past the tipping point (UST $18bn above LUNA's $17bn cap) to compress the dynamics; before the real collapse LUNA's cap was roughly 1.5-2x UST (unverified). After twelve redemption steps the price is a few cents and step 13 collapses. This shows mechanics, not a replay: a peg backed only by its sister token is fragile once redemptions approach that token's market cap, and the model understates real losses because panic also sold LUNA directly. The fiat-backed contrast, coverage 0.98, shows the third failure mode: a small reserve gap triggers a run because the first redeemers are paid in full.
