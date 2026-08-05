# Day 11 primer — Grover's algorithm & amplitude amplification

## Warm-up

Three prior sessions prepare you for today. From Day 4 you learned
that a Hermitian operator with eigenvalues $\pm1$ is a reflection in
its eigenspaces, and that in a real 2D subspace a reflection has a
concrete $2\times2$ matrix you can write down and multiply. That
matrix algebra is exactly what you will use to verify that $O_f$ and
$D$ are reflections and that their product is a rotation. Day 6
established the Born rule: measuring a quantum state returns outcome
$x$ with probability equal to the squared amplitude on $|x\rangle$.
For Grover's algorithm the entire figure of merit is the amplitude on
the marked basis state just before measurement, so maximizing that
single amplitude is the whole problem. Day 8 introduced the
phase-kickback identity $U_f|x\rangle|-\rangle=(-1)^{f(x)}|x\rangle
|-\rangle$, showing how a classical oracle can flip the phase of a
marked state using an ancilla register. Today's oracle reflection
$O_f$ is implemented by exactly that mechanism.

If those three sessions are fresh, the new material today is small: a
geometric fact that two reflections compose to a rotation, and the
formula $P(k)=\sin^2((2k+1)\theta/2)$ for the probability after $k$
iterations. Everything else — unitarity of $O_f$ and $D$, the angle
$\theta$, the optimum iteration count — follows by connecting things
you have already derived. The most common point of confusion is the
periodic behavior of $P(k)$: probability rises to a peak, then falls,
then rises again. That is not surprising once you see it as a rotation
around a circle, which never stops at any fixed angle.

## The hook

Take $N=4$ items ($n=2$ qubits) with $M=1$ marked item. The geometry
of the 2D good/bad plane gives $\sin(\theta/2)=\sqrt{M/N}=
\sqrt{1/4}=1/2$, so $\theta/2=30°$ and $\theta=60°$. Writing
$|s\rangle$ in coordinates $(bad, good)$ as $(\cos30°,\sin30°)=
(\sqrt3/2,\,1/2)$, the initial state sits at angle $30°$ from the
bad axis. One Grover iteration rotates by $\theta=60°$, moving the
angle to $30°+60°=90°$ — exactly the good axis. The final state is
$(0,1)=|good\rangle$ and measuring it returns the marked item with
probability $\sin^2(90°)=1$.

The classical baseline makes the contrast concrete. Randomly sampling
one item from four finds the marked one with probability $1/4=0.25$,
so three draws out of four fail. The quantum algorithm achieves
certainty in a single oracle query. This is an exact advantage, not
an approximation, and it arises from the special arithmetic of $N=4$:
the rotation angle $60°$ happens to carry $|s\rangle$ from its
starting angle of $30°$ directly to $90°$ in one step. For $N=16$,
$M=1$, the rotation angle shrinks to $\approx29°$ and the best
integer iteration count is $k=3$, which reaches $\approx96\%$
probability but not exactly $100\%$ — the generic situation.

## The pictures

The first picture is a clock face with the bad axis pointing right
(three o'clock) and the good axis pointing up (twelve o'clock). The
initial state $|s\rangle$ is an arm sitting close to the bad axis at
a small angle $\theta/2$ above horizontal — for $N=16$, $M=1$ that
is only $\approx14.5°$. Each Grover iteration rotates the arm
counter-clockwise by $\theta\approx29°$. At $k=3$ the arm sits at
$(2\cdot3+1)\cdot14.5°\approx101°$, just past twelve o'clock, which
is why the probability at $k=3$ is $0.962$ and not $1.0$. If you
let the arm keep rotating past twelve o'clock it swings around toward
nine o'clock, then back toward twelve for a second pass near $k=9$:
the arm never stops, it just cycles around.

The second picture is an amplitude bar chart. Start with $N=16$ equal
bars at height $1/4$. After $O_f$ the one marked bar flips to
$-1/4$; all others stay at $+1/4$. The diffusion step $D$ reflects
every amplitude about the mean: the marked bar shoots up dramatically
(from $-1/4$ to roughly $+11/16$ after the first full iteration)
while each unmarked bar drops slightly (from $+1/4$ to roughly
$+3/16$). Repeating this pattern for $k$ steps continues to pump
amplitude into the marked bar and drain it from the unmarked ones,
until at $k=3$ the marked bar is very tall and all others are nearly
flat. If you go past $k=3$, the marked bar overshoots and begins to
shrink while the unmarked bars grow back — the same overshoot visible
in the rotation diagram, now shown amplitude by amplitude.

The third picture is two mirrors standing in the good/bad plane. The
first mirror lies along the bad axis — that is $O_f$. The second
mirror is tilted $\theta/2$ from the first, lying along the $|s\rangle$
direction — that is $D$. When a ray bounces off the first mirror and
then the second, the net effect is a rotation by twice the angle
between the mirrors, which is $\theta$. The direction of rotation is
always toward $|good\rangle$ because $|s\rangle$ lies between the
bad axis and the good axis in the plane. Whether you iterate once or
many times, each double-bounce is the same fixed rotation — which
explains both the quadratic speedup and the overshoot: the rotation
advances by the same $\theta$ every step, regardless of where the
state currently sits.

## Concrete-first walkthrough

The section **"The unstructured search problem"** establishes the
baseline. You query the oracle once per item, and without structure
to exploit the classical expected query count is $\Theta(N/M)$.
Grover's algorithm reduces this to $O(\sqrt{N/M})$ quantum oracle
queries — a provably optimal quadratic speedup; no quantum algorithm
can search an unstructured oracle faster.

**"The good/bad subspace and the state $|s\rangle$"** introduces the
geometric arena. The $M$ marked basis states, normalized, span one
vector $|good\rangle$; the $N-M$ unmarked states, normalized, span
an orthogonal vector $|bad\rangle$. Together they form a real 2D
subspace. The uniform superposition $|s\rangle=N^{-1/2}\sum_x|x\rangle$
lies in this subspace at angle $\theta/2$ from $|bad\rangle$, where
$\sin(\theta/2)=\sqrt{M/N}$. Every operator in Grover's algorithm
maps this subspace to itself, so the entire algorithm lives in 2D.

**"The oracle reflection $O_f$"** is $I-2P_{good}$, where $P_{good}$
is the projector onto the span of the marked basis states. Since
$P_{good}$ is Hermitian and idempotent, $O_f^2=I$: it is a unitary
involution. In the 2D subspace its matrix is $\operatorname{diag}
(1,-1)$ in the $(|bad\rangle,|good\rangle)$ basis — it preserves the
bad component and flips the sign of the good component, exactly a
reflection about the bad axis. The bridge to Day 8: this sign flip
is implemented via phase kickback, $U_f|x\rangle|-\rangle=
(-1)^{f(x)}|x\rangle|-\rangle$, with the $|-\rangle$ ancilla
discarded after; the work register alone carries the phase
$(-1)^{f(x)}$, which is precisely $O_f$ acting on the work register.

**"The diffusion operator $D$"** is $2|s\rangle\langle s|-I$. The
rank-1 projector $|s\rangle\langle s|$ is Hermitian and idempotent,
so by the same involution argument $D^2=I$ and $D$ is unitary. In
the 2D subspace $D$ reflects any vector about the $|s\rangle$ axis,
preserving the component along $|s\rangle$ and negating the component
orthogonal to it.

**"Composing two reflections: Grover's algorithm as rotation"** is
the geometric heart. $O_f$ reflects about $|bad\rangle$ and $D$
reflects about $|s\rangle$; those axes meet at angle $\theta/2$; so
$D\cdot O_f$ is a rotation by $\theta$ toward $|good\rangle$. After
$k$ iterations the state sits at angle $(2k+1)\theta/2$ from the bad
axis and the success probability is $P(k)=\sin^2((2k+1)\theta/2)$.
Check on $N=4$: $(2\cdot1+1)\cdot30°=90°$, $\sin^2(90°)=1$ exactly.

**"How many iterations?"** gives the stopping rule. $P(k)$ is
periodic in $k$ because $(2k+1)\theta/2$ advances around a circle
without stopping. The first maximum is the integer $k$ nearest
$k^\star=\pi/(2\theta)-1/2$, found by solving $(2k+1)\theta/2=\pi/2$.
For small $M/N$ the approximation $\theta\approx2\sqrt{M/N}$ gives
the heuristic $k^\star\approx(\pi/4)\sqrt{N/M}$. One important trap:
for the $N=16$, $M=1$ case, probability decreases on iterations
$4$–$6$ and then climbs toward a second peak near $k=9$, not toward
zero. The state has rotated past $|good\rangle$ and is circling back
for a second pass, not decaying — stopping at the first peak uses the
fewest oracle queries.

## Derivation roadmaps

For the rotation claim in **"Composing two reflections: Grover's
algorithm as rotation"**: the key trick is that two reflections across
lines meeting at angle $\alpha$ compose to a rotation by $2\alpha$.
In the $(|bad\rangle,|good\rangle)$ basis, write $O_f=\operatorname
{diag}(1,-1)$. For $D$, express $|s\rangle=(\cos(\theta/2),
\sin(\theta/2))$ and expand $D=2|s\rangle\langle s|-I$ entry by
entry, using the double-angle identities $2\cos^2(\theta/2)-1=
\cos\theta$ and $2\sin(\theta/2)\cos(\theta/2)=\sin\theta$ to
simplify each entry. Multiply $D\cdot O_f$ and verify the product
matches the standard counter-clockwise rotation matrix for angle
$\theta$. No geometric theorem is required — only double-angle
algebra and one matrix multiplication.

For the optimal count in **"How many iterations?"**: the key trick is
that the success probability peaks when the state's angle
$(2k+1)\theta/2$ equals $\pi/2$. Solve for $k$ to get $k^\star=
\pi/(2\theta)-1/2$; round to the nearest integer. For the heuristic,
replace $\arcsin(\sqrt{M/N})$ by $\sqrt{M/N}$ — valid when $M/N\ll1$
— giving $\theta/2\approx\sqrt{M/N}$, then substitute and simplify
to $k^\star\approx(\pi/4)\sqrt{N/M}$. To see when the approximation
breaks, check whether the rounded exact and heuristic $k^\star$ agree
for $N=16,M=1$ (they do) versus a larger $M/N$ ratio.

For the reflection interpretation of **"The diffusion operator $D$"**:
the key trick is "reflect about the mean amplitude." Decompose any
state $v=c|s\rangle+c_\perp|s_\perp\rangle$ in the 2D subspace,
where $|s_\perp\rangle$ is orthogonal to $|s\rangle$ within the
subspace. Apply $Dv=2\langle s|v\rangle|s\rangle-v$ term by term:
the along-$|s\rangle$ component is preserved and the orthogonal
component is negated. The "mean amplitude" connection follows from
$\langle s|v\rangle=N^{-1/2}\sum_x v_x = \sqrt{N}\,\bar{v}$, so
$D$ maps each amplitude $v_x$ to $2\bar{v}-v_x$ — subtract the
deviation from the mean and negate, which is reflection about
the mean.

## Flashcards

Q: What is the formula for the oracle reflection $O_f$?
A: $O_f = I - 2P_{good}$, where $P_{good} = \sum_{x\,\text{good}}|x\rangle\langle x|$. In the 2D subspace it maps $(a,b)\mapsto(a,-b)$: reflection about the bad axis.

Q: What is the formula for the diffusion operator $D$?
A: $D = 2|s\rangle\langle s| - I$. It reflects any vector in the good/bad subspace about the $|s\rangle$ axis, preserving the along-$|s\rangle$ component and negating the orthogonal component.

Q: What is the rotation angle $\theta$ in terms of $M$ and $N$?
A: $\theta = 2\arcsin(\sqrt{M/N})$. For small $M/N$ this approximates to $2\sqrt{M/N}$.

Q: What is the exact optimal iteration count, and what is the small-angle heuristic?
A: Exact: the integer nearest $k^\star = \pi/(2\theta) - 1/2$. Heuristic: $k^\star \approx (\pi/4)\sqrt{N/M}$, valid when $M/N \ll 1$.

Q: For $N=4$, $M=1$: what is $\theta$, how many Grover iterations are needed, and what is the success probability?
A: $\sin(\theta/2)=1/2$, so $\theta/2=30°$ and $\theta=60°$. One iteration rotates $|s\rangle$ from $30°$ to $90°=|good\rangle$, giving probability $1$.

Q: How is $O_f$ implemented using Day 8's phase-kickback result?
A: $U_f|x\rangle|-\rangle=(-1)^{f(x)}|x\rangle|-\rangle$. The work register picks up the phase $(-1)^{f(x)}$ — exactly the sign flip that defines $O_f$ — while the $|-\rangle$ ancilla is discarded.

Q: What is the "overshoot" behavior for $N=16$, $M=1$ after the first peak?
A: Probability decreases on iterations 4–6, then climbs toward a second peak near $k=9$. The behavior is periodic, not monotone: the state has rotated past $|good\rangle$ and is circling back.

Q: After $k$ Grover iterations, what is the state's angle from the bad axis and the success probability?
A: Angle $(2k+1)\theta/2$; success probability $P(k)=\sin^2((2k+1)\theta/2)$.
