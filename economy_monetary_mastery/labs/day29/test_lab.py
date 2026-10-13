import json

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def make(tmp_path, weight=0.5, **limits):
    broker = m.FakeBroker(10_000.0, {"X": 100.0})
    bot = m.Bot(broker, lambda h: weight, m.RiskLimits(**limits),
                tmp_path / "log.jsonl", tmp_path / "KILL")
    return broker, bot


def test_buys_to_target_weight(tmp_path):
    b, bot = make(tmp_path)
    r = bot.step("X", [100.0])
    assert (r["action"], r["side"], r["qty"]) == ("order", "buy", pytest.approx(50.0))
    assert b.get_position("X") == pytest.approx(50.0)


def test_weight_is_clipped_to_unit_interval(tmp_path):
    b, bot = make(tmp_path, weight=1.7)
    bot.step("X", [100.0])
    assert b.get_position("X") == pytest.approx(100.0)


def test_position_cap(tmp_path):
    b, bot = make(tmp_path, max_position_notional=2_000.0)
    bot.step("X", [100.0])
    assert b.get_position("X") == pytest.approx(20.0)


def test_order_cap_spreads_over_steps(tmp_path):
    b, bot = make(tmp_path, max_order_notional=1_000.0)
    bot.step("X", [100.0])
    bot.step("X", [100.0])
    assert b.get_position("X") == pytest.approx(20.0)


def test_hold_when_at_target(tmp_path):
    _, bot = make(tmp_path)
    bot.step("X", [100.0])
    assert bot.step("X", [100.0])["action"] == "hold"


def test_sells_when_target_drops(tmp_path):
    b, bot = make(tmp_path)
    bot.step("X", [100.0])
    bot.strategy = lambda h: 0.0
    r = bot.step("X", [100.0])
    assert (r["side"], r["qty"]) == ("sell", pytest.approx(50.0))
    assert b.get_position("X") == pytest.approx(0.0)


def test_daily_loss_kill_switch_flattens_and_stays_off(tmp_path):
    b, bot = make(tmp_path, max_daily_loss=0.2)
    bot.step("X", [100.0])
    b.prices["X"] = 50.0  # equity 7,500 < 8,000 floor
    assert bot.step("X", [100.0, 50.0])["action"] == "killed"
    assert b.get_position("X") == pytest.approx(0.0) and bot.killed
    assert bot.step("X", [100.0, 50.0, 50.0])["action"] == "killed"
    assert len(b.orders) == 2


def test_kill_file(tmp_path):
    b, bot = make(tmp_path)
    bot.step("X", [100.0])
    (tmp_path / "KILL").touch()
    assert bot.step("X", [100.0])["action"] == "killed"
    assert b.get_position("X") == pytest.approx(0.0)


def test_log_lines_are_json(tmp_path):
    _, bot = make(tmp_path)
    bot.step("X", [100.0])
    bot.step("X", [100.0])
    lines = (tmp_path / "log.jsonl").read_text().splitlines()
    assert len(lines) == 2
    for line in lines:
        rec = json.loads(line)
        assert {"ts", "symbol", "action", "side", "qty", "price", "equity"} <= rec.keys()


def test_ccxt_adapter_forces_sandbox():
    class FakeExchange:
        def __init__(self):
            self.calls = []

        def set_sandbox_mode(self, enabled):
            self.calls.append(enabled)

    ex = FakeExchange()
    m.CcxtBroker(ex)
    assert ex.calls == [True]


def test_alpaca_adapter_forces_paper():
    seen = {}

    def factory(**kwargs):
        seen.update(kwargs)
        return object()

    m.AlpacaBroker("key", "secret", client_factory=factory)
    assert seen["paper"] is True
