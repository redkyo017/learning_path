# Day 2 Primer — Linear Independence, Basis, Dimension

## Warm-up

Before reading anything new, answer the flashcards at the end of `primers/day01.md` for: Day 1 (~10 min). Say each answer out loud or on paper *before* flipping.

## The hook

Let's say you're trying to represent every point in the plane $\mathbb{R}^2$ as a combination of three vectors: $u=(1,0)$, $v=(0,1)$, and $w=(1,1)$. Your first thought: "Three direction choices—great, I can definitely cover the plane." 

But here's the catch: $w = u + v$. So $w$ is a *freeloader*. You could throw it out and lose nothing—every point you built with $u,v,w$ you can still build with just $u,v$. This redundancy is what we mean by linear *dependence*—one vector is a mix of the others.

Now comes the real problem. Try to write $(3,5)$ using all three vectors. One way: $3u + 5v + 0w = (3,5)$. But another way: $2u + 4v + 1w = 2(1,0) + 4(0,1) + (1,1) = (3,5)$. Even another: $1u + 3v + 2w = (3,5)$. Infinitely many more: any choice of $a,b,c$ satisfying $a + c = 3$ and $b + c = 5$ works, since $w = u+v$ ensures we can slide the coefficient of $w$ around while adjusting $u$ and $v$ to compensate.

**You can express the same point in infinitely many ways.** Your "address" for $(3,5)$ is no longer unique. Redundancy means ambiguity—the same location has multiple coordinates. With just $\{u,v\}$, $(3,5)$ has exactly one address: $3u + 5v$. But bring $w$ back in, and now the address is $3u + 5v + 0w$, or $2u + 4v + 1w$, or whatever—all saying the same spot.

This is the core insight: independent vectors give you one address per point (good), but dependent vectors give you many addresses (ambiguous, broken). The moment you have a freeloader in your kit, coordinates stop being unique—the same spot gets multiple labels.

Conversely, if you remove all freeloaders from a spanning set (the process described by Theorem 2.2), you're left with a *basis*: a minimal kit with no redundancy and no ambiguity. Every point gets exactly one address. This is the foundation of coordinate systems in linear algebra.

Today's mission: detect the freeloaders (linear independence), learn what a minimal non-redundant kit looks like (basis), and see why every kit that covers the same space has the same size (dimension). These three ideas are the scaffolding that makes everything else in linear algebra work.

## The pictures

**Picture 1: Three arrows, one dashed.**  
Draw three arrows in the plane from the origin: the first pointing to $(1,0)$ (solid), the second to $(0,1)$ (solid), the third to $(1,1)$ (dashed). The dashed arrow sits exactly where $u+v$ lands, making it visually clear: $w$ is not a new direction, it's the sum of the other two. Any point you can reach using all three arrows you can reach using just the solid two. Remove the dashed one and nothing is lost. Label: "Dependent = someone is a mix of the others."

**Picture 2: A basis as a graph-paper grid.**  
Two independent arrows generate perpendicular axes across the plane, with grid lines parallel to each axis, like graph paper or a chessboard. Every point on the page sits at the corner of exactly one grid cell—it has a unique address, a unique pair of coefficients when you express it as a combination of the two basis vectors. Change the basis (rotate the arrows), and the grid rotates, but every point still has exactly one address. Label: "A basis = unique coordinates. Every point gets exactly one combination."

**Picture 3: The Exchange shelf.**  
A shelf labeled "Current spanning set" holds $n$ boxes labeled $(v_1, \dots, v_n)$. A queue labeled "Independent vectors" stands outside with $m$ boxes labeled $(w_1, \dots, w_m)$. One at a time, a $w$-box steps up, and some $v$-box must step off the shelf to make room. After the trade, the shelf still spans the space (the remaining $v$'s plus the new $w$ can still generate everything). The queue never empties a shelf—you always find a $v$ to remove. Label: "Steinitz Exchange: independent $\le$ spanning, so $m \le n$."

## Concrete-first walkthrough

**Definition 2.1 — Independence (the definition).**  
A set of vectors is linearly independent if the *only* way to combine them and get zero is to use all-zero coefficients. Write it as: $a_1v_1 + a_2v_2 + \cdots + a_nv_n = 0$ forces $a_1 = a_2 = \cdots = a_n = 0$. If any nonzero combination gives zero, the set is linearly dependent.

For our example: $\{u,v\} = \{(1,0),(0,1)\}$ is independent. Why? Try $a(1,0) + b(0,1) = (0,0)$. You get $(a,b) = (0,0)$, so the only solution is the trivial one ($a=0, b=0$). No nonzero coefficients can sum to zero—they're independent. 

But $\{u,v,w\}$ is dependent: $1u + 1v - 1w = (1,0) + (0,1) - (1,1) = (0,0)$—a nontrivial relation with coefficients $(1,1,-1) \neq (0,0,0)$. This one relation proves the whole set is dependent.

Another way to see the dependence: try to find coefficients $a,b,c$ (not all zero) such that $au + bv + cw = 0$. Set $c=1$. Then $au + bv + w = 0$ becomes $a(1,0) + b(0,1) + (1,1) = (0,0)$, so $(a+1, b+1) = (0,0)$, giving $a=-1, b=-1$. So $-u - v + w = 0$, which is the same relation, rearranged. Dependence confirmed either way.

**Theorem 2.1 — Dependence rephrased.** (Memory: *the rearrangement trick*)  
A set is linearly independent iff no vector in it is a linear combination of the others. This turns the definition into English: "No freeloaders." If some $v_i = \sum_{j \ne i} c_j v_j$, then rearranging gives a dependence relation. Conversely, any nontrivial relation lets you isolate one vector as a combination of the rest. The two statements—"a dependence relation exists" and "one vector is a mix of the others"—are really the same fact, seen from opposite angles.

This theorem is the bridge between two ways of thinking about independence: the algebraic way (Definition 2.1: solve for coefficients) and the geometric way (Theorem 2.1: check if any vector is redundant). Both perspectives are correct, and Theorem 2.1 proves they're equivalent.

In our example: $w = 1u + 1v$ is a mix of the others, so by Theorem 2.1, the set $\{u,v,w\}$ is dependent. Flip it around: the relation $1u + 1v - 1w = 0$ tells you $w = u+v$. You can always move one vector to the opposite side of a dependence relation to express it as a combination. This duality is the heart of the theorem—algebra doesn't lie.

**Definition 2.2 — Basis and dimension.** (Memory: *minimal spanning, maximal independent*)  
A basis is a set that does two things at once: (1) it *spans* the space (every point is a combination), and (2) it's linearly *independent* (no freeloaders). Either property alone is insufficient—you need both. The dimension of the space is the number of vectors in any basis.

Why "minimal" and "maximal"? A basis is the minimal spanning set (you can't throw any vector away without breaking the span—by Theorem 2.2, a redundant vector can be removed, so a basis is the trimmed version). A basis is also the maximal independent set in that space (you can't add any more vectors from the space without creating dependence). A basis is the *sweet spot*—the Goldilocks zone between "too few" (incomplete span) and "too many" (dependence).

For $\mathbb{R}^2$: $\{u,v\} = \{(1,0),(0,1)\}$ is a basis—it spans all of $\mathbb{R}^2$ and is independent. Therefore $\dim \mathbb{R}^2 = 2$. The set $\{u,v,w\}$ spans $\mathbb{R}^2$ but is not independent, so it's not a basis—it has a freeloader. Any other basis of $\mathbb{R}^2$, like $\{(2,0), (0,1)\}$ or $\{(1,1), (1,-1)\}$, will also have exactly 2 vectors. Different bases, same size—that's the power of Theorem 2.3.

**Theorem 2.2 — Extract a basis from any spanning set.**  
If you have a spanning set (even a redundant one), you can trim it to a basis by discarding freeloaders. The algorithm: if your set is independent, stop—it's already a basis. If not, some vector is a mix of the others (by Theorem 2.1); remove it. Repeat until nothing is left to remove. The span never shrinks because when you remove a freeloader, you can replace every occurrence of it with its expansion throughout any combination. Each deletion strictly shrinks the set size while the span stays the same, so this process must terminate after finitely many steps—and it terminates exactly when the survivors are independent and spanning, i.e., a basis.

In our example: start with $\{u,v,w\}$ spanning $\mathbb{R}^2$. It's dependent: $w = u+v$ is a combination (by Theorem 2.1). Remove $w$, leaving $\{u,v\}$. The span survives: $\operatorname{span}\{u,v\} = \operatorname{span}\{u,v,w\}$ (since $w$ is in the span of $u,v$, any point reachable via $u,v,w$ is reachable via $u,v$ alone). And $\{u,v\}$ is independent. Done—$\{u,v\}$ is a basis of $\mathbb{R}^2$ with dimension 2.

**Lemma 2.3 — Steinitz Exchange Lemma.** (Memory: *the hard workhorse*)  
If $n$ vectors span a space and $m$ vectors are linearly independent in that space, then $m \le n$. The idea: feed the $m$ independent vectors in one at a time. Each one can replace one spanning vector (without shrinking the span), but you never run out of spanning vectors to trade before all $m$ independent ones are placed. This forces $m \le n$. 

Why does this matter? Because it's the engine that makes dimension well-defined—it proves that no independent set can be larger than a spanning set, so all bases (which are both independent and spanning) must have the same size. This is the crucial bottleneck: if you ever tried to fit more independent vectors than spanning vectors, you'd run out of something to swap, proving the sets can't both be independent and span the same space.

This is the hard idea of the day—don't try to reinvent it from scratch, just learn the shape of the proof. The core move: at each step, the next independent vector *must* have a nonzero coefficient on some remaining spanning vector (otherwise it would already depend on earlier independent vectors, contradiction). That nonzero coefficient is your escape route—it's the vector you swap out.

**Theorem 2.3 — Dimension is well-defined.**  
All bases of a space have the same size. Why? Take any two bases $B_1$ and $B_2$. Since $B_1$ spans $V$ and $B_2$ is independent, Lemma 2.3 (applied to these two sets) says $|B_2| \le |B_1|$. Now flip the roles: $B_2$ also spans $V$ (by Definition 2.2), and $B_1$ is also independent, so Lemma 2.3 again gives $|B_1| \le |B_2|$. Together: $|B_1| = |B_2|$. Since $B_1$ and $B_2$ were arbitrary bases, every basis of $V$ has the same cardinality.

This is why $\dim V$ is a single well-defined number, not a vague concept. It doesn't matter which basis you pick to count the dimension—you'll always get the same answer. All rulers agree on the measurement. This is huge: it means dimension is a property of the space itself, not of any particular choice of coordinates. Any honest measurement of the space's "size" (in terms of independent directions) will yield the same number. That's the power of this theorem.

## Proof roadmaps

**How to apply this to exercises:** When you tackle the exercises in the main `day02.md`, watch for these patterns:

1. **To check independence:** Set $a_1v_1 + \cdots + a_nv_n = 0$ and solve for the coefficients. If only $a_i = 0$ (all zeros) works, the set is independent. If you find a nontrivial relation (some $a_i \ne 0$), the set is dependent—and you've found your proof.

2. **To extract a basis from a spanning set:** Start with your spanning set and look for a dependent relation (some vector is a mix of others, or solve the system). Remove the redundant vector. Repeat until you get an independent spanning subset—by Theorem 2.2, you're guaranteed to hit a basis. The span never changes, only the set shrinks.

3. **To use dimension (Theorems 2.2, 2.3):** Once you know $\dim V = n$, two powerful shortcuts appear: (a) any set of $n+1$ vectors in $V$ is automatically dependent (Exercise 5—use Lemma 2.3); (b) if an $n$-vector set spans $V$, it's automatically a basis (Exercise 9—you don't need to check independence separately).

4. **Dimension counts "independent directions":** In $\mathbb{R}^2$, you need exactly 2 independent vectors to span. In $\mathbb{R}^3$, exactly 3. Dimension is the bare minimum. Any basis of a given space has that same minimum size—no more, no fewer.

**Theorem 2.1 — Move the offender to one side.**  
The trick: a dependence relation and "one vector = a combination of the rest" are the same equation, rearranged. You're just reading the algebra in two different directions.

- *Forward direction:* Assume $v_i$ equals a combination of the others: $v_i = \sum_{j \ne i} c_j v_j$. Rearrange by moving everything to one side: $v_i - \sum_{j \ne i} c_j v_j = 0$, which is $1 \cdot v_i + (-c_j)v_j + \cdots = 0$. This is a linear combination that equals zero with the $v_i$-coefficient being $1 \ne 0$. By Definition 2.1, a nontrivial solution exists, so the set is dependent.

- *Backward direction:* Suppose a nontrivial relation exists: $a_1v_1 + \cdots + a_nv_n = 0$ with some $a_k \ne 0$. Isolate $v_k$ by dividing through by $a_k$: $v_k = -\frac{a_1}{a_k}v_1 - \cdots - \frac{a_{k-1}}{a_k}v_{k-1} - \frac{a_{k+1}}{a_k}v_{k+1} - \cdots$. This expresses $v_k$ as a combination of the others, contradicting independence.

**Theorem 2.2 — Evict a freeloader.**  
The trick: repeatedly delete a redundant vector; the span never changes and the set shrinks to independence. Why doesn't the span shrink? Because the removed vector was already in the span of the others—so every span-generating combination can rewrite that vector as a mix and collapse it away. The removed vector contributes no new points to the span.

- If the spanning set is already independent, done—it's a basis.
- Otherwise, some $v_i$ is a mix of the others (by Theorem 2.1): $v_i = \sum_{j \ne i} c_j v_j$. Take any point in the span: $u = \sum_{j=1}^n b_j v_j$. Substitute the expression for $v_i$ into this sum to rewrite $u$ using only the vectors $\{v_1,\dots,v_n\} \setminus \{v_i\}$. The span is unchanged—the same points are still reachable, just via a different set of generators.
- Delete $v_i$ and repeat. The process terminates when the remaining set is independent—at which point you have a basis. Since the original set is finite and shrinks by 1 at each step, termination is guaranteed.

**Lemma 2.3 — Swap in one at a time.**  
The trick (hardest move today): feed the independent $w$'s in one at a time, swapping each one for a spanning $v$, keeping the set spanning after every trade. The key insight: if you ever can't find a $v$ to swap out, then the $w$ you're trying to insert must already depend on the earlier $w$'s, violating their independence. So you *always* have a $v$ to trade, which forces $m \le n$. This is why an independent set can never be larger than a spanning set—you'd run out of spanning vectors to trade.

- *Induction setup:* Let $P(k)$ be: "After relabeling the remaining $v$'s, $\{w_1,\dots,w_k,v_{k+1},\dots,v_n\}$ spans $V$."
- *Base case ($k=0$):* $\{v_1,\dots,v_n\}$ spans—given.
- *Inductive step ($k$ to $k+1$):* Write $w_{k+1} = \sum_{i=1}^k a_i w_i + \sum_{j=k+1}^n b_j v_j$ as a combination of the current spanning set. This is possible because the current set spans by $P(k)$.
  
  Claim: at least one $b_j \ne 0$. Proof: if all $b_j = 0$, then $w_{k+1} = \sum_{i=1}^k a_i w_i$ is a combination of the earlier $w$'s. But $\{w_1,\dots,w_m\}$ is independent, so this is impossible for $w_{k+1}$ (assuming $k+1 \le m$). Contradiction.
  
  So pick any $v_j$ with $b_j \ne 0$; relabel it as $v_{k+1}$. Solve for $v_{k+1}$ and substitute it out everywhere—the new mixed set $\{w_1,\dots,w_{k+1},v_{k+2},\dots,v_n\}$ still spans because every vector in the old set can be rewritten in terms of the new one.

**Theorem 2.3 — Two-way Exchange.**  
This is the payoff of the Exchange Lemma. Take two bases $B_1 = \{v_1,\dots,v_n\}$ and $B_2 = \{w_1,\dots,w_m\}$. Since $B_1$ spans and $B_2$ is independent, Lemma 2.3 immediately gives $m \le n$. But both sets are bases, so their roles are symmetric—$B_2$ also spans and $B_1$ is also independent. Flipping the input to Lemma 2.3, we get $n \le m$. Together: $m = n$. All bases match in size, so dimension is a single well-defined number.

## Flashcards

Use these to test your understanding of the key definitions and theorems. Cover the answer before looking.

**Q:** What is the precise definition of linear independence?  
**A:** A set $\{v_1,\dots,v_n\}$ is linearly independent if $a_1v_1 + \cdots + a_nv_n = 0$ only when $a_1 = \cdots = a_n = 0$.

**Q:** State Theorem 2.1 in one sentence.  
**A:** A set is linearly independent if and only if no vector in it is a linear combination of the others.

**Q:** What are the two requirements for a basis (Definition 2.2)?  
**A:** The set must span the space AND be linearly independent.

**Q:** State the Steinitz Exchange Lemma in one sentence.  
**A:** If $n$ vectors span $V$ and $m$ vectors are linearly independent in $V$, then $m \le n$.

**Q:** Why is dimension well-defined (Theorem 2.3)?  
**A:** Two bases each span and are each independent, so Lemma 2.3 gives both $m \le n$ and $n \le m$, forcing them to have the same size.

**Q:** What is the geometric cost of having a redundant (dependent) spanning vector?  
**A:** Points get multiple addresses—the same vector has infinitely many coordinate representations, destroying uniqueness.

**Q:** Describe the key move in the proof of Theorem 2.1 when a nontrivial relation exists.  
**A:** Isolate the vector with the nonzero coefficient by dividing through by that coefficient; it becomes a linear combination of the others.

**Q:** What is $\dim\{0\}$ (Definition 2.2, edge case)?  
**A:** 0—the basis of the zero space is the empty set, by convention.

**Q:** Can a single nonzero vector ever be linearly dependent?  
**A:** No. By Definition 2.1, if $av = 0$ and $v \ne 0$, then $a = 0$—the only solution is trivial, so a nonzero singleton is always independent.

**Q:** If you extract a basis from a dependent spanning set via Theorem 2.2, is the resulting basis unique?  
**A:** No—different removal orders yield different bases. All bases of the same space have the same size (dimension), but they're usually different sets of vectors. The size is fixed, but the choice of which vectors form the basis is not—you have freedom in the choice as long as you keep the count.

---

Now head to the main `day02.md` and work through the exercises. Practice the three skills: checking independence directly from the definition, extracting a basis from a spanning set, and using dimension shortcuts.
