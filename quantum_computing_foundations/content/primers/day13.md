# Before You Read Day 13: Number Theory for Shor's Algorithm & the QFT

## Warm-up

Three prior days feed directly into today. In Day 3 you built the mechanics of
complex inner products, established that unitary matrices are exactly those that
preserve norms, and observed that eigenvalues of unitaries must live on the unit
circle in the complex plane. That machinery is why the QFT — a unitary — can be
specified by its action on basis states and automatically extended to arbitrary
superpositions without any additional checking.

In Day 8 you met the Hadamard transform as a concrete unitary: $H$ on one qubit
maps $|0\rangle$ to $\frac{1}{\sqrt2}(|0\rangle+|1\rangle)$, and $H^{\otimes n}$
applied to $|0\rangle^{\otimes n}$ creates the uniform superposition over all
$n$-bit strings. You used this in Deutsch–Jozsa to query all inputs simultaneously,
and noted that a second application of $H^{\otimes n}$ undoes the first —
a self-inverse transform whose unitarity you could verify directly from the
inner-product machinery of Day 3.

In Day 10 you saw the same Hadamard structure powering Bernstein–Vazirani and
Simon's algorithm: applying $H^{\otimes n}$ to a superposition that has been
phase-kicked by a hidden function concentrates amplitude onto the hidden label.
This is Fourier analysis at work — the transform converts a phase pattern into a
position pattern. Today's QFT does exactly the same thing for a richer group
structure, and the continued-fraction algorithm that follows it is how you read
the order back out of a noisy quantum measurement.

## The hook

Pick $N=15$ and base $a=7$. Raise $7$ to successive powers mod $15$: $7^1=7$,
$7^2=49\equiv4$, $7^3=7\cdot4=28\equiv13$, $7^4=7\cdot13=91\equiv1$. The first
power that returns to $1$ is the fourth, so the order is $r=4$. Because $r$ is
even, Miller's reduction applies: form $7^{r/2}-1=7^2-1=48$, then compute
$\gcd(48,15)$. One Euclidean step gives $48=3\cdot15+3$, so $\gcd(48,15)=
\gcd(15,3)=\gcd(3,15)=3$. And $15/3=5$: both prime factors recovered from a
single order-finding result plus one gcd.

The algebra is the difference-of-squares identity: $a^r-1=(a^{r/2}-1)(a^{r/2}+1)$.
Since $a^r\equiv1\pmod N$, the composite $N$ divides the product. But $N$ divides
neither factor alone — minimality of $r$ blocks the first, and the hypothesis
$a^{r/2}\not\equiv-1$ blocks the second. So $N$'s prime factors must split between
the two terms, and the gcd captures whichever piece lands on the $a^{r/2}-1$ side.
That is all there is to Miller's reduction: a short algebraic argument that turns
an order into a factor in three lines. Everything hard — finding $r$ in the first
place — is delegated to the quantum subroutine, whose design you will trace in
Day 14.

## The pictures

The first picture to hold in mind is the factoring pipeline as a flowchart. You
start with a random base $a$ coprime to $N$ and feed it into an order-finding
subroutine. That subroutine returns an integer $r$. You then check two classical
conditions — is $r$ even, and is $a^{r/2}\not\equiv-1\pmod N$ — and, if both
hold, compute $\gcd(a^{r/2}-1,N)$ to read off a nontrivial factor. The quantum
subroutine is a single highlighted box inside an otherwise classical procedure;
all the exponential hardness is concentrated in that box, and the classical shell
around it runs in polynomial time.

The second picture is the QFT as a quantum Fourier series. Imagine the input
register storing amplitudes across the computational-basis states $|0\rangle$
through $|N-1\rangle$. The QFT remaps each basis label $x$ to a frequency label
$y$ by the kernel $\omega^{xy}$, where $\omega=e^{2\pi i/N}$ is a primitive $N$-th
root of unity. The output amplitude at label $y$ measures how strongly the input
superposition oscillates at frequency $y$, exactly as in a classical Discrete
Fourier Transform — the difference is that the DFT acts on a vector of numbers
while the QFT acts coherently on a superposition, enabling quantum interference
to extract dominant frequencies in logarithmic depth.

The third picture is the continued-fraction ladder. Given a decimal like $0.6247$
that you believe is close to some exact ratio $k/r$ with small $r$, the ladder
operates by peeling off the integer part, inverting the fractional remainder to
get a new number greater than $1$, and repeating. Each step produces a convergent
$p_n/q_n$ — a fraction in lowest terms that is the best rational approximation to
your decimal at its denominator size. You descend the ladder until the denominator
would exceed your known bound on $r$, then back up one step: that last convergent
is the exact ratio you were looking for, provided the initial decimal was close
enough.

## Concrete-first walkthrough

Open ### Modular arithmetic and the order of an element and fix the definition
before anything else: the order of $a$ mod $N$ is the smallest positive $r$ with
$a^r\equiv1\pmod N$. The existence argument is brief — the sequence $a^1,a^2,\ldots$
lives in the finite group $\mathbb{Z}_N^*$, so it must eventually cycle, and the
first return to $1$ defines $r$. Euler's theorem ($a^{\varphi(N)}\equiv1\pmod N$)
gives the upper bound $r\mid\varphi(N)$, so brute-force search only needs to check
divisors of $\varphi(N)$.

Move to ### Miller's reduction: from order to factor and read the **Claim.**
statement at the top: even order $r$, base $a$ satisfying $a^{r/2}\not\equiv-1
\pmod N$, and the conclusion that $\gcd(a^{r/2}-1,N)$ lies strictly between $1$
and $N$. Before reading the proof, work the $N=15$, $a=7$ example from The hook:
$r=4$, $7^2-1=48$, $\gcd(48,15)=3$. Then read the proof to see exactly which
two non-divisibility facts force the gcd to be nontrivial.

In ### The Quantum Fourier Transform, the central formula is the action
$\text{QFT}|x\rangle = \frac{1}{\sqrt N}\sum_{y=0}^{N-1}\omega^{xy}|y\rangle$
with $\omega=e^{2\pi i/N}$. The section establishes unitarity via the geometric-sum
identity for roots of unity. The matrix $M$ has entries $M_{yx}=\omega^{xy}/\sqrt N$
and is symmetric (since $\omega^{xy}=\omega^{yx}$), a symmetry that simplifies the
unitarity check considerably. Absorb the definition first, then follow the column
orthonormality argument.

### Deriving the $N=4$ matrix explicitly is a worked computation you should shadow
with a pencil. For $N=4$, $\omega=e^{2\pi i/4}=i$, so every entry is $i^{xy}/2$
for $x,y\in\{0,1,2,3\}$. The four powers of $i$ cycle as $1,i,-1,-i$; filling in
the $4\times4$ table of $xy\bmod4$ gives the explicit matrix. Copy it down and
multiply one pair of distinct columns by hand to verify orthogonality before
moving on.

In ### Reducing to the Hadamard transform on $(\mathbb{Z}_2)^n$, the key insight
is group-theoretic: $H^{\otimes n}$ is the Fourier transform for $(\mathbb{Z}_2)^n$
(bitwise XOR), and the cyclic QFT is the Fourier transform for $\mathbb{Z}_{2^n}$
(addition mod $2^n$). For $n=1$ the groups coincide and the transforms agree; for
$n\ge2$ they diverge. At $n=2$, $H\otimes H$ has only real entries $(\pm1/2)$
while $\text{QFT}_4$ has imaginary entries $(\pm i/2)$ — compare them directly on
paper before reading the tensor-product argument.

### Continued fractions introduces the floor-and-invert recurrence $a_i=\lfloor
x_i\rfloor$, $x_{i+1}=1/(x_i-a_i)$ and the two-term convergent recurrence
$p_n=a_np_{n-1}+p_{n-2}$, $q_n=a_nq_{n-1}+q_{n-2}$. Trace Exercise 7 on scratch
paper ($x_0=0.6247$) and notice how the denominator stays small for five steps
then jumps at $a_6=51$. The precision condition $|\varphi_{\text{meas}}-k/r|<
1/(2r^2)$ is the QPE guarantee that the measured phase is close enough for the
last convergent within the bound on $r$ to equal $k/r$ exactly.

## Derivation roadmaps

For Miller's reduction, the key trick is the factored form: $a^r-1=(a^{r/2}-1)
(a^{r/2}+1)$, and since $a^r\equiv1\pmod N$, the composite $N$ divides the
product. Two non-divisibility facts follow — minimality of $r$ blocks
$N\mid(a^{r/2}-1)$, and the stated hypothesis blocks $N\mid(a^{r/2}+1)$ — so
$N$'s prime factors must split between the two terms. To fill in from scratch:
argue that $d=\gcd(a^{r/2}-1,N)$ cannot be $1$ (all of $N$'s prime factors
landing on the $a^{r/2}+1$ side would mean $N\mid a^{r/2}+1$, a direct
contradiction) and cannot be $N$ (that would mean $N\mid a^{r/2}-1$, contradicting
minimality of $r$). The **Claim.** and its proof in ### Miller's reduction: from
order to factor work through this skeleton in full.

For QFT unitarity, the key trick is the geometric-sum identity:
$\sum_{x=0}^{N-1}\omega^{x(y-y')}=N\cdot\mathbf{1}[y=y']$. When $y\ne y'$,
$\omega^{y-y'}$ is a nontrivial $N$-th root of unity; the geometric series with
ratio $z=\omega^{y-y'}\ne1$ and $N$ terms evaluates to $(z^N-1)/(z-1)=0$. To
fill in the proof: write the inner product of columns $y$ and $y'$ of the QFT
matrix, substitute $M_{yx}=\omega^{xy}/\sqrt N$, and apply the identity. For the
diagonal case ($y=y'$), every term is $\omega^0=1$ and the sum equals $N$, giving
column norm $1$. Then invoke the Day 3 result that orthonormal columns imply
unitarity.

For continued fractions, the key trick is the best-approximation property of
convergents: $p_k/q_k$ is the closest fraction to the target real number among
all fractions with denominator $\le q_k$. The operationally useful consequence:
if QPE delivers $\varphi_{\text{meas}}$ with $|\varphi_{\text{meas}}-k/r|<
1/(2r^2)$, that precision is exactly strong enough for the best-approximation
property to single out the unique convergent equal to $k/r$. To fill in: run the
floor-and-invert recurrence for a concrete input, identify where the denominator
first exceeds the bound on $r$, and back up one step to read off the exact ratio.

## Flashcards

Q: What is the order of $a$ mod $N$?
A: The smallest positive integer $r$ such that $a^r\equiv1\pmod N$.

Q: State Miller's reduction (**Claim.**) in gcd form.
A: If $r$ is the order of $a$ mod $N$, $r$ is even, and $a^{r/2}\not\equiv-1\pmod N$, then $\gcd(a^{r/2}-1,N)$ is a nontrivial factor of $N$.

Q: Under what hypothesis on $N$ does Miller's reduction fail with probability at most $1/2$?
A: For odd $N$ with at least 2 distinct prime factors, failure over a uniformly random $a$ happens with probability at most $1/2$.

Q: Write the QFT action on basis state $|x\rangle$.
A: $\text{QFT}|x\rangle = \frac{1}{\sqrt N}\sum_{y=0}^{N-1}\omega^{xy}|y\rangle$ where $\omega=e^{2\pi i/N}$.

Q: What geometric-sum identity proves QFT column orthonormality?
A: $\sum_{x=0}^{N-1}\omega^{x(y-y')}=N$ when $y=y'$ and $0$ when $y\ne y'$, making inner products of distinct columns zero and each column unit-norm.

Q: Why is $H^{\otimes 2}$ a different matrix from $\text{QFT}_4$?
A: $H^{\otimes 2}$ is the Fourier transform for $(\mathbb{Z}_2)^2$ (all entries real); $\text{QFT}_4$ is the Fourier transform for $\mathbb{Z}_4$ (entries include $\pm i/2$) — they are transforms for different groups.

Q: Give the one-step rule of the Euclidean algorithm.
A: Write $a=q\cdot b+r_0$, replace $(a,b)$ with $(b,r_0)$, repeat until the remainder is $0$; the last nonzero remainder is $\gcd(a,b)$.

Q: What precision condition lets continued fractions recover $k/r$ exactly from a QPE estimate?
A: The QPE output $\varphi_{\text{meas}}$ must satisfy $|\varphi_{\text{meas}}-k/r|<1/(2r^2)$.

Q: What is the floor-not-round trap in continued-fraction expansion?
A: Always take $\lfloor 1/\text{fractional part}\rfloor$ — rounding instead of flooring gives the wrong quotient and corrupts the convergent recurrence.
