# Day 14 Primer — Inner products, norms, Cauchy-Schwarz

## Warm-up

Before reading anything new, answer the flashcards at the end of `primers/day12.md`, `primers/day11.md`, and `primers/day06.md` for: Days 12, 11, 6 (~10 min).
Say each answer out loud or on paper *before* flipping.
These fast retrievals—remembering what diagonalization means, what the four fundamental subspaces are, what Gaussian elimination does—will make today's new material land in the right mental neighborhoods.
Inner products are the next layer; they build on everything you've learned about structure and independence to add geometry and angles.
You've seen how linear maps transform spaces (Day 3), how dimensions split (Day 4), and how matrices hide eigenvalues and eigenvectors (Days 10–11).
Today you'll learn the language to measure *how close* two vectors are, what *angle* means in any dimension, and why projection (which dominates Days 15–16) works the way it does.

## The hook

Two users rate three movies on a 1–5 scale: User A gives $(5,3,1)$ and User B gives $(4,4,2)$.
How similar are their tastes, as a single number?
One intuition: mix their ratings and see what emerges.
Compute the dot product: $\langle u,v \rangle = 5 \cdot 4 + 3 \cdot 4 + 1 \cdot 2 = 20 + 12 + 2 = 34$.
That's large—but large relative to what?
Normalize by their individual magnitudes.
User A's ratings have length $\|u\| = \sqrt{25+9+1} = \sqrt{35} \approx 5.9$.
User B's have length $\|v\| = \sqrt{16+16+4} = 6$.
The ratio $34 / (6 \times 5.9) \approx 0.96$ captures taste similarity on a scale where 1 is "identical" and 0 is "unrelated."
That ratio is $\cos\theta$ for some angle $\theta$—but here's the hidden assumption that makes this ratio meaningful: *the cosine is always between −1 and 1*.
Numerically, maybe.
Algebraically, *nobody promised it*.
The Cauchy-Schwarz inequality is today's main theorem; it's not a background triviality but the machinery that makes "similarity," "angle," and "projection" mean something concrete in dimensions beyond two or three, and in spaces of functions where you can't draw an arrow with a pencil.
Without Cauchy-Schwarz, the angle formula would be a meaningless fragment.

## The pictures

**Picture 1: Dot product as projection and shadow.**
Draw two arrows from the origin, $u$ and $v$, with angle $\theta$ between them.
Drop a perpendicular from the tip of $v$ onto the line containing $u$.
The shadow—the signed length from the origin to where the perpendicular lands—is $\|v\|\cos\theta$.
Multiply by $\|u\|$ to get a scaled area: $\|u\|\,\|v\|\cos\theta$.
The dot product is exactly this product: $\langle u,v \rangle = \|u\|\,\|v\|\cos\theta$.
The shadow is an orthogonal projection, a concept that will dominate the next two days.
Notice: if $\theta$ is obtuse, $\cos\theta < 0$, so the dot product is negative.
If they're perpendicular, $\cos\theta = 0$, so the dot product vanishes—orthogonal vectors are "unrelated" in the shadow sense.

**Picture 2: Cauchy-Schwarz as "the shadow never exceeds the arrow."**
The magnitude of the shadow is at most the full length of $v$ (it can't stick out beyond the arrow itself).
Translate to algebra: $|\langle u,v \rangle| \le \|u\| \|v\|$.
The shadow's signed length $\|v\|\cos\theta$ satisfies $|\|v\|\cos\theta| \le \|v\|$ because $|\cos\theta| \le 1$ always.
Multiply both sides by $\|u\|$: shadow is bounded.
Equality happens precisely when $\cos\theta = \pm 1$, i.e., when $u$ and $v$ are parallel or anti-parallel.

**Picture 3: Triangle inequality—detours never save distance.**
Draw three points: origin $O$, point $P$ where $\overrightarrow{OP} = u$, and point $Q$ where $\overrightarrow{PQ} = v$.
The path $O \to P \to Q$ has length $\|u\| + \|v\|$.
The direct path $O \to Q$ is the vector $u+v$ and has length $\|u+v\|$.
Euclidean geometry says the direct path is shortest (or tied): $\|u+v\| \le \|u\| + \|v\|$.
Equality holds precisely when the three points are collinear and $P$ sits between $O$ and $Q$, meaning $u$ and $v$ point in the same direction.

**Picture 4: The parallelogram law as the fingerprint of inner products.**
Sketch a parallelogram with adjacent sides $u$ and $v$.
Its two diagonals are $u+v$ (from one corner to the opposite) and $u-v$ (from another corner to its opposite).
The law states: the sum of the squares of the diagonal lengths equals the sum of the squares of all four side lengths: $\|u+v\|^2 + \|u-v\|^2 = 2\|u\|^2 + 2\|v\|^2$.
This identity is universal for inner-product-induced norms.
Any norm that violates it—like the taxicab norm $\|x\|_1 = |x_1| + |x_2|$ or the max norm—cannot possibly come from an inner product, no matter what pairing you try to construct.
This makes the parallelogram law a litmus test for whether a given norm is secretly induced by some hidden inner product.

## Concrete-first walkthrough

**Definition 14.1: The three axioms of an inner product.**
An inner product is a machine that eats two vectors and outputs a real number, written $\langle u,v \rangle$.
To deserve the name "inner product," it must satisfy three axioms.
*Symmetry*: swapping the arguments changes nothing, $\langle u,v \rangle = \langle v,u \rangle$.
*Bilinearity*: the pairing is linear in each slot separately.
If you write $u$ as a combination $au_1 + bu_2$, the pairing distributes: $\langle au_1 + bu_2, v \rangle = a\langle u_1,v \rangle + b\langle u_2,v \rangle$ (and the same linearity holds for the second slot, which follows from symmetry and first-slot linearity).
*Positive-definiteness*: $\langle v,v \rangle \ge 0$ always, and $\langle v,v \rangle = 0$ exactly when $v = 0$.
The standard dot product $u \cdot v = u_1 v_1 + \cdots + u_n v_n$ is the canonical example; today's axioms describe every valid such pairing, including weighted dot products like $2x_1 y_1 + 3x_2 y_2$ on $\mathbb{R}^2$, and inner products defined by integrals on function spaces.
Verifying the axioms for a weighted dot product is an excellent warm-up exercise; do it once on paper (it's mostly checking arithmetic).

**Definition 14.2: Norms from inner products.**
Once you have an inner product, you extract length: $\|v\| = \sqrt{\langle v,v \rangle}$.
This is well-defined (the square root of a real number is real) and always non-negative precisely because of positive-definiteness.
For the standard dot product on $\mathbb{R}^n$, this recovers the familiar Euclidean length $\|v\| = \sqrt{v_1^2 + \cdots + v_n^2}$.
The norm is also called the *length* or *magnitude* induced by the inner product.
A weighted inner product $\langle x,y \rangle_w = 2x_1 y_1 + 3x_2 y_2$ on $\mathbb{R}^2$ induces the norm $\|x\|_w = \sqrt{2x_1^2 + 3x_2^2}$, which is different from the Euclidean norm but equally valid.
The induced norm always satisfies $\|v\| = 0 \iff v = 0$, a property not every norm has (though most common ones do).

**Theorem 14.1: Cauchy-Schwarz inequality.**
The statement is $|\langle u,v \rangle| \le \|u\| \|v\|$.
Equality holds precisely when $u$ and $v$ are linearly dependent—one is a scalar multiple of the other (including the case where one is zero).
This inequality is why the formula $\cos\theta = \langle u,v \rangle / (\|u\| \|v\|)$ for the angle between vectors is universally valid in *any* inner product space.
The ratio on the right is always in $[-1,1]$, so $\arccos$ is a legal operation, even in infinite-dimensional spaces of functions where you cannot visualize an angle with a compass.
This is one of the most-used inequalities in mathematics: linear algebra, functional analysis, statistics, machine learning, and signal processing all lean on it constantly.

**Theorem 14.2: Triangle inequality.**
For any two vectors $u$ and $v$ in an inner product space, $\|u+v\| \le \|u\| + \|v\|$.
This says that a detour is never shorter than the direct route.
Equality holds precisely when the vectors point in the same direction—that is, $u = cv$ or $v = cu$ for some $c \ge 0$.
The triangle inequality is a signature property of any norm worth the name; indeed, it's one of the defining axioms of a norm in abstract spaces.

**Theorem 14.3: Parallelogram law.**
For any $u,v$, the identity $\|u+v\|^2 + \|u-v\|^2 = 2\|u\|^2 + 2\|v\|^2$ holds.
Remarkably, this proof uses *only* bilinearity and symmetry—no positive-definiteness, no inequalities.
This is the payoff: since it is an exact identity that every inner-product norm obeys universally, a norm that *fails* the law (like the $\ell^1$ or taxicab norm $\|x\|_1 = |x_1| + |x_2|$) cannot be the induced norm of any inner product whatsoever.
This makes the parallelogram law a detective: if you hand someone a norm and ask "could this come from an inner product?", testing the parallelogram law is the first thing to try.

## Proof roadmaps

**Theorem 14.1 (Cauchy-Schwarz inequality)—the discriminant trick.**
This proof pattern appears in hundreds of pure and applied mathematics texts.
Learn it once, and you own it forever; do not expect to re-invent it fresh each time.

(1) *First move: build a quadratic that stays non-negative.*
Define a function of a real variable $t$: $q(t) = \|u + tv\|^2$.
Since norm-squared is always $\ge 0$, we have $q(t) \ge 0$ for *every* real $t$.
This is the key insight: the quadratic never goes negative.
Most proofs of Cauchy-Schwarz start here, but many students skip over why this is powerful—pause and convince yourself that $q(t) \ge 0$ everywhere is the real idea.

(2) *Expand the quadratic using bilinearity and symmetry.*
We have $q(t) = \langle u+tv, u+tv \rangle$.
Distribute: $\langle u,u \rangle + 2t\langle u,v \rangle + t^2\langle v,v \rangle = \|u\|^2 + 2t\langle u,v \rangle + t^2\|v\|^2$.
This is a standard quadratic $At^2 + Bt + C$ with $A = \|v\|^2$, $B = 2\langle u,v \rangle$, $C = \|u\|^2$.
(Handle the case $v = 0$ separately: both sides of the claimed inequality are 0 so the claim is trivial.)

(3) *Use the discriminant of a non-negative quadratic.*
If a quadratic $At^2 + Bt + C$ with $A > 0$ is $\ge 0$ for all real $t$, its discriminant must satisfy $B^2 - 4AC \le 0$.
This is because a parabola opening upward ($A > 0$) that never touches the $x$-axis must have no real roots, and the discriminant being non-positive is that condition.
Here, $B^2 - 4AC = 4\langle u,v \rangle^2 - 4\|u\|^2\|v\|^2 \le 0$.
Divide by 4 and take square roots of both sides: $|\langle u,v \rangle| \le \|u\| \|v\|$.
Equality holds iff the discriminant is exactly zero, meaning $q(t)$ has a real double root $t_0$ where $u + t_0 v = 0$, so $u$ and $v$ are scalar multiples.

**Theorem 14.2 (Triangle inequality).**
Expand the left side: $\|u+v\|^2 = \langle u+v, u+v \rangle = \|u\|^2 + 2\langle u,v \rangle + \|v\|^2$.
The cross term $\langle u,v \rangle$ satisfies $\langle u,v \rangle \le |\langle u,v \rangle| \le \|u\| \|v\|$ (applying Cauchy-Schwarz from Theorem 14.1).
Therefore, $\|u+v\|^2 \le \|u\|^2 + 2\|u\| \|v\| + \|v\|^2 = (\|u\| + \|v\|)^2$.
Both sides are non-negative, so taking square roots preserves the inequality.
The equality case follows similarly: equality in Cauchy-Schwarz happens iff the vectors are parallel, which is exactly when the three points are collinear.

**Theorem 14.3 (Parallelogram law).**
Expand each diagonal's norm-squared separately: $\|u+v\|^2 = \|u\|^2 + 2\langle u,v \rangle + \|v\|^2$ and $\|u-v\|^2 = \|u\|^2 - 2\langle u,v \rangle + \|v\|^2$.
Add them together: the cross terms $+2\langle u,v \rangle$ and $-2\langle u,v \rangle$ cancel identically, leaving $2\|u\|^2 + 2\|v\|^2$.
No subtlety, no deep idea—just expansion and cancellation.
This elegant proof shows why the parallelogram law is so special: it follows from linearity alone, not from any inequality.

## Flashcards

### Flashcards

**Q:** State the three inner-product axioms.

**A:** Symmetry: $\langle u,v \rangle = \langle v,u \rangle$. Bilinearity: linear in each argument. Positive-definiteness: $\langle v,v \rangle \ge 0$, with equality iff $v = 0$.

**Q:** State the Cauchy-Schwarz inequality and its equality condition.

**A:** $|\langle u,v \rangle| \le \|u\| \|v\|$. Equality holds iff $u$ and $v$ are linearly dependent (scalar multiples).

**Q:** Compress the Cauchy-Schwarz proof to its essential step.

**A:** The quadratic $q(t) = \|u + tv\|^2$ is $\ge 0$ for all real $t$; a non-negative parabola has discriminant $\le 0$; that inequality is Cauchy-Schwarz after algebra.

**Q:** Why is Cauchy-Schwarz necessary for defining angles?

**A:** It guarantees $\langle u,v \rangle / (\|u\| \|v\|) \in [-1,1]$, so $\arccos$ of that ratio is always a valid angle. Without it, the ratio might be 1.3, and $\arccos(1.3)$ is undefined.

**Q:** Sketch the proof of the triangle inequality.

**A:** Expand $\|u+v\|^2$, apply Cauchy-Schwarz to bound the cross term, then recognize the right side as a perfect square $(\|u\|+\|v\|)^2$.

**Q:** What is the parallelogram law and why is it important?

**A:** $\|u+v\|^2 + \|u-v\|^2 = 2\|u\|^2 + 2\|v\|^2$. Every inner-product-induced norm satisfies it; norms that violate it (like $\|\cdot\|_1$) cannot come from any inner product.

**Q:** Define the norm induced by an inner product.

**A:** $\|v\| = \sqrt{\langle v,v \rangle}$. Well-defined by positive-definiteness: the argument is always $\ge 0$, and the square root is real.
