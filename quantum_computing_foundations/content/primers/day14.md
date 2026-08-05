# Day 14 primer — Quantum Phase Estimation & Shor's Algorithm

## Warm-up

Day 13 built the three results that today assembles rather than re-derives. The
section "The Quantum Fourier Transform" defined the $M$-point QFT, derived the
butterfly recursion, and established the exact matrix for $M=4$; it also proved
unitarity, which is what licenses the inverse QFT at the end of QPE. The section
"Continued fractions" derived the algorithm that converts a floating-point phase
estimate $\varphi \approx k/r$ into the denominator $r$, including the precision
condition $|\varphi - k/r| < 1/(2r^2)$ that determines how many ancilla qubits
are needed. The section "Miller's reduction: from order to factor" showed that an
even order $r$ with $a^{r/2} \not\equiv -1 \pmod N$ yields $\gcd(a^{r/2}-1,N)$
as a nontrivial factor of $N$, and worked through the $N=15$, $a=7$ case that
today reuses. If any of those three sections feels unclear, revisit it before
reading further; today's derivations cite them by result, not by re-proof.

Day 8 derived the phase kickback identity: when an oracle $X^{f(x)}$ acts on a
target in $|-\rangle$, the eigenvalue $-1$ of $X$ kicks back onto the control
qubit as $(-1)^{f(x)}$, leaving the target $|-\rangle$ undisturbed. The section
"The oracle and phase kickback" made the mechanism fully explicit. Today's
generalization is exact: the only restriction being removed is that the eigenvalue
$e^{2\pi i \varphi}$ is now allowed to be any complex unit rather than one of
$\{1,-1\}$. The key phrase to have ready — "the target is an eigenvector, so the
gate writes the eigenvalue on the control and leaves the target alone" — should be
immediately obvious before you open Day 14.

Day 7 established tensor products and the factoring of multi-qubit states. The
QPE phase register consists of $t$ ancilla qubits that never become entangled
with the work register; verifying that independence at each step of the derivation
requires exactly the tensor-product accounting introduced in Day 7.

## The hook

Set $N=15$, $a=7$, and run QPE with $t=6$ phase-register qubits. The register
can return any integer in $\{0,\dots,63\}$; suppose a single run measures $x=48$.
Form the phase estimate: $\varphi = 48/64 = 3/4$. Feed $3/4$ into the
continued-fraction algorithm from Day 13's "Continued fractions": the expansion
terminates at $[0;1,3]$, converging to $3/4$ in two steps, with denominator $4$,
so the recovered order is $r=4$. Check Miller's conditions: $r=4$ is even, and
$7^2 \bmod 15 = 4 \ne 14 \equiv -1 \pmod{15}$, so Miller's reduction applies.
Compute $\gcd(7^2-1,15) = \gcd(48,15) = 3$. The algorithm outputs the factor $3$
and confirms $15 = 3 \times 5$ in a single QPE measurement. The day's **Claim:**
formalizes this run and verifies that $k=3$ and $\gcd(k,r) = \gcd(3,4) = 1$, so
the continued fraction lands exactly on $3/4$ without rounding.

The entire quantum contribution to that computation was the single integer $x=48$.
Every downstream step — dividing by $64$, running the continued-fraction
expansion, computing the gcd — is classical polynomial-time arithmetic. QPE is
needed because no efficient classical algorithm can sample integers $x$ with the
peaked distribution that the quantum circuit produces: the inverse QFT inside QPE
arranges destructive interference on all non-multiples of $2^t/r$ and constructive
interference on multiples, producing the four equal-probability spikes at $0$,
$16$, $32$, $48$ that make the factor accessible.

## The pictures

Picture the QPE circuit as a phase meter with $t$ tick marks. A column of $t$
ancilla qubits runs down the page, each passing through a Hadamard to enter the
state $\frac{1}{\sqrt{2}}(|0\rangle+|1\rangle)$. Moving right, ancilla $j$ then
controls one application of $U^{2^j}$ on the shared work register below it: this
action samples the harmonic $e^{2\pi i \varphi 2^j}$ of the unknown phase, writing
it on the $|1\rangle$ branch of that ancilla while leaving the work register in
the same eigenvector $|u\rangle$ it started in. Each successive ancilla samples a
higher harmonic — doubling the frequency at each row — so the column as a whole
captures $t$ independent frequency samples of $\varphi$. At the far right, the
inverse QFT sweeps across the entire ancilla column, combining all $t$ samples
into a single pointer that reads off the best integer estimate of $\varphi \cdot
2^t$.

Picture Shor's algorithm as a factory with a quantum core surrounded entirely by
classical machinery. On the input side, classical primality testing confirms $N$
is composite, and a classical random number generator picks $a$ coprime to $N$;
if that random pick happens to share a factor with $N$, the factor is returned
immediately without touching the quantum core. The quantum core — QPE on the
modular-multiplication unitary $U_a$ — receives $a$ and $N$ and emits a phase-
register measurement $x$. On the output side, the continued-fraction algorithm
converts $x/2^t$ to a candidate order $r$, and Miller's reduction converts $r$ to
a factor of $N$. The quantum box does exactly one thing the classical factory
cannot replicate efficiently: it samples from the peaked distribution over
multiples of $2^t/r$.

Picture the QPE measurement histogram for $N=15$, $a=7$, $t=6$. The horizontal
axis runs from $x=0$ to $x=63$ and the vertical axis shows probability. All
probability mass concentrates at four equally spaced spikes: $x=0$, $x=16$,
$x=32$, and $x=48$, each carrying probability $0.25$. The uniform spacing
reflects the four eigenphases $e^{2\pi i k/4}$ for $k=0,1,2,3$, and the fact
that $r=4$ divides $2^6=64$ exactly means every eigenphase produces a sharp delta
spike rather than a spread doublet. The spike at $x=0$ is the lone failure case
— its phase estimate $0$ gives $r=1$, which is uninformative — while the other
three spikes each recover $r=4$ through continued fractions, giving a $3/4$
success probability per run.

## Concrete-first walkthrough

The section "Setup: what Quantum Phase Estimation estimates" frames the problem.
A unitary $U$ has eigenvector $|u\rangle$ with eigenvalue $e^{2\pi i \varphi}$
for some $\varphi \in [0,1)$. Given controlled-$U^{2^j}$ for $j=0,\dots,t-1$,
QPE estimates $\varphi$ to $t$ bits using $t$ ancilla qubits initialized in
$|0\rangle$, Hadamarded to $\frac{1}{\sqrt{2}}(|0\rangle+|1\rangle)$, used as
controls for the respective $U^{2^j}$ gates, then passed through an inverse QFT
before measurement. The section also identifies the one component taken as a
given building block: the gate-level circuit implementing $U_a$ from elementary
reversible gates, whose construction is outside this course's scope.

The section "Phase kickback, generalized from a $\pm1$ phase to an arbitrary
phase" carries out the single-ancilla step. One ancilla in
$\frac{1}{\sqrt{2}}(|0\rangle+|1\rangle)$ controls $U^{2^j}$ on the target
eigenvector $|u\rangle$. Because $|u\rangle$ is an eigenvector of $U$, it is also
an eigenvector of $U^{2^j}$, with eigenvalue $e^{2\pi i \varphi \cdot 2^j}$ —
the proof is an induction detailed in the section. The controlled gate therefore
multiplies only the $|1\rangle$ branch by that scalar, leaving the $|0\rangle$
branch unchanged, and $|u\rangle$ factors cleanly from both terms. The ancilla
picks up phase $e^{2\pi i \varphi \cdot 2^j}$ on its $|1\rangle$ branch; the
work register returns to $|u\rangle$, unentangled. This is Day 8's "The oracle
and phase kickback" with the eigenvalue's phase unrestricted.

The section "From one ancilla to the full phase register: recognizing a QFT"
extends the result to all $t$ ancilla qubits. Because the target returns to
$|u\rangle$ unentangled after every controlled-$U^{2^j}$ step, the $t$ ancillas
act independently and the work register factors out of the final state. Expanding
the resulting $t$-fold tensor product in the computational basis, the coefficient
of $|x\rangle$ is the product of $e^{2\pi i \varphi 2^j x_j}$ over all bits $j$
of $x$, which collapses to $e^{2\pi i \varphi x}$ by binary expansion. The phase
register ends in $\frac{1}{\sqrt{2^t}}\sum_x e^{2\pi i \varphi x}|x\rangle$,
which Day 13's "The Quantum Fourier Transform" identifies as $\text{QFT}|\varphi
\cdot 2^t\rangle$; the circuit therefore appends $\text{QFT}^{-1}$ to recover the
peaked state $|\varphi \cdot 2^t\rangle$ before measurement.

The section "Assembling Shor's algorithm" wires QPE into the factoring pipeline.
The unitary is $U_a|y\rangle = |ay \bmod N\rangle$, whose eigenphases are
$e^{2\pi i k/r}$ for $k=0,\dots,r-1$ (stated as a given). Starting the work
register in $|1\rangle$ — an equal superposition of all eigenvectors — QPE
produces a measurement $x \approx k/r \cdot 2^t$ for a uniformly random $k$.
Day 13's "Continued fractions" then recovers $r$ from $x/2^t$, and Day 13's
"Miller's reduction: from order to factor" converts $r$ to a factor of $N$.
The section also describes when to retry: if $k=0$ or $\gcd(k,r)>1$ reduces the
continued-fraction result to a proper divisor of $r$, discard the result and
rerun QPE to sample a fresh $k$.

The section "The $N=15,\ a=7$ pipeline, traced end to end" executes all five
steps with explicit numbers, and closes with a traceability table assigning each
step to the day and section where it was derived. Work the table actively: cover
the right column, try to name the source for each step from memory, then check.
The **Claim:** in the Worked example extends the trace to $x=48$, confirming that
$k=3$ recovers the same $r=4$ and factor $3$ as the $k=1$ path traced in the
section, since $r$ is a property of $a$ and $N$ alone.

## Derivation roadmaps

Three derivations carry the core QPE work. Each has a single key trick; the
remaining steps are explicit algebra to fill in.

The derivation in "Phase kickback, generalized from a $\pm1$ phase to an
arbitrary phase" turns on the eigenvector power identity. Key trick:
$U^{2^j}|u\rangle = e^{2\pi i \varphi \cdot 2^j}|u\rangle$, proved by induction
on $k$ — base case $k=1$ is the hypothesis; the inductive step multiplies the
scalar $e^{2\pi i \varphi k}$ and $e^{2\pi i\varphi}$ by linearity of $U$. Fill
in: write controlled-$U^{2^j}$ acting on both branches, substitute the eigenvalue
identity on the $|1\rangle$ branch, confirm that $|u\rangle$ multiplies both
terms identically and therefore factors out, and read off the phase accumulated
on the $|1\rangle$ branch.

The derivation in "From one ancilla to the full phase register: recognizing a
QFT" turns on the binary representation of $x$. Key trick: the coefficient of
$|x\rangle$ in the $t$-fold tensor product is $\prod_{j=0}^{t-1} e^{2\pi i
\varphi 2^j x_j} = e^{2\pi i \varphi x}$, because $\sum_j 2^j x_j = x$ by
definition of binary notation. Fill in: expand the tensor product term by term
for a generic $x$, collect all phase exponentials, apply the binary sum identity,
include the $1/\sqrt{2^t}$ normalization, and match against Day 13's "The
Quantum Fourier Transform" definition at $y = \varphi \cdot 2^t$.

The derivation in "Assembling Shor's algorithm" turns on the eigenphase structure
of $U_a$. Key trick: $U_a$'s eigenphases are $e^{2\pi i k/r}$ for $k=0,\dots,
r-1$, so QPE on $U_a$ returns $\varphi \approx k/r$ for a random $k$, and $r$ is
recoverable from $\varphi$ by Day 13's "Continued fractions" whenever
$\gcd(k,r)=1$. Fill in: accept the eigenphase claim as given, write $|1\rangle$
as a superposition of eigenvectors, apply the QPE conclusion to each component,
argue the measurement selects a random $k$, and verify the precision bound
$|\varphi - k/r| < 1/(2r^2)$ is met for large enough $t$.

## Flashcards

Q: What does QPE output, and how do you convert it to a phase estimate?
A: QPE measures an integer $x \in \{0,\dots,2^t-1\}$; divide by $2^t$ to get $\varphi \approx x/2^t$, accurate to $t$ bits.

Q: What is the key trick that makes the generalized phase kickback work?
A: $U^{2^j}|u\rangle = e^{2\pi i \varphi \cdot 2^j}|u\rangle$ by induction, so the controlled gate writes that phase on the $|1\rangle$ branch of the control and returns $|u\rangle$ to the target unchanged.

Q: What state does the phase register hold after all $t$ controlled-$U^{2^j}$ steps, before the inverse QFT?
A: $\frac{1}{\sqrt{2^t}}\sum_{x=0}^{2^t-1} e^{2\pi i \varphi x}|x\rangle$, which equals $\text{QFT}|\varphi \cdot 2^t\rangle$.

Q: Why does QPE end with an inverse QFT, not a forward QFT?
A: The phase register already holds a QFT output; applying $\text{QFT}^{-1}$ recovers the basis state $|\varphi \cdot 2^t\rangle$ (up to rounding) so measurement yields an estimate of $\varphi$.

Q: In the **Claim:** example with $N=15$, $a=7$, $t=6$, and $x=48$, what are $\varphi$, $r$, and the factor?
A: $\varphi = 48/64 = 3/4$; continued fractions give $r=4$; $\gcd(7^2-1,15)=\gcd(48,15)=3$, so the factor is $3$.

Q: What continued-fractions precision condition guarantees $r$ is recovered exactly from a QPE measurement?
A: $|\varphi - k/r| < 1/(2r^2)$; choosing $t \ge 2\log_2 r + 1$ ancilla qubits ensures this holds.

Q: Which component of Shor's algorithm does this course treat as a given black box, and why?
A: The gate-level circuit implementing $U_a|y\rangle = |ay \bmod N\rangle$ from elementary reversible gates — modular-multiplication circuit synthesis is a separate topic outside this course's scope.
