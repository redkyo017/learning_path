"""Day 09 solution: a limit order book and the cost curve.

Goal: build a price-time-priority matching engine. Resting limit orders form the book; an
incoming order trades against the best opposite price first, at the resting order's price,
first-in first-out within a price level. Then measure what a market order really costs.
Implement the TODO methods; the dataclasses, the book's constructor and main() are given.
"""
from __future__ import annotations

import collections
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


@dataclass
class Order:
    id: str
    side: str                    # "buy" or "sell"
    qty: int
    price: float | None = None   # None = market order


@dataclass(frozen=True)
class Trade:
    buy_id: str
    sell_id: str
    price: float
    qty: int


class OrderBook:
    def __init__(self) -> None:
        # price level -> FIFO queue of resting orders (oldest on the left)
        self.bids: dict[float, collections.deque[Order]] = {}
        self.asks: dict[float, collections.deque[Order]] = {}

    def submit(self, order: Order) -> list[Trade]:
        """Match `order` against the book and return the trades in execution order.

        Raise ValueError if side is not "buy"/"sell" or qty <= 0. Trade against the best
        opposite price while it crosses (a buy crosses asks <= its limit, a sell crosses
        bids >= its limit; a market order always crosses). The trade price is the resting
        order's price; orders at one price fill oldest first; delete emptied levels.
        A limit order's unfilled remainder rests in the book; a market order's is discarded.
        The caller's Order object should not be mutated.
        """
        if order.side not in ("buy", "sell"):
            raise ValueError(f"side must be 'buy' or 'sell', got {order.side!r}")
        if order.qty <= 0:
            raise ValueError(f"qty must be positive, got {order.qty}")
        is_buy = order.side == "buy"
        book = self.asks if is_buy else self.bids      # the side we trade against
        own = self.bids if is_buy else self.asks
        remaining = order.qty                          # work on a copy of the quantity
        trades: list[Trade] = []
        while remaining > 0 and book:
            best = min(book) if is_buy else max(book)  # best opposite price
            if order.price is not None:                # limit order: stop when no longer crossing
                if (is_buy and best > order.price) or (not is_buy and best < order.price):
                    break
            queue = book[best]
            while remaining > 0 and queue:             # FIFO: oldest resting order first
                resting = queue[0]
                fill = min(remaining, resting.qty)
                buy_id, sell_id = (order.id, resting.id) if is_buy else (resting.id, order.id)
                trades.append(Trade(buy_id, sell_id, best, fill))  # price = RESTING price
                resting.qty -= fill
                remaining -= fill
                if resting.qty == 0:
                    queue.popleft()
            if not queue:
                del book[best]                         # never leave an empty level behind
        if remaining > 0 and order.price is not None:  # limit remainder rests; market remainder dies
            own.setdefault(order.price, collections.deque()).append(
                Order(order.id, order.side, remaining, order.price))
        return trades

    def best_bid(self) -> float | None:
        """Highest resting buy price, or None if there are no bids."""
        return max(self.bids) if self.bids else None

    def best_ask(self) -> float | None:
        """Lowest resting sell price, or None if there are no asks."""
        return min(self.asks) if self.asks else None

    def spread(self) -> float | None:
        """best_ask - best_bid, or None if either side is empty."""
        bid, ask = self.best_bid(), self.best_ask()
        return None if bid is None or ask is None else ask - bid

    def depth(self, side: str) -> list[tuple[float, int]]:
        """Aggregate resting quantity per price level for side "buy" or "sell".

        Returns (price, total_qty) tuples, best price first: bids descending, asks ascending.
        """
        if side not in ("buy", "sell"):
            raise ValueError(f"side must be 'buy' or 'sell', got {side!r}")
        book = self.bids if side == "buy" else self.asks
        levels = [(price, sum(o.qty for o in queue)) for price, queue in book.items()]
        return sorted(levels, reverse=(side == "buy"))  # bids high to low, asks low to high


def average_fill_price(trades: list[Trade]) -> float:
    """Quantity-weighted average price of the trades: sum(price*qty) / sum(qty)."""
    total = sum(t.qty for t in trades)
    return sum(t.price * t.qty for t in trades) / total  # sum(p*q) / sum(q)


def build_random_book(rng: np.random.Generator, mid: float = 100.0, tick: float = 0.01,
                      levels: int = 10) -> OrderBook:
    """Random book: `levels` price levels each side, 1-3 orders per level, 50-500 shares each.

    Deeper levels get a bit more size on average, like real books.
    """
    ob = OrderBook()
    n = 0
    for k in range(1, levels + 1):
        for side, sign in (("buy", -1), ("sell", 1)):
            price = round(mid + sign * k * tick, 2)
            for _ in range(int(rng.integers(1, 4))):
                n += 1
                qty = int(rng.integers(50, 500) * (1 + 0.1 * k))
                ob.submit(Order(f"{side[0]}{n}", side, qty, price))
    return ob


def main() -> None:
    sizes = [100, 500, 1000, 2000, 4000, 8000]
    mid = 100.0
    print(f"{'size':>6} {'avg fill':>9} {'slippage bps':>13}")
    slips = []
    for size in sizes:
        rng = np.random.default_rng(42)  # same book for every size: only the size changes
        ob = build_random_book(rng, mid=mid)
        mid_now = (ob.best_bid() + ob.best_ask()) / 2
        trades = ob.submit(Order("mkt", "buy", size))
        filled = sum(t.qty for t in trades)
        avg = average_fill_price(trades)
        slip = (avg / mid_now - 1) * 1e4
        slips.append(slip)
        print(f"{size:>6} {avg:>9.4f} {slip:>13.1f}" + ("" if filled == size else f"  (only {filled} filled)"))

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day09.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.plot(sizes, slips, marker="o")
    ax.set_xlabel("market buy size (shares)")
    ax.set_ylabel("slippage vs mid (bps)")
    ax.set_title("Cost curve of a market order")
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
