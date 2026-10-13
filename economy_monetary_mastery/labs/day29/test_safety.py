"""Extra safety tests (kept apart from test_lab.py)."""
import math

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def make(tmp_path, broker=None, weight=0.5, **limits):
    broker = broker or m.FakeBroker(10_000.0, {"X": 100.0})
    bot = m.Bot(broker, lambda h: weight, m.RiskLimits(**limits),
                tmp_path / "log.jsonl", tmp_path / "KILL")
    return broker, bot


def test_kill_file_needs_no_market_data(tmp_path):
    b, bot = make(tmp_path)
    bot.step("X", [100.0])
    (tmp_path / "KILL").touch()

    def boom(*a):
        raise RuntimeError("feed down")

    b.get_price = boom
    b.get_equity = boom
    assert bot.step("X", [100.0])["action"] == "killed"
    assert b.get_position("X") == pytest.approx(0.0)


def test_failed_flatten_still_latches_and_retries(tmp_path):
    class Flaky(m.FakeBroker):
        fail = False

        def submit_order(self, symbol, side, qty):
            if self.fail:
                raise ConnectionError("sell failed")
            return super().submit_order(symbol, side, qty)

    b = Flaky(10_000.0, {"X": 100.0})
    _, bot = make(tmp_path, broker=b)
    bot.step("X", [100.0])
    (tmp_path / "KILL").touch()
    b.fail = True
    with pytest.raises(ConnectionError):
        bot.step("X", [100.0])
    assert bot.killed and b.get_position("X") > 0
    b.fail = False
    assert bot.step("X", [100.0])["action"] == "killed"  # retried, still off
    assert b.get_position("X") == pytest.approx(0.0)


def test_non_finite_weight_is_a_hold(tmp_path):
    b, bot = make(tmp_path, weight=math.nan)
    assert bot.step("X", [100.0])["action"] == "hold"
    assert b.orders == []
