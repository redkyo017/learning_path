import math

import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def make_bank():
    return m.Bank("b", reserves=10.0, loans=90.0, deposits=90.0, equity=10.0)


def test_lending_creates_deposits_without_using_reserves():
    b = make_bank()
    b.lend(20)
    assert (b.loans, b.deposits, b.reserves) == (110, 110, 10)


def test_ratios():
    b = make_bank()
    assert b.capital_ratio() == pytest.approx(10 / 90)
    assert b.liquidity_ratio() == pytest.approx(10 / 90)


def test_small_run_is_paid_from_reserves():
    states = m.bank_run(make_bank(), [0.1], fire_sale_haircut=0.3)
    s = states[-1]
    assert s["step"] == 1 and s["status"] == "ok"
    assert s["reserves"] == pytest.approx(1) and s["deposits"] == pytest.approx(81)
    assert s["equity"] == pytest.approx(10)


def test_large_run_forces_fire_sale_and_stops_at_insolvency():
    states = m.bank_run(make_bank(), [0.5, 0.5], fire_sale_haircut=0.3)
    assert len(states) == 1
    s = states[0]
    assert s["status"] == "insolvent"
    assert s["reserves"] == pytest.approx(0)
    assert s["loans"] == pytest.approx(40)
    assert s["deposits"] == pytest.approx(45)
    assert s["equity"] == pytest.approx(-5)


def test_identity_holds_every_step_and_input_not_mutated():
    bank = make_bank()
    states = m.bank_run(bank, [0.2, 0.2, 0.2], fire_sale_haircut=0.1)
    for s in states:
        assert s["reserves"] + s["loans"] == pytest.approx(s["deposits"] + s["equity"])
    assert bank.reserves == 10.0  # bank_run works on a copy


def test_returns():
    p = pd.Series([100.0, 110.0, 99.0])
    assert m.simple_returns(p).tolist() == pytest.approx([0.1, -0.1])
    assert m.log_returns(p).sum() == pytest.approx(math.log(0.99))
