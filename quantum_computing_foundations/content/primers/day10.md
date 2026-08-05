# Day 10 primer — Bernstein–Vazirani & Simon's algorithm

## Warm-up

Three ideas from earlier in the path matter most here. Day 8 established the
Hadamard-transform identity $H^{\otimes n}|x\rangle = \frac{1}{\sqrt{2^n}}\sum_y(-1)^{x\cdot y}|y\rangle$
and its normalization-corrected inverse form
$\frac{1}{\sqrt{2^n}}H^{\otimes n}\bigl[\sum_x(-1)^{a\cdot x}|x\rangle\bigr] = |a\rangle$;
today's derivations use both versions, so reviewing each in
### Recap: the Hadamard transform and phase kickback (Day 8) before starting
will prevent confusion mid-proof. Day 8 also introduced the phase-kickback
shortcut: feeding the ancilla $|-\rangle$ to a Boolean oracle turns it into a
phase multiplier, stamping $(-1)^{f(x)}$ onto each data-register basis state
without disturbing the ancilla. Because BV and Simon's algorithm follow the
same structural shape as Deutsch–Jozsa — Hadamard, one oracle call, Hadamard,
measure — the Day 8 vocabulary applies here directly. From Day 7, you need
tensor-product fluency and comfort expanding $n$-qubit superpositions term by
term, since both derivations sweep over all $2^n$ basis states at once. From
Day 6, you need the Born rule and, critically, the partial-measurement rule:
measuring one register of a two-register system collapses the joint state to
the component consistent with the observed outcome, renormalized to unit norm.
This rule is stated explicitly in
### Simon's circuit: collapse and the linear constraint on $y$, and Simon's
algorithm pivots on it at its decisive step, so a brief refresh of Day 6 before
reaching that section will pay off immediately.

## The hook

Suppose a black box computes $f(x) = a \cdot x \bmod 2$ for a hidden $n$-bit
string $a$, and your task is to identify $a$. Classically you need $n$ queries
— one per standard-basis vector $e_i$, reading off bit $a_i = f(e_i)$ — because
a single Boolean evaluation leaks at most one bit of information about $a$.
Bernstein–Vazirani recovers all $n$ bits in a single quantum query. For $n=3$,
$a=101$ (bits $a_2a_1a_0 = 1,0,1$): after the second Hadamard pass the amplitude
at $|101\rangle$ accumulates as $\frac{1}{8}\sum_x(-1)^{a\cdot x}(-1)^{a\cdot x} = \frac{8}{8} = 1$,
while every other basis state's amplitude cancels to zero by the
parity-orthogonality lemma. The measurement returns $a=101$ with probability 1
in one pass. The quantum trick is not choosing a clever query point — it is
arranging all $2^n$ sign contributions so they reinforce constructively at
$|a\rangle$ and cancel everywhere else, with the hidden string itself supplying
both sign patterns that make this happen.

## The pictures

The first image to hold in mind is the sign table for $a=101$: eight rows, one
per $x\in\{0,1\}^3$, each carrying the oracle phase $(-1)^{a\cdot x}$ from
phase kickback. When computing the amplitude at $|y\rangle$ after the second
Hadamard pass you multiply that oracle sign by a second phase $(-1)^{x\cdot y}$.
For $y=a=101$ the two sign patterns are identical — every row contributes $+1$
and all eight terms add constructively. For any $y\ne a$ the patterns differ in
at least one bit, splitting rows into equal counts of $+1$ and $-1$ that sum to
zero. Picture eight arrows: all pointing the same direction for the correct
answer, forming a perfectly balanced cancellation for every wrong one.

The second image is Simon's oracle as a folded sheet. The $2^n$ inputs are
paired by the hidden period $s$: each $x$ shares its output value with exactly
one partner $x\oplus s$, like a sheet of paper folded along the axis defined by
$s$. The two halves are mirror images under $\oplus s$, and a single query
reveals one output value but not which fold pair produced it. After measuring
the second register you find yourself at one random fold, collapsed by the
partial-measurement rule onto the two-element superposition
$\frac{1}{\sqrt2}(|x_0\rangle+|x_0\oplus s\rangle)$ responsible for that output.

The third image is the $\mathbb{F}_2$ linear system being built row by row.
Each run of Simon's circuit yields a random vector $y$ satisfying
$y\cdot s\equiv0\pmod2$. Think of a grid: rows are constraints, columns are
bits of $s$, and each new independent $y$ adds one row. As long as consecutive
samples are linearly independent over $\mathbb{F}_2$, the null space of the
system shrinks by one dimension per measurement. After $n-1$ independent
equations the system is full-rank, its null space has dimension exactly 1
(spanned by $s$ and $0^n$), and Gaussian elimination over $\mathbb{F}_2$ —
row operations using XOR in place of subtraction — isolates $s$ as the unique
nonzero solution.

## Concrete-first walkthrough

The clearest entry into today's content is the three-qubit Bernstein–Vazirani
trace in the Worked example. Walk Stage 0 through Stage 4 before engaging
### Bernstein–Vazirani: statement and general derivation. Stage 0 is the input
$|000\rangle|1\rangle$. Stage 1 applies $H^{\otimes3}$ to the data register and
$H$ to the ancilla, giving $\frac{1}{\sqrt8}\sum_x|x\rangle\otimes|-\rangle$.
Stage 2 queries the oracle once: phase kickback stamps $(-1)^{a\cdot x}$ onto
each term — with $a=101$ meaning $a\cdot x = x_2\oplus x_0$, four inputs flip
sign and four retain it. Stage 3 applies $H^{\otimes3}$ a second time; the
general argument in ### Bernstein–Vazirani: statement and general derivation
shows the result is exactly $|101\rangle$, and the Worked example verifies this
directly by computing $\text{amp}(y) = \frac{1}{8}\sum_x(-1)^{x\cdot(a\oplus y)}$
for two representative $y$ values and invoking the lemma in
### The parity-orthogonality lemma. Stage 4 is a computational-basis measurement
returning $101$ with probability 1.

For Simon's algorithm, first read ### Simon's algorithm: statement and why the
promise is stronger to understand why the classical problem is genuinely hard.
The birthday-paradox argument there establishes a provable $\Omega(2^{n/2})$
classical query lower bound that survives bounded error, making Simon's quantum
advantage a qualitative exponential separation rather than a constant-factor
speedup. Then move to ### Simon's circuit: collapse and the linear constraint
on $y$. After the oracle call the joint state is
$\frac{1}{\sqrt{2^n}}\sum_x|x\rangle|f(x)\rangle$. Measuring register 2 and
observing outcome $z$ collapses register 1: exactly two inputs, $x_0$ and
$x_0\oplus s$, produce $f(x)=z$, each with amplitude $\frac{1}{\sqrt{2^n}}$,
combined probability $\frac{2}{2^n}$, and renormalization by $\sqrt{2/2^n}$
yields $\frac{1}{\sqrt2}(|x_0\rangle+|x_0\oplus s\rangle)$. Applying
$H^{\otimes n}$ gives amplitude on $|y\rangle$ proportional to
$(-1)^{x_0\cdot y}[1+(-1)^{s\cdot y}]$: the bracket is $2$ when
$s\cdot y\equiv0\pmod2$ and $0$ otherwise, so each run delivers a uniformly
random $y$ from $s^\perp$ and $n-1$ independent samples yield the full system.

A common trap in ### Simon's algorithm: statement and why the promise is
stronger: the text says a classical algorithm "learns almost nothing" from a
non-colliding pair, not "learns nothing." Each queried pair $\{x,x'\}$ with
$f(x)\ne f(x')$ rules out exactly one candidate, $s=x\oplus x'$, from the
$2^n-2$ nonzero possibilities — one elimination from an exponentially large
pool, which is why exponentially many queries are needed before the birthday
paradox delivers an actual collision and useful information about $s$.

After mastering both algorithms individually, read ### Unifying view. The
common engine is the parity-orthogonality lemma: it forces post-second-Hadamard
amplitude to concentrate onto (BV) or be confined to a subspace determined by
(Simon) the oracle's hidden data, and the amount of information recovered per
run — all $n$ bits at once for BV, one random linear bit for Simon — tracks
exactly how rich the oracle's promise is.

## Derivation roadmaps

### Bernstein–Vazirani: statement and general derivation builds on
### The parity-orthogonality lemma. Key trick: express $f(x)=a\cdot x$ as a
mod-2 dot product; after two Hadamard layers the amplitude at $|y\rangle$
contains $(-1)^{a\cdot x}(-1)^{x\cdot y}=(-1)^{x\cdot(a\oplus y)}$ by
bilinearity of the mod-2 dot product. Summing over all $x$ via the lemma gives
$2^n$ when $y=a$ and $0$ otherwise. Fill in the prefactor
$\frac{1}{2^n}\cdot2^n = 1$ and confirm the state collapses to $|a\rangle$.

### Simon's circuit: collapse and the linear constraint on $y$ has two stages.
Collapse — key trick: apply the partial-measurement rule; exactly two branches
survive (those with $f(x)=z$), each with amplitude $\frac{1}{\sqrt{2^n}}$ and
combined probability $\frac{2}{2^n}$; dividing by $\sqrt{2/2^n}$ yields equal
amplitudes $\frac{1}{\sqrt2}$ on the two surviving states. Fill in the
Born-rule probability step explicitly before renormalizing. Constraint — key
trick: expand both surviving states via the Hadamard identity, factor the
bracket $(-1)^{x_0\cdot y}[1+(-1)^{s\cdot y}]$, note it vanishes when
$s\cdot y\equiv1\pmod2$; fill in the amplitude normalization to confirm equal
magnitude on all surviving $y$'s.

### The parity-orthogonality lemma: key trick: the sum factors bitwise as
$\prod_j\sum_{x_j\in\{0,1\}}(-1)^{z_j x_j}$; each single-bit factor is $2$
when $z_j=0$ and $0$ when $z_j=1$, so the entire product is $2^n$ iff
$z=0^n$ and $0$ the moment any $z_j=1$. Fill in the step that justifies
factoring the joint sum by the bitwise independence of the $x_j$'s.

## Flashcards

Q: State the parity-orthogonality lemma.
A: $\sum_{x\in\{0,1\}^n}(-1)^{x\cdot z} = 2^n$ if $z=0^n$, and $0$ if $z\ne0^n$.

Q: Describe the Bernstein–Vazirani circuit in one sentence.
A: Prepare $|0\rangle^{\otimes n}|1\rangle$, apply $H^{\otimes n}$ to the data
register and $H$ to the ancilla, query the oracle once, apply $H^{\otimes n}$
to the data register, and measure.

Q: What is the key algebraic trick in the BV derivation?
A: After two Hadamard layers the amplitude at $|y\rangle$ carries
$(-1)^{x\cdot(a\oplus y)}$; the parity-orthogonality lemma forces the sum over
$x$ to $2^n\cdot\mathbf{1}[y=a]$, concentrating all amplitude on $|a\rangle$.

Q: State Simon's promise precisely.
A: $f:\{0,1\}^n\to\{0,1\}^n$ is exactly 2-to-1, with $f(x)=f(y)\iff y=x$
or $y=x\oplus s$ for a fixed hidden $s\ne0^n$.

Q: State the partial-measurement rule used in Simon's algorithm.
A: Measuring one register yields each outcome with probability given by the
Born rule on that register's marginal; the post-measurement state is the
component of the joint state consistent with the observed outcome, renormalized
to unit norm.

Q: After measuring Simon's second register, what is the state of the first
register?
A: $\frac{1}{\sqrt2}(|x_0\rangle+|x_0\oplus s\rangle)$, where $x_0$ is one
of the two inputs producing the observed output value.

Q: How does the $\mathbb{F}_2$ linear system arise in Simon's algorithm?
A: Each run returns a uniformly random $y$ with $y\cdot s\equiv0\pmod2$;
collecting $n-1$ linearly independent such samples gives a homogeneous system
whose unique nonzero solution, found by Gaussian elimination over $\mathbb{F}_2$,
is $s$.

Q: What does "learns almost nothing" mean for a non-colliding pair in Simon's
setting?
A: Querying $x,x'$ with $f(x)\ne f(x')$ rules out only $s=x\oplus x'$ from
$2^n-2$ nonzero candidates — one elimination from an exponentially large pool,
far too slow to expose $s$ without an actual collision.
