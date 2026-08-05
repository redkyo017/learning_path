# Quantum Computing Foundations — Content & Primer-Readiness Review

**Date:** 2026-08-05 · **Scope:** all 15 day files (full-depth math audit), README, 3 code labs (static), cross-day pass · **Rubric for Part 2:** `docs/superpowers/guides/encoding-primers-playbook.md` (repo root)
**Full finding texts:** `findings/dayNN.md`, `findings/cross-day.md` (this file carries one-line versions; the findings files carry the complete derivations and fixes)

## Verdict

The path is fundamentally sound: five independent auditors re-derived essentially every proof, matrix, probability, and pipeline in the 15 files, and the overwhelming majority checks out exactly — including all three code labs, whose logic matches the content's claims. The defects found are localized and fixable, not structural: **7 critical** findings (a reversibility misstatement, a promise-scope error that appears on both Day 2 and Day 8, an off-by-one degrees-of-freedom count, a sign typo in a model answer, a wrong angle in a Grover solution, and a continued-fraction computation that teaches a method that fails in general), **5 major** (two garbled counts in Day 1, two genuine prerequisite gaps — the partial-measurement rule and NP — and one under-scaffolded probability derivation), and **54 minor** consistency/notation items. The honest time budget is **62–85.5 h (midpoint ≈ 74 h) against the claimed 60 h** — feasible in 15 days only if the 4 h/day cap flexes on the six heavy days. Primer-wise the path is ready: 13 of 15 days are primer-able (review Days 5 and 9 are not, by design), with the domain-context block and warm-up schedule below. No file under `content/` or `code/` was modified by this review — the plan's only writes were the findings files and this report.

Severity counts: **7 critical / 5 major / 54 minor = 66 findings.**

## Findings — correctness (CRITICAL)

- [01-C1] `content/day01.md:229` — Solution 4 implies in-place NOT needs ancillas "to stay strictly reversible"; overwriting via a bijection IS reversible — teaches exactly the misconception the day dispels. Fix: fresh lines are for keeping $a,b$ available, not for reversibility.
- [02-C1] `content/day02.md:17,215,237–238` — day presents its constant-$0$-only algorithm as solving the full constant-vs-balanced Deutsch–Jozsa promise; it errs with certainty on $f\equiv1$. Fix: state the general rule ("constant iff all $k$ answers agree", error $2^{-(k-1)}$) or label the restriction. Same issue as [08-C1].
- [03-C1] `content/day03.md:171` — qubit DOF count: normalization leaves **three** real degrees of freedom, not two; two requires also removing global phase (Day 4's job). Fix: say three, note Day 4 removes one.
- [05-C1] `content/day05.md:315` — Hadamard derivation says "$a = d = \pm\tfrac{1}{\sqrt2}$"; $H$ has $d=-a$. Sign typo a self-grading learner would absorb. Fix: "$a = -d = \tfrac{1}{\sqrt2}$".
- [08-C1] `content/day08.md:195` (also 16–17, 28–30, 204) — quotes Day 2's constant-$0$ strategy as the "best classical strategy" for Day 8's two-sided promise; it fails with probability 1 on $f\equiv1$, and the repetition count changes ($m=21$, not 20). Fix: quote the all-answers-agree variant with the $2^{-(m-1)}$ bound. Same issue as [02-C1].
- [11-C1] `content/day11.md:302` — Solution 4's $k{=}4$ check prints the wrong angle ($146.15°$; correct is $130.30°$) and "coterminal" is misapplied; the value 0.582 is right. Fix: $\sin^2(130.30°)\approx0.582$.
- [15-C1] `content/day15.md:572` — exam model answer 9's continued-fraction expansion rounds the reciprocal before flooring ($1/0.1667 \approx 6$; truly $5.9988\to5$) — the shown method breaks the algorithm in general even though $r=6$ survives here. Fix: run the honest $[0;5,1,832]$ expansion or use the exact $\varphi=1/6$.

## Findings — feasibility (MAJOR)

- [01-C2] `content/day01.md:144` — worked example's garbage/line count ("5 garbage bits, 9 lines") matches no clean reading of its own formula (correct: 4 garbage on 8 lines). Fix: pick one explicit gate list and count exactly.
- [01-C3] `content/day01.md:259` — Solution 7 self-contradicts: "2 CNOTs, 0 ancillas, onto a fresh line" — a fresh line is an ancilla, and preserving $c_{in}$ takes 3 CNOTs. Fix: state both variants with true costs.
- [02-P1] `content/day02.md:158` — Hoeffding lemma uses exponential tilting + Taylor–Lagrange, never introduced, yet Exercise 3 demands full reproduction. Fix: short appendix or downgrade the exercise.
- [10-P1] `content/day10.md:176–185` — Simon's algorithm measures one register of an entangled state; the partial-measurement rule (project + renormalize) is never stated as a postulate anywhere in the path. Fix: 1–2 sentences in day06/day10. Compounded by [X4].
- [15-P1] `content/day15.md:126` — NP/NP-completeness/SAT used substantively but never defined in the course. Fix: 4–5 line verifier definition + one sentence on SAT.

## Findings — consistency (MINOR)

Per-day nits; full text and fixes in `findings/dayNN.md`.

- Day 1: [01-S1] ancilla total omits the constant-1 control lines.
- Day 2: [02-P2] Markov's inequality load-bearing but never stated as a tool.
- Day 3: [03-S1] adjoint relation quantifies $v,w$ over the wrong spaces for $m\times n$ $A$.
- Day 4: [04-C1] Bloch "rigid rotation" pseudo-justified (needs U(2)→SO(3)); [04-C2] garbled abandoned derivation text left at line 284; [04-S1] `notes/` directory referenced but never scaffolded; [04-P1] Schur's theorem cited without textbook pointer; [04-L1] "matches exactly" vs float round-off in lab output.
- Day 5: [05-C2] "reduces error to $e^{-k/18}$" — is an upper bound, add "at most"; [05-C3] O-notation used as induction invariant; [05-C4] realness of Hermitian eigenvalues cited to the wrong source; [05-S1] `notes/` gap again.
- Day 6: [06-S1] trace-identity scope drifts between Theory ("Hermitian") and Ex. 5 ("any operator"); [06-S2] Euler-decomposition objective has no matching exercise; [06-P1] cyclic trace property used, never proved; [06-P2] operator norm undefined.
- Day 7: [07-C1] "no linear map can implement a quadratic one" imprecise — the obstruction is non-orthogonal pairs.
- Day 8: [08-C2] per-branch $(-1)^{f(x)}$ called "global phase" (they're relative); [08-S1] "Day 2, Step 4, Problem 5" pointer doesn't resolve; [08-S2] "$2^{-20}$ … Day 2 Step 3" pointer wrong; [08-S3] learner-facing text references the internal authoring plan.
- Day 9: [09-S1] titled "Review: Days 6–8" but no dedicated Day 6 question.
- Day 10: [10-C1] objective's $H^{\otimes n}$ identity missing normalization; [10-C2] "learns nothing" overstates (non-collisions eliminate candidates); [10-S1] back-reference to a phrase not in the objectives; [10-S2] bit-index convention flips mid-file.
- Day 11: [11-C2] Solution 5's $P(k)$ table off in 3rd–4th decimals (code lab is the correct one); [11-C3] two arithmetic slips in Solution 4; [11-C4] garbled "n of which are indices" sentence; [11-S1] lab notes say probability only decreases after $k{=}3$, but output climbs to a second peak at $k{=}9$; [11-L1] `notes/` gap again; [11-L2] lab static check clean (recorded as the lab's verification bullet).
- Day 12: [12-C1] hybrid-argument sentence contradicts superposition queries; [12-C2] $\Theta$ applied to a single number; [12-P1] "variational-distance" named but never introduced.
- Day 13: [13-C1] "every prime power dividing N divides one factor" false for even N (proof survives via the gcd argument); [13-C2] failure-probability theorem missing oddness hypothesis; [13-C3] continued-fraction recovery overclaims without the $1/(2r^2)$ condition; [13-S1] row/column inner-product conflated (valid only by symmetry, unremarked); [13-P1] Euclidean algorithm required but never introduced.
- Day 14: [14-S1] cross-references by plan step numbers that exist in no content file; [14-L1] lab prints top 8 outcomes where only 4 are nonzero.
- Day 15: [15-S1] exam problem 3 promises an algebraic eigenvector derivation the model answer doesn't deliver; [15-S2] plan-step cross-references again; [15-P2] PSPACE never formally defined; [15-P3] polynomial hierarchy invoked as aside.
- Cross-day: [X1] same lemma named "parity-orthogonality" (Day 10) vs "Character-sum" (Day 15); [X2] Day 11 switches to the phase oracle with no bridge from Day 8's $U_f$/kickback; [X3] systematic plan-step citation pattern (consolidates 08-S1/S2, 14-S1, 15-S2 — fix in one pass); [X4] measurement postulate stated for one qubit only, applied to $n$-qubit registers path-wide; [X5] README claims every day has theory/worked examples/solutions — false for Days 5, 9, 15; [X6] README topic cells for Days 4 and 6 omit half the day; [X7] Day 5 review Q4 asks for a derivation direction Days 1–4 never ran (stretch-synthesis, should be labeled); [X8] exam says $k{=}250$ where Day 2 explicitly requires odd $k{=}251$.

## Corrected time budget

Claimed: flat 4 h/day, ~60 h total (review days as catch-up buffer; Day 15 exam "~2 h").

| Day | Claimed h | Estimated h | Midpoint Δ | Driver |
|---|---|---|---|---|
| 1 | 4 | 3.5–5 | +0.25 | mechanical constructions; Ex. 6–7 slow |
| 2 | 4 | 5–7 | **+2** | densest proof of week 1 (Chernoff/Hoeffding); Ex. 3 alone 1.5–2 h |
| 3 | 4 | 3–4.5 | −0.25 | complex re-run of known LA |
| 4 | 4 | 4.5–6 | +1.25 | high proof density + code lab |
| 5 | 4 | 3.5–5 | +0.25 | five closed-book proof reproductions + self-grading |
| 6 | 4 | 3.5–4.5 | 0 | moderate; misconceptions are reading |
| 7 | 4 | 5–7 | **+2** | two full proofs + 7 exercises (two proof reproductions) |
| 8 | 4 | 6–8 | **+3** | three proved identities + 8 exercises incl. two derivations |
| 9 | 4 | 3–4.5 | −0.25 | four closed-book reproductions |
| 10 | 4 | 4.5–6 | +1.25 | two full algorithm derivations + F₂ elimination |
| 11 | 4 | 3.5–5 | +0.25 | geometric, self-contained + short lab |
| 12 | 4 | 3.5–4.5 | 0 | re-run of Day 11 machinery; BBBV sketch-level |
| 13 | 4 | 4.5–6 | +1.25 | three proofs + hand number theory; learner light on NT |
| 14 | 4 | 4–5.5 | +0.75 | two derivations + lab; file's own journal expects overrun |
| 15 | 4 | 5–7 | **+2** | exam realistically 2.5–3.5 h (not 2) + theory + gap analysis |
| **Total** | **60** | **62–85.5** | **≈ +14 (mid ≈ 74 h)** | |

Reading: the plan fits 15 calendar days only if the heavy days (2, 7, 8, and to a lesser degree 4, 10, 13, 15) can borrow time — the two review days' surplus (~1 h combined at midpoint) does not cover the ~14 h midpoint overrun. Options for the fix list: extend to 17–18 days, raise the daily budget to ~5 h, or trim the heavy days' exercise sets.

## Primer-readiness

### Domain-context block (playbook's five questions)

1. **Main content format:** NAMED labels, not numbered — bold `**Claim:**` / `**Claim (phase kickback):**` / `**Theorem (Bennett–Bernstein–Brassard–Vazirani, 1997).**` plus `###` topic sub-headings. Days 10 and 11 have **no bold labels** — cite their `###` section names ("The parity-orthogonality lemma", "The diffusion operator $D$"). Citation format for primers: quoted label/section names + gate names. Never cite plan step numbers ([X3]).
2. **Pictures type:** circuit diagrams, Bloch-sphere states, amplitude bar charts, and 2D rotation/reflection diagrams (Grover).
3. **Section-5 name:** **Derivation roadmaps** (playbook's Quantum/Physics row).
4. **Path structure:** strictly sequential, with closed-book review days (5, 9) and an exam day (15) that get special handling.
5. **Day 1 warm-up:** no prior material — omit `## Warm-up` (5-section primer). Days 2 and 3 name only the 1–2 prior days that exist.

### Per-day verdicts

| Day | Primer? | Citable labels | Hook candidate (full quotes in findings files) |
|---|---|---|---|
| 1 | yes | partial (1 bold + ###) | Landauer: $kT\ln2 \approx 2.87\times10^{-21}$ J per erased bit (avoid the MAJ garbage count until [01-C2] is fixed) |
| 2 | yes | partial | exact failure 10.35% vs Hoeffding bound 53.5% at $k{=}5$ — a bound loose by 5× |
| 3 | yes | partial | $U=\tfrac{1}{\sqrt2}\begin{psmallmatrix}1&i\\i&1\end{psmallmatrix}$: eigenvalues $(1\pm i)/\sqrt2$, modulus exactly 1 |
| 4 | yes | partial | $A=\begin{psmallmatrix}1&1\\-1&1\end{psmallmatrix}$ normal-but-neither, eigenvalues $1\pm i$ |
| 5 | **no** — closed-book review day; a primer would leak the answers | — | — |
| 6 | yes | partial | Born probabilities $\tfrac{9}{25}+\tfrac{16}{25}=1$ for $\tfrac35\vert0\rangle+\tfrac{4i}{5}\vert1\rangle$ |
| 7 | yes | yes | no-cloning clash: coefficient $0$ vs $\tfrac12$, and $0.707$ vs $0.5$ |
| 8 | yes | yes | four-term interference sum $1-1-1+1=0$ ⇒ balanced detected with certainty |
| 9 | **no** — closed-book review day | — | — |
| 10 | yes | partial (### only) | BV $n{=}3$, $a{=}101$: amplitude $8/8=1$, hidden string in one query |
| 11 | yes | partial (### only) | exact Grover $N{=}4$: $\theta=60°$, one iteration → probability exactly 1 |
| 12 | yes | yes | $N{=}64$: $k{=}6$ iterations, $P\approx0.9966$, against the BBBV ceiling $T^2/N=1$ |
| 13 | yes | partial | $7^4\equiv1 \pmod{15}$, $\gcd(7^2-1,15)=3$ ⇒ $15=3\times5$ |
| 14 | yes | partial | QPE outcome $x{=}48/64$: $\varphi=3/4$ → continued fractions → $r{=}4$ |
| 15 | **theory portion only** (BQP/landscape/adiabatic ###-anchored); no primer for the exam portion | partial | $e^{-k/18}$: $k{=}250$ repetitions push error below $2^{-20}$ (state the odd-$k{=}251$ convention per [X8]) |

**Total: 13 primers** (days 1–4, 6–8, 10–14, 15-theory).

### Warm-up schedule (3 most-prerequisite prior primer-bearing days; never 5/9)

| Primer | Warm-up names | Rationale |
|---|---|---|
| day01 | — (omit Warm-up) | no prior material |
| day02 | day01 | only prior day |
| day03 | day01, day02 | only priors; day02 for probability framing |
| day04 | day03, day02, day01 | day03 is the real prerequisite (adjoint, unitarity, modulus-1 eigenvalues) |
| day06 | day04, day03, day02 | spectral/Pauli (d4), bra-ket/qubit (d3), probability (d2) |
| day07 | day06, day04, day03 | density matrices + rank-1 purity (d6), gates (d4), inner products (d3) |
| day08 | day07, day06, day02 | tensor products (d7), measurement (d6), classical DJ baseline (d2) |
| day10 | day08, day07, day06 | Hadamard identity + kickback (d8), tensors (d7), measurement (d6, see [10-P1]) |
| day11 | day08, day06, day04 | oracle bridge (d8, see [X2]), Born rule (d6), unitaries/geometry (d4) |
| day12 | day11, day10, day08 | rotation picture (d11), query model (d10), oracle (d8) |
| day13 | day10, day08, day03 | Hadamard-transform reduction (d10/d8), unitarity machinery (d3) |
| day14 | day13, day08, day07 | QFT/CF/Miller (d13), kickback (d8), tensors (d7) |
| day15 | day02, day12, day14 | BPP/amplification (d2), Grover/BBBV landscape (d12), Shor pipeline (d14) |

## Part-1 findings that affect primer briefs

- [01-C2] → day01 brief: do not use the MAJ garbage-count as hook or walkthrough numbers until fixed; use the Landauer hook.
- [02-C1]/[08-C1] → day02 and day08 briefs: any statement of the classical DJ strategy must use the corrected promise scope/rule; day08's hook is unaffected.
- [03-C1] → day03 brief: if the walkthrough mentions qubit degrees of freedom, say three-after-normalization.
- [05-C1] → no primer for day05, but day04's flashcards on $H$ should not echo the $a=d$ typo.
- [10-P1]/[X4] → day10 brief: the walkthrough should gloss the partial-measurement rule in one sentence.
- [11-C1]/[11-C2] → day11 brief: quote iteration probabilities from the code lab's output ($P(3)\approx0.9613$), not Solution 5's table.
- [13-C1] → day13 brief: Miller's-reduction roadmap must use the gcd argument, not the prime-power sentence.
- [15-C1] → day15-theory brief: any continued-fraction flashcard should follow Day 13's honest method.
- [15-P1] → day15-theory brief: gloss NP in one flashcard-sized definition.
- [X2] → day11 brief: "The pictures"/walkthrough should bridge the phase oracle to Day 8's $U_f$ via the $\vert-\rangle$ ancilla.
- [X3] (with [08-S1], [08-S2], [14-S1], [15-S2]) → all briefs: cite `###` section names, never plan step numbers.
- [X1] → day15-theory brief: use Day 10's name "parity-orthogonality lemma".

## Proposed fix list (awaiting approval)

No fixes applied. Ordered by severity; file to change in parentheses.

1. Fix the reversibility misstatement in Solution 4 ([01-C1], `content/day01.md`).
2. Fix the DJ promise scope on both sides ([02-C1] `content/day02.md`; [08-C1] `content/day08.md`) — one coordinated edit: state the general all-answers-agree rule with the $2^{-(m-1)}$ bound, fix $m{=}21$, repair the [08-S1]/[08-S2] pointers as part of the same pass.
3. Fix the qubit DOF count ([03-C1], `content/day03.md`).
4. Fix the $a=-d$ sign typo ([05-C1], `content/day05.md`).
5. Fix Solution 4's angle ([11-C1]) and recompute Solution 5's $P(k)$ table ([11-C2]), aligning [11-S1]'s lab note (`content/day11.md`).
6. Fix exam answer 9's continued-fraction computation ([15-C1], `content/day15.md`).
7. Repair Day 1's worked-example count and Solution 7 ([01-C2], [01-C3], `content/day01.md`).
8. Add the partial-measurement rule ([10-P1]+[X4]: one sentence in `content/day06.md`, one in `content/day10.md`).
9. Define NP (and gloss PSPACE) ([15-P1], [15-P2], `content/day15.md`).
10. Add the tilting/Taylor appendix or downgrade Exercise 3 ([02-P1], `content/day02.md`).
11. One systematic pass replacing plan-step citations with `###` section names ([X3] covering [08-S1], [08-S2], [08-S3], [14-S1], [15-S2]).
12. Scaffold `notes/` or add a creation note ([04-S1], [05-S1], [11-L1] — one line in day01 covers all).
13. README corrections ([X5], [X6], `content/README.md`).
14. Time budget: decide between extending to 17–18 days, ~5 h/day, or trimming heavy days (affects `docs/superpowers/plans/2026-07-13-…` and README preamble).
15. Remaining minors, batched per file: day03 ([03-S1]), day04 ([04-C1], [04-C2], [04-P1], [04-L1]), day05 ([05-C2], [05-C3], [05-C4]), day06 ([06-S1], [06-S2], [06-P1], [06-P2]), day07 ([07-C1]), day08 ([08-C2]), day09 ([09-S1]), day10 ([10-C1], [10-C2], [10-S1], [10-S2]), day11 ([11-C3], [11-C4], [11-L2] is a clean-pass record, no action), day12 ([12-C1], [12-C2], [12-P1]), day13 ([13-C2], [13-C3], [13-S1], [13-P1]), day13's [13-C1] gcd-argument cleanup, day14 ([14-L1]), day15 ([15-S1], [15-P3]), day01 ([01-S1]), day02 ([02-P2]), cross-day naming/labeling ([X1], [X2], [X7], [X8]).
