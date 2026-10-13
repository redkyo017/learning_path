import pytest

from common.data import load_json
from common.labimpl import load_impl

m = load_impl(__file__)
RAW = {"number": "0x10", "timestamp": "0x65000000", "baseFeePerGas": hex(20 * 10 ** 9),
       "gasUsed": hex(15_000_000), "gasLimit": hex(30_000_000), "transactions": ["0xa", "0xb"]}
RECEIPT = {"gasUsed": hex(21_000), "effectiveGasPrice": hex(30 * 10 ** 9)}


def test_hex_to_int():
    assert m.hex_to_int("0x1a") == 26 and m.hex_to_int("0x0") == 0


def test_parse_block():
    b = m.parse_block(RAW)
    assert b["number"] == 16 and b["tx_count"] == 2
    assert b["timestamp"].timestamp() == 1_694_498_816
    assert b["timestamp"].tzinfo is not None
    assert b["base_fee_gwei"] == pytest.approx(20.0)
    assert b["utilization"] == pytest.approx(0.5)


@pytest.mark.parametrize("used,expected", [(30_000_000, 1_125_000_000),
                                           (0, 875_000_000),
                                           (15_000_000, 1_000_000_000)])
def test_eip1559_base_fee(used, expected):
    assert m.next_base_fee(10 ** 9, used, 30_000_000) == expected


def test_fees_and_burn():
    assert m.tx_fee_eth(RECEIPT) == pytest.approx(0.00063)
    assert m.burned_eth(RAW) == pytest.approx(0.3)
    assert m.priority_fee_eth(RECEIPT, 20 * 10 ** 9) == pytest.approx(21_000 * 10 * 10 ** 9 / 1e18)


def test_real_fixture_parses():
    b = m.parse_block(load_json("eth/block.json"))
    assert b["number"] > 20_000_000 and 0 <= b["utilization"] <= 1.0
