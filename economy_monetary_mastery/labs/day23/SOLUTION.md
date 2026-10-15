# Solution notes — Lab 23

## annualized_funding
**Idea:** funding is paid every period (default three a day on an 8-hour schedule), so the yearly figure is the average rate times periods per day times 365. It is simple, not compounded, and a mean of rates rather than a path. **Formula:** `mean * ppd * 365`. **Common mistake:** hard-coding 3 so another interval breaks, or compounding. `test_annualized_funding` feeds nine rates of 0.01% and expects 0.0001*3*365 = 10.95%; `test_snapshot_funding_is_sane` bounds the result on real data.

## basis_pct / annualized_basis
**Idea:** basis is how far the future trades above spot, relative to spot. Annualizing scales by the fraction of a year the future has left. **Formula:** `(F-S)/S`, then `× 365/days`. **Common mistake:** dividing by the future price, or leaving the zero-days case to a ZeroDivisionError; the test expects 0.02 for (100, 102), 0.02*365/90 for 90 days, and a `ValueError` for 0.

## cash_and_carry_pnl
**Idea:** long spot and short future make price moves cancel: whatever spot gains, the future loses, except for the entry gap. **Formula:** `qty * ((spot_exit - spot_entry) - (fut_exit - fut_entry))`. **Common mistake:** a sign slip on the short leg. The test uses an up move (110) and a down move (80) with entry basis 2 and expects +2 and +4 (qty 2): the answer must not depend on direction.

## funding_pnl
**Idea:** funding moves between the sides of the perpetual. A positive rate means longs pay shorts, so a short collects `notional * rate` and a long pays it; a negative rate reverses it. **Common mistake:** summing absolute values or forgetting the invalid-side error. Rates 0.01%, -0.005%, 0.02% on 10,000 sum to 0.025%, so short +2.5 and long -2.5; "flat" must raise.

## What the output means
On the Binance snapshot, annualized BTC funding was about +31% in 2021 (leveraged-long demand), only about +4% in 2022 although 22% of periods were negative, and +3% in 2026 with a quarter of periods negative. The perp-minus-spot daily close gap is tiny (median about -0.04%): the perpetual is kept close to spot by funding rather than by expiry. A fee-free short-perp, long-spot carry from 2021 earned roughly 62% of notional over 5.7 years (about 11% a year, simple), against +185% for holding BTC: the carry is a low-beta yield, not a substitute for owning the asset, and the figure ignores fees, margin opportunity cost and exchange risk.
