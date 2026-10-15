# Enhancements (parked during authoring review, 2026-10-11)

Items reviewers found but judged cosmetic or tooling-only (LEAVE in the final triage). None is a factual error a learner would memorise.

## Tooling / labs
- check_content heading checks are substring matches; exercise counter can be confused by nested numbering.
- verify_labs: _DIRTY is a substring match; stubs need not fail every test.
- load_impl can leave a half-initialised module in sys.modules if a lab raises at import.
- fetch.parse_vci_chart gives an unclear error on a dict payload; fetch.vn page-cap exhaustion is silent; paging test is weak.
- labs/.python-version pins macOS arm64 (cpython-3.12-macos-aarch64-none); Linux/Intel users should change it.
- data/MANIFEST.md is append-only on re-runs and doesn't say VN closes are dividend/split-adjusted (the day files do).
- Keyword names differ: common.quant uses periods_per_year=, Day 10 lab and common.risk use periods=.
- day09 average_fill_price([]) and day02 bank_run(haircut=1) edge cases are undocumented.
- Several solution.py module docstrings still say 'Implement the TODO functions' (copied from lab.py).

## Content polish
- README Files tree omits labs/.python-version and uv.lock; README:28 repeats the capstone sentence.
- STRATEGY.md:38 'describes' → 'describe'; STRATEGY.md:56 one mildly preachy line.
- Day 5: sources table lacks a row for the AOCI figures; Reserve Primary Fund cited to a vendor page (Crane Data).
- Day 8 Ex.7 'gap came from earnings/composition, not price' stated a bit firmly.
- Day 10: word-cap trims dropped the 'compare with the index, not cash' anti-pattern and an Ex.2 leverage caveat.
- Day 14:98 'flat day 0' wording; Day 18 README Explore mentions START=2020 only.
- Day 15: Turkey 2021 / Argentina 2001-02 history is uncited background knowledge.
- Day 16: Decree 232/2025 and Decree 103/2026 effective dates and 2024 gold-sales figures not independently re-fetched (hedged in text).
- Day 21: restore the 'current collateral mix: unverified' hedge and the 'decentralised ≠ no counterparty' pitfall if word budget allows.
- Day 25: 0 bps 100-day Sharpe 0.69 vs 0.685 rounding; Day 29 Ex.8 sketch leaves key/secret/history undefined.
- Days 8, 12, 14, 24, 29 sit at 2,999–3,000 words: any addition needs an offsetting trim.
