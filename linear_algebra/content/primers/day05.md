# Day 5 Primer — Gaussian Elimination, Row Reduction, Rank

## Warm-up

If you've absorbed Days 4, 3, and 1, you already have the key pieces scattered in your toolkit:

- **Day 1** established what it means for vectors to be linearly independent: if the only way to combine them to get zero is to use all zero coefficients, they're independent. Dependence means you've got redundancy — at least one vector can be written as a combination of the others. Today you'll meet a new kind of independence: two rows can be independent (can't make one from the other), but their *row space* — the span of all rows — is what actually matters for rank.

- **Day 3** taught you that matrices are just organized grids of numbers, and that we can perform three reversible operations on rows: swap them, scale them, combine them. These aren't random operations — they correspond exactly to legal moves on equations in a system. You learned that matrix operations let you encode and manipulate systems compactly.

- **Day 4** showed you that a linear system is a set of constraints. Each equation carves out a geometric object: a line in 2D, a plane in 3D, a hyperplane in higher dimensions. Multiple equations intersect. The solution set is their intersection — a point, a line, a plane, empty, or something higher-dimensional.

Today you'll tie these together into the most practical tool of linear algebra: a mechanical process to transform any system into a staircase shape that reads off the answer immediately (or tells you there's no answer, or infinitely many). The payoff is deep: this process is *provably* legal because every move is reversible. You're never losing information — only re-describing the same system in clearer form.

## The hook

Imagine solving $x+y+z=6$, $2x+y+3z=13$, $x+2y+2z=11$ by hand using high-school substitution. Solve the first for $x$, substitute into the second and third, simplify to two equations in two unknowns, repeat. You get there, but it's algebra soup: fractions pile up, opportunities to make arithmetic errors multiply, and the pattern is hard to see if there's no solution or infinitely many. And if you scale it to 20 unknowns? Forget it — the substitution method drowns in complexity.

Now imagine the exact same system as a grid of numbers — the augmented matrix $[A \mid b]$ shown in day05.md:
```
[1  1  1 | 6]
[2  1  3 | 13]
[1  2  2 | 11]
```
Suddenly you have three legal mechanical moves: **swap** two rows (reorder equations), **scale** a row by a nonzero number (multiply an equation by a nonzero constant), or **add a multiple of one row to another** (combine two equations to eliminate a variable). Using only these moves, you clean the grid one column at a time, building a staircase downward and to the right. Each step produces a **pivot** — the leading nonzero entry of that row. Below each pivot, that column is all zeros. The bottom rows become trivial ($0=0$) or contradictory ($0 = \text{nonzero}$).

The worked example in day05.md shows exactly this: three row operations later, the matrix becomes:
```
[2  1 -1 | 3]
[0  1  1 | 1]
[0  0 -1 | 3]
```
Three pivots (corners of the staircase), and you read off $z = -3$, then $y = 4$, then $x = -2$ — done in minutes, no algebra mess.

The result? You can read the matrix backward from the bottom up — back-substitution — and extract your answer in seconds. And it scales: this process works identically for 3 equations or 300. Computers use it. Engineers use it. It's the heart of linear algebra in practice.

Two questions arise and answer themselves:

1. **Why is this legal?** Every elementary row operation is **reversible**. Swap rows, you can swap them back. Scale row $i$ by $c \neq 0$, you can scale by $1/c$ to undo it. Add $c$ times row $j$ to row $i$, you can subtract $c$ times row $j$ to undo it. Because every move can be undone, the solution set never changes — you're describing the same system a different way, not solving a different problem. This reversibility is the entire logical justification for Gaussian elimination. (Formally: Theorem 5.1.)

2. **What does the staircase tell you?** The number of steps — the number of **pivots** — is the **rank** of the matrix. Rank tells you how many of your equations are genuinely independent, non-redundant information. If you have rank 3 in a $3 \times 3$ system, you have three independent constraints and typically one unique solution: the three planes intersect at a single point. If rank is less than the number of variables, you have **free variables** — variables you can set to anything — and infinitely many solutions: the equations don't constrain everything. Most importantly: if a row of your augmented matrix reads all zeros except the very last entry (the constant side), you have a contradiction — the equation says $0 = (\text{nonzero})$ — so there's no solution. Rank is the key to reading the outcome. (Formally: Theorem 5.2 and the interpretation of row echelon form.)

## The pictures

**Picture 1: The staircase shape (row echelon form).**
Imagine a matrix with nonzero rows stacked like steps going down and to the right:
```
[× × × × × ]
[0 × × × × ]
[0 0 × × × ]
[0 0 0 0 × ]
[0 0 0 0 0 ]
```
Each × is a **pivot** — the leading nonzero entry of that row. Below each pivot, the column is all zeros. Crucially, each pivot appears strictly to the *right* of the pivot in the row above it. This is **row echelon form** — the canonical staircase. The number of nonzero rows (the number of steps) is the rank. Every row below the last nonzero row is the zero row. This shape is what Gaussian elimination builds, and it's the form where solutions are easiest to read.

**Picture 2: Row operations as reversible knobs.**
Think of your augmented matrix as a physical object with three independent, reversible knobs you can turn:
- **Swap knob:** Exchange any two rows. Turn it in reverse, and the rows swap back. The solution set hasn't moved; you've just relabeled the equations.
- **Scale knob:** Multiply any row by a nonzero number $c$. Turn it backward by multiplying by $1/c$, and you're back where you started. Multiplying $E_i$ by $c \neq 0$ doesn't change which vectors $x$ satisfy it — the equation just looks different.
- **Add knob:** Add any multiple of row $j$ to row $i$. Turn it backward by subtracting that multiple, and you recover the original. If $x$ satisfies both $E_i$ and $E_j$, it satisfies $E_i + cE_j$ too; conversely, if it satisfies $E_i + cE_j$ and $E_j$, you can recover $E_i$ by subtraction.

Each knob has an exact, reversible inverse. This reversibility is *why* solutions are preserved: you're not solving a new system, just re-describing the old one in a form where the answer jumps out.

**Picture 3: Planes in 3D space.**
Picture a linear system in three unknowns as three planes floating in 3D space. Each equation is a plane. Where they intersect is the solution set — a point, a line, a plane, or nothing (if they miss).

Now imagine the three elementary row operations applied to these planes:
- **Swap:** Label the planes differently. The intersection point (if it exists) hasn't moved.
- **Scale:** Make a plane thicker or thinner (multiply its equation by $c$). The intersection is unchanged.
- **Add a multiple:** Tilt one plane by adding a combination of two planes' equations. The intersection point stays the same.

Gaussian elimination is a sequence of geometric re-descriptions of the same intersection. Every legal move tilts or relabels, but the intersection — the solution set — is untouched. That's why you can row-reduce with impunity.

## Concrete-first walkthrough

**Definition 5.1** (Elementary row operations): You have exactly three reversible moves in Gaussian elimination.
1. **Row swap** ($R_i \leftrightarrow R_j$): Exchange any two rows.
2. **Scale** ($R_i \to cR_i$, $c \neq 0$): Multiply a row by a nonzero constant.
3. **Add a multiple** ($R_i \to R_i + cR_j$, $j \neq i$): Replace one row by itself plus a multiple of another row.

The condition $c \neq 0$ in operation 2 is crucial. If you multiply by $0$, you erase the row — losing information irreversibly. That's why it's forbidden.

**Definition 5.2** (Row echelon form, pivot, rank): A matrix $R$ is in **row echelon form (REF)** if:
- Any all-zero rows appear at the bottom.
- For each nonzero row, its leftmost nonzero entry — the **pivot** of that row — lies strictly to the right of the pivot in the row above.

For example, these matrices are in REF:
```
[2  1 -1]        [1  2  0]        [3  0]
[0  1  1]        [0  0  5]        [0  2]
[0  0 -1]        [0  0  0]        [0  0]
```
Each nonzero row's leftmost entry is strictly to the right of the one above, and all zeros appear below.

A matrix in **reduced row echelon form (RREF)** is stricter: every pivot equals $1$, and every pivot is the only nonzero entry in its column. Both REF and RREF have the same pivot positions and nonzero-row count, which is all that matters.

The **rank** of a matrix $A$, written $\operatorname{rank}(A)$, is the number of pivots (equivalently, the number of nonzero rows) in any row echelon form obtained by a finite sequence of elementary row operations. In the three examples above, ranks are 3, 2, and 2 respectively. This definition is only legitimate if that count is the same no matter which row operations you use — you don't get a different answer because you eliminated in a different order. Theorem 5.2 guarantees this.

**Theorem 5.1** (Elementary row operations preserve the solution set): If you apply one elementary row operation to the augmented matrix $[A \mid b]$ of a system $Ax = b$, you get a new system with exactly the same solution set. Apply multiple operations in sequence — still the same solution set. 

**Slogan:** "Cleanup never changes the answer set — because every move can be undone."

**Why?** View the system's solution set as the intersection of the solution sets of the individual equations: $x$ is a solution to the whole system iff $x$ satisfies every equation simultaneously. Each of the three operations is reversible:
- **Row swap** just reorders the list of equations. Set intersection doesn't depend on order.
- **Scaling** an equation by nonzero $c$: if $x$ satisfies $E_i$, multiply the equation by $c$ — $x$ satisfies $cE_i$. If $x$ satisfies $cE_i$, divide by $c$ (legal since $c \neq 0$) — $x$ satisfies $E_i$. Two-way containment: identical solution sets.
- **Adding a multiple:** if $x$ satisfies $E_i$ and $E_j$, then it satisfies $E_i + cE_j$ (add $c$ times one equation to the other). Conversely, if $x$ satisfies $E_i + cE_j$ and $E_j$, multiply $E_j$ by $c$ and subtract from the sum to recover $E_i$. Again, identical solution sets.

Since each single move preserves solutions, so does any finite sequence.

**Theorem 5.2** (Rank is well-defined): If you row-reduce the same matrix using two different sequences of moves, you get two different row echelon forms $R$ and $R'$. Yet they have the *same* number of nonzero rows. This is why Definition 5.2 is legitimate — rank is a property of the matrix itself, not of your cleanup order. Two people working the same problem in two different ways will always compute the same rank.

**Slogan:** "Everyone's staircase has the same number of steps."

**Why?** The trick is to recognize that rank equals the *dimension of the row space*. The row space of $A$ is $\operatorname{Row}(A) = \operatorname{span}\{r_1, \dots, r_m\}$ — all linear combinations of the rows. Elementary row operations preserve the row space (they replace rows by combinations of rows, but the set of all possible combinations stays the same), so any row echelon form of $A$ has the same row space as $A$ itself. 

In any REF, the nonzero rows are linearly independent — the staircase structure with pivots in strictly increasing columns forces this. To see why, suppose a linear combination of the nonzero rows equals zero: $\sum_i \lambda_i \rho_i = 0$. Look at the first pivot column: only the first row is nonzero there (all later rows have pivots further right), so that entry of the sum is $\lambda_1 (\rho_1)_{c_1}$. Since the sum is zero and the pivot $(\rho_1)_{c_1} \neq 0$, we have $\lambda_1 = 0$. Repeat for the second pivot column among the remaining rows — get $\lambda_2 = 0$ — and so on. All coefficients are zero: the nonzero rows are independent.

Thus the nonzero rows form a basis of the row space, and their count equals $\dim(\operatorname{Row}(A))$. Since dimension is a geometric property of the row space (uniquely determined by Day 2), all bases — and all REFs — must have the same number of nonzero rows.

## Proof roadmaps

**Theorem 5.1** — *Trick: reversibility gives two-way containment.*

Key idea: the solution set of a system is the intersection of the solution sets of its individual equations. (An $x$ solves the system iff it satisfies every equation.)

For each move type, show the new system has the same solution set:

- **Row swap:** Swapping two equations is reordering the list $E_1, E_2, \dots, E_m$. The set of all vectors satisfying every equation doesn't depend on the order — $\operatorname{Sol}(E_1) \cap \operatorname{Sol}(E_2) \cap \cdots$ is the same intersection no matter which equation comes first. Solution set unchanged.

- **Scale ($R_i \to cR_i$, $c \neq 0$):** Show $\operatorname{Sol}(E_i) = \operatorname{Sol}(cE_i)$. ($\Rightarrow$) If $x$ satisfies $\sum_k a_{ik}x_k = b_i$, multiply both sides by $c$ to get $\sum_k (ca_{ik})x_k = cb_i$ — so $x$ satisfies $cE_i$. ($\Leftarrow$) If $x$ satisfies $cE_i$, divide both sides by $c$ (legal since $c \neq 0$) to recover $E_i$ — so $x$ satisfies $E_i$. Two-way inclusion: equal solution sets.

- **Add a multiple ($R_i \to R_i + cR_j$, $j \neq i$):** Show solutions are preserved. ($\Rightarrow$) If $x \in S$ (old system), it satisfies all equations, including $E_i$ and $E_j$. Then $x$ satisfies $E_i + cE_j$ (add $c$ times the second to the first). ($\Leftarrow$) If $x$ satisfies $E_i + cE_j$ and $E_j$ (among the unchanged equations of the new system), then $c E_j$ is satisfied; subtract from $E_i + cE_j$ to recover $E_i$. Two-way inclusion: same intersection.

Apply induction: finite sequences of moves preserve solutions.

**Theorem 5.2** — *Trick: rank is the dimension of the row space; dimension is unique.*

Three-step proof:

1. **Row ops preserve row space (Lemma A):** Each elementary row operation replaces rows by linear combinations of rows. So the span of the new rows is contained in the span of the old rows. But each move is reversible — apply the inverse operation and the span is restored. Thus $\operatorname{Row}(A) = \operatorname{Row}(A')$ after any single move. Induction: $\operatorname{Row}(\text{any REF of } A) = \operatorname{Row}(A)$.

2. **Nonzero rows of REF are independent (Lemma B):** Let $\rho_1, \dots, \rho_r$ be the nonzero rows of an REF, with pivots in columns $c_1 < c_2 < \cdots < c_r$ (strictly increasing). If $\sum_{i=1}^r \lambda_i \rho_i = 0$, look at column $c_1$: by definition of REF, rows $\rho_2, \dots, \rho_r$ have zeros in column $c_1$ (their pivots are to the right). So the column-$c_1$ entry of the sum is $\lambda_1 (\rho_1)_{c_1}$. Since the sum is zero and $(\rho_1)_{c_1} \neq 0$ (it's a pivot), $\lambda_1 = 0$. Repeat at column $c_2$ for $\rho_2, \dots, \rho_r$ — get $\lambda_2 = 0$. Induction gives all $\lambda_i = 0$: the nonzero rows are independent, forming a basis of the row space.

3. **Any two REFs have the same rank:** Let $R, R'$ be two REFs of $A$ with $r, r'$ nonzero rows. Both satisfy $\operatorname{Row}(R) = \operatorname{Row}(A) = \operatorname{Row}(R')$ (step 1). Their nonzero rows form bases of the same subspace (step 2). All bases of a space have equal size (Day 2). Thus $r = r'$.

Conclusion: rank is well-defined, equal to $\dim(\operatorname{Row}(A))$.

## Flashcards

### Flashcards

**Q:** What are the three elementary row operations?

**A:** Swap two rows; multiply a row by a nonzero scalar $c \neq 0$; add a multiple of one row to another row (the row being added to is replaced, the other is unchanged).

**Q:** Why do elementary row operations preserve the solution set of a linear system?

**A:** Each operation is reversible — you can undo any swap, scale, or combination move — so the solution set maps into itself both ways and cannot change between the old and new system.

**Q:** Define rank using row echelon form.

**A:** Rank is the number of pivots (equivalently, the number of nonzero rows) in any row echelon form obtained from the matrix by a finite sequence of elementary row operations.

**Q:** Why is rank well-defined, independent of which moves you use to reduce a matrix?

**A:** Row operations preserve the row space, and the nonzero rows of any REF form a basis of that space, so their count equals the dimension of the row space — a geometric property that doesn't depend on your reduction order.

**Q:** What does rank mean in plain terms?

**A:** The number of genuinely independent, non-redundant equations or constraints in your system — how many of the given equations carry unique information not implied by the others.

**Q:** What are the three possible solution-set shapes for a linear system?

**A:** Empty set (inconsistent; no solution), a single point (unique solution), or infinitely many solutions (free variables with at least one degree of freedom).

**Q:** What signal in the augmented row echelon form indicates that a system is inconsistent?

**A:** A row with all zeros in the coefficient columns but a nonzero entry in the constants column — it reads $0 = (\text{nonzero})$, a mathematical contradiction.
