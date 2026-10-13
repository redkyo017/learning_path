# Capstone: from idea to paper deployment

Copy this file, fill every section, and keep it with the journal. Educational template, not financial advice. Write the Hypothesis section BEFORE running any code.

## Hypothesis (written before testing)

- **Idea in one sentence:**
- **Who pays me and why?** (the counterparty and the reason they accept the loss: forced seller, hedger, slow adjuster, leveraged speculator)
- **When should this fail?** (the regime or event that breaks it)
- **The single result that makes me drop it:**

## Data & universe

- **Series and source:** (ticker, snapshot or live, start and end dates)
- **Adjustments:** (splits, dividends; VN closes in the snapshots are already adjusted)
- **Survivorship notes:** (why this asset is in the universe; what dead or delisted assets are missing)
- **Calendar and annualization:** (252 for equities, 365 for native daily crypto)
- **Assumed one-way cost (bps) and where it comes from:**

## Variants tried (all of them)

Every row counts. Include the ones abandoned after a glance. The row count is `n_trials` for the deflated Sharpe.

| # | Date | Variant (rule and parameters) | Asset / window | Headline metric | Kept? |
|---|---|---|---|---|---|
| 1 | | | | | |

Total variants tried (n_trials):

## Report

Paste the output of `run_capstone` (or `uv run python -m day30.lab`) here, unedited.

```
dsr:
is_sharpe:
oos_sharpe:
net_sharpe:
benchmark_sharpe:
n_trades:
max_drawdown:
breakeven_cost_bps:
assumed_cost_bps:
chosen_lookback:
```

## Kill checklist

| # | Rule | Threshold | My value | Pass / fail |
|---|---|---|---|---|
| 1 | deflated_sharpe | dsr >= 0.95 | | |
| 2 | oos_decay | oos_sharpe >= 0.5 * is_sharpe | | |
| 3 | beats_benchmark | net_sharpe > benchmark_sharpe | | |
| 4 | sample_size | n_trades >= 30 | | |
| 5 | drawdown | max_drawdown >= -0.35 | | |
| 6 | cost_survival | breakeven_cost_bps >= 2 * assumed_cost_bps | | |

## Decision

- **Verdict (kill or paper-trade):**
- **If kill:** one paragraph on what the failure taught; what would you change in the hypothesis (not the parameters)?
- **If paper-trade:**
  - **Venue** (Alpaca paper, Binance spot testnet, or a spreadsheet log):
  - **Size** (paper equity, maximum position, maximum order):
  - **Duration** (at least 3 months):
  - **Metrics to compare with the backtest** (Sharpe, turnover, hit rate, realised cost per trade, drawdown):
  - **Stop conditions** (drawdown limit, daily-loss limit, kill file, data failure, date):
  - **Who restarts the bot after a stop, and what must they check first:**

## Investment Policy Statement

Draft for your own planning; a written commitment, not advice. Vietnam context: as of 2026-10 (Day 16 and Day 17), resident individuals have no general legal channel to own foreign securities under Decree 135/2015, so check the US-ETF row with a licensed adviser before assuming it is available. Crypto in Vietnam is under a licensing pilot (Resolution 05/2025/NQ-CP; Day 23), so venue and legal status need checking too. Paper trading is unaffected.

- **Goals** (what the money is for, in VND, with dates):
- **Horizon:**
- **Liquidity needs** (emergency reserve in months of expenses; known large outflows):
- **Risk tolerance** (the maximum drawdown I can sit through without selling, and how I know):
- **Allocation ranges** (minimum and maximum, with a note on what is legally and practically available to you):

| Bucket | Min % | Max % | Availability note |
|---|---|---|---|
| US ETFs | | | |
| VN equities | | | |
| Crypto | | | |
| Cash (VND deposits and equivalents) | | | |

- **Rebalancing rule** (calendar or threshold, and the cost you accept):
- **Rules I will never break** (for example: no leverage, no keys with withdrawal permission, no strategy without a written kill rule):
- **Review date:**
