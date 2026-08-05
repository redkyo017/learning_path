# Day 12 findings
## Correctness
- [12-C1] MINOR — content/day12.md:127-128 — hybrid-argument sketch: "A single query can only touch the oracle's answer on the one input the algorithm currently has amplitude on" — wrong as stated (a quantum query addresses all inputs in superposition, and the state has amplitude on many inputs — as the very next clause says); the correct point is that $O_i$ and $O_0$ differ only at input $i$, so one query can shift the state by at most an amount governed by the amplitude on $i$ — reword accordingly; the section is explicitly flagged sketch-level and the rest of the paragraph carries the right picture, so impact is limited.
- [12-C2] MINOR — content/day12.md:269-270 — "$T=6$ queries is $\Theta(\sqrt N) = \Theta(\sqrt{64}) = \Theta(8)$" — $\Theta$ of a single concrete number is a notation abuse (asymptotic classes don't apply to one instance); the intended meaning ("$6$ is on the order of $\sqrt{64}=8$") is clear — drop the $\Theta$'s in the instance check. (All other numerics verified exact: $\theta=2\arcsin(1/8)=0.250656$, $k^\star\approx5.77\to k=6$, table $P(5)=0.9635$, $P(6)=0.9966$, $P(7)=0.9074$; Exercise 8: $P(7)=0.99534 > P(8)=0.98266$, $k^\star\approx7.34$ — all re-derived and correct.)
## Consistency
- none
## Prerequisites
- [12-P1] MINOR — content/day12.md:46 — "variational-distance or amplitude bound" names a concept (variational/trace distance) introduced nowhere in Days 1–11 — it appears only inside the explicit "beyond scope" disclaimer, so no derivation depends on it, but a learner can't unpack the term; either gloss it in a half-sentence ("a standard measure of how distinguishable two states are") or drop the name.
## Time budget
- estimated hours: 3.5–4.5 h — 458 lines but the mathematically demanding half (generalized amplitude amplification) is a direct re-run of Day 11's derivation with $\sqrt p$ in place of $\sqrt{M/N}$, and the BBBV half is deliberately sketch-level; 9 exercises, of which four (1, 2, 4, 9) are restatement/explanation and the computational ones (5–8) are short; assumes a learner comfortable with linear algebra, new to quantum, who completed Day 11.
## Code lab
- not applicable
## Primer-ability
- citable labels: yes — bold named labels present: "**Theorem (Bennett–Bernstein–Brassard–Vazirani, 1997).**" (line 82) and "**Claim:**" opening the worked example (line 240), plus strong ### anchors ("The hybrid-argument sketch" line 108, "Generalized amplitude amplification" line 151, "The modified iteration count" line 207).
- hook candidate: "Take $N = 64$, $M = 1$ (a uniquely marked item, exactly the BBBV setting). Then $p = M/N = 1/64$, and ... $\theta = 2\arcsin(1/8) \approx 0.250656$ rad" (lines 245-248), culminating in $k=6$ iterations with success probability $\approx 0.9966$ (table, lines 260-264) checked against the BBBV ceiling $T^2/N = 64/64 = 1$ (line 274).
