# Solution notes — Day 12

## `implied_rate`
Key idea: a fed funds future settles at 100 minus the average effective fed funds rate over its month, so the price is a quoted forecast of that average. Formula: `100 - price`. Common mistake: returning a decimal (0.0425) when the contract and the other functions use percent. `test_implied_rate` expects 4.25 for 95.75.

## `meeting_adjusted_implied`
Key idea: the month average blends the old rate for the days before the decision with the new rate for the remaining days, so the new rate is hidden inside it. Formula: `(avg*D - current*(day-1)) / (D-day+1)`. Raise `ValueError` unless `1 <= day <= D`. Common mistake: using `day` instead of `day-1` for the old-rate days (off by one), or dividing by `D-day`. `test_meeting_adjustment_recovers_post_meeting_rate` (15 days at 4.50, 15 at 4.25) catches the off-by-one; `test_meeting_day_bounds` catches the missing validation. Note the amplification: with few days after the meeting, a tiny price error becomes a big rate error.

## `move_probability`
Key idea: if one step is 25 bp and the market expects 4.3125 against 4.50, it expects 18.75 bp of easing, i.e. 75 percent odds of one cut. Formula: `clip((implied-current)/step, -1, 1)`. Common mistake: forgetting the clip, so an implied rate far below current yields -2 ("200 percent"). `test_move_probability` includes 4.00 against 4.50, which must return -1.

## `surprise_bp`
Key idea: the market is already pricing the expected move, so only the difference moves prices. Formula: `actual_bp - probability*step_bp`. Common mistake: using the sign convention backwards or ignoring the probability (treating any cut as dovish). The tests pin a fully priced cut at 0 and a hold against 75 percent cut odds at +18.75 (a "hawkish hold").

## `asset_reaction_pct`
Key idea: a linear first approximation: surprise in bp times the asset's historical percent move per bp. Formula: the product. Common mistake: dropping the sign of the sensitivity; a dovish (negative) surprise times a negative equity sensitivity must give a gain, which `test_reaction` checks (0.625).

## What the output means
The "Priced-in cut" row has a futures price implying about 97 percent odds of a cut, the FOMC cuts, and the surprise is under one basis point, so every asset's expected move is about zero: the decision itself carried no news. The "Hawkish hold" row has about 72 percent cut odds priced and a hold, a +18 bp hawkish surprise, so the hypothetical sensitivities give stocks -1.8 percent, long bonds -4.5 percent, the dollar +1.1 percent and bitcoin -3.6 percent. The "Dovish surprise" row has a small hike priced and a cut, a -30.6 bp surprise and large gains. The sensitivities are made up for teaching; the point is the shape: moves scale with the surprise, not with the decision.
