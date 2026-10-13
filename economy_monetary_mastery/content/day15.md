# Day 15 — Impossible trinity, capital controls, currency crises

> Block 3: FX, the dollar & Vietnam. Facts as of 2026-10. Educational, not financial advice.

## Why this matters

Day 13 showed that a forward rate is arithmetic, not a forecast, and Day 14 showed that the dollar sits at the centre of the plumbing. Today asks the obvious next question: what happens when a government says "this exchange rate will not move"? Sometimes it works for decades (Hong Kong). Sometimes it works until a single day (Thailand, 2 July 1997). The difference is not willpower, it is arithmetic about reserves, interest rates and what else the country has promised.

For an investor holding VND assets, US ETFs and crypto, this is the day that explains why a managed currency can look boring for years and then gap 20% in a week, and why emerging-market local-currency bonds pay high yields. Day 16 applies all of this to Vietnam; today only previews it.

## Core concepts

### The regime menu

From most flexible to least:

- **Free float:** the market sets the price; the central bank does not target a level (US dollar, euro, yen, mostly).
- **Managed float:** floating, but the central bank leans against moves and may publish no target.
- **Crawling peg / crawling band:** the central rate moves on a schedule (often by inflation), with a band around it. Vietnam and, since 2025, Argentina use band-type systems.
- **Hard peg:** a fixed rate defended by the central bank at its own discretion; can be abandoned by decision.
- **Currency board:** the monetary base is backed by foreign currency at the fixed rate, by law, and the central bank cannot create money on its own (Hong Kong today; Bulgaria until the end of 2025, when it adopted the euro).
- **Dollarization:** the country drops its own currency and uses another (Ecuador, El Salvador, Panama). No exchange rate, no central bank policy.
- **Monetary union:** several countries share one currency and one central bank (the euro area, 21 members since Bulgaria joined on 1 January 2026 per the [European Commission](https://trade.ec.europa.eu/access-to-markets/en/news/bulgaria-adopts-euro-1-january-2026)). Members lose the exchange rate and the policy rate together.

### The impossible trinity

A country cannot have all three at once:

```
                 Fixed exchange rate
                    /          \
          (Hong Kong)          (China pre-reform:
          peg + open            peg + own policy,
          no own policy         capital controls)
                  /              \
   Open capital  ---------------  Independent monetary policy
     account          (US: float + open + own policy)
```

The logic is the UIP arithmetic from Day 13. If capital moves freely and the rate is fixed, investors will arbitrage any gap between the domestic and the foreign rate, so the domestic rate has to equal the foreign rate (plus a risk premium): policy is imported. If the country wants its own rate, then either the currency must float (so the rate gap is offset by expected movement) or capital must be blocked (so there is no arbitrage). Pick two:

| Country | Fixed FX | Open capital | Own policy | Gives up |
|---|---|---|---|---|
| Hong Kong | yes (HKD 7.75–7.85 per USD) | yes | no | independent policy |
| United States | no (float) | yes | yes | fixed rate |
| China | managed against a basket | no (controls) | mostly | free capital |
| Vietnam | managed band | partial | partly | a mix: managed band, partial capital controls, partly independent policy (Day 16) |

Real countries sit between the corners. Vietnam is a managed-band, partial-controls case; the central-bank toolkit, the band and the exchanges are Day 16. The lab's `trinity_violation(fixed, open, independent)` is true only when all three are claimed.

**Hong Kong, verified:** the HKMA stands ready to sell HKD to banks at 7.75 per USD (strong side) and buy HKD from banks at 7.85 (weak side), and the monetary base is fully backed by USD assets ([HKMA, how the LERS works](https://www.hkma.gov.hk/eng/key-functions/money/linked-exchange-rate-system/how-does-the-lers-work/); the band was set in 2005, see the [HKMA press release](https://www.hkma.gov.hk/eng/news-and-media/press-releases/2005/05/20050518-4)). Between the two undertakings the HKD floats; at the edges the interest rate does the work automatically, which is exactly "no independent policy".

### Reserves, intervention and sterilization

To hold a currency up, the central bank sells foreign reserves and buys its own currency. Reserves are finite; the domestic currency is not, which is the asymmetry that makes pegs vulnerable to attack on the weak side. (Defending against appreciation is easy: print the currency and buy dollars. The cost shows up as inflation.)

When the central bank buys dollars (to stop appreciation) the domestic money supply expands. **Sterilization** offsets that by selling bonds or issuing bills to absorb the new money:

```
  Central bank, intervention (buys USD with new VND)
  Assets            | Liabilities
  FX reserves  +100 | Bank reserves (VND)  +100

  Sterilization (sells bills, absorbs the reserves)
  Assets            | Liabilities
  (unchanged)       | Bank reserves  -100
                    | Central bank bills +100
```

Sterilization keeps the policy rate from being dragged by the peg, but it costs interest on the bills and works only while buyers exist, so it cannot be sustained for long.

### Why pegs break: three generations of models

Plain English, in the order economists discovered them:

1. **First generation (Krugman, 1979): fundamentals.** The government runs persistent deficits and finances them by printing money, while promising a fixed rate. Reserves drain steadily. Speculators know the peg will end and attack just before reserves hit the floor, so it ends in a sudden run, not a slow fade. Lesson: the break date is set by the reserve stock, and markets can see it. Latin America in the 1970s–80s.
2. **Second generation (Obstfeld, 1994): self-fulfilling.** The government weighs the cost of holding the peg (high rates, unemployment) against the gain. If enough people expect devaluation, interest rates must rise, which raises the cost, which tips the government to give up. Expectations alone can cause the break. Europe's ERM in 1992 is the canonical case.
3. **Third generation (Asia, 1997): balance sheets.** Firms and banks borrow in dollars short-term, lend in local currency long-term, and trust the peg to hide the mismatch. A fall in the currency inflates dollar debts, bankrupts borrowers, and the banking crisis and the currency crisis feed each other. Lesson: the peg's own stability encourages the borrowing that kills it.

The mechanical backbone, used in the lab: reserves fall by each period's net outflow; when the next outflow would take them below the floor (the level where the authorities stop) the peg ends.

### Can interest rates defend the peg?

Under UIP, to make holders indifferent to expected depreciation the domestic rate has to rise to `(1 + r_foreign)(1 + expected depreciation) - 1` (the lab's `rate_to_defend`). Expect 30% depreciation with a 5% foreign rate and the required rate is 36.5%, not 35%, because the two compound. That rate is only credible if the economy can survive it: banks face higher funding cost, borrowers default, government debt service balloons. When the market sees that the authorities cannot tolerate such rates, a rate hike signals weakness and can accelerate the exit. A high rate defends a currency only when it is believed to be sustainable.

### Reserve adequacy: rules of thumb

- **Import cover:** reserves of at least about **3 months of imports**, a traditional guide for trade-driven shocks (the lab's `import_cover_months`).
- **Greenspan–Guidotti:** reserves should at least equal **short-term external debt** (maturity within one year, counting amortizing long debt due within the year), so the country can ride out a full refusal to roll over.
- The IMF's reserve-adequacy metric combines these ideas: short-term debt, other portfolio liabilities, broad money and exports, weighted by regime and capital-control status ([IMF, reserve adequacy page](https://www.imf.org/external/np/spr/ara)).

Import cover looked fine in Thailand and nearly every other crisis country, because the runs came from short-term capital, not trade. Both rules matter; the debt rule is the more important one in a crisis.

### Capital controls

Controls restrict cross-border flows: limits on residents buying foreign currency, taxes on inflows, reporting rules, bans on offshore lending. They buy a country the second corner of the trinity (own policy plus a managed rate) at the price of the third, and they leak (trade invoicing, informal channels, crypto). Their credibility matters as much as their text: controls introduced mid-crisis (Malaysia 1998) are read differently from standing controls (China).

## Case studies

### Thailand, 1997

The baht was pegged to a basket dominated by the dollar. Capital was opened in 1993, banks and finance companies borrowed dollars short-term and lent into property, and the current account ran a large deficit. As the dollar strengthened in 1996–97 and exports slowed, speculators sold baht forward; the central bank defended spot by selling reserves while committing the rest in forward contracts, which hid the real depletion from public reserve statistics. On **2 July 1997 Thailand floated the baht**; it fell sharply, contagion hit the Philippines, Malaysia, Indonesia and Korea, and an IMF programme followed in August. This is a textbook third-generation crisis on a first-generation reserve-drain script (a [TDRI account](https://www.tdri.or.th/wp-content/uploads/2013/01/m50.pdf) puts net official reserves (after netting forward commitments) at only US$2.9 billion at end-June 1997, to be compared with about US$36.5 billion of gross short-term foreign debt; the [IMF](https://www.imf.org/en/News/Articles/2015/09/14/01/49/pr9737) describes the baht depreciating about 20% against the dollar during July; other accounts say 15–20%).

### Argentina: convertibility, collapse, and the current band

The 1991 **convertibility** law fixed the peso at 1 per USD under a currency-board-like rule that backed the base with reserves. It stopped hyperinflation, but it removed the exchange rate as a shock absorber; after the 1998–99 Brazilian devaluation and a strong dollar, Argentina slid into recession, deposits fled, a bank freeze came in late 2001, the country defaulted, and convertibility ended in January 2002. Since then Argentina has cycled through multiple exchange-rate regimes, parallel markets and capital controls.

Current status, **verified for 2026-10**: Argentina runs an **exchange-rate band regime**, launched 11 April 2025, under which the peso floats between a floor and a ceiling; the BCRA buys USD at the floor and sells USD at the ceiling. From 1 January 2026 the ceiling rises and the floor falls each month by the latest INDEC monthly inflation figure (two-month lag). The BCRA's page (last updated 10 September 2026) projects a floor of ARS 723.88 and a ceiling of ARS 1,920.44 per USD for 1 October 2026 ([BCRA, exchange rate band regime](https://www.bcra.gob.ar/en/exchange-rate-band-regime/)). In the plain-English taxonomy, this is a wide managed band with a crawling ceiling, not a hard peg. The [PIIE analysis](https://www.piie.com/blogs/realtime-economics/2026/argentinas-fragile-monetary-framework-risks-renewed-volatility) notes the scheme can work with external financing support but adds new vulnerabilities.

### Turkey: unorthodox rates and the lira

Textbook theory says to raise rates when inflation is high and the currency is falling. In late 2021 Turkey did the reverse: the policy rate was cut from 19% to 14% while inflation climbed, on the view that high rates cause inflation. The lira lost roughly 44% of its value against the dollar in 2021; savers fled to FX, and the government created FX-protected lira deposits so that savers would stay in lira, shifting the depreciation risk to the budget and central bank. Reserves, net of swaps, fell hard. After the May 2023 election the central bank returned to tight policy and raised the one-week repo rate to 50% in March 2024.

Current status, **verified for 2026-10**: the one-week repo rate is **37%**, cut 100 bp from 38% to 37% on 22 January 2026 (the fifth straight cut, after cumulative easing from 46% in July 2025; [Bloomberg](https://www.bloomberg.com/news/articles/2026-01-22/turkey-lowers-key-interest-rate-to-37-in-fifth-straight-cut), [Daily Sabah](https://www.dailysabah.com/business/economy/turkish-central-bank-cuts-key-interest-rate-to-37-less-than-expected)) and unchanged since; the 10 September 2026 meeting held it for a fifth straight time with the overnight lending rate at 40% ([Intellinews, 10 September decision](https://new.intellinews.com/articles/turkish-central-bank-sticks-to-37-policy-rate-for-fifth-straight-time-467058)). The central bank resumed one-week repo auctions on 23 August, so the 37% rate is again the marginal funding cost (same source family: [Intellinews, auctions revived](https://www.intellinews.com/turkey-revives-one-week-repo-auctions-463063/)). Regime: managed float with heavy intervention. The next scheduled meeting, 22 October 2026, has not happened as of this writing.

## Worked example

The lab's Thailand-style scenario (**stylized, not historical data**): reserves 38 bn USD, floor 12 bn, net outflows per period `[3, 5, 6, 8, 9, 10]`, foreign rate 5%, expected depreciation 30% if the peg falls, monthly imports 5 bn.

```
step  outflow   reserves after   vs floor 12
  1      3          35              ok
  2      5          30              ok
  3      6          24              ok
  4      8          16              ok
  5      9          16 - 9 = 7      7 < 12  -> peg breaks at step 5
```

`defend_peg(38, [3,5,6,8,9,10], 12)` returns `(5, [35, 30, 24, 16])`. Rate needed to hold: `1.05 * 1.30 - 1 = 36.5%`. Import cover at the start: `38 / 5 = 7.6 months`, which is far above the 3-month rule, yet the peg still breaks: the outflow is capital, not trade. If short-term external debt in this stylized economy were 30 bn, Greenspan–Guidotti cover would be `38 / 30 = 1.27`, only just above 1 and nothing like comfortable once forward commitments are counted. Run `uv run python -m day15.solution` for all three scenarios.

## Exercises

1. **Classify.** A country fixes its currency to the dollar, bans most capital outflows, and sets its own interest rate. Which trinity corners does it hold, and which does it give up? **Hint:** tick the three boxes. **Solution sketch:** fixed rate and independent policy held; open capital given up. `trinity_violation(True, False, True)` is False. This is China's pre-2005 shape.
2. **Break step.** `defend_peg(80, [10, 15, 20, 25], floor=20)`: at which step does the peg break and what is the returned path? **Hint:** check `reserves - outflow < floor` before subtracting. **Solution sketch:** 80 to 70 to 55 to 35 pass; at step 4, 35 - 25 = 10 < 20, so `(4, [70, 55, 35])`.
3. **Cost of defence.** Foreign rate 4%, market expects 15% depreciation. What domestic rate holds the peg, and how far off is the additive guess? **Hint:** compound. **Solution sketch:** 1.04 * 1.15 - 1 = 19.6%; the additive guess of 19% understates by 0.6 points, which adds up quickly on a large borrowed position.
4. **Sterilization T-account.** A central bank buys 50 of USD to stop appreciation, then sterilizes. Draw both entries. **Hint:** reserves rise first; then bank reserves fall and bills rise. **Solution sketch:** assets FX +50 with bank reserves +50; sterilization swaps bank reserves -50 for bills +50. Net: reserves up, base unchanged, the bank pays interest on the bills.
5. **Greenspan–Guidotti.** Reserves 60, short-term external debt 80, monthly imports 15. Compute both coverage ratios and judge. **Hint:** two divisions, two rules. **Solution sketch:** import cover 60/15 = 4.0 months passes the 3-month rule; debt cover 60/80 = 0.75 fails Greenspan–Guidotti. The country is vulnerable to a rollover refusal even though trade looks safe.
6. **Which generation?** (a) Persistent deficits financed by printing, reserves falling for years. (b) A peg that breaks because everyone expects a break and rates would have to be unaffordable. (c) Banks with unhedged dollar loans. **Hint:** match to deficits, expectations, balance sheets. **Solution sketch:** (a) first generation; (b) second; (c) third.
7. **Edge case.** `import_cover_months(90, 0)` raises `ValueError`. Why is raising better than returning infinity? **Hint:** think of who reads the number. **Solution sketch:** zero imports is bad data or a modelling error, not "infinite safety"; failing loudly prevents a nonsense ratio flowing into a dashboard.

## Anti-patterns / Common mistakes

- **"A peg is stable until it isn't."** Years of calm are evidence about the past, not about reserves versus claims. Track reserve stock against the floor, not the volatility of the rate.
- **Ignoring short-term external debt.** Import cover looked healthy in 1997; short-term dollar debt was the run risk. Always compare reserves to debt due within a year.
- **Believing high rates always defend a peg.** A hike defends only if believed sustainable; if it signals distress, it speeds the exit. Use the compounded UIP rate to see what is being asked.
- **Reading a reserve figure as free money.** Reserves committed in forwards or swaps are not available (Thailand 1997, Turkey's swap-adjusted reserves).
- **Treating the regime label as the whole story.** "Managed float" covers everything from tidy to heavily controlled. Read the intervention behaviour, not the IMF category.

## Lab

Open `labs/day15/README.md`. Implement `trinity_violation`, `defend_peg`, `rate_to_defend` and `import_cover_months`, then run `uv run python -m day15.lab`. The three scenario paths are stylized, not historical data; the plot shows reserves against floors.

## Teardown

Nothing billable is created.

## Journal prompt

Pick one currency you hold exposure to (VND, USD, a stablecoin). In three sentences: which trinity corner does its issuer give up, which reserve rule would you check first, and what single number would make you worry?
