# Day 19 — Bitcoin: UTXO, proof of work, halving

> Block 4: Crypto deep dive. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Bitcoin is the first asset in this course whose "balance sheet" is a public program. There is no issuer to read a prospectus from and no central bank to read minutes from: the rules for who owns what, who can add a block and how many coins will ever exist are code that thousands of independent computers re-check. If you can read a ledger as a set of unspent outputs, you can explain what a "confirmation" is, why a cap is a promise made by software rather than by a person, and where Bitcoin sits in the hierarchy of money from [Day 1](day01.md). Today's lab builds the ledger, the miner and the issuance schedule in about 100 lines.

## Core concepts

### The problem: double spending without a ledger keeper

Digital files copy for free, so digital cash needs someone to stop you paying the same coin twice. In a bank, that someone is the bank's ledger (Day 1, Day 2). Bitcoin's [whitepaper](https://bitcoin.org/bitcoin.pdf) (2008) asks how strangers can agree on one ordering of payments with no trusted keeper. The answer has three parts: a ledger everybody can copy, a rule for which copy wins, and a cost to proposing the next page of it.

### A hash is a fingerprint

SHA-256 turns any input into 256 bits (64 hex characters). The same input always gives the same output, a one-character change gives an unrelated output, and nobody can work backwards from an output to an input except by guessing. Two uses matter: a *transaction id* is the hash of the transaction's contents, and a *block hash* is the hash of the block's header, which includes the previous block's hash.

### Blocks and chaining

A block is a batch of transactions plus a header. Because each header contains the previous block's hash, changing an old transaction changes its block hash, which breaks the link in every later block. Rewriting history means redoing the work for that block and every block after it. A chain is therefore a tamper-evident log, not a database anyone can edit.

### UTXO versus account model

Bitcoin does not store balances. It stores *unspent transaction outputs* (UTXOs): each is an amount locked to an address, identified by `(txid, output index)`. A transaction consumes whole outputs as inputs and creates new outputs. A "balance" is a query: the sum of UTXOs your keys can unlock. Ethereum (Day 20) uses the other design, the account model, where the ledger stores `address -> balance` and a transaction subtracts and adds.

```
  UTXO model                         Account model
  state = set of coins               state = table of balances
  spend = consume a coin, make new   spend = debit A, credit B
  double spend = reuse a coin        double spend = overdraft / replay (needs nonce)
```

Change outputs are the consequence. A coin cannot be split: to pay 10 from a 50 coin you spend the whole 50, create a 10 output for the payee and a 39 output back to yourself. Anything not claimed by an output is the *fee*, which goes to the miner. Forget the change output and you donate it.

```
  Inputs (consumed)            Outputs (created)
  alice coin  50    ---->      bob      10
                               alice    39   (change)
                               fee       1   (inputs - outputs, to the miner)
```

### Signatures (explained, not implemented in the lab)

An output is locked to a public key (via an address). To spend it, the transaction must carry a digital signature made with the matching private key (Bitcoin uses elliptic-curve signatures, ECDSA and, since 2021, Schnorr). Anyone can verify the signature with the public key; only the key holder can produce it. A wallet is therefore a keyring plus software that scans the chain for outputs those keys can unlock and builds signed transactions; it is not an account holding coins. The lab skips signatures entirely, so in the toy chain anyone can spend any output.

### Proof of work

Any node may propose the next block, so the network needs a way to choose one proposer and make rewriting history expensive. Proof of work does it: the header includes a *nonce*, and a block is valid only if its hash, read as a number, is below a target. You find a valid nonce only by trying many. Each extra leading hex zero of difficulty makes a valid hash 16 times rarer. The lab's `mine` searches for a hash with N leading hex zeros (real Bitcoin compares against a numeric target and hashes twice; the idea is the same). Checking a solution takes one hash; finding it takes billions.

The target is retargeted every 2016 blocks so blocks keep arriving about every 10 minutes: if the last 2016 blocks took less than two weeks, difficulty rises, otherwise it falls. The lab has no adjustment. Order of magnitude as of 2026-10 (read 2026-10-11): [mempool.space](https://mempool.space/api/v1/mining/hashrate/3m) reports a network hashrate of roughly 980 EH/s (about 10^21 hashes per second) and a difficulty of about 1.33 x 10^14. At 10 minutes per block, that is on the order of 6 x 10^23 hashes spent per block.

### Which chain wins, and finality as probability

Nodes follow the valid chain with the most accumulated work (usually the longest). Honest miners extend the tip they see first; if two blocks appear at once, the network splits briefly and the next block settles it. The orphaned block's transactions return to the mempool.

An attacker who controls more than half of hashrate (a 51% attack) can privately build a longer chain and publish it, reversing payments they themselves made (double spending them). They still cannot forge signatures or spend other people's coins, and they cannot change the rules nodes enforce. Finality is therefore probabilistic: the chance that a block is reversed falls exponentially with the number of blocks built on top, provided no attacker holds a majority of hashrate. The whitepaper computes this; "6 confirmations" (about an hour) is a convention for large payments, not a protocol constant.

### Monetary policy as code

Issuance is a consensus rule: each block's coinbase (the first transaction) may claim at most *subsidy + fees*. The subsidy started at 50 BTC and halves every 210,000 blocks (about four years). Amounts are integers in satoshis (1 BTC = 10^8 sat), and the halving is an integer shift, so rounding down makes the final total slightly less than 21 million: 2,099,999,997,690,000 sat, or 20,999,999.9769 BTC, per the [Bitcoin wiki](https://en.bitcoin.it/wiki/Controlled_supply). Your `total_supply` reproduces that number exactly.

```
  Era   Start height   Subsidy (BTC)   Cumulative at era end
  0            0       50              10,500,000   (50.0% of cap)
  1      210,000       25              15,750,000
  2      420,000       12.5            18,375,000
  3      630,000       6.25            19,687,500   (93.75%)
  4      840,000       3.125           20,343,750   (96.9%)  <- April 2024 halving
  5    1,050,000       1.5625          20,671,875   (98.4%)  <- future era, from ~April 2028
```

Changing the cap would take a change of software that most node operators, exchanges and miners choose to run. That social cost, not cryptography, is what makes the schedule credible.

### Issuance versus fees: the security budget

Miners are paid subsidy plus fees, and that payment is the cost an attacker must outbid. As the subsidy keeps halving, fees must replace it or hashrate (and security) must be funded some other way. At 3.125 BTC per block and about 144 blocks per day, issuance is about 450 BTC per day. Whether fee income alone can sustain a large security budget in the 2030s and beyond is an open question; there is no consensus answer and the evidence so far (fees have historically been a minority of miner revenue; no dated fee-share source was checked for this course) does not settle it. The framing is cost to attack versus value secured: the budget must stay large relative to the value an attacker could steal or destroy.

### Bitcoin as money

Using the hierarchy from [Day 1](day01.md): Bitcoin is nobody's liability. It is not a deposit, not reserves and not a claim on an issuer, so it does not rank by "settles at par into the rung above". Its price is set by trading, which puts it with securities in the "priced, not promised" tier even though it is also a payment network. Three consequences:

- *Volatility.* Drawdowns of 50% or more have happened repeatedly (measurable on the `data/crypto` OHLCV snapshots with `max_drawdown` from `common.quant`). That is why it is rarely used as a unit of account: prices and wages in the real economy are still quoted in dollars or dong.
- *Custody is the risk.* Whoever holds the private keys controls the coins. Lose the keys and the coins are unrecoverable; hand them to an exchange and you hold an IOU from the exchange (a lower rung again).
- *Bridges to the traditional system.* Spot Bitcoin ETFs (the SEC approved the first US spot bitcoin ETPs on 10 January 2024, per the [SEC Chair's statement](https://www.sec.gov/newsroom/speeches-statements/gensler-statement-spot-bitcoin-011023); trading began on 11 January 2024, a date that statement does not give) let a brokerage account hold exposure without keys; spot ETFs are covered in Day 23 (crypto market structure).

## Worked example

Walk the lab's chain at difficulty 2 (all amounts in BTC; the lab uses satoshis).

*Block 0 (genesis).* No transactions are submitted. The chain builds a coinbase `Tx(inputs=(("coinbase", 0),), outputs=(TxOut("alice", 50),))`. The subsidy at height 0 is 50. Call its txid `cb`. The header is `0|000...0|cb`; `mine` searches nonces until the hash starts with `00`. UTXO set: `{(cb, 0): alice 50}`.

```
  After block 0
  UTXO set                       Balances
  (cb,0)  alice  50              alice 50
```

*Block 1.* Alice builds `Tx(inputs=((cb, 0),), outputs=(bob 10, alice 39))`. Validation: input `(cb,0)` exists and is unspent; inputs 50 >= outputs 49; fee = 1. The coinbase for height 1 pays the miner subsidy + fee = 50 + 1 = 51. Then `(cb,0)` is removed and three outputs are added.

```
  Alice spends (cb,0)
  Inputs          | Outputs
  alice 50        | bob    10
                  | alice  39   (change)
                  | miner  51   (coinbase: 50 subsidy + 1 fee, a separate tx)
  Net new coins this block: 50 (subsidy only). The fee only moved from alice to the miner.
```

Final balances: alice 39, bob 10, miner 51, total 100 = two subsidies. Block 1's header contains block 0's hash in `prev_hash`, which is the link tested by `test_spend_with_fee_and_linking`.

*Attacks the lab rejects.* If Alice later submits another transaction spending `(cb, 0)` to Carol, `(cb,0)` is no longer in the UTXO set, so the whole block is rejected and nothing changes (`test_double_spend_across_blocks_rejected_atomically`). Two transactions in one block spending the same output fail through the block-local `spent` set. Outputs 49 + 6 against a 50 input fail because inputs < outputs.

*Real-world check, as of 2026-10.* [mempool.space](https://mempool.space/api/blocks/tip/height) reports a tip height of 970,883 (read 2026-10-11). The subsidy is `block_subsidy(970_883)` = 3.125 BTC, in force since block 840,000 (April 2024). The next halving is at block 1,050,000, which is 79,117 blocks away: at 10 minutes per block, about 549 days, i.e. roughly April 2028 (an estimate: it moves with hashrate and luck). Your `total_supply(970_883)` gives 20,096,509.375 BTC; [blockchain.info](https://blockchain.info/q/totalbc) reports 20,096,478 BTC in circulation. The difference of about 31 BTC (about 0.0002%) is plausibly subsidy the schedule allowed but miners did not claim; the exact breakdown, including how each data source treats the genesis output, is not verified here (definitional differences between providers are also possible).

## Exercises

1. Compute `block_subsidy` (in BTC) for heights 419,999, 420,000 and 1,050,000. How many halvings have happened by block 970,883?
   **Hint:** era = height // 210,000.
   **Solution sketch:** Height 419,999 gives 25 (era 1); 420,000 gives 12.5 (era 2); 1,050,000 gives 1.5625 (era 5). 970,883 // 210,000 = 4, so four halvings have happened and the subsidy is 50 / 16 = 3.125.

2. Alice owns two UTXOs worth 30 and 25. She pays Bob 40 and wants a fee of 0.5. Draw inputs and outputs.
   **Hint:** One input is not enough; everything not in an output is the fee.
   **Solution sketch:** Inputs 30 + 25 = 55. Outputs: Bob 40, Alice change 14.5. Fee = 55 - 54.5 = 0.5. Spending only the 30 coin cannot cover 40.5.

3. At difficulty D leading hex zeros, how many nonces does `mine` need on average? How much longer is difficulty 6 than difficulty 4?
   **Hint:** Each hex digit is 1 of 16 values.
   **Solution sketch:** About 16^D tries on average. Difficulty 6 takes 16^2 = 256 times as long as difficulty 4. With the lab's output (difficulty 5 in about 0.15 s) difficulty 6 would be roughly 2 s and difficulty 8 about 10 minutes on the same machine.

4. Use `total_supply` to find the first height at which 99% of the cap has been issued. In which era is it, roughly which year?
   **Hint:** 99% of 21 million is 20.79 million; compare to the era-end figures.
   **Solution sketch:** Era 5 ends at 20,671,875 (98.4%) and era 6 at 20,835,937 (99.2%), so 99% falls in era 6, between blocks 1,260,000 and 1,470,000: at about four years per era from April 2028, that is the 2030s (roughly 2032 to 2036). The point: most coins are already issued and the schedule's tail is almost irrelevant.

5. An attacker has 30% of hashrate and the honest network 70%. Is a 51% attack possible? What can a 51% attacker not do?
   **Hint:** Separate what the majority controls (ordering) from what signatures protect (ownership).
   **Solution sketch:** At 30% a sustained private chain falls further behind each block, so a deep reversal is unlikely though not impossible for short depths. With more than 50% the attacker can reverse their own confirmed payments and censor transactions. They cannot spend coins without the private keys, cannot create coins beyond the subsidy (nodes reject such blocks) and cannot change consensus rules.

6. Explain why "balance" is a query in a UTXO chain, and write the one-line Python that gives it.
   **Hint:** Look at `Chain.utxos`.
   **Solution sketch:** `sum(o.amount for o in utxos.values() if o.address == addr)`. Nothing stores a running balance, so spending a coin simply removes it from the set and adding change adds a new one.

7. Place Bitcoin on the Day 1 hierarchy and say what changes if you hold it through an exchange instead of your own keys.
   **Hint:** Whose liability is each?
   **Solution sketch:** Self-custodied bitcoin is a bearer asset with no issuer, priced by trading (securities tier). On an exchange you hold an IOU from the exchange; you carry its credit and operational risk on top of price risk. A spot ETF share is a claim on a fund that holds the coins.

## Anti-patterns / Common mistakes

- "Bitcoin is anonymous." Addresses are pseudonyms on a fully public ledger. Anyone can follow every output; once an address is linked to an identity (an exchange account, a purchase), its whole history is linked too.
- "The cap makes the price go up." A fixed supply schedule limits issuance; price is set by demand. A scarce asset nobody wants is worth nothing, and the schedule is already priced in by traders. Do not infer price direction from the halving.
- Confusing a wallet with an account. A wallet holds keys; the coins are UTXOs on the chain. Deleting the app does not delete coins, and losing the keys does not delete them either: it makes them unspendable.
- Forgetting change outputs. Anything not assigned to an output is the fee. This has cost real users large fees.
- Treating one confirmation as final for a large payment. Finality is probabilistic; size the confirmation count to the value at risk.

## Lab

Open `labs/day19/README.md` and follow the steps. In order: `block_subsidy`, `total_supply`, `mine`, `Chain.add_block`, `Chain.balance`. Success is `uv run pytest day19` with all 8 tests passing, then `uv run python -m day19.lab` printing the issuance table, mining times for difficulty 1 to 5, and saving `.cache/plots/day19.png`. The lab is a toy: no signatures, scripts or difficulty adjustment.

## Teardown

Nothing billable is created. The only files written are the plot in `labs/.cache/plots/`, which is gitignored.

## Journal prompt

In `journal.md`: write one sentence each on what you believe makes a Bitcoin payment final, who pays for that finality after the 2028 halving, and where you would put Bitcoin on the Day 1 hierarchy. Then write what price move or event would change your view.
