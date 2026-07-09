# Day 1 — Vector Spaces, Subspaces, Span

## Learning objectives

By the end of today you should be able to:
- State the vector space axioms and check whether a given set with given
  operations satisfies them.
- Prove whether a subset of a vector space is or is not a subspace.
- Prove that the span of a set of vectors is always a subspace.
- Determine, by hand, whether a given vector lies in the span of a given set.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapters 1–2 — [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §1.1–1.3 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Vector Spaces — if you don't have a copy, the exercises below are
  self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF to
do today's work, but reading his §1.1–1.3 alongside this is the "theory" layer
of today's three-layer structure.

## Theory

### Definition 1.1 (Vector space)

A **vector space** over $\mathbb{R}$ is a set $V$ together with two operations,
vector addition $+: V \times V \to V$ and scalar multiplication
$\cdot: \mathbb{R} \times V \to V$, satisfying for all $u, v, w \in V$ and all
$a, b \in \mathbb{R}$:

1. $u + v = v + u$ (commutativity)
2. $(u + v) + w = u + (v + w)$ (associativity)
3. There exists $0 \in V$ such that $v + 0 = v$ for all $v$ (additive identity)
4. For every $v \in V$ there exists $-v \in V$ such that $v + (-v) = 0$
5. $a(u + v) = au + av$ (distributivity over vector addition)
6. $(a + b)v = av + bv$ (distributivity over scalar addition)
7. $a(bv) = (ab)v$ (associativity of scalar multiplication)
8. $1v = v$ (identity for scalar multiplication)

$\mathbb{R}^n$ with the usual coordinate-wise addition and scalar
multiplication is the running example for this whole 30-day plan, but the
definition is deliberately abstract — it also applies to spaces of matrices,
polynomials, and functions, which is why the proofs below are written
generically in terms of $V$ rather than assuming coordinates.

### Definition 1.2 (Subspace)

A subset $W \subseteq V$ is a **subspace** of $V$ if:
1. $0 \in W$ (equivalently, $W \neq \emptyset$ together with closure below),
2. $W$ is closed under addition: $u, v \in W \implies u + v \in W$,
3. $W$ is closed under scalar multiplication: $u \in W, a \in \mathbb{R}
   \implies au \in W$.

A subspace is itself a vector space (all eight axioms are inherited from $V$
since they hold for *all* elements of $V$, hence in particular for elements of
$W$) — this is why checking only the three conditions above is sufficient.

### Definition 1.3 (Linear combination, span)

Given vectors $v_1, \dots, v_k \in V$, a **linear combination** of them is any
vector of the form $a_1v_1 + a_2v_2 + \cdots + a_kv_k$ for scalars $a_i \in
\mathbb{R}$. Given a subset $S \subseteq V$ (possibly infinite), the **span**
of $S$, written $\operatorname{span}(S)$, is the set of all linear
combinations of *finitely many* vectors from $S$.

### Theorem 1.1 (The span of a set is a subspace)

For any $S \subseteq V$, $\operatorname{span}(S)$ is a subspace of $V$.

**Proof.** We check the three conditions of Definition 1.2.

*Contains 0.* If $S = \emptyset$, we adopt the convention that the empty sum
is $0$, so $0 \in \operatorname{span}(S)$. If $S \neq \emptyset$, pick any
$s \in S$; then $0 = 0 \cdot s \in \operatorname{span}(S)$.

*Closed under addition.* Let $u, v \in \operatorname{span}(S)$. Then
$u = \sum_{i=1}^{m} a_i s_i$ and $v = \sum_{j=1}^{n} b_j t_j$ for some
$s_i, t_j \in S$ and scalars $a_i, b_j$. Let $\{r_1, \dots, r_p\} = \{s_1,
\dots, s_m\} \cup \{t_1, \dots, t_n\}$ be the (finite) union of the vectors
used, and rewrite both sums over this common index set, padding with
zero coefficients where a vector doesn't appear in the original sum:
$u = \sum_{k=1}^p c_k r_k$, $v = \sum_{k=1}^p d_k r_k$. Then
$$u + v = \sum_{k=1}^p (c_k + d_k) r_k,$$
which is a finite linear combination of vectors in $S$, so
$u + v \in \operatorname{span}(S)$.

*Closed under scalar multiplication.* Let $u = \sum_{i=1}^m a_i s_i \in
\operatorname{span}(S)$ and $c \in \mathbb{R}$. Then
$cu = \sum_{i=1}^m (ca_i) s_i$, again a finite linear combination of vectors
in $S$, so $cu \in \operatorname{span}(S)$.

All three conditions hold, so $\operatorname{span}(S)$ is a subspace of
$V$. $\blacksquare$

### Theorem 1.2 (Intersection of subspaces is a subspace)

If $W_1, W_2$ are subspaces of $V$, then $W_1 \cap W_2$ is a subspace of $V$.

**Proof.** *Contains 0.* $0 \in W_1$ and $0 \in W_2$ (both are subspaces), so
$0 \in W_1 \cap W_2$.

*Closed under addition.* Let $u, v \in W_1 \cap W_2$. Then $u, v \in W_1$, and
since $W_1$ is a subspace, $u + v \in W_1$. Likewise $u, v \in W_2 \implies
u + v \in W_2$. Hence $u + v \in W_1 \cap W_2$.

*Closed under scalar multiplication.* Let $u \in W_1 \cap W_2$ and $c \in
\mathbb{R}$. Then $u \in W_1 \implies cu \in W_1$, and $u \in W_2 \implies cu
\in W_2$, so $cu \in W_1 \cap W_2$. $\blacksquare$

### Remark (The union of subspaces is generally *not* a subspace)

Let $V = \mathbb{R}^2$, $W_1 = \{(x, 0) : x \in \mathbb{R}\}$ (the $x$-axis),
$W_2 = \{(0, y) : y \in \mathbb{R}\}$ (the $y$-axis). Both are subspaces
(check the three conditions yourself as a warm-up). But $(1,0) \in W_1
\subseteq W_1 \cup W_2$ and $(0,1) \in W_2 \subseteq W_1 \cup W_2$, while
$(1,0) + (0,1) = (1,1) \notin W_1 \cup W_2$ (it's on neither axis). So
$W_1 \cup W_2$ is not closed under addition, hence not a subspace. This is
exactly the kind of claim that *feels* true by analogy with intersection but
is false — always check closure explicitly rather than assuming it.

## Worked example

**Claim:** Let $S = \{(1,0,1), (0,1,1)\} \subseteq \mathbb{R}^3$. Then
$(2,3,5) \in \operatorname{span}(S)$ but $(1,1,1) \notin \operatorname{span}(S)$.

**Check $(2,3,5)$:** we need $a, b$ with $a(1,0,1) + b(0,1,1) = (a, b, a+b) =
(2,3,5)$. Reading off coordinates: $a = 2$, $b = 3$, and $a + b = 5$ ✓
(consistent). So $(2,3,5) = 2(1,0,1) + 3(0,1,1) \in \operatorname{span}(S)$.

**Check $(1,1,1)$:** we need $a(1,0,1) + b(0,1,1) = (a,b,a+b) = (1,1,1)$.
Reading off: $a = 1$, $b = 1$, but then $a + b = 2 \neq 1$ — contradiction.
No such $a, b$ exist, so $(1,1,1) \notin \operatorname{span}(S)$.

Notice the pattern: because $S$ has only 2 vectors in $\mathbb{R}^3$, its span
is (at most) a 2-dimensional plane through the origin, and $(a, b, a+b)$ shows
that plane is exactly $\{(x,y,z) : z = x + y\}$. $(1,1,1)$ fails $z = x+y$
since $1 \neq 1+1$.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–4 and 6–7 are computational; 5, 8, 9, 10 are proof-based.

1. Prove that $\{0\}$ (the set containing only the zero vector) is a subspace
   of any vector space $V$.
2. Let $V = \mathbb{R}^3$ and $W = \{(x,y,z) : x + y + z = 0\}$. Is $W$ a
   subspace of $V$? Prove your answer.
3. Let $V = \mathbb{R}^3$ and $W = \{(x,y,z) : x + y + z = 1\}$. Is $W$ a
   subspace of $V$? Prove your answer.
4. Let $P_n$ denote the set of polynomials of degree $\le n$ (including the
   zero polynomial), as a subset of the vector space $P$ of all polynomials.
   Prove $P_n$ is a subspace of $P$.
5. Find two subspaces $W_1, W_2$ of $\mathbb{R}^2$, different from the
   $x$-axis/$y$-axis example above, such that $W_1 \cup W_2$ is not a
   subspace. Prove your example works.
6. Let $S = \{(1,2,0), (0,1,1), (1,3,1)\} \subseteq \mathbb{R}^3$. Is
   $\operatorname{span}(S)$ all of $\mathbb{R}^3$, a plane through the
   origin, or a line through the origin? Justify your answer.
7. Determine whether $v = (4,1,3)$ is in the span of $\{(1,0,1), (2,1,0)\}$.
   Show your work.
8. Prove: if $S_1 \subseteq S_2 \subseteq V$, then
   $\operatorname{span}(S_1) \subseteq \operatorname{span}(S_2)$.
9. Using problem 8 and the fact that $\operatorname{span}(S)$ is a subspace
   (Theorem 1.1), prove that $\operatorname{span}(\operatorname{span}(S)) =
   \operatorname{span}(S)$.
10. True or False, with justification: the set of all invertible $2\times2$
    matrices is a subspace of $M_2(\mathbb{R})$ (the vector space of all
    $2\times2$ real matrices, under matrix addition and scalar
    multiplication).

## Solutions

**1.** $\{0\}$ contains $0$ by definition. Closure under addition: $0 + 0 = 0
\in \{0\}$. Closure under scalar multiplication: for any $c$, $c \cdot 0 = 0
\in \{0\}$. All three conditions hold, so $\{0\}$ is a subspace (the *trivial*
or *zero subspace*).

**2.** Yes, $W$ is a subspace. Contains $0$: $0+0+0 = 0$ ✓. Closed under
addition: if $(x_1,y_1,z_1), (x_2,y_2,z_2) \in W$ then
$(x_1+x_2)+(y_1+y_2)+(z_1+z_2) = (x_1+y_1+z_1) + (x_2+y_2+z_2) = 0 + 0 = 0$,
so the sum is in $W$. Closed under scalar multiplication: if $(x,y,z) \in W$
and $c \in \mathbb{R}$, then $cx+cy+cz = c(x+y+z) = c\cdot 0 = 0$, so
$c(x,y,z) \in W$. $W$ is the plane through the origin with normal
$(1,1,1)$.

**3.** No. $0 = (0,0,0)$ gives $0+0+0 = 0 \neq 1$, so $0 \notin W$. Since
every subspace must contain $0$, $W$ is not a subspace. (Geometrically, $W$
is a plane, but it does *not* pass through the origin — it's an affine
subspace, not a linear subspace.)

**4.** The zero polynomial has degree $\le n$ trivially, so $0 \in P_n$. If
$p, q \in P_n$ (each has degree $\le n$), then $p + q$ has degree $\le n$ too
— adding polynomials can only cancel terms or leave degree unchanged, never
increase it. If $p \in P_n$ and $c \in \mathbb{R}$, $cp$ has degree $\le n$
(or is the zero polynomial if $c=0$). All three conditions hold.

**5.** Let $W_1 = \operatorname{span}\{(1,0)\}$ and $W_2 =
\operatorname{span}\{(1,1)\}$ (any two distinct lines through the origin
work). $(1,0) \in W_1$ and $(1,1) \in W_2$, so both are in $W_1 \cup W_2$.
Their sum is $(2,1)$. Is $(2,1) \in W_1$? $W_1 = \{(t,0): t\in\mathbb R\}$
requires the second coordinate to be $0$; it's $1$, so no. Is $(2,1) \in
W_2$? $W_2 = \{(t,t)\}$ requires both coordinates equal; $2 \neq 1$, so no.
So $(2,1) \notin W_1 \cup W_2$, and the union isn't closed under addition —
not a subspace.

**6.** Check whether the third vector is redundant: $(1,2,0) + (0,1,1) =
(1,3,1)$ — yes, exactly the third vector. So
$\operatorname{span}(S) = \operatorname{span}\{(1,2,0),(0,1,1)\}$. These two
remaining vectors are not scalar multiples of each other (so they're linearly
independent — a formal test for this is Day 2's topic), so their span is a
genuine 2-dimensional subspace: a **plane through the origin**, not all of
$\mathbb{R}^3$ and not a line.

**7.** Solve $a(1,0,1) + b(2,1,0) = (a+2b,\, b,\, a) = (4,1,3)$. From the
third coordinate, $a = 3$. From the second coordinate, $b = 1$. Check the
first coordinate: $a + 2b = 3 + 2 = 5 \neq 4$ — contradiction. No solution
exists, so $v \notin \operatorname{span}\{(1,0,1),(2,1,0)\}$.

**8.** Let $w \in \operatorname{span}(S_1)$. Then $w = \sum_{i=1}^k a_i s_i$
for some $s_i \in S_1$. Since $S_1 \subseteq S_2$, each $s_i \in S_2$ as
well, so this same expression exhibits $w$ as a finite linear combination of
vectors in $S_2$, i.e. $w \in \operatorname{span}(S_2)$. Since $w$ was
arbitrary, $\operatorname{span}(S_1) \subseteq \operatorname{span}(S_2)$.

**9.** Since $S \subseteq \operatorname{span}(S)$ (every $s \in S$ equals
$1 \cdot s \in \operatorname{span}(S)$), problem 8 gives
$\operatorname{span}(S) \subseteq \operatorname{span}(\operatorname{span}(S))$.
For the reverse inclusion: by Theorem 1.1, $\operatorname{span}(S)$ is
already a subspace, hence closed under addition and scalar multiplication;
so *any* linear combination of vectors already in $\operatorname{span}(S)$
is again in $\operatorname{span}(S)$ (by repeated closure), i.e.
$\operatorname{span}(\operatorname{span}(S)) \subseteq \operatorname{span}(S)$.
Both inclusions give equality.

**10.** False. The zero matrix $\begin{pmatrix}0&0\\0&0\end{pmatrix}$ is not
invertible, so the set doesn't contain $0$ — already enough to fail
Definition 1.2. (It also fails closure under addition: $I$ and $-I$ are both
invertible, but $I + (-I) = 0$ is not.)

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical span-membership test. Open
`starter_code/day01_vector_spaces.py` — it has one function to complete,
`is_in_span`. Fill in the `TODO`, then run the file directly
(`python starter_code/day01_vector_spaces.py`); it should print
`All checks passed!`.

**Hint:** stack the given vectors as columns of a matrix $A$, solve
$A x \approx b$ with `np.linalg.lstsq`, and check whether the residual
$\|Ax - b\|$ is (numerically) zero — that's the computational analogue of the
"solve for $a, b$" technique you used by hand in Exercise 7.

If you get stuck for more than ~10 minutes, check
`solutions/day01_vector_spaces.py` — but only after a real attempt.

Once your implementation passes, extend it: pick two vectors of your own in
$\mathbb{R}^4$, and construct a third vector you can *prove* by hand is
outside their span (same technique as Exercise 7), then confirm your code
agrees.

## Journal template

```
## Day 1 — Vector spaces, span
Key theorem in my own words: ...
What confused me: ...
```
