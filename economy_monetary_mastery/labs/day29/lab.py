"""Day 29 lab: a paper-trading bot with a kill switch.

Goal: build the risk layer of a trading bot -- target weight to order size, position and order
caps, a daily-loss kill switch, a kill file, and a JSON-lines audit log -- against a Broker
interface, so the same Bot runs on FakeBroker (tests), Alpaca paper or the Binance spot testnet.
Phase 1 is paper only: the adapters below force paper/sandbox mode. Educational, not financial
advice. With no CLI arguments main() replays the BTC snapshot through FakeBroker; it never
touches a network. See the README Safety section before using --venue.
"""
import argparse
import json
import math
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Protocol

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from common.data import load_crypto_ohlcv


class Broker(Protocol):
    def get_price(self, symbol: str) -> float: ...
    def get_position(self, symbol: str) -> float: ...
    def get_equity(self) -> float: ...
    def submit_order(self, symbol: str, side: str, qty: float) -> str: ...


class FakeBroker:
    def __init__(self, cash: float, prices: dict[str, float]):
        self.cash = cash
        self.prices = dict(prices)
        self.positions: dict[str, float] = {}
        self.orders: list[tuple[str, str, str, float, float]] = []

    def get_price(self, symbol):
        return self.prices[symbol]

    def get_position(self, symbol):
        return self.positions.get(symbol, 0.0)

    def get_equity(self):
        return self.cash + sum(q * self.prices[s] for s, q in self.positions.items())

    def submit_order(self, symbol, side, qty):
        if qty <= 0 or side not in ("buy", "sell"):
            raise ValueError(f"bad order {side} {qty}")
        px = self.prices[symbol]
        signed = qty if side == "buy" else -qty
        self.positions[symbol] = self.get_position(symbol) + signed
        self.cash -= signed * px
        oid = f"fake-{len(self.orders) + 1}"
        self.orders.append((oid, symbol, side, qty, px))
        return oid


class CcxtBroker:
    """Crypto exchange adapter. ALWAYS sandbox/testnet in Phase 1."""

    def __init__(self, exchange):
        exchange.set_sandbox_mode(True)  # never remove: Phase 1 is testnet-only
        self.ex = exchange

    def get_price(self, symbol):
        return float(self.ex.fetch_ticker(symbol)["last"])

    def get_position(self, symbol):
        base = symbol.split("/")[0]
        return float(self.ex.fetch_balance()["total"].get(base, 0.0))

    def get_equity(self):
        raise NotImplementedError("Equity across assets is exchange-specific; "
                                  "supply quote balance + position × price yourself.")

    def submit_order(self, symbol, side, qty):
        return self.ex.create_order(symbol, "market", side, qty)["id"]


class AlpacaBroker:
    """US equities adapter. ALWAYS paper in Phase 1."""

    def __init__(self, api_key, secret_key, client_factory=None):
        if client_factory is None:
            from alpaca.trading.client import TradingClient as client_factory
        self.client = client_factory(api_key=api_key, secret_key=secret_key, paper=True)
        self._keys = (api_key, secret_key)

    def get_price(self, symbol):
        from alpaca.data.historical import StockHistoricalDataClient
        from alpaca.data.requests import StockLatestTradeRequest
        data = StockHistoricalDataClient(*self._keys)
        return float(data.get_stock_latest_trade(
            StockLatestTradeRequest(symbol_or_symbols=symbol))[symbol].price)

    def get_position(self, symbol):
        try:
            return float(self.client.get_open_position(symbol).qty)
        except Exception:  # no open position
            return 0.0

    def get_equity(self):
        return float(self.client.get_account().equity)

    def submit_order(self, symbol, side, qty):
        from alpaca.trading.enums import OrderSide, TimeInForce
        from alpaca.trading.requests import MarketOrderRequest
        req = MarketOrderRequest(symbol=symbol, qty=qty, time_in_force=TimeInForce.DAY,
                                 side=OrderSide.BUY if side == "buy" else OrderSide.SELL)
        return str(self.client.submit_order(req).id)


@dataclass
class RiskLimits:
    max_position_notional: float = math.inf  # cap on |position| * price
    max_order_notional: float = math.inf     # cap on one order's notional
    max_daily_loss: float = 0.05             # kill when equity < start-of-day * (1 - this)
    min_order_notional: float = 10.0         # smaller trades are holds (avoids dust orders)


class Bot:
    """Risk-checked trading bot: strategy -> target -> risk checks -> orders -> log."""

    def __init__(self, broker, strategy: Callable[[list[float]], float], limits: RiskLimits,
                 log_path: Path, kill_file: Path):
        self.broker = broker
        self.strategy = strategy  # reassignable: history -> target weight
        self.limits = limits
        self.log_path = Path(log_path)
        self.kill_file = Path(kill_file)
        self.killed = False
        self.day_start_equity = broker.get_equity()

    def new_day(self) -> None:
        """Reset the start-of-day equity that the daily-loss limit is measured against."""
        self.day_start_equity = self.broker.get_equity()

    def step(self, symbol: str, history: list[float]) -> dict:
        """Run one decision cycle and return {"action", "side", "qty"}.

        Order: (1) if killed or the kill file exists (check this BEFORE fetching any market data) ->
        set killed, flatten, log, return action "killed"; (2) if equity < day_start_equity*(1-max_daily_loss) -> same kill path;
        (3) w = clip(strategy(history), 0, 1), a non-finite w is a hold; target_qty = min(w*equity, max_position_notional)
        / price; delta = target_qty - position; if |delta|*price < min_order_notional -> "hold";
        else clip |delta| to max_order_notional/price and submit; (4) log every step with keys
        symbol, action, side, qty, price, equity.

        Kill path must survive a dead feed: price and equity are best-effort (None if the feed fails),
        latch `killed` before flattening, and let a failed sell raise.
        """
        raise NotImplementedError("TODO: kill checks, weight -> target -> capped order, log")

    def _flatten(self, symbol: str, price: float | None) -> None:
        """Sell the entire position in `symbol` (no-op when flat). `price` is for the caller's log."""
        raise NotImplementedError("TODO: sell the whole position if one exists")

    def _log(self, record: dict) -> None:
        """Append `record` plus an ISO-8601 'ts' as one JSON line to self.log_path."""
        raise NotImplementedError("TODO: append one JSON line with an ISO ts")


def momentum_weight(history: list[float], window: int = 50) -> float:
    """1.0 if the last price is above its level `window` days ago, else 0.0 (long/flat)."""
    if len(history) <= window:
        return 0.0
    return 1.0 if history[-1] > history[-1 - window] else 0.0


def replay(days: int = 365, log_path: Path | None = None):
    """Replay the BTC snapshot day by day through FakeBroker. Offline, no network."""
    df = load_crypto_ohlcv("BTC/USDT")
    closes = df["close"].astype(float).tolist()[-(days + 50):]
    dates = list(df.index[-(days + 50):])
    broker = FakeBroker(10_000.0, {"BTC": closes[0]})
    log_path = log_path or Path(".cache/day29_bot.jsonl")
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text("")
    kill_file = log_path.with_name("day29_KILL")
    bot = Bot(broker, momentum_weight, RiskLimits(max_daily_loss=0.15), log_path, kill_file)
    equity, results = [], []
    for i in range(50, len(closes)):
        bot.new_day()  # the day starts at the PREVIOUS close ...
        broker.prices["BTC"] = closes[i]  # ... then today's price arrives
        results.append(bot.step("BTC", closes[: i + 1]))
        equity.append(broker.get_equity())
    return dates[50:], closes[50:], equity, results, broker, bot


def build_venue(venue: str):
    """PAPER/TESTNET PATH ONLY. Not run by tests or by the default main()."""
    from dotenv import load_dotenv
    load_dotenv()
    if venue == "ccxt":
        import ccxt
        ex = ccxt.binance({"apiKey": os.environ["BINANCE_TESTNET_API_KEY"],
                           "secret": os.environ["BINANCE_TESTNET_SECRET"]})
        return CcxtBroker(ex)
    if venue == "alpaca":
        return AlpacaBroker(os.environ["ALPACA_API_KEY"], os.environ["ALPACA_SECRET_KEY"])
    raise ValueError(f"unknown venue {venue!r}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--venue", choices=["ccxt", "alpaca"],
                        help="PAPER/TESTNET adapter; read the README Safety section first")
    args = parser.parse_args()
    if args.venue:
        broker = build_venue(args.venue)
        print(f"Adapter ready: {type(broker).__name__} (paper/sandbox enforced). "
              "The CLI places no orders; wire the adapter into Bot yourself.")
        return
    dates, closes, equity, results, broker, bot = replay()
    n_orders = sum(r["action"] == "order" for r in results)
    n_hold = sum(r["action"] == "hold" for r in results)
    print(f"Replay {dates[0].date()} -> {dates[-1].date()} on FakeBroker (no network)")
    print(f"decisions: {len(results)}  orders: {n_orders}  holds: {n_hold}  killed: {bot.killed}")
    print(f"final equity: {equity[-1]:,.0f} from 10,000   buy&hold: "
          f"{10_000 * closes[-1] / closes[0]:,.0f}")
    print(f"log lines: {len(bot.log_path.read_text().splitlines())} -> {bot.log_path}")
    out = Path(".cache/plots")
    out.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(dates, equity, label="bot equity")
    ax.plot(dates, [10_000 * c / closes[0] for c in closes], label="buy & hold", alpha=0.6)
    ax.set_title("Day 29: momentum bot replay on FakeBroker")
    ax.legend()
    fig.savefig(out / "day29.png", dpi=110, bbox_inches="tight")


if __name__ == "__main__":
    main()
