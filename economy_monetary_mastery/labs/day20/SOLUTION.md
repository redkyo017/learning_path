# Lab 20 — Solution notes

## hex_to_int
A node returns every quantity as a hex string with a `0x` prefix. `int(h, 16)` accepts the prefix, and "0x0" gives 0. Common mistake: stripping characters by hand or using `int(h)`, which raises. `test_hex_to_int` checks 0x1a and 0x0.

## parse_block
Convert each field with `hex_to_int`; timestamp via `datetime.fromtimestamp(ts, tz=timezone.utc)`; base fee in gwei is wei / 1e9; `tx_count = len(transactions)` (the list holds hashes); utilization = gas_used / gas_limit. Common mistake: a naive `datetime.fromtimestamp(ts)`, which uses the machine's local time zone; the test asserts `tzinfo is not None` and the exact epoch 1,694,498,816. The real-fixture test checks the block number and 0 <= utilization <= 1.

## next_base_fee
Formula with `target = gas_limit // 2`: at target keep the fee; above, `base + max(base*(used-target)//target//8, 1)`; below, `base - base*(target-used)//target//8`. Integer division is what the protocol uses. Common mistake: float math (rounding drift) or applying 12.5% regardless of how far from target the block is. The three parametrized cases (full, empty, exactly at target) pin 1.125e9, 0.875e9 and 1e9.

## tx_fee_eth
`gasUsed * effectiveGasPrice / 1e18`. The effective price already includes the burned base fee and the tip. Common mistake: using the max fee the user offered, which is not in the receipt, or forgetting the wei to ETH division. The test expects 21,000 x 30 gwei = 0.00063 ETH.

## burned_eth
The whole block pays one base fee, so the burn is `baseFeePerGas * gasUsed / 1e18`. Common mistake: using a single transaction's gas, or the gas limit instead of gas used. The test expects 20 gwei x 15M gas = 0.3 ETH.

## priority_fee_eth
The validator keeps what remains after the burn: `gasUsed * (effectiveGasPrice - base_fee) / 1e18`. Common mistake: multiplying the tip by the gas limit, or computing it from the base fee alone. The test (30 - 20 gwei over 21,000 gas) expects 21,000 x 10 gwei. Together with the previous two it also satisfies burn + tip = fee.

## What the output means
The frozen finalized block (26,167,253, 11 October 2026) was 37.7% full against a 60M gas limit, so the rule cuts the next base fee by about 3.1%, to 0.0624 gwei. The block burned 0.001456 ETH, and the sampled contract call paid 0.000027 ETH, all of it base fee: its tip was exactly zero. At this level the burn is a tiny fraction of the roughly 1M ETH a year paid to stakers, so the fee market is not offsetting issuance today. The simulation shows the controller's asymmetry in compounding: 50 full blocks lift 1 gwei to about 361 gwei, while 50 empty blocks bring that back to about 0.5 gwei.
