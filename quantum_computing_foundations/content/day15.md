# Day 15 — Beyond Discrete-Time Quantum Computing & Final Exam

## Learning objectives

By the end of today you should be able to:
- State the definition of BQP and prove that its error probability is
  amplifiable exponentially, by the same Chernoff/Hoeffding argument used
  for BPP.
- Prove $P\subseteq BPP\subseteq BQP$ and sketch why $BQP\subseteq PSPACE$,
  and state precisely which relationships among $P$, $BPP$, $BQP$, $NP$,
  $PSPACE$ are proven and which remain open.
- State the adiabatic theorem informally and the fact (without proof) that
  adiabatic quantum computation is polynomially equivalent to the circuit
  model.
- Explain precisely what a random-circuit-sampling "quantum advantage" claim
  does and does not assert about the relationship between $BQP$ and $BPP$.
- Sit a full closed-book exam spanning Modules 1–7, and carry out a
  gap-analysis pass that re-derives, from scratch, anything that came out
  wrong or shaky.

## Reference material

- Nielsen & Chuang, *Quantum Computation and Quantum Information*, the
  chapter(s) covering quantum complexity theory (BQP and its relation to
  classical classes) and the adiabatic model.
- Ronald de Wolf, *Quantum Computing: Lecture Notes*, the sections on
  quantum complexity classes and on quantum supremacy/advantage claims.
- As with every day in this course, the theory below is self-contained: you
  do not need either text to do today's work, but they are useful for a
  second explanation in different words.
- This is also the terminal day of the plan: the exam below deliberately
  reuses results, notation, and worked examples established on Days
  1–14 (in particular Day 2's BPP/Chernoff material, and Days 13–14's
  $N=15,\,a=7$ factoring pipeline, whose $N=21$ counterpart is worked fresh
  below).

## Theory

### BQP: bounded-error quantum polynomial time

**BQP** (bounded-error quantum polynomial time) is the class of decision
problems (languages $L\subseteq\{0,1\}^*$) solvable by a uniformly
generated family of poly-size quantum circuits, built from a fixed
universal gate set, such that on every input $x$:
- if $x\in L$, the circuit's final measurement returns "accept" with
  probability $\ge 2/3$;
- if $x\notin L$, the circuit's final measurement returns "accept" with
  probability $\le 1/3$.

This is deliberately the exact same shape of definition as Day 2's $BPP$
(languages decided by a probabilistic poly-time algorithm with two-sided
error $\le 1/3$), with "probabilistic poly-time algorithm" replaced by
"poly-size quantum circuit family" and "coin flips" replaced by "quantum
measurement outcomes."

**Error amplification.** The constant $1/3$ in the definition is not
special — it can be replaced by any constant strictly less than $1/2$
without changing the class, by the *same* argument as Day 2 Step 3. Run the
circuit $k$ independent times (fresh ancillas/measurement each run) and take
the majority of the $k$ outcomes. Let $X_i$ be the indicator that run $i$ is
correct; the $X_i$ are i.i.d. Bernoulli-type random variables with
$\Pr[X_i=1]\ge 2/3$, exactly as in Day 2 — the Hoeffding/Chernoff bound used
there never assumed the underlying randomness was classical; it only used
independence and a constant gap between the trials' mean and $1/2$. So the
identical computation gives: majority vote is wrong with probability at
most $e^{-k/18}$ (worked in full in Model answer 2 below), driving the
error down to any inverse-exponentially small target with only a
polynomial (in the target precision) increase in circuit size — hence
amplification preserves membership in BQP (a poly-size circuit repeated a
polynomial number of times is still poly-size).

### The complexity landscape: $P\subseteq BPP\subseteq BQP\subseteq PSPACE$

**$P\subseteq BPP$** (established Day 2): a deterministic poly-time
algorithm is a probabilistic one that happens to use no randomness — it has
error $0\le 1/3$ on every input, so it already meets $BPP$'s error bound.

**$BPP\subseteq BQP$**: a classical randomized computation is a special
case of a quantum one. Concretely, given a $BPP$ algorithm, build a quantum
circuit that (a) prepares each random bit the classical algorithm would
have flipped by putting a fresh ancilla qubit through a Hadamard (or, for a
biased coin, an appropriate single-qubit rotation) and measuring it
immediately — reproducing exactly the classical probability distribution
over random strings the $BPP$ algorithm would have sampled — then (b)
simulates the algorithm's (WLOG reversible, by Day 1) classical logic using
Toffoli/CNOT gates embedded as quantum unitaries acting on basis states. No
step of this circuit ever uses superposition or entanglement beyond the
single-qubit randomness-generation step, so its output distribution is
*identical* to the classical algorithm's, and in particular its
acceptance probabilities meet the same $BPP$ error bound — hence the same
language is also in $BQP$. This containment is proven unconditionally.

**$BQP\subseteq PSPACE$**: A quantum circuit's final acceptance probability
is $\sum_{\text{accepting } y}|\langle y|U_T\cdots U_1|x\rangle|^2$, a sum
over exponentially many basis states $y$ of squared amplitudes, each of
which is itself, by expanding $U_T\cdots U_1$ as a product of the circuit's
poly-many gates, a sum over all *computational paths* — sequences of
intermediate basis states $z_1,\dots,z_{T-1}$ the circuit passes through —
of a product of $T$ matrix entries (one per gate). There are exponentially
many such paths, so evaluating this sum naively takes exponential *time*.
But it can be done in polynomial *space*: enumerate the exponentially many
paths one at a time (e.g. in lexicographic order, exactly as a
polynomial-space recursive enumeration would), compute each path's
contribution using only the poly-many bits needed to describe that one
path and a running total, add it into an accumulator, and discard the path
before moving to the next. At no point does this procedure need to hold
more than a polynomial amount of data in memory simultaneously — the
exponential blow-up shows up only in *how long* the enumeration takes, not
in how much space it occupies. Since $PSPACE$ places no bound on time, only
space, this puts the exact acceptance probability (and hence the decision
of whether it exceeds $1/2$) inside $PSPACE$. This containment, too, is
proven unconditionally.

**Open in the reverse direction.** Whether any of these containments is
*strict* is, in general, not resolved by the containment proofs themselves
(a containment proof shows $\subseteq$; it says nothing about $\subsetneq$
versus $=$). In particular:
- $P = BPP$ is a widely believed but unproven conjecture (motivated by
  derandomization results), so $P\subseteq BPP$ is not known to be strict.
- $BPP\subsetneq BQP$ is widely *believed* (Shor's algorithm is the
  headline candidate witness — integer factoring is in $BQP$ but not known
  to be in $BPP$), but proving $BQP\supsetneq BPP$ unconditionally is a
  major open problem: nobody has ruled out a not-yet-discovered classical
  algorithm putting factoring (or every other BQP problem) into $BPP$ after
  all.
- Whether $BQP\subseteq NP$ or $NP\subseteq BQP$ — in *either* direction —
  is a genuinely open problem. Grover's algorithm (Days 11–12) gives only a
  quadratic speedup for unstructured search, and BBBV proves that quadratic
  speedup is optimal for the *unstructured* case; this is consistent with,
  but does not prove, $NP\not\subseteq BQP$, since it says nothing about
  search problems with exploitable structure. No proof of either
  containment or non-containment exists.
- $BQP\subseteq PSPACE$ is proven; whether it is strict ($BQP\subsetneq
  PSPACE$) is also open, though believed true, since $PSPACE$ is believed
  to be a much larger class.

This is precisely the "beyond provable" boundary the module title points
at: several of the most basic relationships between these classes are
open problems in theoretical computer science today, not merely facts this
course omitted for time.

### The adiabatic model

The **adiabatic theorem** (informal statement): if a physical system's
Hamiltonian $H(t)$ is varied slowly enough, relative to the size of its
instantaneous spectral gap (the energy difference between its ground state
and the next excited state) at every point along the way, then a system
that starts in the ground state of $H(0)$ remains, to good approximation,
in the *instantaneous* ground state of $H(t)$ throughout the evolution —
ending, at $t=T$, in the ground state of $H(T)$.

**Adiabatic quantum computation** exploits this: prepare an easy
ground state of some simple initial Hamiltonian $H(0)$ (e.g. one whose
ground state is the uniform superposition over all basis states), then
slowly deform $H(t)$ from $H(0)$ to a final Hamiltonian $H(T)$ whose ground
state *encodes the solution* to the problem of interest (e.g. an
optimization problem, encoded so that low-energy states correspond to good
solutions). If the deformation is slow enough relative to the spectral gap
at every point of the path, the adiabatic theorem guarantees the system
ends (approximately) in $H(T)$'s ground state — read that off by
measurement and you have your answer. This is a fundamentally different
computational primitive from the discrete-time circuit model used
throughout the rest of this course: there is no sequence of discrete
gates, only a single continuously varying physical process.

The important fact for this course (stated without proof, as flagged in the
plan): **adiabatic quantum computation is known to be polynomially
equivalent to the discrete gate-circuit model** — each can simulate the
other with only a polynomial overhead in resources. So "beyond
discrete-time" names a different computational *model*, not a more
*powerful* one: nothing achievable adiabatically escapes BQP (up to
polynomial overhead), and nothing achievable in the circuit model is
unreachable adiabatically. Every complexity-theoretic statement made about
BQP above therefore applies equally to the adiabatic model.

### Quantum advantage / supremacy claims

A **quantum advantage** (or "quantum supremacy") experimental claim — the
canonical example being random-circuit sampling — asserts something
narrow and specific: *for this particular sampling task, run on this
particular quantum device, no currently known classical algorithm running
on current (or foreseeably scalable) classical hardware can reproduce
samples from the same output distribution in a comparable amount of time.*
This is an empirical/complexity-theoretic claim about the current frontier
of known classical algorithms and available classical compute, sometimes
additionally supported by complexity-theoretic evidence (e.g. hardness
results conditional on standard conjectures about the polynomial
hierarchy not collapsing).

What it does **not** assert is that $BQP\supsetneq BPP$ has been *proven*.
That containment being strict remains exactly the open problem stated
above — an experimental demonstration that today's classical algorithms
and hardware cannot keep up with a specific sampling task is not, and
cannot by itself be, a proof of an unconditional separation between
complexity classes; complexity classes are defined by what is
*possible in principle* for algorithms in the class, not by what happens
to be implemented on hand at a point in time. A future classical
algorithmic breakthrough (or even sufficiently large classical compute)
could in principle close the specific empirical gap being claimed, without
that touching the (much stronger, and unproven) statement $BQP\ne BPP$.

This is exactly the same distinction Day 2 Step 5 raised when asked to
turn "a quantum computer solved X faster than a classical laptop's
program" into a well-posed complexity statement: an informal
speed comparison between two specific implementations is not, by itself, a
statement about complexity classes. There, the fix was to restate the
claim in $P$/$BPP$ language ("no known/possible poly-time classical
algorithm solves X, while a poly-size quantum circuit does"). Here, the
same discipline applies to advantage claims: "no known classical algorithm
on today's hardware reproduces this sampling task efficiently" is a
well-posed, checkable, and already asserted claim; "no classical algorithm
that will *ever* be discovered can do this in poly time" is the
unconditional separation $BQP\ne BPP$, which nobody has proven.

### Two open problems

1. **Is $BQP=BPP$?** Nobody has proven a language separating the two
   classes (i.e. proven something is in $BQP$ but not $BPP$), despite
   strong evidence (Shor's algorithm) that this should be false.
2. **Could a future classical algorithm match Shor's performance for
   factoring?** It remains open whether integer factoring is actually
   outside $BPP$, or whether a not-yet-discovered classical algorithm could
   factor in probabilistic polynomial time, matching Shor's quantum
   performance and thereby placing factoring inside $BPP$ after all. (Note
   that factoring is *not* believed to be $NP$-complete either, so this is
   a separate question from $P$ vs $NP$.)

## Common misconceptions

- **"A quantum-advantage experiment proves $BQP$ is strictly bigger than
  $BPP$."** No. As explained above, an advantage claim is a statement about
  specific classical algorithms/hardware failing to keep pace with a
  specific sampling task; $BQP\supsetneq BPP$ is an unconditional statement
  about *all possible* classical algorithms and remains a formally open
  problem. Every advantage experiment to date is compatible with a future
  classical algorithm closing that particular gap without $BQP=BPP$ being
  false, and equally compatible with $BQP\ne BPP$ being eventually proven
  by entirely different means. The experiment is evidence, not proof, and
  is not even evidence of the *unconditional* statement — only of a
  claim about currently known algorithms.
- **"The adiabatic model is a fundamentally more powerful way to compute,
  since it's continuous rather than gate-by-gate."** No — it is a different
  primitive with the same power: adiabatic QC and the discrete circuit
  model are polynomially equivalent (stated above without proof). Any
  problem solvable efficiently adiabatically is solvable efficiently in the
  gate model too, and vice versa.
- **"BQP contains NP, so quantum computers can efficiently solve
  NP-complete problems like SAT."** Not known, and not believed by most
  researchers. No proof exists that $NP\subseteq BQP$ (nor of
  $NP\not\subseteq BQP$). The generic quadratic Grover speedup for
  unstructured search (Days 11–12) does not turn exponential brute-force
  search into polynomial time, and BBBV shows that speedup is optimal for
  the unstructured case — evidence against, but not a proof against,
  $NP\subseteq BQP$ for structured NP-complete problems.

## Final exam

Closed-book, ~2 hours suggested. Attempt every problem before consulting
the Model answers section below.

1. Prove that Toffoli gates together with constant ancilla bits are
   universal for reversible classical computation.
2. State the definition of BPP, and prove that repeating a BPP algorithm
   $k$ times independently and taking the majority vote drives the error
   probability down to $e^{-ck}$ for an explicit constant $c>0$, via the
   Chernoff/Hoeffding bound.
3. State and prove the spectral theorem for normal operators in the
   $2\times2$ case, and use it (together with the defining algebraic
   properties of the Pauli matrices) to derive the eigenvalues and
   eigenvectors of $X$, $Y$, and $Z$.
4. For $|\psi\rangle = \frac35|0\rangle + \frac{4i}{5}|1\rangle$, compute the
   Born-rule measurement probabilities in the standard basis
   $\{|0\rangle,|1\rangle\}$ and in the Hadamard basis
   $\{|+\rangle,|-\rangle\}$. Separately, prove that the density matrix
   $\rho=|\psi\rangle\langle\psi|$ of any normalized pure state is rank 1.
5. Prove the no-cloning theorem: no unitary $U$ can satisfy
   $U(|\psi\rangle\otimes|0\rangle) = |\psi\rangle\otimes|\psi\rangle$ for
   every single-qubit state $|\psi\rangle$.
6. Derive the general-$n$ Deutsch–Jozsa amplitude formula for the
   all-zeros outcome, and prove it distinguishes constant from balanced
   functions with certainty after a single oracle query.
7. Derive the exact Bernstein–Vazirani result
   $H^{\otimes n}\!\left[\frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}|x\rangle\right]
   = |a\rangle$ from scratch.
8. Derive Grover's rotation angle $\theta$ and the optimal iteration count
   for $N=16$, $M=1$, and state the BBBV lower bound on the number of
   oracle queries needed for unstructured search.
9. For $N=21$ (a new example — do not reuse $N=15$): choose a value $a$
   coprime to $21$, find its multiplicative order $r$ modulo $21$ by hand,
   and — assuming a Quantum Phase Estimation run returned a phase estimate
   near $k/r$ for some integer $k$ — walk through the full Shor's pipeline
   (continued fractions recovering $r$, then Miller's reduction) to a
   nontrivial factor of $21$.
10. State the containments $P\subseteq BPP\subseteq BQP\subseteq PSPACE$.
    For each, briefly justify why it holds, and state explicitly which
    containments (if any) are known to be strict versus open in the
    reverse direction.

## Model answers

### 1. Toffoli universality

**Reversibility.** A gate on $n$ bits is reversible iff its function
$\{0,1\}^n\to\{0,1\}^n$ is a bijection. Toffoli$(a,b,c) = (a,b,c\oplus(a\wedge
b))$ is its own inverse: applying it twice gives $c'' = c\oplus(a\wedge
b)\oplus(a\wedge b) = c$ (using $x\oplus x=0$), with $a,b$ untouched — so it
is a bijection, hence reversible. The same cancellation shows CNOT$(a,b) =
(a, a\oplus b)$ is its own inverse too.

**AND.** Toffoli$(a,b,0) = (a,b,0\oplus(a\wedge b)) = (a,b,a\wedge b)$: feeding
a fresh ancilla fixed at $0$ as the target realizes AND reversibly, with
$a,b$ passed through unchanged.

**NOT.** Toffoli$(1,1,c) = (1,1,c\oplus(1\wedge1)) = (1,1,c\oplus1) =
(1,1,\neg c)$: fixing both controls to the constant $1$ turns the target
line's update into an unconditional flip, i.e. NOT.

**OR.** By De Morgan's law, $a\vee b = \neg(\neg a\wedge\neg b)$. Compute
$\neg a,\neg b$ via the NOT construction (routed to fresh ancilla lines to
preserve $a,b$), AND them via the AND construction, then NOT the result —
all built from Toffoli gates and constant ancillas.

**General universality.** Claim: any classical circuit with $g$ AND/OR/NOT
gates can be converted into a reversible circuit using $O(g)$ Toffoli gates
and $O(g)$ fresh ancilla bits. Proof by induction on $g$. Base case $g=0$:
the empty circuit is the identity, trivially reversible. Inductive step:
suppose the first $g-1$ gates have already been converted into a reversible
circuit using $O(g-1)$ Toffolis/ancillas (inductive hypothesis). The $g$-th
gate is AND, OR, or NOT applied to existing wires; by the three
constructions above, it is realized with $O(1)$ additional Toffoli gates
and $O(1)$ additional fresh ancillas, feeding from the existing wires and
producing one new (plus $O(1)$ garbage) output wire. Appending this $O(1)$
gadget to the already-reversible prefix circuit keeps the whole circuit
reversible, because a composition of bijections is a bijection. Total cost:
$O(g-1)+O(1) = O(g)$ Toffolis and ancillas. $\blacksquare$

Every intermediate value produced along the way (e.g. the AND-results fed
into an OR construction) must be *kept*, not overwritten, as garbage output
— this is what makes the whole circuit, garbage included, a bijection.

### 2. BPP and Chernoff error amplification

**Definition.** $BPP$ is the class of languages $L$ decidable by a
probabilistic polynomial-time algorithm $A$ such that for every input $x$,
$\Pr[A(x) = \mathbb{1}[x\in L]] \ge 2/3$ (equivalently: two-sided error
$\le1/3$).

**Amplification.** Run $A$ on the same input $x$, $k$ times independently,
and output the majority answer. Let $X_i$ be the indicator that run $i$ is
correct, so $X_1,\dots,X_k$ are i.i.d. $\{0,1\}$-valued with $p:=\Pr[X_i=1]
\ge 2/3$. Let $S=\sum_{i=1}^k X_i$, so $\mu:=\mathbb E[S]=kp\ge \frac{2k}{3}$.
The majority vote is wrong exactly when $S\le k/2$ (fewer than half the
runs were correct).

By Hoeffding's inequality, for i.i.d. $[0,1]$-valued random variables,
$$\Pr[S \le \mu - t] \le e^{-2t^2/k}\quad\text{for any } t>0.$$
Take $t = \mu - k/2 \ge \frac{2k}{3}-\frac{k}{2} = \frac{k}{6}$ (using
$\mu\ge 2k/3$). Then
$$\Pr[S\le k/2] \le \Pr[S \le \mu - k/6] \le e^{-2(k/6)^2/k} = e^{-2k/36} =
e^{-k/18}.$$
So the majority-vote error probability is at most $e^{-ck}$ with
$c=\frac{1}{18}$, an explicit constant.

**Driving the error below $2^{-20}$.** We need $e^{-k/18} < 2^{-20}$, i.e.
$k/18 > 20\ln2$, i.e. $k > 360\ln2 \approx 249.5$. So $k=250$ independent
repetitions suffice.

### 3. Spectral theorem (2×2 case) and Pauli eigenstructure

**Statement.** A matrix $A$ is normal ($AA^\dagger = A^\dagger A$) iff $A =
UDU^\dagger$ for some unitary $U$ and diagonal $D$ — i.e. $A$ has an
orthonormal eigenbasis.

**Proof, $2\times2$ case.** Let $A$ be a normal $2\times2$ matrix. By the
fundamental theorem of algebra, $A$ has an eigenvalue $\lambda_1$ with a
unit eigenvector $v_1$. Let $v_2$ be any unit vector orthogonal to $v_1$
(exists in $\mathbb C^2$); $\{v_1,v_2\}$ is an orthonormal basis. In this
basis, since $Av_1=\lambda_1 v_1$, $A$'s matrix takes the upper-triangular
form
$$M = \begin{pmatrix}\lambda_1 & b\\ 0 & d\end{pmatrix}.$$
Compute both products:
$$MM^\dagger = \begin{pmatrix}|\lambda_1|^2+|b|^2 & bd^*\\ db^* & |d|^2
\end{pmatrix}, \qquad M^\dagger M = \begin{pmatrix}|\lambda_1|^2 &
\lambda_1^* b\\ b^*\lambda_1 & |b|^2+|d|^2\end{pmatrix}.$$
Normality forces $MM^\dagger = M^\dagger M$; comparing the $(1,1)$ entries
gives $|\lambda_1|^2+|b|^2 = |\lambda_1|^2$, so $b=0$. Hence $M =
\mathrm{diag}(\lambda_1,d)$ is already diagonal in the $\{v_1,v_2\}$ basis,
with $v_1,v_2$ orthonormal eigenvectors. Setting $U=(v_1\mid v_2)$ gives
$A=UDU^\dagger$ with $D=\mathrm{diag}(\lambda_1,d)$. $\blacksquare$

**Pauli eigenstructure.** $X,Y,Z$ are each Hermitian ($X^\dagger=X$ etc.)
and unitary, hence normal, hence diagonalizable in an orthonormal basis by
the theorem above. Each is also an involution ($X^2=Y^2=Z^2=I$, checked
directly from the matrices), so any eigenvalue $\lambda$ satisfies
$\lambda^2=1$, giving $\lambda=\pm1$ (consistent with Hermiticity, which
guarantees real eigenvalues).

- $Z=\begin{pmatrix}1&0\\0&-1\end{pmatrix}$ is already diagonal:
  eigenvalue $+1$ with eigenvector $|0\rangle=(1,0)^T$; eigenvalue $-1$ with
  eigenvector $|1\rangle=(0,1)^T$.
- $X=\begin{pmatrix}0&1\\1&0\end{pmatrix}$: $X(1,1)^T=(1,1)^T$, so eigenvalue
  $+1$ with eigenvector $|+\rangle=\frac{1}{\sqrt2}(1,1)^T$; $X(1,-1)^T =
  (-1,1)^T = -1\cdot(1,-1)^T$, so eigenvalue $-1$ with eigenvector
  $|-\rangle=\frac{1}{\sqrt2}(1,-1)^T$.
- $Y=\begin{pmatrix}0&-i\\i&0\end{pmatrix}$: $Y(1,i)^T = (-i\cdot i,\ i\cdot1)^T
  = (1,i)^T$, so eigenvalue $+1$ with eigenvector $\frac{1}{\sqrt2}(1,i)^T$;
  $Y(1,-i)^T = (-i\cdot(-i),\ i\cdot1)^T = (-1,i)^T = -1\cdot(1,-i)^T$, so
  eigenvalue $-1$ with eigenvector $\frac{1}{\sqrt2}(1,-i)^T$.

### 4. Born rule in two bases; pure-state density matrix is rank 1

**Standard basis.** For $|\psi\rangle=\frac35|0\rangle+\frac{4i}{5}|1\rangle$:
$$\Pr[0] = \left|\tfrac35\right|^2 = \tfrac{9}{25},\qquad
\Pr[1] = \left|\tfrac{4i}{5}\right|^2 = \tfrac{16}{25},\qquad
\tfrac{9}{25}+\tfrac{16}{25}=1.$$

**Hadamard basis.** $|+\rangle=\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$,
$|-\rangle=\frac{1}{\sqrt2}(|0\rangle-|1\rangle)$.
$$\langle+|\psi\rangle = \tfrac{1}{\sqrt2}\left(\tfrac35+\tfrac{4i}{5}\right)
= \tfrac{3+4i}{5\sqrt2},\qquad
|\langle+|\psi\rangle|^2 = \frac{9+16}{25\cdot2} = \frac{25}{50}=\frac12.$$
$$\langle-|\psi\rangle = \tfrac{1}{\sqrt2}\left(\tfrac35-\tfrac{4i}{5}\right)
= \tfrac{3-4i}{5\sqrt2},\qquad
|\langle-|\psi\rangle|^2 = \frac{9+16}{50}=\frac12.$$
Both sum to $1$, but the outcome distribution ($9/25$ vs. $16/25$
standard-basis, exactly $1/2$ vs. $1/2$ Hadamard-basis) is completely
different for the *same* physical state — measurement statistics are
basis-dependent.

**Rank-1 proof.** Let $\rho=|\psi\rangle\langle\psi|$ for normalized
$|\psi\rangle$. First, $\rho^\dagger = (|\psi\rangle\langle\psi|)^\dagger =
|\psi\rangle\langle\psi| = \rho$ (Hermitian), $\mathrm{Tr}(\rho) =
\langle\psi|\psi\rangle = 1$, and for any $|\phi\rangle$,
$\langle\phi|\rho|\phi\rangle = |\langle\psi|\phi\rangle|^2\ge0$ (positive
semidefinite). Now for eigenstructure: $\rho|\psi\rangle =
|\psi\rangle\langle\psi|\psi\rangle = |\psi\rangle$ (using
$\langle\psi|\psi\rangle=1$), so $|\psi\rangle$ is an eigenvector with
eigenvalue $1$. For any $|\phi\rangle$ orthogonal to $|\psi\rangle$
($\langle\psi|\phi\rangle=0$), $\rho|\phi\rangle = |\psi\rangle\langle
\psi|\phi\rangle = 0$, an eigenvector with eigenvalue $0$. Since the whole
space decomposes as $\mathrm{span}\{|\psi\rangle\}\oplus
\{|\psi\rangle\}^\perp$ and $\rho$ acts as the identity on the first
(1-dimensional) piece and as zero on the second, $\rho$ has exactly one
nonzero eigenvalue ($1$), with multiplicity $1$ — i.e. $\rho$ is rank $1$.
$\blacksquare$ (A mixed state's density matrix, by contrast, has more than
one nonzero eigenvalue.)

### 5. No-cloning theorem

Suppose, for contradiction, a unitary $U$ exists with $U(|\psi\rangle\otimes
|0\rangle) = |\psi\rangle\otimes|\psi\rangle$ for *every* single-qubit
$|\psi\rangle$. Apply this to the two basis states:
$$U(|0\rangle\otimes|0\rangle) = |0\rangle\otimes|0\rangle,\qquad
U(|1\rangle\otimes|0\rangle) = |1\rangle\otimes|1\rangle.$$
Now consider $|+\rangle = \frac{1}{\sqrt2}(|0\rangle+|1\rangle)$. By
*linearity* of $U$,
$$U(|+\rangle\otimes|0\rangle) = \frac{1}{\sqrt2}\Big[U(|0\rangle\otimes
|0\rangle) + U(|1\rangle\otimes|0\rangle)\Big] = \frac{1}{\sqrt2}\big(
|00\rangle + |11\rangle\big).$$
But the cloning assumption, applied directly to $|\psi\rangle=|+\rangle$,
requires
$$U(|+\rangle\otimes|0\rangle) = |+\rangle\otimes|+\rangle =
\frac12\big(|00\rangle+|01\rangle+|10\rangle+|11\rangle\big).$$
These two results are different states
($\frac{1}{\sqrt2}(|00\rangle+|11\rangle)$ is an entangled Bell state, not
equal to the separable, uniformly-weighted $\frac12(|00\rangle+|01\rangle+
|10\rangle+|11\rangle)$) — a contradiction. Hence no unitary $U$ cloning
every single-qubit state can exist. $\blacksquare$

### 6. Deutsch–Jozsa, general $n$

Circuit: registers start at $|0\rangle^{\otimes n}|1\rangle$. Apply
$H^{\otimes n}$ to the first register and $H$ to the second
($H|1\rangle=|-\rangle$), giving $\frac{1}{\sqrt{2^n}}\sum_x
|x\rangle\otimes|-\rangle$. The oracle acts by phase kickback (Day 8):
$U_f|x\rangle|-\rangle = (-1)^{f(x)}|x\rangle|-\rangle$, giving
$\frac{1}{\sqrt{2^n}}\sum_x(-1)^{f(x)}|x\rangle\otimes|-\rangle$. Apply
$H^{\otimes n}$ again to the first register, using $H^{\otimes n}|x\rangle =
\frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle$:
$$\frac{1}{2^n}\sum_x\sum_y(-1)^{f(x)}(-1)^{x\cdot y}|y\rangle =
\sum_y\left[\frac{1}{2^n}\sum_x(-1)^{f(x)+x\cdot y}\right]|y\rangle.$$
The amplitude on $y=0^n$ (where $x\cdot y=0$ for all $x$) is
$$\alpha_0 = \frac{1}{2^n}\sum_x(-1)^{f(x)}.$$
- If $f$ is constant ($f\equiv0$ or $f\equiv1$), every term in the sum has
  the same sign, so $\alpha_0 = \pm\frac{2^n}{2^n} = \pm1$: measuring $y=0^n$
  is certain.
- If $f$ is balanced (exactly half the $2^n$ inputs give $f(x)=1$), the sum
  has $2^{n-1}$ terms of $+1$ and $2^{n-1}$ of $-1$, so $\alpha_0 =
  \frac{2^{n-1}-2^{n-1}}{2^n} = 0$: measuring $y=0^n$ has probability exactly
  $0$.

Since these two cases give disjoint, deterministic outcomes on the $y=0^n$
measurement, a single oracle query distinguishes constant from balanced
with certainty (zero error) — versus the classical randomized algorithm of
Day 2, which needs $k$ queries for confidence $1-2^{-k}$ and never reaches
certainty with any fixed finite number of queries.

### 7. Bernstein–Vazirani, exact derivation

Start from $\frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}|x\rangle$ (this is the
state produced, exactly as in Deutsch–Jozsa, by preparing
$H^{\otimes n}|0\rangle^{\otimes n}$ and applying the phase-kickback oracle
for $f(x)=a\cdot x\bmod2$). Apply $H^{\otimes n}$:
$$H^{\otimes n}\left[\frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}|x\rangle\right]
= \frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}\cdot\frac{1}{\sqrt{2^n}}\sum_y
(-1)^{x\cdot y}|y\rangle = \frac{1}{2^n}\sum_y\left[\sum_x(-1)^{x\cdot(a\oplus
y)}\right]|y\rangle.$$
**Character-sum lemma:** for $z\in\{0,1\}^n$, $\sum_{x\in\{0,1\}^n}
(-1)^{x\cdot z} = 2^n$ if $z=0^n$, and $=0$ otherwise. *Proof:* if $z=0^n$,
every term is $1$ and the sum is $2^n$. If $z\ne0^n$, pick an index $i$ with
$z_i=1$; pairing each $x$ with $x\oplus e_i$ (flipping bit $i$) gives
$(-1)^{(x\oplus e_i)\cdot z} = (-1)^{x\cdot z}(-1)^{z_i} = -(-1)^{x\cdot z}$,
so the two paired terms cancel; summing over all such pairs gives $0$.

Applying the lemma with $z=a\oplus y$: the inner sum is $2^n$ exactly when
$a\oplus y = 0^n$, i.e. $y=a$, and $0$ for every other $y$. So the outer sum
collapses to a single term:
$$\frac{1}{2^n}\cdot2^n\,|a\rangle = |a\rangle.$$
Hence $H^{\otimes n}\!\left[\frac{1}{\sqrt{2^n}}\sum_x(-1)^{a\cdot x}
|x\rangle\right] = |a\rangle$ exactly — measuring gives $a$ with probability
$1$, in a single oracle query, versus $n$ queries classically.

### 8. Grover's angle, optimal iteration count, BBBV

**Setup.** $|good\rangle$/$|bad\rangle$ span the 2D real subspace
containing the uniform start state $|s\rangle = \cos(\theta/2)|bad\rangle +
\sin(\theta/2)|good\rangle$, where $\sin(\theta/2)=\sqrt{M/N}$, i.e.
$\theta = 2\arcsin\sqrt{M/N}$.

**Rotation.** The oracle reflection $O_f$ reflects about $|bad\rangle$; the
diffusion operator $D=2|s\rangle\langle s|-I$ reflects about $|s\rangle$,
which sits at angle $\theta/2$ from $|bad\rangle$. Composing two
reflections about lines separated by angle $\alpha$ gives a rotation by
$2\alpha$; here $\alpha=\theta/2$, so $D\cdot O_f$ rotates by $\theta$
toward $|good\rangle$ on every application. After $k$ applications,
starting at angle $\theta/2$ from $|bad\rangle$, the state sits at angle
$\frac{(2k+1)\theta}{2}$ from $|bad\rangle$, so the probability of measuring
a good state is $\sin^2\!\left(\frac{(2k+1)\theta}{2}\right)$.

**$N=16,M=1$.** $\theta = 2\arcsin(1/4) \approx 2(0.25268) = 0.50536$ rad.
This probability is maximized (over real $k$) when $\frac{(2k+1)\theta}{2}=
\frac\pi2$, i.e. $k^\* = \frac{\pi}{2\theta}-\frac12 \approx
\frac{3.14159}{1.01072}-0.5 \approx 2.61$. Checking the two nearest
integers directly:
- $k=2$: angle $=\frac{5\theta}{2}\approx1.2634$ rad, $\sin^2\approx0.908$.
- $k=3$: angle $=\frac{7\theta}{2}\approx1.7688$ rad, $\sin^2\approx0.962$.
- $k=4$: angle $=\frac{9\theta}{2}\approx2.2741$ rad, $\sin^2\approx0.582$.

So the optimal integer iteration count is $k=3$, matching the standard
heuristic $k\approx\frac\pi4\sqrt{N/M} = \frac\pi4\cdot4 = \pi\approx3.14$.

**BBBV lower bound.** Any quantum algorithm making $T$ oracle queries to an
unstructured search oracle over $N$ items with a unique marked item
succeeds with probability $O(T^2/N)$; hence a success probability bounded
away from $0$ forces $T=\Omega(\sqrt N)$ queries. Grover's algorithm
achieves $O(\sqrt N)$, so it is optimal up to constant factors.

### 9. Shor's pipeline for $N=21$

**Choosing $a$.** Take $a=2$. Since $21=3\times7$ and $\gcd(2,21)=1$, $a=2$
is a valid choice.

**Order-finding by hand.** Compute powers of $2$ mod $21$:
$$2^1=2,\quad 2^2=4,\quad 2^3=8,\quad 2^4=16,\quad 2^5=32\bmod21=11,\quad
2^6=64\bmod21=1.$$
The order is $r=6$ (first exponent returning to $1$). Sanity check:
$\varphi(21)=\varphi(3)\varphi(7)=2\times6=12$, and $6\mid12$. ✓.

**Continued fractions (from an assumed QPE output).** Suppose a QPE run
returns a phase estimate $\varphi\approx k/r$ for some integer $k$; take, for
concreteness, $k=1$, so $\varphi\approx1/6\approx0.1667$. The continued
fraction expansion of $0.1667$: integer part $0$, remainder $0.1667$;
reciprocal of the remainder is $\approx6.0$, integer part $6$, remainder
$\approx0$. So the expansion terminates at $[0;6] = 1/6$, recovering
denominator (candidate order) $r=6$ — matching the brute-force value found
above exactly.

**Miller's reduction.** $r=6$ is even. Compute $a^{r/2}\bmod N = 2^3\bmod21
= 8$. Check the non-degeneracy condition: is $8\equiv-1\pmod{21}$, i.e.
$8\equiv20\pmod{21}$? No — $8\ne20$, so Miller's condition holds and we may
proceed. Compute
$$\gcd(a^{r/2}-1,\ N) = \gcd(8-1,\ 21) = \gcd(7,21) = 7.$$
$7$ is a nontrivial factor of $21$ ($1<7<21$), giving the factorization
$21 = 7\times3$.

**Why this works (Day 13's proof, applied here).** $a^r\equiv1\pmod N
\Rightarrow (a^{r/2}-1)(a^{r/2}+1)\equiv0\pmod N$. Since $r=6$ is the
*smallest* exponent with $2^r\equiv1\pmod{21}$, $2^{3}=8\ne1$, so $N\nmid
(a^{r/2}-1)$; and we checked directly $a^{r/2}=8\not\equiv-1\equiv20\pmod
{21}$, so $N\nmid(a^{r/2}+1)$ either. Since $N$ divides the product of the
two factors but divides neither factor outright, $N$'s prime factors must
be split between $(a^{r/2}-1)$ and $(a^{r/2}+1)$ — so $\gcd(a^{r/2}-1,N)$ is
a nontrivial divisor of $N$. Here that gcd is exactly $7$.

### 10. $P\subseteq BPP\subseteq BQP\subseteq PSPACE$

- $P\subseteq BPP$: a deterministic poly-time algorithm has error $0$,
  trivially meeting $BPP$'s $\le1/3$ bound. **Proven.**
- $BPP\subseteq BQP$: any classical randomized poly-time computation can be
  simulated by a quantum circuit that generates the same random bits via
  measured Hadamards (or biased rotations) and simulates the reversible
  classical logic (Day 1) via unitary gates on basis states, reproducing an
  identical output distribution. **Proven.**
- $BQP\subseteq PSPACE$: a quantum circuit's acceptance probability can be
  computed exactly via a path-sum over intermediate basis states, using
  exponential time but only polynomial space (paths are enumerated and
  discarded one at a time, never held simultaneously). **Proven.**

None of these three containments is known to be strict in the reverse
direction: $P=BPP$ is conjectured but open; $BQP\supsetneq BPP$ is believed
(Shor's algorithm as evidence) but unproven — no problem has been
unconditionally shown to be in $BQP\setminus BPP$; and $BQP\subsetneq
PSPACE$ is believed but likewise unproven. Additionally, whether
$BQP\subseteq NP$ or $NP\subseteq BQP$ is open in *either* direction — $NP$
does not appear anywhere in the proven chain above, and no containment
between $BQP$ and $NP$ has been established.

## Gap analysis

Grade every Step-5-style answer above (or, if you are working through this
as your own exam, your own written answers) against the corresponding
day's notes file:

| Exam problem | Traces back to |
|---|---|
| 1 | `notes/day01_boolean_reversible.md` |
| 2 | `notes/day02_complexity_randomized.md` |
| 3 | `notes/day03_complex_vector_spaces.md`, `notes/day04_normal_matrices_bloch.md` |
| 4 | `notes/day06_measurement_density_matrices.md` |
| 5 | `notes/day07_multiqubit_entanglement.md` |
| 6 | `notes/day08_deutsch_jozsa.md` |
| 7 | `notes/day10_bernstein_vazirani_simon.md` |
| 8 | `notes/day11_grovers.md`, `notes/day12_grover_optimality.md` |
| 9 | `notes/day13_number_theory_qft.md`, `notes/day14_qpe_shors.md` |
| 10 | `notes/day15_beyond_and_exam.md` |

For every problem that came out wrong, incomplete, or took noticeably
longer than it should have:
1. Identify which day it traces back to, using the table above.
2. Re-open that day's notes file and compare, line by line, where your
   closed-book attempt diverged — a mismatched definition, a forgotten
   step, an arithmetic slip, a skipped case, or a genuinely missing
   argument.
3. Re-derive that day's core result from scratch, closed-book, right now —
   do not just re-read the correct version. Write the fresh derivation
   immediately below your original exam attempt in
   `notes/day15_beyond_and_exam.md`, without erasing the original attempt
   (the gap itself is useful data, exactly as in the Day 5 and Day 9 review
   days).
4. Only once every problem has either been confirmed solid on the first
   attempt, or successfully re-derived from scratch after review, should
   the 15-day plan be considered complete.

Append a final entry to `journal.md` summarizing, across all 15 days,
which modules are solid and which need continued practice as the
module's actual lectures/coursework proceed — this is the plan's exit
criterion, not a fixed score.

## Journal template

```
## Day 15 — Beyond discrete-time quantum computing & final exam
Key idea in my own words: ...
What confused me: ...
Exam problems solid on first attempt: ...
Exam problems that needed a from-scratch re-derivation (Step 6), and why
each one slipped: ...
Modules I consider solid heading into the real course: ...
Modules I need continued practice on: ...
Overall course-completion note: ...
```
