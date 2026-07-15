# Day 13 — Number Theory for Shor's Algorithm & the Quantum Fourier Transform

## Learning objectives

By the end of today you should be able to:
- Define the multiplicative order of $a$ mod $N$, state Euler's theorem, and
  compute an order by brute force, checking it divides $\varphi(N)$.
- State and prove Miller's reduction: how an even-order, non-$(-1)$
  order-finding result yields a nontrivial factor of $N$ via a single gcd
  computation.
- Work the full $N=15,\ a=7$ order-finding-to-factor pipeline by hand, and
  recognize the failure mode when the reduction's hypothesis is violated.
- Derive the Quantum Fourier Transform matrix explicitly for small $N$ and
  verify its unitarity directly.
- Show precisely in what sense the Hadamard transform $H^{\otimes n}$ is a
  special case of the Fourier-transform idea, distinct from the cyclic-group
  QFT used in Shor's algorithm.
- Run the continued-fraction algorithm by hand to recover a low-denominator
  rational from a noisy decimal estimate.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or Nielsen & Chuang, *Quantum Computation and Quantum Information*, the
  chapters covering modular arithmetic / order-finding and the Quantum
  Fourier Transform.
- The theory below is self-contained — you do not need either book to do
  today's work, but reading the matching chapter alongside this is useful
  for a second explanation in different words.

## Theory

### Modular arithmetic and the order of an element

Fix a modulus $N$ and an integer $a$ with $\gcd(a,N)=1$. The set of integers
mod $N$ that are coprime to $N$ forms a group under multiplication, denoted
$\mathbb{Z}_N^*$, of size $\varphi(N)$ (Euler's totient function — the count
of integers in $\{1,\dots,N\}$ coprime to $N$). The **order** of $a$ mod $N$
is the smallest positive integer $r$ such that
$$a^r \equiv 1 \pmod N.$$
This $r$ exists because $\mathbb{Z}_N^*$ is a finite group, so the powers
$a^1,a^2,a^3,\dots$ must eventually repeat, and the first repeat is at
$a^r=a^0=1$ (if $a^i\equiv a^j$ with $i<j$ then $a^{j-i}\equiv1$, so some
positive power of $a$ is $\equiv1$; take the smallest).

**Euler's theorem:** $a^{\varphi(N)}\equiv1\pmod N$. This is Lagrange's
theorem applied to $\mathbb{Z}_N^*$: the order of any group element divides
the order of the group, so $r \mid \varphi(N)$. (Sketch of Lagrange's
theorem here: the powers $1,a,a^2,\dots,a^{r-1}$ form a subgroup of
$\mathbb{Z}_N^*$ of size $r$, and the cosets of this subgroup partition
$\mathbb{Z}_N^*$ into equal-size blocks, so $r$ divides $|\mathbb{Z}_N^*| =
\varphi(N)$.)

Shor's algorithm needs exactly this $r$ for a well-chosen $a$: quantum phase
estimation (Day 14) extracts $r$ efficiently, where every known classical
algorithm is believed to need superpolynomial time.

### Miller's reduction: from order to factor

The link from "found the order $r$" to "found a factor of $N$" is a single
algebraic identity, valid whenever $N=pq$ is composite with two (or more)
coprime factors:

**Claim.** Let $r$ be the order of $a$ mod $N$ ($\gcd(a,N)=1$), suppose $r$
is even, and suppose $a^{r/2}\not\equiv-1\pmod N$. Then
$$d = \gcd\!\left(a^{r/2}-1,\ N\right)$$
is a **nontrivial** factor of $N$ (i.e. $1 < d < N$).

**Proof.** Since $r$ is even, write $r=2m$ with $m=r/2$. By definition of
the order, $a^{2m}\equiv1\pmod N$, i.e.
$$a^{2m}-1 \equiv 0 \pmod N \quad\Longleftrightarrow\quad (a^m-1)(a^m+1)
\equiv 0 \pmod N.$$
So $N$ divides the product $(a^m-1)(a^m+1)$.

Now consider the two factors separately:

- $N \nmid (a^m-1)$: if $N$ divided $a^m-1$ we would have $a^m\equiv1\pmod
  N$ with $0<m<r$, contradicting that $r$ is the *smallest* positive
  exponent with $a^r\equiv1$.
- $N \nmid (a^m+1)$: this is exactly the assumption $a^{r/2}\not\equiv-1
  \pmod N$, i.e. $a^m+1\not\equiv0\pmod N$.

So $N$ divides the product $(a^m-1)(a^m+1)$ but divides neither factor
individually. Since $N=pq$ (or more generally has at least two distinct
prime factors), this is only possible if $N$'s prime factors are *split*
between the two terms — some of $N$'s factors divide $a^m-1$ and the
complementary factors divide $a^m+1$, with neither side getting all of
$N$. Concretely: let $d=\gcd(a^m-1,N)$. Since $N\mid(a^m-1)(a^m+1)$, every
prime power dividing $N$ divides at least one of the two factors; combined
with $N\nmid(a^m-1)$ and $N\nmid(a^m+1)$ individually, $d$ cannot be $1$
(some nontrivial common factor must exist on the $a^m-1$ side — otherwise
all of $N$'s prime power divides $a^m+1$, i.e. $N\mid a^m+1$, contradiction)
and $d$ cannot be $N$ (that would mean $N\mid a^m-1$, also a
contradiction). Hence $1<d<N$: $d$ is a nontrivial factor of $N$.
$\blacksquare$

The power of this claim is computational: computing $a^{r/2}\bmod N$ and
then a single $\gcd$ (fast, via the Euclidean algorithm) is all that's
needed to turn "the order $r$" into an actual factorization — *provided*
$r$ is even and $a^{r/2}\not\equiv-1$. (If either fails, the reduction
gives no information and a different $a$ must be tried; Shor's algorithm
shows this failure happens with probability at most $1/2$ for a
uniformly random $a$, so retrying a constant expected number of times
succeeds.)

### The Quantum Fourier Transform

The **Quantum Fourier Transform** on an $N$-dimensional space (basis states
$|0\rangle,\dots,|N-1\rangle$) is the unitary
$$\text{QFT}\,|x\rangle = \frac{1}{\sqrt N}\sum_{y=0}^{N-1} \omega^{xy}
|y\rangle, \qquad \omega = e^{2\pi i/N}$$
a primitive $N$-th root of unity. Written as a matrix with entries
$M_{yx} = \omega^{xy}/\sqrt N$ (row $y$, column $x$), $M$ is symmetric
since $\omega^{xy}=\omega^{yx}$.

**Unitarity in general.** The columns of $M$ are orthonormal precisely
because of the geometric-sum identity
$$\sum_{x=0}^{N-1} \omega^{x(y-y')} = \begin{cases} N & y=y' \\ 0 & y\ne
y'\end{cases}.$$
When $y=y'$ every term is $\omega^0=1$, summing to $N$. When $y\ne y'$,
$\omega^{y-y'}$ is itself a nontrivial $N$-th root of unity (since
$0<|y-y'|<N$), and a nontrivial root of unity raised to $x=0,\dots,N-1$
sums to zero (a geometric series with ratio $z\ne1$, $z^N=1$, sums to
$(z^N-1)/(z-1)=0$). Dividing by $N$, this says exactly $\langle
\text{column } y, \text{column } y'\rangle = \delta_{yy'}$ — orthonormal
columns, hence unitary.

### Deriving the $N=4$ matrix explicitly

For $n=2$ qubits, $N=2^n=4$ and $\omega=e^{2\pi i/4}=e^{i\pi/2}=i$. The
matrix entries are $M_{yx}=i^{xy}/2$. Tabulating $i^{xy}$ for
$x,y\in\{0,1,2,3\}$ (using $i^2=-1,\ i^3=-i,\ i^4=1$, and reducing exponents
mod $4$):

$$M = \frac12\begin{pmatrix}
1 & 1 & 1 & 1 \\
1 & i & -1 & -i \\
1 & -1 & 1 & -1 \\
1 & -i & -1 & i
\end{pmatrix}$$

(row/column index running $0,1,2,3$; row $y$, column $x$, entry
$i^{xy}/2$).

### Reducing to the Hadamard transform on $(\mathbb{Z}_2)^n$

The QFT above is the Fourier transform for the **cyclic** group
$\mathbb{Z}_N$. The Hadamard transform $H^{\otimes n}$ used in Days 8 and 10
is the Fourier transform for a *different* group — the direct product
$(\mathbb{Z}_2)^n$ (bitwise XOR on $n$-bit strings) — and the two coincide
only when these groups coincide, i.e. at $n=1$ ($\mathbb{Z}_2 =
(\mathbb{Z}_2)^1$).

To see this precisely: the Fourier transform for the cyclic group
$\mathbb{Z}_2$ (i.e. $N=2$) uses $\omega=e^{2\pi i/2}=e^{i\pi}=-1$, giving
the $2\times2$ matrix $\frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}
= H$ exactly. The Fourier transform for the direct-product group
$(\mathbb{Z}_2)^n$ is, by the general theory of Fourier analysis on finite
abelian groups, the *tensor product* of the per-factor transforms (since a
direct product's characters are products of each factor's characters):
$$\text{QFT}_{(\mathbb{Z}_2)^n} = \underbrace{\text{QFT}_{\mathbb{Z}_2}
\otimes\cdots\otimes \text{QFT}_{\mathbb{Z}_2}}_{n\text{ times}} = H\otimes
\cdots\otimes H = H^{\otimes n}.$$
This can be checked directly on matrix entries too: the characters of
$(\mathbb{Z}_2)^n$ are $\chi_y(x) = (-1)^{x\cdot y}$ where $x\cdot y =
\sum_i x_iy_i \bmod 2$, so the transform matrix entries are
$(-1)^{x\cdot y}/\sqrt{2^n}$ — exactly the identity
$H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle$
from Day 10. This is a genuinely different unitary from the cyclic
$\text{QFT}_{2^n}$ for $n\ge2$ (e.g. $\text{QFT}_4 \ne H\otimes H$ — compare
the $N=4$ matrix above, which has $i$'s in it, against $H\otimes H$, which
is entirely real): the "reduction" is precise about *which group* is being
Fourier-transformed, not a claim that the two matrices are literally equal
for $n\ge2$.

### Continued fractions

Given a real number $x_0$ (in Shor's algorithm, a phase estimate
$\varphi\approx k/r$), the **continued-fraction expansion** is built by
repeatedly peeling off the integer part and inverting the remainder:
$$a_i = \lfloor x_i \rfloor, \qquad x_{i+1} = \frac{1}{x_i - a_i}
\quad(\text{if } x_i \ne a_i).$$
The **convergents** $p_n/q_n$ are computed from the $a_i$ by the recurrence
(with $p_{-2}=0,\ q_{-2}=1,\ p_{-1}=1,\ q_{-1}=0$):
$$p_n = a_n p_{n-1} + p_{n-2}, \qquad q_n = a_n q_{n-1} + q_{n-2}.$$
Each convergent $p_n/q_n$ is in lowest terms, and — the fact that makes this
useful for Shor's algorithm — it is the *best* rational approximation to
$x_0$ among all fractions with denominator $\le q_n$. So given a noisy
estimate of $k/r$ and an a-priori bound on $r$, running this expansion
until the denominator first exceeds the bound, then backing up one step,
recovers $k/r$ exactly despite the noise (stated here as the operational
fact used below; the full approximation-theory proof is standard but not
re-derived today).

## Worked example

**Full pipeline: $N=15$, $a=7$.**

First, $\gcd(7,15)=1$, so $7$ has a well-defined order mod $15$. Find it by
brute force:
$$7^1 = 7,$$
$$7^2 = 49 = 3\cdot15+4 \equiv 4 \pmod{15},$$
$$7^3 = 7\cdot4 = 28 = 15+13 \equiv 13 \pmod{15},$$
$$7^4 = 7\cdot13 = 91 = 6\cdot15+1 \equiv 1 \pmod{15}.$$
The first power that hits $1$ is the fourth, so the order is $r=4$. (Sanity
check via Euler: $\varphi(15)=(3-1)(5-1)=8$, and indeed $4\mid8$.)

$r=4$ is even, so Miller's reduction applies. Compute $a^{r/2} = 7^2 \equiv
4\pmod{15}$ (already computed above). Check the hypothesis: is
$4\equiv-1\pmod{15}$, i.e. is $4\equiv14$? No — the hypothesis holds, so
the reduction is guaranteed to produce a nontrivial factor.

Compute
$$d = \gcd(7^{2}-1,\ 15) = \gcd(4-1,\ 15) = \gcd(3,15) = 3.$$
Indeed $3\mid15$ and $1<3<15$: $d=3$ is a nontrivial factor, and
$15/3=5$ is the complementary factor — recovering the full factorization
$15=3\times5$ from a single order-finding computation plus one gcd.

**Keep $r=4$** — Day 14 reuses this exact value when tracing the full
Quantum Phase Estimation pipeline for $N=15,a=7$.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Compute $\varphi(15)$ directly from its prime factorization. Separately,
   find the order of $2$ mod $15$ by brute force (list $2^1,2^2,2^3,\dots$
   mod $15$ until you hit $1$), and verify your order divides $\varphi(15)$.
2. Without looking back at the Theory section, reprove Miller's reduction
   from scratch: state the claim precisely and reproduce the proof that
   $\gcd(a^{r/2}-1,N)$ is a nontrivial factor of $N=pq$ under the stated
   hypotheses.
3. Apply Miller's reduction to $N=15,\ a=4$: find the order of $4$ mod
   $15$ by brute force, check the hypotheses, and compute the resulting
   factor.
4. Apply Miller's reduction to $N=15,\ a=14$ (note $14\equiv-1\pmod{15}$):
   find the order of $14$ mod $15$, and explain exactly which hypothesis of
   the theorem fails and why the resulting gcd is trivial rather than a
   factor.
5. Derive the $4\times4$ QFT matrix for $N=4$ explicitly (as in the Theory
   section) and verify unitarity directly by checking that all $\binom42=6$
   pairs of distinct columns are orthogonal and all $4$ columns have norm
   $1$.
6. Show precisely why $H^{\otimes n}$ equals the Fourier transform for the
   group $(\mathbb{Z}_2)^n$, and why this is a different statement from
   "$H^{\otimes n}$ equals the cyclic QFT on $2^n$ dimensions" (give a
   concrete example distinguishing the two for $n=2$).
7. Run the continued-fraction expansion of $0.6247$ by hand (equivalently,
   of the exact fraction $6247/10000$, via the Euclidean algorithm) down to
   the convergent with the largest denominator $\le10$. Confirm it recovers
   $5/8$.

## Solutions

**1.** $15=3\times5$, so $\varphi(15) = (3-1)(5-1) = 2\times4 = 8$.

Powers of $2$ mod $15$: $2^1=2$, $2^2=4$, $2^3=8$, $2^4=16\equiv1\pmod{15}$.
The order is $r=4$. Check: $4\mid8$ — yes, consistent with Euler's theorem
($r\mid\varphi(15)$).

**2.** *Claim:* if $r$ is the order of $a$ mod $N=pq$, $r$ is even, and
$a^{r/2}\not\equiv-1\pmod N$, then $\gcd(a^{r/2}-1,N)$ is a nontrivial
factor of $N$.

*Proof:* write $m=r/2$. Since $a^r=a^{2m}\equiv1\pmod N$,
$(a^m-1)(a^m+1)=a^{2m}-1\equiv0\pmod N$, so $N\mid(a^m-1)(a^m+1)$. $N\nmid
a^m-1$, since that would give $a^m\equiv1$ with $0<m<r$, contradicting
minimality of $r$. $N\nmid a^m+1$, by the assumption $a^{r/2}\ne-1$. So $N$
divides the product of the two factors while dividing neither factor
alone, which (since $N=pq$ has two distinct prime factors to distribute)
forces $\gcd(a^m-1,N)$ to be strictly between $1$ and $N$: it can't be $1$
(else all of $N$'s factors would have to divide $a^m+1$, i.e. $N\mid
a^m+1$, contradiction) and can't be $N$ (that's exactly the excluded case
$N\mid a^m-1$). Hence $d=\gcd(a^{r/2}-1,N)$ satisfies $1<d<N$. $\blacksquare$

**3.** $4^1=4$, $4^2=16\equiv1\pmod{15}$. Order $r=2$, even. $a^{r/2}=4^1=4
\pmod{15}$; check $4\ne14$ ($-1\bmod15$), hypothesis holds. Compute
$\gcd(4-1,15)=\gcd(3,15)=3$ — the same nontrivial factor $3$ found in the
worked example (a different $a$ can recover the same or a different factor
of $N$; here it happens to coincide).

**4.** $14 \equiv -1 \pmod{15}$, so $14^1\equiv-1$, $14^2\equiv(-1)^2=1
\pmod{15}$. Order $r=2$, even. $a^{r/2}=14^1\equiv-1\pmod{15}$ — this is
*exactly* the excluded case $a^{r/2}\equiv-1\pmod N$, so the hypothesis of
Miller's reduction fails and the theorem gives no guarantee. Checking
directly: $\gcd(14-1,15)=\gcd(13,15)=1$, a trivial gcd — no factor is
recovered. This illustrates why the theorem's hypothesis is not a technical
formality: when it fails, the construction genuinely produces nothing
useful, which is why Shor's algorithm must be prepared to retry with a
different random $a$.

**5.** From the Theory section,
$$M = \frac12\begin{pmatrix}
1 & 1 & 1 & 1 \\
1 & i & -1 & -i \\
1 & -1 & 1 & -1 \\
1 & -i & -1 & i
\end{pmatrix}.$$
Every entry has modulus $\tfrac12$ in absolute value $\times$ a unit-modulus
factor, so every column has squared norm $4\times(\tfrac12)^2=1$: unit
norm, confirmed. For orthogonality, compute $\langle \text{col }y,
\text{col }y'\rangle = \sum_x \overline{M_{xy}}M_{xy'}$ for each pair
(equivalently, since the unscaled matrix is symmetric, this is the same as
checking rows):
- $y=0,y'=1$: unscaled entries $(1,1,1,1)$ vs $(1,i,-1,-i)$; dot
  $=1+i-1-i=0$.
- $y=0,y'=2$: $(1,1,1,1)$ vs $(1,-1,1,-1)$; dot $=1-1+1-1=0$.
- $y=0,y'=3$: $(1,1,1,1)$ vs $(1,-i,-1,i)$; dot $=1-i-1+i=0$.
- $y=1,y'=2$: conjugate of $(1,i,-1,-i)$ is $(1,-i,-1,i)$, dot with
  $(1,-1,1,-1)$: $1+i-1-i=0$.
- $y=1,y'=3$: conjugate of $(1,i,-1,-i)$ is $(1,-i,-1,i)$, dot with
  $(1,-i,-1,i)$: $1\cdot1+(-i)(-i)+(-1)(-1)+i\cdot i = 1+i^2+1+i^2 =
  1-1+1-1=0$.
- $y=2,y'=3$: conjugate of $(1,-1,1,-1)$ is itself (real); dot with
  $(1,-i,-1,i)$: $1+i-1-i=0$.

All $6$ pairs are orthogonal and all $4$ columns have norm $1$: the columns
form an orthonormal basis of $\mathbb{C}^4$, so $M$ is unitary.

**6.** The Fourier transform for a finite abelian group $G$ is built from
$G$'s characters; for a direct product $G=G_1\times\cdots\times G_n$, the
characters are products of each factor's characters, so the transform
matrix is the tensor product of the per-factor transform matrices. Taking
$G=(\mathbb{Z}_2)^n = \mathbb{Z}_2\times\cdots\times\mathbb{Z}_2$, the
per-factor transform is $\text{QFT}_{\mathbb{Z}_2}$, which uses
$\omega=e^{2\pi i/2}=-1$ and is exactly the matrix
$\frac{1}{\sqrt2}\begin{pmatrix}1&1\\1&-1\end{pmatrix}=H$. Tensoring $n$
copies gives $\text{QFT}_{(\mathbb{Z}_2)^n} = H^{\otimes n}$ — an identity,
not an approximation, because $H$ literally *is* the $N=2$ cyclic QFT and
$(\mathbb{Z}_2)^n$'s transform is by definition the tensor product of $n$
such factors.

This is a different group from $\mathbb{Z}_{2^n}$ (cyclic of order $2^n$)
for $n\ge2$: $(\mathbb{Z}_2)^2$ has every non-identity element of order $2$,
while $\mathbb{Z}_4$ has an element of order $4$ — they are not isomorphic
groups, so their Fourier transforms are different unitaries. Concretely for
$n=2$: $H\otimes H$ has every entry real ($\pm\tfrac12$), since $H$ itself
is real, whereas $\text{QFT}_4$ (derived in Exercise 5) has entries
$\pm\tfrac12$ *and* $\pm\tfrac{i}2$ — visibly not the same matrix. The
"reduction" is exactly the $(\mathbb{Z}_2)^n$ case, not the cyclic
$\mathbb{Z}_{2^n}$ case.

**7.** Work with the exact fraction $0.6247 = 6247/10000$ and run the
Euclidean algorithm (equivalent to the decimal integer-part/reciprocal
process):
$$10000 = 1\cdot6247 + 3753 \Rightarrow a_1=1$$
$$6247 = 1\cdot3753 + 2494 \Rightarrow a_2=1$$
$$3753 = 1\cdot2494 + 1259 \Rightarrow a_3=1$$
$$2494 = 1\cdot1259 + 1235 \Rightarrow a_4=1$$
$$1259 = 1\cdot1235 + 24 \Rightarrow a_5=1$$
$$1235 = 51\cdot24 + 11 \Rightarrow a_6=51$$
(and the expansion continues, but the denominators are already past the
bound by this point, as shown below). Together with $a_0=\lfloor
0.6247\rfloor=0$, the continued fraction is $[0;1,1,1,1,1,51,\dots]$.

Compute convergents via $p_n=a_np_{n-1}+p_{n-2}$, $q_n=a_nq_{n-1}+q_{n-2}$
(starting $p_{-2}=0,q_{-2}=1,p_{-1}=1,q_{-1}=0$):

| $n$ | $a_n$ | $p_n$ | $q_n$ | convergent |
|---|---|---|---|---|
| 0 | 0 | 0 | 1 | $0/1$ |
| 1 | 1 | 1 | 1 | $1/1$ |
| 2 | 1 | 1 | 2 | $1/2$ |
| 3 | 1 | 2 | 3 | $2/3$ |
| 4 | 1 | 3 | 5 | $3/5$ |
| 5 | 1 | 5 | 8 | $5/8$ |
| 6 | 51 | 258 | 413 | $258/413$ |

The denominator jumps from $8$ (row $n=5$) to $413$ (row $n=6$), which
exceeds the bound $r\le10$. So the last convergent within the bound is
$$\frac{5}{8} = 0.625,$$
which matches the target: $0.6247$ rounds to $0.625$ to three decimal
places, and $5/8$ is indeed the best rational approximation to $0.6247$
with denominator $\le10$ (checking nearby candidates confirms it: $3/5=0.6$
is off by $0.0247$, $2/3\approx0.667$ is off by $0.042$, while $5/8=0.625$
is off by only $0.0003$). This confirms the continued-fraction step of
Shor's algorithm recovers the exact target ratio despite realistic
measurement-level noise in the phase estimate.

## Journal template

```
## Day 13 — Number theory for Shor's algorithm & the Quantum Fourier Transform
Key idea in my own words: ...
What confused me: ...
```
