"""Day 20 lab: Ethereum fee economics -- decode a raw JSON-RPC block and receipt.

Goal: turn the hex strings a node returns into numbers (hex_to_int, parse_block), apply the
EIP-1559 base-fee update rule with integer math (next_base_fee), and split transaction fees into
the burned base fee and the validator's priority tip (tx_fee_eth, burned_eth, priority_fee_eth).
main() decodes the frozen finalized block and one receipt in data/eth/, then simulates base-fee
dynamics over 50 full blocks followed by 50 empty ones. Amounts are in wei (1 ETH = 1e18 wei,
1 gwei = 1e9 wei); the block's burn counts base fee x gas used for the whole block, as the protocol does.
"""
from datetime import datetime, timezone
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from common.data import load_json


def hex_to_int(h: str) -> int:
    """Convert a JSON-RPC hex quantity such as "0x1a" to an int ("0x0" -> 0)."""
    raise NotImplementedError("TODO: int(h, 16)")


def parse_block(raw: dict) -> dict:
    """Decode an eth_getBlockByNumber result (transactions as hashes) into a plain dict.

    Keys: number (int), timestamp (tz-aware UTC datetime), base_fee_gwei (float),
    gas_used (int), gas_limit (int), tx_count (int), utilization (gas_used / gas_limit).
    """
    raise NotImplementedError("TODO: hex_to_int each field; datetime.fromtimestamp(ts, tz=timezone.utc)")


def next_base_fee(base_fee_wei: int, gas_used: int, gas_limit: int) -> int:
    """EIP-1559 base fee of the next block, in integer wei.

    target = gas_limit // 2. At the target the fee is unchanged; above it, it rises by
    base*(used-target)/target/8 (at least 1 wei); below it, it falls by base*(target-used)/target/8.
    Use integer floor division throughout.
    """
    raise NotImplementedError("TODO: target = gas_limit // 2; three branches with // 8")


def tx_fee_eth(receipt: dict) -> float:
    """Total fee paid by a transaction in ETH: gasUsed * effectiveGasPrice / 1e18."""
    raise NotImplementedError("TODO: gasUsed * effectiveGasPrice / 1e18")


def burned_eth(raw_block: dict) -> float:
    """ETH burned by a whole block: baseFeePerGas * gasUsed / 1e18."""
    raise NotImplementedError("TODO: baseFeePerGas * gasUsed / 1e18")


def priority_fee_eth(receipt: dict, base_fee_wei: int) -> float:
    """The tip a transaction pays the validator, in ETH: gasUsed * (effectiveGasPrice - base_fee) / 1e18."""
    raise NotImplementedError("TODO: gasUsed * (effective - base) / 1e18")


def main() -> None:
    raw = load_json("eth/block.json")
    rec = load_json("eth/receipt.json")
    b = parse_block(raw)
    print(f"Block {b['number']:,} at {b['timestamp']:%Y-%m-%d %H:%M} UTC: {b['tx_count']} txs, "
          f"gas {b['gas_used']:,} / {b['gas_limit']:,} ({b['utilization']:.1%} full), "
          f"base fee {b['base_fee_gwei']:.4f} gwei")
    print(f"  burned in the block: {burned_eth(raw):.6f} ETH")

    base = hex_to_int(raw["baseFeePerGas"])
    fee, tip = tx_fee_eth(rec), priority_fee_eth(rec, base)
    print(f"Receipt: gas {hex_to_int(rec['gasUsed']):,} at {hex_to_int(rec['effectiveGasPrice']) / 1e9:.4f} gwei "
          f"-> fee {fee:.6f} ETH = burned {fee - tip:.6f} + tip {tip:.6f}")
    nxt = next_base_fee(base, b["gas_used"], b["gas_limit"])
    print(f"Next base fee: {nxt / 1e9:.4f} gwei ({nxt / base - 1:+.2%} vs this block)")

    path, fee_w = [], 10 ** 9
    for used in [60_000_000] * 50 + [0] * 50:
        path.append(fee_w / 1e9)
        fee_w = next_base_fee(fee_w, used, 60_000_000)
    print(f"Simulation from 1 gwei: after 50 full blocks {path[50]:.1f} gwei (x{path[50]:.0f}); "
          f"after 50 empty ones {path[-1]:.2f} gwei")
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(path)
    ax.axvline(50, color="grey", ls="--")
    ax.set_yscale("log")
    ax.set(xlabel="block", ylabel="base fee (gwei, log)", title="EIP-1559: 50 full blocks, then 50 empty")
    out = Path(__file__).resolve().parent.parent / ".cache" / "plots" / "day20.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=120, bbox_inches="tight")
    print(f"Saved {out}")


if __name__ == "__main__":
    main()
