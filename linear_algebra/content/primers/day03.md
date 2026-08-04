# Primer: Day 3 — Linear Transformations, Matrix Representation

Today's primer prepares your intuition for the main file by walking through the core idea: which transformations can be encoded in matrices, and how. You'll see the hook (the 90° rotation), pictures that clarify what "linear" means visually, worked examples showing how matrices work, roadmaps for the main theorems (Theorem 3.1 and 3.2), and finally flashcards to cement the key definitions. This is *encoding* material—building the mental models before diving into formal proofs in the theory section.

## Warm-up

Before reading anything new, answer the flashcards at the end of `primers/day02.md` and `primers/day01.md` for: Day 2, Day 1 (~10 min). Say each answer out loud or on paper *before* flipping.

## The hook

Imagine you rotate the entire plane by 90° counterclockwise. That rule moves *infinitely many* points—yet you can write it down with just 4 numbers. Why does this work?

The trick is linearity. Rotation sends $e_1=(1,0) \mapsto (0,1)$ and $e_2=(0,1) \mapsto (-1,0)$. Because the map is linear (it respects mixing), linearity forces everything else. For example, $(3,2) = 3e_1 + 2e_2$ must map to $3(0,1) + 2(-1,0) = (-2,3)$. Check this against geometry: a point at angle $0°$ and distance $\sqrt{13}$ rotates to angle $90°$ at the same distance, landing exactly at $(-2,3)$. The algebra and geometry agree.

Here's the profound part: you don't need separate instructions for $(3,2)$, for $(5.7, -2.1)$, for $(\pi, \sqrt{2})$, or for *any* other point. Once you know what the map does to $e_1$ and $e_2$ (the basis), the behavior everywhere else is forced by the linearity property. This is impossibly powerful: from 2 base cases and one rule, you get a complete description of a transformation on infinitely many points.

Today formalizes this idea: which maps allow this trick (linear ones), and how the numbers are organized. The answer: the 4 numbers form columns of a matrix, where each column tells you where a basis vector landed. Once you know where the basis goes, linearity forces everything else everywhere.

## The pictures

**Picture 1: Before and after the grid**

Imagine a graph-paper grid covering $\mathbb{R}^2$. Under a 90° rotation, every grid line stays straight, lines that were parallel stay parallel, and the spacing between lines is even. Most importantly, the origin stays fixed at the origin. This is what "linear" looks like geometrically: grids stay grids. Why? Because a linear map respects addition and scaling. If two grid points are 3 units apart, they stay 3 units apart after the map (or at least the relationship that made them 3 apart still holds in the output). Any map that bends or tangles the grid, or moves the origin, is not linear. A curved transformation, or a translation like $(x,y) \mapsto (x+1, y)$, will warp the grid and shift the origin—both violations of linearity.

**Picture 2: The matrix as a filing cabinet**

Think of the matrix as a phone book or filing cabinet. Column $j$ tells you exactly where basis vector $j$ landed. If the rotation matrix is $\begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$, then column 1 says "$e_1$ went to $(0,1)$" and column 2 says "$e_2$ went to $(-1,0)$". Every column is a coordinate list in the output basis. This is Definition 3.2. The beauty of this filing system: you store just $n$ vectors (the outputs for $n$ input basis vectors), and you can look them up and mix them to recover the output for any other vector.

**Picture 3: Two machines in series**

Imagine two transformations chained together: a vector $v$ goes through machine $T$, comes out as $T(v)$, then feeds into machine $S$, coming out as $S(T(v))$. This composition $S \circ T$ is itself a linear map—and here's the key: its matrix is the product $BA$, where $A$ is the matrix of $T$ and $B$ is the matrix of $S$. The product is read right-to-left, just like function composition. This is Theorem 3.2: you don't need to trace through the intermediate space to find the overall effect; you can just multiply the matrices.

## Concrete-first walkthrough

Before proving anything, let's see how the mechanics work in practice.

**Pre-teaching: How to compute $Ax$ (the conceptual move)**

You'll see Definition 3.2 use matrix-vector multiplication without saying exactly what it means. Here's the picture. If $A$ has columns $a_1, a_2, \ldots$ and $x = (x_1, x_2, \ldots)^T$, then $Ax$ means "mix the columns of $A$ using the entries of $x$ as recipe amounts":
$$Ax = x_1 a_1 + x_2 a_2 + \cdots$$

This is the key mental model: a matrix is not just a grid of numbers, but a *storage device for column vectors*. When you multiply by a vector, you're asking "what combination of these stored columns do I get?"

For the rotation example, $A = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$, so $A \begin{pmatrix} 3 \\ 2 \end{pmatrix} = 3 \begin{pmatrix} 0 \\ 1 \end{pmatrix} + 2 \begin{pmatrix} -1 \\ 0 \end{pmatrix} = \begin{pmatrix} -2 \\ 3 \end{pmatrix}$. You're mixing the two columns of $A$ with weights $3$ and $2$. Take 3 copies of the first column, 2 copies of the second, and add them up. That's it.

For matrix-times-matrix, same idea applied to each column. If you multiply $B \cdot A$ where $A = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$ and $B = \begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix}$, you apply $B$ to each column of $A$ separately:
$$BA = \begin{pmatrix} B(0,1)^T & B(-1,0)^T \end{pmatrix} = \begin{pmatrix} (0,-1)^T & (-1,0)^T \end{pmatrix} = \begin{pmatrix} 0 & -1 \\ -1 & 0 \end{pmatrix}.$$

The $(i,j)$ entry of $BA$ is "row $i$ of $B$ dotted with column $j$ of $A$", because that's how the mixing rule produces the $i$-th entry of each output column.

**Why pre-teach the mechanics?**

The main file (day03.md) uses matrix-vector multiplication freely without spelling out what it means. Rather than stop and puzzle over the notation later, we're front-loading the picture: a matrix is a *list of columns*, and multiplying by a vector is *asking how to combine those columns*. This turns the abstract notation into something you can picture and compute by hand. Once this clicks, the rest of the theory becomes much more concrete.

**One more example: reflection + scaling**

Let $R$ be reflection across the $x$-axis: $(x,y) \mapsto (x,-y)$. This is linear (check: it preserves addition and scaling). Its matrix is $\begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix}$ (where does $e_1$ go? Where does $e_2$ go?). Let $S$ be scaling by 2: $(x,y) \mapsto (2x, 2y)$, with matrix $\begin{pmatrix} 2 & 0 \\ 0 & 2 \end{pmatrix}$. The composition $S \circ R$ (first reflect, then scale) has matrix product $\begin{pmatrix} 2 & 0 \\ 0 & 2 \end{pmatrix} \begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix} = \begin{pmatrix} 2 & 0 \\ 0 & -2 \end{pmatrix}$. Check: $(S \circ R)(1,1) = S(1,-1) = (2,-2)$, and multiplying by the matrix gives $\begin{pmatrix} 2 & 0 \\ 0 & -2 \end{pmatrix} \begin{pmatrix} 1 \\ 1 \end{pmatrix} = \begin{pmatrix} 2 \\ -2 \end{pmatrix}$. They match—matrix multiplication encodes composition.

**Definition 3.1 (Linear transformation)**

A map $T: V \to W$ is linear if it respects mixing: $T(au+bv) = aT(u) + bT(v)$ for any vectors $u, v$ and scalars $a, b$. This is one condition that unpacks into two parts: additivity ($T(u+v) = T(u) + T(v)$) and homogeneity ($T(cu) = cT(u)$). Geometrically, this means grids stay grids (no bending or tangling), straight lines map to straight lines or points, and the origin is always fixed (since $T(0) = 0$, which follows immediately by setting $c=0$). 

Examples of non-linear maps: a translation like $T(x,y) = (x+1,y)$ shifts the origin, so it fails linearity. Any map with nonlinear terms like $T(x,y) = (xy, x)$ or $T(x,y) = (x^2, y)$ breaks the mixing property. Even a seemingly innocent map like $T(x,y) = (|x|, y)$ is not linear (because of the absolute value). The key test: does additivity hold? Does homogeneity hold? If either fails, it's not linear.

**Definition 3.2 (Matrix of a linear transformation relative to given bases)**

Once you fix an input basis and an output basis, the matrix of $T$ is a filing cabinet: column $j$ is the coordinate list of $T(\text{basis vector } j)$ in the output basis. The key point is that a linear map is completely determined by where it sends the input basis vectors (Theorem 3.1 coming up). So if you know the images of those basis vectors, you know the matrix, and you know the map.

For the 90° rotation with the standard basis on both sides, the matrix is $\begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$ because $T(e_1) = (0,1)$ (first column) and $T(e_2) = (-1,0)$ (second column). The entries of each column are the coordinates of the image in the output basis. This allows you to compute $T(x) = A[x]$ by multiplying the matrix by the coordinate vector. Important: the matrix is basis-dependent—the *same* linear map can have different-looking matrices if you choose different bases.

**Lemma 3.1 (Linearity extends to finite linear combinations)**

The two-vector rule $T(au+bv) = aT(u) + bT(v)$ extends to any finite combination: $T(c_1 v_1 + \cdots + c_k v_k) = c_1 T(v_1) + \cdots + c_k T(v_k)$. This is proved by induction, peeling off one term at a time—a routine (but key) extension of Definition 3.1. 

The induction idea: if you know the rule for $k-1$ terms, split the $k$-term sum as $(k-1$ terms$) + 1$ term. Apply additivity (Definition 3.1, part 1) to split $T$ of the whole into $T$ of the first chunk plus $T$ of the last term. The inductive hypothesis handles the first chunk, homogeneity handles the last, and they reassemble. 

The practical meaning: once you know $T$ on a basis, you know it everywhere, because every vector is a unique combination of basis vectors. This lemma makes that fact precise and lets us use linearity at scale.

**Theorem 3.1 (A linear transformation is determined by its action on a basis)**

This is the foundational result—it explains why storing a finite matrix is sufficient to encode an infinite-dimensional rule. Part (a) says: if two linear maps agree on every basis vector, they agree everywhere. This is the *uniqueness* part: there's at most one linear map with prescribed values on the basis. Part (b) says: you can send the basis vectors anywhere you like—each choice yields exactly one linear map. This is the *existence* part: there's always at least one such map. 

Why does this work? Because every vector is a unique combination of basis vectors (from Day 2), and linearity (plus Lemma 3.1) forces $T$ to be that same combination of the images. You have complete freedom in choosing where the $n$ basis vectors go, and linearity locks in the behavior on all infinitely many other vectors. This is why the matrix (which stores those $n$ images in its columns) completely determines the transformation.

**Theorem 3.2 (The matrix of a composition is the product of the matrices)**

If you compose two linear maps $S \circ T$ (do $T$ first, then $S$), the matrix of the composition is the product $BA$, where $A$ is the matrix of $T$ and $B$ is the matrix of $S$. The critical point: the order is right-to-left. You read it as "$B$ times $A$", but $A$ acts first. This mirrors how function notation $(S \circ T)(v) = S(T(v))$ applies $T$ first. This means matrix multiplication is not commutative—$AB$ and $BA$ are usually different, sometimes not even the same shape—because they represent different compositions (doing $A$ first vs. doing $B$ first).

## Proof roadmaps

**Theorem 3.1 — the trick is: expand, push, and use uniqueness of coordinates.**

This theorem has two parts: uniqueness and existence.

*Uniqueness (part a):* You want to show that if two linear maps $T$ and $S$ agree on every basis vector, they agree everywhere. The idea is simple: any vector $x \in V$ is a unique combination $x = \sum_i c_i b_i$ of basis vectors. Now apply Lemma 3.1 to both $T$ and $S$:
$$T(x) = T\left(\sum_i c_i b_i\right) = \sum_i c_i T(b_i) = \sum_i c_i S(b_i) = S\left(\sum_i c_i b_i\right) = S(x).$$
They agree everywhere. The key insight: linearity lets you "pull the map through" the linear combination (that's Lemma 3.1), and if the map agrees on every term, the results agree. This is why the matrix is enough: knowing the images of the $n$ basis vectors (the $n$ columns of the matrix) completely and uniquely determines the linear map everywhere.

*Existence (part b):* You want to show that you can always construct a linear map sending basis vectors anywhere you choose. The trick is to *define* it via the combination formula: if you want $T(b_i) = w_i$, then define $T(x) := \sum_i c_i w_i$ for any $x = \sum_i c_i b_i$. This is well-defined precisely because the representation of $x$ in the basis is unique (the definition doesn't depend on which representation you pick). A quick check shows it's linear: if $x + y = \sum_i (c_i + d_i) b_i$, then $T(x+y) = \sum_i (c_i+d_i) w_i = T(x) + T(y)$, and similarly for scaling.

**Theorem 3.2 — the trick is: chase one basis vector through both maps, and let indices do the bookkeeping.**

You want to show that the matrix of $S \circ T$ is the product $BA$. The strategy is to trace through what happens to one input basis vector.

Fix an input basis vector $e_j$. Apply $T$ first: you get $T(e_j) = \sum_k A_{kj} f_k$—that's column $j$ of $A$, written in the intermediate basis $\mathcal{C}$. Next, apply $S$ to each intermediate basis vector $f_k$: you get $S(f_k) = \sum_i B_{ik} g_i$—that's row $i$ of $B$, written in the output basis $\mathcal{D}$. Now substitute:
$$(S \circ T)(e_j) = S\left(\sum_k A_{kj} f_k\right) = \sum_k A_{kj} S(f_k) = \sum_k A_{kj} \sum_i B_{ik} g_i = \sum_i \left(\sum_k B_{ik} A_{kj}\right) g_i.$$
The coefficient of $g_i$ is $\sum_k B_{ik} A_{kj}$, which is exactly the $(i,j)$ entry of the matrix product $BA$. The row-times-column dot product rule falls out automatically. The proof is mostly careful bookkeeping—keep a legend of which index runs where to avoid confusion. The key insight: once you compute where one basis vector lands, you've found an entire column of the output matrix, and the formula for that column is just a sum of matrix products.

**Why this matters:** These two theorems together explain why linear algebra is so powerful. Theorem 3.1 says a linear map is completely described by $n$ vectors (where $n$ is the input dimension)—that's compression: infinitely many points → finitely many pieces of data. Theorem 3.2 says that computing with those descriptions is as simple as multiplying matrices. So instead of computing $S(T(v))$ by tracing through both formulas, you compute $(BA)v$ with one matrix product. This is why linear transformations are so tractable.

**Heads up: matrix is basis-dependent**

The same linear transformation can have different matrices depending on which bases you choose. The identity map $I(v) = v$ has matrix $\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}$ relative to the standard basis, but it can be a very different-looking matrix if you choose nonstandard bases. This is not a bug—it's a feature of the theory (Day 25, change of basis, will explore this fully). For now: remember that "the matrix of $T$" is shorthand for "the matrix of $T$ relative to some pair of bases", and different basis choices give different matrices for the same map.

**Heads up: matrix product order is right-to-left**

In Theorem 3.2, the composition $S \circ T$ (do $T$ first, then $S$) has matrix product $BA$ (not $AB$). This is counterintuitive at first, because reading left-to-right you see $B$ first. But remember: matrices are read right-to-left, just like function composition. If you ever forget, test it on a simple example: rotation followed by reflection should give a different result than reflection followed by rotation. The matrix product order ensures the calculations match the geometric composition.

## Flashcards

Use these to consolidate your intuition. After reading the primer above, these should feel familiar—they capture the essence of each idea. They're phrased as you'd need to explain them to yourself or someone else.

**Q:** The one defining property of a linear map?

**A:** $T(au+bv) = aT(u) + bT(v)$ — respects mixing of vectors and scaling.

**Q:** What is column $j$ of the matrix of $T$?

**A:** The coordinates of $T(\text{basis vector } j)$, written in the output basis.

**Q:** How do you compute $Ax$ conceptually?

**A:** Mix the columns of $A$ using the entries of $x$ as recipe amounts: $Ax = x_1 a_1 + x_2 a_2 + \cdots$

**Q:** Why is a linear map completely determined by its values on a basis?

**A:** Every vector expands uniquely in the basis; linearity (Lemma 3.1) pushes $T$ through that expansion, forcing $T$ everywhere.

**Q:** What is the matrix of $S \circ T$?

**A:** The product $BA$ — composed in composition order, applied right-to-left.

**Q:** What do grid pictures of linear maps always preserve?

**A:** Straightness of lines, parallelism, even spacing, and the origin stays fixed.

**Q:** Which earlier fact makes coordinates well-defined (so $T$ in Theorem 3.1(b) is well-defined)?

**A:** Linear independence (Day 2) — the basis is unique; no vector has two different coordinate lists.
