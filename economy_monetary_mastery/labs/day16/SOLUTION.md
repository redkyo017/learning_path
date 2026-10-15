# Lab 16 — Solution notes

## sbv_band
The SBV publishes a central rate each day and lets banks trade within a fixed percentage of it. Formula: `(c*(1-band), c*(1+band))`. Common mistake: dividing by `1+band` or using the band as VND instead of a fraction. The test for 25,000 expects 23,750 and 26,250.

## within_band
Measure the market rate relative to the central rate and compare with the band: `abs(market/central - 1) <= band`. Pandas aligns the two Series on their index. Common mistake: `<` instead of `<=`, or comparing the level difference with the band. The test row 24,500 vs 24,000 (+2.1%) is inside, 25,300 (+5.4%) and 22,700 (-5.4%) are outside.

## hose_tick
A three-bracket lookup: 10 VND below 10,000; 50 VND from 10,000 up to 49,950; 100 VND from 50,000. Common mistake: using `<= 10_000` or `<= 50_000`, which puts the boundary prices in the wrong bracket. The tests at 9,990, 10,000, 49,950 and 50,000 sit on every boundary.

## price_limits
Compute `raw = round(ref*(1±limit), 6)` (the rounding removes float noise: `12000*1.15` is `13799.999999999998`, so without it an UPCoM ceiling floors to 13,700 instead of 13,800), then round inward to the tick that applies at the raw price: ceiling `floor(raw/tick)*tick`, floor `ceil(raw/tick)*tick`. HOSE is 7% with the HOSE ticks; HNX 10% and UPCOM 15%, both with tick 100. Upper-case the exchange name, raise `ValueError` for anything else. Common mistake: rounding to nearest, or using the reference price's tick instead of the raw price's. The 10,250 HOSE case (raw floor 9,532.5 gives 9,540; raw ceiling 10,967.5 gives 10,950) catches both. `test_unknown_exchange` checks the error.

## flag_limit_moves
For each day t >= 1 compute `price_limits(close[t-1], exchange)` and mark True if `close[t]` equals either value. Element 0 has no previous close, so it is False. Common mistake: using the current close as the reference, or comparing returns with a fixed 7%, which ignores tick rounding (a 7% move is not always a valid price). The test mixes a ceiling hit (26,750), a non-hit (27,000) and a floor hit (25,150 from 27,000, where the raw floor 25,110 rounds up to 25,150).

## foreign_room
`max(0, cap*total - foreign)`. A company at or above its cap has zero room, never negative. Common mistake: returning the negative number when foreigners already exceed the cap. The second assertion (30% cap, 300 of 1,000 held) expects 0.

## What the output means
On the snapshot VN-Index rose from about 517 to 1,769 points between 2010 and September 2026, a CAGR near 7.6%, with a maximum drawdown of about 45% (1,204 points on 2018-04-09 to 659 on 2020-03-24, 545 points). Exact-limit counts for FPT, HPG and VCB are zero because the Vietcap closes are dividend/split-adjusted and no longer land on tick prices; the tolerance count (|move| of at least 6.5%) is the usable approximation and shows HPG, the most cyclical of the three, with about 1.4% of days near the limit versus 0.6% to 0.7% for FPT and VCB. The USD/VND band check against a 60-day rolling-mean proxy shows 100% of days inside, which proves only that a proxy built from the market itself cannot show a breach: the real central rate is set by the SBV and can sit well below the market (a secondary source reported 25,433 against a market near 26,235 in August 2026).
