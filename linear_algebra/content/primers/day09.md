# Day 9 Primer — Invertibility, Inverse, LU

Welcome to Day 9. Today's focus is on computing matrix inverses and factoring matrices into a product $A = LU$. These are among the most practical algorithms in all of linear algebra, used millions of times daily in engineering, science, finance, and machine learning. You'll see that the theoretical tool—elementary matrices and row operations—connects directly to computation. By the end of today, you'll understand why Gauss-Jordan elimination (not the adjugate formula) computes inverses in practice, why LU decomposition is the industrial standard for solving systems repeatedly with the same coefficient matrix, and how all of this connects to the rank and pivots you learned on Day 6.

## Warm-up: Review Days 8, 6, 2

From Day 8 (determinants), you met the adjugate formula $A^{-1} = \frac{1}{\det A}\text{adj}(A)$ and saw that $\det A = 0$ exactly when $A$ is singular. This formula is theoretically elegant—it ties invertibility directly to a single number—but computationally disastrous: computing the adjugate for large matrices requires $n^2$ cofactor expansions, each itself an $(n-1) \times (n-1)$ determinant. For a $100 \times 100$ matrix, this is hundreds of thousands of nested determinant computations. Impractical for real problems.

From Day 6 (rank and the Fundamental Theorem of Linear Algebra), you learned that *rank equals the number of pivots* and that an $n \times n$ matrix is invertible iff its rank is $n$ (equivalently, iff it has $n$ pivots). You also learned the rank-nullity formula: $\operatorname{rank}(A) + \dim N(A) = n$. For an invertible matrix, the null space is trivial—only the zero vector solves $Ax = 0$—so the null space has dimension $0$, forcing rank to equal $n$. Pivots are the key: invertible = $n$ pivots in an $n \times n$ matrix. This is a *computational* test for invertibility.

From Day 2 (row reduction), you learned the three elementary row operations: row swap (exchange two rows), row scale (multiply a row by a nonzero constant), and row add (add a multiple of one row to another). These operations don't change the rank or invertibility of a matrix. This is the key insight: row reduction preserves the fundamental properties we care about. A matrix remains invertible or singular through any chain of row operations; only the representation changes. This is why row reduction is safe to use in theory and computationally efficient in practice.

Today you'll see how these threads tie together: invertible means "reachable from $I$ by row reduction," and that equivalence is why Gauss-Jordan elimination (not the adjugate formula) is the *standard* method for computing $A^{-1}$ in practice. The adjugate is beautiful theory for small, symbolic problems. Row reduction is beautiful and practical for computation.

## The hook

Real computation doesn't solve $Ax = b$ once—it solves it 1000 times for the same $A$ but 1000 different right-hand sides $b_1, b_2, \ldots, b_{1000}$. This scenario is ubiquitous in engineering and science: one physical system (same $A$), many forcing terms or loads (different $b$'s), or one design with many test cases. Real examples: a finite-element structural analysis runs the same stiffness matrix $K$ against loads at different positions; a circuit analysis solves the same admittance matrix $Y$ for different voltage sources; a machine-learning problem solves the same Gram matrix repeatedly. One wasteful approach: run Gaussian elimination from scratch 1000 times. Wasteful because the cleanup moves that zero out entries below the pivot in column 1 depend only on $A$, not on which $b$ you're solving for—you're redoing 90% of the same arithmetic 999 times over.

Two smarter fixes:
1. **Compute $A^{-1}$ once.** Then for each $b$, compute $x = A^{-1}b$ (one matrix-vector product). Saves elimination repeats, but forming and storing $A^{-1}$ is expensive (roughly $n^3$ flops to compute), and rounding errors can accumulate when $A$ is nearly singular (ill-conditioned). Also, you now have $n^2$ entries to store and move around. In floating-point arithmetic, forming $A^{-1}$ explicitly can magnify small computational errors.
2. **Keep the *receipt* of elimination.** Factor $A = LU$ (lower times upper). For each new $b$, solve $LUx = b$ in two cheap passes: first $Ly = b$ by forward substitution (scanning top to bottom, since $L$ is lower triangular with known structure), then $Ux = y$ by back substitution (scanning bottom to top, since $U$ is upper triangular). This avoids ever forming $A^{-1}$, is numerically safer (triangular systems are easier to solve accurately because back-substitution is inherently stable), and is almost always faster in practice. The LU factorization is the industrial standard for this reason.

**Warm-up puzzle.** To undo "put on socks, then shoes," you must undo in *reverse order*: take off shoes first, then socks. You cannot take off socks while shoes are on—the order matters! This is exactly why $(AB)^{-1} = B^{-1}A^{-1}$ (Theorem 9.1b). The inverse of a product reverses the order. Verify it algebraically: $(AB)(B^{-1}A^{-1}) = A(BB^{-1})A^{-1} = AIA^{-1} = I$. The middle factors collapse, leaving outer factors to cancel. Not coincidence—a deep principle of inverse operations. Same logic applies to longer chains: $(ABC)^{-1} = C^{-1}B^{-1}A^{-1}$.

When you work through problems today, keep this principle in mind. Every time you see a product of two invertible matrices, ask yourself: "what happens when I invert this product?" The answer is always the reverse order. This principle extends to higher powers too: $(A^3)^{-1} = (A^{-1})^3$ because you're undoing three applications of $A$.

## The pictures

**Picture 1: Gauss-Jordan inversion.** Augment $A$ with the identity $I$ on the right to form the block matrix $[A \mid I]$. Apply the same row operations that reduce $A$ to $I$ to both halves in parallel. When done, the left block becomes $I$ and the right block becomes $A^{-1}$. Why? Because the row operations represent left-multiplication by a chain of elementary matrices $E_k \cdots E_1$. When applied to $A$, you get $E_k \cdots E_1 A = I$, so by Definition 9.1 (with $B = E_k \cdots E_1$), the product $E_k \cdots E_1$ is exactly $A^{-1}$. That same chain applied to $I$ gives $E_k \cdots E_1 I = A^{-1}$, which is precisely what the right block accumulates. No extra computation—the side-by-side algorithm computes both simultaneously, exploiting the fact that applying an elementary operation to a block matrix applies it to both blocks. This is Theorem 9.2's constructive proof in action.

Concretely: if you scale row 1 by $2$ in the augmented matrix, that row operation affects both the left and right halves. The right half keeps pace with the left, accumulating the same product of elementary matrices. This is why you never have to compute the elementary matrices explicitly—the right block does the accumulation for you.

**Picture 2: LU as a receipt.** Elimination without row swaps factors $A = LU$ where:
- $U$ = the upper-triangular echelon form you reach at the end (the "cleaned" matrix).
- $L$ = unit lower triangular with $1$'s on the diagonal; strictly-below-diagonal entries are the *multipliers you used* during elimination, placed at the exact $(i, j)$ positions where you eliminated entry $(i,j)$.

Concrete example: if you clear $(3,1)$ by doing $R_3 \to R_3 - 2R_1$, the multiplier $2$ goes into position $(3,1)$ of $L$. If you then clear $(3,2)$ from the new row 3 by doing $R_3 \to R_3 - 5R_2$, the multiplier $5$ goes into position $(3,2)$ of $L$. The beauty: you read $L$ directly off the board as you eliminate; no matrix inversion needed. This shortcuts the proof of Theorem 9.3 into a practical algorithm. It's also why the LU factorization is so popular in computational practice: it's literally the elimination process itself, written in matrix form, and reusable for any right-hand side. Once you have $L$ and $U$, you can solve any system $Ax = b$ by first solving $Ly = b$ (which is fast because $L$ is lower triangular with $1$'s on the diagonal) and then solving $Ux = y$ (which is fast because $U$ is upper triangular).

**Picture 3: Socks & shoes.** Draw a sequence: $A \xrightarrow{B} C$ (first apply $B$, then $A$). To undo (reverse the sequence), you must invert in reverse order: $C \xrightarrow{B^{-1}} \square \xrightarrow{A^{-1}} A$ (first undo $B$, then undo $A$). So $(AB)^{-1} = B^{-1}A^{-1}$. Write it down and underline the reversal: *the order flips*. This is the intuition behind Theorem 9.1b, and it extends to products of any length. If you have five transformations chained together, undoing them all means reversing the order completely: the last one inverted must go first in the inverse chain.

Example to cement this: if I first rotate a sheet of paper 45 degrees, then flip it upside down, the inverse sequence is: first flip it upright again (undo the flip), then rotate back -45 degrees (undo the rotation). Not the other way around. The order of undoing is the reverse of the order of doing.

## Concrete-first walkthrough

Read Definition 9.1 (invertible matrix): $A$ is invertible iff there exists a matrix $B$ with $AB = BA = I$. This two-sided condition is crucial—you need both $AB = I$ and $BA = I$ for the full definition, though if one holds and $A$ is square, the other follows automatically (a subtlety when $A$ is not square; for rectangular matrices, left and right inverses are different and not always both possible). The key fact, Theorem 9.1a, is **uniqueness**: if such a $B$ exists, it is unique, so we write it as $A^{-1}$ (not "an inverse," but "the" inverse). No ambiguity. This uniqueness is what lets you treat $A^{-1}$ as *the* matrix that undoes $A$, not one of many possibilities.

Why is uniqueness important? Because it means the inverse is well-defined. You can write statements like "$x = A^{-1}b$" and know you're talking about a specific matrix, not a collection of possible solutions. In computation, this is essential: an algorithm for computing $A^{-1}$ can be trusted to produce a single, canonical answer.

Next, Definition 9.2 defines elementary matrices: matrices obtained by applying a single row operation to $I_n$. There are three types: swap (row $i$ and $j$ of $I$ swapped), scale (row $i$ of $I$ scaled by $c \ne 0$), and add (row $i$ of $I$ replaced by row $i$ plus $c$ times row $j$). These matrices encode row operations as multiplication. Each elementary matrix differs from $I$ in a very specific, controlled way that mirrors the row operation. For example, the swap elementary matrix $E_{\text{swap}}(2,3)$ is $I$ with rows 2 and 3 swapped. The scale elementary matrix $E_{\text{scale}}(1, 5)$ is $I$ with row 1 multiplied by 5. The add elementary matrix $E_{\text{add}}(3,1,2)$ is $I$ with row 3 replaced by row 3 plus 2 times row 1.

Lemma 9.1 says: left-multiplying a matrix $M$ by an elementary matrix $E$ performs that row operation on the rows of $M$. This is the bridge between row operations (which you've been doing by hand) and matrix algebra (which lives in the space of matrices). It justifies treating row reduction as a sequence of matrix multiplications, which sounds abstract but is exactly what happens on a computer. When row-reducing a matrix, you're literally computing matrix products $E_k \cdots E_1 A$ in sequence. The first row operation corresponds to $E_1$, the second to $E_2$, etc.

Theorem 9.2 is the payoff: **every invertible $n \times n$ matrix is a product of elementary matrices.** This is *why* Gauss-Jordan works. You reduce $A$ to $I$ using some chain of elementary operations (each corresponding to an elementary matrix $E_1, E_2, \ldots, E_k$). That chain, applied to $I$ in parallel, builds $A^{-1}$. The algorithm is not a shortcut or a hack—it's a direct consequence of this theorem. Invertibility is equivalent to reachability from the identity by row reduction. No coincidence; this is deep mathematics.

Think about what this means: every invertible matrix can be expressed as a product of row operations. So $A$ is invertible iff you can row-reduce it to $I$. Equivalently, $A$ is singular iff row reduction gets stuck—you can't reach $I$ because some pivot position is zero and can't be rescued by further operations. This connects Definition 9.1 (an abstract undo operation) to computational reality (pivot columns).

Finally, Lemma 9.3 and Theorem 9.3 deal with unit lower-triangular matrices. A matrix is unit lower triangular if it's lower triangular (zero above the diagonal) and has $1$'s on the diagonal. Lemma 9.3 says: products and inverses of such matrices stay unit lower triangular. The proof uses an index-chase argument: to get a nonzero off-diagonal entry above the diagonal in a product of lower-triangular matrices is impossible because the row and column indices don't align (you'd need $i < j$ and simultaneously $k \le i$ and $k \ge j$, which can't both be true). This seemingly abstract fact has a huge payoff: it guarantees that $L$ will always be "nice"—lower triangular with $1$'s on the diagonal, no surprises. Theorem 9.3 says: elimination-without-row-swaps factors $A = LU$ where both $L$ and $U$ have the shapes you expect. Both $L$ and $U$ are guaranteed to exist and be computable without row exchanges. This is the theoretical foundation for the practical LU factorization algorithm, which is ubiquitous in numerical linear algebra.

## Proof roadmaps

**Theorem 9.1 (uniqueness of the inverse).** Trick: *sandwich.* If $B$ and $C$ both invert $A$ (i.e., $AB = BA = I$ and $AC = CA = I$), evaluate $BAC$ in two ways using associativity and identity laws:
- $B(AC) = B \cdot I = B$
- $(BA)C = I \cdot C = C$

So $B = C$; the inverse is unique. This elegantly sidesteps complex algebra—just evaluate the same product in two different orders and watch the identity elements cancel from the middle outward. The sandwich trick is a general principle: to show two things are equal, sandwich them between an operation and its "undo" and see if they collapse. Intuition: $B$ and $C$ sandwich $A$. On the left, $B$ multiplies the result $AC = I$. On the right, $A$ multiplies the result $BA = I$. Both sandwiches collapse to just $B$ and just $C$, so they must be equal. This same trick appears throughout linear algebra whenever you need to prove uniqueness of something with an "undoing" property. The elegance is that you don't manipulate any equations; you just interpret them differently.

**Theorem 9.1b (inverse of a product).** Trick: test whether $B^{-1}A^{-1}$ satisfies the definition of $(AB)^{-1}$ by checking both $AB$ times $B^{-1}A^{-1}$ and vice versa. Compute using associativity to group the middle factors: 
$(AB)(B^{-1}A^{-1}) = A(BB^{-1})A^{-1} = AIA^{-1} = I$. 

Similarly $(B^{-1}A^{-1})(AB) = B^{-1}(A^{-1}A)B = B^{-1}IB = I$. So $B^{-1}A^{-1}$ satisfies the definition of an inverse of $AB$ (Definition 9.1). By Theorem 9.1a (uniqueness), it's *the* inverse, so $(AB)^{-1} = B^{-1}A^{-1}$. The genius of this proof is that it doesn't manipulate the matrices themselves—it just shows that the claimed inverse satisfies the defining property. Applying this repeatedly gives the corollary for longer products: $(A_1 A_2 \cdots A_k)^{-1} = A_k^{-1} \cdots A_2^{-1}A_1^{-1}$ by induction.

**Theorem 9.2 (every invertible matrix is a product of elementary matrices).** Trick: *row-reduce all the way to $I$, then invert the equation.* Since $A$ is invertible, it has full rank $n$ (using the rank formula from Day 6: rank plus null space dimension equals $n$, and a trivial null space gives rank $n$), so its reduced row echelon form is exactly $I$ (one pivot per row, per column, with all off-diagonal entries zero—the unique reduced echelon form for an invertible $n \times n$ matrix). The reduction sequence is $E_k E_{k-1} \cdots E_1 A = I$. Left-multiply both sides by $(E_k \cdots E_1)^{-1}$: you get $A = E_1^{-1}E_2^{-1} \cdots E_k^{-1}$. By Lemma 9.2, each $E_i^{-1}$ is itself elementary (undo a swap by swapping again, undo a scale by scaling by the reciprocal, undo an add by adding the negative—each undo operation is a single row operation, hence elementary). So $A$ is a product of elementary matrices—the exact ones that row-reduce it to $I$, but with operations reversed and negated.

This theorem is the theoretical justification for Gauss-Jordan: the fact that any invertible matrix is a product of elementary matrices means that row-reducing $A$ to $I$ literally shows $A = E_1^{-1} \cdots E_k^{-1}$. The inverse is exactly that product of elementary matrix inverses. By applying those same matrices to $I$, you compute $A^{-1}$.

**Lemma 9.3 & Theorem 9.3 (products and inverses of unit lower-triangular matrices; LU decomposition).** Trick: *index chase.* For a product $PQ$ with $i < j$, entry $(PQ)_{ij} = \sum_k P_{ik}Q_{kj}$. A term $P_{ik}Q_{kj}$ is nonzero only if $k \le i$ (since $P$ is lower triangular, $P_{ik}=0$ for $k>i$) *and* $k \ge j$ (since $Q$ is lower triangular, $Q_{kj}=0$ for $k<j$). So you need $j \le k \le i$; but $i < j$ makes this range empty—every term vanishes, so $(PQ)_{ij} = 0$. Hence $PQ$ stays lower triangular. Diagonal: $(PQ)_{ii} = \sum_k P_{ik}Q_{ki}$; only $k=i$ survives (else the $P$ or $Q$ term is zero), giving $(PQ)_{ii} = P_{ii}Q_{ii} = 1 \cdot 1 = 1$. So the product is unit lower triangular.

For inversion of $P$ (unit lower triangular), the diagonal is already $1$, so you can clear everything below using only "subtract a multiple of an upper row from a lower row" operations (each is unit lower triangular, since it differs from $I$ only in a strictly-below-diagonal entry; Lemma 9.2). Their product is unit lower triangular (by the product result) and equals $P^{-1}$. By induction, this guarantees $P^{-1}$ is unit lower triangular.

For LU: every elimination step without row swaps is left-multiplication by a unit lower-triangular elementary matrix (each step does "row $i$ minus a multiple of an upper row," which is unit lower triangular by the argument above). Their product $M = E_k \cdots E_1$ is unit lower triangular (by induction on the product result). Since $MA = U$, we get $A = M^{-1}U =: LU$ where $L = M^{-1}$ is unit lower triangular (by the inversion result). Read $L$ from the multipliers directly, stored at their elimination positions: the multiplier $m_{ij}$ used in "row $i$ minus $m_{ij}$ times row $j$" goes into position $(i,j)$ of $L$. This is the practical recipe that avoids any matrix inversion.

### Key takeaways before flashcards

You now have the complete picture:
- **Invertibility and rank:** $A$ is invertible iff it has full rank $n$ (equivalently, $n$ pivots in an $n \times n$ matrix).
- **Elementary matrices:** These encode row operations and are always invertible themselves (Lemma 9.2).
- **Uniqueness of the inverse:** By the sandwich trick, if an inverse of $A$ exists, it's unique (Theorem 9.1a).
- **Inverse of products:** $(AB)^{-1} = B^{-1}A^{-1}$, reversing the order—the socks-and-shoes principle (Theorem 9.1b).
- **Every invertible matrix is a product of elementary matrices:** This is the deep reason why Gauss-Jordan works (Theorem 9.2).
- **LU decomposition:** Elimination without row swaps factors $A = LU$ where $L$ records the multipliers (Theorem 9.3).

These six facts form the foundation for the algorithms you'll use repeatedly in computation. Study them before tackling the exercises.

### Connections: Invertibility, Rank, Pivots

You may be wondering: how do Definition 9.1 (invertibility as an abstract undo), the rank formula from Day 6, and the pivot count from Day 2 all fit together? Here's the connection:
- An $n \times n$ matrix has $n$ pivots (Day 2 concept) iff its rank is $n$ (Day 6 concept).
- An $n \times n$ matrix with rank $n$ has trivial null space (Day 6 Fundamental Theorem).
- If $A$ has trivial null space, then $Ax = 0 \implies x = 0$, so $A$ is injective.
- For square matrices, injectivity is equivalent to surjectivity (no missing rows in the image).
- If $A$ is bijective, then it has a two-sided inverse $A^{-1}$ (Definition 9.1).
- By Theorem 9.2, $A$ is invertible iff it can be row-reduced to $I$, iff it has $n$ pivots, iff rank$(A) = n$.

All five characterizations of invertibility are equivalent. You can use whichever is most convenient for the problem at hand.

### Tips for working through Day 9 exercises

- **Exercise 1–4 (computing inverses):** Show every row operation step. Write the augmented matrix $[A \mid I]$ at each stage. Verify your answer by checking $AA^{-1} = I$.
- **Exercise 5 (LU decomposition):** After each elimination step that clears an entry $(i,j)$, immediately record the multiplier into the $(i,j)$ position of $L$. Don't try to compute $L$ afterwards.
- **Exercise 6 (trap: sum of invertibles):** Remember: invertibility is not preserved by addition, only by multiplication (Theorem 9.1b).
- **Exercise 7–8 (proofs):** Use the definitions of matrix inverse (Definition 9.1) and transpose properties. The sandwich trick works here too.
- **Exercise 9 (singular matrix):** When you hit a row of zeros on the left block, stop. You've proven the matrix is singular.

**Working through the exercises effectively:**

As you solve each exercise, step back periodically and ask: which definition or theorem am I using? Am I applying the socks-and-shoes rule? Am I reading off multipliers correctly for LU? This reflection will deepen your understanding of how the theory and practice connect. By the end of Day 9, you should feel confident computing inverses and factorizations by hand, and you should have a deep appreciation for why Gauss-Jordan and LU are the computational gold standards in linear algebra. 

Finally: invertibility is perhaps the most important concept in linear algebra. A matrix is either invertible (bijective, full rank, has $n$ pivots, can be row-reduced to $I$) or singular (not bijective, rank $< n$, missing pivots, cannot reach $I$). This binary division shapes everything that follows in the course and in computational practice. Master it today. You're not just learning to compute $A^{-1}$ or factor $A = LU$—you're learning to recognize invertibility in all its forms and understand why it matters so deeply.

Do the work, understand the theory, and trust that both will pay dividends throughout your journey in linear algebra.

## Flashcards

### Flashcards

**Q:** What is the socks-and-shoes rule for $(AB)^{-1}$?
**A:** $(AB)^{-1} = B^{-1}A^{-1}$ — undo in reverse order, just like taking off shoes before socks.

**Q:** Why does Gauss-Jordan on $[A|I]$ produce $A^{-1}$ on the right?
**A:** The row operations are a chain $E_k \cdots E_1$, and $E_k \cdots E_1 A = I$ means that product is $A^{-1}$ (Definition 9.1). Applied to $I$, it gives $A^{-1}$; the side-by-side algorithm computes both simultaneously.

**Q:** What do L and U represent in the factorization $A = LU$?
**A:** $U$ = the upper-triangular echelon form reached at the end of elimination. $L$ = unit lower triangular with multipliers from elimination stored below the diagonal at the $(i,j)$ positions they eliminated.

**Q:** Why is $A = LU$ better than computing $A^{-1}$ when solving $Ax = b$ multiple times?
**A:** Two cheap triangular solves per $b$ (forward substitution for $Ly=b$, then back substitution for $Ux=y$). No inverse is ever formed, saving computation and improving numerical stability.

**Q:** Can a non-square matrix be invertible?
**A:** No. Invertibility requires both $AB = I$ and $BA = I$ with the same $B$, which forces $A$ and $B$ to be the same size and square. Non-square matrices cannot have full rank.

**Q:** Is the inverse unique? What's the key proof idea?
**A:** Yes, the inverse is unique. Proof: use the sandwich trick. If $B$ and $C$ both invert $A$, evaluate $BAC$ as $B(AC) = B$ and $(BA)C = C$, so $B = C$.

**Q:** When does $A = LU$ (without row swaps) exist?
**A:** When Gaussian elimination never needs a row swap—all pivot entries appear in their natural positions without exchanging rows. Equivalently, all leading principal minors are nonzero.

Day 9 ties theory to practice. You now know that invertibility is equivalent to reachability from the identity by row reduction (Theorem 9.2), that Gauss-Jordan on $[A \mid I]$ computes $A^{-1}$ by accumulating the row operations on the right half, and that LU decomposition factors $A = LU$ where $L$ records the elimination multipliers and $U$ is the upper-triangular result (Theorem 9.3). For multiple right-hand sides, solve $Ly = b$ then $Ux = y$ twice per $b$; never form $A^{-1}$ explicitly. As you work through the exercises, apply these ideas directly. When you compute an inverse by hand, you're literally performing the row operations encoded by elementary matrices. When you find $L$ and $U$, you're reading off the elimination receipt. Keep the pictures and the socks-and-shoes rule close—they're the keys to understanding why these algorithms work and why they're structured the way they are.

### Important caveat: When not to form $A^{-1}$

In practice, avoid computing and storing $A^{-1}$ explicitly, even though you now know how. Here's why: (1) forming $A^{-1}$ requires $O(n^3)$ flops and $O(n^2)$ storage, (2) rounding errors are magnified when $A$ is ill-conditioned (nearly singular), and (3) if you need $x = A^{-1}b$, you can solve $Ax = b$ directly in $O(n^3)$ flops and $O(n)$ extra storage. The only time you might compute $A^{-1}$ is for pedagogical reasons (to verify theory) or when you need the inverse matrix itself (rare). Always solve $Ax = b$ instead.
