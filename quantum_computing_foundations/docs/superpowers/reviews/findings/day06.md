# Day 06 findings

## Correctness
- none — all claims re-derived and verified: Born-rule normalization argument; $\rho=\frac12[[1,1],[1,1]]$ with eigenvalues $\{0,1\}$ and $\rho|-\rangle=0$; $\mathrm{Tr}(\rho Z)=0=\langle+|Z|+\rangle$; solutions 1–7 ($\frac9{25}+\frac{16}{25}=1$; $\langle-|+\rangle=0$; trace/Hermiticity/PSD proofs; rank-1 spectrum; completeness-relation trace identity; $R_z$ unitarity and $R_z(\pi/2)|0\rangle=e^{-i\pi/4}|0\rangle=\frac{\sqrt2}{2}(1-i)|0\rangle$); the Z-Y-Z Euler form and $R_z$/$R_y$ matrices match the standard (Nielsen–Chuang) convention; Solovay–Kitaev stated correctly as $O(\log^c(1/\varepsilon))$; the misconception section's physics (classical 50/50 coin stays 50/50 in every basis, i.e. $\rho=I/2$, vs. deterministic $|+\rangle$ outcome) is correct.

## Consistency
- [06-S1] MINOR — content/day06.md:105 vs content/day06.md:273 — Theory states the trace identity "for any observable (Hermitian operator) $O$", while Exercise 5 asks to prove it "for any operator $O$" and the solution proves the general case — both are true (Hermiticity is never used), but the scope drift is confusing for a learner checking their proof — align both to "any operator $O$ (Hermiticity not needed)".
- [06-S2] MINOR — content/day06.md:17 — learning objective "use it [$R_z(\theta)$] as a concrete instance of the general single-qubit rotation decomposition" — no exercise actually touches the Euler product; Exercise 6 only verifies unitarity and computes one phase action (the solution's "up to overall phase" remark is the sole tie-in) — soften the objective or add a one-line exercise plugging $R_z$ into the Z-Y-Z form. (All cross-references resolve: Day 3's bra-ket/completeness section exists per inventory; the "$\frac35,\frac{4i}{5}$ state back in Day 3" claim verified at day03.md:256; Day 4 gate references and the Day 7 forward reference to reduced states match inventory.)

## Prerequisites
- [06-P1] MINOR — content/day06.md:314 — Solution 3 invokes "the cyclic property of the trace" — the trace appears earlier only as $\mathrm{tr}$ in Day 4's characteristic polynomials; its cyclic property is never introduced or proved in Days 1–5 — acceptable for the assumed LA-comfortable learner, but a one-line proof ($\mathrm{Tr}(AB)=\sum_{ij}A_{ij}B_{ji}=\mathrm{Tr}(BA)$) would close the gap.
- [06-P2] MINOR — content/day06.md:148 — "within distance $\varepsilon$ of $U$ (in operator norm)" — operator norm is never defined anywhere in Days 1–6 — add a parenthetical gloss (largest factor by which $U$ can stretch a unit vector).

## Time budget
- estimated hours: 3.5–4.5 h — 411 lines of moderate proof density (three short structural proofs, one trace identity, mostly computational exercises); the long misconception section is reading, not derivation; assumes a learner comfortable with linear algebra, new to quantum.

## Code lab
- not applicable

## Primer-ability
- citable labels: partial — one bold label (`**Claim:**` line 207); otherwise clear `###` names ("The measurement postulate and the Born rule", "Basis-dependence of measurement statistics", "Density matrices: definition and basic properties", "Universal gate sets and the Solovay–Kitaev theorem").
- hook candidate: Exercise 1, line 258 — "For $|\psi\rangle = \frac{3}{5}|0\rangle + \frac{4i}{5}|1\rangle$, compute the Born-rule measurement probabilities in the standard basis" — yielding $\frac{9}{25}$ and $\frac{16}{25}$ summing to $1$ (solution at line 285).
