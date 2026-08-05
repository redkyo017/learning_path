# Day 8 primer — Quantum parallelism & the Deutsch–Jozsa algorithm

## Warm-up

Day 7 built the tensor-product formalism, gave you the mechanics of
multi-qubit states and entanglement, and proved the no-cloning theorem:
no unitary can copy an arbitrary unknown quantum state. Day 6 gave you
the measurement postulate and the Born rule — measuring $|\psi\rangle =
\sum_x \alpha_x|x\rangle$ yields outcome $x$ with probability $|\alpha_x|^2$
and collapses the state irreversibly to $|x\rangle$, destroying all other
amplitudes. Day 2 introduced the classical randomized version of today's
promise problem and the all-agree algorithm: query $f$ at $m$ random
points, guess constant if all answers agree, balanced otherwise, with
confidence $1 - 2^{-(m-1)}$ — never certainty for any finite $m$.

Before reading further, confirm you can write the tensor product
$|a\rangle \otimes |b\rangle$ in full Dirac notation for single-qubit
states, state the no-cloning theorem in one sentence, and recall what
$|-\rangle$ is: $\frac{1}{\sqrt2}(|0\rangle - |1\rangle)$. That single
auxiliary state is the key ingredient today's algorithm adds to what
Day 7 prepared.

## The hook

Take the balanced function $f(00)=0,\,f(01)=1,\,f(10)=1,\,f(11)=0$ on
two input bits. The amplitude the algorithm places on $|00\rangle$ after
a single oracle call sandwiched between two Hadamard layers is
$a_0 = \frac{1}{4}\sum_x (-1)^{f(x)}$. Plugging in the four values:
$(-1)^0 + (-1)^1 + (-1)^1 + (-1)^0 = 1 - 1 - 1 + 1 = 0$, so
$a_0 = \frac{1}{4}\cdot 0 = 0$. The probability of observing $|00\rangle$
is $|a_0|^2 = 0$ — exactly impossible. Seeing any outcome other than
$|00\rangle$ certifies balanced with certainty in one query.

A classical randomized algorithm cannot achieve this. It must query $f$
at individual points and infer from the outputs; no finite collection of
point evaluations pins down the global sum $\sum_x (-1)^{f(x)}$ with
certainty, because an adversarially constructed balanced $f$ can look
identical to a constant $f$ on all queried points. The classical
confidence bound is $1 - 2^{-(m-1)}$ after $m$ queries, and no finite
$m$ reaches zero error. The gap today is therefore qualitative: exact
versus bounded-error, and one query versus $\Omega(2^n)$ in the worst case.

## The pictures

Picture the Deutsch–Jozsa circuit as a five-stage pipeline. The first
stage sets up two registers: the $n$-qubit input register in
$|0\rangle^{\otimes n}$ and the single output register in $|1\rangle$.
The second stage applies Hadamard to every qubit, spreading the input
register into a uniform superposition of all $2^n$ bit strings and
converting the output register into $|-\rangle$. The third stage is the
oracle $U_f$, which stamps $f$'s information across the superposition
as per-branch relative phases. The fourth stage is a second Hadamard
layer on the input register, converting those phase differences into
amplitude differences that are visible to measurement. The fifth and
final stage is a single measurement of the input register: observing
$|0^n\rangle$ certifies constant; observing anything else certifies
balanced.

Now picture the output register alone as a phase reservoir. When the
oracle acts on a branch $|x\rangle\otimes|-\rangle$, it was defined to
XOR $f(x)$ into the output register — but since the output is already
$|-\rangle$, XOR-ing zero leaves it unchanged and XOR-ing one flips
its sign back to the same $|-\rangle$ state. Either way the output
register returns unentangled and unchanged; what changes is that the
input-register branch $|x\rangle$ acquires a relative phase
$(-1)^{f(x)}$. The ancilla is never read. Its sole role is to let the
oracle write $f(x)$ as a relative phase on the input side rather than
as a bit value stored in the output register.

Finally, picture what those relative phases do at the second Hadamard
layer. Before that layer, each branch $(-1)^{f(x)}|x\rangle$ carries a
sign that is invisible to measurement in the standard basis — measuring
at that point yields a uniform random $x$, no better than a single
classical query. The second Hadamard recombines all $2^n$ branches into
new amplitudes on each output string $|y\rangle$. For $y = 0^n$ the
recombination is especially clean: every branch contributes, and the
amplitude is $a_0 = \frac{1}{2^n}\sum_x(-1)^{f(x)}$. Constant $f$
makes all signs agree — perfect constructive interference, $|a_0|=1$.
Balanced $f$ cancels them exactly — perfect destructive interference,
$a_0=0$.

## Concrete-first walkthrough

The formal setup is in **The promise problem**: $f:\{0,1\}^n\to\{0,1\}$
is promised to be constant (same output on every input) or balanced
(exactly $2^{n-1}$ inputs map to each output value). The task is to
decide which case holds using as few oracle queries as possible.

The oracle definition and the algorithm's central trick live in **The
oracle and phase kickback**. The oracle is $U_f|x\rangle|b\rangle =
|x\rangle|b\oplus f(x)\rangle$: reversible, unitary, and applicable to
quantum superpositions by linearity. The trick is to supply the output
register in $|-\rangle$ rather than $|0\rangle$. When you do, the
**Claim (phase kickback)** applies: $U_f|x\rangle|-\rangle =
(-1)^{f(x)}|x\rangle|-\rangle$. The factor $(-1)^{f(x)}$ is a relative
phase on branch $|x\rangle$ inside a superposition — different branches
carry different signs, and those sign differences survive to affect
interference in the final Hadamard layer. This is not a global phase:
it has measurable consequences. The trap to avoid is starting the output
register in $|0\rangle$ instead; phase kickback does not occur, and the
oracle merely writes $f(x)$ classically into the output register with
no phase effect on the input.

**The Hadamard-transform identity** and its **Claim** state:
$H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle$,
where $x\cdot y = \sum_i x_i y_i \bmod 2$. This identity is applied
twice: first with $x = 0^n$ to produce the uniform input superposition,
and then after the oracle to route the phased amplitudes into measurable
amplitude differences.

**The Deutsch–Jozsa circuit, general $n$** assembles these two tools:
initialize both registers, apply $H^{\otimes n}$ to both, apply $U_f$,
apply $H^{\otimes n}$ to the input register again, and measure the input.
Constant $f$ produces $|0^n\rangle$ with certainty; balanced $f$ can
never produce $|0^n\rangle$.

The quantitative stakes appear in **Comparison with the classical
randomized algorithm (Day 2)**. The all-agree strategy achieves
confidence $1 - 2^{-(m-1)}$ after $m$ queries; bringing error below
$2^{-20}$ requires $m = 21$ queries, after which a genuine $2^{-20}$
error probability still remains. Deutsch–Jozsa uses one query and
produces the correct answer with probability $1$ — a gap in both query
count and error model.

## Derivation roadmaps

To derive the **Claim (phase kickback)**, the key trick is to expand
$|-\rangle = \frac{1}{\sqrt2}(|0\rangle - |1\rangle)$ before applying
$U_f$ and then distribute $U_f$ over the two terms by linearity. After
applying the oracle's defining action to each term, the output register
holds $|f(x)\rangle$ in one term and $|1\oplus f(x)\rangle$ in the
other. Case on $f(x)=0$ and $f(x)=1$ separately: the bracket reduces
to $|-\rangle$ in the first case and $-|-\rangle$ in the second.
Factoring out the sign in each case gives $(-1)^{f(x)}$ multiplying
$|x\rangle|-\rangle$. Fill in: write the full tensor expansion, apply
the oracle definition term by term, and collect the sign by cases.

To derive the **Claim** in **The Hadamard-transform identity**, the key
trick is that $H$ on a single-qubit basis state $|x_j\rangle$ gives
$\frac{1}{\sqrt2}\sum_{y_j\in\{0,1\}}(-1)^{x_j y_j}|y_j\rangle$. Taking
the tensor product across all $n$ qubits multiplies $n$ such single-qubit
sums, and the product of the signs is
$(-1)^{x_1 y_1}\cdots(-1)^{x_n y_n} = (-1)^{x\cdot y}$. Fill in: write
the explicit $n$-fold tensor product, expand each qubit factor using the
single-qubit identity, and identify the combined exponent as the bitwise
inner product.

To derive the constant-versus-balanced outcome, the key trick is that
setting $y = 0^n$ in the post-circuit amplitude formula makes every
$x\cdot y$ term vanish, leaving $a_0 = \frac{1}{2^n}\sum_x(-1)^{f(x)}$.
For constant $f$ all $2^n$ terms share the same sign, so the sum is
$\pm 2^n$ and $|a_0|=1$. For balanced $f$ exactly $2^{n-1}$ terms are
$+1$ and $2^{n-1}$ are $-1$, so the sum is $0$ and $a_0=0$. Fill in:
derive the amplitude formula from the general-$n$ circuit state, then
supply the explicit counting argument for each case.

## Flashcards

Q: What does the promise in the Deutsch–Jozsa problem require of
$f:\{0,1\}^n\to\{0,1\}$?

A: $f$ is promised to be either constant (same output on every input) or
balanced (exactly $2^{n-1}$ inputs map to $0$ and $2^{n-1}$ to $1$).
No other case is possible under the promise.

Q: State the phase-kickback identity and name what the ancilla register
must be initialized to.

A: $U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle$. The ancilla
must start in $|-\rangle = \frac{1}{\sqrt2}(|0\rangle-|1\rangle)$, not
$|0\rangle$; starting in $|0\rangle$ produces no phase effect on the input.

Q: State the Hadamard-transform identity and name the quantity that
controls each sign.

A: $H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_{y}(-1)^{x\cdot y}|y\rangle$,
where $x\cdot y = \sum_i x_i y_i \bmod 2$ is the bitwise inner product.

Q: What does the Deutsch–Jozsa circuit output for constant $f$, and
for balanced $f$?

A: Constant $f$: measuring the input register always gives $|0^n\rangle$,
probability $1$. Balanced $f$: the input register can never be
$|0^n\rangle$; the probability of seeing $|0^n\rangle$ is exactly $0$.

Q: What distinguishes a relative phase from a global phase, and why does
the distinction matter in the Deutsch–Jozsa circuit?

A: A global phase multiplies the entire state and leaves all measurement
probabilities unchanged. A relative phase is a sign difference between
distinct branches of a superposition; further unitaries can convert it
into an amplitude difference, which does affect measurement probabilities.
The factor $(-1)^{f(x)}$ on branch $|x\rangle$ is a relative phase that
the second Hadamard layer converts into constructive or destructive
interference at $|0^n\rangle$.

Q: What confidence does the classical all-agree algorithm achieve after
$m$ queries, and how many queries are needed to bring error below
$2^{-20}$?

A: Confidence $1 - 2^{-(m-1)}$ after $m$ queries; $m = 21$ queries bring
error below $2^{-20}$, and even then a genuine $2^{-20}$ error remains.

Q: How many oracle queries does Deutsch–Jozsa need, and how does its
error guarantee compare with the classical algorithm?

A: Exactly one oracle query, with probability-$1$ correctness for any $n$.
The classical algorithm needs $m = 21$ queries for error below $2^{-20}$
and still has positive error — Deutsch–Jozsa is strictly stronger in
both query count and error model.
