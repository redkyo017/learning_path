# Day 26 Primer — Trace, Determinant, Cholesky Bridge

## Warm-up

You've spent the past week climbing the spectral mountain. Day 19 showed you that symmetric matrices decompose perfectly into eigenvalue and eigenvector pairs, revealing their internal structure layer by layer. Day 23 applied that power to real data through PCA, showing how eigenvectors align with the directions of maximum variance—turning theory into machine learning. Day 25 taught you that similarity transformations and basis changes both respect the eigenvalue structure underneath; no matter what coordinate system you choose, the eigenvalues stay the same.

They are invariant, a hidden skeleton that no linear change of perspective can alter. This week you've proven that symmetric matrices are diagonalizable; their eigenvalues and eigenvectors capture everything that matters for quadratic forms and dimension reduction.

Now comes the practical payoff: two simple formulas that let you verify every eigenvalue calculation you'll ever do before trusting it. Before you compute eigenvalues laboriously by hand or before you rely on a numerical solver's answer, you'll learn to ask a quick sanity-check question: does the sum of the eigenvalues equal the trace, and does their product equal the determinant? Those are free, five-second checks built into every matrix by the structure of the characteristic polynomial itself.

Why does this matter? Because eigenvalue computation by hand is error-prone. You'll solve a characteristic polynomial, collect roots, and suddenly want to know: did I mess up the arithmetic? The trace-and-determinant test is an instant verification gate. It won't find every error, but it catches the most common ones—misplaced signs, dropped factors, arithmetic slips. Even better: it's a free check that takes five seconds and requires no new computation; you just add and multiply what you've already found.

Today you'll see exactly why those checks work—the mechanism tying trace and determinant to eigenvalues through the structure of the characteristic polynomial—and you'll meet Cholesky decomposition, the triangular "square root" that makes positive definite matrices as easy to work with as positive numbers, closing the story that began on Day 20 with the spectral theorem. Together, these tools give you both a verification strategy and a computational shortcut for the matrices you care most about in applications.

## The hook

Every time you find eigenvalues of a matrix—whether by hand using the characteristic polynomial, by computer via a numerical eigensolver, or by inspired guessing—the result must pass two strict tests built into the very definition of the characteristic polynomial itself.

First, the eigenvalues must sum to the trace of the matrix. You calculate this trace in literally five seconds by adding the diagonal entries of the original matrix. No computation needed; it's just reading off the diagonal. Second, the eigenvalues must multiply to the determinant of the matrix. For a $2 \times 2$ matrix this is a single arithmetic formula, and for larger matrices it's a number you've probably computed already.

These aren't just nice coincidences or convenient shortcuts. They're hard constraints that follow directly from how the characteristic polynomial factors. If your eigenvalues fail either check, they are wrong, and you need to recalculate. This is not optional—it's a mathematical fact embedded in the definition of the characteristic polynomial. No exceptions.

Consider a concrete example: with $A = \begin{pmatrix}4&1\\2&3\end{pmatrix}$ from earlier in the course, suppose you found eigenvalues $\lambda = 5, 2$ by solving $\det(A - \lambda I) = 0$. Now check: does $5 + 2 = 7$ equal the trace $4 + 3 = 7$? Yes. Does $5 \times 2 = 10$ equal the determinant $4 \cdot 3 - 1 \cdot 2 = 10$? Yes. Both pass, so you can trust those eigenvalues.

But suppose a careless arithmetic mistake led you to write down eigenvalues $5, 3$ instead. The sum is $5 + 3 = 8 \neq 7$, an immediate red flag. The product is $5 \times 3 = 15 \neq 10$, another loud alarm. You would catch the error instantly without having to redo the entire calculation.

Here's another example: for a $3 \times 3$ matrix with eigenvalues $2, -1, 3$, what must the trace and determinant be? The trace must be $2 + (-1) + 3 = 4$. The determinant must be $2 \cdot (-1) \cdot 3 = -6$. If someone told you the eigenvalues were $2, 1, 3$ instead, you'd immediately see it's wrong: that sum is 6, not 4. If they said $2, -1, 4$, you'd catch it: that product is $-8$, not $-6$. These checks are foolproof once you compute a single trace and determinant. The point: build this verification habit into every eigenvalue calculation you do.

This error-detection mechanism is the heart of today's main theorem. It's invaluable in practice: you never trust eigenvalue output blindly. You verify it against these two checks first. Always verify. Alongside the theorem comes a second practical tool: Cholesky decomposition, which extends the power of positive definite matrices into numerical algorithms used everywhere in statistics and machine learning.

## The pictures

The core insight of Theorem 26.1 is captured visually by imagining the characteristic polynomial dressed in two different "costumes" at once. You already know what the characteristic polynomial is from Days 10 and beyond, but today we're seeing two different faces of the same object, and that duality is where the magic happens.

**Picture 1: Two expressions for the characteristic polynomial.**
On the left side, you expand $\det(A - \lambda I)$ using the standard Leibniz definition of determinant, summing over all permutations of columns and multiplying corresponding entries. You collect terms by their power in $\lambda$, arranging them as a polynomial in descending degree. This expansion is mechanical but messy—you sum over $n!$ permutations. The result is a degree-$n$ polynomial in $\lambda$ with coefficients built from entries of $A$. On the right side, you write that exact same polynomial in its factored form, $\prod_{i=1}^n (\lambda - \lambda_i)$, because you know the roots are the eigenvalues $\lambda_1, \ldots, \lambda_n$ (with multiplicities, possibly complex). This factored form is clean and conceptual—the roots are eigenvalues, and the coefficients of this expansion are built from sums and products of eigenvalues.

Here is the key point: each side is the same polynomial, so their coefficients must match term for term. The coefficient of $\lambda^{n-1}$ on the right side is $\pm \sum_i \lambda_i$ (from expanding the product), and on the left side it is $\pm \operatorname{trace}(A)$ (from the Leibniz expansion structure)—they must be equal. The constant term (degree zero) on the right is $\pm \prod_i \lambda_i$, and on the left it is $\pm \det(A)$—they must be equal. This "two costumes, one polynomial" picture is the entire theorem. That's all you need to remember: match coefficients on the same degree, and the formulas appear.

**Picture 2: Checksum verification workflow.**
After computing eigenvalues by any method, immediately perform two verification steps. First, add up all the eigenvalues—does the sum equal the matrix's trace (diagonal sum)? Second, multiply all the eigenvalues—does the product equal the matrix's determinant? Only after both checksums pass do you trust the eigenvalues and move forward. This workflow catches errors before they propagate through subsequent calculations, which is critical when you're using eigenvalues for prediction, optimization, or simulation. The two checks are your safety valve. In practice: compute trace (read diagonal), compute determinant (use formula or prior computation), compute eigenvalues (solve characteristic polynomial), verify sum and product match, then proceed. This five-minute insurance saves hours of debugging.

**Picture 3: Cholesky as a matrix square root.**
Cholesky shows the matrix world mirrors the number world. For every positive real number $a > 0$, there exists a unique positive square root $\sqrt{a}$ satisfying $(\sqrt{a})^2 = a$. Analogously, for every symmetric positive definite matrix $A$, there exists a unique lower-triangular matrix $L$ with positive diagonal entries such that $A = LL^T$. This matrix $L$ is called the Cholesky factor, and the decomposition $A = LL^T$ is the Cholesky decomposition. Just as the square root of a positive number encodes its "size" in a single number, the Cholesky factor $L$ encodes the structure of a positive definite matrix in triangular form, making it practical for sampling, solving linear systems, and optimization algorithms.

## Concrete-first walkthrough

Theorem 26.1 states two parallel formulas—the two eigenvalue checksums:
$$\operatorname{trace}(A) = \sum_i \lambda_i \quad \text{and} \quad \det(A) = \prod_i \lambda_i$$

This is the slogan you should remember: **trace equals sum of eigenvalues, determinant equals product of eigenvalues—the two conserved arithmetic quantities.** They're the sum and product of the roots of the characteristic polynomial. Remember: any time you compute eigenvalues, verify these two formulas hold. If they don't, your eigenvalues are wrong.

Why are these formulas true? The answer lies in a clever observation about polynomials. The characteristic polynomial $p(\lambda) = \det(A - \lambda I)$ is a degree-$n$ polynomial in $\lambda$. This polynomial can be written two ways: as a Leibniz expansion (messy but explicit) and as a product of linear factors (clean but requires roots). Since both are the same polynomial, their coefficients match, and from that matching you extract both the trace and determinant formulas for free.

The why-it-works hook rests on one elegant observation about the Leibniz expansion of $\det(A - \lambda I)$. When you expand this determinant as a sum over all permutations, each permutation picks exactly one entry from each row and each column. The only way to collect a term with power $\lambda^{n-1}$ is to pick exactly $n-1$ diagonal entries (of the form $a_{ii} - \lambda$, each containing a power of $\lambda$) and exactly one off-diagonal entry (which contains no $\lambda$). This is a combinatorial constraint that forces only the identity permutation to contribute to the $\lambda^{n-1}$ term.

But here's the trap: if you pick an off-diagonal entry from any row $i$ and column $j$ with $i \neq j$, that entry is not from the diagonal, so you automatically exclude at least two diagonal positions from your product. This means you have at most $n-2$ diagonal factors left to contribute $\lambda$-powers, capping the degree at $n-2$. Therefore, only the product of all diagonal entries, $\prod_{i=1}^n(a_{ii} - \lambda)$, can reach degree $n-1$ in $\lambda$. This is the key insight.

Matching this coefficient between the Leibniz side and the factored form $\prod_i(\lambda_i - \lambda)$ immediately yields the trace formula. To derive the determinant formula, use a quick trick: set $\lambda = 0$ in both sides of the characteristic polynomial equation. On the left, $\det(A - 0 \cdot I) = \det(A)$. On the right, $\prod_i(0 - \lambda_i) = (-1)^n \prod_i(-\lambda_i) = (-1)^n(-1)^n \prod_i \lambda_i = \prod_i \lambda_i$ (after canceling signs). Thus $\det(A) = \prod_i \lambda_i$. Both formulas drop right out of matching a single polynomial against itself in two forms.

The Cholesky decomposition (stated as a Remark in the main file) is the second major concept. It says that every symmetric positive definite matrix $A$ admits a unique factorization $A = LL^T$ where $L$ is lower-triangular with positive diagonal entries. This decomposition is the spectral theorem's square root, repackaged into triangular form.

What does this mean in practice? It means you can write any symmetric positive definite matrix $A$ as a product of a lower-triangular matrix $L$ and its transpose $L^T$. The matrix $L$ is your Cholesky factor. Why is this useful? Because triangular matrices are easy to work with: solving linear systems with a triangular matrix requires only forward or backward substitution, which is $O(n^2)$ instead of $O(n^3)$. This speed boost is why Cholesky factors are ubiquitous in scientific computing.

It appears everywhere in numerical computing: sampling from multivariate Gaussian distributions requires computing $L$ to generate correlated samples as $L z$ where $z$ is standard normal; numerical optimization uses Cholesky factors in algorithms like Cholesky gradient descent to ensure stability and efficiency; many linear solvers exploit the triangular structure for speed. The computational benefits are enormous.

Crucially—and this is a common pitfall—Cholesky requires strict positive definiteness. A single zero eigenvalue (making the matrix merely semidefinite) breaks the decomposition completely. Exercise 5 of the main file shows this explicitly: the matrix $\begin{pmatrix}4&2\\2&1\end{pmatrix}$ has eigenvalues $0, 5$ and is only semidefinite, so Cholesky does not apply, and the decomposition $LL^T = A$ has no solution with $L$ lower-triangular and positive diagonal. Always check: all eigenvalues must be strictly positive before you attempt Cholesky.

## Proof roadmaps

Theorem 26.1 (Trace and determinant via eigenvalues) is proven by one central idea: **one polynomial, two costumes; match coefficients.** Here is the complete roadmap for understanding how the proof works.

**The central principle: matching polynomials.**
The characteristic polynomial $p(\lambda) = \det(A - \lambda I)$ can be written in two completely different ways: as a messy Leibniz expansion over permutations (the "expanded costume") or as a clean factored product over roots (the "factored costume"). Since these are the same polynomial, coefficients must match. That's it. That's the entire proof strategy. Every degree has a coefficient on both the left side and the right side, and those coefficients must be equal. From that single principle, both the trace formula and the determinant formula fall out immediately.

**Step 1: Write the characteristic polynomial in factored form.** 
Write $p(\lambda) = \det(A - \lambda I) = \prod_{i=1}^n(\lambda - \lambda_i)$, where the product is taken over all eigenvalues with their algebraic multiplicities. The list includes complex eigenvalues if the matrix is not symmetric. This factorization is valid over $\mathbb{C}$ by the fundamental theorem of algebra. The roots of $p$ are the eigenvalues, with multiplicity. This is the "second costume"—the factored form. It's clean and reveals the roots directly. You know this form is correct because it captures the complete factorization of the degree-$n$ polynomial over the complex numbers.

**Step 2: Determinant formula via evaluation at $\lambda = 0$.** 
Evaluate $p(\lambda)$ at $\lambda = 0$ on both sides. The left side gives $\det(A - 0 \cdot I) = \det(A)$ (direct definition). The right side gives $\prod_i(0 - \lambda_i) = (-1)^n\prod_i(-\lambda_i) = (-1)^n(-1)^n\prod_i\lambda_i = \prod_i\lambda_i$ after canceling signs carefully. Therefore $\det(A) = \prod_i \lambda_i$. Done in one line. This is why the constant term of the characteristic polynomial is always the determinant (up to sign).

**Step 3: Trace formula via coefficient matching.** 
Expand $\det(A - \lambda I)$ using the Leibniz/permutation definition of determinant, collecting terms by degree in $\lambda$. Every permutation $\sigma$ contributes a product of $n$ entries, each from a different row and column. To get a $\lambda^{n-1}$ term, you must pick exactly $n-1$ entries from the diagonal (each containing a power of $\lambda$) and exactly one off-diagonal entry (containing no $\lambda$).

But here's the constraint: using any off-diagonal entry forces at least two diagonal positions to be skipped. Why? Because each permutation picks exactly one entry per row and per column. If you pick entry $(i, j)$ with $i \neq j$, that permutation skips both position $i$ in the diagonal entries (used elsewhere) and position $j$ in the diagonal entries (used for row $j$'s entry). This means you collect at most $n-2$ diagonal factors total, capping the degree at $n-2$. Therefore, the only permutation reaching degree $n-1$ is the identity permutation, giving product $\prod_i(a_{ii} - \lambda)$.

The coefficient of $\lambda^{n-1}$ in this product is $(-1)^{n-1}\sum_i a_{ii} = (-1)^{n-1}\operatorname{trace}(A)$. This is the "first costume"—the Leibniz expansion. It's the explicit expansion of the determinant formula you know from Day 1.

The factored form $\prod_i(\lambda - \lambda_i)$ expands to $\lambda^n - (\sum_i\lambda_i)\lambda^{n-1} + \text{lower degrees}$. Reading off the coefficient of $\lambda^{n-1}$ gives $(-1)^{n-1}(\sum_i\lambda_i)$. Now match the two costumes: $(-1)^{n-1}\operatorname{trace}(A) = (-1)^{n-1}(\sum_i\lambda_i)$, so $\operatorname{trace}(A) = \sum_i\lambda_i$. Done. (See Theorem 26.1 in the main file for complete sign-tracking and full proofs of all details.)

You now have two powerful tools at your disposal. First, Theorem 26.1 gives you a free error-detection mechanism: any time you compute eigenvalues, you can instantly verify them against the trace and determinant without additional work. Second, the Cholesky decomposition shows that symmetric positive definite matrices have a hidden triangular structure that makes them computationally friendly. Together, these tools form the bridge from the theory of spectral decomposition (Days 19–25) into the practice of numerical algorithms.

Remember the slogans: **trace = sum of eigenvalues, determinant = product of eigenvalues.** These are not optional facts—they're consequences of the polynomial structure of the characteristic polynomial itself. Verify them every time. And remember: Cholesky needs strict positive definiteness, not just semidefiniteness. A single zero eigenvalue kills it.

## Flashcards

### Flashcards

**Q:** What are the two eigenvalue checksums?

**A:** $\sum_i \lambda_i = \operatorname{trace}(A)$ and $\prod_i \lambda_i = \det(A)$.

---

**Q:** How do you get $\det(A) = \prod_i \lambda_i$ in one move?

**A:** Set $\lambda = 0$ in both sides of $\det(A - \lambda I) = \prod_i(\lambda - \lambda_i)$ to read off the constant term.

---

**Q:** Why does only the diagonal product contribute to the $\lambda^{n-1}$ coefficient in $\det(A - \lambda I)$?

**A:** Using any off-diagonal entry in the Leibniz expansion forfeits at least two diagonal factors, reducing the degree in $\lambda$ to at most $n-2$.

---

**Q:** What is the Cholesky decomposition and for which matrices does it exist?

**A:** Cholesky decomposition is $A = LL^T$ with $L$ lower-triangular and positive diagonal; it exists uniquely for symmetric positive definite matrices.

---

**Q:** What is the everyday use of the trace and determinant checksums?

**A:** An instant self-check after any eigenvalue computation—if the eigenvalues don't sum to the trace or multiply to the determinant, your calculation is wrong.

---

**Q:** What is the number analogy for the Cholesky decomposition?

**A:** Cholesky is the matrix version of taking the square root: $A = LL^T$ mirrors $a = (\sqrt{a})^2$ for positive numbers $a > 0$.

---

**Q:** Why does Cholesky fail for semidefinite matrices?

**A:** A zero eigenvalue makes the matrix singular or nearly singular, so $LL^T = A$ with $L$ lower-triangular and positive diagonal has no solution; uniqueness and existence both fail.

---

**Q:** What is the connection between Cholesky and the spectral theorem?

**A:** Cholesky repackages the spectral decomposition $A = Q\Lambda Q^T$ (with $Q$ orthogonal and $\Lambda$ positive diagonal) into the triangular form $A = LL^T$ via Gram-Schmidt. The spectral form is conceptual; the Cholesky form is computational.

---

**Q:** What single property of Theorem 26.1 makes it useful as an error-checking tool?

**A:** It gives you two free checksums (trace and determinant) that are easy to compute and must hold for any eigenvalue calculation, so you catch arithmetic errors immediately.

---

**Q:** How would you summarize the relationship between the characteristic polynomial and Theorem 26.1?

**A:** The characteristic polynomial is a single object with two faces—expanded form and factored form—and their coefficient matching gives you both formulas automatically.
