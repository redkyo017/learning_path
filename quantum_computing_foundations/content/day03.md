# Day 3 — Complex Vector Spaces & the Qubit

## Learning objectives

By the end of today you should be able to:
- State the complex inner product on $\mathbb{C}^n$ and prove it satisfies
  conjugate symmetry, linearity in the second argument, and
  positive-definiteness — and explain exactly where the complex conjugate
  enters that wasn't needed in the real-valued inner-product spaces you
  already mastered.
- Compute the Hermitian adjoint of a matrix and prove
  $(A^\dagger)^\dagger = A$ in general.
- Prove the three standard characterizations of a unitary matrix are
  equivalent: $U^\dagger U = I$, orthonormal columns, and preservation of
  inner products.
- Prove every eigenvalue of a unitary matrix has modulus $1$.
- Define a qubit as a normalized vector in $\mathbb{C}^2$, verify
  normalization directly, and work with bra-ket notation including outer
  products and the completeness relation.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or de Wolf's *Quantum Computing: Lecture Notes*, the chapter/section
  covering complex vector spaces, Hermitian adjoints, unitary operators, and
  bra-ket notation.
- The theory below is self-contained — you do not need either text to do
  today's work, but reading the matching section alongside this is useful
  for a second explanation in different words.
- You already proved the real-valued analogues of nearly everything below
  (inner products, adjoints, orthogonality) in your linear algebra plan.
  Today's job is to see precisely what changes when the field is
  $\mathbb{C}$ instead of $\mathbb{R}$, and to build the qubit and bra-ket
  formalism on top of that.

## Theory

### Complex vector spaces, in one paragraph

A complex vector space is exactly what you'd expect from your real-valued
linear algebra: a set closed under addition and scalar multiplication,
except the scalars are now drawn from $\mathbb{C}$ instead of $\mathbb{R}$.
$\mathbb{C}^n$ — column vectors of $n$ complex numbers — is the only space
we need today. Everything about bases, dimension, linear independence,
and linear maps carries over unchanged from the real case; what genuinely
changes is the *inner product*, because the real construction
$\langle v,w\rangle = \sum_i v_iw_i$ silently relied on being over
$\mathbb{R}$ in a way that breaks over $\mathbb{C}$.

### The complex inner product, and why conjugation is forced

Define, for $v,w\in\mathbb{C}^n$,
$$\langle v,w\rangle \;=\; \sum_{i=1}^n v_i^{*}w_i \;=\; v^\dagger w,$$
where $v_i^*$ is the complex conjugate of $v_i$ and $v^\dagger$ denotes the
conjugate-transpose of $v$ (defined precisely in the next section). This is
the *physicist's convention*: conjugate-linear in the first argument,
linear in the second. (Some texts use the opposite convention,
conjugate-linear in the second argument — the two are mirror images of each
other; bra-ket notation below is built to match the convention used here.)

**Why the conjugate is unavoidable.** In your real inner-product spaces,
$\langle v,v\rangle = \sum_i v_i^2 \ge 0$ automatically, because every real
number squared is nonnegative. Over $\mathbb{C}$ this fails: take
$v = (i, 0)$. Then $\sum_i v_i^2 = i^2 = -1 < 0$ — the naive, unconjugated
"inner product" $\sum v_iw_i$ is not even real-valued in general, let alone
positive, so it cannot serve as a notion of squared length. Conjugating one
argument repairs this: $v_i^*v_i = |v_i|^2 \ge 0$ always, for *any* complex
number $v_i$, since $|v_i|^2$ is by definition a nonnegative real number
(the squared modulus). This is the single structural reason bra-ket
notation and the complex inner product involve a conjugate at all — it is
not a notational convenience, it is what makes "length" well-defined over
$\mathbb{C}$ in the first place.

**Conjugate symmetry.** $\langle v,w\rangle = \langle w,v\rangle^*$, in place
of the real case's plain symmetry $\langle v,w\rangle=\langle w,v\rangle$.
This is the correct replacement: over $\mathbb{R}$, conjugation is the
identity, so conjugate symmetry silently reduces to ordinary symmetry — the
real case was a special case of this all along, not a different rule.

**Linearity in the second argument, conjugate-linearity in the first.** The
inner product is linear in the argument that isn't conjugated, and
*conjugate*-linear (also called antilinear) in the one that is: scalars
pulled out of the first argument come out conjugated. This asymmetry has no
counterpart in the real case (where linearity in both arguments is the same
statement), and it is exactly what makes conjugate symmetry and linearity
in one argument jointly consistent.

**Positive-definiteness.** $\langle v,v\rangle = \sum_i|v_i|^2 \ge 0$, with
equality iff every $v_i=0$, i.e. iff $v=0$ — the same conclusion as the real
case, now via moduli instead of squares, for the reason given above.

### The Hermitian adjoint

For a matrix $A\in\mathbb{C}^{m\times n}$, its **Hermitian adjoint** (or
*conjugate transpose*, or *dagger*) is
$$A^\dagger = \left(\overline{A}\right)^T, \qquad
(A^\dagger)_{ij} = \overline{A_{ji}}.$$
That is: transpose, then conjugate every entry (the order doesn't matter —
the two operations commute). This is the direct complex analogue of the
transpose $A^T$ you used throughout your real-valued linear algebra plan as
"the adjoint with respect to the standard inner product," i.e. the unique
matrix satisfying $\langle Av,w\rangle_{\mathbb{R}} = \langle v,A^Tw
\rangle_{\mathbb{R}}$ for all $v,w$. The complex adjoint satisfies the exact
same defining relation, but with the complex inner product:
$$\langle Av,w\rangle = (Av)^\dagger w = v^\dagger A^\dagger w =
\langle v, A^\dagger w\rangle$$
for all $v,w\in\mathbb{C}^n$ — and this property, together with linearity,
*characterizes* $A^\dagger$ uniquely, exactly as the real transpose was
characterized. Taking the adjoint twice returns the original matrix,
$(A^\dagger)^\dagger = A$, since conjugating twice and transposing twice
both return you to the start.

A matrix with $A=A^\dagger$ is called **Hermitian** — the complex analogue
of a real *symmetric* matrix, and (as you'll see on Day 4) the complex
analogue that plays the same spectral-theorem role real symmetric matrices
played in your linear algebra plan.

### Unitary matrices

A matrix $U\in\mathbb{C}^{n\times n}$ is **unitary** iff
$$U^\dagger U = UU^\dagger = I.$$
This is the complex analogue of a real *orthogonal* matrix
($Q^TQ=QQ^T=I$): unitary matrices are exactly the linear maps that preserve
the complex inner product, hence preserve length and angle in the complex
sense, in the same way orthogonal matrices do over $\mathbb{R}$. Three
equivalent characterizations (proved in the Exercises/Solutions below):
$U^\dagger U=I$; the columns of $U$ form an orthonormal basis of
$\mathbb{C}^n$; $U$ preserves inner products,
$\langle Uv,Uw\rangle=\langle v,w\rangle$ for all $v,w$.

Unitary matrices are the complex-linear-algebra structure underlying every
quantum gate you will meet from here on: quantum time evolution (and every
quantum circuit) is, by postulate, implemented by a unitary matrix acting on
a state vector, precisely because unitary matrices are exactly the maps
that preserve the normalization ($\langle\psi|\psi\rangle=1$) a valid
quantum state must always have.

### Eigenvalues of unitary matrices have modulus 1

If $Uv=\lambda v$ for some nonzero $v$ and unitary $U$, then taking the norm
of both sides and using $U^\dagger U=I$:
$$\langle v,v\rangle = \langle Uv,Uv\rangle = \langle \lambda v,\lambda v
\rangle = \lambda^*\lambda\langle v,v\rangle = |\lambda|^2\langle v,v
\rangle.$$
Since $v\ne0$, positive-definiteness gives $\langle v,v\rangle > 0$, so it
can be divided out, leaving $|\lambda|^2=1$, i.e. $|\lambda|=1$. This is the
complex analogue of a fact you may recall from the real case — real
orthogonal matrices have eigenvalues $\pm1$ *when real eigenvalues exist at
all* (a $2\times2$ rotation, for instance, has no real eigenvalues except
at angle $0$ or $\pi$). Over $\mathbb{C}$ there is no such escape: every
$n\times n$ matrix has exactly $n$ eigenvalues counted with multiplicity
(the fundamental theorem of algebra applied to the characteristic
polynomial), and for a unitary matrix every single one of them is
guaranteed to lie exactly on the unit circle in $\mathbb{C}$. This fact is
the reason unitary evolution never amplifies or shrinks any eigen-direction
of a quantum state — it only rotates phases.

### The qubit

A **qubit** is a normalized vector
$$|\psi\rangle = \alpha|0\rangle + \beta|1\rangle \in \mathbb{C}^2,
\qquad |\alpha|^2+|\beta|^2 = 1,$$
written in the standard orthonormal basis $\{|0\rangle,|1\rangle\}$ where
$|0\rangle = \binom{1}{0}$, $|1\rangle=\binom{0}{1}$. The normalization
condition is exactly $\langle\psi|\psi\rangle=1$ under the complex inner
product above — it is the complex-vector-space statement that a quantum
state has "total probability 1," a physical requirement that will be made
precise by the Born rule on Day 6. Unlike a real unit vector in
$\mathbb{R}^2$ (parametrized by a single angle), a general normalized
vector in $\mathbb{C}^2$ has two independent real degrees of freedom beyond
overall normalization — this is exactly the extra structure ($\alpha,\beta$
complex rather than real) that makes a qubit richer than a classical bit,
and is what the Bloch-sphere picture on Day 4 will make geometrically
precise.

### Bra-ket notation, outer products, completeness

In bra-ket notation, $|\psi\rangle$ (a "**ket**") denotes an ordinary column
vector in $\mathbb{C}^n$, and $\langle\psi|$ (a "**bra**") denotes its
Hermitian adjoint, $\langle\psi| := |\psi\rangle^\dagger$ — a row vector
with every entry conjugated. Placing a bra next to a ket,
$\langle\phi|\psi\rangle$, reproduces exactly the inner product
$\langle\phi,\psi\rangle$ defined above (matrix-multiplying a $1\times n$
row by an $n\times1$ column gives a scalar) — the notation is built so that
"bra times ket" is inner product by construction.

The reverse order, $|\phi\rangle\langle\psi|$ (ket times bra, an
$n\times1$ times a $1\times n$), is an $n\times n$ matrix called the
**outer product**. For the standard basis $\{|0\rangle,|1\rangle\}$ of
$\mathbb{C}^2$, the family of outer products $|i\rangle\langle i|$ are the
rank-1 projectors onto each basis vector, and they satisfy the
**completeness relation**
$$\sum_i |i\rangle\langle i| = I,$$
the statement that projecting onto every direction of an orthonormal basis
and summing recovers the identity — an algebraic fact you will reuse
constantly from Day 6 onward, where $|i\rangle\langle i|$ becomes the
projector associated with measurement outcome $i$.

## Worked example

**Claim:** $U = \dfrac{1}{\sqrt2}\begin{pmatrix}1 & i\\ i & 1\end{pmatrix}$
is unitary, and its eigenvalues have modulus $1$, verified three independent
ways.

**1. Columns orthonormal.** The columns are $c_1 = \frac{1}{\sqrt2}\binom{1}{i}$
and $c_2=\frac{1}{\sqrt2}\binom{i}{1}$. Norms:
$\langle c_1,c_1\rangle = \frac12\left(|1|^2+|i|^2\right)=\frac12(1+1)=1$,
and likewise $\langle c_2,c_2\rangle=1$. Cross term:
$$\langle c_1,c_2\rangle = \frac12\left(1^{*}\cdot i + i^{*}\cdot 1\right)
= \frac12\left(i + (-i)\right) = 0.$$
So $\{c_1,c_2\}$ is orthonormal.

**2. Direct check $U^\dagger U = I$.** $U^\dagger = \dfrac{1}{\sqrt2}
\begin{pmatrix}1 & -i\\ -i & 1\end{pmatrix}$ (transpose is a no-op here since
$U$ is symmetric as a matrix of *entries*; only the conjugation changes
anything). Then
$$U^\dagger U = \frac12\begin{pmatrix}1&-i\\-i&1\end{pmatrix}
\begin{pmatrix}1&i\\i&1\end{pmatrix}
= \frac12\begin{pmatrix}1\cdot1+(-i)(i) & 1\cdot i+(-i)\cdot1\\
(-i)\cdot1+1\cdot i & (-i)(i)+1\cdot1\end{pmatrix}
= \frac12\begin{pmatrix}2 & 0\\ 0 & 2\end{pmatrix} = I,$$
using $(-i)(i) = -i^2 = 1$. The same computation with the factors reversed
gives $UU^\dagger=I$ as well (omitted; identical arithmetic). So $U$ is
unitary by the defining condition directly, consistent with Check 1.

**3. Eigenvalues have modulus 1.** $\operatorname{tr}(U) =
\frac{1}{\sqrt2}+\frac{1}{\sqrt2} = \sqrt2$, and $\det(U) =
\frac12\left(1\cdot1 - i\cdot i\right) = \frac12(1-(-1)) = 1$. The
characteristic polynomial is $\lambda^2 - \operatorname{tr}(U)\,\lambda +
\det(U) = \lambda^2-\sqrt2\,\lambda+1=0$, so
$$\lambda = \frac{\sqrt2 \pm \sqrt{2-4}}{2} = \frac{\sqrt2\pm i\sqrt2}{2}
= \frac{1}{\sqrt2}(1\pm i).$$
Modulus: $|1\pm i| = \sqrt{1^2+1^2}=\sqrt2$, so $|\lambda| =
\frac{1}{\sqrt2}\cdot\sqrt2 = 1$ for both roots — confirming the general
theorem proved above, on this concrete matrix, by a route (characteristic
polynomial) independent of the $U^\dagger U=I$ argument used to prove the
theorem in general.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Verify that the complex inner product $\langle v,w\rangle=\sum_i
   v_i^*w_i$ on $\mathbb{C}^n$ satisfies conjugate symmetry
   ($\langle v,w\rangle=\langle w,v\rangle^*$), linearity in the second
   argument, and positive-definiteness ($\langle v,v\rangle\ge0$, with
   equality iff $v=0$).
2. Given $A=\begin{pmatrix}1 & i\\ 2-i & 3\end{pmatrix}$, compute $A^\dagger$
   explicitly, then verify $(A^\dagger)^\dagger=A$.
3. Prove that $U$ is unitary ($U^\dagger U=I$) if and only if its columns
   form an orthonormal basis of $\mathbb{C}^n$, if and only if $U$ preserves
   inner products ($\langle Uv,Uw\rangle=\langle v,w\rangle$ for all
   $v,w$).
4. Prove that every eigenvalue of a unitary matrix has modulus $1$.
5. Given $|\psi\rangle = \frac{3}{5}|0\rangle+\frac{4i}{5}|1\rangle$, verify
   it is normalized by computing $\langle\psi|\psi\rangle$ explicitly.
6. Compute the outer product $|0\rangle\langle1|$ as a $2\times2$ matrix,
   then verify the completeness relation $|0\rangle\langle0|+
   |1\rangle\langle1|=I$ by direct matrix addition.

## Solutions

**1.** Write $v,w\in\mathbb{C}^n$ with entries $v_i,w_i$.

*Conjugate symmetry:*
$$\langle w,v\rangle^* = \left(\sum_i w_i^*v_i\right)^* =
\sum_i (w_i^*v_i)^* = \sum_i w_i v_i^* = \sum_i v_i^*w_i = \langle v,w
\rangle,$$
using $(zw)^*=z^*w^*$ and $(z^*)^*=z$ entrywise.

*Linearity in the second argument:* for $\alpha,\beta\in\mathbb{C}$ and
$w=\alpha w^{(1)}+\beta w^{(2)}$,
$$\langle v,w\rangle = \sum_i v_i^*\left(\alpha w_i^{(1)}+\beta w_i^{(2)}
\right) = \alpha\sum_i v_i^*w_i^{(1)} + \beta\sum_i v_i^*w_i^{(2)} =
\alpha\langle v,w^{(1)}\rangle+\beta\langle v,w^{(2)}\rangle,$$
by distributing the (fixed) $v_i^*$ over the sum and pulling out the
scalars, which multiply ordinary complex numbers and so commute freely.

*Positive-definiteness:* $\langle v,v\rangle=\sum_i v_i^*v_i =
\sum_i|v_i|^2$. Each term $|v_i|^2\ge0$ is a nonnegative real number by
definition of modulus, so the sum is $\ge0$. If $v=0$, every term is $0$,
so the sum is $0$. Conversely if $\sum_i|v_i|^2=0$ with every term
nonnegative, every term must individually be $0$ (a sum of nonnegative
reals is zero only if each summand is), so $|v_i|=0$, i.e. $v_i=0$, for
every $i$ — hence $v=0$. (Contrast with the real case, where
$\langle v,v\rangle=\sum v_i^2$ needs no conjugate to be nonnegative; here
the conjugate is what forces every term to be a nonnegative real modulus
rather than an arbitrary — and possibly negative or non-real — square.)

**2.** $A=\begin{pmatrix}1&i\\2-i&3\end{pmatrix}$. Transpose:
$A^T=\begin{pmatrix}1&2-i\\i&3\end{pmatrix}$. Conjugate every entry:
$$A^\dagger = \begin{pmatrix}1^* & (2-i)^*\\ i^* & 3^*\end{pmatrix}
= \begin{pmatrix}1 & 2+i\\ -i & 3\end{pmatrix}.$$
Now take the adjoint again: transpose $A^\dagger$ to get
$\begin{pmatrix}1 & -i\\ 2+i & 3\end{pmatrix}$, then conjugate every entry:
$$(A^\dagger)^\dagger = \begin{pmatrix}1^* & (-i)^*\\ (2+i)^* & 3^*\end{pmatrix}
= \begin{pmatrix}1 & i\\ 2-i & 3\end{pmatrix} = A.$$
This matches $A$ exactly, confirming $(A^\dagger)^\dagger=A$ — as it must in
general, since transposing twice and conjugating twice both return every
entry to its original value and original position.

**3.** Let $U=\begin{pmatrix}c_1 & c_2 & \cdots & c_n\end{pmatrix}$ with
columns $c_1,\dots,c_n\in\mathbb{C}^n$.

*$U^\dagger U=I \iff$ columns orthonormal.* The $(i,j)$ entry of $U^\dagger
U$ is, by matrix multiplication, $c_i^\dagger c_j = \langle c_i,c_j\rangle$
(row $i$ of $U^\dagger$ is exactly $c_i^\dagger$, the conjugate-transpose of
column $i$ of $U$). So $U^\dagger U=I$ means precisely $\langle
c_i,c_j\rangle=\delta_{ij}$ for all $i,j$ — i.e. every column has norm $1$
and every pair of distinct columns is orthogonal, which is exactly the
statement that $\{c_1,\dots,c_n\}$ is an orthonormal set. An orthonormal
set of $n$ vectors in the $n$-dimensional space $\mathbb{C}^n$ is
automatically a basis (orthonormal vectors are linearly independent: if
$\sum_i\alpha_ic_i=0$, take $\langle c_j,\cdot\rangle$ of both sides to get
$\alpha_j=0$ for every $j$), so this is equivalent to "columns form an
orthonormal basis of $\mathbb{C}^n$."

(Note $U^\dagger U=I$ for a square matrix already implies $UU^\dagger=I$
too, since a square matrix with a left inverse has that same matrix as its
two-sided inverse; so it is not necessary to separately impose
$UU^\dagger=I$ once $U^\dagger U=I$ and squareness are established.)

*$U^\dagger U=I \iff U$ preserves inner products.* If $U^\dagger U=I$, then
for any $v,w$,
$$\langle Uv,Uw\rangle = (Uv)^\dagger(Uw) = v^\dagger U^\dagger U w =
v^\dagger I w = v^\dagger w = \langle v,w\rangle,$$
so $U$ preserves inner products. Conversely, suppose $\langle Uv,Uw\rangle
=\langle v,w\rangle$ for all $v,w$. Take $v=e_i,w=e_j$, the standard basis
vectors: $\langle Ue_i,Ue_j\rangle=\langle e_i,e_j\rangle=\delta_{ij}$. But
$Ue_i=c_i$ (the $i$-th column of $U$), so this says exactly $\langle
c_i,c_j\rangle=\delta_{ij}$ for all $i,j$ — the columns are orthonormal,
which by the first equivalence above is the same as $U^\dagger U=I$. This
closes the loop: all three conditions are equivalent.

**4.** Suppose $Uv=\lambda v$ with $v\ne0$ and $U$ unitary. Then
$$\langle v,v\rangle = \langle Uv,Uv\rangle \quad\text{(unitary preserves
inner products, by Exercise 3)} = \langle\lambda v,\lambda v\rangle
= \lambda^*\lambda\,\langle v,v\rangle = |\lambda|^2\langle v,v\rangle,$$
where the last equality uses conjugate-linearity in the first argument
(pulling out $\lambda^*$) and linearity in the second (pulling out
$\lambda$). Since $v\ne0$, positive-definiteness (Exercise 1) gives
$\langle v,v\rangle>0$, so it may be divided out of both sides, leaving
$1=|\lambda|^2$, i.e. $|\lambda|=1$.

**5.** $\langle\psi|\psi\rangle = \left|\frac35\right|^2 +
\left|\frac{4i}{5}\right|^2 = \frac{9}{25} + \frac{16}{25} = \frac{25}{25}
= 1$, using $|4i/5|^2 = (4/5)^2|i|^2 = (16/25)(1) = 16/25$ since $|i|=1$.
So $|\psi\rangle$ is normalized.

**6.** $|0\rangle=\binom10$, $\langle1|=\binom01^\dagger=(0\ \ 1)$ (a row
vector; no entries are non-real here, so conjugation is invisible). The
outer product is
$$|0\rangle\langle1| = \binom10\begin{pmatrix}0&1\end{pmatrix} =
\begin{pmatrix}1\cdot0 & 1\cdot1\\ 0\cdot0 & 0\cdot1\end{pmatrix} =
\begin{pmatrix}0&1\\0&0\end{pmatrix}.$$
Similarly $|0\rangle\langle0| = \binom10(1\ \ 0) =
\begin{pmatrix}1&0\\0&0\end{pmatrix}$ and $|1\rangle\langle1| =
\binom01(0\ \ 1) = \begin{pmatrix}0&0\\0&1\end{pmatrix}$. Adding:
$$|0\rangle\langle0|+|1\rangle\langle1| =
\begin{pmatrix}1&0\\0&0\end{pmatrix} + \begin{pmatrix}0&0\\0&1\end{pmatrix}
= \begin{pmatrix}1&0\\0&1\end{pmatrix} = I,$$
confirming the completeness relation by direct matrix addition.

## Journal template

```
## Day 3 — Complex vector spaces & the qubit
Key idea in my own words: ...
What confused me: ...
```
