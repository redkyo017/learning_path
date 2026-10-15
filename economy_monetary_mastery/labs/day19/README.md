# Lab 19 — Bitcoin: UTXO, proof of work, halving

**Goal:** code Bitcoin's issuance schedule, a proof-of-work search and a toy UTXO ledger that rejects double spends.   **Time:** ~1.5 h   **Content:** `../../content/day19.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function, run its tests with the `-k` expression listed below (`uv run pytest day19 -k "<expression>"`).
4. When all pass: `uv run python -m day19.lab` and inspect the printed summary / `.cache/plots/day19.png`.

Run every command from the `labs/` folder. Failing tests at the start are expected: they are your to-do list. Amounts are integer satoshis (1 BTC = 100,000,000). This is a toy model: no signatures, scripts or difficulty adjustment.

## Functions to implement (in order)
1. `block_subsidy` — 50 BTC halved every 210,000 blocks, 0 after 64 halvings. (`-k "test_subsidy"`)
2. `total_supply` — cumulative subsidy before `height`, closed form per era. (`-k "test_supply"`)
3. `mine` — smallest nonce whose SHA-256 hex digest has the zero prefix. (`-k "test_mine"`)
4. `Chain.add_block` — validate, add coinbase with fees, apply, mine, link. (`-k "genesis or spend or double or overspend"`)
5. `Chain.balance` — sum of unspent outputs for an address. (`-k "genesis or spend"`)

## Success signal
`uv run pytest day19` — all 8 tests pass.

## Explore further (optional)
- Add a `reorg(blocks)` that adopts a longer valid chain and rebuilds the UTXO set.
- Count how many nonces `mine` needs at difficulty 1 to 5 over 20 headers and compare with 16^d.
- Add a coinbase-maturity rule (coinbase outputs unspendable for 100 blocks).

## Teardown
Nothing billable is created. The only file written is the plot in `.cache/plots/`, which is gitignored.
