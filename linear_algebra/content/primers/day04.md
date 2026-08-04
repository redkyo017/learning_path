# Day 4 Primer — Kernel, Image, Rank-Nullity

## Warm-up

Start here to land where Day 4 meets what came before.

- **Day 3 memory:** You know that a linear map $T: V \to W$ must send $0_V$ to $0_W$, and addition/scaling are preserved. Today we're asking: which inputs get *crushed* to zero, and which outputs are *reachable*?
- **Day 2 memory:** You can extend any linearly independent set to a basis (Exercise 6). Today's main proof uses this fact directly — we'll build a basis in two pieces and watch the second piece determine the image dimension.
- **Day 1 memory:** Dimension is the size of a basis. Today: dimensions will *add up* in a fixed way, no matter what map we pick.

## The hook

Picture a projection: flatten $\mathbb{R}^3$ onto the horizontal floor by sending $(x,y,z) \mapsto (x,y,0)$.

Two questions with numbers:
- **What gets crushed to zero?** The vertical line $(0,0,z)$ for any $z \in \mathbb{R}$ — that's 1 independent direction collapsing to the origin.
- **Where can you land?** Any point on the floor $(x,y,0)$ — that's 2 independent directions you can reach.

The punchline: $1 + 2 = 3$. Is this a coincidence? Never. The theorem (Theorem 4.1) says: crushed + kept = total, always.

**Follow-up:** Could ANY linear map from $\mathbb{R}^3$ to $\mathbb{R}^2$ be reversible (invertible)?  
*No.* Rank-nullity forces this: if you're mapping into only 2 dimensions, at least one dimension in the input must be crushed. Something nonzero must disappear — so it can't be injective, and hence not invertible. This is the "dimension can't grow" principle: you cannot inject a 3-dimensional space into a 2-dimensional one linearly.

## The pictures

1. **Projection flattening:** Draw $\mathbb{R}^3$ as a cube. Mark the vertical line (the $z$-axis through the origin) collapsing to a single dot at the origin — label it "kernel (crushed)." Mark the horizontal plane (the $xy$-plane) as the landing zone — label it "image (where you can land)." These two regions partition what happens to the map: everything on the vertical line gets sent to zero; everything else survives projection.

2. **Pipe diagram:** Draw an arrow labeled "$n$ dimensions" flowing in. Inside the pipe, split it: one branch labeled "lost (nullity $= k$)" flowing into a drain, the other labeled "delivered (rank $= r$)" flowing out. At the exit, label the output "$r$ dimensions." Below, write $k + r = n$. This visualizes conservation: input splits into two disjoint flows, and they recombine to equal the input count.

3. **Invertible matchmaking:** Draw two ovals: input space $V$ (left) and output space $W$ (right). Draw arrows from each point in $V$ to exactly one point in $W$ (no two inputs collide — injective). Separately show that every point in $W$ is hit (no misses — surjective). Label the whole picture: "Perfect one-to-one correspondence = isomorphism." This is the visual definition of invertibility.

## Concrete-first walkthrough

Master these five concepts with examples first, then patterns.

**Definition 4.1 — kernel and image:**

Kernel is *what gets crushed to 0*: $\ker T = \{v : T(v) = 0\}$. 

Image is *where you can actually land*: $\mathrm{im}\,T = \{T(v) : v \in V\}$.

*Numeric example:* Let $T: \mathbb{R}^3 \to \mathbb{R}^2$ be $T(x,y,z) = (x+y, 0)$. Then $T(x,y,z) = (0,0)$ requires $x+y=0$, so $\ker T = \{(t,-t,z) : t,z \in \mathbb{R}\}$ — all inputs where $x = -y$ (and $z$ is free). This is a 2-dimensional plane in $\mathbb{R}^3$ (spanning vectors: $(1,-1,0)$ and $(0,0,1)$). The image is everything of the form $(a, 0)$ for any $a$ — a line in $\mathbb{R}^2$, dimension 1. Both are subspaces; closure under addition and scaling flow directly from linearity of $T$. Notice: dimension split is $2 + 1 = 3$ ✓ (this is rank-nullity in action).

**Definition 4.2 — invertible, isomorphism:**

Invertible means *there's an exact undo*: a map $S$ with $S \circ T = \mathrm{id}_V$ and $T \circ S = \mathrm{id}_W$. An invertible map is also called an *isomorphism*, and we say *the two spaces are the same space wearing different clothes* — structurally identical, just coordinate systems differ.

*Numeric example:* The matrix $\begin{pmatrix}2 & 0 \\ 0 & 3\end{pmatrix}$ sends $(x,y) \mapsto (2x, 3y)$. Its inverse is $\begin{pmatrix}1/2 & 0 \\ 0 & 1/3\end{pmatrix}$, sending $(a,b) \mapsto (a/2, b/3)$. Check: $\begin{pmatrix}1/2 & 0 \\ 0 & 1/3\end{pmatrix} \begin{pmatrix}2 & 0 \\ 0 & 3\end{pmatrix} = \begin{pmatrix}1 & 0 \\ 0 & 1\end{pmatrix} = \mathrm{id}$ ✓. Every output is hit exactly once; every input reaches a unique output — perfect one-to-one correspondence. The two $\mathbb{R}^2$ spaces are the same structure, just with different scaling on each coordinate.

**Lemma 4.1 — injective test via kernel:**

Injective means *no two inputs collide*. The slogan: *the kernel is the injectivity meter.* Mathematically: injective $\iff$ $\ker T = \{0\}$.

*Numeric example:* Consider $T: \mathbb{R}^2 \to \mathbb{R}^3$, $T(x,y) = (x, y, x+y)$. Is it injective? Find $\ker T$: if $T(x,y) = (0,0,0)$, then $x=0$, $y=0$, so $\ker T = \{0\}$. The kernel is trivial, so $T$ is injective (no two inputs produce the same output). Test: suppose $T(2,3) = T(a,b)$. Then $(2,3,5) = (a,b,a+b)$, so $a=2, b=3$ — forced unique. Why the general principle works? If $T(u) = T(v)$, linearity gives $T(u-v) = 0$, so $u-v$ is in the kernel; if the kernel is only zero, then $u - v = 0$, hence $u = v$. This reduces checking all pairs to checking a single set.

**Theorem 4.1 — rank-nullity (the day's main event):**

The conservation law: $\dim\ker T + \dim\mathrm{im}\,T = \dim V$. Slogan: *crushed + kept = total*.

*Numeric example (revisited):* The projection $T(x,y,z) = (x,y,0)$ on $\mathbb{R}^3$ has $\ker T = \text{span}\{(0,0,1)\}$ (dimension 1) and $\mathrm{im}\,T = \text{span}\{(1,0,0), (0,1,0)\}$ (dimension 2). Check: $1 + 2 = 3 = \dim \mathbb{R}^3$ ✓. The domain dimension *always* splits between crushed input directions and output directions that survive. You cannot compute both from scratch if you know one — subtract from the domain dimension and you're done.

**Why rank-nullity matters:** This is a *conservation law* — input dimension is partitioned into two pieces, no more, no less. Once you count how many directions are crushed (nullity), you instantly know how many directions survive (rank). This unlocks the whole invertibility toolkit: if you know the domain is 5-dimensional and you crush 2 directions, the image is 3-dimensional; the map cannot be onto a 4-dimensional codomain. Rank-nullity forbids many possibilities before any computation.

**Theorem 4.2 — equal-dimension equivalence:**

For maps between spaces of equal dimension, *one virtue buys them all*: injective $\iff$ surjective $\iff$ invertible.

*Why?* Rank-nullity creates a seesaw: if rank + nullity = $n$ and both spaces have dimension $n$, then zero nullity forces full rank, which forces you hit all of the codomain (surjectivity). If something is crushed (nullity $> 0$), the rank can't fill the codomain (not surjective). Every equivalence is just one glance at the same equation. For example, a $3 \times 3$ matrix: if its kernel contains only zero (nullity = 0), rank-nullity gives rank = $3 - 0 = 3$, so the image is all of $\mathbb{R}^3$ (dimension 3, which is all of the codomain — surjective). And a bijection is invertible. The kicker: in equal dimensions, *any one of the three properties forces the other two*. In unequal dimensions (like $\mathbb{R}^3 \to \mathbb{R}^2$), this breaks — rank-nullity forbids injectivity, so invertibility is impossible.

This theorem (Theorem 4.2) is why $n \times n$ matrices have a clean invertibility story: one simple check determines all three properties.

## Proof roadmaps

Master these three proof structures. They appear again and again throughout linear algebra, so internalizing the proof techniques (not just the theorems) is your real goal.

The three tricks: difference detection, two-installment basis construction, and the rank-nullity seesaw.

**Lemma 4.1 — Injective iff trivial kernel — trick: difference detection.**

The core move: detect collisions via differences. If two inputs produce the same output, their *difference* lands in the kernel. This is why checking one set (the kernel) replaces checking all pairs of inputs. The payoff: you avoid checking infinitely many pairs by checking a single set instead.

*First move:* Suppose $T(u) = T(v)$. By linearity, $T(u-v) = T(u) - T(v) = 0$, so $u - v \in \ker T$. This is the "difference detection" step — collision becomes membership in the kernel. Notice: this *always* works because $T$ is linear, so subtraction preserves the image structure.

*Middle rung:* Now apply this to prove injectivity. ($\Rightarrow$) If $T$ is injective and $v \in \ker T$ (so $T(v) = 0 = T(0)$), then injectivity forces $v = 0$, so $\ker T \subseteq \{0\}$. But $0 \in \ker T$ always, so $\ker T = \{0\}$. ($\Leftarrow$) If $\ker T = \{0\}$ and $T(u) = T(v)$, then by the first move, $u - v \in \ker T = \{0\}$, so $u - v = 0$, hence $u = v$ (injective by the "for all pairs" definition).

*Full sketch:* The kernel is the injectivity meter. Trivial kernel (only zero) means the only way $T$ can collapse two inputs is if they're identical, i.e., injective. Nontrivial kernel (contains some $v \neq 0$) means $v$ and $0$ both map to zero, i.e., two different inputs collide, so not injective. For linear maps, this single criterion replaces checking all pairs — a massive computational shortcut. This is why Lemma 4.1 is the gateway to all of Day 4.

**Theorem 4.1 — Rank-nullity theorem — trick: basis in two installments.**

The key insight: build a basis of the domain by starting with the kernel, then extend; watch what the extended part does under $T$. The clever part: the kernel basis disappears under $T$ (since $T(u_i) = 0$ for kernel elements), leaving only the extension part to span the image.

*First move:* Take a basis $u_1, \ldots, u_k$ of $\ker T$ (possibly empty if $\ker T = \{0\}$). By Day 2's basis extension theorem (Exercise 6), extend this to a basis $u_1, \ldots, u_k, w_1, \ldots, w_r$ of $V$. Now we have $k + r = \dim V$. The two pieces: kernel basis (dimension $k$) and extension (dimension $r$).

*Middle rung:* Claim: $\{T(w_1), \ldots, T(w_r)\}$ is a basis of $\mathrm{im} T$. **Spanning:** Let $w \in \mathrm{im} T$, so $w = T(v)$ for some $v \in V$. Write $v = \sum_{i=1}^k a_i u_i + \sum_{j=1}^{r} b_j w_j$ (using the basis of $V$). Apply $T$: $w = T(v) = \sum_{i=1}^k a_i T(u_i) + \sum_{j=1}^r b_j T(w_j) = \sum_{j=1}^r b_j T(w_j)$ (since each $u_i \in \ker T$ means $T(u_i) = 0$). So the kernel terms vanish, and $w$ is a combination of the $T(w_j)$'s. **Independence:** Suppose $\sum_{j=1}^r c_j T(w_j) = 0$ for scalars $c_j$. By linearity, $T\left(\sum_{j=1}^r c_j w_j\right) = 0$, so $\sum_{j=1}^r c_j w_j \in \ker T$. Since the basis of the kernel is $\{u_1, \ldots, u_k\}$, we can write $\sum_{j=1}^r c_j w_j = \sum_{i=1}^k d_i u_i$ for some $d_i$. Rearranging: $\sum_{i=1}^k d_i u_i - \sum_{j=1}^r c_j w_j = 0$. But $u_1, \ldots, u_k, w_1, \ldots, w_r$ is a basis of $V$, so all coefficients are zero — in particular $c_j = 0$ for all $j$.

*Full sketch:* The dimension of the image equals $r = \dim V - k = \dim V - \dim(\ker T)$, which rearranges to $\dim(\ker T) + \dim(\mathrm{im} T) = \dim V$. The proof works by splitting the basis: kernel part contributes zero images (they map to zero), extension part forms the image basis (they span and are independent). Conservation of dimension follows directly from the counting: the domain splits, so its dimension splits. This is why rank-nullity is not a coincidence — it's a geometric partition encoded in the proof itself.

**Theorem 4.2 — Invertible iff injective iff surjective (equal-dimension case) — trick: rank-nullity seesaw.**

When the domain and codomain have equal dimension, one virtue forces all three. The seesaw: if nullity is zero, rank must be full, which fills the codomain.

*First move:* Assume $\dim V = \dim W = n$. By Lemma 4.1, $T$ is injective $\iff$ $\ker T = \{0\}$ $\iff$ $\dim(\ker T) = 0$. By rank-nullity, $\dim(\ker T) + \dim(\mathrm{im} T) = n$, so $\dim(\ker T) = 0$ $\iff$ $\dim(\mathrm{im} T) = n$.

*Middle rung:* Now $\mathrm{im} T$ is a subspace of $W$ with $\dim(\mathrm{im} T) = n = \dim W$. A subspace of a finite-dimensional space has dimension equal to the whole space iff it is the whole space (a basis of the subspace has $n$ vectors, and any basis of $W$ must also have $n$ vectors, so the subspace's basis is already a basis of $W$, hence $\mathrm{im} T = W$). Thus $\dim(\mathrm{im} T) = n$ $\iff$ $T$ is surjective. Chaining: injective $\iff$ surjective.

*Full sketch:* If $T$ is invertible, then applying the inverse reverses any collision (so $T$ is injective) and reaches any target (so $T$ is surjective). Conversely, if $T$ is both injective and surjective, $T$ is a bijection of sets, so it has a set-theoretic inverse function $S: W \to V$. Checking linearity of $S$ (which follows from $T$'s linearity and the bijection property) shows $S$ is the desired linear inverse. Thus all three are equivalent, and any one of them determines the other two. The upshot: for $n \times n$ matrices (equal dimensions), testing invertibility reduces to computing the kernel or rank — a simple mechanical check.

**Synthesis and memory anchors:**

Day 4 is where linear maps become predictable. Once you know the kernel and image, you can predict invertibility without trying to find an inverse. The three proof tricks (difference detection, two-installment basis, dimension seesaw) are not abstract — they're algorithms for checking these properties with just one or two computations instead of exhaustive checks.

**Key takeaways:**

- **Don't compute both kernel and image separately every time.** Once you know $\dim V$ and $\dim(\ker T)$, you have $\dim(\mathrm{im} T)$ for free by rank-nullity. This is the "conservation law" at work — no extra computation needed.
- **"Invertible" requires *both* dimensions to match.** A $3 \times 2$ matrix cannot be invertible; rank-nullity forbids it. The image has dimension at most 2, but the codomain is 3-dimensional, so something is missed.
- **Kernel is the injectivity meter** (Lemma 4.1). Trivial kernel ⟺ injective. For linear maps, this single criterion replaces checking all pairs of inputs — a computational lifesaver compared to the general definition.
- **Equal dimensions unlock equivalences** (Theorem 4.2). When $\dim V = \dim W$, injective ⟺ surjective ⟺ invertible. This critical equivalence fails in unequal dimensions, where any two of the three can float independently. The seesaw locks them together only when the scales have equal weight.

## Flashcards

Use these to drill the core definitions, theorems, and proof tricks. Master all 10 before moving to Day 5.

**Q:** Define kernel and image.  
**A:** $\ker T = \{v : T(v) = 0\}$; $\mathrm{im}\,T = \{T(v) : v \in V\}$.

**Q:** Rank-nullity in one sentence?  
**A:** $\dim\ker T + \dim\mathrm{im}\,T = \dim V$ — crushed plus kept equals total.

**Q:** Injectivity test via kernel?  
**A:** Injective $\iff$ $\ker T = \{0\}$.

**Q:** Why can't a map $\mathbb{R}^3 \to \mathbb{R}^2$ be invertible?  
**A:** Rank $\le 2$, so nullity $\ge 1$ — something nonzero is crushed; not injective.

**Q:** For a map between equal-dimensional spaces, injective implies…?  
**A:** Surjective (and hence invertible) — rank-nullity seesaw.

**Q:** The proof skeleton of rank-nullity?  
**A:** Basis of kernel, extend to basis of $V$; images of the extension form a basis of the image.

**Q:** What earlier result does the rank-nullity proof silently need?  
**A:** Basis extension (Day 2, Exercise 6).

**Q:** When you have a map $T: \mathbb{R}^5 \to \mathbb{R}^3$ with $\dim(\ker T) = 2$, what is the rank?  
**A:** Rank $= 5 - 2 = 3$ (by rank-nullity). The image is all of $\mathbb{R}^3$.

**Q:** In equal-dimension case, if a linear map is surjective, is it always injective?  
**A:** Yes — rank-nullity forces it. If surjective, then rank $= \dim W$, so nullity $= 0$, so injective.

**Q:** You have a matrix with rank 4. Can it have a left inverse?  
**A:** Depends on the dimensions. If it's $4 \times n$ with $n > 4$, yes (injective map can have left inverse). If it's $m \times 4$ with $m > 4$, no (not surjective, cannot have right inverse in the usual sense).
