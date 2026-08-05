# Day 05 findings

## Correctness
- [05-C1] CRITICAL — content/day05.md:315 — "from Problem 3, $a = d = \pm\frac{1}{\sqrt2}$" in the Hadamard derivation — false: $H$'s diagonal entries are $a=\frac1{\sqrt2}$, $d=-\frac1{\sqrt2}$, and the $b\ne0$ family derived two paragraphs earlier forces $d=-a$; "$a=d$" contradicts both the matrix and the family constraint (the sentence's own continuation "$d=-a=-\frac1{\sqrt2}$" is correct, so this is a sign typo a self-grading learner could absorb) — fix to "$a = -d = \frac{1}{\sqrt2}$".
- [05-C2] MINOR — content/day05.md:139 — "reduces the error probability to $e^{-k/18}$" — it is an upper bound, not an exact value; the proof itself correctly concludes "at most $e^{-k/18}$" — insert "at most". (Bound re-derived: Hoeffding with $t=1/6$ gives $e^{-2k/36}=e^{-k/18}$; sanity check $k\ge 360\ln2\approx 250$ is correct; constant matches Day 2's derivation, verified in day02.md lines 202/433.)
- [05-C3] MINOR — content/day05.md:103–116 — the induction carries "$O(g-1)$ Toffolis/ancillas" inside the inductive hypothesis and concludes "$O(g-1)+O(1)=O(g)$" — using O-notation as an induction invariant is formally abusive (the hidden constant must be fixed, e.g. "$\le C\,g$ Toffolis for a fixed constant $C$"); the conclusion is right since each simulated gate costs a bounded constant — restate the hypothesis with an explicit constant.
- [05-C4] MINOR — content/day05.md:264 — "eigenvalues of a Hermitian matrix are real, by Problem 3's spectral theorem applied to the eigenvector equation" — Problem 3's model answer never proves realness of Hermitian eigenvalues (that proof lives in Day 4's Theory section, day04.md:111–123) — cite Day 4 instead of Problem 3. (All other model answers re-derived and verified: Toffoli AND/NOT/OR constructions, the $2\times2$ spectral proof including both $A'A'^\dagger$/$A'^\dagger A'$ products and $b=0$, $\tan(\pi/8)=\sqrt2-1$ eigenvectors, $UDU^\dagger=H$ double-angle reconstruction, the $A^2=I$ three-equation system, Landauer statement.)

## Consistency
- [05-S1] MINOR — content/day05.md:31 — instructs attempting the questions in `notes/day05_review.md`, but no `notes/` directory exists in the repo — same gap as Day 4; add a creation note or scaffold. (Otherwise consistent: 5 review questions ↔ 5 model answers, each answer solves its stated question; the five learning-objective bullets map one-to-one onto the five questions; all reviewed material is genuinely from Days 1–4 as a closed-book review requires.)

## Prerequisites
- none — every reviewed result is introduced on Days 1–4 (Toffoli/Landauer: Day 1; BPP/Hoeffding with the same $e^{-k/18}$ constant: Day 2; inner products/unitarity: Day 3; spectral theorem, Pauli/Hadamard eigenstructure: Day 4, all confirmed against inventory.md); extending $\{v_1\}$ to an orthonormal basis is assumed LA background, consistent with the learner profile.

## Time budget
- estimated hours: 3.5–5 h — no new theory, but writing five full proof-level derivations from memory (Hoeffding amplification, $2\times2$ spectral proof, the $X,Y,Z,H$ family derivation) plus self-grading and transcribing corrections is slow, closed-book work for a learner new to quantum.

## Code lab
- not applicable

## Primer-ability
- citable labels: yes — `**Claim.**` (line 66), `**Definition.**` (line 131), `**Claim.**` (line 138), `**Definition.**` (line 179), `**Theorem ($2\times2$ case).**` (line 183), plus numbered `###` model-answer sections ("1. Toffoli + ancilla universality…" through "5. Landauer's principle…").
- hook candidate: line 172–175 — "to push the error below $2^{-20}$, we'd need $e^{-k/18} \le 2^{-20}$, i.e. $k \ge 18 \cdot 20\ln 2 \approx 250$ — a modest, poly-size number of repetitions for an exponentially small error".
