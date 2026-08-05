# Before you read — Day 15: Beyond discrete-time quantum computing

## Warm-up

Day 2's material on BPP and randomized computation is the single most
important prerequisite for today. That day established the definition of
BPP — decision problems solvable in probabilistic polynomial time with
two-sided error at most $1/3$ — and proved, via the Hoeffding inequality,
that running a BPP algorithm $k$ independent times and taking the majority
vote drives the failure probability down to $e^{-k/18}$. Today's definition
of BQP uses the exact same template, with quantum circuits replacing
probabilistic algorithms, and the error amplification argument transfers
without modification.

Day 12 on Grover optimality returns in a supporting role. The BBBV lower
bound — any quantum algorithm needs $\Omega(\sqrt{N})$ oracle queries for
unstructured search — is cited when discussing quantum advantage to make
precise what an exponential quantum speedup means and, more importantly,
what it does not mean. Grover's quadratic advantage is optimal for
unstructured search, yet unstructured search and NP-hard decision problems
are quite different things, a distinction today's complexity landscape
sharpens considerably.

Day 14 on Quantum Phase Estimation and Shor's algorithm supplies the main
concrete example of a problem believed to separate BQP from BPP. The final
exam revisits the entire Shor pipeline — order-finding via QPE, continued-
fraction recovery of the order, then Miller's reduction — applied to $N=21$
rather than $N=15$. If the Day 14 pipeline is comfortable, the new example
will feel like routine practice rather than a surprise.

## The hook

The $e^{-k/18}$ bound from Day 2's Hoeffding argument does something
striking when pushed hard. To drive the error probability below $2^{-20}$
— roughly one part in a million — you need $e^{-k/18} \le 2^{-20}$, which
rearranges to $k/18 \ge 20\ln 2$, giving $k \ge 360\ln 2 \approx 249.5$.
So $k = 250$ independent repetitions of the original circuit suffice; if
odd $k$ is required to break majority ties, take $k = 251$. The punchline
is that starting from a constant error bound and reaching inverse-exponential
precision costs only a polynomial count of repetitions — and the same
argument applies identically to BQP, because the Hoeffding bound cares only
about independence and a constant gap from $1/2$, not about whether the
underlying randomness comes from coin flips or quantum measurement outcomes.

## The pictures

Picture one is the complexity Venn diagram. Draw four nested regions: $P$
innermost, then $BPP$ around it, then $BQP$, then $PSPACE$ as the outermost
container. All four inclusions are proven unconditionally. Now draw a fifth
region, $NP$, that partially overlaps $BQP$ and $PSPACE$ but without a
determined nesting: its position relative to $BQP$ is unknown in both
directions — neither $BQP \subseteq NP$ nor $NP \subseteq BQP$ has been
proved. The open question mark between $BQP$ and $NP$ is the central
unsolved relationship in today's theory portion.

Picture two is the adiabatic energy landscape. Draw a horizontal axis
representing the interpolation parameter from $H(0)$ on the left to $H(T)$
on the right, and a vertical axis for energy. At each point draw the ground-
state energy as the lowest curve and the first excited energy as the curve
above it; the gap between them is the spectral gap. So long as this gap
never pinches to zero, a system starting in the ground state of $H(0)$ is
carried by a sufficiently slow evolution all the way into the ground state
of $H(T)$, which encodes the problem's solution.

Picture three is the quantum advantage frontier. Place circuit depth on the
horizontal axis and classical simulation cost on the vertical. At low depth
classical algorithms track the quantum device efficiently. Past a threshold
depth the classical cost surges to what appears superpolynomial, and this
is where advantage claims live. The critical visual detail is that the
threshold is not fixed: classical simulation algorithms have improved over
time, moving the frontier rightward. Claiming quantum advantage means
claiming the device is beyond today's frontier; it does not claim the
frontier can never move.

## Concrete-first walkthrough

The section "BQP: bounded-error quantum polynomial time" establishes what a
quantum computer can solve efficiently under the same probabilistic acceptance
convention BPP uses. A decision problem is in BQP if there is a uniformly
generated family of poly-size quantum circuits, built from a fixed universal
gate set, such that YES instances are accepted with probability at least $2/3$
and NO instances with probability at most $1/3$. The threshold $1/3$ is not
special: any constant strictly less than $1/2$ gives the same class, because
the Hoeffding majority-vote argument amplifies the gap exponentially at
polynomial repetition cost, exactly as it does for BPP.

The containment chain in "The complexity landscape: $P\subseteq BPP\subseteq
BQP\subseteq PSPACE$" rests on three separate unconditional arguments. The
step $P \subseteq BPP$ is immediate: a deterministic algorithm has error
$0 \le 1/3$, meeting BPP's bound without modification. The step $BPP \subseteq
BQP$ is a simulation: given a BPP algorithm, build a quantum circuit that
generates each random bit by measuring a Hadamard-rotated ancilla qubit, then
simulates the classical logic via Toffoli and CNOT gates acting only on
computational basis states, never creating genuine superposition or entanglement
in the logic steps. The output distribution is identical to the original BPP
algorithm's, so the same $\le 1/3$ error bound holds. The step $BQP \subseteq
PSPACE$ is a space-efficient path-sum: the acceptance probability is a sum
over exponentially many computational paths through intermediate basis states.
Enumerating paths one at a time — computing each path's contribution in
polynomial space and adding to a running total, then discarding the path
before starting the next — keeps the memory footprint polynomial even though
the enumeration takes exponential time. PSPACE places no bound on time, so
this puts BQP decisions inside PSPACE.

None of these containments is known to be strict. PSPACE is the class of
languages decidable using at most polynomial space and unbounded time —
believed much larger than BQP, but no proof separates them. Whether
$BQP \supsetneq BPP$ is the central open question: integer factoring is in
BQP via Shor's algorithm, and no classical probabilistic poly-time factoring
algorithm is known, but nothing unconditionally rules one out. NP is the
class of decision problems whose YES instances have a polynomial-length
certificate verifiable in polynomial time by a deterministic machine; an
NP-complete problem is one in NP to which every NP problem poly-time reduces,
with SAT as the canonical example via the Cook–Levin theorem. The relationship
between BQP and NP is open in both directions: neither $NP \subseteq BQP$
nor $BQP \subseteq NP$ has been established. BBBV shows the quadratic Grover
speedup is optimal for unstructured search — evidence against $NP \subseteq
BQP$ for that special case, but not a proof, since it says nothing about
NP-complete problems that might carry exploitable structure.

The section "The adiabatic model" introduces a primitive that looks entirely
different from the gate-circuit model: instead of discrete unitary gates,
computation is a single continuously varying physical process. The adiabatic
theorem says that if a Hamiltonian $H(t)$ is varied slowly enough relative
to the spectral gap at every moment, a system starting in the ground state
of $H(0)$ tracks the instantaneous ground state throughout and ends in the
ground state of $H(T)$. The algorithmic version encodes a problem's solution
as the ground state of $H(T)$, starts from an easy-to-prepare ground state
of $H(0)$, and reads off the answer by measurement. Despite the completely
different computational surface, the adiabatic model is polynomially equivalent
to the discrete circuit model: nothing achievable adiabatically escapes BQP,
and nothing achievable in the circuit model is unreachable adiabatically.

The section "Quantum advantage / supremacy claims" draws the line between
experimental evidence and complexity-theoretic proof. An advantage claim —
canonical example: random-circuit sampling — asserts that no currently known
classical algorithm reproduces the sampling task in comparable time on current
hardware. It does not assert that $BQP \supsetneq BPP$ is proved, because
complexity classes capture what is possible in principle for all algorithms,
not what today's algorithms happen to do. A future classical breakthrough
could close an empirical gap without touching the unconditional separation.
The section "Two open problems" closes the theory honestly: no language has
been unconditionally proved to lie in $BQP \setminus BPP$, and integer
factoring might yet admit a classical probabilistic poly-time algorithm —
an open question independent of $P$ versus $NP$.

## Derivation roadmaps

For the chain $P \subseteq BPP \subseteq BQP$: the key trick for the first
step is that deterministic computation is probabilistic computation with error
exactly $0$, which trivially meets the $\le 1/3$ bound. For the second step,
the key trick is that a classical randomized computation is a special case of
quantum — no entanglement, amplitudes stay real and non-negative, random bits
come from measured Hadamards. Fill in: verify that the simulating circuit's
output distribution matches the classical algorithm's exactly, and confirm
that the circuit size grows by at most a polynomial factor.

For $BQP \subseteq PSPACE$: the key trick is that the exponential-time path
enumeration can be executed in polynomial space by processing one path at a
time, keeping only the current path's description ($O(n)$ bits per gate) and
a running accumulator, never holding two paths simultaneously. Time blows up
exponentially; space does not. Fill in: count precisely how many bits describe
one intermediate-basis-state path and one gate matrix entry, then verify that
discarding a completed path releases all of its space before the next begins.

For BQP error amplification: the key trick is that Hoeffding's inequality
requires only independence and a constant success bias above $1/2$ — no
assumption of classical randomness. Running the quantum circuit $k$ independent
times with fresh ancillas and measurements each run produces exactly $k$ i.i.d.
Bernoulli trials with $\Pr[\text{correct}] \ge 2/3$. Fill in: set $\mu \ge
2k/3$, choose $t = k/6$, and verify that the exponent $-2t^2/k$ simplifies
to $-k/18$.

## Flashcards

Q: What is BQP?
A: The class of decision problems solvable by a uniformly generated family of
poly-size quantum circuits such that YES instances are accepted with probability
$\ge 2/3$ and NO instances with probability $\le 1/3$.

Q: State the proven four-class containment chain.
A: $P \subseteq BPP \subseteq BQP \subseteq PSPACE$. All three inclusions are
proven unconditionally; whether any is strict in the reverse direction is open.

Q: What is PSPACE?
A: The class of languages decidable using at most polynomial space and unbounded
time.

Q: What is NP, and what is an NP-complete problem?
A: NP is the class of decision problems whose YES instances have a polynomial-
length certificate verifiable in polynomial time. NP-complete means every NP
problem poly-time reduces to it; SAT is the canonical example (Cook–Levin).

Q: What is the known relationship between BQP and NP?
A: It is open in both directions: neither $NP \subseteq BQP$ nor $BQP \subseteq
NP$ has been proved or refuted.

Q: Describe the adiabatic model and its relationship to the gate-circuit model.
A: Start in an easy ground state, slowly vary the Hamiltonian keeping the
spectral gap open, and read off the final ground state as the solution. The
adiabatic model is polynomially equivalent to the discrete gate-circuit model.

Q: What does a quantum advantage experiment prove, and what does it not prove?
A: It proves no currently known classical algorithm reproduces the sampling task
efficiently on current hardware. It does not prove $BQP \supsetneq BPP$, which
remains an unconditional open statement about all possible algorithms.

Q: How many repetitions $k$ suffice to push majority-vote error below $2^{-20}$,
and when should you use $k = 251$ instead?
A: $k = 250$ suffices since $e^{-250/18} < 2^{-20}$. Use $k = 251$ when odd
$k$ is required to avoid ties in the majority vote.

Q: A lemma equating $\sum_{x \in \{0,1\}^n}(-1)^{x \cdot z}$ to $2^n$ when
$z = 0^n$ and $0$ otherwise appears in Day 10. What is it called there?
A: The parity-orthogonality lemma. (It is also called the character-sum lemma
elsewhere, but the Day 10 name is parity-orthogonality lemma.)
