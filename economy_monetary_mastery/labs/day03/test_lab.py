import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
KW = dict(iorb=4.40, ceiling=4.50, satiation=2500.0)


def test_floor_system_rate_is_iorb_when_reserves_ample():
    assert m.overnight_rate(3000.0, **KW) == pytest.approx(4.40)
    assert m.overnight_rate(2500.0, **KW) == pytest.approx(4.40)


def test_scarce_reserves_push_rate_toward_ceiling():
    assert m.overnight_rate(0.0, **KW) == pytest.approx(4.50)
    assert m.overnight_rate(1250.0, **KW) == pytest.approx(4.45)


def test_rate_never_rises_with_more_reserves():
    rates = [m.overnight_rate(r, **KW) for r in range(0, 4001, 250)]
    assert all(a >= b for a, b in zip(rates, rates[1:]))


def test_negative_reserves_rejected():
    with pytest.raises(ValueError):
        m.overnight_rate(-1.0, **KW)


def test_qe_from_nonbank_creates_reserves_and_deposits():
    p = m.qe_postings(100.0, seller="nonbank")
    assert p["central_bank"] == {"assets": {"treasuries": 100.0},
                                 "liabilities": {"reserves:bank": 100.0}}
    assert p["bank"] == {"assets": {"reserves": 100.0},
                         "liabilities": {"deposit:seller": 100.0}}
    assert p["seller"] == {"assets": {"treasuries": -100.0, "deposit": 100.0},
                           "liabilities": {}}


def test_qe_from_bank_creates_reserves_only():
    p = m.qe_postings(100.0, seller="bank")
    assert p["bank"] == {"assets": {"reserves": 100.0, "treasuries": -100.0},
                         "liabilities": {}}
    assert "seller" not in p


@pytest.mark.parametrize("seller", ["bank", "nonbank"])
def test_every_entity_balances(seller):
    for side in m.qe_postings(50.0, seller=seller).values():
        assert sum(side["assets"].values()) == pytest.approx(sum(side["liabilities"].values()))


def test_unknown_seller_rejected():
    with pytest.raises(ValueError):
        m.qe_postings(1.0, seller="alien")


def test_align_weekly():
    daily = pd.Series(range(14), index=pd.date_range("2024-01-01", periods=14, freq="D"),
                      dtype=float)
    monthly = pd.Series([1.0], index=pd.to_datetime(["2023-12-01"]))
    df = m.align_weekly({"d": daily, "m": monthly})
    assert list(df.columns) == ["d", "m"]
    assert df.index[0] == pd.Timestamp("2024-01-03")
    assert df["d"].tolist() == [2.0, 9.0, 13.0]
    assert df["m"].tolist() == [1.0, 1.0, 1.0]
