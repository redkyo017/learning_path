"""Day 12 solution: the meeting-day tape (Block 2 integration).

Goal: turn a fed funds futures price into what the market expected from an FOMC meeting,
compare it with the actual decision to get the surprise, and turn the surprise into an
expected move in stocks, bonds, the dollar and bitcoin. Implement the five TODO functions;
the scenarios and main() are given. Scenarios and sensitivities are hypothetical teaching
numbers, not estimates.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Hypothetical meetings. price: fed funds futures price for the meeting month (100 - the
# month's average expected rate). current: current effective fed funds rate before the meeting, percent.
# decision_bp: what the FOMC actually did. sens: % move per bp of hawkish surprise.
SCENARIOS = [
    {"name": "Priced-in cut", "price": 95.61, "current": 4.50, "meeting_day": 18,
     "days_in_month": 31, "decision_bp": -25.0,
     "sens": {"SPY": -0.10, "TLT": -0.25, "DXY": 0.06, "BTC": -0.20}},
    {"name": "Hawkish hold", "price": 95.59, "current": 4.50, "meeting_day": 16,
     "days_in_month": 30, "decision_bp": 0.0,
     "sens": {"SPY": -0.10, "TLT": -0.25, "DXY": 0.06, "BTC": -0.20}},
    {"name": "Dovish surprise", "price": 95.96, "current": 4.00, "meeting_day": 10,
     "days_in_month": 31, "decision_bp": -25.0,
     "sens": {"SPY": -0.10, "TLT": -0.25, "DXY": 0.06, "BTC": -0.20}},
]


def implied_rate(futures_price: float) -> float:
    """Average fed funds rate (percent) the market expects over the contract month.

    A fed funds future settles at 100 minus the month's average effective rate, so the
    implied rate is 100 - price. Example: price 95.75 means 4.25 percent.
    """
    return 100.0 - futures_price


def meeting_adjusted_implied(month_avg: float, current: float, meeting_day: int,
                             days_in_month: int) -> float:
    """Rate (percent) expected AFTER the meeting, backed out of the month average.

    The month average mixes `current` for days before the meeting and the new rate from
    `meeting_day` on (the decision is effective that day's evening or next day; treat days
    1..meeting_day-1 as old and days meeting_day..days_in_month as new). Solve
    month_avg*D = current*(day-1) + new*(D-day+1) for new.
    Raise ValueError unless 1 <= meeting_day <= days_in_month.
    """
    if not 1 <= meeting_day <= days_in_month:
        raise ValueError("meeting_day must satisfy 1 <= meeting_day <= days_in_month")
    new_days = days_in_month - meeting_day + 1          # days at the new rate
    old_days = meeting_day - 1                          # days at the current rate
    return (month_avg * days_in_month - current * old_days) / new_days


def move_probability(current: float, implied: float, step: float = 0.25) -> float:
    """Signed probability of a one-step move: (implied - current) / step, clipped to [-1, 1].

    Negative means a cut is priced, positive a hike. -0.75 reads "75 percent odds of a cut".
    """
    return max(-1.0, min(1.0, (implied - current) / step))  # beyond one step: clip


def surprise_bp(actual_bp: float, probability: float, step_bp: float = 25.0) -> float:
    """Surprise in basis points: the actual move minus the expected move.

    Expected move = probability * step_bp. Positive is hawkish (tighter than priced),
    negative is dovish.
    """
    return actual_bp - probability * step_bp  # what happened minus what was priced


def asset_reaction_pct(surprise_bp: float, sensitivity_pct_per_bp: float) -> float:
    """Expected percent move of an asset: surprise (bp) times its sensitivity (% per bp)."""
    return surprise_bp * sensitivity_pct_per_bp


def run_scenario(s: dict) -> dict:
    avg = implied_rate(s["price"])
    post = meeting_adjusted_implied(avg, s["current"], s["meeting_day"], s["days_in_month"])
    prob = move_probability(s["current"], post)
    sur = surprise_bp(s["decision_bp"], prob)
    moves = {a: asset_reaction_pct(sur, k) for a, k in s["sens"].items()}
    return {"name": s["name"], "month_avg": avg, "post": post, "prob": prob,
            "surprise": sur, "moves": moves}


def main() -> None:
    rows = [run_scenario(s) for s in SCENARIOS]
    print(f"{'Meeting':<16}{'avg%':>7}{'post%':>8}{'prob':>7}{'surp bp':>9}"
          f"{'SPY%':>7}{'TLT%':>7}{'DXY%':>7}{'BTC%':>7}")
    for r in rows:
        m = r["moves"]
        print(f"{r['name']:<16}{r['month_avg']:7.3f}{r['post']:8.3f}{r['prob']:7.2f}"
              f"{r['surprise']:9.2f}{m['SPY']:7.2f}{m['TLT']:7.2f}{m['DXY']:7.2f}{m['BTC']:7.2f}")
    print("Positive surprise = hawkish. Sensitivities are hypothetical.")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day12.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(8, 4))
    width = 0.2
    assets = list(rows[0]["moves"])
    for i, a in enumerate(assets):
        ax.bar([j + i * width for j in range(len(rows))], [r["moves"][a] for r in rows],
               width, label=a)
    ax.set_xticks([j + 1.5 * width for j in range(len(rows))])
    ax.set_xticklabels([r["name"] for r in rows])
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_ylabel("expected move (%)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
