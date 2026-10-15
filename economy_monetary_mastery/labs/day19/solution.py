"""Day 19 lab: Bitcoin as code -- issuance schedule, proof of work, and a UTXO ledger.

Goal: implement the subsidy schedule and total supply in closed form (block_subsidy, total_supply),
the proof-of-work search (mine), and a toy UTXO chain that validates spends, pays fees to the miner
and links blocks by hash (Chain.add_block, Chain.balance). Amounts are integer satoshis.
main() prints the issuance schedule by era, times mining at difficulty 1-5 and plots the supply curve.
Toy model: no signatures or scripts (anyone can spend any output), no difficulty adjustment,
no Merkle tree, no network. It shows the ledger rules, not the security of real Bitcoin.
"""
import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

BTC = 100_000_000
HALVING_INTERVAL = 210_000
MAX_HALVINGS = 64


@dataclass(frozen=True)
class TxOut:
    address: str
    amount: int


@dataclass(frozen=True)
class Tx:
    inputs: tuple[tuple[str, int], ...]
    outputs: tuple[TxOut, ...]

    def txid(self) -> str:
        body = {"in": [list(i) for i in self.inputs],
                "out": [[o.address, o.amount] for o in self.outputs]}
        return hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()


class InvalidTx(ValueError):
    pass


def block_subsidy(height: int) -> int:
    """Block subsidy in satoshis at `height`: 50 BTC halved every 210,000 blocks (integer shift),
    and 0 once 64 halvings have happened."""
    # A right shift by the era number is an exact integer halving; after 33 shifts it is already 0,
    # but the explicit >= 64 guard avoids relying on that (and on huge shift widths).
    era = height // HALVING_INTERVAL
    if era >= MAX_HALVINGS:
        return 0
    return (50 * BTC) >> era


def total_supply(height: int) -> int:
    """Sum of block_subsidy(h) for h in 0..height-1, in satoshis. Must be closed form per era
    (tests call it with 10**8; a loop over every height would be far too slow)."""
    # Count complete eras and the partial remainder; each era contributes 210,000 * its subsidy.
    height = min(height, MAX_HALVINGS * HALVING_INTERVAL)
    full, rem = divmod(height, HALVING_INTERVAL)
    total = sum(HALVING_INTERVAL * ((50 * BTC) >> e) for e in range(full))  # at most 64 terms
    if full < MAX_HALVINGS:
        total += rem * ((50 * BTC) >> full)
    return total


def mine(header: str, difficulty: int) -> tuple[int, str]:
    """Find the smallest nonce >= 0 such that sha256(f"{header}{nonce}") in hex starts with
    `difficulty` zeros. Return (nonce, hex_digest)."""
    prefix = "0" * difficulty
    nonce = 0
    while True:
        digest = hashlib.sha256(f"{header}{nonce}".encode()).hexdigest()
        if digest.startswith(prefix):
            return nonce, digest
        nonce += 1


class Chain:
    def __init__(self, difficulty: int = 2):
        self.difficulty = difficulty
        self.utxos: dict[tuple[str, int], TxOut] = {}
        self.blocks: list[dict] = []

    def add_block(self, txs: list[Tx], miner: str) -> dict:
        """Validate `txs`, then mine and append a block; return the block dict
        {"height", "prev_hash", "txids", "nonce", "hash"}. All-or-nothing: raise InvalidTx before
        changing any state if an input is missing/already spent (also within this block), an output
        is negative, or inputs < outputs. The miner's coinbase pays subsidy + fees and comes first."""
        height = len(self.blocks)
        prev_hash = self.blocks[-1]["hash"] if self.blocks else "0" * 64

        # Phase 1: validate everything against the current UTXO set. Nothing is mutated here.
        spent: set[tuple[str, int]] = set()  # block-local: catches double spends inside one block
        fees = 0
        for tx in txs:
            if not tx.inputs:
                raise InvalidTx("transaction has no inputs")
            total_in = 0
            for outpoint in tx.inputs:
                if outpoint in spent:
                    raise InvalidTx(f"double spend of {outpoint} within the block")
                if outpoint not in self.utxos:  # also rejects outputs created in this same block
                    raise InvalidTx(f"unknown or already spent output {outpoint}")
                spent.add(outpoint)
                total_in += self.utxos[outpoint].amount
            if any(o.amount < 0 for o in tx.outputs):
                raise InvalidTx("negative output")
            total_out = sum(o.amount for o in tx.outputs)
            if total_in < total_out:
                raise InvalidTx("outputs exceed inputs")
            fees += total_in - total_out

        # Phase 2: build the coinbase (first), apply all state changes, then mine.
        coinbase = Tx(inputs=(("coinbase", height),),
                      outputs=(TxOut(miner, block_subsidy(height) + fees),))
        all_txs = [coinbase, *txs]
        for outpoint in spent:
            del self.utxos[outpoint]
        for tx in all_txs:
            tid = tx.txid()
            for i, out in enumerate(tx.outputs):
                self.utxos[(tid, i)] = out
        txids = [tx.txid() for tx in all_txs]
        header = f"{height}|{prev_hash}|{','.join(txids)}"
        nonce, digest = mine(header, self.difficulty)
        block = {"height": height, "prev_hash": prev_hash, "txids": txids,
                 "nonce": nonce, "hash": digest}
        self.blocks.append(block)
        return block

    def balance(self, address: str) -> int:
        """Total satoshis in unspent outputs owned by `address`."""
        return sum(o.amount for o in self.utxos.values() if o.address == address)


def main() -> None:
    print("Issuance schedule by era (heights are era starts; supply is cumulative at era end):")
    print(f"{'era':>3} {'start height':>13} {'subsidy BTC':>12} {'supply at end':>16} {'% of cap':>9}")
    cap = total_supply(MAX_HALVINGS * HALVING_INTERVAL)
    for era in range(0, 34, 4):
        start = era * HALVING_INTERVAL
        end_supply = total_supply(start + HALVING_INTERVAL)
        print(f"{era:>3} {start:>13,} {block_subsidy(start) / BTC:>12.8f} "
              f"{end_supply / BTC:>16,.4f} {end_supply / cap:>9.4%}")
    print(f"Cap (sum of integer subsidies): {cap} sat = {cap / BTC:,.8f} BTC (just under 21,000,000)")

    print("Mining time for one header, sha256 prefix of N zeros (each +1 is ~16x more work):")
    for d in range(1, 6):
        t0 = time.perf_counter()
        nonce, h = mine("day19-demo", d)
        print(f"  difficulty {d}: nonce {nonce:>9,}  {time.perf_counter() - t0:7.3f}s  {h[:16]}...")

    c = Chain()
    cb = c.add_block([], "alice")["txids"][0]
    c.add_block([Tx(((cb, 0),), (TxOut("bob", 10 * BTC), TxOut("alice", 39 * BTC)))], "miner")
    print("Toy chain after genesis + one spend with a 1 BTC fee:",
          {a: c.balance(a) / BTC for a in ("alice", "bob", "miner")})

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day19.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    heights = list(range(0, 33 * HALVING_INTERVAL + 1, 10_000))
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.plot([h / 1e6 for h in heights], [total_supply(h) / BTC / 1e6 for h in heights])
    ax.axhline(21, color="gray", linestyle="--")
    ax.set_xlabel("block height (millions)")
    ax.set_ylabel("cumulative supply (millions of BTC)")
    ax.set_title("Bitcoin issuance schedule")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
