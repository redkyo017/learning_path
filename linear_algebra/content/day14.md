# Day 14 — Inner Products, Norms, Cauchy-Schwarz

## Learning objectives

By the end of today you should be able to:
- State the axioms of an inner product and derive the induced norm from it.
- Prove the Cauchy-Schwarz inequality from the positive-definiteness axiom
  alone, and reproduce the discriminant argument from scratch.
- Prove the triangle inequality and the parallelogram law, and explain how
  each depends on (or doesn't depend on) Cauchy-Schwarz.
- Compute inner products, norms, and angles between vectors by hand, and
  check whether a proposed formula is a valid inner product.

## Reference material

- Primer (15 min, geometric intuition): 3Blue1Brown, *Essence of Linear
  Algebra*, Chapter 9 (dot products and duality) —
  [playlist](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
- Primary theory text: Sergei Treil, *Linear Algebra Done Wrong*, §5.1–5.2 —
  [free PDF](https://www.math.brown.edu/streil/papers/LADW/LADW-2014-09.pdf)
- Exercise bank: Schaum's Outline of Linear Algebra (Lipschutz/Lipson), the
  Inner Product Spaces chapter (first part) — if you don't have a copy, the
  exercises below are self-contained and sufficient for today.

The theory below is self-contained — you do not strictly need the Treil PDF
to do today's work, but reading his §5.1–5.2 alongside this is the "theory"
layer of today's three-layer structure.

## Theory

### Definition 14.1 (Inner product, inner product space)

Let $V$ be a vector space over $\mathbb{R}$. An **inner product** on $V$ is a
function $\langle \cdot, \cdot \rangle : V \times V \to \mathbb{R}$
satisfying, for all $u, v, w \in V$ and all $a, b \in \mathbb{R}$:

1. **Symmetry:** $\langle u, v \rangle = \langle v, u \rangle$.
2. **Bilinearity** (linearity in the first argument):
   $\langle au + bw, v \rangle = a\langle u, v \rangle + b\langle w, v
   \rangle$. (Combined with symmetry, this also gives linearity in the
   second argument: $\langle u, av + bw \rangle = a\langle u,v\rangle +
   b\langle u,w\rangle$, so "bilinear" — linear in *both* slots — is the
   right word even though we only impose linearity in one slot directly.)
3. **Positive-definiteness:** $\langle v, v \rangle \ge 0$ for all $v$, with
   equality if and only if $v = 0$.

A vector space equipped with an inner product is called an **inner product
space**. The standard example is $V = \mathbb{R}^n$ with the familiar dot
product $\langle u, v \rangle = u \cdot v = \sum_{i=1}^n u_i v_i$; you should
check for yourself that the dot product satisfies all three axioms — it's a
good five-minute warm-up before reading further, since everything below is
proved for a *general* inner product, not just the dot product. (Exercise 8
asks you to verify the axioms for a genuinely different inner product on
$\mathbb{R}^2$, which is the point: many different valid inner products can
exist on the same vector space.)

### Definition 14.2 (Norm)

Given an inner product space $(V, \langle \cdot,\cdot\rangle)$, the
**norm** (or length) induced by the inner product is
$$\|v\| = \sqrt{\langle v, v \rangle}.$$
This is well-defined (the quantity under the square root is real and
non-negative) precisely because of positive-definiteness (axiom 3 above), and
$\|v\| = 0 \iff v = 0$ for the same reason. For the standard dot product on
$\mathbb{R}^n$, this recovers the familiar Euclidean length
$\|v\| = \sqrt{v_1^2 + \cdots + v_n^2}$.

### Theorem 14.1 (Cauchy-Schwarz inequality)

For all $u, v$ in an inner product space $V$,
$$|\langle u, v \rangle| \le \|u\| \, \|v\|.$$

**Proof.** *Case $v = 0$.* By bilinearity, $\langle u, 0 \rangle = \langle u,
0 \cdot 0 \rangle = 0 \cdot \langle u, 0 \rangle = 0$, so the left side is
$0$. Also $\|v\| = \|0\| = 0$, so the right side is $0$ too. The inequality
$0 \le 0$ holds (with equality), so the case $v = 0$ is done.

*Case $v \neq 0$.* Define a real-valued function of a real variable $t$:
$$f(t) = \|u - tv\|^2 = \langle u - tv,\, u - tv \rangle.$$
By positive-definiteness, $f(t) \ge 0$ for *every* real number $t$, since
$f(t)$ is the norm-squared of the vector $u - tv$.

Expand $f(t)$ using bilinearity and symmetry:
$$f(t) = \langle u,u\rangle - t\langle u,v\rangle - t\langle v,u\rangle + t^2\langle v,v\rangle = \langle u,u\rangle - 2t\langle u,v\rangle + t^2\langle v,v\rangle,$$
where the middle two terms combined using symmetry ($\langle u,v\rangle =
\langle v,u\rangle$). Writing this in terms of norms,
$$f(t) = \|v\|^2 t^2 - 2\langle u,v\rangle\, t + \|u\|^2.$$

This is a quadratic polynomial in $t$ with leading coefficient $\|v\|^2$,
which is strictly positive since $v \neq 0$ (positive-definiteness again).
Write it as $f(t) = At^2 + Bt + C$ with $A = \|v\|^2 > 0$, $B =
-2\langle u,v\rangle$, $C = \|u\|^2$.

We now show: *a quadratic $At^2+Bt+C$ with $A>0$ that is $\ge 0$ for all
real $t$ must have discriminant $B^2 - 4AC \le 0$.* Complete the square:
$$At^2+Bt+C = A\left(t + \frac{B}{2A}\right)^2 + \left(C - \frac{B^2}{4A}\right).$$
The first term is $\ge 0$ for every $t$ and equals exactly $0$ when $t =
-B/(2A)$; at that specific $t$, the whole expression equals $C -
B^2/(4A)$, which is therefore the *minimum* value of $f$ over all real $t$.
Since we are given $f(t) \ge 0$ for all $t$, in particular the minimum value
must be $\ge 0$:
$$C - \frac{B^2}{4A} \ge 0 \implies 4AC - B^2 \ge 0 \implies B^2 - 4AC \le 0,$$
using $A > 0$ to multiply through without flipping the inequality.

Substituting back $A = \|v\|^2$, $B = -2\langle u,v\rangle$, $C = \|u\|^2$:
$$B^2 - 4AC = 4\langle u,v\rangle^2 - 4\|v\|^2\|u\|^2 \le 0.$$
Divide by $4$ and rearrange:
$$\langle u,v\rangle^2 \le \|u\|^2\|v\|^2.$$
Taking square roots of both (non-negative) sides preserves the inequality:
$$|\langle u,v\rangle| \le \|u\|\,\|v\|. \qquad \blacksquare$$

### Theorem 14.2 (Triangle inequality)

For all $u, v$ in an inner product space $V$,
$$\|u+v\| \le \|u\| + \|v\|.$$

**Proof.** Expand $\|u+v\|^2$ using bilinearity and symmetry, exactly as in
the proof of Theorem 14.1:
$$\|u+v\|^2 = \langle u+v, u+v\rangle = \langle u,u\rangle + 2\langle u,v\rangle + \langle v,v\rangle = \|u\|^2 + 2\langle u,v\rangle + \|v\|^2.$$

Now bound the cross term. Since any real number is at most its absolute
value, $\langle u,v\rangle \le |\langle u,v\rangle|$, and by Theorem 14.1
(Cauchy-Schwarz), $|\langle u,v\rangle| \le \|u\|\|v\|$. Chaining these,
$$\langle u,v \rangle \le \|u\| \, \|v\|.$$

Substituting this bound into the expansion above:
$$\|u+v\|^2 \le \|u\|^2 + 2\|u\|\|v\| + \|v\|^2 = (\|u\| + \|v\|)^2,$$
where the right side is recognized as a perfect square, $(\|u\|+\|v\|)^2 =
\|u\|^2 + 2\|u\|\|v\| + \|v\|^2$.

Both $\|u+v\|$ and $\|u\|+\|v\|$ are non-negative real numbers (norms are
always $\ge 0$, and a sum of non-negative numbers is non-negative), and we
have shown $\|u+v\|^2 \le (\|u\|+\|v\|)^2$. For non-negative reals $x, y$,
$x^2 \le y^2 \implies x \le y$ (the function $x \mapsto x^2$ is
strictly increasing on $[0,\infty)$, so its inverse, the square root, is
also increasing, and applying it to both sides of $x^2 \le y^2$ preserves
the inequality). Applying this with $x = \|u+v\|$, $y = \|u\|+\|v\|$:
$$\|u+v\| \le \|u\| + \|v\|. \qquad \blacksquare$$

### Theorem 14.3 (Parallelogram law)

For all $u, v$ in an inner product space $V$,
$$\|u+v\|^2 + \|u-v\|^2 = 2\|u\|^2 + 2\|v\|^2.$$

**Proof.** Expand each term on the left using bilinearity and symmetry.
$$\|u+v\|^2 = \langle u+v, u+v \rangle = \langle u,u\rangle + 2\langle u,v\rangle + \langle v,v\rangle = \|u\|^2 + 2\langle u,v\rangle + \|v\|^2,$$
$$\|u-v\|^2 = \langle u-v, u-v \rangle = \langle u,u\rangle - 2\langle u,v\rangle + \langle v,v\rangle = \|u\|^2 - 2\langle u,v\rangle + \|v\|^2.$$
Adding these two equations, the cross terms $+2\langle u,v\rangle$ and
$-2\langle u,v\rangle$ cancel exactly:
$$\|u+v\|^2 + \|u-v\|^2 = 2\|u\|^2 + 2\|v\|^2. \qquad \blacksquare$$

Notice this proof used *only* bilinearity and symmetry — no
positive-definiteness, no inequality, no discriminant argument. Unlike
Theorems 14.1 and 14.2, the parallelogram law is an **identity** (always
exact equality), not an inequality, and it holds for every pair of vectors
with no case split needed. Exercise 10 uses this to show that not every norm
comes from an inner product: any norm that *fails* the parallelogram law for
some pair of vectors cannot possibly be $\sqrt{\langle \cdot,\cdot\rangle}$
for any inner product, since Theorem 14.3 says every inner-product norm must
satisfy it.

## Worked example

**Claim:** For $u = (3,4)$ and $v = (1,2)$ in $\mathbb{R}^2$ with the
standard dot product, Cauchy-Schwarz, the triangle inequality, and the
parallelogram law all check out numerically.

**Setup.** $\langle u,v\rangle = u \cdot v = (3)(1) + (4)(2) = 3 + 8 = 11$.
$\|u\| = \sqrt{3^2+4^2} = \sqrt{25} = 5$. $\|v\| = \sqrt{1^2+2^2} =
\sqrt{5} \approx 2.236$.

**Cauchy-Schwarz.** $|\langle u,v\rangle| = 11$. $\|u\|\|v\| = 5\sqrt5
\approx 11.180$. Indeed $11 \le 11.180$ ✓. (Not equality, as expected: $u =
(3,4)$ and $v=(1,2)$ are not scalar multiples of each other — $3/1 = 3 \neq
2 = 4/2$... wait, check carefully: $u$ is a multiple of $v$ iff $(3,4) =
c(1,2)$ for some $c$, i.e. $c=3$ from the first coordinate but $c=2$ from the
second — inconsistent, so $u,v$ are linearly independent, consistent with
strict inequality by Exercise 5's equality condition.)

**Triangle inequality.** $u + v = (4,6)$, so $\|u+v\| = \sqrt{4^2+6^2} =
\sqrt{52} \approx 7.211$. Meanwhile $\|u\| + \|v\| = 5 + \sqrt5 \approx
7.236$. Indeed $7.211 \le 7.236$ ✓.

**Parallelogram law.** $u+v = (4,6)$ gives $\|u+v\|^2 = 16+36 = 52$. $u - v =
(2,2)$ gives $\|u-v\|^2 = 4+4 = 8$. Left side: $52 + 8 = 60$. Right side:
$2\|u\|^2 + 2\|v\|^2 = 2(25) + 2(5) = 50 + 10 = 60$. Both sides equal $60$
exactly ✓ — as they must, since the parallelogram law is an identity, not
merely an inequality.

## Unconventional edge

It's tempting to file Cauchy-Schwarz away as "just an inequality to
memorize" — a fact you plug into other proofs (like Theorem 14.2 above) and
otherwise forget. That misses why it matters: the angle formula $\cos\theta
= \langle u,v\rangle / (\|u\|\|v\|)$ is only *well-defined* — meaning
$\arccos$ can actually be applied to it — because Cauchy-Schwarz guarantees
the ratio always lies in $[-1,1]$, the domain of $\arccos$. Without that
guarantee, nothing would stop the ratio from landing at, say, $1.3$, at
which point "the angle between $u$ and $v$" would be meaningless. This is
precisely what lets "angle between two things" generalize far beyond the
$\mathbb{R}^2$/$\mathbb{R}^3$ pictures where you can literally draw the
angle with a protractor: any inner product space — including spaces of
functions, with inner products defined by integrals — inherits a
well-defined notion of angle for free, purely from satisfying the three
axioms of Definition 14.1. This is exactly the machinery behind *cosine
similarity* in machine learning (comparing two high-dimensional vectors, or
even two documents represented as vectors, by "the angle between them" makes
sense precisely because Cauchy-Schwarz never lets the cosine escape
$[-1,1]$, no matter the dimension).

## Exercises

Attempt every problem closed-book before checking the Solutions section
below. Problems 1–4, 6, 7, 9, 10 are computational/verification; 5 and 8 are
proof-based.

1. For $u = (1,0)$ and $v = (0,1)$ in $\mathbb{R}^2$ (standard dot product),
   verify Cauchy-Schwarz, the triangle inequality, and the parallelogram law
   by computing both sides of each numerically.
2. Do the same for $u = (2,-1)$ and $v = (-1,2)$ in $\mathbb{R}^2$.
3. Do the same for $u = (1,2,2)$ and $v = (2,1,-2)$ in $\mathbb{R}^3$.
4. Do the same (Cauchy-Schwarz and the parallelogram law only) for
   $u = (1,1,0,0)$ and $v = (0,0,1,1)$ in $\mathbb{R}^4$.
5. Prove: equality holds in Cauchy-Schwarz, $|\langle u,v\rangle| =
   \|u\|\|v\|$, if and only if $u$ and $v$ are linearly dependent. (Hint:
   revisit the discriminant argument in the proof of Theorem 14.1 — equality
   in Cauchy-Schwarz corresponds to discriminant *exactly* zero, i.e. the
   quadratic $f(t) = \|u-tv\|^2$ has a real double root.)
6. Compute the angle $\theta$ (in degrees) between $u = (1,0)$ and
   $v = (1,1)$ using $\cos\theta = \langle u,v\rangle/(\|u\|\|v\|)$.
7. Compute the angle $\theta$ (in degrees, to two decimal places) between
   $u = (3,4)$ and $v = (4,3)$.
8. Define $\langle x, y \rangle_w = 2x_1y_1 + 3x_2y_2$ for $x = (x_1,x_2),
   y = (y_1,y_2) \in \mathbb{R}^2$ (a "weighted" dot product). Prove that
   $\langle \cdot,\cdot\rangle_w$ satisfies all three inner product axioms
   from Definition 14.1.
9. Using the weighted inner product from Exercise 8, compute
   $\|(1,1)\|_w$ (compare it to the standard Euclidean norm of $(1,1)$), and
   verify Cauchy-Schwarz for $u=(1,1)$, $v=(1,-1)$ under $\langle
   \cdot,\cdot\rangle_w$.
10. **Trap.** Consider the $\ell_1$ norm on $\mathbb{R}^2$, $\|x\|_1 =
    |x_1| + |x_2|$ (this is a perfectly legitimate norm, just not one we've
    built from an inner product). Show that $u = (1,0)$, $v=(0,1)$ *violate*
    the parallelogram law under $\|\cdot\|_1$. What does this tell you about
    whether $\|\cdot\|_1$ can be written as $\sqrt{\langle x,x\rangle}$ for
    some inner product on $\mathbb{R}^2$?

## Solutions

**1.** $\langle u,v\rangle = (1)(0)+(0)(1) = 0$. $\|u\|=1$, $\|v\|=1$.
*Cauchy-Schwarz:* $|0| \le (1)(1) = 1$ ✓ (strict, since $u,v$ independent).
*Triangle:* $u+v=(1,1)$, $\|u+v\| = \sqrt2 \approx 1.414 \le \|u\|+\|v\| =
2$ ✓. *Parallelogram:* $\|u+v\|^2 = 2$; $u-v=(1,-1)$, $\|u-v\|^2=2$; sum $=
4$. Right side: $2(1)^2+2(1)^2 = 4$. Equal ✓.

**2.** $\langle u,v\rangle = (2)(-1)+(-1)(2) = -4$. $\|u\| = \sqrt{4+1} =
\sqrt5$, $\|v\| = \sqrt{1+4}=\sqrt5$. *Cauchy-Schwarz:* $|{-4}| = 4 \le
(\sqrt5)(\sqrt5) = 5$ ✓. *Triangle:* $u+v = (1,1)$, $\|u+v\| = \sqrt2 \approx
1.414 \le \|u\|+\|v\| = 2\sqrt5 \approx 4.472$ ✓ (loose, as expected since
$u,v$ point in nearly opposite directions). *Parallelogram:* $\|u+v\|^2=2$;
$u-v=(3,-3)$, $\|u-v\|^2 = 9+9=18$; sum $=20$. Right side: $2(5)+2(5)=20$.
Equal ✓.

**3.** $\langle u,v\rangle = (1)(2)+(2)(1)+(2)(-2) = 2+2-4=0$. $\|u\| =
\sqrt{1+4+4} = 3$, $\|v\| = \sqrt{4+1+4}=3$. *Cauchy-Schwarz:* $|0| \le
(3)(3)=9$ ✓ (very loose — $u,v$ are orthogonal, the opposite extreme from
equality). *Triangle:* $u+v = (3,3,0)$, $\|u+v\| = \sqrt{18} = 3\sqrt2
\approx 4.243 \le \|u\|+\|v\| = 6$ ✓. *Parallelogram:* $\|u+v\|^2=18$;
$u-v=(-1,1,4)$, $\|u-v\|^2 = 1+1+16=18$; sum $=36$. Right side:
$2(9)+2(9)=36$. Equal ✓.

**4.** $\langle u,v\rangle = (1)(0)+(1)(0)+(0)(1)+(0)(1) = 0$. $\|u\| =
\sqrt2$, $\|v\|=\sqrt2$. *Cauchy-Schwarz:* $|0| \le (\sqrt2)(\sqrt2) = 2$ ✓.
*Parallelogram:* $u+v = (1,1,1,1)$, $\|u+v\|^2 = 4$; $u-v = (1,1,-1,-1)$,
$\|u-v\|^2=4$; sum $=8$. Right side: $2(2)+2(2)=8$. Equal ✓.

**5.** ($\Leftarrow$) Suppose $u,v$ are linearly dependent. If $v=0$, then
(as shown in the proof of Theorem 14.1) both sides of Cauchy-Schwarz are
$0$, so equality holds trivially, and $\{u,0\}$ is always a dependent set
($1\cdot 0 = 0$ is a nontrivial relation with a zero coefficient on $u$ —
more precisely, $0\cdot u + 1 \cdot 0 = 0$ is a nontrivial dependence
relation). If $v \neq 0$ and $u,v$ dependent, then $u = cv$ for some scalar
$c$ (this is what dependence of a pair with $v\ne0$ means). Then
$\langle u,v\rangle = \langle cv,v\rangle = c\langle v,v\rangle = c\|v\|^2$,
so $|\langle u,v\rangle| = |c|\,\|v\|^2$. Also $\|u\| = \|cv\| =
\sqrt{\langle cv,cv\rangle} = \sqrt{c^2\langle v,v\rangle} = |c|\,\|v\|$, so
$\|u\|\|v\| = |c|\,\|v\|^2$ as well. Hence $|\langle u,v\rangle| =
\|u\|\|v\|$: equality holds.

($\Rightarrow$) Suppose equality holds: $|\langle u,v\rangle| = \|u\|\|v\|$.
If $v = 0$, then $\{u,v\}$ is dependent as noted above, and we're done. If
$v \neq 0$, revisit the proof of Theorem 14.1: $f(t) = \|u-tv\|^2 = At^2+Bt+C
\ge 0$ for all $t$, with $A=\|v\|^2>0$, $B=-2\langle u,v\rangle$,
$C=\|u\|^2$, and we showed $B^2-4AC \le 0$ is equivalent to Cauchy-Schwarz.
Equality $|\langle u,v\rangle| = \|u\|\|v\|$ is exactly the case
$B^2 - 4AC = 0$ (tracing back through the same algebra: $B^2-4AC =
4\langle u,v\rangle^2 - 4\|u\|^2\|v\|^2$, which is $0$ exactly when
$\langle u,v\rangle^2 = \|u\|^2\|v\|^2$, i.e. $|\langle u,v\rangle| =
\|u\|\|v\|$). A quadratic with $A>0$ and discriminant exactly $0$ has a
*real double root* $t_0 = -B/(2A)$, and at that root the completed-square
form shows $f(t_0) = 0$ exactly (the minimum value $C - B^2/(4A)$ equals $0$
when $B^2=4AC$). So $\|u - t_0v\|^2 = 0$, and by positive-definiteness
(Definition 14.1, axiom 3), $u - t_0 v = 0$, i.e. $u = t_0 v$. This exhibits
$u$ as a scalar multiple of $v$, so $u,v$ are linearly dependent.

Both directions hold, so equality in Cauchy-Schwarz holds if and only if
$u,v$ are linearly dependent.

**6.** $\langle u,v\rangle = (1)(1)+(0)(1) = 1$. $\|u\| = 1$, $\|v\| =
\sqrt2$. $\cos\theta = 1/\sqrt2 \approx 0.7071$. $\theta = \arccos(1/\sqrt2)
= 45°$.

**7.** $\langle u,v\rangle = (3)(4)+(4)(3) = 24$. $\|u\|=5$, $\|v\|=5$.
$\cos\theta = 24/25 = 0.96$. $\theta = \arccos(0.96) \approx 16.26°$.

**8.** *Symmetry:* $\langle x,y\rangle_w = 2x_1y_1+3x_2y_2 = 2y_1x_1+3y_2x_2
= \langle y,x\rangle_w$, using commutativity of real multiplication.
*Bilinearity (linearity in the first argument):* for $x,z \in \mathbb{R}^2$
and $a,b \in \mathbb{R}$,
$$\langle ax+bz, y\rangle_w = 2(ax_1+bz_1)y_1 + 3(ax_2+bz_2)y_2 = a(2x_1y_1+3x_2y_2) + b(2z_1y_1+3z_2y_2) = a\langle x,y\rangle_w + b\langle z,y\rangle_w,$$
just distributing and regrouping. (Linearity in the second argument then
follows from this plus symmetry, as noted in Definition 14.1.)
*Positive-definiteness:* $\langle x,x\rangle_w = 2x_1^2+3x_2^2$. Each term is
a non-negative coefficient times a square, so the sum is $\ge 0$ always.
Equality $2x_1^2+3x_2^2=0$ forces $x_1^2=0$ and $x_2^2=0$ (since both
coefficients $2,3$ are strictly positive, neither term can be negative, so
both must individually be $0$ for the sum to be $0$), i.e. $x_1=x_2=0$, i.e.
$x=0$. All three axioms hold, so $\langle\cdot,\cdot\rangle_w$ is a valid
inner product on $\mathbb{R}^2$.

**9.** $\|(1,1)\|_w = \sqrt{2(1)^2+3(1)^2} = \sqrt{5} \approx 2.236$, versus
the standard Euclidean norm $\sqrt{1^2+1^2} = \sqrt2 \approx 1.414$ — a
different inner product genuinely changes lengths, not just angles.
For $u=(1,1)$, $v=(1,-1)$: $\langle u,v\rangle_w = 2(1)(1)+3(1)(-1) = 2-3 =
-1$, so $|\langle u,v\rangle_w| = 1$. $\|u\|_w = \sqrt{2+3}=\sqrt5$;
$\|v\|_w = \sqrt{2(1)^2+3(-1)^2} = \sqrt{2+3}=\sqrt5$. Cauchy-Schwarz:
$1 \le (\sqrt5)(\sqrt5) = 5$ ✓.

**10.** $\|u\|_1 = |1|+|0| = 1$, $\|v\|_1=|0|+|1|=1$. $u+v=(1,1)$:
$\|u+v\|_1 = 1+1=2$, so $\|u+v\|_1^2 = 4$. $u-v=(1,-1)$: $\|u-v\|_1 =
1+1=2$, so $\|u-v\|_1^2=4$. Left side of the parallelogram law: $4+4=8$.
Right side: $2\|u\|_1^2 + 2\|v\|_1^2 = 2(1)+2(1) = 4$. Since $8 \neq 4$, the
parallelogram law fails for $\|\cdot\|_1$. By Theorem 14.3, *every* norm
induced by an inner product must satisfy the parallelogram law for *all*
vectors — so a norm that fails it even for one pair of vectors cannot be
$\sqrt{\langle x,x\rangle}$ for any inner product whatsoever. Hence the
$\ell_1$ norm is a perfectly good norm, but it is not, and cannot be, induced
by any inner product on $\mathbb{R}^2$.

## Code lab

**Rule:** don't open this section until you've finished the exercises above
on paper.

Today's lab automates the two numeric checks you just did by hand
repeatedly in the Exercises: verifying Cauchy-Schwarz and the parallelogram
law. Open `starter_code/day14_inner_products.py` — it has two functions to
complete, `cauchy_schwarz_holds` and `parallelogram_law_holds`.

**Hint:** `np.dot(u, v)` gives $\langle u,v\rangle$ and `np.linalg.norm(v)`
gives $\|v\|$ for the standard dot product on $\mathbb{R}^n$ — both
functions reduce to a couple of lines built from those two primitives, plus
a floating-point tolerance (exact equality rarely survives floating-point
arithmetic, so use `<=` with a small epsilon, or `np.isclose`, rather than
`==`).

Fill in the `TODO`s, then run the file directly
(`python3 starter_code/day14_inner_products.py`); it should print
`All checks passed across 5 random trials!`.

If you get stuck for more than ~10 minutes, check
`solutions/day14_inner_products.py` — but only after a real attempt.

Once your implementation passes, extend it: write a small
`angle_between(u, v)` function that computes $\arccos(\langle u,v\rangle /
(\|u\|\|v\|))$ in degrees, using `np.clip(x, -1.0, 1.0)` on the ratio before
calling `np.arccos` (a direct nod to the Unconventional edge above — even
though Cauchy-Schwarz *guarantees* the ratio lies in $[-1,1]$
mathematically, floating-point rounding can push it a hair outside that
range in practice, e.g. $1.0000000002$, which would otherwise make
`np.arccos` return `nan`). Test it on the vector pairs from Exercises 6 and
7 and confirm your hand-computed angles match.

## Journal template

```
## Day 14 — Inner products, norms, Cauchy-Schwarz
Key theorem in my own words: ...
What confused me: ...
```
