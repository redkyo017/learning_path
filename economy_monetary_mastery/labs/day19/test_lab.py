import hashlib

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
BTC = 100_000_000


def test_subsidy_schedule():
    assert m.block_subsidy(0) == 50 * BTC
    assert m.block_subsidy(209_999) == 50 * BTC
    assert m.block_subsidy(210_000) == 25 * BTC
    assert m.block_subsidy(840_000) == 312_500_000
    assert m.block_subsidy(64 * 210_000) == 0


def test_supply_cap():
    assert m.total_supply(210_000) == 210_000 * 50 * BTC
    assert m.total_supply(64 * 210_000) == 2_099_999_997_690_000
    assert m.total_supply(10 ** 8) == 2_099_999_997_690_000


def test_mine():
    nonce, h = m.mine("hdr", 3)
    assert h.startswith("000")
    assert h == hashlib.sha256(f"hdr{nonce}".encode()).hexdigest()


def spend(chain, txid, to, amount, change_to, change):
    return m.Tx(inputs=((txid, 0),), outputs=(m.TxOut(to, amount), m.TxOut(change_to, change)))


def test_genesis_pays_miner():
    c = m.Chain()
    b = c.add_block([], "alice")
    assert c.balance("alice") == 50 * BTC
    assert b["height"] == 0 and b["prev_hash"] == "0" * 64 and b["hash"].startswith("00")


def test_spend_with_fee_and_linking():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    tx = spend(c, cb, "bob", 10 * BTC, "alice", 39 * BTC)
    b1 = c.add_block([tx], "miner")
    assert c.balance("bob") == 10 * BTC
    assert c.balance("alice") == 39 * BTC
    assert c.balance("miner") == 51 * BTC
    assert b1["prev_hash"] == c.blocks[0]["hash"]


def test_double_spend_across_blocks_rejected_atomically():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    c.add_block([spend(c, cb, "bob", 10 * BTC, "alice", 40 * BTC)], "miner")
    with pytest.raises(m.InvalidTx):
        c.add_block([spend(c, cb, "carol", 10 * BTC, "alice", 40 * BTC)], "miner")
    assert len(c.blocks) == 2 and c.balance("carol") == 0


def test_double_spend_within_block_rejected():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    t1 = spend(c, cb, "bob", 10 * BTC, "alice", 40 * BTC)
    t2 = spend(c, cb, "carol", 10 * BTC, "alice", 40 * BTC)
    with pytest.raises(m.InvalidTx):
        c.add_block([t1, t2], "miner")
    assert len(c.blocks) == 1


def test_overspend_rejected():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    with pytest.raises(m.InvalidTx):
        c.add_block([spend(c, cb, "bob", 45 * BTC, "alice", 10 * BTC)], "miner")
