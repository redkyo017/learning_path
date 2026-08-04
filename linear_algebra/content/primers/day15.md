# Primer — Day 15: Orthogonal Complements, Gram-Schmidt

## Warm-up

Before diving into today's theory, revisit Day 14 (inner products, norms, and orthogonality) to refresh the machinery of perpendicularity: how to recognize orthogonal vectors via vanishing inner products and how to compute norms.

Recall that orthogonality is detected by the inner product being zero, and norms quantify length. Spend a few minutes reworking one or two inner-product computations from Day 14 to get the mechanics into your fingers. Work through the computation on paper.

Then review Day 12's treatment of subspaces and span—today we will be partitioning all of V into two orthogonal subspaces W and W⊥, so you need to be fluent with what it means for a set to span a subspace and how to verify closure properties.

Subspaces are closed under addition and scalar multiplication; we will use these facts repeatedly in today's proofs. Make sure you can verify that a set is a subspace in under two minutes.

Finally, touch Day 8's definition of linear independence and bases. Gram-Schmidt transforms an arbitrary basis into a special one while preserving the underlying span. Why does this work? Because Gram-Schmidt never removes a vector entirely; it only subtracts projections, which preserves the span.

These three ingredients—orthogonality, subspaces, and linear independence—combine today into the theory of orthogonal decomposition and the Gram-Schmidt algorithm, which has become a workhorse of numerical linear algebra and data analysis.

## The hook

Imagine you are working with a tilted plane W in ℝ³ spanned by two vectors: v₁ = (1,1,0) and v₂ = (1,0,1).

Technically these form a basis of W, so you can represent any point on the plane as a linear combination of them. However, they are not orthogonal to each other—their dot product is 1, not zero—and their norms are not equal to each other.

This means every inner-product calculation you perform with them drags along cross-terms and requires constant bookkeeping of factors of √2. Try computing a single projection: tedious.

Your goal is to replace this awkward pair with a "square grid": two orthogonal unit vectors e₁ and e₂ that span the same plane, making every subsequent calculation clean.

The algorithm is elementary: keep v₁ as-is; from v₂, subtract its "shadow" on v₁.

What is this shadow? It is the orthogonal projection of v₂ onto the line through v₁, computed via the projection formula: $\frac{\langle v_2, v_1 \rangle}{\langle v_1, v_1 \rangle} v_1 = \frac{1}{2} (1,1,0)$.

Subtract it: $u_2 = v_2 - \frac{1}{2}(1,1,0) = (1/2, -1/2, 1)$.

Verify orthogonality: $(1/2, -1/2, 1) \cdot (1,1,0) = 1/2 - 1/2 + 0 = 0$. They are perpendicular!

Now normalize both: $e_1 = \frac{(1,1,0)}{\sqrt{2}}$ and $e_2 = \frac{(1/2, -1/2, 1)}{\sqrt{1.5}}$.

You now have an orthogonal grid for the same plane.

This "subtract the shadows" pattern is the essence of the Gram-Schmidt algorithm. It generalizes perfectly to any finite-dimensional inner-product space: given any basis, repeatedly subtract each new vector's projection onto all previous directions to orthogonalize, then normalize.

The intuition is simple: at each step, you remove all the parts of the new vector that "point in directions you've already fixed," leaving only the genuinely new direction.

## The pictures

**Picture 1: Floor and pole.**

Think of W as a tilted floor in a room and W⊥ as a vertical pole sticking straight up from the floor.

Every vector v in the room can be decomposed into exactly two perpendicular pieces: its shadow on the floor (the component in W) and its height measured straight up relative to the floor (the component in W⊥).

These two pieces together completely describe v, and they are always orthogonal to each other because one points along the floor and the other points perpendicular to it.

The decomposition is unique: you cannot write v as a floor-shadow plus a height in two different ways, because any two decompositions would produce the same floor-shadow and the same perpendicular part. This is the content of Theorem 15.1.

The floor has dimension k, the pole has dimension n − k, and together they account for all n dimensions.

**Picture 2: The Gram-Schmidt step.**

Suppose you have already built an orthonormal basis q₁, q₂, …, q_{k−1} for the first k−1 directions.

Now v_k arrives. Geometrically, v_k has a "shadow" on each of the q₁, …, q_{k−1} directions—the component of v_k that already points along each q_i.

These shadows are ⟨v_k, q_i⟩q_i, and they represent the parts of v_k that "point in old directions" already accounted for.

The new direction u_k is formed by v_k minus the sum of all these shadows: $u_k = v_k - \sum_{i<k} \langle v_k, q_i \rangle q_i$.

Subtracting off all the "old directions" leaves only the genuinely new part of v_k, which by construction is perpendicular to all previous directions.

This is the key insight of Gram-Schmidt: the residual after projecting v_k onto the span of q₁, …, q_{k−1} is always orthogonal to that span.

After normalizing to unit length, you obtain q_k, and the process repeats.

**Picture 3: Dimension bookkeeping.**

If W is a k-dimensional subspace of V (an n-dimensional space), then W⊥ has dimension exactly n − k.

Together, dim W + dim W⊥ = n.

The floor and pole dimensions always add up to the total room dimension, with no overlap or ambiguity.

This relationship follows from the orthogonal decomposition theorem (Theorem 15.1) and is a powerful counting tool when analyzing subspaces and their complements.

It is also the source of the rank-nullity theorem for linear maps, which appears later in the course.

## Concrete-first walkthrough

Before reading the full proofs in `content/day15.md`, read both Theorem 15.2 (Gram-Schmidt) and Theorem 15.1 (orthogonal decomposition) *statement-first*—see what each one claims to do.

This is crucial because the main file proves Theorem 15.1 by *using* Theorem 15.2 in its proof, so they are logically entangled.

Seeing both goals upfront helps you understand the dependence and motivates why each part matters.

The logical flow is: Gram-Schmidt exists (Thm 15.2), therefore we can build orthonormal bases of any subspace W, therefore we can prove the orthogonal decomposition (Thm 15.1).

Next, *attempt the Gram-Schmidt proof first* (Theorem 15.2): it is self-contained, uses only induction and properties of orthonormality, and does not depend on Theorem 15.1.

Once you understand how Gram-Schmidt produces an orthonormal basis from any basis of a subspace, return to Theorem 15.1 and its uniqueness argument, which relies on the key property that W ∩ W⊥ = {0}.

**Definition 15.1** introduces the orthogonal complement: $W^\perp = \{v \in V : \langle v, w \rangle = 0 \text{ for all } w \in W\}$. This is the set of all vectors that are perpendicular to every single vector in W, not just some vectors in W. Slogan: the "orthogonal world" to W—all directions orthogonal to W. Understanding this definition precisely is the foundation for everything that follows.

**Lemma 15.1** (W⊥ is a subspace) proves that this orthogonal world is closed under addition and scalar multiplication, so it is itself a subspace of V. The key trick: orthogonality to a fixed w is a linear condition in v, so it is preserved by adding two orthogonal vectors or scaling an orthogonal vector. Every step uses only the bilinearity of the inner product.

**Definition 15.2** defines orthonormal sets: a finite set of vectors {e₁, …, e_k} is orthonormal if $\langle e_i, e_j \rangle = \delta_{ij}$ for all i, j, where δ_{ij} is 1 when i = j and 0 otherwise. In words: pairwise orthogonal (perpendicular to each other) and all unit norm (each vector has length 1). Think: a perfect perpendicular-and-normalized grid, the analog of the standard basis in any inner-product space.

**Theorem 15.1** (Orthogonal decomposition: V = W ⊕ W⊥) is the conceptual centerpiece: every vector v ∈ V can be written *uniquely* as v = w + w' with w ∈ W and w' ∈ W⊥. Slogan: **shadow on W plus perpendicular leftover, exactly one way**. This decomposition immediately implies dim V = dim W + dim W⊥, a powerful relationship that ties together the dimensions of a subspace and its orthogonal complement.

**Theorem 15.2** (The Gram-Schmidt process) is the algorithm that makes Theorem 15.1 constructive. Given any basis v₁, …, v_n of a subspace U, the algorithm recursively defines $u_k = v_k - \sum_{i < k} \frac{\langle v_k, u_i \rangle}{\langle u_i, u_i \rangle} u_i$ and then sets $e_i = u_i / \|u_i\|$. This produces an orthonormal basis e₁, …, e_n of U with the same span. Slogan: **keep what's new; subtract the shadows on everything so far, normalize, repeat**. The crucial technical detail preserved at every intermediate step k is span{u₁, …, u_k} = span{v₁, …, v_k}—this property is exactly why QR decomposition (Day 17) works correctly.

## Proof roadmaps

**Theorem 15.2 (Gram-Schmidt)** proves three properties hold at every step k: u_k is nonzero, the vectors u₁, …, u_k are pairwise orthogonal, and the span relationship span{u₁, …, u_k} = span{v₁, …, v_k} holds.

The proof uses mathematical induction on k. The base case k=1 is trivial: u₁ = v₁ is nonzero (since v₁ is part of a basis), and span{u₁} = span{v₁} trivially.

The inductive step is the heart of the argument. Assume the three properties hold for k−1.

Define $u_k = v_k - \sum_{i < k} \frac{\langle v_k, u_i \rangle}{\langle u_i, u_i \rangle} u_i$ (subtract all the shadows of v_k on earlier directions).

To verify orthogonality with the earlier vectors, fix j < k and compute $\langle u_k, u_j \rangle$ by expanding with bilinearity.

The sum $\sum_{i < k} \frac{\langle v_k, u_i \rangle}{\langle u_i, u_i \rangle} \langle u_i, u_j \rangle$ telescopes to zero because by induction hypothesis the earlier u_i are pairwise orthogonal (all terms vanish except i = j, where ⟨u_j, u_j⟩ in the denominator and numerator cancel exactly), leaving only $\langle v_k, u_j \rangle - \langle v_k, u_j \rangle = 0$.

For the nonzero property: if u_k were zero, then v_k would equal the sum $\sum_{i < k} \frac{\langle v_k, u_i \rangle}{\langle u_i, u_i \rangle} u_i$, lying in span{v₁, …, v_{k−1}}, contradicting linear independence of the input basis.

Span equality follows because u_k is v_k minus a linear combination of earlier terms, so bidirectionally the spans of {u₁, …, u_k} and {v₁, …, v_k} agree.

**Theorem 15.1 (Orthogonal decomposition)** proves existence and uniqueness separately.

For *existence*, apply Gram-Schmidt to any basis of W to obtain an orthonormal basis q₁, …, q_k of W (this is now legal because of Theorem 15.2).

Define $w = \sum_{i=1}^k \langle v, q_i \rangle q_i$ (the shadow or projection of v onto W) and $w' = v - w$ (the residual perpendicular part).

Check that w' ∈ W⊥ by computing $\langle w', q_j \rangle$ for each basis vector q_j: using bilinearity, $\langle v - \sum \langle v, q_i \rangle q_i, q_j \rangle = \langle v, q_j \rangle - \langle v, q_j \rangle \cdot 1 = 0$ (by orthonormality of the q_i, only the i = j term survives in the sum and it exactly cancels).

So w' is orthogonal to every basis vector of W, hence orthogonal to all of W.

For *uniqueness*, suppose v = w₁ + w₁' = w₂ + w₂' with w_i ∈ W and w₁', w₂' ∈ W⊥.

Rearrange: w₁ − w₂ = w₂' − w₁'.

The left side lies in W (subspaces are closed under subtraction), the right lies in W⊥ (by Lemma 15.1), so their common value x lies in both: x ∈ W ∩ W⊥.

Now, x ∈ W⊥ means ⟨x, u⟩ = 0 for all u ∈ W; since x ∈ W as well, take u = x to get ⟨x, x⟩ = 0.

By positive-definiteness of the inner product, x = 0. Thus W ∩ W⊥ = {0}, forcing w₁ = w₂ and w₁' = w₂'.

## Flashcards

### Flashcards

**Q:** Define W⊥.

**A:** The set of all vectors orthogonal to every vector in W.

**Q:** State the orthogonal decomposition theorem in one sentence.

**A:** Every vector v splits uniquely as w + w' with w ∈ W and w' ∈ W⊥.

**Q:** Why is the orthogonal decomposition unique?

**A:** Any difference of two decompositions would lie in W ∩ W⊥ = {0}, since only the zero vector is orthogonal to itself.

**Q:** Describe the Gram-Schmidt step in words.

**A:** Take the new vector, subtract its projections (shadows) on all previous orthonormal directions, normalize what remains.

**Q:** Why is the Gram-Schmidt leftover u_k never zero?

**A:** The input vectors form a basis (linearly independent), so v_k doesn't lie in span of its predecessors.

**Q:** What is the formula for the projection (shadow) of v onto an orthonormal basis of W?

**A:** ∑ᵢ ⟨v, qᵢ⟩ qᵢ, where q₁, …, qₖ is an orthonormal basis of W.

**Q:** Relate the dimensions: dim W + dim W⊥ = ?

**A:** dim V; the floor and pole together account for every direction in the room.

**Q:** What does Gram-Schmidt preserve at every intermediate step k?

**A:** The span: span{u₁, …, uₖ} = span{v₁, …, vₖ}, which is why QR decomposition works.
