# Day 2 primer — Computational complexity & randomized computation

## Warm-up

Yesterday's primer (primers/day01.md) grounded you in Boolean logic and
reversible computation — gates, Toffoli universality, and Landauer's
principle connecting irreversible erasure to heat. You saw that every
reversible gate permutes its inputs without destroying information. Today's
expansion is orthogonal: instead of asking whether a computation can be
undone, it asks whether a computation can be *wrong*, on purpose, and still
be useful. That shift — from deterministic, reversible procedures to
probabilistic ones with bounded error — is the whole subject of day02.md.
Before you open it, ask yourself: if an algorithm tosses biased coins during
its run, what does "efficient" mean? And what does "correct" mean when
different runs can give different answers?

## The hook

Here is the central tension you will resolve. Run a randomized algorithm
five times independently, each run succeeding with probability $3/4$, and
take the majority answer. The vote fails only when two or fewer runs are
correct, and that is computable exactly: $\Pr[S \le 2] \approx 0.103516$,
just over ten percent. Now apply the Hoeffding bound from the section
**Error amplification: the Chernoff/Hoeffding bound** — it predicts failure
probability at most $\exp(-0.625) \approx 0.535$. The bound holds — $0.104
\le 0.535$ — but it overshoots the truth by more than a factor of five at
this small value of $k$. That is not a flaw; it is a design feature of
worst-case concentration inequalities. The bound's payoff is asymptotic:
its exponent $-k/18$ proves that majority-vote error decays exponentially
in $k$, so roughly 251 repetitions push the error below $2^{-20}$. That
tradeoff — loose at small $k$, powerful asymptotically — is the
intellectual core of today's material.

## The pictures

Picture the amplification process as a funnel. At the wide end, a single
run spills its output into two bins — correct and wrong — with a
$3/4$-to-$1/4$ split. Each additional repetition tightens the funnel: the
wrong bin's width shrinks by a constant multiplicative factor with every
new run, so the funnel narrows exponentially and closes like $e^{-k/18}$
as $k$ grows. By 251 repetitions the wrong bin has been squeezed below one
part in a million. Any starting gap above $1/2$ — not just $2/3$ —
generates its own funnel with its own tightening rate, which is why the
$2/3$ threshold in BPP's definition is arbitrary and not a hard ceiling.

The Hoeffding bound's proof pivots on a second picture: the exponential
tilt. Imagine a histogram of the deviation $Y$ of a single run from its
mean, with most weight near zero and thin tails on either side. Multiplying
each outcome's weight by $e^{sY}$ re-weights the histogram, shifting mass
toward the right tail, but the tilted distribution is still supported on
the same interval $[a, b]$. The key insight in **Step 2 — Hoeffding's
lemma** is that the variance bound established in **Step 1 — a variance
bound** applies equally to the tilted distribution, because no re-weighting
ever moves an outcome outside $[a, b]$. Reusing the same one-line algebraic
bound twice is what makes the cumulant generating function tractable.

The Deutsch–Jozsa promise is best seen as two far-apart islands. One is
"constant": the function returns the same value on every input, so every
sample you collect is the same color. The other is "balanced": exactly half
the inputs map to $0$ and half to $1$, so independent samples split evenly.
The promise places you on one island or the other — no shoreline, no
"mostly-constant" middle ground. That hard separation is why a handful of
random queries is decisive. On the balanced island, all $m$ independent
samples agree only if they all land in the same half, which happens with
probability $2^{-(m-1)}$. On the constant island, there is no error at all.
Without the promise the islands would merge and no finite sample could
separate them reliably.

## Concrete-first walkthrough

Open day02.md at the section **Deterministic and probabilistic decision
procedures**. A deterministic algorithm on a fixed input always runs the
same way and gives the same answer. A probabilistic algorithm has access to
random bits, so different runs may follow different paths and may output
different answers. BPP captures the right notion of "useful despite
randomness": for every input, the algorithm runs in polynomial time and is
correct with probability at least $2/3$. The guarantee is worst-case over
inputs, randomized only over the algorithm's own coin flips. The $2/3$
threshold is a convention, not a deep boundary: because any fixed success
probability strictly above $1/2$ can be amplified to $1 - \varepsilon$ at
polynomial cost, the exact constant does not change the class BPP.

The section **$P \subseteq BPP$** resolves in one sentence. A deterministic
algorithm is a probabilistic one that ignores its random bits; it succeeds
with probability exactly $1$, which satisfies the $\ge 2/3$ condition with
room to spare. So every language in $P$ is in $BPP$ by the same algorithm,
requiring no modification. The interesting content of $BPP$ lies in what
might sit inside it beyond $P$ — a question the theory leaves open.

The section **Las Vegas algorithms versus BPP** draws the sharpest
distinction in today's material. A Las Vegas algorithm is never wrong:
randomness lives in its running time, not its output. A BPP algorithm has
a fixed time budget but can produce a wrong answer. If you try to bridge
these by truncating a Las Vegas algorithm — running it for $c$ times its
expected runtime and outputting a fixed default if it has not finished —
Markov's inequality gives you one fact: for any nonneg. r.v. $X$ and
threshold $t > 0$, $\Pr[X \ge t] \le \mathbb{E}[X]/t$, so truncation fires
on at most $1/c$ of runs. For $c = 3$ that is at most one run in three,
which looks like BPP's error margin. But Markov says nothing about whether
the default guess is correct on those triggered runs. The Las Vegas
correctness guarantee applies only to runs allowed to finish naturally; a
forcibly halted computation carries no promise, and an arbitrary default
output has no guaranteed relationship to the correct answer. You get a
ceiling on how often truncation fires, not on how often the output is wrong
when it does.

The section **Error amplification: the Chernoff/Hoeffding bound** is the
day's technical centerpiece. Let $S = \sum_{i=1}^{k} X_i$ count correct
runs, each $X_i$ a $\{0,1\}$ indicator with mean at least $2/3$. The
majority vote errs only when $S \le k/2$. **Step 1 — a variance bound**
establishes the algebraic foundation: any r.v. with values in $[a, b]$ has
variance at most $(b-a)^2/4$, proved by noting $(Y - a)(b - Y) \ge 0$
pointwise. **Step 2 — Hoeffding's lemma** applies Step 1 to the tilted
distribution and deduces $\mathbb{E}[e^{sY}] \le \exp(s^2(b-a)^2/8)$ via
Taylor's theorem. **Step 3 — the Chernoff argument** applies Markov to
$e^{-s(S-\mu)}$, factors over independence, plugs in the lemma, and
minimizes the exponent $-st + ks^2/8$ over $s > 0$, giving $\Pr[S - \mu
\le -t] \le \exp(-2t^2/k)$. **Step 4 — applying it** notes that since
$\mu \ge 2k/3$, the gap from $\mu$ to $k/2$ is at least $k/6$; taking
$t = k/6$ yields $\Pr[S \le k/2] \le e^{-k/18}$.

The worked example's **Claim:** is that the Hoeffding bound is valid but
loose at small $k$: with $k = 5$ and $p = 3/4$, the exact failure
probability is $0.103516$ while the bound predicts $0.535$ — loose by more
than a factor of five. The prescription of $k = 251$ for error below
$2^{-20}$ is therefore a safe ceiling, not a tight minimum.

The section **A randomized classical algorithm for the Deutsch–Jozsa
promise problem** closes the day. Query $f$ at $m$ independently and
uniformly chosen inputs. Output "constant" if and only if all $m$ answers
agree — all $0$ or all $1$; output "balanced" otherwise. When $f$ is
constant (either $f \equiv 0$ or $f \equiv 1$), every query returns the
same value, so the algorithm is always correct on this side of the promise.
When $f$ is balanced, an error occurs only when all $m$ answers agree: all
land in the $0$-half (probability $(1/2)^m$) or all in the $1$-half
(probability $(1/2)^m$), giving total error $2^{-(m-1)}$. One practical
trap: majority votes need an odd number of trials to avoid ties. The bound
$e^{-k/18} < 2^{-20}$ requires $k > 249.53$, so take $k = 251$, the
smallest odd integer above that threshold — not $250$.

## Derivation roadmaps

The Chernoff/Hoeffding chain is today's longest derivation. The key trick
is to exponentiate the deviation: rather than bounding $\Pr[S - \mu \le
-t]$ directly, rewrite it as $\Pr[e^{-s(S-\mu)} \ge e^{st}]$ and apply
Markov's inequality to the nonneg. r.v. $e^{-s(S-\mu)}$. Independence then
lets you factor the joint expectation into a product of per-variable
expectations, Hoeffding's lemma caps each factor, and optimizing the
exponent over $s$ tightens the bound. What you need to fill in: the Taylor
expansion of $\varphi(s) = \ln \mathbb{E}[e^{sY}]$ using $\varphi(0) = 0$,
$\varphi'(0) = 0$, and $\varphi''(s) = \mathrm{Var}_s(Y) \le (b-a)^2/4$
(the tilted-distribution appendix supplies the two derivative identities);
and the calculus step minimizing $-st + ks^2/8$ over $s > 0$ by
differentiating and setting the derivative to zero.

For $P \subseteq BPP$ the key trick is definitional: a deterministic machine
is a probabilistic one that ignores its random tape entirely, so its error
is exactly $0$, which is below the $1/3$ BPP ceiling. What you need to fill
in: a careful statement of why error $0 < 1/3$ satisfies the BPP condition
without any modification to the algorithm, and why that suffices to witness
$P \subseteq BPP$ for every language in $P$.

For the classical Deutsch–Jozsa argument the key trick is that under a
balanced $f$ the event "all $m$ answers agree" splits into exactly two
disjoint sub-events — all in the $0$-half, all in the $1$-half — each with
probability $(1/2)^m$, because each query independently lands in either
half with probability exactly $1/2$. What you need to fill in: the
independence argument turning per-query probability into the product
$(1/2)^m$ for each sub-event, the disjointness step justifying addition of
the two probabilities rather than overlapping them, and the simplification
$2 \cdot (1/2)^m = 2^{-(m-1)}$.

## Flashcards

Q: What is BPP?
A: The class of languages decided by a probabilistic polynomial-time
algorithm that is correct on every input with probability at least $2/3$
(two-sided error at most $1/3$ on every input).

Q: What is the majority-vote error bound after $k$ repetitions?
A: At most $e^{-k/18}$, exponentially small in $k$.

Q: At $k = 5$ and $p = 3/4$, what does the Hoeffding bound predict versus
the exact failure probability?
A: Hoeffding predicts at most $\exp(-0.625) \approx 0.535$; the exact
failure probability is $\Pr[S \le 2] \approx 0.103516$ (about $10.4\%$).
The bound holds but is loose by more than a factor of five.

Q: State Hoeffding's lemma.
A: If $Y$ is supported on $[a, b]$ with $\mathbb{E}[Y] = 0$, then
$\mathbb{E}[e^{sY}] \le \exp\!\bigl(s^2(b-a)^2/8\bigr)$ for all $s$.

Q: State Markov's inequality.
A: For any nonneg. r.v. $X$ and threshold $t > 0$, $\Pr[X \ge t] \le
\mathbb{E}[X]/t$.

Q: What is the all-agree rule and error bound for the classical DJ
algorithm?
A: Output "constant" if and only if all $m$ query answers agree (all $0$
or all $1$); the error probability is $2^{-(m-1)}$, incurred only on the
balanced side of the promise.

Q: Why use an odd $k$ for majority vote, and what is the smallest valid $k$
for error below $2^{-20}$?
A: An even $k$ risks a tie; an odd $k$ always produces a strict majority.
Since $e^{-k/18} < 2^{-20}$ requires $k > 249.53$, take $k = 251$, the
smallest odd integer above that threshold.
