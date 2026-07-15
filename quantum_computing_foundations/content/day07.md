# Day 7 — Multi-Qubit States, Entanglement & No-Cloning

## Learning objectives

By the end of today you should be able to:
- Construct the joint state space of two qubits via the tensor product, and
  embed single-qubit gates into it as Kronecker products.
- Derive the standard Bell-state preparation circuit $(H\otimes I)$ then
  CNOT, and identify the resulting entangled state $|\Phi^+\rangle$.
- Prove that a specific two-qubit state is entangled (not separable),
  directly from the product-state definition and again via the partial
  trace / reduced density matrix.
- State and prove the no-cloning theorem in full, including the exact
  linearity-based numerical contradiction that makes the proof airtight.
- Compute Kronecker products of Pauli matrices and prove that a tensor
  product of unitaries is itself unitary.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  or Nielsen & Chuang, *Quantum Computation and Quantum Information*, the
  chapter(s) covering tensor products, entanglement, Bell states, and the
  no-cloning theorem.
- The theory below is self-contained — you do not need either book to do
  today's work, but reading the matching chapter alongside this is useful
  for a second explanation in different words.

## Theory

### The joint state space of two qubits

A single qubit lives in $\mathbb{C}^2$. The joint state space of **two**
qubits is the **tensor product** $\mathbb{C}^2\otimes\mathbb{C}^2 \cong
\mathbb{C}^4$, with basis $\{|00\rangle, |01\rangle, |10\rangle,
|11\rangle\}$, where $|x_1x_2\rangle \equiv |x_1\rangle\otimes|x_2\rangle$.
Ordering this basis lexicographically identifies it with the standard basis
of $\mathbb{C}^4$:
$$
|00\rangle=\begin{pmatrix}1\\0\\0\\0\end{pmatrix},\quad
|01\rangle=\begin{pmatrix}0\\1\\0\\0\end{pmatrix},\quad
|10\rangle=\begin{pmatrix}0\\0\\1\\0\end{pmatrix},\quad
|11\rangle=\begin{pmatrix}0\\0\\0\\1\end{pmatrix}.
$$
A general two-qubit state is $|\Phi\rangle = c_{00}|00\rangle +
c_{01}|01\rangle + c_{10}|10\rangle + c_{11}|11\rangle$ with $\sum_{ij}
|c_{ij}|^2 = 1$. The tensor product of two single-qubit vectors is defined
component-wise: for $|\chi\rangle = \alpha|0\rangle+\beta|1\rangle$ and
$|\varphi\rangle = \gamma|0\rangle+\delta|1\rangle$,
$$
|\chi\rangle\otimes|\varphi\rangle = \alpha\gamma|00\rangle +
\alpha\delta|01\rangle + \beta\gamma|10\rangle + \beta\delta|11\rangle,
$$
obtained by formally distributing the product over both sums — the
tensor product is bilinear (linear in each argument separately).

### Embedding single-qubit gates: the Kronecker product

If a unitary $A$ acts on qubit 1 alone and $B$ acts on qubit 2 alone, the
combined operation on the joint 2-qubit system is the **Kronecker product**
$A\otimes B$, defined on basis vectors by $(A\otimes B)(|x\rangle\otimes
|y\rangle) = (A|x\rangle)\otimes(B|y\rangle)$ and extended linearly to all
of $\mathbb{C}^4$. In matrix form, for $2\times2$ blocks $A=
\begin{pmatrix}a_{11}&a_{12}\\a_{21}&a_{22}\end{pmatrix}$,
$$
A\otimes B = \begin{pmatrix} a_{11}B & a_{12}B \\ a_{21}B & a_{22}B
\end{pmatrix},
$$
a $4\times4$ matrix built from four scaled copies of $B$. Two structural
facts we will use repeatedly:
- **Mixed-product rule:** $(A\otimes B)(C\otimes D) = (AC)\otimes(BD)$.
- **Adjoint of a tensor product:** $(A\otimes B)^\dagger = A^\dagger\otimes
  B^\dagger$.

Combining these: if $A$ and $B$ are each unitary, then $A\otimes B$ is
unitary, since
$$
(A\otimes B)^\dagger(A\otimes B) = (A^\dagger\otimes B^\dagger)(A\otimes B)
= (A^\dagger A)\otimes(B^\dagger B) = I\otimes I = I_4,
$$
and identically $(A\otimes B)(A\otimes B)^\dagger = I_4$. So tensoring
together any number of unitary single-qubit gates always yields a unitary
multi-qubit gate — this is exactly how $H\otimes I$, used below to build
the Bell state, is guaranteed to be a legal quantum operation without any
separate unitarity check.

The **CNOT** gate (control = qubit 1, target = qubit 2) acts on basis
states as $\text{CNOT}|x_1,x_2\rangle = |x_1,\ x_2\oplus x_1\rangle$, i.e.
$|00\rangle\to|00\rangle$, $|01\rangle\to|01\rangle$, $|10\rangle\to
|11\rangle$, $|11\rangle\to|10\rangle$. As a $4\times4$ matrix in the basis
order above,
$$
\text{CNOT} = \begin{pmatrix}1&0&0&0\\0&1&0&0\\0&0&0&1\\0&0&1&0\end{pmatrix}.
$$
Unlike $A\otimes B$, CNOT is *not* a Kronecker product of two single-qubit
gates — it is a genuinely two-qubit gate, and this is precisely what makes
it capable of creating entanglement, as the next section shows.

### Separability and entanglement

A two-qubit pure state $|\Phi\rangle$ is **separable** (a *product state*)
if there exist single-qubit states $|\chi\rangle, |\varphi\rangle$ with
$|\Phi\rangle = |\chi\rangle\otimes|\varphi\rangle$. If no such
$|\chi\rangle,|\varphi\rangle$ exist, $|\Phi\rangle$ is **entangled**.
Physically, a separable state describes two qubits that are, in every
measurable sense, independent of one another; an entangled state cannot be
described that way even though the joint state is perfectly well-defined
and pure.

**Constructing the Bell state $|\Phi^+\rangle$.** Start from $|00\rangle$
and apply $H\otimes I$ (Hadamard on qubit 1, identity on qubit 2):
$$
(H\otimes I)|00\rangle = (H|0\rangle)\otimes(I|0\rangle) =
\Big(\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)\Big)\otimes|0\rangle =
\tfrac{1}{\sqrt2}(|00\rangle+|10\rangle).
$$
This intermediate state is still separable — it's just $|+\rangle\otimes
|0\rangle$. Now apply CNOT (control qubit 1, target qubit 2):
$$
\text{CNOT}\,\tfrac{1}{\sqrt2}(|00\rangle+|10\rangle) =
\tfrac{1}{\sqrt2}\big(\text{CNOT}|00\rangle+\text{CNOT}|10\rangle\big) =
\tfrac{1}{\sqrt2}(|00\rangle+|11\rangle) \equiv |\Phi^+\rangle.
$$
$|\Phi^+\rangle$ is one of the four **Bell states**, and — as proved
rigorously below — it is entangled: no factorization into single-qubit
states exists. The mechanism is exactly the asymmetry noted above: $H$
alone (a Kronecker product $H\otimes I$) cannot create entanglement, since
tensor products of single-qubit unitaries always send product states to
product states; it is specifically CNOT's genuinely-two-qubit structure
that correlates the two qubits.

### The partial trace and reduced density matrices

To make "qubit 1's state on its own" precise when the global state is
entangled, we need the **partial trace**. For basis vectors $|a\rangle,
|b\rangle$ of qubit 1's space and $|c\rangle,|d\rangle$ of qubit 2's space,
define the partial trace over qubit 2 on the rank-1 operator $|a\rangle
\langle b|\otimes|c\rangle\langle d|$ by
$$
\text{Tr}_2\big(|a\rangle\langle b|\otimes|c\rangle\langle d|\big) :=
\langle d|c\rangle\,|a\rangle\langle b|,
$$
and extend to arbitrary operators on the joint space by linearity (write
the operator as a sum of such terms, apply the rule to each term, and add
the results). Given a joint pure state $|\Phi\rangle$, the **reduced
density matrix of qubit 1** is $\rho_1 = \text{Tr}_2(|\Phi\rangle
\langle\Phi|)$. If $|\Phi\rangle$ is separable, $|\Phi\rangle=|\chi\rangle
\otimes|\varphi\rangle$, then $\rho_1 = \text{Tr}_2\big((|\chi\rangle
\langle\chi|)\otimes(|\varphi\rangle\langle\varphi|)\big) = \langle
\varphi|\varphi\rangle\,|\chi\rangle\langle\chi| = |\chi\rangle\langle\chi|$
(using $\langle\varphi|\varphi\rangle=1$) — a rank-1, pure-state density
matrix, exactly as expected for a qubit that genuinely has its own definite
state. The signature of **entanglement** is the opposite: as computed
explicitly in Exercise 4/Solution 4 below, $|\Phi^+\rangle$'s reduced
density matrix $\rho_1$ turns out to be $I/2$ — a *mixed* state, even
though the global two-qubit state $|\Phi^+\rangle$ is perfectly pure. A
pure joint state whose marginal on a subsystem is mixed is the algebraic
hallmark of entanglement: qubit 1 has no definite pure state of its own to
speak of, precisely because its state is correlated with qubit 2's.

### The no-cloning theorem

**Claim:** there is no unitary $U$ on two qubits such that $U(|\psi\rangle
\otimes|0\rangle) = |\psi\rangle\otimes|\psi\rangle$ holds for *every*
single-qubit state $|\psi\rangle$.

**Proof.** Suppose, for contradiction, that such a universal "cloning"
unitary $U$ exists. Apply the defining property to the two basis states:
$$
U(|0\rangle\otimes|0\rangle) = |0\rangle\otimes|0\rangle = |00\rangle,
\qquad
U(|1\rangle\otimes|0\rangle) = |1\rangle\otimes|1\rangle = |11\rangle.
$$
These two instances are individually consistent — no contradiction yet.
Now apply the same defining property to the superposition $|+\rangle =
\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)$. Directly from the cloning
assumption, applied to $|\psi\rangle=|+\rangle$, $U$ *must* produce
$$
U(|+\rangle\otimes|0\rangle) \stackrel{!}{=} |+\rangle\otimes|+\rangle =
\tfrac12(|00\rangle+|01\rangle+|10\rangle+|11\rangle),
\tag{required}
$$
using $|+\rangle\otimes|+\rangle = \tfrac12(|0\rangle+|1\rangle)\otimes
(|0\rangle+|1\rangle) = \tfrac12(|00\rangle+|01\rangle+|10\rangle+|11\rangle)$.

But $U$ is a *unitary operator*, hence **linear**, and $|+\rangle\otimes
|0\rangle$ can equally be written as a superposition of the two basis
inputs already fixed above:
$$
|+\rangle\otimes|0\rangle = \tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)\otimes
|0\rangle = \tfrac{1}{\sqrt2}\big(|0\rangle\otimes|0\rangle\big) +
\tfrac{1}{\sqrt2}\big(|1\rangle\otimes|0\rangle\big).
$$
Applying $U$ and using linearity — *not* the cloning assumption this time,
just the fact that $U$ is a linear operator — together with the two
individual results already established:
$$
U(|+\rangle\otimes|0\rangle) =
\tfrac{1}{\sqrt2}\,U(|0\rangle\otimes|0\rangle) +
\tfrac{1}{\sqrt2}\,U(|1\rangle\otimes|0\rangle) =
\tfrac{1}{\sqrt2}|00\rangle + \tfrac{1}{\sqrt2}|11\rangle =
\tfrac{1}{\sqrt2}(|00\rangle+|11\rangle).
\tag{actual}
$$
Now compare (required) and (actual) term by term:
$$
\underbrace{\tfrac{1}{\sqrt2}(|00\rangle+|11\rangle)}_{\text{actual, from linearity}}
\quad\text{vs.}\quad
\underbrace{\tfrac12(|00\rangle+|01\rangle+|10\rangle+|11\rangle)}_{\text{required, from the cloning assumption}}.
$$
The coefficient of $|01\rangle$ is $0$ on the left and $\tfrac12$ on the
right; the coefficient of $|00\rangle$ is $\tfrac{1}{\sqrt2}\approx0.707$
on the left and $\tfrac12=0.5$ on the right. Since $0\ne\tfrac12$ (and
$\tfrac{1}{\sqrt2}\ne\tfrac12$), these are two genuinely different vectors
in $\mathbb{C}^4$ — not equal, not merely differing by a global phase. So
$U(|+\rangle\otimes|0\rangle)$ cannot simultaneously equal both (actual)
and (required). This is a direct contradiction, forced purely by demanding
that a *single* unitary $U$ clone *both* $|0\rangle,|1\rangle$ *and* their
superposition $|+\rangle$. Hence no universal cloning unitary $U$ exists.
$\blacksquare$

The proof's entire force comes from the clash between two facts that are
each individually true of quantum mechanics: unitaries must act linearly
on superpositions (forced by the axioms), while the *desired* cloning
action $|\psi\rangle\mapsto|\psi\rangle\otimes|\psi\rangle$ is manifestly
**not** linear in $|\psi\rangle$ (squaring, in effect, a vector is a
quadratic, not linear, operation). No linear map can implement a quadratic
one on more than a one-dimensional set of inputs, and that is really all
the no-cloning theorem is saying.

## Worked example

**Claim:** the same two-gate circuit $\text{CNOT}\cdot(H\otimes I)$ that
produces $|\Phi^+\rangle$ from $|00\rangle$ produces all four Bell states
from the four computational basis states, and every one of them is
maximally entangled.

Apply $H\otimes I$ to each of $|00\rangle,|01\rangle,|10\rangle,|11\rangle$
(using $H|0\rangle=|+\rangle=\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and
$H|1\rangle=|-\rangle=\tfrac{1}{\sqrt2}(|0\rangle-|1\rangle)$), then CNOT:

- $|00\rangle \xrightarrow{H\otimes I} \tfrac{1}{\sqrt2}(|00\rangle+
  |10\rangle) \xrightarrow{\text{CNOT}} \tfrac{1}{\sqrt2}(|00\rangle+
  |11\rangle) = |\Phi^+\rangle$.
- $|01\rangle \xrightarrow{H\otimes I} \tfrac{1}{\sqrt2}(|01\rangle+
  |11\rangle) \xrightarrow{\text{CNOT}} \tfrac{1}{\sqrt2}(|01\rangle+
  |10\rangle) = |\Psi^+\rangle$.
- $|10\rangle \xrightarrow{H\otimes I} \tfrac{1}{\sqrt2}(|00\rangle-
  |10\rangle) \xrightarrow{\text{CNOT}} \tfrac{1}{\sqrt2}(|00\rangle-
  |11\rangle) = |\Phi^-\rangle$.
- $|11\rangle \xrightarrow{H\otimes I} \tfrac{1}{\sqrt2}(|01\rangle-
  |11\rangle) \xrightarrow{\text{CNOT}} \tfrac{1}{\sqrt2}(|01\rangle-
  |10\rangle) = |\Psi^-\rangle$.

(Each CNOT step just uses $|00\rangle\to|00\rangle$, $|10\rangle\to
|11\rangle$, $|01\rangle\to|01\rangle$, $|11\rangle\to|10\rangle$, applied
term by term, linearity carrying the $\pm$ sign through unchanged.)

All four Bell states have exactly the same structure as $|\Phi^+\rangle$ —
two basis kets with equal-magnitude amplitudes $\pm\tfrac{1}{\sqrt2}$ and
the other two amplitudes exactly $0$ — so the *same* separability argument
given in Exercise 3/Solution 3 for $|\Phi^+\rangle$ applies verbatim to each
of the other three (matching coefficients to $(\pm\tfrac1{\sqrt2},0)$ or
$(0,\pm\tfrac1{\sqrt2})$ patterns always forces one factor's product to be
simultaneously zero and nonzero). Likewise, the reduced density matrix of
qubit 1 for every Bell state works out to $I/2$ by the same partial-trace
computation as Solution 4, since each state's density matrix expands into
exactly two surviving diagonal terms with squared-magnitude coefficient
$\tfrac12$ and no surviving off-diagonal ($|0\rangle\langle1|$-type) terms.
So all four Bell states — the entire Bell basis — are maximally entangled,
not just the particular one built from $|00\rangle$.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Compute $(H\otimes I)|00\rangle$ explicitly, by tensor-expanding
   $H|0\rangle$ and $I|0\rangle$ separately and then tensoring the results.
2. Apply CNOT (control = qubit 1, target = qubit 2) to the result of
   Exercise 1. Confirm you get the Bell state $|\Phi^+\rangle =
   \frac{1}{\sqrt2}(|00\rangle+|11\rangle)$.
3. Prove $|\Phi^+\rangle$ is not separable: suppose $|\Phi^+\rangle =
   (a|0\rangle+b|1\rangle)\otimes(c|0\rangle+d|1\rangle)$. Match
   coefficients against $|\Phi^+\rangle$'s own coefficients and derive a
   contradiction (case on which factor must be zero).
4. State the definition of the partial trace, then use it to compute the
   reduced density matrix of qubit 1, $\rho_1 = \text{Tr}_2\big(
   |\Phi^+\rangle\langle\Phi^+|\big)$, explicitly. Show $\rho_1 = I/2$.
5. State and prove the no-cloning theorem in full: assume a unitary $U$
   satisfies $U(|\psi\rangle\otimes|0\rangle) = |\psi\rangle\otimes
   |\psi\rangle$ for every single-qubit $|\psi\rangle$. Apply this to
   $|0\rangle$ and $|1\rangle$ individually, then compute
   $U(|+\rangle\otimes|0\rangle)$ two different ways — once via linearity
   from the $|0\rangle,|1\rangle$ cases, once via the cloning assumption
   applied directly to $|+\rangle$ — and show the two results disagree.
6. Compute the Kronecker product $X\otimes Z$ explicitly as a $4\times4$
   matrix, and verify it is unitary (a) by direct matrix multiplication and
   (b) by the general mixed-product-rule argument for tensor products of
   unitaries.
7. In one paragraph, explain why $\rho_1 = I/2$ being a *mixed* state,
   despite $|\Phi^+\rangle$ itself being a pure global state, is the
   defining algebraic signature of entanglement — and contrast this with
   the separable state $|00\rangle$, whose qubit-1 reduced density matrix
   is the pure state $|0\rangle\langle0|$.

## Solutions

**1.** $H|0\rangle = \tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)$ and
$I|0\rangle = |0\rangle$. Tensoring:
$$
(H\otimes I)|00\rangle = \Big(\tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)\Big)
\otimes|0\rangle = \tfrac{1}{\sqrt2}\big(|0\rangle\otimes|0\rangle +
|1\rangle\otimes|0\rangle\big) = \tfrac{1}{\sqrt2}(|00\rangle+|10\rangle).
$$

**2.** CNOT (control qubit 1) sends $|00\rangle\to|00\rangle$ and
$|10\rangle\to|11\rangle$ (control bit $1$ flips the target). By linearity,
$$
\text{CNOT}\,\tfrac{1}{\sqrt2}(|00\rangle+|10\rangle) =
\tfrac{1}{\sqrt2}(|00\rangle+|11\rangle) = |\Phi^+\rangle,
$$
exactly the Bell-state preparation circuit stated in the Theory section.

**3.** Expand the assumed factorization:
$$
(a|0\rangle+b|1\rangle)\otimes(c|0\rangle+d|1\rangle) = ac|00\rangle +
ad|01\rangle + bc|10\rangle + bd|11\rangle.
$$
Matching coefficients to $|\Phi^+\rangle$'s $\big(\tfrac{1}{\sqrt2},0,0,
\tfrac{1}{\sqrt2}\big)$ requires
$$
ac = \tfrac{1}{\sqrt2},\qquad ad = 0,\qquad bc = 0,\qquad bd =
\tfrac{1}{\sqrt2}.
$$
From $ad=0$: either $a=0$ or $d=0$.
- If $a=0$: then $ac = 0\cdot c = 0 \ne \tfrac{1}{\sqrt2}$ — contradicts
  $ac=\tfrac{1}{\sqrt2}$.
- If $d=0$: then $bd = b\cdot0 = 0 \ne \tfrac{1}{\sqrt2}$ — contradicts
  $bd=\tfrac{1}{\sqrt2}$.

Both branches of the case split lead to a contradiction, and the case
split is exhaustive ($ad=0$ forces one of the two), so no scalars
$a,b,c,d$ satisfying all four equations exist. (The other constraint,
$bc=0$, gives the identical conclusion by the symmetric argument: $b=0
\Rightarrow bd=0$, contradiction; $c=0\Rightarrow ac=0$, contradiction —
consistent with, and not needed beyond, the argument above.) Hence
$|\Phi^+\rangle$ is not separable — it is entangled.

**4.** **Definition (partial trace over qubit 2):** for basis vectors
$|a\rangle,|b\rangle$ of qubit 1 and $|c\rangle,|d\rangle$ of qubit 2,
$$
\text{Tr}_2\big(|a\rangle\langle b|\otimes|c\rangle\langle d|\big) :=
\langle d|c\rangle\,|a\rangle\langle b|,
$$
extended to general operators by linearity.

Expand $|\Phi^+\rangle\langle\Phi^+| = \tfrac12(|00\rangle+|11\rangle)
(\langle00|+\langle11|) = \tfrac12\big(|00\rangle\langle00| +
|00\rangle\langle11| + |11\rangle\langle00| + |11\rangle\langle11|\big)$,
and rewrite each term in $(\cdot)\otimes(\cdot)$ form:
$$
|00\rangle\langle00| = |0\rangle\langle0|\otimes|0\rangle\langle0|,\quad
|00\rangle\langle11| = |0\rangle\langle1|\otimes|0\rangle\langle1|,\quad
|11\rangle\langle00| = |1\rangle\langle0|\otimes|1\rangle\langle0|,\quad
|11\rangle\langle11| = |1\rangle\langle1|\otimes|1\rangle\langle1|.
$$
Apply the partial-trace definition term by term:
$$
\text{Tr}_2\big(|0\rangle\langle0|\otimes|0\rangle\langle0|\big) =
\langle0|0\rangle\,|0\rangle\langle0| = |0\rangle\langle0|,\qquad
\text{Tr}_2\big(|0\rangle\langle1|\otimes|0\rangle\langle1|\big) =
\langle1|0\rangle\,|0\rangle\langle1| = 0,
$$
$$
\text{Tr}_2\big(|1\rangle\langle0|\otimes|1\rangle\langle0|\big) =
\langle0|1\rangle\,|1\rangle\langle0| = 0,\qquad
\text{Tr}_2\big(|1\rangle\langle1|\otimes|1\rangle\langle1|\big) =
\langle1|1\rangle\,|1\rangle\langle1| = |1\rangle\langle1|.
$$
Summing with the overall $\tfrac12$:
$$
\rho_1 = \tfrac12\big(|0\rangle\langle0| + |1\rangle\langle1|\big) =
\tfrac12\begin{pmatrix}1&0\\0&0\end{pmatrix} +
\tfrac12\begin{pmatrix}0&0\\0&1\end{pmatrix} =
\begin{pmatrix}\tfrac12&0\\0&\tfrac12\end{pmatrix} = \frac{I}{2}.
$$
So $\rho_1 = I/2$: the maximally mixed state, even though $|\Phi^+\rangle$
itself is pure.

**5.** *Theorem:* no unitary $U$ on two qubits satisfies $U(|\psi\rangle
\otimes|0\rangle) = |\psi\rangle\otimes|\psi\rangle$ for every
single-qubit $|\psi\rangle$.

*Proof.* Assume such a $U$ exists. Applied to the two basis states:
$$
U(|0\rangle\otimes|0\rangle) = |00\rangle, \qquad
U(|1\rangle\otimes|0\rangle) = |11\rangle.
$$
Applied to $|+\rangle = \tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)$, the
cloning assumption *requires*
$$
U(|+\rangle\otimes|0\rangle) = |+\rangle\otimes|+\rangle =
\tfrac12(|00\rangle+|01\rangle+|10\rangle+|11\rangle).
$$
But $U$ is linear, and $|+\rangle\otimes|0\rangle = \tfrac{1}{\sqrt2}
(|0\rangle\otimes|0\rangle) + \tfrac{1}{\sqrt2}(|1\rangle\otimes|0\rangle)$,
so *independently of the cloning assumption*, linearity alone gives the
*actual* value:
$$
U(|+\rangle\otimes|0\rangle) = \tfrac{1}{\sqrt2}U(|0\rangle\otimes|0\rangle)
+ \tfrac{1}{\sqrt2}U(|1\rangle\otimes|0\rangle) = \tfrac{1}{\sqrt2}|00\rangle
+ \tfrac{1}{\sqrt2}|11\rangle = \tfrac{1}{\sqrt2}(|00\rangle+|11\rangle).
$$
Comparing: the required value has coefficient $\tfrac12$ on $|01\rangle$,
while the actual value (forced by linearity) has coefficient $0$ on
$|01\rangle$ — and $\tfrac12 \ne 0$. (Equivalently: required has
coefficient $\tfrac12$ on $|00\rangle$, actual has $\tfrac{1}{\sqrt2}$ on
$|00\rangle$, and $\tfrac12\ne\tfrac{1}{\sqrt2}$.) These are two different
vectors, so $U(|+\rangle\otimes|0\rangle)$ cannot equal both — a direct
contradiction. Hence no such universal cloning unitary $U$ exists.
$\blacksquare$

**6.** With $X=\begin{pmatrix}0&1\\1&0\end{pmatrix}$ and
$Z=\begin{pmatrix}1&0\\0&-1\end{pmatrix}$, using the block rule $X\otimes Z
= \begin{pmatrix}0\cdot Z & 1\cdot Z\\ 1\cdot Z & 0\cdot Z\end{pmatrix}$:
$$
X\otimes Z = \begin{pmatrix}
0 & 0 & 1 & 0\\
0 & 0 & 0 & -1\\
1 & 0 & 0 & 0\\
0 & -1 & 0 & 0
\end{pmatrix}.
$$
*(a) Direct check:* call this matrix $M$. $M$ is real and symmetric
($M^\dagger=M^T=M$), so unitarity reduces to $M^2=I$. Computing row-by-row
(row $i$ of $M^2$ is $\sum_k M_{ik}\cdot(\text{row }k\text{ of }M)$):
row 1 of $M^2$ = $1\times$(row 3 of $M$) = $(1,0,0,0)$; row 2 = $-1\times$
(row 4 of $M$) = $-1\times(0,-1,0,0)=(0,1,0,0)$; row 3 = $1\times$(row 1 of
$M$) = $(0,0,1,0)$; row 4 = $-1\times$(row 2 of $M$) = $-1\times(0,0,0,-1)
=(0,0,0,1)$. So $M^2 = I_4$, and since $M=M^\dagger$, $M^\dagger M = M^2 =
I_4$ — $M$ is unitary.

*(b) General argument:* $X$ and $Z$ are each unitary ($X^\dagger X = X^2 =
I$, $Z^\dagger Z = Z^2 = I$, both being Hermitian involutions). By the
mixed-product rule,
$$
(X\otimes Z)^\dagger(X\otimes Z) = (X^\dagger\otimes Z^\dagger)(X\otimes Z)
= (X^\dagger X)\otimes(Z^\dagger Z) = I\otimes I = I_4,
$$
confirming unitarity without any explicit $4\times4$ multiplication.

**7.** A separable state like $|00\rangle$ describes qubit 1 as genuinely,
independently being in the pure state $|0\rangle$ — measuring qubit 2, or
doing anything at all to it, teaches you nothing new about qubit 1, and
$\rho_1 = |0\rangle\langle0|$ (rank 1, one eigenvalue equal to $1$) reflects
exactly that: qubit 1 has a definite state of its own. $|\Phi^+\rangle$,
by contrast, is a perfectly pure, perfectly well-defined vector in the
*joint* 4-dimensional space — there is nothing uncertain or "mixed" about
the pair of qubits taken together. Yet its qubit-1 marginal $\rho_1=I/2$ is
maximally mixed (two equal eigenvalues $\tfrac12$, no preferred
eigenvector) — algebraically identical to "qubit 1 is a uniformly random
classical coin flip between $|0\rangle$ and $|1\rangle$." This mismatch —
total certainty about the whole, total uncertainty about a part — cannot
happen for a separable state (whose reduced density matrix is always pure,
as shown in the Theory section), so it is precisely what a mixed marginal
of a pure joint state signals: the qubits are correlated in a way that
cannot be decomposed into "qubit 1 has its own state" and "qubit 2 has its
own state" separately. That is entanglement.

## Journal template

```
## Day 7 — Multi-qubit states, entanglement & no-cloning
Key idea in my own words: ...
What confused me: ...
```
