# Day 13 findings
## Correctness
- [13-C1] MINOR — content/day13.md:88 — "every prime power dividing N divides at least one of the two factors" — false in general: for p=2 with a odd, both a^m−1 and a^m+1 are even and a power 2^e | N can split between them (e.g. 8 | 4·6 but 8∤4, 8∤6); the sentence is only true for odd N. The proof survives because the parenthetical d=1 ⇒ N | a^m+1 argument (lines 91–93) is the correct one and never needs this sentence — suggested fix: either state N odd (standard in Shor, since even N is factored trivially) or delete the sentence and lead with the gcd argument.
- [13-C2] MINOR — content/day13.md:102 — "this failure happens with probability at most 1/2 for a uniformly random a" — the standard theorem requires N odd with at least two distinct prime factors; stated without the oddness hypothesis — suggested fix: add "for odd N with ≥2 distinct prime factors".
- [13-C3] MINOR — content/day13.md:190 — "running this expansion until the denominator first exceeds the bound, then backing up one step, recovers k/r exactly despite the noise" — overclaims: exact recovery requires |x₀ − k/r| < 1/(2r²) (and gcd(k,r)=1 to read off r itself); with larger noise the procedure fails — suggested fix: state the 1/(2r²) precision condition alongside the "operational fact" disclaimer (the worked instance, error 0.0003 < 1/(2·8²), does satisfy it).
## Consistency
- [13-S1] MINOR — content/day13.md:118 — the orthonormality identity Σ_x ω^{x(y−y')} sums over x with y, y' fixed, which under the stated convention M_{yx} (row y, column x) is an inner product of *rows* y and y', yet is presented as "⟨column y, column y'⟩" — valid only because M is symmetric, which goes unremarked — suggested fix: one clause noting symmetry makes rows/columns interchangeable, or index columns by x.
## Prerequisites
- [13-P1] MINOR — content/day13.md:98 — the Euclidean algorithm is invoked ("fast, via the Euclidean algorithm") and Exercise 7 (line 250) requires running it by hand, but it is never introduced anywhere in the course — most learners with the assumed background know it; a two-line reminder of the division-with-remainder loop would close the gap.
## Time budget
- estimated hours: 4.5–6 h — 387 lines with three full proofs (Miller's reduction, QFT unitarity, group-Fourier reduction) plus 7 exercises including reproving Miller from scratch and a 6-step hand Euclidean expansion; for a learner comfortable with linear algebra but new to quantum and light on number theory, this exceeds the plan's ~3.2 h step budget.
## Code lab
- not applicable
## Primer-ability
- citable labels: partial — one bold label (**Claim.** line 64, Miller's reduction) plus strong ### names ("Miller's reduction: from order to factor", "The Quantum Fourier Transform", "Deriving the $N=4$ matrix explicitly", "Continued fractions").
- hook candidate: "7^4 = 7·13 = 91 ≡ 1 (mod 15), so r=4; then d = gcd(7²−1, 15) = gcd(3, 15) = 3, recovering 15 = 3×5" — worked example, lines 204–217 (gcd computation at line 214).
