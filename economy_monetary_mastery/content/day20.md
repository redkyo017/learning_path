# Day 20 — Ethereum: accounts, gas, EVM, proof of stake

> Block 4: Crypto deep dive. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 19 showed money as a set of unspent outputs that nobody can forge. Ethereum answers a different question: what if the shared ledger could also run programs? The result is a chain that holds balances like a bank ledger, executes code like a tiny global computer, charges for that computation like a toll road, and since September 2022 secures itself by locking up the asset it issues rather than by burning electricity. Almost everything you will meet later in the course (stablecoins on Day 21, AMMs and liquidations on Day 22) is a smart contract running on this machine, so its fee market, its yield and its failure modes are the substrate of that risk.

Two things make Ethereum useful for an investor with a finance background. First, its fee mechanism (EIP-1559) is a clean example of an algorithmic price controller, and you can reproduce it in ten lines. Second, staking yield is the first place in this course where "yield" appears without a borrower on the other side, and it is easy to mistake for a risk-free rate. Today's lab decodes a raw block from a real node and checks the arithmetic by hand.

## Core concepts

### Accounts, not coins

Bitcoin (Day 19) tracks unspent outputs: your "balance" is the sum of coins you can spend. Ethereum keeps a **world state**: a table mapping each address to a balance, a nonce (a counter of transactions sent) and, for contracts, code and storage. Sending value subtracts from one row and adds to another, like a bank ledger (Day 2) but with no bank in the middle.

| | UTXO (Bitcoin) | Account (Ethereum) |
|---|---|---|
| State | set of unspent outputs | address -> balance, nonce, code, storage |
| Replay protection | each output spent once | nonce must increase by 1 |
| Programmability | limited script | arbitrary code |
| Parallelism | easy (independent outputs) | harder (shared state) |

There are two kinds of account. An **externally owned account (EOA)** is controlled by a private key. A **contract account** is controlled by its code: it acts only when called. Since Pectra, [EIP-7702](https://blog.ethereum.org/2025/04/23/pectra-mainnet) lets an EOA delegate to contract code, which blurs the line (batching, gas sponsorship) without changing the key-holder's ultimate control.

### The EVM as a deterministic state machine

The Ethereum Virtual Machine takes the current state plus a transaction and produces a new state. It is **deterministic**: every node, given the same input, must compute the same output, otherwise they could not agree on the chain. That is why contracts cannot call the internet; they can only read chain state, and external prices arrive through oracle contracts that someone writes into the chain (a risk of its own, Day 22). A block is an ordered list of transactions applied one after another, and the block header commits to the resulting state (`stateRoot` in the fixture).

### Gas: metered compute

Every EVM operation costs **gas**: 21,000 for a plain transfer, far more for storage writes or contract calls. Gas is a unit of work, not money. You pay for it in ETH at a **gas price** quoted in **gwei** (1 gwei = 10^-9 ETH = 10^9 wei). Two limits matter: each transaction sets its own gas limit (unused gas is refunded), and each block has a **block gas limit** capping total work, which sets throughput and how heavy a node's job is. As of 2026-10 the limit is 60,000,000 gas: [Fusaka](https://blog.ethereum.org/2025/11/06/fusaka-mainnet-announcement) set the mainnet default to 60M via EIP-7935, and the frozen fixture block of 2026-10-11 reports `gasLimit` 60,000,000 (0x3938700). Developers discuss a path toward roughly 200M with parallel execution, but no date is set ([InvestingLive](https://investinglive.com/education/glamsterdam-in-plain-english-how-ethereum-plans-to-cut-out-the-middlemen-in-block-building/), secondary; the figure is a discussion target, unverified as of 2026-10).

### EIP-1559: the base fee burns, the tip pays

Before 2021, users bid in a first-price auction for block space and overpaid. Since the London upgrade (August 2021), each block carries a protocol-set **base fee** per gas, and a transaction pays:

```
fee paid  =  gasUsed x effectiveGasPrice
effectiveGasPrice = base fee (burned) + priority fee ("tip", paid to the validator)
```

The base fee is a feedback controller aimed at half-full blocks. With `target = gasLimit / 2`:

- block exactly at target: next base fee unchanged;
- block full: next base fee up by 12.5%;
- block empty: next base fee down by 12.5%;
- in between: proportional, `base * (used - target) / target / 8`.

Because the change is multiplicative, a run of full blocks compounds: 1.125^50 is about 361, so a sustained rush multiplies the fee 361 times in 50 blocks (about 10 minutes) and quiet periods bleed it back down. Users who set a max fee and a tip never pay more than the max, and the protocol burns the base portion: those ETH leave supply forever. A T-account of one transfer:

```
   Sender (EOA)            Validator            Protocol burn
  ETH -(base+tip)*gas     ETH +tip*gas         supply -base*gas
```

In the lab: `next_base_fee`, `tx_fee_eth`, `burned_eth`, `priority_fee_eth`.

### Proof of stake, yield and slashing

Since [the Merge](https://ethereum.org/en/roadmap/merge/) (September 2022) validators replace miners. A validator locks 32 ETH (up to 2,048 ETH per validator since Pectra's [EIP-7251](https://blog.ethereum.org/2025/04/23/pectra-mainnet)), is chosen to propose blocks and attest to others, and earns protocol rewards. Time is cut into 12-second slots and 32-slot epochs.

- **Yield sources:** new ETH issued by the protocol for attestation and proposal duties, priority fees, and MEV (value extracted by ordering transactions, passed on through block builders). Issuance per validator falls as the total staked rises, so yield compresses as staking grows.
- **Slashing:** provably contradictory behaviour (signing two conflicting blocks) forfeits part of the stake and ejects the validator. Plain downtime costs only small penalties.
- **Finality:** a block is finalised after two epochs of supermajority attestation (about 13 minutes); reversing it would require burning roughly a third of all staked ETH.

Current numbers, as of 2026-10: [validatorqueue.com](https://www.validatorqueue.com/) shows a staking APR of 2.59%, 43.7 million ETH staked (35.77% of supply), an entry queue of about 1.34M ETH (roughly 23 days) and an exit queue of about 0.93M ETH (read 2026-10-11, from a live dashboard). A late-May 2026 secondary report put base yield near 2.8% with MEV-Boost adding roughly 0.3 to 1 percentage point (the same article gives both figures; [KuCoin](https://www.kucoin.com/blog/ethereum-staking-in-2026-yield-trends-validator-queue-dynamics-and-mev-impact-exlained?lang=en_US)). So the **APR range is roughly 2.6% to 3.8%** (base about 2.6% to 2.8%; the top end is a secondary source's all-in figure with MEV), well below the double-digit figures common a few years ago; it moves daily, so re-check the dashboard.

### Supply dynamics and "ultrasound money"

Net issuance is issuance minus burn. In 2022 to 2023, high fees burned more ETH than validators received, so supply shrank and the "ultrasound money" claim (better than Bitcoin's fixed schedule) was born. It depends on fee revenue, which fell as activity moved to layer 2 (below). A September 2026 secondary guide ([BloFin](https://blofin.com/academy/education/ethereum/eth-ultrasound-money), page not retrievable for checking) says supply is growing slowly again; one analysis cited puts net issuance near 0.7% to 0.8% a year, unverified as of 2026-10. Total supply is about 122.1 million ETH per [ultrasound.money](https://ultrasound.money) (its growth and burn counters were not loaded when read). The trend is therefore **mildly inflationary, not deflationary**. The worked example shows why.

### Liquid staking tokens as shadow banking

Locked ETH is illiquid, so protocols such as Lido issue a receipt token (stETH) for deposited ETH, which trades and can be posted as collateral elsewhere. This is maturity transformation of the Day 5 kind: a claim redeemable "on demand" backed by an asset that exits through a queue (currently days to weeks, above). In normal times the token trades near 1 ETH; in a run, holders who need cash can only sell at a discount, as stETH did in June 2022. Chain the token as collateral into lending (Day 22) and you have leverage on top of a queue.

### Layer 2s and blobs

Layer 1 block space is scarce, so **rollups** execute transactions off-chain in batches and post compressed data plus proofs to Ethereum, inheriting its security. Fees fall because many users share one L1 transaction. [EIP-4844](https://www.eip4844.com/) (March 2024) added **blob transactions**: cheap, temporary data space priced in a separate fee market, so rollups no longer compete with ordinary transfers. Capacity has expanded: Pectra (7 May 2025) raised the blob target to 6; [Fusaka](https://blog.ethereum.org/2025/11/06/fusaka-mainnet-announcement) (3 December 2025) added PeerDAS sampling, and two config-only forks raised the blob target to 10 (9 Dec 2025) and then 14, maximum 21 (7 Jan 2026). The side effect is the one above: cheaper L2 data means less L1 fee revenue and less burn.

**Latest hard fork, as of 2026-10:** Fusaka (activated 3 December 2025, 21:49 UTC), after Pectra (7 May 2025). The next, Glamsterdam, reached the Sepolia testnet on 6 October 2026; Hoodi is tentatively 27 October and a mainnet date is not set ([InvestingLive](https://investinglive.com/education/glamsterdam-in-plain-english-how-ethereum-plans-to-cut-out-the-middlemen-in-block-building/), secondary).

### Reading the chain

A node speaks **JSON-RPC**: `eth_getBlockByNumber` returns a block and `eth_getTransactionReceipt` returns what a transaction did, with every number as a hex string (`"0x3938700"`). Block explorers such as [Etherscan](https://etherscan.io) decode these for you, but the lab works on the raw JSON so you can verify an explorer rather than trust it. Frozen fixtures are `data/eth/block.json` and `receipt.json`.

## Worked example

Decode the fixture block (number 26,167,253, 11 October 2026, 05:55 UTC; run `uv run python -m day20.solution`):

```
gasLimit  0x3938700  = 60,000,000
gasUsed   0x158c6b5  = 22,595,253   -> utilization 37.7%, below the 50% target
baseFee   0x3d710a0  = 64,426,144 wei = 0.0644 gwei
burn      0.0644 gwei x 22,595,253 gas = 0.001456 ETH
next base fee: deficit (30,000,000 - 22,595,253) / 30,000,000 = 24.7%; / 8 = 3.09% cut -> 0.0624 gwei
```

The receipt (type 0x2, a multi-token contract call with 24 log entries, including ERC-20 Transfer events) used 418,702 gas at an effective price of exactly the base fee, so fee = 0.000027 ETH, all of it burned, and the **tip is zero**. Gas price is not the whole fee, and the fee is not all revenue to the validator.

Now scale the burn. One block burned 0.001456 ETH. At 7,200 blocks a day, that is about 10.5 ETH a day or 3,800 ETH a year if every block looked like this one. Staking issuance is roughly 2.6% on 43.7 million ETH, of the order of 1 million ETH a year. The burn is a rounding error beside issuance: at 0.06 gwei, ETH is **inflationary** (a single block is a crude sample, but the base fee being below 1 gwei is itself the finding). For the ultrasound-money claim to hold, base fees would need to be hundreds of times higher. The lab's simulation shows how: sustained full blocks lift 1 gwei to about 361 gwei in 50 blocks; empty ones decay that back to about 0.5 gwei in 50 more. Break-even for the burn: about 1.1M ETH a year over 2.63M blocks is 0.43 ETH per block, which at 22.6M gas needs a base fee near 19 gwei, roughly 300 times today's.

## Exercises

1. **Compute a swap fee.** A transaction uses 150,000 gas at an effective gas price of 25 gwei, with the block's base fee at 20 gwei. Find the fee, the burn and the tip in ETH.
   **Hint:** gas x price in gwei, then divide by 10^9 to get ETH.
   **Solution sketch:** fee = 150,000 x 25 = 3.75M gwei = 0.00375 ETH; burn = 150,000 x 20 = 3.0M gwei = 0.003 ETH; tip = 150,000 x 5 = 0.75M gwei = 0.00075 ETH. Check: burn + tip = fee.

2. **Base fee after a rush.** The base fee is 30 gwei and three consecutive blocks are 100% full. What is the base fee for the fourth block? Then three empty blocks follow.
   **Hint:** each full block multiplies by 1.125 and each empty block by 0.875; the lab uses integer floor division, so tiny rounding differs.
   **Solution sketch:** 30 x 1.125^3 = about 42.7 gwei; then x 0.875^3 = about 28.6 gwei. A rush of three blocks does not reverse symmetrically: up-down leaves the fee slightly lower than it started because 1.125 x 0.875 is 0.984.

3. **Mean-reverting?** Explain why a base fee that doubles during a rush returns to normal only if demand also falls, using the target rule.
   **Hint:** what utilization keeps the fee unchanged?
   **Solution sketch:** at 50% utilization the fee is stable at any level, so the controller holds a high fee as long as demand keeps blocks half full at that price. Fees fall only when demand at the higher price drops below the target. It adjusts the price until demand equals the target, not toward an "old" price.

4. **Net issuance.** Suppose 43.7M ETH is staked, the staking APR is 2.6% (assume all of it is protocol issuance), and annual burn is 3,800 ETH. Find net issuance as a percentage of a 122.1M ETH supply.
   **Hint:** issuance = staked x APR; net = issuance - burn.
   **Solution sketch:** issuance = 43.7M x 0.026 = about 1.136M ETH; net = 1.136M - 0.0038M = about 1.132M ETH, or about 0.93% of supply. In practice part of the APR is tips and MEV (not new issuance), so treat 0.93% as an upper bound; the 0.7% to 0.8% reported by one source is of the same order.

5. **stETH run risk.** A lender accepts stETH as collateral at par with 85% loan-to-value. Describe what happens if stETH trades at 0.90 ETH and the exit queue is 40 days.
   **Hint:** compare the collateral's market value, not its redemption value, with the debt, and think about who can wait 40 days.
   **Solution sketch:** debt of 0.85 ETH against collateral now worth 0.90 ETH is at 94% LTV, close to liquidation; liquidators sell stETH on the market, pushing the discount deeper. Redemption through the queue would pay par but takes 40 days, so a forced seller cannot use it. This is the Day 5 pattern: promised liquidity backed by an illiquid asset.

6. **Account vs UTXO.** Give one advantage and one risk of the account model compared with the UTXO model of Day 19.
   **Hint:** think of programmability and of two transactions touching the same row.
   **Solution sketch:** advantage: contracts keep persistent state, so a lending pool or exchange is one address that anyone can call. Risk: shared mutable state makes ordering matter (MEV, front-running), and a bug in a contract can drain every user's funds at once, where a bug in one UTXO script only affects that output.

## Anti-patterns / Common mistakes

- **"Gas price = fee."** Fee = gas used x price, and the price splits into a burned base fee and a tip. A 20 gwei price on a 21,000-gas transfer is 0.00042 ETH; the same price on a 400,000-gas swap is nearly twenty times as much.
- **Treating staking yield as risk-free.** The 2.6% to 3.8% is paid in ETH, so it carries ETH price risk. It also carries slashing risk, smart-contract risk when staking through a liquid token, and an exit queue that can run to weeks. Compare it with a Treasury bill (Day 7) only after pricing those.
- **Ignoring smart-contract risk.** Audited code still has bugs; a contract that holds funds is a single point of failure. Position size should reflect it.
- **Assuming "ultrasound" is permanent.** Burn tracks fee revenue, and fee revenue moved to layer 2s. Check the current net issuance before quoting a supply trend.
- **Believing explorer numbers blindly.** Explorers rely on the same node data; decode a few fields yourself, as the lab does, so you know what each column means.

## Lab

From `economy_monetary_mastery/labs/`:

```
uv run pytest day20                          # the six functions, red at the start
uv run python -m day20.lab                   # decode the fixture block and receipt
```

Implement `hex_to_int`, `parse_block`, `next_base_fee`, `tx_fee_eth`, `burned_eth` and `priority_fee_eth` in `labs/day20/lab.py` (see `labs/day20/README.md`). `main()` prints the block summary, the receipt's burn/tip split, the next base fee and a 50-full-then-50-empty simulation, and saves `labs/.cache/plots/day20.png`. `labs/day20/SOLUTION.md` has notes once you are done.

## Teardown

Nothing billable is created. The lab reads frozen snapshots only; no node, key or wallet is needed.

## Journal prompt

You are offered a 3% yield for staking ETH through a liquid token. List the three risks that a bank deposit at the same rate would not carry, say which you would pay to avoid, and write down the base fee at which Ethereum's burn would exceed its issuance.
