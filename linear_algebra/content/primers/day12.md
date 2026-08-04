# Day 12 — Diagonalization Applications: Primer

Today's material is the payoff of the entire first month: you learn what diagonalization is *for*. Days 10–11 taught you how to diagonalize and what diagonalizability means. Today you see why this matters: once you've diagonalized a matrix, computing its powers becomes trivial. This changes everything about how you solve recurrence relations, model systems that evolve over time, and predict long-run behavior. The Fibonacci sequence is your motivating example, but the pattern applies to anything that obeys a linear recurrence: populations, financial systems, coupled differential equations discretized into difference equations. The key insight is this: convert the recurrence to a matrix equation, diagonalize, apply Theorem 12.1, and you get a closed form that evaluates instantly at any point in time.

## Warm-up

Before reading anything new, answer the flashcards at the end of `primers/day11.md`, `primers/day10.md`, and `primers/day05.md` for: Day 11, Day 10, and Day 5 (~10 min). Say each answer out loud or on paper *before* flipping. 

These three days form the complete scaffold for today's work. Day 11 answered the central question: "When can you write $A = PDP^{-1}$, and how do you diagonalize a matrix?" It taught you how to identify eigenvectors that form an independent set, package them into $P$, and discover when that's even possible. Day 10 showed you how eigenvalues and eigenvectors exist, transforming a geometric question ("which directions don't turn under $A$?") into an algebraic root-finding problem via the characteristic polynomial $\det(A - \lambda I) = 0$. Day 5 gave you Gaussian elimination and row-reduction—the computational machinery of linear algebra, connecting to determinants and inverses through the lens of rank and pivot structure. You learned that elimination never changes solutions and always produces the same rank regardless of order.

Today you harvest the payoff from all three. All this theory becomes immediately, viscerally practical. Once you have diagonalized a matrix into $A = PDP^{-1}$, computing matrix powers $A^k$ becomes effortless and transparent. You go from exponential algorithmic cost (repeated matrix multiplication) to linear cost (scalar operations). This is the day the abstract becomes concrete and useful—and you see why mathematicians invested so much effort in eigenvectors.

## The hook

The Fibonacci sequence is among the most famous patterns in mathematics: $1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, \ldots$ Each term is the sum of the two before it. The rule is simple and ancient, but asking for $F_{50}$ without writing down 50 addition steps by hand feels tedious, error-prone, and pointless. One slip anywhere in the chain corrupts the entire tail of the sequence.

Here is the transformation that changes everything. Instead of tracking one number $F_n$ at a time, stack the last two consecutive terms into a vector:
$$x_n = \begin{pmatrix}F_{n+1}\\F_n\end{pmatrix}.$$
The recurrence $F_{n+1} = F_n + F_{n-1}$ together with the trivial identity $F_n = F_n$ combine into a single matrix multiplication:
$$x_n = \begin{pmatrix}1&1\\1&0\end{pmatrix}x_{n-1} = Ax_{n-1}.$$
To travel from $x_0 = \begin{pmatrix}1\\0\end{pmatrix}$ (encoding $F_1 = 1, F_0 = 0$) all the way to $x_{50}$, you compute $A^{50}$. Fifty matrix applications compress into one matrix power. This reframing transforms the problem from "repeated addition" into "compute a matrix power"—and that is exactly what yesterday's diagonalization machinery solves. 

When you factor the Fibonacci matrix into $A = PDP^{-1}$, the eigenvalues are $\varphi = (1+\sqrt{5})/2$ (the golden ratio, $\varphi \approx 1.618$) and $\psi = (1-\sqrt{5})/2$ (its algebraic conjugate, $\psi \approx -0.618$). The golden ratio lives hidden inside the simplest recurrence rule all along—you can read it off by computing the eigenvalues of a $2 \times 2$ matrix.

Why is this valuable beyond Fibonacci? Because once you've mastered the pattern—convert recurrence to matrix, diagonalize, apply Theorem 12.1—you can solve any linear recurrence instantly. Population models (Leslie matrices in ecology), compound interest (finance), epidemic spread (SIR models), vibrating systems (coupled oscillators): they all follow linear recurrences. The formula that works for Fibonacci works for all of them.

**Key realization:** A recurrence is just a difference equation. $F_{n+1} = F_n + F_{n-1}$ says the "next state" depends linearly on the "current state." Once you translate to $x_n = Ax_{n-1}$, you've converted the recurrence into a dynamical system problem—and eigenvalues are the language of dynamical systems. That's why the entire month has been building toward today: eigenvalues tell you everything about what happens as time goes on.

## The pictures

**Picture 1: The power pipeline for $A^n = PD^nP^{-1}$.**
When $A = PDP^{-1}$ with $D$ diagonal, computing $A^n$ unfolds as a three-stage relay. Stage 1: translate the input vector into eigen-coordinates by applying $P^{-1}$ (a one-time matrix inversion, paid upfront). Stage 2: apply the diagonal power $D^n$ in that coordinate system (the cheap step—just raise each diagonal entry independently to the $n$-th power, no cross-multiplication between different rows or columns). Stage 3: translate the result back to standard coordinates via $P$ (another matrix multiply with the same $P$ you inverted in Stage 1). 

The remarkable fact is this: $P$ and $P^{-1}$ never change from one power to the next. Only the exponent $n$ in the middle slot changes. After computing $P$, $D$, and $P^{-1}$ once (the one-time eigenvalue-eigenvector work from Day 10–11), you hold the keys to every power you'll ever need: $A^1, A^2, A^{10}, A^{100}, A^{10000}$, even symbolic $A^n$ or limits like $\lim_{n \to \infty} A^n$. The same three matrices—$P$, $D$, $P^{-1}$—answer all of them. This is the essence of diagonalization's power: you pay once, use forever.

**Picture 2: Dominant eigenvalue takeover in long-run behavior.**
Start with any arbitrary vector (say, $(1, 1)$ or random numbers) and repeatedly multiply by $A$: the resulting sequence gradually aligns with the eigenvector of the eigenvalue with largest magnitude. Why does this happen? In the diagonalized coordinate system (the eigen-basis), the component along $\lambda_{\max}$ grows like $\lambda_{\max}^n$ while every other eigenvalue's component grows like $|\lambda_i|^n$ for smaller $|\lambda_i|$. After enough iterations, the dominant term overwhelms all others, and the direction of the iterate stabilizes—you are literally seeing the eigenvector of the dominant eigenvalue emerge from noise. You see this phenomenon in population biology (age-structured population models governed by Leslie matrices), in internet search algorithms (Google's PageRank via Markov chains where the steady-state distribution is the eigenvalue-$1$ eigenvector), and in disease modeling: long-run behavior follows from the dominant eigenvalue alone, regardless of the starting condition.

**Picture 3: The recurrence-to-matrix shift register.**
Any linear recurrence relation—whether Fibonacci's $F_{n+1} = F_n + F_{n-1}$, a second-order recurrence like $a_{n+1} = 3a_n - 2a_{n-1}$, or higher orders like $x_n = c_1 x_{n-1} + c_2 x_{n-2} + \cdots + c_k x_{n-k}$—can be compressed into a matrix state equation using a sliding window of history. You pack the last few consecutive terms into a single state vector, and advancing one time step becomes multiplication by a fixed companion matrix. That transformation is why today exists: once you have developed the full machinery of diagonalization, it solves every linear recurrence in one unified framework. There is no need for ad-hoc formulas per recurrence type; the same $A^n = PD^nP^{-1}$ formula works universally, whether the recurrence is second-order or twentieth-order.

**Memory hook — when you see "matrix power":**
Any time a problem asks "compute $A^k$ for large $k$" or "what happens to a system as time goes to infinity," your first thought should be: diagonalize. Ask yourself: Can I write $A = PDP^{-1}$? If yes, then $A^k = PD^kP^{-1}$ is automatic. If no (because $A$ is not diagonalizable), then you'll need a generalized Jordan form—but that's a later topic. For now, assume $A$ is diagonalizable and watch the problem simplify dramatically.

**Payoff for the month:** Today is where Days 1–11 all converge. You use vector spaces (Day 1) and basis (Day 2) to understand coordinates. You use linear transformations (Day 3) and rank-nullity (Day 4) to understand map structure. You use row reduction (Day 5) and the four fundamental subspaces (Day 6) to understand matrices concretely. You use determinants (Day 8) and invertibility (Day 9) to detect non-singularity. You use eigenvalues (Day 10) and diagonalization (Day 11) to find special directions. And today (Day 12) you apply all of it: transform the problem into the eigen-basis (Theorem 12.1), and the complexity collapses. This is how mathematics works: you build tools, then you use them to solve problems that seemed impossible before.

## Concrete-first walkthrough

**Theorem 12.1 (Powers of a diagonalizable matrix):**
If $A = PDP^{-1}$ with $D = \operatorname{diag}(\lambda_1, \dots, \lambda_n)$, then for every integer $k \ge 1$,
$$A^k = PD^kP^{-1}, \quad \text{where } D^k = \operatorname{diag}(\lambda_1^k, \dots, \lambda_n^k).$$

This theorem reveals profound computational efficiency. You diagonalize once, investing the one-time cost of finding eigenvalues and eigenvectors (the Day 10–11 machinery, roughly $O(n^3)$ operations). After that upfront investment, raising $A$ to any power $k$—whether $k = 10$, $k = 10000$, or a symbolic parameter—costs only $n$ scalar exponentiations (one per diagonal slot of $D^k$) plus the fixed overhead of two matrix multiplications (one for $PD^k$ and one for $(PD^k)P^{-1}$).

Compare this head-to-head against the naive approach. Computing $A^k$ by straightforward repeated multiplication requires $k-1$ full $n \times n$ matrix multiplications, each costing $O(n^3)$ operations, for a total of $O(n^3 k)$. Even binary exponentiation (the "fast" method taught in many courses) costs $O(n^3 \log k)$—still cubic in the matrix dimension for every power you compute. Theorem 12.1 compresses this all the way down to $O(n^3)$ one-time diagonalization plus $O(n)$ operations per new power (plus $O(n^2)$ for the final two matrix-matrix products, which is a lower-order term).

The diagonalization investment gets amortized across unlimited future powers. For computing $F_{50}$ via $A^{50}$ where $A = \begin{pmatrix}1&1\\1&0\end{pmatrix}$, you are trading 49 matrix multiplications for two scalar exponentiations ($\varphi^{50}$ and $\psi^{50}$)—an extraordinary computational win.

**Concrete numbers:** If $n = 100$ (a $100 \times 100$ matrix), one matrix multiply costs roughly $100^3 = 10^6$ operations. To compute $A^{50}$, naive repeated multiplication costs $49 \times 10^6 = 4.9 \times 10^7$ operations. Via diagonalization, you pay $O(n^3)$ once (say $10^6$ operations for eigendecomposition) plus two matrix multiplies of $P$ and $P^{-1}$ with the same matrices (roughly $2 \times 10^6$ operations). Total: roughly $3 \times 10^6$ operations instead of $5 \times 10^7$—more than a tenfold speedup. For $A^{1000}$, the naive method would cost $999 \times 10^6 \approx 10^9$ operations while diagonalization still costs the same $3 \times 10^6$.

**Converting linear recurrences to matrix form — the general technique:**
The universal technique is stacking a history window into a state vector. For Fibonacci where each term depends on exactly the two immediately before it, you form the state vector $x_n = \begin{pmatrix}F_{n+1}\\F_n\end{pmatrix}$. The recurrence relation $F_{n+1} = F_n + F_{n-1}$ paired with the identity $F_n = F_n$ produces the matrix recurrence $x_n = Ax_{n-1}$. Unrolling by repeated application gives $x_n = A \cdot A \cdots A \cdot x_0 = A^n x_0$ ($n$ factors of $A$). Now diagonalize $A = PDP^{-1}$ using the Day 11 machinery, apply Theorem 12.1, and you obtain a closed-form formula for $F_n$ (called Binet's formula in the main file). This formula evaluates instantly at any $n$ with no loop, no recursion, no accumulated rounding error. 

For a third-order recurrence like $a_{n+1} = c_1 a_n + c_2 a_{n-1} + c_3 a_{n-2}$, you would use $x_n = \begin{pmatrix}a_{n+1}\\a_n\\a_{n-1}\end{pmatrix}$ and construct a $3 \times 3$ companion matrix:
$$A = \begin{pmatrix}c_1&c_2&c_3\\1&0&0\\0&1&0\end{pmatrix}.$$
Diagonalize this $3 \times 3$ matrix (find three eigenvalues and three independent eigenvectors), and the rest follows. The method is identical regardless of recurrence order.

The main file walks through Fibonacci in meticulous detail—see Steps 1–6 of the worked example to witness the technique applied to the most famous recurrence in mathematics. Exercise 5 in the main file asks you to do the same for the recurrence $a_{n+1} = 3a_n - 2a_{n-1}$, which is a perfect practice problem to cement the technique.

**Why matrix powers matter in practice:**
Before you learned diagonalization, computing $A^{10}$ for even a $2 \times 2$ matrix required nine multiplications, each one tedious to calculate by hand. Computing $A^{100}$ would require 99 multiplies—impractical and error-prone. Computational errors accumulate with each multiply. After diagonalization, $A^{100} = PD^{100}P^{-1}$ means just computing two scalar powers ($\lambda_1^{100}$ and $\lambda_2^{100}$) plus two matrix products—fast, clean, error-free. The scalar exponentiation can be done exactly or with controlled precision. Example from the main file: for $B = \begin{pmatrix}4&-2\\1&1\end{pmatrix}$ with eigenvalues $\lambda_1 = 2, \lambda_2 = 3$, computing $B^{10}$ naively would require 9 multiplications of $2 \times 2$ matrices. Via diagonalization, you compute $2^{10} = 1024$ and $3^{10} = 59049$, arrange them into $D^{10}$, then do two $2 \times 2$ multiplies. The savings compound for larger powers and larger matrices.

**Numerical illustration with a simple example:**
Consider $A = \begin{pmatrix}2&0\\0&3\end{pmatrix}$. This is already diagonal, so $P = I$. Then $A^k = \begin{pmatrix}2^k&0\\0&3^k\end{pmatrix}$ immediately. You can compute $A^{50} = \begin{pmatrix}2^{50}&0\\0&3^{50}\end{pmatrix}$ in seconds without ever multiplying matrices. For a non-diagonal matrix like the Fibonacci matrix, the same principle applies after you diagonalize: the work collapses to scalar exponentiations in the diagonal matrix.

**Fibonacci expanded: From recurrence to closed-form formula.**

To trace the complete pipeline end-to-end, consider the Fibonacci matrix $A = \begin{pmatrix}1&1\\1&0\end{pmatrix}$ that encodes the recurrence $F_{n+1} = F_n + F_{n-1}$ as $x_n = Ax_{n-1}$. Find the eigenvalues by solving the characteristic polynomial $\det(A - \lambda I) = \lambda^2 - \lambda - 1 = 0$. The roots are $\varphi = \frac{1+\sqrt{5}}{2} \approx 1.618$ (the famous golden ratio) and $\psi = \frac{1-\sqrt{5}}{2} \approx -0.618$ (its algebraic conjugate). The golden ratio was hiding inside the simplest recurrence all along—eigenvalues reveal it instantly.

This discovery illustrates a profound truth: seemingly innocent recurrences encode deep mathematical constants in their eigenvalues.

Once you diagonalize $A = PDP^{-1}$ with $D = \operatorname{diag}(\varphi, \psi)$ (using the Day 11 machinery), Theorem 12.1 immediately delivers the closed-form Binet's formula (see the main file, Steps 1–6, for the full derivation):
$$F_n = \frac{\varphi^n - \psi^n}{\sqrt{5}}.$$
This formula computes any Fibonacci number instantly—just two scalar exponentiations and one division. No loops, no recursion, no tedious manual addition chains, no accumulated rounding error. This is the concrete payoff: the abstract eigenvalue machinery you built in Days 10–11 delivers a beautiful closed form that mathematicians and artists have pursued for centuries.

**Memory hook — the diagonalization principle:**
*"Diagonalization converts matrix powers into scalar powers."* Every time a problem asks for "compute $A^k$ for large $k$" or "what happens as $n \to \infty$?", your instinct should be: diagonalize. Transform to the eigen-basis where $A$ becomes diagonal; then scalar exponentiation is free and explicit. Invert the cost-benefit trade: spend $O(n^3)$ once to find $P$, $D$, $P^{-1}$, then spend only $O(n)$ per new exponent $k$. If $A$ is not diagonalizable, you'll need the Jordan normal form—but for now, diagonalizable matrices are your fundamental workhorse.

**Where this pattern lives beyond Fibonacci:**
Population ecology uses Leslie matrices to predict age-structured population growth rates via the dominant eigenvalue: $|\lambda_{\max}| > 1$ means exponential growth, $< 1$ means decline. Markov chains stabilize to steady-state distributions encoded in the $\lambda = 1$ eigenvector—Google's PageRank algorithm is built on exactly this idea, treating the web graph as a massive stochastic matrix. Epidemic models compute the basic reproduction number $R_0$ as the dominant eigenvalue of the next-generation matrix, telling epidemiologists whether a disease will die out or spread. Coupled harmonic oscillators vibrate in normal modes (the eigenvectors) at frequencies tied to eigenvalues. Discrete dynamical systems in finance (compound returns), chemistry (reaction kinetics), and control theory (feedback stability) all boil down to this one insight. Every linear system evolving over discrete time steps—from biology to finance to engineering—follows the same pipeline: write the recurrence as $x_n = Ax_{n-1}$, diagonalize, apply Theorem 12.1, extract dynamics from eigenvalues and eigenvectors. This is the universal lingua franca of applied mathematics.


**Long-run behavior from eigenvalue magnitudes — the decisive fact:**
For a linear difference equation $x_n = Ax_{n-1}$ with $A$ diagonalizable, the fate of the sequence as $n \to \infty$ depends entirely on $\lambda_{\max}$ (the eigenvalue with largest absolute value):
- If $|\lambda_{\max}| > 1$: the norm of $x_n$ grows exponentially, and the sequence diverges toward infinity at an exponential rate proportional to $|\lambda_{\max}|^n$.
- If $|\lambda_{\max}| = 1$: the sequence persists with bounded amplitude, neither exploding nor collapsing, instead oscillating or settling to a fixed distribution.
- If $|\lambda_{\max}| < 1$: the sequence decays exponentially to the zero vector as $n \to \infty$, at a rate controlled by $|\lambda_{\max}|^n$.

For Fibonacci, $|\varphi| \approx 1.618 > 1$, so Fibonacci numbers grow exponentially, roughly like $\varphi^n$. Each Fibonacci number is approximately the previous one times $\varphi$. For a damped spring or other dissipative system, $|\lambda_{\max}| < 1$, so any perturbation from equilibrium decays away completely—the system returns to rest. For a Markov chain (a stochastic matrix where every row sums to 1, making the dominant eigenvalue exactly $1$ by construction), this explains why populations reach a steady-state distribution: the long-run behavior is convergence to the stationary distribution, which is the normalized eigenvector for $\lambda = 1$. This is why Markov chains don't diverge or collapse—the structure of stochastic matrices guarantees the dominant eigenvalue is exactly $1$.

**Application hint:** The next time you see a problem asking "what happens as $n \to \infty$?" in any applied context (biology, economics, physics, social science), your first instinct should be: find the dominant eigenvalue. If $|\lambda_{\max}| < 1$, the system stabilizes. If $|\lambda_{\max}| > 1$, it explodes. If $|\lambda_{\max}| = 1$, it oscillates or holds steady. That single eigenvalue tells you the fate of the entire system.

## Proof roadmaps

**Theorem 12.1 proof — induction with telescoping:**
Induction on $k$: the inductive step hinges on one telescoping cancellation. From $A^k = PD^kP^{-1}$, we compute
$$A^{k+1} = A \cdot A^k = (PDP^{-1})(PD^kP^{-1}) = P \cdot D \cdot (P^{-1}P) \cdot D^k \cdot P^{-1} = P \cdot D \cdot D^k \cdot P^{-1} = PD^{k+1}P^{-1}.$$
The middle $P^{-1}P = I$ telescopes away; that's the entire engine.

P-similarity gives you conjugacy; the eigenvalue structure does the rest.

## Flashcards

The flashcards below target the key ideas: the formula itself (Theorem 12.1), how to set up recurrences as matrices, why long-run behavior matters, and where the golden ratio comes from. Use these to lock in the day's core concepts before tackling the exercises and code lab in the main file. The questions progress from the mechanics (how to compute $A^k$) to the applications (what does it tell you about a system?). First work through the mechanics questions until they feel automatic. Then move to the applications—those questions connect today's machinery to the real world.

### Flashcards

**Q:** State Theorem 12.1 precisely and explain its computational advantage over repeated matrix multiplication.

**A:** If $A = PDP^{-1}$, then $A^k = PD^kP^{-1}$ where $D^k = \operatorname{diag}(\lambda_1^k, \ldots, \lambda_n^k)$. Instead of $k-1$ full $n \times n$ matrix multiplications at $O(n^3)$ each (total $O(n^3 k)$ or $O(n^3 \log k)$ with binary exponentiation), you perform $n$ independent scalar exponentiations plus fixed $O(n^2)$ overhead for two matrix-matrix multiplies. For large $n$ or large $k$, the savings are dramatic.

**Q:** Convert the Fibonacci recurrence $F_{n+1} = F_n + F_{n-1}$ into matrix form $x_n = Ax_{n-1}$.

**A:** Stack consecutive terms into the state vector $x_n = \begin{pmatrix}F_{n+1}\\F_n\end{pmatrix}$, giving $x_n = \begin{pmatrix}1&1\\1&0\end{pmatrix}\begin{pmatrix}F_n\\F_{n-1}\end{pmatrix} = Ax_{n-1}$. Then $x_n = A^n x_0$ with initial state $x_0 = \begin{pmatrix}1\\0\end{pmatrix}$. Once you've set up the matrix form, the rest is automatic: diagonalize, apply Theorem 12.1, and extract $F_n$ from the resulting vector.

**Q:** If $A$ is diagonalizable with eigenvalues ordered by magnitude as $|\lambda_1| > |\lambda_2| > \cdots > |\lambda_n|$, describe the long-run behavior of $A^n x$ as $n \to \infty$ for a generic starting vector.

**A:** The sequence aligns with the eigenvector of $\lambda_1$ and grows or shrinks like $|\lambda_1|^n$. Other eigenvalue contributions become negligible because their ratios to the dominant term decay like $(|\lambda_i|/|\lambda_1|)^n \to 0$. This is why $\lambda_1$ is called the "dominant" eigenvalue—it eventually controls the entire behavior, regardless of starting point or smaller eigenvalues.

**Q:** What does the magnitude of the dominant eigenvalue $\lambda_{\max}$ predict about the long-run behavior of the system $x_n = Ax_{n-1}$?

**A:** If $|\lambda_{\max}| > 1$: exponential growth (sequence diverges). If $|\lambda_{\max}| = 1$: bounded amplitude (sequence oscillates or stabilizes). If $|\lambda_{\max}| < 1$: exponential decay to zero.

**Q:** Where does the golden ratio $\varphi = (1+\sqrt{5})/2$ appear in the Fibonacci sequence, and how does diagonalization reveal it?

**A:** It is the dominant eigenvalue of the Fibonacci matrix $\begin{pmatrix}1&1\\1&0\end{pmatrix}$. Binet's formula (derived in the main file) is $F_n = \frac{\varphi^n - \psi^n}{\sqrt{5}}$, showing that Fibonacci grows at the golden ratio's exponential rate.

**Q:** Why is computing $A^k = PD^kP^{-1}$ more efficient than computing $A^k$ via repeated matrix multiplication?

**A:** Powering a diagonal matrix costs only $n$ scalar exponentiations (one per diagonal entry). You avoid $k-1$ full $n \times n$ multiplications at $O(n^3)$ each. The complexity trades from $O(n^3 k)$ naive or $O(n^3 \log k)$ with binary exponentiation, down to $O(n^3)$ for diagonalization (one-time) plus $O(n)$ per new power (just scalar operations). For $n=100$ and $k=1000$, that's a tenfold or better speedup. For $n=1000$ and large $k$, the speedup becomes enormous.

---

**Study strategy for today:** 
(1) State Theorem 12.1 from memory and sketch its proof (the induction + telescoping). 
(2) Practice converting one recurrence (not Fibonacci—try Exercise 5 from the main file, $a_{n+1} = 3a_n - 2a_{n-1}$) into matrix form and diagonalizing it end-to-end. 
(3) Write down the eigenvalues of any $2 \times 2$ or $3 \times 3$ matrix and predict the long-run behavior: growth, decay, or stability before computing anything. 
(4) Read the worked example in the main file (Steps 1–6) on Binet's formula; that is exactly what you just practiced.
(5) Do the code lab: reproduce Fibonacci both ways (direct diagonalization and NumPy's matrix_power) and confirm they agree.

That intuition—reading the fate of a system off its eigenvalues—is the real payoff from understanding eigenvalues.
