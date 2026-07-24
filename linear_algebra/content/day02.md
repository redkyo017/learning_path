# Day 2 — Linear Independence, Basis, Dimension

## Learning objectives

By the end of today you should be able to:
- State the definition of linear independence and prove, from the definition,
  whether a given finite set of vectors is independent or dependent.
- Prove that a set is linearly independent if and only if no vector in it is a
  linear combination of the others, and use this to find explicit dependency
  relations.
- Prove that every finite spanning set contains a basis, and that all bases of
  a finite-dimensional vector space have the same size (so "dimension" is
  well-defined).
- Find a basis for the span of a given finite set of vectors and state its
  dimension.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 2 ("Linear combinations, span, and basis vectors") —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §1.4–1.5 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson),
  chapter on Vector Spaces, independence/basis/dimension problems, if you have
  a copy — the exercises below are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF to
do today's work, but reading his §1.4–1.5 alongside this is the "theory" layer
of today's three-layer structure.

## Theory

### Definition 2.1 (Linear independence)

A finite set of vectors $\{v_1, \dots, v_n\} \subseteq V$ is **linearly
independent** if the only scalars $a_1, \dots, a_n \in \mathbb{R}$ satisfying
$$a_1v_1 + a_2v_2 + \cdots + a_nv_n = 0$$
are $a_1 = a_2 = \cdots = a_n = 0$ (the *trivial* solution). If some nontrivial
solution exists (some $a_i \neq 0$), the set is **linearly dependent**.

### Theorem 2.1 (Independence $\iff$ no vector is a combination of the others)

A set $\{v_1, \dots, v_n\} \subseteq V$ is linearly independent if and only if
no $v_i$ is a linear combination of the remaining vectors $\{v_1, \dots,
v_n\} \setminus \{v_i\}$.

(When $n = 1$, "the remaining vectors" is the empty set, and the only linear
combination of the empty set is $0$ by convention; so the statement for
$n = 1$ reads "$\{v_1\}$ is independent iff $v_1 \neq 0$," which matches
Definition 2.1 directly: $a_1 v_1 = 0$ with $v_1 \ne 0$ forces $a_1 = 0$.)

**Proof.** We prove both directions.

($\Rightarrow$) Suppose $\{v_1, \dots, v_n\}$ is linearly independent. Suppose
toward contradiction that some $v_i$ *is* a linear combination of the others,
say $v_i = \sum_{j \neq i} c_j v_j$. Rearranging,
$$1 \cdot v_i + \sum_{j \neq i} (-c_j) v_j = 0.$$
This is a linear combination of $\{v_1, \dots, v_n\}$ equal to $0$ in which
the coefficient of $v_i$ is $1 \neq 0$ — a nontrivial solution. This
contradicts linear independence. Hence no $v_i$ is a linear combination of
the others.

($\Leftarrow$) Suppose no $v_i$ is a linear combination of the remaining
vectors. We show $\{v_1, \dots, v_n\}$ is linearly independent. Suppose
$a_1v_1 + \cdots + a_nv_n = 0$ for some scalars, and suppose toward
contradiction that this solution is nontrivial, i.e., $a_k \neq 0$ for some
$k$. Then we can isolate $v_k$:
$$a_k v_k = -\sum_{j \neq k} a_j v_j \implies v_k = \sum_{j \neq k}
\left(-\frac{a_j}{a_k}\right) v_j,$$
(division by $a_k$ is valid since $a_k \neq 0$). This expresses $v_k$ as a
linear combination of the remaining vectors, contradicting our hypothesis.
Hence no nontrivial solution exists, i.e. $a_1 = \cdots = a_n = 0$, so
$\{v_1, \dots, v_n\}$ is linearly independent. $\blacksquare$

### Definition 2.2 (Basis, dimension)

A finite set $B = \{v_1, \dots, v_n\} \subseteq V$ is a **basis** of $V$ if:
1. $B$ spans $V$: $\operatorname{span}(B) = V$, and
2. $B$ is linearly independent.

If $V$ has a finite basis, $V$ is called **finite-dimensional**, and (once
Theorem 2.3 below is established) the **dimension** of $V$, written
$\dim V$, is defined as the number of elements in *any* basis of $V$. (By
convention, $V = \{0\}$ has the empty set as its basis, and $\dim\{0\} = 0$.)

### Theorem 2.2 (Every finite spanning set contains a basis)

If $S = \{v_1, \dots, v_n\}$ is a finite spanning set of $V$ (i.e.
$\operatorname{span}(S) = V$), then some subset of $S$ is a basis of $V$.

**Proof.** If $S$ is linearly independent, then $S$ itself already satisfies
both conditions of Definition 2.2 (it spans $V$ by hypothesis and is
independent), so $S$ is a basis and we are done.

Otherwise $S$ is linearly dependent, so by Definition 2.1 there exist
scalars $a_1, \dots, a_n$, not all zero, with $a_1v_1 + \cdots + a_nv_n = 0$.
Pick an index $i$ with $a_i \neq 0$. By the ($\Leftarrow$-direction argument
used in the proof of Theorem 2.1), $v_i$ is a linear combination of
$S \setminus \{v_i\}$.

*Claim:* $\operatorname{span}(S \setminus \{v_i\}) = \operatorname{span}(S)$.
The inclusion $\operatorname{span}(S \setminus \{v_i\}) \subseteq
\operatorname{span}(S)$ is immediate since $S \setminus \{v_i\} \subseteq S$
(Day 1, Exercise 8's monotonicity fact). For the reverse inclusion, let
$u \in \operatorname{span}(S)$, so $u = \sum_{j=1}^n b_j v_j$ for some
scalars $b_j$. Substitute the expression $v_i = \sum_{j \neq i} c_j v_j$
(derived above) for $v_i$:
$$u = b_i\Big(\sum_{j \neq i} c_j v_j\Big) + \sum_{j \neq i} b_j v_j =
\sum_{j \neq i} (b_i c_j + b_j) v_j,$$
which is a linear combination of $S \setminus \{v_i\}$ alone. Hence
$u \in \operatorname{span}(S \setminus \{v_i\})$, proving the claim.

So we may discard $v_i$ from $S$ without changing the span. This gives a new
spanning set $S_1 = S \setminus \{v_i\}$ of $V$, with $|S_1| = n - 1$. Repeat
the argument on $S_1$: if it is independent, it is a basis and we stop;
otherwise remove another redundant vector, obtaining $S_2$ with
$|S_2| = n - 2$, and so on. Each step strictly decreases the (finite) size of
the current set while preserving its span (equal to $V$), so this process
must terminate after at most $n$ steps — either because the current set is
independent (hence a basis, by construction it still spans $V$), or because
the set becomes empty, which only happens if $V = \operatorname{span}(\emptyset)
= \{0\}$, in which case the empty set is (by convention) a basis of $\{0\}$.
In either case, we obtain a subset of the original $S$ that is a basis of
$V$. $\blacksquare$

### Lemma 2.3 (Steinitz Exchange Lemma)

If $\{v_1, \dots, v_n\}$ spans $V$ and $\{w_1, \dots, w_m\}$ is linearly
independent in $V$, then $m \le n$.

**Proof.** We prove, by induction on $k = 0, 1, \dots, m$, the following
statement $P(k)$: *it is possible to relabel the $v$'s so that $k \le n$ and
$\{w_1, \dots, w_k, v_{k+1}, \dots, v_n\}$ spans $V$* (when $k = n$ this set
is just $\{w_1, \dots, w_n\}$).

*Base case $k=0$.* $P(0)$ says $\{v_1, \dots, v_n\}$ spans $V$, which is
given.

*Inductive step.* Suppose $P(k)$ holds for some $0 \le k < m$: after
relabeling, $k \le n$ and $\{w_1, \dots, w_k, v_{k+1}, \dots, v_n\}$ spans
$V$. We show $k+1 \le n$ and (after possibly relabeling the remaining $v$'s)
$\{w_1, \dots, w_{k+1}, v_{k+2}, \dots, v_n\}$ spans $V$.

First, suppose for contradiction $k = n$. Then the spanning set from $P(k)$
is exactly $\{w_1, \dots, w_k\}$, so $w_{k+1} \in V = \operatorname{span}
\{w_1,\dots,w_k\}$, i.e. $w_{k+1} = \sum_{i=1}^k a_i w_i$ for some scalars
$a_i$. This expresses $w_{k+1}$ as a linear combination of the other $w$'s,
which by Theorem 2.1 contradicts the linear independence of
$\{w_1, \dots, w_m\}$ (recall $k + 1 \le m$). So $k < n$, i.e. $k + 1 \le n$:
there is at least one $v_j$ ($j > k$) left to exchange.

Since $\{w_1, \dots, w_k, v_{k+1}, \dots, v_n\}$ spans $V$ and
$w_{k+1} \in V$, write
$$w_{k+1} = \sum_{i=1}^k a_i w_i + \sum_{j=k+1}^n b_j v_j$$
for some scalars $a_i, b_j$. Not all $b_j$ ($j = k+1, \dots, n$) can be zero:
if they were, this equation would express $w_{k+1}$ as a linear combination
of $w_1, \dots, w_k$ alone, again contradicting the independence of
$\{w_1, \dots, w_m\}$ by Theorem 2.1. So some $b_j \neq 0$; relabel the
indices $k+1, \dots, n$ (i.e. rename the $v$'s) so that this nonzero
coefficient is $b_{k+1}$. Solving for $v_{k+1}$,
$$v_{k+1} = \frac{1}{b_{k+1}}\left(w_{k+1} - \sum_{i=1}^k a_i w_i -
\sum_{j=k+2}^n b_j v_j\right),$$
which exhibits $v_{k+1}$ as a linear combination of
$\{w_1, \dots, w_{k+1}, v_{k+2}, \dots, v_n\}$.

Now take any $u \in V$. By $P(k)$, $u$ is a linear combination of
$\{w_1, \dots, w_k, v_{k+1}, \dots, v_n\}$. Substituting the expression above
for $v_{k+1}$ into that combination replaces the single term "$v_{k+1}$" by
a linear combination of $\{w_1, \dots, w_{k+1}, v_{k+2}, \dots, v_n\}$, so
overall $u$ becomes a linear combination of
$\{w_1, \dots, w_{k+1}, v_{k+2}, \dots, v_n\}$. Since $u \in V$ was
arbitrary, this set spans $V$ — establishing $P(k+1)$.

By induction, $P(m)$ holds: in particular $m \le n$ (proved along the way at
each step), which is exactly what we needed. $\blacksquare$

### Theorem 2.3 (Dimension is well-defined)

All bases of a finite-dimensional vector space $V$ have the same number of
elements.

**Proof.** Let $B_1 = \{v_1, \dots, v_n\}$ and $B_2 = \{w_1, \dots, w_m\}$
both be bases of $V$. Since $B_1$ spans $V$ and $B_2$ is linearly
independent, Lemma 2.3 gives $m \le n$. Symmetrically, since $B_2$ spans $V$
and $B_1$ is linearly independent, Lemma 2.3 (with the roles of the two sets
swapped) gives $n \le m$. Together, $m = n$. Since $B_1, B_2$ were arbitrary
bases, all bases of $V$ have the same size. $\blacksquare$

This is exactly what makes Definition 2.2's "$\dim V$ = size of *any* basis"
a legitimate definition rather than an ambiguous one: it doesn't matter which
basis you pick to count.

## Worked example

**Claim:** $S = \{v_1, v_2, v_3\} = \{(1,2,3), (0,1,1), (1,4,5)\}$ is
linearly dependent in $\mathbb{R}^3$; $\{v_1, v_2\}$ is independent and hence
a basis for $\operatorname{span}(S)$, a 2-dimensional subspace of
$\mathbb{R}^3$.

**Step 1 — find a dependency relation.** Try to write $v_3$ as a combination
of $v_1, v_2$: we want $a, b$ with $a(1,2,3) + b(0,1,1) = (1,4,5)$, i.e.
$(a, 2a+b, 3a+b) = (1,4,5)$. From the first coordinate, $a = 1$. Substituting
into the second, $2(1) + b = 4 \Rightarrow b = 2$. Check the third
coordinate: $3(1) + 2 = 5$ ✓ (consistent). So
$$v_3 = v_1 + 2v_2, \quad\text{i.e.}\quad (1,4,5) = (1,2,3) + 2(0,1,1).$$

**Step 2 — conclude dependence via Theorem 2.1.** Since $v_3$ is a linear
combination of $v_1, v_2$ (the other two vectors in $S$), Theorem 2.1 tells
us $S$ is linearly dependent. Equivalently, rearranging Step 1 gives the
explicit dependency relation
$$1\cdot v_1 + 2\cdot v_2 + (-1)\cdot v_3 = 0,$$
a nontrivial solution ($a_1,a_2,a_3) = (1,2,-1) \ne (0,0,0)$ to Definition
2.1's equation, confirming dependence directly from the definition too.

**Step 3 — $\{v_1, v_2\}$ is independent.** Suppose $c_1 v_1 + c_2 v_2 = 0$,
i.e. $c_1(1,2,3) + c_2(0,1,1) = (c_1,\, 2c_1+c_2,\, 3c_1+c_2) = (0,0,0)$. The
first coordinate gives $c_1 = 0$; substituting into the second gives
$c_2 = 0$. So the only solution is trivial, and $\{v_1, v_2\}$ is linearly
independent (equivalently: they are not scalar multiples of each other, so
by Theorem 2.1 with $n=2$, neither is a combination — i.e. a scalar multiple
— of the other).

**Step 4 — identify the basis and dimension.** By Step 1,
$v_3 \in \operatorname{span}\{v_1, v_2\}$, so (by the same removal argument
as in Theorem 2.2's proof) $\operatorname{span}(S) =
\operatorname{span}\{v_1, v_2\}$. Combined with Step 3,
$\{v_1, v_2\}$ is a linearly independent spanning set for
$\operatorname{span}(S)$ — a basis, by Definition 2.2. Hence
$\dim \operatorname{span}(S) = 2$: it's a genuine plane through the origin in
$\mathbb{R}^3$, not all of $\mathbb{R}^3$ (dimension 3) and not a line
(dimension 1).

## Unconventional edge

A common trap: memorizing "compute the determinant; zero means dependent" as
a context-free recipe, detached from Definition 2.1. That test only makes
sense when you have exactly $n$ vectors in $\mathbb{R}^n$ — enough to form a
*square* matrix. Hand someone $\{(1,2,3), (0,1,1)\}$ (2 vectors in
$\mathbb{R}^3$) and the recipe-follower will try to "take the determinant"
of a $3\times2$ matrix, which doesn't exist, and either freak out or pad it
with a fabricated row/column — nonsense. The actual tool for a non-square set
is **rank**: stack the vectors as columns and row-reduce (or, as in the
worked example, go straight to Definition 2.1 and solve
$a_1v_1+\cdots+a_kv_k=0$ by hand). The determinant-zero test is a *corollary*
that happens to coincide with rank-deficiency in the square case (you'll see
why once Day 8's determinant theory connects it to invertibility) — it is
never the definition, and reaching for it outside its domain is a sign the
underlying idea (Definition 2.1) hasn't actually been internalized.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–3, 8, 10 are computational; 4–7, 9 are proof-based.

1. Determine whether $\{(1,1,0), (0,1,1), (1,0,-1)\}$ is linearly independent
   in $\mathbb{R}^3$. If dependent, exhibit an explicit nontrivial relation.
2. Determine whether $\{(2,4), (1,2)\}$ is linearly independent in
   $\mathbb{R}^2$.
3. Find a basis for $\operatorname{span}\{(1,1,1), (2,2,2), (1,0,-1)\}
   \subseteq \mathbb{R}^3$ and state its dimension.
4. Working directly from Definition 2.1 (not by inspection/pattern-matching),
   prove that $\{(1,0), (0,1), (1,1)\}$ is linearly dependent in
   $\mathbb{R}^2$, and exhibit the dependency relation.
5. Prove: if $\dim V = n$, then any set of more than $n$ vectors in $V$ is
   linearly dependent. (Use Lemma 2.3.)
6. Prove: every linearly independent set in a finite-dimensional vector space
   $V$ can be extended to a basis of $V$ (i.e., more vectors from $V$ can be
   added to it, if necessary, to make it a basis).
7. True or False, with justification: three vectors can be linearly
   independent in $\mathbb{R}^2$.
8. Let $v_1 = (1,2)$, $v_2 = (3,6)$. Is $\{v_1, v_2\}$ a basis for
   $\mathbb{R}^2$? Justify your answer.
9. Prove: if $\dim V = n$ and $\{v_1, \dots, v_n\}$ (exactly $n$ vectors)
   spans $V$, then $\{v_1, \dots, v_n\}$ is automatically linearly
   independent, hence a basis. (Use Lemma 2.3; this is the useful converse
   fact that "the right count + spanning" already buys you a basis, with no
   independence check needed.)
10. Find a basis for $\operatorname{span}\{(1,2,3,4), (2,4,6,8), (1,0,1,0)\}
    \subseteq \mathbb{R}^4$ and state its dimension.

## Solutions

**1.** Set $a(1,1,0) + b(0,1,1) + c(1,0,-1) = (0,0,0)$. Coordinate-wise:
$a + c = 0$ (first), $a + b = 0$ (second), $b - c = 0$ (third). From the
first two equations, $c = -a$ and $b = -a$; substituting into the third,
$b - c = -a - (-a) = 0$, which holds automatically for *any* $a$ — so
nontrivial solutions exist. Take $a = 1$: then $b = -1$, $c = -1$. Check:
$1(1,1,0) - 1(0,1,1) - 1(1,0,-1) = (1-0-1,\ 1-1-0,\ 0-1+1) = (0,0,0)$ ✓.
So the set is linearly **dependent**, with relation
$v_1 - v_2 - v_3 = 0$, i.e. $v_1 = v_2 + v_3$ (indeed
$(0,1,1)+(1,0,-1) = (1,1,0)$).

**2.** $(2,4) = 2\cdot(1,2)$, so the second vector is a scalar multiple of
the first. By Theorem 2.1 (the $n=2$ case: one vector is "a linear
combination of the other" exactly when it's a scalar multiple), the set is
linearly **dependent**.

**3.** Note $(2,2,2) = 2\cdot(1,1,1)$, so by Theorem 2.1 the second vector is
redundant, and (as in the proof of Theorem 2.2) removing it doesn't change
the span: $\operatorname{span}\{(1,1,1),(2,2,2),(1,0,-1)\} =
\operatorname{span}\{(1,1,1),(1,0,-1)\}$. Check these two remaining vectors
are independent: is $(1,0,-1) = t(1,1,1)$ for some $t$? The first coordinate
forces $t=1$, but then the second coordinate would need to be $1$, not $0$
— no such $t$. So they're not scalar multiples, hence independent (Theorem
2.1, $n=2$ case). A basis is $\{(1,1,1), (1,0,-1)\}$, and the dimension is
**2**.

**4.** We seek scalars $a,b,c$, not all zero, with
$a(1,0) + b(0,1) + c(1,1) = (0,0)$. Coordinate-wise: $a + c = 0$ and
$b + c = 0$. Choose $c = 1$: then $a = -1$, $b = -1$. Check:
$-1(1,0) - 1(0,1) + 1(1,1) = (-1+0+1,\ 0-1+1) = (0,0)$ ✓. This is a
nontrivial solution $(a,b,c) = (-1,-1,1) \neq (0,0,0)$, so by Definition 2.1
the set is linearly dependent. Rearranging: $(1,1) = (1,0) + (0,1)$, i.e.
$v_3 = v_1 + v_2$.

**5.** Let $\{u_1, \dots, u_n\}$ be *some* basis of $V$ (it exists since
$\dim V = n$ means $V$ is finite-dimensional with a basis of size $n$); in
particular it spans $V$. Let $\{w_1, \dots, w_m\}$ be any set of $m > n$
vectors in $V$, and suppose toward contradiction it is linearly independent.
Lemma 2.3, applied with the spanning set $\{u_1,\dots,u_n\}$ and the
independent set $\{w_1,\dots,w_m\}$, gives $m \le n$ — contradicting
$m > n$. So $\{w_1,\dots,w_m\}$ cannot be linearly independent; it is
dependent. $\blacksquare$

**6.** Let $\{v_1, \dots, v_k\}$ be linearly independent in a
finite-dimensional $V$ with $\dim V = n$. We build up a basis containing it.
If $\operatorname{span}\{v_1,\dots,v_k\} = V$, then $\{v_1,\dots,v_k\}$
already spans $V$ and is independent, hence is itself a basis — done. 

Otherwise $\operatorname{span}\{v_1,\dots,v_k\} \neq V$, so there exists some
$w_1 \in V \setminus \operatorname{span}\{v_1,\dots,v_k\}$. *Claim:*
$\{v_1,\dots,v_k,w_1\}$ is linearly independent. Indeed, suppose
$a_1v_1 + \cdots + a_kv_k + b w_1 = 0$. If $b \neq 0$, we could solve
$w_1 = -\frac1b(a_1v_1+\cdots+a_kv_k) \in \operatorname{span}\{v_1,\dots,v_k\}$,
contradicting the choice of $w_1$. So $b = 0$, leaving
$a_1v_1+\cdots+a_kv_k = 0$, which forces $a_1=\cdots=a_k=0$ by independence
of $\{v_1,\dots,v_k\}$. So all coefficients are zero, proving the claim.

Now repeat this process on $\{v_1,\dots,v_k,w_1\}$: either it already spans
$V$ (done, it's a basis extending the original set), or we can again find a
vector outside its span and adjoin it while preserving independence, exactly
as above. Each step increases the size of the independent set by 1. By
Exercise 5 (equivalently Lemma 2.3), no linearly independent set in $V$ can
have more than $n = \dim V$ elements, so this process cannot continue past
$n$ steps total — it must terminate with a spanning independent set, i.e., a
basis, of size $\le n$, containing the original $\{v_1,\dots,v_k\}$.
$\blacksquare$

**7. False.** Since $\dim \mathbb{R}^2 = 2$ (the standard basis
$\{(1,0),(0,1)\}$ has 2 elements), Exercise 5 shows that *any* set of more
than 2 vectors in $\mathbb{R}^2$ — in particular any 3 vectors, no matter how
they're chosen — is automatically linearly dependent. It's tempting to think
"maybe some clever choice of 3 vectors avoids this," but the proof shows the
conclusion is forced by the count alone, independent of which vectors you
pick.

**8.** $(3,6) = 3\cdot(1,2)$, so $v_2$ is a scalar multiple of $v_1$; by
Theorem 2.1, $\{v_1,v_2\}$ is linearly dependent, hence **not** a basis
(Definition 2.2 requires independence). (It also fails to span
$\mathbb{R}^2$: $\operatorname{span}\{v_1,v_2\} = \operatorname{span}\{v_1\}$
is only the line through the origin and $(1,2)$, not all of $\mathbb{R}^2$
— consistent, since a dependent spanning attempt with too few "effective"
vectors can't reach full dimension.)

**9.** Suppose toward contradiction that $\{v_1,\dots,v_n\}$ is linearly
*dependent*. Then by Theorem 2.2's proof technique, some $v_i$ is a linear
combination of the rest, and removing it leaves a spanning set
$\{v_1,\dots,v_n\}\setminus\{v_i\}$ of size $n - 1$ with
$\operatorname{span}(\{v_1,\dots,v_n\}\setminus\{v_i\}) =
\operatorname{span}\{v_1,\dots,v_n\} = V$. Now let $\{u_1,\dots,u_n\}$ be any
basis of $V$ (exists since $\dim V = n$); in particular it's a linearly
independent set of size $n$. Applying Lemma 2.3 with the spanning set
$\{v_1,\dots,v_n\}\setminus\{v_i\}$ (size $n-1$) and the independent set
$\{u_1,\dots,u_n\}$ (size $n$) gives $n \le n - 1$ — a contradiction. So
$\{v_1,\dots,v_n\}$ cannot be dependent; it is independent, and since it also
spans $V$ by hypothesis, it is a basis. $\blacksquare$

**10.** Note $(2,4,6,8) = 2\cdot(1,2,3,4)$, so by Theorem 2.1 the second
vector is redundant and can be dropped without changing the span (same
argument as Exercise 3):
$\operatorname{span}\{(1,2,3,4),(2,4,6,8),(1,0,1,0)\} =
\operatorname{span}\{(1,2,3,4),(1,0,1,0)\}$. These two are not scalar
multiples: if $(1,0,1,0) = t(1,2,3,4)$, the first coordinate forces $t=1$,
but then the second coordinate would need to be $2$, not $0$ — contradiction.
So $\{(1,2,3,4),(1,0,1,0)\}$ is independent, hence a basis for the span, and
the dimension is **2**.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab implements a numerical independence test. Open
`starter_code/day02_basis_dimension.py` — it has one function to complete,
`is_independent`. Fill in the `TODO`, then run the file directly
(`python starter_code/day02_basis_dimension.py`); it should print
`All checks passed! dimension of span{v1,v2,v3} = 2`.

**Hint:** stack the given vectors as columns of a matrix $A$ and compare
`np.linalg.matrix_rank(A)` to the number of vectors — the set is independent
exactly when the rank equals the count (no redundant/dependent column drags
the rank down). This is the computational analogue of the "solve for the
coefficients and check only the trivial solution works" technique you used
by hand throughout today's exercises, and it works for *any* shape of matrix,
not just square ones — directly avoiding the determinant-recipe trap from
the Unconventional edge section above.

If you get stuck for more than ~10 minutes, check
`solutions/day02_basis_dimension.py` — but only after a real attempt.

Once your implementation passes, extend it: construct your own 4-vector set
in $\mathbb{R}^4$ with exactly one redundant vector (i.e. one vector that is
a linear combination of the other three, by your own explicit construction),
and verify with `np.linalg.matrix_rank` that the rank drops by exactly 1
relative to 4 independent vectors.

## Plain-language review

### Notation decoder

| Symbol | Read it as | In today's context |
|--------|------------|--------------------|
| $\iff$ | "if and only if — each side forces the other" | independence $\iff$ no vector is a combination of the others |
| $\Rightarrow$, $\Leftarrow$ | "the forward / backward half of an 'if and only if' proof" | the two directions proved separately |
| $\{v_1,\dots,v_n\}$ | "the set of these vectors" | the collection whose independence we test |
| $\setminus$ | "set minus — remove these" | $\{v_1,\dots,v_n\}\setminus\{v_i\}$ = all the vectors except $v_i$ |
| $\neq$ | "is not equal to" | a nonzero coefficient, e.g. $a_k \neq 0$ |
| $\dim V$ | "the dimension of $V$" | the number of vectors in any basis of $V$ |
| $\lvert S\rvert$ | "the size of $S$ — how many vectors" | $\lvert S_1\rvert = n-1$ after removing one vector |
| $\le$ | "is less than or equal to" | $m \le n$ in the Exchange Lemma |
| $\operatorname{span}(B) = V$ | "$B$ spans $V$" | $B$'s combinations fill all of $V$ |
| $\in$, $\subseteq$ | "is in; is a subset of" | the basic membership and containment symbols |
| $\blacksquare$ | "end of proof" | — |

### The big ideas (conclusions)

- A set of vectors is linearly independent when the only way to combine them
  to zero uses all-zero coefficients; if any nonzero combination gives zero,
  the set is dependent.
- Independence says the same thing as "no vector in the set is a linear
  combination of the others."
- Every finite spanning set can be trimmed down to a basis by discarding
  redundant vectors one at a time.
- No linearly independent set is ever larger than a spanning set (the
  Steinitz Exchange Lemma) — this is the engine behind dimension.
- All bases of a space have the same size, so "dimension" is a single
  well-defined number.

### Proof sketches

**Theorem 2.1 — key trick: a dependence relation and "one vector = a
combination of the rest" are the same equation, rearranged.**
Both directions are algebra on a single equation. If some $v_i$ equals a
combination of the others, move it to the same side and you get a dependence
relation whose $v_i$-coefficient is $1$ (nonzero) — so the set is dependent.
Conversely, if a nontrivial relation exists, grab any vector with a nonzero
coefficient, divide through by it, and solve for that vector as a combination
of the rest. Full version: Theorem 2.1 above.

**Theorem 2.2 — key trick: repeatedly delete a redundant vector; the span
never changes and the set keeps shrinking.**
If the spanning set is already independent, it is a basis. If not, some
vector is a combination of the others; deleting it leaves the span unchanged
(substitute its expression into any combination). Each deletion shrinks a
finite set, so the process must stop — and it stops exactly when the
survivors are independent, i.e. a basis. Full version: Theorem 2.2 above.

**Lemma 2.3 — key trick: feed the independent vectors in one at a time, each
time trading out a spanning vector it can replace.**
Induct on how many $w$'s you have swapped in. At each stage the current mixed
set still spans, so the next $w$ is a combination of it — and that
combination must genuinely use a leftover $v$ (otherwise $w$ would depend on
earlier $w$'s, impossible for an independent set). Swap that $v$ out for the
$w$; the set still spans. You never run out of $v$'s to trade before all $m$
of the $w$'s are placed, which forces $m \le n$. Full version: Lemma 2.3
above.

**Theorem 2.3 — key trick: apply the Exchange Lemma both ways.**
Take two bases. The first spans and the second is independent, so Exchange
gives (size of second) $\le$ (size of first). Swap their roles — now the
second spans and the first is independent — to get the reverse inequality.
Two $\le$'s force equality, so both bases have the same size. Full version:
Theorem 2.3 above.

### If you remember only 3 things

1. Independent = "only the all-zero combination gives zero." Equivalently, no
   vector is a combination of the others.
2. Basis = independent + spanning; every finite spanning set already contains
   one.
3. The Exchange Lemma (independent $\le$ spanning) makes dimension
   well-defined — and instantly rules out 3 independent vectors in
   $\mathbb{R}^2$.

## Journal template

```
## Day 2 — Linear independence, basis, dimension
Key theorem in my own words: ...
What confused me: ...
```
