import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_balanced_apply_updates_both_sides():
    b = m.BalanceSheet("bank")
    b.apply(assets={"reserves": 100}, liabilities={"equity": 100})
    b.apply(assets={"loans": 50}, liabilities={"deposit:alice": 50})
    assert b.assets == {"reserves": 100, "loans": 50}
    assert b.total_assets() == 150 and b.total_liabilities() == 150


def test_unbalanced_apply_raises_and_leaves_state_unchanged():
    b = m.BalanceSheet("bank")
    b.apply(assets={"reserves": 10}, liabilities={"equity": 10})
    with pytest.raises(m.UnbalancedError):
        b.apply(assets={"loans": 5})
    assert b.assets == {"reserves": 10} and b.liabilities == {"equity": 10}


def test_asset_swap_is_balanced():
    b = m.BalanceSheet("bank")
    b.apply(assets={"reserves": 100}, liabilities={"equity": 100})
    b.apply(assets={"reserves": -40, "treasuries": 40})
    assert b.assets == {"reserves": 60, "treasuries": 40}
    assert b.total_assets() == 100


def _banks():
    a = m.BalanceSheet("bank_a")
    a.apply(assets={"reserves": 20, "loans": 80}, liabilities={"deposit:alice": 90, "equity": 10})
    b = m.BalanceSheet("bank_b")
    b.apply(assets={"reserves": 5}, liabilities={"equity": 5})
    return a, b


def test_transfer_moves_deposits_and_reserves():
    a, b = _banks()
    m.transfer_deposit(a, b, 15, payer="alice", payee="bob")
    assert a.assets["reserves"] == 5 and a.liabilities["deposit:alice"] == 75
    assert b.assets["reserves"] == 20 and b.liabilities["deposit:bob"] == 15


def test_transfer_without_enough_reserves_raises_and_changes_nothing():
    a, b = _banks()
    with pytest.raises(ValueError):
        m.transfer_deposit(a, b, 25, payer="alice", payee="bob")
    assert a.assets["reserves"] == 20 and "deposit:bob" not in b.liabilities


def test_parse_fred_csv_handles_missing_dots_and_header():
    text = "observation_date,DFF\n2024-01-01,5.33\n2024-01-02,.\n2024-01-03,5.31\n"
    s = m.parse_fred_csv(text)
    assert s.name == "DFF"
    assert isinstance(s.index, pd.DatetimeIndex)
    assert s.tolist() == [5.33, 5.31]
