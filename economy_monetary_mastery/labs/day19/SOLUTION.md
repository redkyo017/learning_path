# Solution notes — Day 19

## `block_subsidy`
Bitcoin Core computes the subsidy as `50 BTC >> (height // 210_000)`: a right shift is an exact integer halving in satoshis, so rounding down happens automatically (the 33rd shift reaches 0 satoshis). Formula: `subsidy = (50 * 10**8) >> era`, with 0 for `era >= 64`. Common mistake: using floats (`50 / 2**era`), which breaks the exact cap. `test_subsidy_schedule` checks 840,000 gives exactly 312,500,000 satoshis and era 64 gives 0.

## `total_supply`
Sum the complete eras (`210_000 * subsidy(era)`, at most 64 terms) and add `remainder * subsidy(current era)`. Formula: `S(h) = sum_{e < h//210000} 210000 * (50e8 >> e) + (h % 210000) * (50e8 >> (h//210000))`. Clamp `h` at `64 * 210_000` first. Common mistake: looping over every height, which is fine at 840,000 and hopeless at `10**8`; or an off-by-one that includes block `height`. `test_supply_cap` calls it with `10**8` and expects exactly 2,099,999,997,690,000 satoshis, which is slightly under 21,000,000 BTC because of integer rounding.

## `mine`
Try nonces 0, 1, 2, ... hashing `f"{header}{nonce}"` until the hex digest starts with `"0" * difficulty`. Each extra hex zero multiplies expected work by 16. Common mistake: hashing the nonce as bytes or starting from 1, so the digest no longer equals what the test recomputes.

## `Chain.add_block`
Two phases. Phase 1 validates every transaction against the current `utxos` with a block-local `spent` set: it needs at least one input, every input must exist and not be in `spent`, outputs must be non-negative, and the sum of inputs must be at least the sum of outputs; the surplus is the fee. Because validation reads only the pre-block UTXO set, spending an output created in the same block fails automatically. Nothing is mutated until phase 1 passes. Phase 2 builds the coinbase `Tx(inputs=(("coinbase", height),), outputs=(TxOut(miner, subsidy + fees),))` first, deletes spent outpoints, adds new `(txid, i)` outputs, builds `header = f"{height}|{prev_hash}|{','.join(txids)}"`, mines it, and appends the block dict. Common mistake: deleting UTXOs while still validating, which leaves a half-applied state when the second transaction fails. `test_double_spend_across_blocks_rejected_atomically` and `test_double_spend_within_block_rejected` check that the chain length and balances are unchanged after the error.

## `Chain.balance`
Sum `amount` over UTXOs whose `address` matches. A "balance" is not stored anywhere: it is a query over unspent outputs. `test_spend_with_fee_and_linking` expects the miner at 51 BTC (50 subsidy + 1 fee) and alice at 39 BTC (the change output).

## What the output means
The schedule shows 50% of all coins issued by block 210,000 and 93.75% by the end of era 3 (the April 2024 halving started era 4 at 3.125 BTC) and 96.875% by the end of era 4; the cap is 2,099,999,997,690,000 satoshis, about 20,999,999.9769 BTC. Mining time grows by roughly 16x per difficulty step, but on this machine difficulty 5 still takes well under a second, which is why real Bitcoin needs about 10^21 hashes per second rather than a Python loop. The toy chain ends with alice 39, bob 10, miner 51. The total is 100 BTC, matching two 50 BTC subsidies (the 1 BTC fee moved from alice to the miner but created nothing).
