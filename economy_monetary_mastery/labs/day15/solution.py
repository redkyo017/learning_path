"""Day 15 solution: the impossible trinity and a peg under attack.

Goal: encode the trinity as a logical test, simulate a central bank defending a peg
with its reserves until they would cross a floor, and compute the interest rate that
uncovered interest parity says is needed to hold the peg, plus import cover. Implement
the four TODO functions; the scenarios and main() are given. Scenario numbers are
stylized, not historical data.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Stylized, not historical data: three crisis-shaped scenarios. Money amounts are in
# USD billions. outflows: net reserve loss per period (negative would be an inflow).
# floor: the reserve level at which the authorities give up. expected_dep: annual
# depreciation the market expects if the peg breaks. monthly_imports: USD bn per month.
SCENARIOS = [
    {"name": "Thailand-style 1997", "reserves": 38.0, "outflows": [3.0, 5.0, 6.0, 8.0, 9.0, 10.0],
     "floor": 12.0, "r_foreign": 0.05, "expected_dep": 0.30, "monthly_imports": 5.0},
    {"name": "Argentina-style", "reserves": 30.0, "outflows": [2.0, 3.0, 3.0, 4.0, 5.0, 6.0],
     "floor": 10.0, "r_foreign": 0.05, "expected_dep": 0.50, "monthly_imports": 6.0},
    {"name": "Turkey-style", "reserves": 60.0, "outflows": [4.0, -2.0, 5.0, 3.0, 6.0, 2.0],
     "floor": 15.0, "r_foreign": 0.05, "expected_dep": 0.25, "monthly_imports": 20.0},
]


def trinity_violation(fixed_fx: bool, open_capital: bool, independent_policy: bool) -> bool:
    """True if a regime claims all three corners of the impossible trinity at once.

    The three goals are a fixed exchange rate, free capital movement and an independent
    domestic monetary policy. Any two are feasible; all three together are not.
    """
    # The trinity: any two corners are feasible, all three are not.
    return all((fixed_fx, open_capital, independent_policy))


def defend_peg(reserves: float, outflows: list[float], floor: float) -> tuple[int | None, list[float]]:
    """Spend reserves period by period until the next outflow would cross the floor.

    Returns (break_step, path). Steps are 1-indexed. If reserves - outflow would fall
    below `floor` at step k, return (k, path) where path holds the reserve levels after
    each successful earlier step (it does not include the failing step). If every step
    succeeds return (None, path) with all levels. A negative outflow is an inflow.
    """
    path: list[float] = []
    for step, out in enumerate(outflows, start=1):
        if reserves - out < floor:
            return step, path  # the failing step is not recorded
        reserves -= out
        path.append(reserves)
    return None, path


def rate_to_defend(r_foreign: float, expected_depreciation: float) -> float:
    """Domestic interest rate that offsets expected depreciation (UIP, compounded).

    (1 + r_domestic) = (1 + r_foreign) * (1 + expected_depreciation); return r_domestic.
    """
    # Compounded UIP: the carry must cancel expected depreciation.
    return (1 + r_foreign) * (1 + expected_depreciation) - 1


def import_cover_months(reserves: float, monthly_imports: float) -> float:
    """Months of imports the reserves can pay for. Raise ValueError if imports <= 0."""
    if monthly_imports <= 0:
        raise ValueError("monthly_imports must be positive")
    return reserves / monthly_imports


def run_scenario(s: dict) -> dict:
    step, path = defend_peg(s["reserves"], s["outflows"], s["floor"])
    return {"name": s["name"], "break_step": step, "path": [s["reserves"]] + path,
            "rate": rate_to_defend(s["r_foreign"], s["expected_dep"]),
            "cover": import_cover_months(s["reserves"], s["monthly_imports"])}


def main() -> None:
    rows = [run_scenario(s) for s in SCENARIOS]
    print("Stylized scenarios, not historical data (USD bn).")
    print(f"{'Scenario':<22}{'break step':>11}{'rate to hold':>14}{'import cover (mo)':>19}")
    for r in rows:
        brk = "holds" if r["break_step"] is None else str(r["break_step"])
        print(f"{r['name']:<22}{brk:>11}{r['rate'] * 100:13.1f}%{r['cover']:19.1f}")
    print("Trinity check (fixed, open, independent): "
          f"Hong Kong-style (T,T,F) violates: {trinity_violation(True, True, False)}; "
          f"all three claimed (T,T,T) violates: {trinity_violation(True, True, True)}")

    out = Path(__file__).resolve().parents[1] / ".cache" / "plots" / "day15.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(8, 4))
    for s, r in zip(SCENARIOS, rows):
        ax.plot(range(len(r["path"])), r["path"], marker="o", label=r["name"])
        ax.axhline(s["floor"], linestyle=":", linewidth=0.8, color="grey")
    ax.set_xlabel("period")
    ax.set_ylabel("reserves (USD bn, stylized)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out)
    print(f"Saved plot to {out}")


if __name__ == "__main__":
    main()
