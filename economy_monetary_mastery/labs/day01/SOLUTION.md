# Solution notes — Day 01

## `BalanceSheet.apply`
Key idea: an entry is a set of signed changes. It is legal only if the asset changes sum to the liability changes (equity counts as a liability), so the identity assets = liabilities + equity survives. Compute both sums first, raise `UnbalancedError` if `abs(diff) > 1e-9`, and only then mutate with `d[k] = d.get(k, 0) + v`.
Formula: `sum(asset deltas) - sum(liability deltas) == 0`.
Common mistake: mutating the assets dict, then discovering the imbalance on the liability side and raising, which leaves half an entry behind. `test_unbalanced_apply_raises_and_leaves_state_unchanged` catches it. A second mistake is `d[k] += v` on a missing key (KeyError); the first test creates new lines such as `loans`.

## `transfer_deposit`
Key idea: Alice's bank owes her less (deposit down) and holds fewer reserves; Bob's bank owes him more and holds more reserves. Each bank's entry balances by itself, so reuse `apply`. Check reserves before any call.
Formula: payer bank `assets{reserves: -x}, liabilities{deposit:payer: -x}`; payee bank the same with `+x`.
Common mistake: applying the payer side, then raising on the reserve check, or forgetting that the payee bank may have no `deposit:bob` line yet. `test_transfer_without_enough_reserves_raises_and_changes_nothing` catches the first; `test_transfer_moves_deposits_and_reserves` the second.

## `parse_fred_csv`
Key idea: `pd.read_csv(io.StringIO(text), na_values=["."])` turns FRED's missing marker into NaN. Read the second column's header as the series ID, rename the first column to `date` whatever it was called (`observation_date` today, `DATE` in older files), parse it as datetimes, index by it, drop NaN, and name the Series.
Common mistake: forgetting `na_values`, which makes the column strings (`"."` poisons the dtype) so `tolist()` is not floats; or hard-coding the header `DATE`. The test uses `observation_date` and a `.` row.

## What the output means
`main()` prints the latest effective federal funds rate in the snapshot (3.88% on 2026-09-30, in percent per year, not a fraction) and its change against one year earlier (-0.21 percentage points, from 4.09%). "Percentage points" is the right unit for a difference between two rates. The plot starts in 2000 and shows a market rate (the volume-weighted median of overnight fed funds trades) that the Fed steers into its target range with tools such as IORB: near zero after 2008 and 2020, and climbing fast in 2022-23.
