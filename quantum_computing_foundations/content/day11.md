# Day 11 — Grover's Algorithm & Amplitude Amplification

## Learning objectives

By the end of today you should be able to:
- State the unstructured search problem precisely and give the classical
  query-complexity baseline it beats.
- Prove that the oracle reflection $O_f$ and the diffusion operator $D$ are
  each unitary, and show explicitly (by their action on basis vectors of a
  2D subspace) that each is a reflection.
- Derive the rotation angle $\theta$ from $\sin(\theta/2)=\sqrt{M/N}$, and
  show that one Grover iteration $D\cdot O_f$ is a rotation by $\theta$ in
  the $\{|bad\rangle,|good\rangle\}$ plane.
- Compute, for a concrete $(N,M)$, the exact optimal iteration count and
  compare it to the standard $\frac{\pi}{4}\sqrt{N/M}$ heuristic.
- Read the output of a small Grover simulation and explain the "overshoot"
  (probability rises, peaks, then falls) in terms of the same rotation
  picture.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or Nielsen & Chuang, the chapter(s) covering Grover's algorithm and
  amplitude amplification.
- The theory below is self-contained — you do not need the book to do
  today's work, but reading the matching chapter alongside this is useful
  for a second explanation in different words.
- The Day 11 implementation plan for this course:
  `quantum_computing_foundations/docs/superpowers/plans/2026-07-13-quantum-computing-15-day-plan.md`
  (Day 11 section) has the exact code and run commands for the Code lab
  below; this document is the theory to have in mind while you run it.

## Theory

### The unstructured search problem

You are given an oracle over $N=2^n$ items, $n$ of which are indices into a
list with no exploitable structure — no ordering, no hashing shortcut,
nothing but the ability to ask the oracle "is this item marked?" for one
item at a time. $M$ of the $N$ items are **marked** ("good"); the rest are
**unmarked** ("bad"). The task: find a marked item using as few oracle
queries as possible. Classically, with no structure to exploit, you must
query items essentially at random (without replacement) until you hit a
marked one; the expected number of queries is $\Theta(N/M)$. **Grover's
algorithm** solves this with $O(\sqrt{N/M})$ *quantum* oracle queries — a
quadratic speedup, not exponential like Deutsch–Jozsa or Simon's algorithm,
but unlike those problems this one has no promise on the oracle's structure
at all: it is the most general search problem there is.

### The good/bad subspace and the state $|s\rangle$

Define two normalized superposition states:
$$|good\rangle = \frac{1}{\sqrt{M}}\sum_{x\text{ marked}}|x\rangle, \qquad
|bad\rangle = \frac{1}{\sqrt{N-M}}\sum_{x\text{ unmarked}}|x\rangle.$$
Because the marked and unmarked basis states are disjoint sets of the
standard basis, $|good\rangle$ and $|bad\rangle$ are orthonormal, and they
span a real 2-dimensional subspace of the full $N$-dimensional Hilbert
space. This is the entire arena Grover's algorithm operates in: every
operator we care about today, restricted to this 2D subspace, behaves like
ordinary 2D plane geometry, even though the ambient space has $N$
dimensions.

The algorithm starts in the uniform superposition
$|s\rangle=\frac{1}{\sqrt N}\sum_x|x\rangle$. Splitting the sum into marked
and unmarked terms,
$$|s\rangle=\frac{1}{\sqrt N}\Big(\sum_{x\text{ marked}}|x\rangle+
\sum_{x\text{ unmarked}}|x\rangle\Big)
=\sqrt{\frac{M}{N}}\,|good\rangle+\sqrt{\frac{N-M}{N}}\,|bad\rangle,$$
using $\sum_{x\text{ marked}}|x\rangle=\sqrt M\,|good\rangle$ and the
analogous identity for the unmarked sum. Writing the coefficients as
$\sin(\theta/2)$ and $\cos(\theta/2)$ for some angle $\theta$ gives exactly
$$|s\rangle=\cos(\theta/2)|bad\rangle+\sin(\theta/2)|good\rangle,\qquad
\sin(\theta/2)=\sqrt{M/N}.$$
So $|s\rangle$ sits in the 2D subspace at angle $\theta/2$ away from
$|bad\rangle$, tilted toward $|good\rangle$ — and $\theta$ is *not* an
arbitrary label, it is fixed entirely by $M$ and $N$.

### The oracle reflection $O_f$

The oracle reflection is $O_f = I - 2\sum_{x\text{ good}}|x\rangle\langle
x| = I - 2P_{good}$, where $P_{good}=\sum_{x\text{ good}}|x\rangle\langle
x|$ is the projector onto the span of the marked basis states. Concretely,
$O_f$ leaves every unmarked basis state alone and flips the sign of every
marked basis state's amplitude — the standard "phase oracle" used in
Grover's algorithm.

$P_{good}$ is a Hermitian, idempotent projector ($P_{good}^2=P_{good}$), so
$O_f$ is Hermitian and $O_f^2 = I-4P_{good}+4P_{good}^2 = I$: $O_f$ is its
own inverse. A Hermitian involution is automatically unitary
($O_f^\dagger O_f = O_f^2 = I$). Restricted to the 2D subspace, $P_{good}$
fixes $|good\rangle$ (it is entirely built from marked basis states) and
annihilates $|bad\rangle$ (built entirely from unmarked, hence orthogonal,
basis states), so $O_f|good\rangle=-|good\rangle$ and
$O_f|bad\rangle=|bad\rangle$: $O_f$ is exactly a reflection about the
$|bad\rangle$ axis. The full derivation, on arbitrary vectors of the
subspace rather than just the two basis vectors, is worked out in
Exercise 1's solution.

### The diffusion operator $D$

The diffusion operator is $D = 2|s\rangle\langle s| - I$. $|s\rangle\langle
s|$ is a rank-1 Hermitian projector onto the (normalized) vector
$|s\rangle$, so by the same involution argument as above, $D^2=I$ and $D$
is unitary. Geometrically, $D$ reflects any vector about the $|s\rangle$
axis: decomposing a vector into a component along $|s\rangle$ and a
component orthogonal to it, $D$ preserves the along-$|s\rangle$ component
and flips the sign of the orthogonal component — exactly what a reflection
about $|s\rangle$ does. Because $|s\rangle$ itself lies in the 2D
$\{|good\rangle,|bad\rangle\}$ subspace, $D$ maps that subspace to itself,
so this reflection can be studied entirely within the plane. Exercise 2's
solution carries out the decomposition explicitly.

### Composing two reflections: Grover's algorithm as rotation

A classical fact from plane geometry: composing two reflections about two
lines that meet at angle $\varphi$ produces a rotation by $2\varphi$. Here
the two reflection axes are $|bad\rangle$ (for $O_f$) and $|s\rangle$ (for
$D$), and by construction those two axes meet at angle $\theta/2$. So one
Grover iteration, $D\cdot O_f$ (oracle first, then diffusion), should
rotate the 2D subspace by $\theta$ — Exercise 3 verifies this by writing
out the two $2\times 2$ matrices explicitly and multiplying them, rather
than just invoking the geometric fact. The direction of the rotation
matters: it turns out to rotate *toward* $|good\rangle$, meaning each
iteration increases the angle between the current state and the
$|bad\rangle$ axis by $\theta$. After $k$ iterations, the state sits at
angle $\theta/2 + k\theta = (2k+1)\theta/2$ from $|bad\rangle$, so the
probability of measuring a good state is
$$P(k) = \sin^2\!\Big(\frac{(2k+1)\theta}{2}\Big).$$

### How many iterations?

$P(k)$ is *not* monotonically increasing — it is periodic in $k$, because
$(2k+1)\theta/2$ keeps advancing around a circle. The number of iterations
that maximizes $P(k)$ closest to $k=0$ (the fewest oracle queries you'd
actually want to spend) is the integer $k$ nearest
$$k^\star = \frac{\pi}{2\theta}-\frac12,$$
found by asking when $(2k+1)\theta/2$ is closest to $\pi/2$ (where
$\sin^2$ peaks at $1$). For small $\theta$ (i.e. $M\ll N$),
$\theta\approx 2\sqrt{M/N}$ (small-angle approximation to $\sin$), which
gives the familiar heuristic $k^\star\approx\frac{\pi}{4}\sqrt{N/M}$ quoted
without derivation in most treatments — Exercise 4 checks both the exact
and the approximate formula against each other on a concrete instance.
Iterating past the peak *overshoots*: probability decreases, eventually
reaching a trough, then rises again toward a second, later peak — the
"overshoot" behavior you'll see directly in today's code.

## Worked example

**A case where Grover's algorithm is exact.** Take $N=4$ ($n=2$ qubits),
$M=1$. Then $\sin(\theta/2)=\sqrt{1/4}=1/2$, so $\theta/2=30°$ and
$\theta=60°=\pi/3$. In the orthonormal basis $\{|bad\rangle,|good\rangle\}$
(writing vectors as coordinate pairs (bad-component, good-component)):

$$O_f = \begin{pmatrix}1&0\\0&-1\end{pmatrix}\quad\text{(from
$O_f|bad\rangle=|bad\rangle$, $O_f|good\rangle=-|good\rangle$)}.$$

A reflection about a line at angle $\alpha$ to the bad-axis has matrix
$\begin{pmatrix}\cos2\alpha&\sin2\alpha\\\sin2\alpha&-\cos2\alpha
\end{pmatrix}$; with $\alpha=\theta/2=30°$ this is $D$'s matrix,
$$D=\begin{pmatrix}\cos60°&\sin60°\\\sin60°&-\cos60°\end{pmatrix}
=\begin{pmatrix}0.5&0.8660\\0.8660&-0.5\end{pmatrix}.$$

Multiplying,
$$D\cdot O_f=\begin{pmatrix}0.5&0.8660\\0.8660&-0.5\end{pmatrix}
\begin{pmatrix}1&0\\0&-1\end{pmatrix}
=\begin{pmatrix}0.5&-0.8660\\0.8660&0.5\end{pmatrix},$$
which is exactly the rotation matrix $\begin{pmatrix}\cos60°&-\sin60°\\
\sin60°&\cos60°\end{pmatrix}$ — a rotation by $\theta=60°$, confirming the
general claim of the Theory section on this concrete instance.

$|s\rangle$'s coordinates are $(\cos30°,\sin30°)=(0.8660,0.5)$, i.e.
$|s\rangle$ sits at angle $30°$ from $|bad\rangle$. Applying one rotation
by $60°$ moves it to angle $30°+60°=90°$ — exactly $|good\rangle$.
Checking numerically:
$$D\cdot O_f\,|s\rangle=\begin{pmatrix}0.5&-0.8660\\0.8660&0.5\end{pmatrix}
\begin{pmatrix}0.8660\\0.5\end{pmatrix}
=\begin{pmatrix}0.5(0.8660)-0.8660(0.5)\\0.8660(0.8660)+0.5(0.5)\end{pmatrix}
=\begin{pmatrix}0\\1\end{pmatrix}.$$
So after exactly **one** Grover iteration, measuring is certain to return
the marked item: $N=4,M=1$ is one of the rare instances where Grover's
algorithm succeeds with probability exactly $1$, not merely close to $1$.
This will not happen for the $N=16,M=1$ case in the Exercises — there, the
best achievable probability at the nearest integer iteration count falls
just short of $1$, which is the generic situation.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Prove $O_f=I-2\sum_{x\text{ good}}|x\rangle\langle x|$ is unitary for
   general $N,M$. Then compute $O_f|good\rangle$ and $O_f|bad\rangle$
   directly from the definition, and use those two results to show $O_f$
   acts as a reflection about $|bad\rangle$ on an *arbitrary* vector
   $a|bad\rangle+b|good\rangle$ of the 2D subspace (not just on the two
   basis vectors themselves).
2. Prove $D=2|s\rangle\langle s|-I$ is unitary. Then, by decomposing an
   arbitrary vector of the 2D subspace into a component along $|s\rangle$
   and a component orthogonal to it, show $D$ reflects that vector about
   $|s\rangle$. Explain why $D$ maps the 2D subspace to itself even though
   it is defined using the identity on the full $N$-dimensional space.
3. Derive $\sin(\theta/2)=\sqrt{M/N}$ from the definitions of $|good\rangle,
   |bad\rangle,|s\rangle$ (don't just cite it). Then write $O_f$ and $D$ as
   explicit $2\times2$ matrices in the $\{|bad\rangle,|good\rangle\}$ basis
   and multiply them to show $D\cdot O_f$ is the rotation matrix for angle
   $\theta$.
4. For $N=16,M=1$: compute $\theta=2\arcsin(1/4)$ in radians and in
   degrees. Find the integer $k$ that maximizes $\sin^2((2k+1)\theta/2)$
   among small $k$ (the iteration count you'd actually stop at), and
   compare it to the heuristic $k\approx\frac{\pi}{4}\sqrt{N/M}$. Do they
   agree here?
5. Still for $N=16,M=1$: tabulate $P(k)=\sin^2((2k+1)\theta/2)$ for
   $k=0,1,\dots,10$. Identify where the probability peaks, where it dips to
   a trough, and explain — in terms of $\theta$ and the rotation picture —
   why it eventually starts climbing again rather than staying low.

## Solutions

**1.** Let $P_{good}=\sum_{x\text{ good}}|x\rangle\langle x|$; it is
Hermitian ($P_{good}^\dagger=P_{good}$, being a sum of Hermitian rank-1
projectors $|x\rangle\langle x|$) and idempotent
($P_{good}^2=\sum_{x,y\text{ good}}|x\rangle\langle x|y\rangle\langle y|
=\sum_{x\text{ good}}|x\rangle\langle x|=P_{good}$, using orthonormality
$\langle x|y\rangle=\delta_{xy}$). So $O_f=I-2P_{good}$ is Hermitian, and
$$O_f^2=(I-2P_{good})^2=I-4P_{good}+4P_{good}^2=I-4P_{good}+4P_{good}=I.$$
$O_f^\dagger O_f=O_f\cdot O_f=O_f^2=I$, so $O_f$ is unitary.

Now $P_{good}|good\rangle=\frac{1}{\sqrt M}\sum_{y\text{ good}}
P_{good}|y\rangle=\frac{1}{\sqrt M}\sum_{y\text{ good}}|y\rangle=
|good\rangle$ (each marked basis state is already an eigenvector of
$P_{good}$ with eigenvalue $1$), while $P_{good}|bad\rangle=0$ because
$|bad\rangle$ is a combination purely of unmarked basis states, all
orthogonal to every marked basis state. Hence
$$O_f|good\rangle=|good\rangle-2P_{good}|good\rangle=|good\rangle-2|good\rangle=-|good\rangle,\qquad
O_f|bad\rangle=|bad\rangle-2\cdot0=|bad\rangle.$$
For a general vector $v=a|bad\rangle+b|good\rangle$ in the subspace,
linearity gives
$$O_f v = a\,O_f|bad\rangle+b\,O_f|good\rangle = a|bad\rangle - b|good\rangle,$$
i.e. $(a,b)\mapsto(a,-b)$ in these coordinates — precisely the reflection
of the plane about the $|bad\rangle$ axis (the component along the axis is
unchanged, the component perpendicular to it flips sign).

**2.** $|s\rangle\langle s|$ is Hermitian and, since $\langle s|s\rangle=1$,
idempotent: $(|s\rangle\langle s|)^2=|s\rangle\langle s|s\rangle\langle
s|=|s\rangle\langle s|$. So by the identical argument as in Exercise 1,
$D=2|s\rangle\langle s|-I$ satisfies $D^2=4|s\rangle\langle s|-
4|s\rangle\langle s|+I=I$, and $D^\dagger D=D^2=I$: $D$ is unitary.

For an arbitrary vector $v$ in the 2D subspace, write $v=c|s\rangle+
c_\perp|s_\perp\rangle$, where $|s_\perp\rangle$ is the unit vector in the
same subspace orthogonal to $|s\rangle$. Then $\langle s|v\rangle=c$, so
$$Dv=2\langle s|v\rangle|s\rangle-v=2c|s\rangle-(c|s\rangle+c_\perp|s_\perp\rangle)
=c|s\rangle-c_\perp|s_\perp\rangle,$$
i.e. the component along $|s\rangle$ is preserved and the component
orthogonal to it is negated — exactly a reflection about $|s\rangle$.
$D$ maps the 2D subspace to itself because, for any $v$ in the subspace,
$Dv$ is built from $I v = v$ (which stays in the subspace trivially) and
$2\langle s|v\rangle|s\rangle$ (a scalar multiple of $|s\rangle$, which is
itself in the subspace by hypothesis) — a linear combination of two
vectors already in the subspace is still in the subspace, even though $D$
is defined using the identity on the full $N$-dimensional space.

**3.** Splitting $|s\rangle=\frac{1}{\sqrt N}\sum_x|x\rangle$ into marked
and unmarked terms and using $\sum_{x\text{ good}}|x\rangle=\sqrt M
|good\rangle$, $\sum_{x\text{ bad}}|x\rangle=\sqrt{N-M}\,|bad\rangle$:
$$|s\rangle=\sqrt{\frac MN}\,|good\rangle+\sqrt{\frac{N-M}N}\,|bad\rangle.$$
Matching this to $\cos(\theta/2)|bad\rangle+\sin(\theta/2)|good\rangle$
(a valid parametrization since the two coefficients are non-negative reals
whose squares sum to $1$) gives $\sin(\theta/2)=\sqrt{M/N}$ directly by
comparing the $|good\rangle$ coefficients.

From Exercise 1, in the $(bad,good)$ coordinate basis,
$O_f=\begin{pmatrix}1&0\\0&-1\end{pmatrix}$. For $D$: writing $v=(a,b)$ and
$|s\rangle=(\cos(\theta/2),\sin(\theta/2))$,
$$Dv = 2\big(a\cos\tfrac\theta2+b\sin\tfrac\theta2\big)
\Big(\cos\tfrac\theta2,\ \sin\tfrac\theta2\Big)-(a,b).$$
First coordinate: $a\big(2\cos^2\tfrac\theta2-1\big)+b\big(2\sin\tfrac\theta2
\cos\tfrac\theta2\big)=a\cos\theta+b\sin\theta$. Second coordinate:
$a\big(2\sin\tfrac\theta2\cos\tfrac\theta2\big)+b\big(2\sin^2\tfrac\theta2-1
\big)=a\sin\theta-b\cos\theta$ (using the double-angle identities
$\cos\theta=2\cos^2\tfrac\theta2-1=1-2\sin^2\tfrac\theta2$ and
$\sin\theta=2\sin\tfrac\theta2\cos\tfrac\theta2$). So
$$D=\begin{pmatrix}\cos\theta&\sin\theta\\\sin\theta&-\cos\theta\end{pmatrix}.$$
Multiplying,
$$D\cdot O_f=\begin{pmatrix}\cos\theta&\sin\theta\\\sin\theta&-\cos\theta
\end{pmatrix}\begin{pmatrix}1&0\\0&-1\end{pmatrix}
=\begin{pmatrix}\cos\theta&-\sin\theta\\\sin\theta&\cos\theta\end{pmatrix},$$
which is exactly the standard counter-clockwise rotation matrix by angle
$\theta$ in the $(bad,good)$ plane — confirming the composition-of-two-
reflections claim by direct matrix computation, not just by citing the
general geometric fact.

**4.** $\theta=2\arcsin(1/4)$. Using $\arcsin(0.25)\approx0.252680$ rad
($\approx14.478°$), $\theta\approx0.505360$ rad $\approx28.955°$.

The peak nearest $k=0$ is at the integer closest to
$k^\star=\frac{\pi}{2\theta}-\frac12=\frac{3.14159}{1.01072}-0.5\approx
3.1089-0.5=2.6089$, which rounds to $k=3$. Checking: $(2\cdot3+1)\theta/2=
3.5\theta\approx1.7688$ rad $\approx101.36°$,
$\sin^2(101.36°)\approx0.962$ — noticeably higher than the neighboring
$k=2$ value ($\sin^2(72.39°)\approx0.908$) and $k=4$ value
($\sin^2(146.15°)$... using the coterminal angle, $\approx0.582$), so
$k=3$ is indeed the local peak.

The heuristic gives $k\approx\frac\pi4\sqrt{16/1}=\frac\pi4\cdot4=\pi
\approx3.14$, which also rounds to $k=3$. **They agree exactly** for this
instance — both the exact optimum and the small-angle heuristic point to
3 iterations. (This agreement is not guaranteed in general: the heuristic
uses $\theta\approx2\sqrt{M/N}$, a small-angle approximation, and for
larger $M/N$ ratios the true $\theta$ deviates enough from that
approximation that the two rounded integers can differ by one.)

**5.** With $\theta/2\approx0.25268$ rad, $P(k)=\sin^2((2k+1)\cdot0.25268)$:

| $k$ | $(2k+1)\theta/2$ (rad) | $P(k)$ |
|---|---|---|
| 0 | 0.2527 | 0.0625 |
| 1 | 0.7580 | 0.4729 |
| 2 | 1.2634 | 0.9076 |
| 3 | 1.7688 | 0.9616 |
| 4 | 2.2741 | 0.5816 |
| 5 | 2.7795 | 0.1254 |
| 6 | 3.2848 | 0.0204 |
| 7 | 3.7902 | 0.3657 |
| 8 | 4.2956 | 0.8360 |
| 9 | 4.8009 | 0.9922 |
| 10 | 5.3063 | 0.6849 |

(Sanity check: $k=0$ gives $P(0)=\sin^2(\theta/2)=M/N=1/16=0.0625$ exactly,
as it must — no rotation has been applied yet, so this is just the overlap
of the initial state $|s\rangle$ with $|good\rangle$.)

The probability rises from $k=0$ to a peak at $k=3$ ($\approx0.962$), then
falls to a trough around $k=6$ ($\approx0.020$) — the "overshoot" — before
climbing again toward a *second*, even higher peak near $k=9$
($\approx0.992$). This is exactly the periodicity implied by the rotation
picture: each iteration advances the state's angle by the fixed amount
$\theta$, so $\sin^2$ of that angle repeats (up to the sign ambiguity that
squaring removes) with period $\pi/\theta\approx6.22$ iterations in $k$ —
consistent with the second peak appearing roughly $6$ iterations after the
first ($9-3=6$). Stopping at the *first* peak ($k=3$) is what the
algorithm actually does in practice, since it reaches near-certainty using
the fewest oracle queries; continuing past it wastes queries only to
arrive back near the same success probability later.

## Code lab

The simulation for today's Exercises 4–5 is already written at
`quantum_computing_foundations/code/day11_grover_simulation.py`. It
implements exactly the operators from the Theory section for the
$N=16,M=1$ instance: `oracle()` flips the sign of the amplitude at the one
marked index (this *is* $O_f$ for $M=1$ — sign-flipping a single basis
state's amplitude is precisely $I-2|x_{marked}\rangle\langle x_{marked}|$),
and `diffusion()` computes `2 * (<s|state> * s) - state`, which is
literally $D=2|s\rangle\langle s|-I$ applied to `state`, using the same
projection-then-double-then-subtract structure derived in Exercise 2.

Run it with:
```bash
cd quantum_computing_foundations
python3 code/day11_grover_simulation.py
```

**Expected behavior**, tying directly back to Exercises 4 and 5: the
printed probability of measuring the marked state should climb from
$0.0625$ at iteration $0$ (matching $M/N=1/16$, the sanity check above),
rise through iterations $1$ and $2$, **peak at iteration $3$** near
$0.96$ — the exact $k=3$ predicted in Exercise 4 — and then *decrease*
again on iterations $4$ and beyond as the rotation overshoots
$|good\rangle$ and continues past it, exactly the non-monotonic,
periodic behavior derived in Exercise 5's table. If your printed peak
iteration doesn't land at $3$, or the values don't roughly match the
table in Exercise 5's solution, recheck the `marked` index and the
`diffusion` implementation against the $D=2|s\rangle\langle s|-I$
definition before trusting the rest of the run. Record the printed peak
iteration and probability in `notes/day11_grovers.md` alongside your
hand-computed values from Exercise 4.

## Journal template

```
## Day 11 — Grover's algorithm & amplitude amplification
Key idea in my own words: ...
What confused me: ...
```
