# Solution notes — Day 03

## `overnight_rate`
Key idea: a piecewise-linear supply/demand picture of the interbank market. With reserves at or above the satiation level, banks are flush, nobody pays more than the central bank pays on reserves, so the rate equals IORB (a floor system). Below satiation each missing dollar makes borrowing slightly more valuable, and the rate drifts linearly up to the ceiling (the rate at which the central bank lends freely) when reserves hit zero.
Formula: `iorb` if `reserves >= satiation`, else `ceiling - (ceiling - iorb) * reserves / satiation`; `ValueError` if `reserves < 0`.
Common mistake: forgetting the `>=` boundary (2500 must give exactly IORB) or the negative check. `test_floor_system_rate_is_iorb_when_reserves_ample` covers the boundary, `test_negative_reserves_rejected` the check, and `test_rate_never_rises_with_more_reserves` catches a slope with the wrong sign.

## `qe_postings`
Key idea: the central bank always gets Treasuries on the asset side and new reserves on the liability side. Who sold decides the rest. A bank seller swaps one asset for another (Treasuries out, reserves in): no deposit exists. A nonbank seller is paid by crediting its deposit, so its bank books new reserves (asset) and a new deposit (liability) at the same time.
Formula: central bank `assets {treasuries: +a}`, `liabilities {reserves:bank: +a}`; bank seller `assets {reserves: +a, treasuries: -a}`; nonbank: bank `assets {reserves: +a}`, `liabilities {deposit:seller: +a}`, seller `assets {treasuries: -a, deposit: +a}`.
Common mistake: creating a deposit in the bank-seller case, or leaving the "seller" entry in it. `test_qe_from_bank_creates_reserves_only` checks both; `test_every_entity_balances` catches any unbalanced entity; `test_unknown_seller_rejected` the `ValueError`.

## `align_weekly`
Key idea: resample each series to weeks ending Wednesday (the day H.4.1 balance sheets are measured) taking the last value, concatenate, forward-fill so a monthly figure carries across its weeks, and drop leading rows where some series has not started.
Formula: `pd.concat({k: s.resample("W-WED").last()}, axis=1).sort_index().ffill().dropna()`.
Common mistake: using `.mean()` (wrong for levels), or `dropna()` before `ffill()` (which deletes every week the monthly series lacks). `test_align_weekly` expects `[2, 9, 13]` for the daily series, the monthly value repeated, and the first row on 2024-01-03.

## What the output means
Year-end 2008 to 2014: total assets rose from about $2.2 trillion to $4.5 trillion and reserves from about $0.85 trillion to $2.6 trillion while the fed funds rate sat near zero: QE built the "ample reserves" regime. By end-2019 QT had shrunk reserves to about $1.65 trillion and the rate was no longer glued to the floor (the Sept 2019 spike). The 2022 row shows the balance sheet at its peak era (about $8.6 trillion; peak $8.97 trillion in April 2022) with $2.3 trillion parked in ON RRP, a sign that cash was abundant. The latest row ($6.7 trillion of assets, $2.9 trillion of reserves, ON RRP usage near zero, fed funds 3.88% vs IORB 3.90%) shows a floor system again, with the rate just under IORB.
