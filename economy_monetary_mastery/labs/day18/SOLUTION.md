# Day 18 — Solution notes

## `to_vnd_prices`
Convert prices, not returns. Reindex the USD/VND series (VND per USD) onto the price dates, forward-fill FX holidays so the last known rate carries across, and multiply: `usd_prices * usdvnd.reindex(usd_prices.index).ffill()`. The result keeps the price index. Common mistake: `usd_prices * usdvnd` without reindexing, which aligns on the union of dates and fills the gaps with NaN; or adding the USD return and the FX return, which drops the cross term. `test_to_vnd_prices` uses an FX series shorter than the prices, so only the forward-fill version returns `[2_500_000, 2_750_000]`.

## `scorecard`
For each name compute `r = simple_returns(p)` and then `cagr(p)`, `annualize_vol(r)`, `sharpe(r)` (zero risk-free rate) and `max_drawdown(p)`. Build a DataFrame in input order with columns `["cagr", "vol", "sharpe", "max_drawdown"]`. Common mistakes: passing prices to `annualize_vol` or `sharpe` (they take returns), passing returns to `cagr` or `max_drawdown` (they take prices), or sorting the index so the input order is lost. `test_scorecard_matches_reference_helpers` compares every cell with the `common.quant` helpers and checks index and column order.

## `hedge_decision`
`"hedge"` if `expected_depreciation > hedge_cost`, else `"stay unhedged"`. Both inputs are annual decimals: the first is the loss you expect on the currency leg (foreign currency falling against home), the second is what the forward hedge costs per year. The inequality is strict: at break-even the hedge removes variance for no expected gain, so the default is to leave it alone. The `0.02, 0.02` case in `test_hedge_decision` catches `>=`.

## What the output means
On the common range 2015-01-05 to 2026-09-29, BTC-USD in VND ranks first on Sharpe (about 1.12) but with an 82% drawdown; SPY in VND (about 0.90) beats SPY in USD (about 0.85) because VND depreciated, so the currency leg added roughly 2 points of CAGR; GLD in VND and the VN-Index follow, and VNM (a USD-listed ETF restated in VND) is last. The ranking depends on the window (a 2020 start moves gold to first) and on survivorship: the assets were picked because they are well-known today. The VN-Index row is a price index in points without dividends, and on the common-date panel each return spans weekends, so the right annualization factor is observations per year (about 242 here, not 252 or 365); 252 inflates every row's vol by about 2% equally, and BTC's panel vol (0.679) is slightly above its native 365-day figure (0.668).
