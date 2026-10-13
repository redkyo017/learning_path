"""Day 18 lab: the cross-currency scorecard.

Goal: put assets quoted in different currencies on one comparable footing. Restate USD prices in VND
(to_vnd_prices), compute CAGR, volatility, Sharpe and maximum drawdown for each (scorecard), and apply
the hedge-or-not rule of thumb from Day 17 (hedge_decision). main() scores SPY (USD and VND), VNM, VN-Index,
GLD and BTC-USD on their common date range since 2015 and prints the table sorted by Sharpe.
Caveats: the Sharpe here uses a zero risk-free rate; VN-Index is a price index in points (no dividends);
the "in VND" rows are cross-currency arithmetic, not a statement that a resident individual may lawfully
hold those assets (Day 17 scope note). Educational, not financial advice.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from common.data import load_prices, load_vn
from common.quant import annualize_vol, cagr, max_drawdown, sharpe, simple_returns

START = "2015-01-01"


def to_vnd_prices(usd_prices: pd.Series, usdvnd: pd.Series) -> pd.Series:
    """Restate a USD price series in VND.

    Align `usdvnd` (VND per USD) to the dates of `usd_prices`, forward-filling FX holidays, then
    multiply. Return a series on the price index. Convert prices, not returns.
    """
    raise NotImplementedError("TODO: usd_prices * usdvnd.reindex(usd_prices.index).ffill()")


def scorecard(prices: dict[str, pd.Series]) -> pd.DataFrame:
    """One row per name (input order) with columns ["cagr", "vol", "sharpe", "max_drawdown"].

    Use common.quant on each price series: cagr(prices), annualize_vol(returns), sharpe(returns),
    max_drawdown(prices), where returns = simple_returns(prices).
    """
    raise NotImplementedError("TODO: per name, apply the four quant helpers; build a DataFrame")


def hedge_decision(expected_depreciation: float, hedge_cost: float) -> str:
    """Return "hedge" or "stay unhedged".

    `expected_depreciation` is the annual loss you expect on the currency leg (foreign currency falling
    against home); `hedge_cost` is the annual cost of the forward hedge. Hedge only if the expected
    loss is strictly greater than the cost.
    """
    raise NotImplementedError("TODO: 'hedge' if expected_depreciation > hedge_cost else 'stay unhedged'")


def main() -> None:
    px = load_prices(["SPY", "VNM", "GLD", "BTC-USD", "VND=X"])
    fx = px["VND=X"].dropna()
    vnindex = load_vn("VNINDEX")

    def usd(tk):
        return px[tk].dropna()

    raw = {
        "SPY (USD)": usd("SPY"),
        "SPY (VND)": to_vnd_prices(usd("SPY"), fx),
        "VNM (VND)": to_vnd_prices(usd("VNM"), fx),
        "VN-Index (points)": vnindex,
        "GLD (VND)": to_vnd_prices(usd("GLD"), fx),
        "BTC-USD (VND)": to_vnd_prices(usd("BTC-USD"), fx),
    }
    df = pd.concat(raw, axis=1, sort=True)
    df = df[df.index >= START].dropna()
    print(f"Common range {df.index[0].date()} to {df.index[-1].date()} ({len(df)} dates)")
    sc = scorecard({k: df[k] for k in df.columns}).sort_values("sharpe", ascending=False)
    print(sc.to_string(float_format=lambda x: f"{x:.3f}"))
    print(f"Hedge rule, VND holder of USD assets (USD expected +2.2%/yr vs VND since 2010, Day 17, i.e. depreciation -2.2%; "
          f"hedge pays +1.3%): {hedge_decision(-0.022, -0.013)}")
    print(f"Hedge rule, expected 5% loss on the currency leg vs 1% cost: {hedge_decision(0.05, 0.01)}")

    reb = df / df.iloc[0] * 100
    fig, ax = plt.subplots(figsize=(9, 5))
    reb.plot(ax=ax, logy=True)
    ax.set_title("Rebased to 100 (log); common date range")
    out = Path(__file__).resolve().parent.parent / ".cache" / "plots"
    out.mkdir(parents=True, exist_ok=True)
    fig.savefig(out / "day18.png", dpi=110, bbox_inches="tight")


if __name__ == "__main__":
    main()
