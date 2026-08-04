# Day 25 — Change of Basis, Similarity

## Warm-up

Before reading anything new, answer the flashcards at the end of `primers/day23.md`, `primers/day22.md`, and `primers/day17.md` for: Day 23, Day 22, Day 17 (~10 min). Say each answer out loud or on paper before flipping. Don't skip this step—these three days are foundations for understanding why change of basis matters.

These earlier primers have covered covariance matrices and how the geometry of data relates to linear algebra (Day 23), low-rank approximation and why the SVD discovers structure and finds the best low-rank approximation (Day 22), and orthogonal matrices and QR factorization which gave us an orthonormal basis (Day 17). All of those use and rely on the standard coordinate system, often implicitly without thinking too much about it.

Today we ask a foundational question: what happens when we choose a different coordinate system? The answers from Days 17, 22, and 23 will look very different numerically—completely different numerical values in the matrices and vectors—but they encode exactly the same geometric truth underneath. The map, the data structure, the approximation—these are all geometric facts that don't depend on your choice of coordinates. But the numbers do. That's today's central insight.

Why does this matter? All data lives in $\mathbb{R}^n$, encoded as coordinate vectors. But which axes we use to label that space is our choice—a choice we make implicitly every time we write down a matrix or apply an algorithm. The standard axes are just the default, the convention. Change those axes, and every number in sight changes: eigenvalues? No, they're invariant. Eigenvectors? No, they rotate too. But other quantities—determinant, trace, rank—survive coordinate changes because they capture *geometric* facts about the map itself, not about the particular ruler we picked. Understanding this distinction will cement everything you've learned so far. Finally, you'll see why Day 11's diagonalization was never truly about "finding a basis where the matrix looks nice"—it was always about choosing the right coordinate glasses to see a transformation's true nature.

The practical payoff: by choosing the right basis, you can make a linear map look trivial. A complicated-seeming transformation becomes pure scaling in the eigenbasis. A shear becomes a rotation in the right frame. This isn't a computational trick; it's a revelation. It says that complexity often lives in your description, not in the geometry. Switch the glasses, and the complexity vanishes. This principle will serve you throughout applied linear algebra: data compression, machine learning, physics, and numerical methods all hinge on choosing bases wisely. Today, you'll master the machinery that makes basis-switching precise: Definition 25.1 (how to change coordinate vectors) and Theorem 25.1 (how to change transformation matrices). These two tools—one for vectors, one for matrices—are your new superpower.

## The hook

Imagine two observers looking at the exact same physical rotation of a vector in the plane. One uses the standard grid, the familiar $x$-$y$ axes. The other stands at an angle and uses a tilted grid, maybe $b_1 = (1,1)$ and $b_2 = (-1,1)$ as her basis vectors. They both write down a matrix for the identical physical map—yet the matrices contain completely different numbers. One sees a certain $2 \times 2$ array of values; the other sees very different entries in her tilted language. Who is right? Both. Neither is wrong because a matrix is fundamentally never the map itself; it is a *description of the map in a particular coordinate language*. The same river looks different depending on which bridge you stand on.

To make this concrete, imagine a single vector $v$ sitting somewhere in the plane. The first observer, using standard axes (call them the $e$-axes), looks at $v$ and writes $(x, y)$ using her grid-line crossings. The second observer, using the tilted axes (call them the $b$-axes), looks at the *exact same physical point* and writes different numbers—say, $(u, w)$—using her tilted grid-line crossings. Same arrow, different labels. The matrix $P$—the change-of-basis matrix—is precisely the dictionary that translates from one numbering system to the other. If the first observer tells the second observer her coordinates, she can feed them to $P$ and instantly get the tilted-coordinate reading: $P(x, y)^T = (u, w)^T$. It's a Rosetta Stone. Its columns are the second observer's new basis vectors, written in the first observer's language. Once you have $P$, you can translate any vector between languages, and you can translate any matrix too. The formula you'll use today, $[T]_B = P^{-1}[T]_{\text{std}}P$, says: to rewrite a transformation's matrix in the new basis, you conjugate (wrap it with $P^{-1}$ on the left and $P$ on the right). This wrapping is the mathematical way to say "translate in, act, translate out."

Today we build the dictionary that translates between languages. Two observers standing in different grids, measuring the same rotation and writing down a matrix, must get different numerical answers because they are using different rulers. One writes down the rotation as $\begin{pmatrix}\cos\theta&-\sin\theta\\\sin\theta&\cos\theta\end{pmatrix}$ in standard coordinates. The other, working in her tilted coordinates, gets a completely different matrix—yet they describe the same physical spinning motion. If you want to understand what the second observer computed, you need a translation formula that relates her matrix to the first observer's matrix. That is Definition 25.1 and Theorem 25.1.

Learning to switch between their descriptions—and recognizing that Day 11's diagonalization was all along just a beautifully special case of this switching—is this day's payoff and grand consolidation. By the end of today, you'll see that diagonalization was never a separate trick; it was simply the special case where you pick the eigenvector basis as your new grid. This unification of Days 11 and 25 is one of the most satisfying revelations in linear algebra: two seemingly different topics are the same idea viewed from two angles. The two observers aren't having a disagreement—they're both describing the same physical reality, just with different measurement systems. Your job is to translate between their languages using $P$ and $P^{-1}$, and to recognize that when they both compute trace, determinant, or eigenvalues, they'll always get the same answers, even though their matrices look completely different. Today, you'll become fluent in this translation. You'll see how to build the dictionary ($P$), how to use it to convert vectors and matrices, and why the resulting theory is one of linear algebra's great unifications.

## The pictures

To internalize why change of basis matters and why similarity captures something deep, we'll build three mental pictures. Each one highlights a different facet of the same truth: coordinate systems are choices, and the same geometric reality looks different in different languages. These pictures are your intuition anchors for the formulas that follow. They're drawn from the standard geometric intuition of linear algebra and appear repeatedly in applications—once you own these pictures, you'll recognize them everywhere.

**Picture 1: Two grids, one vector, two names.** Imagine the standard $x$-$y$ grid and a tilted grid overlaid on the same plane, both centered at the origin. Draw grid lines for each. A single vector points somewhere in the picture and has one geometric location in space—one spot in the plane. In the standard grid, you might label that point $(2,1)$ using grid-crossings along the $x$-axis and $y$-axis. In the tilted grid, the same vector—the identical arrow pointing to the same spot—has a different numerical label, say $(3,-0.5)$ using the tilted axis crossings. The vector itself hasn't budged; only the language changed. You're describing the same arrow with two different coordinate systems. This is where the change-of-basis matrix $P$ comes in: its columns are the tilted basis vectors written in standard language. Multiply standard coordinates by $P^{-1}$ to get tilted coordinates, and multiply tilted coordinates by $P$ to recover the standard ones. The matrix $P$ is the rosetta stone that lets the two observers communicate. In the next day's context, this is why changing coordinate systems *preserves* the geometric reality while changing all the numerical entries: the vector is a fixed point in space, but its address depends on which grid you're standing on.

The key insight from Picture 1: a vector is a geometric object. Its coordinates depend on the basis you choose, but the vector itself is invariant. Similarly, a linear transformation is a geometric object; its matrix representation depends on the basis, but the transformation itself is invariant.

**Picture 2: The commuting square.** Imagine four boxes arranged in a square, like a grid. At the top-left box sits $[v]_B$ (coordinates of a vector $v$ expressed in basis $B$). At the top-right box is $[v]_{\text{std}}$ (the same vector's standard coordinates). At the bottom-right box is $[Av]_{\text{std}}$ (the image after applying the linear map $A$, expressed in standard coordinates). At the bottom-left box is $[Av]_B$ (the image in basis $B$'s language).

Now draw four arrows connecting these boxes, forming a square loop. Starting from the top-left, go right: that arrow is labeled $P$, representing multiplication by $P$ to convert $B$-coordinates to standard coordinates. From the top-right, go down: that arrow is labeled $A$, representing multiplication by the standard matrix to apply the map. From the bottom-right, go left: that arrow is labeled $P^{-1}$, representing multiplication by $P^{-1}$ to convert back to $B$-coordinates. The fourth arrow, from bottom-left to top-left, is labeled $[T]_B$: this is the matrix we're trying to find—the standard matrix of $T$ written in basis $B$.

The question is: which path do you take? You can go right-then-down, or you can go down-then-left from the bottom-right. Both paths end at the bottom-left. The right-then-down path applies: multiply by $P$, then multiply by $A$, then multiply by $P^{-1}$—giving $P^{-1}A(P[v]_B) = P^{-1}AP[v]_B$. The down-then-left path says: apply the $B$-basis matrix directly to $[v]_B$—giving $[T]_B[v]_B$. Since both reach the same box and must give the same result for every vector $v$, they're equal: $[T]_B = P^{-1}AP$. The diagram "commutes" because going around any path gives the same answer. The commuting square is the geometric heart of Theorem 25.1: translate in, act, translate out.

The key insight from Picture 2: if you know how to transform vectors between bases (via $P$), you can automatically transform matrices between bases (via conjugation $P^{-1} \cdot P$). The commuting square ensures consistency: no matter which path you take around the square, the result is the same.

**Picture 3: Callback to Day 11.** Diagonalization $A = PDP^{-1}$ from Day 11 is not a separate algebraic trick but rather this commuting square with $B$ chosen cleverly as the eigenvector basis. In the eigenvector basis language, the map $T$ looks like a pure diagonal matrix—each eigenvector is stretched or flipped by a scalar, nothing more complicated. In standard coordinates, the same map looks messy and off-diagonal. "Diagonalization" was secretly "change your coordinate glasses to the eigenbasis." Now you understand the glasses shop. The eigenvector basis is the magic choice of coordinates. The diagonal $D$ you compute in Day 11 is literally what the transformation looks like when viewed through eigenvector-colored glasses.

Think about it this way: Day 11 asked, "Can we find a basis where the matrix looks diagonal?" and the answer was: "Yes, if you have enough independent eigenvectors—use the eigenvector basis!" Now we know why that works: diagonalization is just changing to the eigenvector basis. The off-diagonal entries appear in standard coordinates only because we're describing the map in the "wrong" language (standard). Switch to the eigenvector language, and the off-diagonal terms vanish. This is the grand payoff of Day 25: you have a single unifying theory that explains both change of basis (the general machinery) and diagonalization (the special case where you pick the eigenvector glasses).

The key insight from Picture 3: diagonalization from Day 11 is not a special trick for finding eigenvalues and eigenvectors—it's a special case of change of basis where you choose the eigenvector basis because it reveals the map's simplest form.

These three pictures—two grids and one vector, the commuting square, and the Day 11 callback—are not three separate ideas. They're three angles on the same truth: a linear map is independent of basis, but its matrix representation depends entirely on which basis you choose. The formulas $[v]_B = P[v]_{B'}$ and $[T]_{B'} = P^{-1}[T]_BP$ are bookkeeping for this fundamental fact. Memorize the pictures before memorizing the formulas; the formulas will follow naturally from the pictures. In practice, this insight means: whenever you see a matrix on a problem, stop and ask yourself "in which basis is this expressed?" The default answer is standard coordinates, but other bases—eigenvector bases, orthonormal bases, problem-specific bases—often reveal hidden structure and make computation simpler.

## Concrete-first walkthrough

Before diving into abstract ideas, let's build intuition with numbers. We'll walk through Definition 25.1 with a concrete, worked example that you can follow on paper. This is where all the ideas from The pictures come to life: you'll see how to compute $P$, use it to convert coordinates, apply it to transform a matrix, and verify that similarity invariants (trace, determinant) are indeed preserved.

**Setting up two coordinate systems.** Take the standard basis $e_1 = (1,0)$, $e_2 = (0,1)$ and suppose you want to switch to $B = \{b_1, b_2\} = \{(1,1), (1,-1)\}$. These are perfectly good basis vectors: they point in different directions, neither is a multiple of the other, and they span $\mathbb{R}^2$. Visually, the standard basis vectors point right and up; the $B$ basis vectors point northeast and southeast (along the diagonals of a square).

Now here's the question that Definition 25.1 answers: if I describe a vector using basis $B$ (i.e., I tell you the B-coordinates), how do I convert that description to standard coordinates (so you can plot it on a regular xy-axis)? The bridge between these languages is the change-of-basis matrix. That's where Definition 25.1 comes in.

**Starting with Definition 25.1: the change-of-basis matrix.** According to Definition 25.1, the change-of-basis matrix $P$ from $B$ to the standard basis has as its columns the standard-coordinate expressions of the new basis vectors. So we form: 
$$P = \begin{pmatrix}1&1\\1&-1\end{pmatrix}.$$
The first column is $b_1 = (1,1)$ written in standard form; the second column is $b_2 = (1,-1)$ written in standard form. This is the key insight, repeated in every treatment of change of basis: $P$'s columns ARE the new basis vectors, expressed in the old language. Write this down and remember it forever: "the columns are the new guys in old clothes." This one phrase unlocks the entire idea.

Why does this work? Because when you multiply $P$ by the coordinate vector $\begin{pmatrix}1\\0\end{pmatrix}$ in basis $B$ (the first basis vector's coordinates), you get $P \cdot \begin{pmatrix}1\\0\end{pmatrix}$ = the first column of $P$ = $b_1$ in standard coordinates. Same for the second basis vector. So $P$ acts as a translator: input the $B$-coordinates, output the standard coordinates. Every time you form $P$, you're making a phrase book: "in the new basis, the $j$-th basis vector $b_j$ is column $j$ of $P$, said in the old language."

**Converting coordinates from one basis to another.** Now suppose you have a vector written in $B$-coordinates as $(c_1, c_2)$ (meaning the actual vector is $c_1 b_1 + c_2 b_2 = c_1(1,1) + c_2(1,-1)$). To convert to standard coordinates, you compute $P \begin{pmatrix}c_1\\c_2\end{pmatrix}$.

Let's try an example: suppose $(c_1, c_2) = (2, 1)$ in $B$-coordinates. This means the vector is $2(1,1) + 1(1,-1) = (2,2) + (1,-1) = (3, 1)$ in standard coordinates. Let's verify using $P$:
$$P\begin{pmatrix}2\\1\end{pmatrix} = \begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}2\\1\end{pmatrix} = \begin{pmatrix}1(2) + 1(1) \\1(2) + (-1)(1)\end{pmatrix} = \begin{pmatrix}3\\1\end{pmatrix}.$$
Correct! The vector $(3, 1)$ in standard coordinates IS $2b_1 + 1b_2$ in basis $B$-coordinates.

Conversely, if you have standard coordinates and want the $B$-coordinates, multiply by $P^{-1}$. To test this, compute $P^{-1}\begin{pmatrix}3\\1\end{pmatrix}$. We already know $P^{-1} = \begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}$, so:
$$P^{-1}\begin{pmatrix}3\\1\end{pmatrix} = \begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}\begin{pmatrix}3\\1\end{pmatrix} = \begin{pmatrix}(1/2)(3) + (1/2)(1) \\(1/2)(3) + (-1/2)(1)\end{pmatrix} = \begin{pmatrix}2\\1\end{pmatrix}.$$
We get back $(2, 1)$—the $B$-coordinates we started with. This confirms the direction: $P$ goes new→old (new coordinates become old), and $P^{-1}$ goes old→new. Say it aloud: "P is new-to-old, P-inverse is old-to-new."

**Applying the change-of-basis formula to a transformation.** Next, consider a linear transformation $T$ with standard matrix $[T]_{\text{std}} = \begin{pmatrix}0&1\\1&0\end{pmatrix}$, which is reflection across the line $y=x$. This is a well-known geometric transformation: any point $(a,b)$ gets mirrored to $(b,a)$ across the line $y=x$. Theorem 25.1 tells us that the matrix of $T$ relative to basis $B$ is $[T]_B = P^{-1}[T]_{\text{std}}P$. Let's compute it step by step to see what happens when we switch to the tilted basis.

First, we need $P^{-1}$. Using the 2×2 inverse formula, we have $\det(P) = (1)(-1) - (1)(1) = -2$, so:
$$P^{-1} = \frac{1}{-2}\begin{pmatrix}-1&-1\\-1&1\end{pmatrix} = \begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}.$$
Let's double-check that this is correct by verifying $PP^{-1} = I$: the first column of the product is $\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}1/2\\1/2\end{pmatrix} = \begin{pmatrix}1\\0\end{pmatrix}$ and the second column is $\begin{pmatrix}1&1\\1&-1\end{pmatrix}\begin{pmatrix}1/2\\-1/2\end{pmatrix} = \begin{pmatrix}0\\1\end{pmatrix}$. Yes, $PP^{-1} = I$.

Now we need to multiply three matrices in order: $P^{-1}[T]_{\text{std}}P$. Following the order of operations, start by computing $[T]_{\text{std}}P$:
$$\begin{pmatrix}0&1\\1&0\end{pmatrix}\begin{pmatrix}1&1\\1&-1\end{pmatrix} = \begin{pmatrix}1&-1\\1&1\end{pmatrix}.$$
(Check: first row is $0 \cdot 1 + 1 \cdot 1 = 1$ and $0 \cdot 1 + 1 \cdot (-1) = -1$; second row is $1 \cdot 1 + 0 \cdot 1 = 1$ and $1 \cdot 1 + 0 \cdot (-1) = 1$.)

Now multiply by $P^{-1}$ on the left:
$$[T]_B = \begin{pmatrix}1/2&1/2\\1/2&-1/2\end{pmatrix}\begin{pmatrix}1&-1\\1&1\end{pmatrix} = \begin{pmatrix}1&0\\0&-1\end{pmatrix}.$$
(Check: first row is $(1/2)(1) + (1/2)(1) = 1$ and $(1/2)(-1) + (1/2)(1) = 0$; second row is $(1/2)(1) + (-1/2)(1) = 0$ and $(1/2)(-1) + (-1/2)(1) = -1$.)

Remarkable: in the tilted basis $B$, the reflection becomes diagonal! This happens precisely because $b_1=(1,1)$ and $b_2=(1,-1)$ are eigenvectors of the reflection map with eigenvalues $1$ and $-1$ respectively. Let's verify: the reflection of $(1,1)$ across the line $y=x$ is $(1,1)$ itself (it's on the line), so eigenvalue is $1$. The reflection of $(1,-1)$ is $(-1,1)$, which is $-1 \cdot (1,-1)$, so eigenvalue is $-1$. Perfect.

The same geometric object (reflection across $y=x$) has a messy off-diagonal matrix $\begin{pmatrix}0&1\\1&0\end{pmatrix}$ in standard coordinates but a crystal-clear diagonal matrix $\begin{pmatrix}1&0\\0&-1\end{pmatrix}$ in the eigenvector basis $B$. The diagonal entries are exactly the eigenvalues we just verified: $1$ and $-1$. This is the grand payoff of changing coordinates: you can often find a basis where a complicated-looking map becomes trivial and transparent. In the right basis, the map's action is completely obvious—each basis vector is just scaled by its eigenvalue. This is why finding the eigenvector basis is so powerful: it reveals the map's true nature.

**Similar matrices and their invariants.** The Remark from the main file emphasizes that matrices related by $B = P^{-1}AP$ are called *similar*. Two similar matrices describe the same geometric transformation in two different bases. Similar matrices share crucial properties: eigenvalues (both describe the same stretch factors), trace (same sum of diagonal entries), determinant (same volume scaling factor), and rank (same dimension of image). The numerical entries differ wildly, but the *geometric reality* is identical.

This is why these quantities are **similarity invariants**: they measure fundamental properties of the map itself, not the particular coordinate system you chose to write it down in. Two observers standing in different grids and computing trace or determinant of "their" matrix will get the same answer, even if all the matrix entries are different. For instance, with our reflection example: in standard coordinates the trace is $0 + 0 = 0$ and the determinant is $-1$. In the $B$-basis, the trace is $1 + (-1) = 0$ and the determinant is $(1)(-1) = -1$. Identical, as guaranteed. Trace and determinant are *properties of the map*, not properties of the description.

## Proof roadmaps

**Theorem 25.1 — key trick: chase one vector around the commuting square.**

The proof is a coordinate chase, and it's the heart of why Theorem 25.1 works. The idea is simple: to apply a transformation in basis $B$, we can translate to standard coordinates, apply the transformation there, and translate back. This indirect path gives us the matrix in basis $B$.

Take any vector in $B$-coordinates, written $[v]_B$. We want to find $[T(v)]_B$, the image of that vector under the transformation $T$, expressed in $B$-coordinates. By the definition of a matrix relative to a basis, we have $[T(v)]_B = [T]_B[v]_B$. This is what we're trying to find: the matrix $[T]_B$ itself.

But we can also compute $[T(v)]_B$ by traveling around the commuting square. Picture the four-box diagram: start in the top-left with $[v]_B$ (coordinates in basis $B$). Travel right via $P$, converting to standard coordinates: $[v]_{\text{std}} = P[v]_B$. This step asks: "what are these $B$-coordinates when expressed in the standard basis?" Travel down via the standard matrix: $[T(v)]_{\text{std}} = [T]_{\text{std}} P[v]_B$ (this is how $[T]_{\text{std}}$ acts, by definition of matrix-vector multiplication). This step applies the transformation in standard coordinates. Travel left via $P^{-1}$, converting back to $B$-coordinates: $[T(v)]_B = P^{-1}[T]_{\text{std}}P[v]_B$. You've now reached the bottom-left box.

Now the key observation: by the definition of $[T]_B$ (what we mean by the matrix of $T$ relative to basis $B$), this composite path IS $[T]_B[v]_B$. The left-hand side (going directly to bottom-left via matrix $[T]_B$) must equal the right-hand side (the long route around the square). So we have:
$$[T]_B[v]_B = P^{-1}[T]_{\text{std}}P[v]_B$$
for every coordinate vector $[v]_B$. 

Now here's the power move: this equation holds for *every possible* vector in coordinate space. We can let $[v]_B$ range over the standard basis vectors of coordinate space, one at a time (first $e_1$, then $e_2$, etc.). For each basis vector, the two sides match. Therefore, the matrices themselves must be equal, entry by entry:
$$[T]_B = P^{-1}[T]_{\text{std}}P.$$
This is exactly what Theorem 25.1 asserts. The proof is complete. It relies on a standard fact: if two matrices give the same result on all basis vectors, then the matrices are identical. The technique of "apply to basis vectors one at a time" is ubiquitous in linear algebra and appears whenever you need to prove two matrices are equal.

**The big picture.** The proof is transparent once you see the commuting square, but what it reveals is profound. A linear map is a geometric object—a rotation, shear, or stretch—independent of any coordinate system. It's purely geometric; it exists before any matrix is written down. A matrix is an accountant's notation for that object in a particular language. The same map yields different matrices if you change your basis. This is not a contradiction; it means matrices are *relative to a choice of basis*, always, without exception.

Think of it like describing a town's street layout. If I use a north-south/east-west grid, I'd describe locations one way. If you use a tilted grid (say, 45 degrees rotated), the same town's locations get new addresses. But the town is the same physical place. You and I are describing the same physical town (the map) in two different coordinate systems (our grids). The map itself is coordinate-free; it's the geometric reality. When you see $A$ written on a problem set without a basis specified, it's implicitly in standard coordinates. Always ask: which basis is this matrix expressed in? The default answer is standard, but remember that's just a choice, a convention. Other bases are equally valid and often more revealing.

**Direction confusion: P goes new-to-old.** The change-of-basis matrix $P$ points towards the old basis: its columns are the new basis vectors written in the old language. Think of it this way: if you feed $P$ a vector written in the NEW basis, it will spit out that same vector written in the OLD basis. So $P[v]_{\text{new}} = [v]_{\text{old}}$. To go the other direction (old-to-new), multiply by $P^{-1}$. This reversal trips up most students on the first encounter—write it down in large letters: "P is new-to-old; $P^{-1}$ is old-to-new." The mnemonic: the inverse flips the direction.

**Similarity unifies everything.** Two matrices $A$ and $B$ are similar if $B = P^{-1}AP$ for some invertible $P$. Geometrically, they describe the same linear map in two different bases. They're not "equal" in the sense that their entries match; they're "the same geometric object, reported in different languages." Every property depending on the map itself—eigenvalues, trace, determinant, rank—will match between $A$ and $B$; properties depending on the coordinate system might differ (like the actual numerical entries).

Day 11's diagonalization $A = PDP^{-1}$ is revealed as a special case of this change-of-basis formula: you change basis to the eigenvector basis, where the map becomes pure scaling (the diagonal matrix $D$). In eigenvector coordinates, the map is trivial; in standard coordinates, it looks complicated. This is the grand unification: Days 11 and 25 are the same idea, just viewed from two different angles. Diagonalization is not a separate trick—it's a spectacular application of change of basis.

Before you look at flashcards, internalize these key anchor points: (1) The rosetta stone metaphor—$P$ is a translator between languages; (2) The loop idea—to apply a map in a new basis, you loop out, act, then back; (3) Geometric invariants—trace, determinant, rank, eigenvalues survive similarity; (4) Diagonalization is the special case of eigenvector basis choice; (5) Similarity is equivalence under coordinate change. These five ideas are the entire foundation of today's material. Once you've absorbed them, the formulas and computations become straightforward applications of a single coherent principle: matrices describe geometry in a chosen language, and similarity is what stays true across all language choices.

## Flashcards

### Flashcards

**Q:** What are the columns of the change-of-basis matrix $P$ (from basis $B$ to the standard basis)?

**A:** The new basis vectors (the vectors in $B$) expressed in old (standard) coordinates. Column $j$ of $P$ is the $j$-th vector of $B$ written as a standard coordinate vector. Memorize the mnemonic forever: "the columns are the new guys in old clothes." This phrase is the master key.

**Q:** Which direction does $P$ translate, and which direction does $P^{-1}$ translate?

**A:** $P$ translates from $B$-coordinates to standard coordinates: $[v]_{\text{std}} = P[v]_B$. The inverse $P^{-1}$ goes the other way: $[v]_B = P^{-1}[v]_{\text{std}}$. The mnemonic: new→old for $P$, old→new for $P^{-1}$. This is the trickiest direction to remember, so practice it.

**Q:** State the change-of-basis formula for a map's matrix (Theorem 25.1).

**A:** If $T$ has matrix $[T]_{\text{std}}$ relative to the standard basis and $P$ is the change-of-basis matrix from $B$ to standard, then $[T]_B = P^{-1}[T]_{\text{std}}P$. This is the core translation rule: translate in, act, translate out. It's the main formula of today.

**Q:** What does it mean geometrically for two matrices to be "similar"?

**A:** Two matrices $A$ and $B$ are similar if $B = P^{-1}AP$ for some invertible $P$. Geometrically, they represent the same linear map described in two different bases or coordinate systems. The map's geometric reality is identical; only the language changes. They're not equal, they're equivalent.

**Q:** How does diagonalization relate to change of basis?

**A:** Diagonalization $A = PDP^{-1}$ (from Day 11) is a special case of change of basis where $B$ is chosen to be the eigenvector basis. In that language, the map becomes pure scaling: $D$ is diagonal, and the basis elements $P$'s columns are the eigenvectors. It is literally a change of glasses to see the map simply and clearly.

**Q:** Name four similarity invariants—properties shared by all similar matrices.

**A:** Characteristic polynomial, eigenvalues, trace, and determinant. Rank is also a similarity invariant. All of these depend on the map itself, not the coordinate system used to describe it. Two observers in different grids computing these quantities will always agree, no matter what basis they use.
