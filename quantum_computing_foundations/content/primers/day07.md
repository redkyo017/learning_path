# Day 7 primer — Multi-qubit states, entanglement & no-cloning

## Warm-up

Day 3 gave you the qubit as a unit vector in $\mathbb{C}^2$, complex inner
products, the adjoint operator, and bra-ket notation — all of which transfer
directly to the joint two-qubit space you will work in today. Day 4 built the
toolkit of normal matrices, unitary gates, and the spectral theorem, and
introduced the Pauli matrices and Hadamard as the standard single-qubit
unitaries you will compose into two-qubit circuits. Day 6 closed out the
single-qubit picture with measurement, the Born rule, and density matrices:
a state is pure when its density matrix has rank 1 (equivalently,
$\mathrm{Tr}(\rho^2)=1$), and that rank-1 condition will reappear today as the
dividing line between separable and entangled states.

Today takes all of that single-qubit machinery and scales it to two qubits.
The algebraic move is the tensor product, which assembles two independent
$\mathbb{C}^2$ spaces into a single $\mathbb{C}^4$ — a space large enough to
contain genuinely new phenomena with no single-qubit analogue. Entanglement
lives in that larger space as a structural property of the global state vector,
and the no-cloning theorem is the most striking demonstration of what
linearity, the most basic axiom of quantum mechanics, forbids once you are
working in it.

## The hook

Suppose you want a quantum photocopier: a unitary $U$ on two qubits that
satisfies $U(|\psi\rangle\otimes|0\rangle) = |\psi\rangle\otimes|\psi\rangle$
for every single-qubit state $|\psi\rangle$. On the computational basis states
this is not immediately absurd. Applying the cloning property to $|0\rangle$
gives $U(|0\rangle\otimes|0\rangle) = |00\rangle$, and applying it to
$|1\rangle$ gives $U(|1\rangle\otimes|0\rangle) = |11\rangle$. Both are
consistent assignments for a unitary gate, and CNOT actually achieves them —
no contradiction yet.

The trouble arrives when you try to clone a superposition. Feed the copier
$|\psi\rangle = |{+}\rangle = \tfrac{1}{\sqrt2}(|0\rangle+|1\rangle)$. The
cloning assumption demands the output be $|{+}\rangle\otimes|{+}\rangle =
\tfrac12(|00\rangle+|01\rangle+|10\rangle+|11\rangle)$. But
$|{+}\rangle\otimes|0\rangle = \tfrac{1}{\sqrt2}(|0\rangle\otimes|0\rangle) +
\tfrac{1}{\sqrt2}(|1\rangle\otimes|0\rangle)$, so linearity of $U$ alone —
independent of any cloning assumption — forces the actual output to be
$\tfrac{1}{\sqrt2}|00\rangle + \tfrac{1}{\sqrt2}|11\rangle$.

Comparing the two vectors term by term resolves the issue immediately. The
coefficient of $|01\rangle$ is $0$ in the linearity result and $\tfrac12$ in
the cloning requirement. The coefficient of $|00\rangle$ is
$\tfrac{1}{\sqrt2}\approx0.707$ from linearity and $\tfrac12=0.5$ from cloning.
Since $0\ne\tfrac12$ and $\tfrac{1}{\sqrt2}\ne\tfrac12$, these are two genuinely
different vectors in $\mathbb{C}^4$. No single linear map can produce two
different vectors from the same input, so no universal cloning unitary $U$
exists. The entire argument is a coefficient comparison.

## The pictures

Think of the two-qubit state space as a column of four complex numbers, a
unit vector in $\mathbb{C}^4$. Tensor product states occupy a strict subset:
$|\chi\rangle\otimes|\varphi\rangle$ must have the coefficient pattern
$(\alpha\gamma,\alpha\delta,\beta\gamma,\beta\delta)$ — a rank-1 outer-product
structure. Entangled states fill the rest of $\mathbb{C}^4$. When you write
$|\Phi^+\rangle = \tfrac{1}{\sqrt2}(|00\rangle+|11\rangle)$ as the column
$(\tfrac{1}{\sqrt2},0,0,\tfrac{1}{\sqrt2})^T$ and try to match it to
$(\alpha\gamma,\alpha\delta,\beta\gamma,\beta\delta)$, the zero entries in the
middle slots and nonzero corner entries make factorization impossible — that
incompatibility is the geometry of entanglement made concrete.

For the partial trace, picture qubit 2 hidden behind a curtain. The operation
$\rho_1 = \mathrm{Tr}_2(\rho_{AB})$ is everything you can know about qubit 1
from measurements on qubit 1 alone, with qubit 2's degrees of freedom averaged
out. For a separable state $|\chi\rangle\otimes|\varphi\rangle$ the curtain
changes nothing — qubit 1 has a definite pure state of its own, and the result
is $|\chi\rangle\langle\chi|$. For $|\Phi^+\rangle$, drawing the curtain leaves
$I/2$: maximum uncertainty about qubit 1, even though the global two-qubit
state is a perfectly pure vector.

For no-cloning, picture a machine that copies black-and-white originals
($|0\rangle$ and $|1\rangle$) correctly but garbles any greyscale image. The
garbling is not a hardware defect; it is an exact arithmetic mismatch encoded in
the coefficients of $\mathbb{C}^4$, visible in the hook calculation above.
Orthogonal states can be cloned because there is no superposition to pit the
two linearity constraints against each other. Any non-orthogonal pair exposes
the clash.

## Concrete-first walkthrough

The section **The joint state space of two qubits** opens with the central
definition: the joint state of two qubits is a unit vector in
$\mathbb{C}^2\otimes\mathbb{C}^2\cong\mathbb{C}^4$ with ordered basis
$\{|00\rangle,|01\rangle,|10\rangle,|11\rangle\}$. The tensor product is
bilinear — linear in each argument separately — so it distributes like
polynomial multiplication: $(\alpha|0\rangle+\beta|1\rangle)\otimes
(\gamma|0\rangle+\delta|1\rangle) = \alpha\gamma|00\rangle+\alpha\delta|01\rangle
+\beta\gamma|10\rangle+\beta\delta|11\rangle$. The common trap is to treat
this as element-wise multiplication; the result has four components, not two.

The section **Embedding single-qubit gates: the Kronecker product** defines the
$4\times4$ matrix $A\otimes B$ in block form and establishes two structural
rules: the mixed-product rule $(A\otimes B)(C\otimes D)=(AC)\otimes(BD)$ and
the adjoint rule $(A\otimes B)^\dagger = A^\dagger\otimes B^\dagger$. Together
these prove that any Kronecker product of unitary single-qubit gates is itself
unitary. CNOT is then introduced as a gate that is not a Kronecker product —
and that distinction is precisely why it can create entanglement when
$H\otimes I$ alone cannot.

The section **Separability and entanglement** defines the two classes and then
constructs $|\Phi^+\rangle$ step by step: $H\otimes I$ applied to $|00\rangle$
yields the intermediate product state $\tfrac{1}{\sqrt2}(|00\rangle+|10\rangle)$,
and CNOT then correlates the two qubits to produce
$\tfrac{1}{\sqrt2}(|00\rangle+|11\rangle)$. The **Worked example** opens with a
second **Claim**: the same $\mathrm{CNOT}\cdot(H\otimes I)$ circuit generates
all four Bell states from the four computational basis inputs.

The section **The partial trace and reduced density matrices** formalizes "qubit
1's state alone." The partial trace over qubit 2 is defined on rank-1 operators
by $\mathrm{Tr}_2(|a\rangle\langle b|\otimes|c\rangle\langle d|)
= \langle d|c\rangle\,|a\rangle\langle b|$ and extended by linearity to all
operators on the joint space. For a separable state the result is always
pure. For $|\Phi^+\rangle$, the off-diagonal terms vanish because
$\langle 0|1\rangle = 0$, and only two diagonal terms survive, giving $\rho_1
= I/2$. The trap to avoid is treating the partial trace as a scalar trace over
the whole matrix; it contracts only one tensor factor.

The section **The no-cloning theorem** states the **Claim** — no universal
cloning unitary exists — and proves it through the coefficient comparison
described in the hook. The important nuance is that CNOT does successfully clone
the orthogonal pair $\{|0\rangle,|1\rangle\}$; the impossibility is specific to
non-orthogonal states. No linear map can agree with the quadratic cloning map
on two non-orthogonal inputs, and that is the full content of the theorem.

## Derivation roadmaps

For the no-cloning theorem, the key trick is to assume $U$ clones two arbitrary
states $|\psi\rangle$ and $|\phi\rangle$ and then take the inner product of both
cloning equations. The left side yields $\langle\psi|\phi\rangle$ while the
right side yields $(\langle\psi|\otimes\langle\psi|)(|\phi\rangle\otimes|\phi\rangle)
= \langle\psi|\phi\rangle^2$, forcing $\langle\psi|\phi\rangle\in\{0,1\}$ —
only orthogonal or identical states can be cloned. When you fill in the full
argument, track carefully which step uses the cloning assumption on each input
individually and which step uses only the fact that $U$ is unitary and therefore
preserves inner products.

For the partial trace, the key trick is to write out $\rho_{AB} =
|\Phi^+\rangle\langle\Phi^+|$ as a sum of four rank-1 terms in
$(\cdot)\otimes(\cdot)$ form, then apply $\mathrm{Tr}_2$ to each term
individually using $\mathrm{Tr}_2(|a\rangle\langle b|\otimes|c\rangle\langle d|)
= \langle d|c\rangle\,|a\rangle\langle b|$. When you fill in the derivation,
identify which pairs $(c,d)$ give $\langle d|c\rangle = 0$ (distinct basis
vectors) and which give $1$ (same basis vector); the off-diagonal terms vanish
because $\langle 0|1\rangle = 0$, leaving exactly $|0\rangle\langle0|$ and
$|1\rangle\langle1|$ each with weight $\tfrac12$.

For the Bell state construction, the key trick is that $H$ maps $|0\rangle$ to
$|{+}\rangle$ and $|1\rangle$ to $|{-}\rangle$, creating a first-qubit
superposition, and CNOT then uses qubit 1 as control to correlate qubit 2 via
$|x_1,x_2\rangle\mapsto|x_1,x_2\oplus x_1\rangle$. When you fill in all four
cases, apply $H\otimes I$ first using both $H|0\rangle=|+\rangle$ and
$H|1\rangle=|-\rangle$, then apply CNOT term by term, carrying the sign through
linearity unchanged, and verify which of the four Bell states results from each
computational basis input.

## Flashcards

Q: What is $(\alpha|0\rangle+\beta|1\rangle)\otimes(\gamma|0\rangle+\delta|1\rangle)$
expanded in the standard two-qubit basis?
A: $\alpha\gamma|00\rangle+\alpha\delta|01\rangle+\beta\gamma|10\rangle+\beta\delta|11\rangle$.
The tensor product is bilinear and produces four components; it is not element-wise multiplication.

Q: What does it mean for a two-qubit pure state to be separable?
A: It can be written as $|\chi\rangle\otimes|\varphi\rangle$ for some single-qubit states
$|\chi\rangle$ and $|\varphi\rangle$. If no such factorization exists, the state is entangled.

Q: What circuit prepares $|\Phi^+\rangle$ from $|00\rangle$, and what is $|\Phi^+\rangle$?
A: Apply $H\otimes I$ (Hadamard on qubit 1, identity on qubit 2) then CNOT (control qubit 1).
The result is $|\Phi^+\rangle = \tfrac{1}{\sqrt2}(|00\rangle+|11\rangle)$.

Q: Write the partial trace formula as a sum over a basis.
A: $\rho_A = \sum_j\langle j_B|\rho_{AB}|j_B\rangle$, summing over an orthonormal basis $\{|j_B\rangle\}$
of qubit B's space. On rank-1 operators the defining rule is
$\mathrm{Tr}_2(|a\rangle\langle b|\otimes|c\rangle\langle d|)=\langle d|c\rangle\,|a\rangle\langle b|$.

Q: What is the reduced density matrix $\rho_1$ of qubit 1 for $|\Phi^+\rangle$, and what does it mean?
A: $\rho_1 = I/2$, the maximally mixed state. Even though $|\Phi^+\rangle$ is globally pure,
qubit 1 has no definite pure state of its own — a mixed marginal from a pure joint state is the
algebraic signature of entanglement.

Q: State the no-cloning theorem precisely.
A: There is no unitary $U$ on two qubits such that $U(|\psi\rangle\otimes|0\rangle)
= |\psi\rangle\otimes|\psi\rangle$ holds for every single-qubit state $|\psi\rangle$.

Q: Why can CNOT clone $|0\rangle$ and $|1\rangle$ but no unitary can clone $|{+}\rangle$?
A: CNOT clones the orthogonal pair $\{|0\rangle,|1\rangle\}$ because the two assignments never
conflict. For $|{+}\rangle$, linearity forces the output to be $\tfrac{1}{\sqrt2}(|00\rangle+|11\rangle)$,
which differs from the required clone $\tfrac12(|00\rangle+|01\rangle+|10\rangle+|11\rangle)$.
No linear map can agree with the cloning map on two non-orthogonal states.

Q: How do you verify that $\rho_1 = I/2$ is a valid density matrix?
A: $\mathrm{Tr}(I/2) = \tfrac12\mathrm{Tr}(I_2) = \tfrac12\cdot2 = 1$, satisfying the trace-one
condition. The eigenvalues $\tfrac12,\tfrac12$ are both non-negative, so $\rho_1$ is positive
semidefinite as required.
