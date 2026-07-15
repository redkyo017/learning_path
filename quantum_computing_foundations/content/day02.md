# Day 2 — Computational Complexity & Randomized Computation

## Learning objectives

By the end of today you should be able to:
- State the classes P and BPP precisely, and prove $P \subseteq BPP$.
- Distinguish a Las Vegas algorithm (randomized *running time*, always
  correct) from a Monte Carlo / BPP algorithm (fixed running time,
  bounded-error *answer*), and explain what goes wrong if you naively
  truncate a Las Vegas algorithm at a fixed time bound.
- Derive, with an explicit constant, the Chernoff/Hoeffding bound showing
  that majority-vote repetition of a bounded-error algorithm drives the
  error probability down exponentially in the number of repetitions.
- Use that bound to compute concretely how many repetitions are needed to
  reach a target confidence.
- Design and analyze a randomized classical algorithm for the
  Deutsch–Jozsa promise problem (constant vs. balanced), and state its
  confidence as a function of the number of queries.
- Explain precisely why an informal "quantum computer solved X faster"
  claim is not, by itself, a complexity-theoretic statement, and how to
  rewrite it so that it is.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*
  (or Ronald de Wolf's *Quantum Computing: Lecture Notes*), the sections
  covering complexity classes P/NP/BPP and randomized algorithms.
- Any standard algorithms or complexity reference's treatment of the
  Chernoff/Hoeffding concentration bound. The derivation below is
  self-contained — you do not need an external source to work through
  today's material, but a second explanation in different words is useful.

## Theory

### Deterministic and probabilistic decision procedures

A **language** $L \subseteq \{0,1\}^*$ is decided by an algorithm if, on
every input $x$, the algorithm outputs $1$ when $x \in L$ and $0$ when
$x \notin L$. **P** is the class of languages decidable by a
*deterministic* algorithm running in time polynomial in $|x|$: on a fixed
input, the algorithm always does the same thing and always gets the right
answer.

A **probabilistic** algorithm additionally has access to a private source
of unbiased random bits; on the same input $x$, different runs may follow
different computational paths and, in general, may even output different
answers. **BPP** (bounded-error probabilistic polynomial time) is the class
of languages $L$ for which there is a probabilistic algorithm running in
time polynomial in $|x|$ such that, for every input $x$ (not just "most"
inputs — the guarantee is worst-case over $x$, only randomized over the
algorithm's internal coin flips):
$$
\Pr[\text{algorithm outputs the correct answer on } x] \ge \frac{2}{3}.
$$
Equivalently, the *two-sided* error — the algorithm can be wrong whether
the correct answer is $1$ or $0$ — is at most $1/3$ on every input. The
constant $2/3$ (equivalently error $\le 1/3$) is a convention, not a deep
threshold: as the error-amplification argument below shows, *any* fixed
constant success probability strictly above $1/2$ can be boosted to
$1-\varepsilon$ for arbitrarily small $\varepsilon$ at the cost of a
polynomial (in $\log(1/\varepsilon)$) number of repetitions, so the exact
choice of constant does not change the class BPP.

### $P \subseteq BPP$

Every deterministic polynomial-time algorithm is trivially also a
probabilistic polynomial-time algorithm: it is simply one that happens
never to consult its random bits, and it is correct with probability $1$
on every input, which certainly satisfies "correct with probability
$\ge 2/3$." So the same algorithm, viewed as a (degenerate) probabilistic
algorithm, witnesses membership in BPP for every language already in P.
This containment is not merely definitional bookkeeping — it says that
allowing randomness cannot make a *P*-decidable language harder to decide,
so BPP is a genuine relaxation, and any effort spent proving a language is
in BPP that is already known to be in P adds no new algorithmic power;
the interesting content of BPP is the (open) question of which additional
languages, not known to be in P, it might contain.

### Las Vegas algorithms versus BPP

A **Las Vegas** algorithm is randomized but never wrong: on every input, if
it terminates, its output is correct with certainty; what varies from run
to run is its *running time*, which is a random variable. "Runs in
expected polynomial time" means $\mathbb{E}[T(x)] = \text{poly}(|x|)$ for
every $x$, where $T(x)$ is the (random) running time on input $x$.

This is a genuinely different guarantee from a BPP algorithm's, and the two
do not automatically convert into one another. A BPP algorithm has a *fixed*
worst-case running time bound (a hard deadline that never gets exceeded)
but may output a *wrong answer*. A Las Vegas algorithm never outputs a
wrong answer but has no fixed deadline — only a bound on its *average*
running time.

Suppose you try to force a Las Vegas algorithm into a fixed time budget by
truncating it: run it for at most $T = c \cdot \mathbb{E}[T(x)]$ steps (some
constant multiple of its expected time) and, if it has not yet halted,
stop it and output *something* — e.g. a fixed default guess. Two things
must be tracked separately:

1. **How often does truncation actually trigger?** By Markov's inequality,
   $\Pr[T(x) > c\cdot\mathbb{E}[T(x)]] \le 1/c$, since $T(x)$ is a
   nonnegative random variable. So for, say, $c=3$, truncation triggers
   with probability at most $1/3$ — this part alone already looks exactly
   like a BPP-style bound.
2. **What happens on the runs where truncation triggers?** The algorithm's
   Las Vegas guarantee says *nothing* about the partial state of a run that
   has not yet finished — there is no guarantee that a half-finished Las
   Vegas computation, forcibly stopped and read out, is even a well-formed
   candidate answer, let alone a correct one with any particular
   probability. If you plug in an arbitrary default output on truncation,
   the *only* thing you can say about the resulting error probability is
   the Markov bound on how often truncation happens at all — you get no
   help whatsoever from the algorithm's own logic on those runs, unlike a
   true BPP algorithm, whose bounded-error guarantee holds by design across
   its *entire* fixed running time, not just on some most-likely-good
   prefix of it.

So "expected poly time, always correct" and "fixed poly time, correct with
probability $\ge 2/3$" are related (Markov's inequality gives one direction
of a translation, with a real, quantifiable cost in success probability)
but are not the same promise, and turning one into the other requires an
explicit argument like the one above, not just relabeling.

### Error amplification: the Chernoff/Hoeffding bound

Now the central quantitative result of the day. Suppose $A$ is a BPP
algorithm for some language $L$: on every fixed input $x$, a single run of
$A$ is correct with probability $p \ge 2/3$ (the exact value of $p$ may
depend on $x$, but is always at least $2/3$). Run $A$ on $x$ independently
$k$ times (fresh random bits each time) and output the majority answer.
Call this the *amplified* algorithm $A_k$. The claim is that $A_k$'s error
probability decays *exponentially* in $k$.

**Setup.** Let $X_1,\dots,X_k$ be independent random variables with
$X_i = 1$ if the $i$-th run of $A$ is correct and $X_i=0$ otherwise, so
$X_i \in \{0,1\}$ and $\mathbb{E}[X_i] = p_i \ge 2/3$. Let $S = \sum_{i=1}^k
X_i$ (the number of correct runs) and $\mu = \mathbb{E}[S] = \sum_i p_i \ge
\frac{2k}{3}$. The majority vote is wrong only if strictly fewer than half
the runs are correct, which in particular implies $S \le k/2$; we bound
$\Pr[S \le k/2]$, which upper-bounds the majority-vote error probability.

**Step 1 — a variance bound for bounded random variables.** For any random
variable $Y$ supported on an interval $[a,b]$, $(Y-a)(b-Y)\ge 0$ always
(since $a\le Y\le b$), so taking expectations, $\mathbb{E}[-Y^2+(a+b)Y-ab]
\ge 0$, i.e. $\mathbb{E}[Y^2] \le (a+b)\mathbb{E}[Y]-ab$. Hence
$$
\text{Var}(Y) = \mathbb{E}[Y^2]-\mathbb{E}[Y]^2 \le (a+b)\mathbb{E}[Y]-ab
-\mathbb{E}[Y]^2 = -(\mathbb{E}[Y]-a)(\mathbb{E}[Y]-b).
$$
The right-hand side, as a function of $\mathbb{E}[Y]$, is a downward
parabola maximized at $\mathbb{E}[Y]=(a+b)/2$ with maximum value
$(b-a)^2/4$. So $\text{Var}(Y) \le (b-a)^2/4$ for *any* distribution
supported on $[a,b]$, regardless of its shape.

**Step 2 — Hoeffding's lemma.** Let $Y$ be supported on $[a,b]$ with
$\mathbb{E}[Y]=0$. Define the cumulant generating function $\varphi(s) =
\ln \mathbb{E}[e^{sY}]$. Then $\varphi(0)=0$, and
$\varphi'(s) = \mathbb{E}_s[Y]$ (the mean of $Y$ under the exponentially
"tilted" distribution with density proportional to $e^{sy}$), so
$\varphi'(0)=\mathbb{E}[Y]=0$. Differentiating again, $\varphi''(s) =
\text{Var}_s(Y)$, the variance of $Y$ under the same tilted distribution —
and since the tilted distribution is still supported on $[a,b]$, Step 1
applies to it too: $\varphi''(s) \le (b-a)^2/4$ for every $s$. By Taylor's
theorem with Lagrange remainder, for every $s$ there is some $\xi$ with
$$
\varphi(s) = \varphi(0)+\varphi'(0)s+\tfrac{1}{2}\varphi''(\xi)s^2 \le
\frac{(b-a)^2}{8}s^2,
$$
i.e. $\mathbb{E}[e^{sY}] \le \exp\!\big(s^2(b-a)^2/8\big)$ for all $s$.

**Step 3 — the Chernoff argument.** Apply Step 2 to $Y_i = X_i - p_i \in
[-p_i,\,1-p_i]$, an interval of length exactly $1$ regardless of $p_i$, so
$\mathbb{E}[e^{sY_i}] \le e^{s^2/8}$. For any $s>0$ and any threshold $t>0$,
Markov's inequality applied to the nonnegative random variable
$e^{-s(S-\mu)}$ gives
$$
\Pr[S-\mu \le -t] = \Pr\big[e^{-s(S-\mu)} \ge e^{st}\big] \le
e^{-st}\,\mathbb{E}\big[e^{-s(S-\mu)}\big] = e^{-st}\prod_{i=1}^k
\mathbb{E}[e^{-sY_i}] \le e^{-st+ks^2/8},
$$
using independence of the $X_i$ (hence of the $Y_i$) to split the
expectation of the product into a product of expectations. Minimizing the
exponent $-st+ks^2/8$ over $s>0$: its derivative is $-t+ks/4$, zero at
$s=4t/k$, giving minimum value $-4t^2/k + \frac{k}{8}\cdot\frac{16t^2}{k^2}
= -\frac{4t^2}{k}+\frac{2t^2}{k} = -\frac{2t^2}{k}$. So
$$
\Pr[S-\mu \le -t] \le \exp\!\left(-\frac{2t^2}{k}\right) \qquad
\text{for all } t>0.
$$
This is the Hoeffding tail bound for a sum of independent $\{0,1\}$-valued
random variables.

**Step 4 — applying it to majority-vote amplification.** We need
$\Pr[S\le k/2]$. Since $\mu \ge 2k/3$, the gap $\mu - k/2 \ge \frac{2k}{3}-
\frac{k}{2} = \frac{k}{6}$ — the mean of $S$ is bounded away from the
majority threshold by a constant fraction, $1/6$, of $k$. So $S\le k/2$
implies $S-\mu \le k/2-\mu \le -k/6$, and therefore, taking $t=k/6$ in Step
3's bound,
$$
\Pr[S\le k/2] \le \Pr\!\left[S-\mu \le -\frac{k}{6}\right] \le
\exp\!\left(-\frac{2(k/6)^2}{k}\right) = \exp\!\left(-\frac{2k}{36}\right)
= e^{-k/18}.
$$
So the majority-vote-amplified algorithm $A_k$ has error probability at
most $e^{-k/18}$ on every input — exponentially small in the number of
repetitions $k$, with an explicit constant $c = 1/18$ in the bound
$e^{-ck}$. This is the precise sense in which the constant $2/3$ in BPP's
definition is not fragile: any fixed gap above $1/2$ (here, $1/6$) can be
blown up into an exponentially small error at only polynomial (in fact
linear) cost in the number of repetitions.

### A randomized classical algorithm for the Deutsch–Jozsa promise problem

Consider a black-box function $f:\{0,1\}^n \to \{0,1\}$, promised to be
either the constant function $f\equiv 0$ or **balanced** (exactly half of
the $2^n$ inputs map to $1$, half to $0$). We want to decide which case
holds using as few queries to $f$ as possible.

**Algorithm.** Query $f$ at $m$ points $x_1,\dots,x_m$, drawn independently
and uniformly at random from $\{0,1\}^n$. If any query returns $1$, output
"balanced." If all $m$ queries return $0$, output "constant."

**Correctness.** If $f\equiv 0$, every query returns $0$ with certainty, so
the algorithm always (correctly) outputs "constant" — there is no error on
this side of the promise at all. If $f$ is balanced, the algorithm errs
only if it happens to output "constant," i.e. only if all $m$ independent
uniformly random queries land in the half of the domain where $f=0$. Since
the queries are independent and each one lands in the zero-half with
probability exactly $1/2$ (balance is exact, not approximate), this
happens with probability exactly $(1/2)^m = 2^{-m}$. So with $m=k$ queries,
the algorithm is correct with probability at least $1-2^{-k}$ — confidence
$1-2^{-k}$, one-sided error only (it can never mistake a truly constant
function for balanced).

This is worth holding onto: no *fixed* number of classical random queries
ever reaches error $0$ with certainty — confidence approaches $1$ only in
the limit $k\to\infty$. Day 8's Deutsch–Jozsa algorithm solves this exact
promise problem with a *single* quantum query and *zero* error, which is a
qualitatively different guarantee, not just a quantitatively better
constant — the comparison is the entire point of revisiting this problem
on Day 8.

## Common misconceptions

**"A quantum computer solved X faster than a classical program" is not,
by itself, a complexity-theoretic claim.** Complexity theory is a
statement about how running time (or query count) *scales* as the input
size $n$ grows, across an entire family of instances, for the *best
possible* algorithm on each side — not a stopwatch comparison between two
specific, fixed programs running on two specific pieces of hardware on one
particular input. A claim of the form "the quantum program finished in 10
seconds and the classical program took 10 minutes" is compatible with
almost anything: the classical program might be a poor, unoptimized
implementation of an algorithm that is actually polynomial-time (in which
case a better classical program erases the gap entirely); the comparison
might hold only at the one problem size tested and vanish, invert, or
grow, at larger $n$; and differences in hardware, engineering effort, and
constant factors can dwarf any genuine asymptotic effect at the sizes
anyone can actually run.

**A well-posed version of the claim has to name complexity classes, not
programs.** The precise question is a *class-containment* question: is
there *any* algorithm in P (or, allowing randomness, in BPP) — the best
possible one, not a specific implementation — that solves the problem
family in polynomial time, versus a poly-size quantum circuit family (in
BQP, formalized on Day 15) that does. "No known or possible poly-time
classical algorithm (in P or BPP) solves this problem family, while a
poly-size quantum circuit family does" is a meaningful claim precisely
because it quantifies over *all* classical algorithms (or is backed by an
unconditional lower-bound proof, as BBBV supplies for Grover search on
Day 12) rather than pointing at one implementation that happened to run
slower on one afternoon.

**This is exactly why Day 2's own results matter as a baseline before any
quantum content appears.** Exercise 3's amplification bound establishes
that BPP's fixed constant ($2/3$) is not a meaningful ceiling — a
classical randomized algorithm can be made *arbitrarily* confident at only
linear cost in repetitions, so "the quantum algorithm is more confident"
is not by itself an advantage claim either, unless the classical
repetition count needed to match that confidence is compared honestly (as
Exercise 5 does, explicitly, against Deutsch–Jozsa's single-query
certainty on Day 8). Every later "quantum speedup" claim in this course
(Grover, Shor) will be stated the same way: as a comparison between the
best known or provably optimal classical complexity and a specific quantum
circuit's complexity, on an infinite family of growing instances — never
as a comparison of two stopwatch readings.

## Worked example

**Claim:** the Hoeffding bound derived above is *valid* but, as expected of
a general-purpose concentration inequality, not *tight* for small $k$ — it
is a genuine upper bound on the error, not an estimate of it.

Take a BPP-style algorithm whose single-run success probability is $p=3/4$
(comfortably above the $2/3$ threshold, to make the arithmetic clean), and
amplify it by running it $k=5$ times and taking the majority (so "majority"
means $3$ or more correct out of $5$; the vote fails iff $2$ or fewer are
correct).

**Exact failure probability.** $S \sim \text{Binomial}(5, 0.75)$. Directly:
$$
\Pr[S=0] = 0.25^5 = 0.0009766,\qquad
\Pr[S=1] = \binom{5}{1}(0.75)(0.25)^4 = 0.014648,
$$
$$
\Pr[S=2] = \binom{5}{2}(0.75)^2(0.25)^3 = 0.087891.
$$
Summing, $\Pr[\text{fail}] = \Pr[S\le 2] \approx 0.0009766+0.014648+0.087891
= 0.103516$ — about $10.4\%$.

**The Hoeffding bound's prediction.** Redo Step 4 of the derivation above
with $p=3/4$ instead of the worst-case $2/3$: $\mu = 5(0.75)=3.75$, and the
gap to the majority threshold $k/2=2.5$ is $t=\mu-k/2 = 1.25$. The bound
gives
$$
\Pr[S\le k/2] \le \exp\!\left(-\frac{2t^2}{k}\right) =
\exp\!\left(-\frac{2(1.25)^2}{5}\right) = \exp(-0.625) \approx 0.535.
$$

**Comparison.** The exact failure probability ($\approx 0.104$) is indeed
$\le$ the Hoeffding bound's prediction ($\approx 0.535$), confirming the
bound holds — but the bound overshoots the true error by more than a
factor of $5$ at this small value of $k$. This is typical of Chernoff/
Hoeffding-type bounds: they are one-sided, worst-case-shape guarantees that
become tight only in an asymptotic ($k\to\infty$) sense, via the exponent's
rate ($1/18$, or $2t^2/k$ in general) being the *correct* asymptotic decay
rate, even when the bound's *constant prefactor* is loose for small $k$.
Practically, this means: Exercise 4's computed repetition count for a
target confidence is a safe (conservative) sufficient number of
repetitions, not a claim that fewer repetitions couldn't also work.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Prove that $P \subseteq BPP$.
2. Explain the difference between a Las Vegas algorithm (always correct,
   randomized running time with a bound only on its *expectation*) and a
   BPP algorithm (fixed running time, bounded-error answer). If you
   truncate a Las Vegas algorithm at a fixed multiple of its expected
   running time and output a default guess whenever it hasn't finished,
   what exactly can you say — and, importantly, what can you *not* say —
   about the resulting error probability?
3. A BPP algorithm has two-sided error at most $1/3$ on every input (correct
   with probability $\ge 2/3$). Derive the Chernoff/Hoeffding bound for
   running the algorithm $k$ times independently and taking the majority
   answer: show the majority vote is wrong with probability at most
   $e^{-ck}$ for an explicit constant $c>0$ that you compute from the
   $1/6$ gap between $2/3$ and the majority threshold $1/2$. Show your
   work — don't just cite the bound.
4. Using your bound from Exercise 3, compute how large $k$ must be to
   guarantee the amplified algorithm's error probability is below
   $2^{-20}$.
5. A black-box $f:\{0,1\}^n\to\{0,1\}$ is promised to be either constant-$0$
   or exactly balanced. Design a randomized classical algorithm that
   queries $f$ at random points and decides which case holds, and prove
   that after $k$ random queries all returning $0$, the algorithm's
   confidence is $1-2^{-k}$.
6. Explain in a short paragraph why the informal claim "a quantum computer
   solved X faster than a classical laptop's program" is not, by itself, a
   well-posed complexity statement. Rewrite it as a precise complexity
   claim using P/BPP language.

## Solutions

**1.** Let $L\in P$, witnessed by a deterministic algorithm $M$ running in
time $\text{poly}(|x|)$ with $M(x)=1$ iff $x\in L$. View $M$ as a
probabilistic algorithm that simply never reads its random tape: on every
input $x$, it still runs in the same polynomial time, and it is correct
with probability exactly $1$ (there is no randomness to be wrong about),
which certainly satisfies $\ge 2/3$. So $M$, viewed this way, witnesses
$L\in BPP$. Since $L$ was an arbitrary language in $P$, $P\subseteq BPP$.

**2.** A Las Vegas algorithm's output is *never* wrong; the randomness is
entirely in its *running time* $T(x)$, a random variable with
$\mathbb{E}[T(x)] \le \text{poly}(|x|)$. A BPP algorithm instead has a
fixed, worst-case-bounded running time on every input, but its *output* can
be wrong with probability up to $1/3$.

If you truncate a Las Vegas algorithm at $T = c\cdot\mathbb{E}[T(x)]$ steps
and output a fixed default guess whenever it hasn't halted by then, Markov's
inequality gives $\Pr[T(x) > c\,\mathbb{E}[T(x)]] \le 1/c$ — so you can say
truncation is triggered on at most a $1/c$ fraction of runs (e.g. $\le 1/3$
of runs, for $c=3$). What you *cannot* say is anything about the accuracy
of the default guess on those triggered runs: the Las Vegas guarantee only
promises correctness for runs that are allowed to finish naturally; a
forcibly-halted, incomplete computation carries no such promise, and an
arbitrary default output has no guaranteed relationship to the correct
answer at all. So the only usable bound on the *truncated* algorithm's
error probability is "at most $1/c$" (treating every triggered run as a
worst-case wrong answer) — which is a real, valid BPP-style bound, but a
strictly weaker conclusion than "the algorithm is always correct," and one
that had to be derived via Markov's inequality rather than assumed for
free from the Las Vegas property alone.

**3.** Let $X_1,\dots,X_k\in\{0,1\}$ be independent indicators of "the
$i$-th run of the algorithm is correct," with $\mathbb{E}[X_i]=p_i\ge2/3$.
Let $S=\sum_i X_i$, $\mu=\mathbb{E}[S]\ge 2k/3$. The majority vote is wrong
only if $S\le k/2$, so it suffices to bound $\Pr[S\le k/2]$.

*Variance bound for bounded variables:* for $Y$ supported on $[a,b]$,
$(Y-a)(b-Y)\ge0$ pointwise, so $\mathbb{E}[Y^2]\le(a+b)\mathbb{E}[Y]-ab$,
giving $\text{Var}(Y) = \mathbb{E}[Y^2]-\mathbb{E}[Y]^2 \le
-(\mathbb{E}[Y]-a)(\mathbb{E}[Y]-b) \le (b-a)^2/4$ (the last step: a
downward parabola in $\mathbb{E}[Y]$, maximized at the midpoint).

*Hoeffding's lemma:* for $Y$ on $[a,b]$ with $\mathbb{E}[Y]=0$, let
$\varphi(s)=\ln\mathbb{E}[e^{sY}]$. Then $\varphi(0)=0$, $\varphi'(0)=
\mathbb{E}[Y]=0$, and $\varphi''(s)=\text{Var}_s(Y)\le(b-a)^2/4$ for every
$s$ (the tilted distribution is still supported on $[a,b]$, so the variance
bound above still applies to it). By Taylor's theorem,
$\varphi(s)\le s^2(b-a)^2/8$, i.e. $\mathbb{E}[e^{sY}]\le
\exp(s^2(b-a)^2/8)$.

*Chernoff step:* apply this to $Y_i=X_i-p_i\in[-p_i,1-p_i]$, an interval of
length $1$, so $\mathbb{E}[e^{sY_i}]\le e^{s^2/8}$. For $s,t>0$, Markov's
inequality on $e^{-s(S-\mu)}\ge0$ gives
$$
\Pr[S-\mu\le-t] \le e^{-st}\,\mathbb{E}[e^{-s(S-\mu)}] = e^{-st}
\prod_{i=1}^k\mathbb{E}[e^{-sY_i}] \le e^{-st+ks^2/8}.
$$
Minimizing the exponent over $s>0$ (derivative $-t+ks/4=0 \Rightarrow
s=4t/k$) gives minimum value $-2t^2/k$, so
$$
\Pr[S-\mu\le -t] \le \exp(-2t^2/k) \quad\text{for all } t>0.
$$

*Applying it:* $\mu-k/2 \ge 2k/3-k/2 = k/6$, so $S\le k/2 \Rightarrow S-\mu
\le -k/6$. Taking $t=k/6$,
$$
\Pr[S\le k/2] \le \exp\!\left(-\frac{2(k/6)^2}{k}\right) =
\exp\!\left(-\frac{k}{18}\right).
$$
So the majority vote is wrong with probability at most $e^{-k/18}$: the
explicit constant is $c=1/18$.

**4.** We need $e^{-k/18} < 2^{-20}$. Taking natural logs (both sides
negative, inequality direction preserved after negating):
$$
-\frac{k}{18} < -20\ln 2 \iff k > 360\ln 2 \approx 360(0.693147) \approx
249.53.
$$
So $k=250$ already satisfies the inequality; since a majority vote needs
an odd number of trials to avoid ties, take $k=251$. (Any $k\ge250$
works arithmetically; $251$ is the smallest odd such $k$.)

**5.** Algorithm: draw $x_1,\dots,x_k \in \{0,1\}^n$ independently and
uniformly at random; query $f$ at each. If any query returns $1$, output
"balanced"; if all return $0$, output "constant."

Correctness: if $f\equiv0$, every query returns $0$ and the algorithm
always outputs "constant" — correctly, with certainty. If $f$ is balanced,
each independent uniform query lands in $f$'s zero-valued half of the
domain with probability exactly $1/2$ (exact balance, by the promise). The
algorithm errs (outputting "constant" for a balanced $f$) exactly when all
$k$ independent queries land in that half, which has probability
$(1/2)^k = 2^{-k}$ by independence. So the algorithm is correct with
probability at least $1-2^{-k}$ whenever $f$ is balanced, and with
probability exactly $1$ whenever $f$ is constant — overall confidence
$1-2^{-k}$ (one-sided error only, and only on the balanced case).

**6.** "A quantum computer solved X faster than a classical laptop's
program" compares two specific, fixed implementations on specific hardware
at a specific problem size — a wall-clock measurement, not an asymptotic
statement. It says nothing about how either side scales as the problem
grows, nothing about whether the classical program used was anywhere near
the best classical algorithm available (versus, say, an unoptimized
reference implementation), and nothing that survives being re-run on
better classical hardware or a smarter classical program. None of these
are complexity-class facts.

A well-posed rewrite names the relevant classes and quantifies over *all*
algorithms of the relevant type, over a growing family of instances: "for
this family of instances (indexed by size $n$), no known — or, in the
strongest form, provably no possible — polynomial-time classical
algorithm (in P, or even allowing randomness, in BPP) solves the problem,
while an explicit polynomial-size quantum circuit family does." This is
exactly the shape Day 12's BBBV lower bound gives for Grover search
(provably no possible bound, not just none known) and the shape a
rigorous statement of Shor's algorithm's advantage will need on Day 14 —
and it is exactly the class comparison ($P/BPP$ versus, once defined on
Day 15, $BQP$) that a stopwatch reading can never substitute for.

## Journal template

```
## Day 2 — Computational complexity & randomized computation
Key idea in my own words: ...
What confused me: ...
```
