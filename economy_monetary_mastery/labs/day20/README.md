# Lab 20 — Ethereum: decoding a block and the EIP-1559 fee split

**Goal:** turn raw JSON-RPC hex into numbers, apply the EIP-1559 base-fee rule, and split a transaction fee into burn and tip.   **Time:** ~1.5 h   **Content:** `../../content/day20.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day20 -k "<expression>"`).
4. When all pass: `uv run python -m day20.lab` and inspect the printed summary / `.cache/plots/day20.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. All amounts are wei internally (1 ETH = 1e18 wei, 1 gwei = 1e9 wei); `main()` reads the frozen files `data/eth/block.json` and `data/eth/receipt.json`.

## Functions to implement (in order)
1. `hex_to_int` — JSON-RPC hex string to int. (`-k "hex_to_int"`)
2. `parse_block` — raw block to a dict with a UTC timestamp, base fee in gwei and utilization. (`-k "parse_block or real_fixture"`)
3. `next_base_fee` — EIP-1559 update in integer wei. (`-k "eip1559"`)
4. `tx_fee_eth` — gasUsed x effectiveGasPrice in ETH. (`-k "fees_and_burn"`)
5. `burned_eth` — block burn = base fee x gas used, in ETH. (`-k "fees_and_burn"`)
6. `priority_fee_eth` — the tip: gasUsed x (effective price - base fee), in ETH. (`-k "fees_and_burn"`)

Functions 4 to 6 share one test (`test_fees_and_burn`), which fails until all three are done.

## Success signal
`uv run pytest day20` — all 7 tests pass (3 parametrized base-fee cases).

## Explore further (optional)
- Change the simulation in `main()` to 80% utilization and find the sustained base fee after 100 blocks; then find the utilization at which the fee stays flat.
- Estimate the annual burn from the fixture block at 7,200 blocks a day and compare it with 1M ETH of yearly issuance.
- Decode the receipt's first log topic by hand: `0xddf252ad...` is the ERC-20 `Transfer` event signature.

## Teardown
Nothing billable is created.

Educational material, not financial advice.
