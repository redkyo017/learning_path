# Day 1 Primer — Vector Spaces, Subspaces, Span

*(Warm-ups start on Day 2.)*

## The Hook

You have two ingredients: $v=(1,2,0)$ and $w=(0,1,1)$ in $\mathbb{R}^3$, and you're allowed to mix them in any proportion—multiply each by any real number, then add. Can you make $(2,5,1)$? Sure: $2v + 1w = (2,4,0) + (0,1,1) = (2,5,1)$. Can you make $(1,1,1)$? Let's see: you'd need $av + bw = (a, 2a+b, b) = (1,1,1)$. So $a=1$, $2a+b=1 \implies b=-1$, and $b=1$. Contradiction. No mixture works.

The point: the set of all mixtures $\{av + bw : a,b \in \mathbb{R}\}$ is *not* all of $\mathbb{R}^3$. It's constrained—the third coordinate is always $b$, and the first two encode $a$ and $2a+b$. What shape is it? A 2-dimensional plane through the origin. The question "What can you reach by mixing?" is central to everything in linear algebra.

This question appears everywhere: In signal processing, "what waveforms can you synthesize from a set of basis signals?" In machine learning, "what decision boundaries can your model represent?" In control systems, "what states can you steer your system into?" All of these are span questions in disguise.

Today we name the "mixing set" (*span*) and learn the vocabulary for sets that deserve the name "space" (*subspaces*). By the end of the day, you'll know why a plane through the origin qualifies as a space, and why a parallel plane that misses the origin does not.

## The Pictures

**Picture 1: Span as a flat sheet.**
Draw two arrows emanating from the origin: one pointing to $v=(1,2,0)$ and one to $w=(0,1,1)$. Now imagine sweeping one arrow around the other, tracing out all the vectors you can reach. You get a thin 2-dimensional plane slicing through 3-dimensional space, always passing through $0$. That plane is span$(\{v,w\})$—the flat sheet of all finite mixtures. Any point on this plane can be written as $av+bw$ for some real numbers $a$ and $b$. Notice: as $a$ and $b$ range over all reals, you fill the entire plane. Nothing escapes it; nothing outside it is reachable.

Why does it always pass through the origin? Because $0 = 0 \cdot v + 0 \cdot w$ is always a mix. This is non-negotiable for a span to be a subspace.

**Picture 2: Why the origin matters.**
Draw the $x$-axis in the plane (a line through the origin). Now draw a parallel line 1 unit above it (missing the origin). Both look like 1-dimensional subsets of $\mathbb{R}^2$, but geometrically they feel very different. The upper line is *not* a subspace: pick two points on it, say $(0, 1)$ and $(1, 1)$, add them, and you get $(1, 2)$—off the line. Closure breaks. The axis-line always remains closed under addition and scaling (any mix of points on it stays on it) *because it includes the origin*. When you scale a point on the axis by 0, you land back on it. 

This is why Definition 1.2 requires $0 \in W$ as condition 1: it's the guarantor of closure. Subspaces must pass through $0$.

**Picture 3: Why intersection works, union doesn't.**
Draw two distinct lines through the origin forming an X: the $x$-axis (with a vector $u=(1,0)$ on it) and the $y$-axis (with a vector $w=(0,1)$ on it). Their sum $u+w=(1,1)$ points diagonally, off *both* axes. So the union of the two axes is not closed under addition—it's not a flat, it's an angular shape. But their intersection is just the origin $\{(0,0)\}$, a trivial subspace. This illustrates Definition 1.2: intersection of subspaces stays flat; union generally does not. The remark in the day file uses this exact example.

## Concrete-First Walkthrough

Before diving into the theory section, here's the intuition with $v=(1,2,0)$ and $w=(0,1,1)$ to anchor everything. As you read the day file, you'll encounter Definitions 1.1–1.3 and Theorems 1.1–1.2 in formal language. This section builds the memory hooks first, so when you see the formal statements, they feel like naming something you already understand.

**Definition 1.1 (Vector space).** A vector space is a room where adding vectors and scaling by real numbers never take you outside. The eight axioms listed in the theory section are just the arithmetic rules you already obey—commutativity, associativity, distributivity—promoted to law. You're allowed to operate freely without fear of stepping outside the room.

Why should we care? Because if you know a set is a vector space, you can rely on familiar algebra. You don't have to verify addition and scaling work in that set—they do, by definition.

Example: $\mathbb{R}^3$ is a vector space. If you add $(1,2,0) + (0,1,1) = (1,3,1)$, you stay in $\mathbb{R}^3$. If you scale $3 \cdot (1,2,0) = (3,6,0)$, you stay in $\mathbb{R}^3$. The eight axioms all hold because coordinate arithmetic works that way. You could also check that $(0,0,0)$ exists, additive inverses exist, and distributivity holds—but you already know these from arithmetic, so the axioms feel less like restrictions and more like formalization.

**Definition 1.2 (Subspace).** A subspace is a flat through the origin. To test whether a subset $W$ of a vector space $V$ is a subspace, check three things: (1) Does $W$ contain zero? (2) Closed under addition: if $u, v \in W$, is $u+v \in W$? (3) Closed under scaling: if $u \in W$ and $c \in \mathbb{R}$, is $cu \in W$?

Why only these three? Because if these three hold, *all* eight axioms are automatically inherited from $V$. So a subspace is a vector space in its own right—and the shortcut test saves you from having to check commutativity, associativity, and associativity of scalar multiplication all over again.

Example 1: Let $W = \{(x,y,z) : z = x + y\}$ (the plane defined by the constraint $z = x+y$ in $\mathbb{R}^3$). Check: (1) Does $(0,0,0) \in W$? Yes, $0 = 0+0$ ✓. (2) If $(x_1,y_1,x_1+y_1), (x_2,y_2,x_2+y_2) \in W$, their sum is $(x_1+x_2, y_1+y_2, x_1+x_2+y_1+y_2) = (x_1+x_2, y_1+y_2, (x_1+x_2)+(y_1+y_2))$, which satisfies the plane equation ✓. (3) If $(x,y,x+y) \in W$ and $c \in \mathbb{R}$, then $c(x,y,x+y) = (cx, cy, cx+cy)$ ✓. All three hold, so $W$ is a subspace.

Counterexample: the plane $\{(x,y,z) : z = x + y + 1\}$ (shifted up by 1). Does it contain the origin? $(0,0,0)$ has $0 = 0 + 0 + 1$? No. So it's not a subspace, even though it looks geometrically "flat."

Example 2: $W = \{(x,y,z) : x + y + z = 0\}$ (vectors in $\mathbb{R}^3$ summing to 0). Check: (1) $(0,0,0)$ sums to 0 ✓. (2) If $(x_1,y_1,z_1)$ and $(x_2,y_2,z_2)$ sum to 0 each, then $(x_1+x_2) + (y_1+y_2) + (z_1+z_2) = 0+0 = 0$ ✓. (3) If $(x,y,z)$ sums to 0 and $c \in \mathbb{R}$, then $cx + cy + cz = c(x+y+z) = c \cdot 0 = 0$ ✓. Subspace.

**Definition 1.3 (Linear combination, span).** A linear combination of vectors $v_1, \ldots, v_k$ is any sum $a_1v_1 + a_2v_2 + \cdots + a_kv_k$ for real number weights. The span of a set $S$ is the collection of *all* finite linear combinations of vectors from $S$. Span is the answer to: "What can I reach by mixing?"

Example: span$(\{v,w\}) = \{av + bw : a,b \in \mathbb{R}\}$ with $v=(1,2,0)$ and $w=(0,1,1)$. Every vector in this span has the form $(a, 2a+b, b)$ for some $a,b$. The vector $(2,5,1)$ is in the span ($a=2, b=1$). The vector $(1,1,1)$ is not (we get a contradiction: first coordinate gives $a=1$, second gives $2a+b=1 \Rightarrow b=-1$, third gives $b=1$—clash).

Another example: span$(\{(1,0), (0,1)\}) = \mathbb{R}^2$—any vector is reachable. span$(\{(1,0)\}) = \{(t,0) : t \in \mathbb{R}\}$—just the $x$-axis, a 1-dimensional line. By convention, span$(\emptyset) = \{0\}$ (the empty mixture is zero).

**Theorem 1.1 (The span of a set is a subspace).** No matter what set $S$ you choose, span$(S)$ is always a subspace. Why? Because the set of all mixtures is itself closed under mixing and scaling—a fundamental principle that will echo throughout the entire course.

Example: span$(\{v,w\})$ contains $(2,5,1) = 2v+1w$ and $(3,7,2) = 3v+2w$. Their sum is $(5,12,3) = 5v+3w$, which is again a mixture of $v$ and $w$, so it's in the span. Scaling works the same way: $5 \cdot (2,5,1) = 5(2v+w) = 10v+5w$, also in the span. You can also scale by 0: $0 \cdot v + 0 \cdot w = (0,0,0)$, the zero vector, showing the span contains it.

This means: if you take any finite list of vectors, their span forms a "flat through the origin"—a subspace. The mixing set never closes off or leaves a gap. Why does this matter? Because it means you can always rely on the structure: once you know span$(S)$ is a subspace, you know every theorem about subspaces applies to it automatically.

**Theorem 1.2 (Intersection of subspaces is a subspace).** If $W_1$ and $W_2$ are both subspaces, their overlap $W_1 \cap W_2$ is also a subspace. This is reassuring: shared properties preserve structure. A vector living in both respects both rules of closure.

Example: If $W_1$ is the $x$-axis $\{(x,0,0) : x \in \mathbb{R}\}$ and $W_2$ is the $xy$-plane $\{(x,y,0) : x,y \in \mathbb{R}\}$, then $W_1 \cap W_2$ is the $x$-axis itself—which is a subspace. Every point in the intersection must satisfy both constraints: be on the axis and be in the plane. Another example: if $W_1 = \{(x,y,z) : z=0\}$ and $W_2 = \{(x,y,z) : x=0\}$, then $W_1 \cap W_2 = \{(0,y,0) : y \in \mathbb{R}\}$—the $y$-axis in the $xy$-plane, a subspace.

**Remark (The union of subspaces is generally not a subspace).** Don't assume that $W_1 \cup W_2$ is also a subspace—it usually isn't. Take $u$ from $W_1$ and $w$ from $W_2$; their sum often lands outside both, breaking closure. An X is not a flat. This is a common pitfall: you might expect that "either $W_1$ or $W_2$" would behave as well as "both $W_1$ and $W_2$," but closure breaks the analogy. Always verify closure when you're unsure.

### Why This Architecture Matters

You've now seen the building blocks:
- **Vector spaces** are the rooms where algebra works.
- **Subspaces** are the flats inside them that inherit the structure (contain 0, closed under + and scaling).
- **Span** is the subspace generated by a set—the reachable region by mixing.
- **Intersection** of subspaces is a subspace; **union** generally is not.

This vocabulary will repeat throughout the course with different objects (matrices, polynomials, functions). By mastering it on $\mathbb{R}^n$ first, you'll be ready to apply it everywhere. The three-condition subspace test (Definition 1.2) will become your workhorse for the next week.

## Proof Roadmaps

These are the scaffolds for the key proofs. When you read the full proofs in the main file, use these roadmaps as sign-posts. The point of each roadmap is to show you the *shape* of the argument before you see the technical details.

**Theorem 1.1 (The span is a subspace)—Key trick:** Don't try to describe the shape of the span geometrically. Instead, grab two arbitrary elements of span$(S)$ and mechanically verify the three subspace conditions. A "combination of combinations" is still a combination—that's the heart of it.

- **Hint 1 (contains 0):** Either $S$ is empty (convention: empty sum $= 0$), or pick any $s \in S$ and note $0 = 0 \cdot s \in$ span$(S)$.
- **Hint 2 (closed under addition):** Write two spanning vectors $u = \sum_i a_i s_i$ and $v = \sum_j b_j t_j$ using their own index sets. Merge the two index sets, pad with zero coefficients where a vector doesn't appear in one sum, and rewrite both over the merged index. Now $u+v = \sum_k (c_k + d_k) r_k$ is a single finite combination—still in the span. The coefficients changed, but you're still mixing vectors from $S$.
- **Hint 3 (closed under scaling):** If $u = \sum_i a_i s_i$ and $c \in \mathbb{R}$, then $cu = \sum_i (ca_i) s_i$—multiply every coefficient by $c$. Still a finite combination, still in the span. The recipe didn't leave the set; it stayed there.

**Theorem 1.2 (Intersection of subspaces is a subspace)—Key trick:** To show $W_1 \cap W_2$ has a property, show it holds in $W_1$ *and* in $W_2$ separately, then conclude it holds in the overlap. A vector that lives in both subspaces is governed by both their closure rules.

- **Hint 1 (contains 0):** $0 \in W_1$ (since $W_1$ is a subspace) and $0 \in W_2$ (since $W_2$ is a subspace). So $0$ is in both, hence in $W_1 \cap W_2$.
- **Hint 2 (closed under addition):** If $u,v \in W_1 \cap W_2$, then $u,v$ lie in both. Use closure in $W_1$ to get $u+v \in W_1$, and closure in $W_2$ to get $u+v \in W_2$. Thus $u+v \in W_1 \cap W_2$. The sum is caught by both nets.
- **Hint 3 (closed under scaling):** Apply the same logic: if $u \in W_1 \cap W_2$, then $cu \in W_1$ (by $W_1$ closure) and $cu \in W_2$ (by $W_2$ closure), so $cu$ is in the intersection. Scaling obeys both rules.

## Flashcards

Use these to self-check understanding. Shuffle them, quiz yourself before looking at answers, and revisit any that feel shaky.

**Q:** What are the three conditions for testing whether a subset is a subspace?

**A:** Contains 0, closed under addition, and closed under scalar multiplication.

---

**Q:** Define span$(S)$ precisely.

**A:** The set of all finite linear combinations of vectors from $S$: $\text{span}(S) = \{a_1v_1 + \cdots + a_nv_n : v_i \in S, a_i \in \mathbb{R}, n \in \mathbb{N}\}$.

---

**Q:** Is a line through the origin always a subspace? What about a line that does not pass through the origin?

**A:** Yes to the first. No to the second—it fails to contain 0 (and closure under addition breaks too).

---

**Q:** What is the slogan for Theorem 1.1?

**A:** "The mixing set is itself a room"—span$(S)$ is always a subspace of $V$, no matter what $S$ is.

---

**Q:** Is the union of two subspaces always a subspace?

**A:** No. Counterexample: two distinct lines through the origin (like an X). Pick a vector from each line; their sum typically lands off both lines, violating closure. The intersection, however, is always a subspace.

---

**Q:** What is the one subspace-membership property that every subspace must have, by definition?

**A:** Every subspace contains the zero vector. This is guaranteed by the axioms of vector spaces (any subspace inherits them).

---

**Q:** By convention, what is span of the empty set?

**A:** span$(∅) = \{0\}$, because the empty sum is defined to be 0.

---

**Q:** Give an example of a set that contains 0 and is closed under addition, but is not a subspace.

**A:** The set of integers $\mathbb{Z}$ inside the vector space $\mathbb{R}$. It contains 0, is closed under addition (sum of integers is an integer), but fails closure under scalar multiplication: $\frac{1}{2} \cdot 2 = 1 \in \mathbb{Z}$ ✓, but $\frac{1}{3} \cdot 1 = \frac{1}{3} \notin \mathbb{Z}$. All three conditions are required.

---

**Q:** How do you decide whether a given vector $v$ is in span$(S)$?

**A:** Solve the system: write $v$ as a linear combination $v = a_1s_1 + \cdots + a_ns_n$ of vectors in $S$, where $a_i \in \mathbb{R}$ are unknowns. If a solution exists, $v$ is in the span; if not, it isn't (see Exercise 7 in the day file for a concrete example).

