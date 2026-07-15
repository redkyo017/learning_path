# Day 1 — Boolean Logic & Reversible Computation

## Learning objectives

By the end of today you should be able to:
- State which classical gates are reversible and prove it directly from
  their truth tables.
- Construct AND, OR, and NOT reversibly using only Toffoli gates and
  constant ancilla bits.
- Explain why any classical circuit can be converted to a reversible one,
  and what "garbage bits" are and why they must be kept, not erased.
- State Landauer's principle and connect it to why reversible computing
  matters at all, before any mention of quantum mechanics.

## Reference material

- Primer: Yanofsky & Mannucci, *Quantum Computing for Computer Scientists*,
  the chapter covering Boolean circuits and reversible gates.
- The theory below is self-contained — you do not need the book to do
  today's work, but reading the matching chapter alongside this is useful
  for a second explanation in different words.

## Theory

### Boolean gates and reversibility

A **Boolean gate** on $n$ bits computes some function $f: \{0,1\}^n \to
\{0,1\}^m$. The standard gates AND, OR, NOT (and the single universal gate
NAND, from which all others can be built) are the ones you already know from
ordinary digital logic.

A gate on $n$ bits is **reversible** iff its function $\{0,1\}^n \to
\{0,1\}^n$ is a *bijection*: every possible output pattern has exactly one
input pattern that produces it. Equivalently, you can always determine the
input uniquely from the output — nothing about the input is "thrown away."

Ordinary AND and OR are **not** reversible: AND$(0,0) = $ AND$(0,1) = $
AND$(1,0) = 0$, so three different inputs map to the same output — you
cannot recover the input from the output alone. NOT, on the other hand,
*is* reversible on its own (it's a bijection on one bit), but it's too weak
by itself to build anything interesting.

### CNOT and Toffoli

Two gates that are both reversible and powerful enough to build everything
else:

**CNOT** (controlled-NOT): $\text{CNOT}(a,b) = (a,\ a\oplus b)$. The first
bit (the *control*) passes through unchanged; the second bit (the *target*)
gets flipped exactly when the control is $1$.

**Toffoli** (CCNOT, controlled-controlled-NOT):
$\text{Toffoli}(a,b,c) = (a,\ b,\ c \oplus (a \wedge b))$. Both control bits
pass through unchanged; the target bit gets flipped exactly when *both*
controls are $1$.

Both are reversible, and for the same structural reason: each is its own
inverse. Applying CNOT twice: $(a,b) \to (a, a\oplus b) \to (a, a \oplus
(a\oplus b)) = (a, b)$, using $a \oplus a = 0$. The same cancellation happens
for Toffoli. A gate that XORs some function of the control bits into the
target bit, leaving the controls alone, is automatically its own inverse and
therefore automatically reversible — this is the single idea underlying
essentially every reversible classical gate.

### Building AND, OR, NOT reversibly

The point of Toffoli is not just that it's reversible — it's that, together
with **ancilla bits** (extra bits you introduce, fixed at a known constant
$0$ or $1$), it lets you realize the ordinary irreversible gates
reversibly:

- **Reversible AND:** Toffoli$(a, b, 0) = (a, b, 0 \oplus (a\wedge b)) =
  (a, b, a\wedge b)$. Feed a fresh ancilla fixed at $0$ as the target; it
  comes out holding $a \wedge b$, while $a$ and $b$ pass through unchanged.
- **Reversible NOT:** Toffoli$(1, 1, c) = (1, 1, c \oplus 1) = (1, 1,
  \neg c)$. Fixing *both* controls to the constant $1$ turns Toffoli into a
  NOT on the target line.
- **Reversible OR:** by De Morgan's law, $a \vee b = \neg(\neg a \wedge
  \neg b)$, so OR is built by composing the AND and NOT constructions above.

So "Toffoli gates plus constant ancilla bits" is enough, by itself, to
realize a universal classical gate set (AND, NOT, and therefore OR) —
entirely reversibly.

### Universality and garbage bits

This generalizes: **any classical circuit** built from AND/OR/NOT with $g$
gates can be converted into a reversible circuit using $O(g)$ Toffoli gates
and $O(g)$ fresh ancilla bits. The recipe is mechanical: walk through the
original circuit gate by gate, replace each AND/OR/NOT with its Toffoli
construction above, feeding a fresh $0$-ancilla to each one.

The catch is that every one of those ancilla lines now holds some
intermediate value you didn't ask for — a **garbage bit**. Because
reversible gates are bijections, you cannot simply "overwrite and forget"
these values the way an ordinary irreversible circuit implicitly does; a
reversible circuit's *entire* output, garbage included, must together be
a bijective function of the entire input. So a reversible version of a
circuit that computes one output bit ends up with many more output
lines than you started with — the original result plus a pile of garbage
you must carry along (or, in more advanced constructions, "uncompute" back
to $0$ once you no longer need it, by running the relevant part of the
circuit backwards after copying out the answer you wanted — a standard
trick, mentioned here for context, not required for today's exercises).

### Landauer's principle

Why care about any of this before quantum computing has even been
mentioned? **Landauer's principle**: a logically irreversible operation —
one that maps two or more distinct states to the same state, i.e. erases
information — must dissipate at least $kT\ln 2$ of energy as heat, where
$k$ is Boltzmann's constant and $T$ is the temperature. This is a
*physical* lower bound, not an engineering limitation of current
transistors — it follows from the second law of thermodynamics applied to
information.

A circuit built entirely from reversible gates, with garbage bits kept
(not erased), is not subject to this bound on a per-gate basis, because no
step of it is logically irreversible — it's a bijection start to finish.
This is the physical motivation for caring about reversible computing at
all: it is not merely an academic curiosity, but the only way to compute
that isn't fundamentally bound by this thermodynamic floor.

## Worked example

**Claim:** Toffoli gates and constant ancillas can compute the majority
function $\text{MAJ}(a,b,c) = 1$ iff at least two of $a,b,c$ are $1$.

Classically, $\text{MAJ}(a,b,c) = (a\wedge b) \vee (b\wedge c) \vee
(a\wedge c)$. Build it reversibly, one AND at a time, each on a fresh
ancilla:

1. Toffoli$(a,b,0) \to$ ancilla $1$ holds $a\wedge b$; call it $g_1$.
2. Toffoli$(b,c,0) \to$ ancilla $2$ holds $b\wedge c$; call it $g_2$.
3. Toffoli$(a,c,0) \to$ ancilla $3$ holds $a\wedge c$; call it $g_3$.

Now OR three bits together using the De Morgan construction (NOT, AND, NOT):
$g_1 \vee g_2 \vee g_3 = \neg(\neg g_1 \wedge \neg(g_2\vee g_3))$, applied
twice. Each NOT is Toffoli$(1,1,\cdot)$; each remaining AND is another
Toffoli-on-a-fresh-ancilla. The final ancilla holds $\text{MAJ}(a,b,c)$; every
other line — $a,b,c$ themselves plus $g_1,g_2,g_3$ and the intermediate OR
results — is either an original input or a garbage bit that must be kept.
Counting: 3 original inputs never change, and the circuit produces one
"real" answer plus 5 garbage bits (three AND-results, two intermediate ORs)
for a total of 9 output lines from 3 input lines — a concrete illustration
of why garbage accumulates quickly even for a simple 3-input function.

## Exercises

Attempt every problem closed-book before checking the Solutions section
below.

1. Write out the full truth table for CNOT (4 rows) and for Toffoli
   (8 rows). Verify directly from the tables that applying each gate twice
   in a row returns every input unchanged.
2. Using a single Toffoli gate and a fresh ancilla fixed at $0$, construct a
   reversible AND: what are the exact inputs to the Toffoli gate, and what
   appears on each output line?
3. Show that Toffoli$(1,1,c) = (1,1,\neg c)$, and explain why this means
   Toffoli, together with constant ancillas, realizes NOT.
4. Using Steps 2 and 3 and De Morgan's law, sketch how to build a reversible
   OR gate. How many Toffoli gates and how many ancilla bits does your
   construction use?
5. Construct a reversible circuit (Toffoli/CNOT/NOT only) that computes the
   3-bit XOR $a \oplus b \oplus c$. How many ancilla/garbage bits does your
   circuit need, if any? (Hint: is XOR itself already reversible on 3 bits,
   in the sense of the definition at the top of today's theory?)
6. Sketch a proof that any classical circuit with $g$ AND/OR/NOT gates can
   be converted into a reversible circuit using $O(g)$ Toffoli gates and
   $O(g)$ ancilla bits.
7. Build a reversible full adder: given inputs $(a, b, c_{in})$, produce
   $(\text{sum}, \text{carry})$ where $\text{sum} = a\oplus b\oplus c_{in}$
   and $\text{carry} = (a\wedge b)\vee(b\wedge c_{in})\vee(a\wedge c_{in})$
   (note: this is exactly the majority function from the worked example).
   Write out the circuit and label which output lines are garbage.
8. State Landauer's principle and compute the minimum energy dissipated by
   erasing one bit at room temperature ($T=300\text{K}$,
   $k=1.38\times10^{-23}\ \text{J/K}$). Give your answer in joules.
9. Explain, referencing your Exercise 2–5 constructions, why a
   garbage-preserving reversible circuit sidesteps the per-erasure bound
   from Exercise 8, while a NAND-based irreversible circuit that overwrites
   intermediate results does not.

## Solutions

**1.** CNOT truth table:

| $a$ | $b$ | $a\oplus b$ |
|---|---|---|
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |

Applying CNOT again to $(a, a\oplus b)$ gives $(a,\ a \oplus (a\oplus b))$.
Since $a\oplus(a\oplus b) = (a\oplus a)\oplus b = 0\oplus b = b$, this is
$(a,b)$ — the original input, for all 4 rows.

Toffoli truth table ($c' = c \oplus (a\wedge b)$):

| $a$ | $b$ | $c$ | $c'$ |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 1 |
| 0 | 1 | 0 | 0 |
| 0 | 1 | 1 | 1 |
| 1 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 |
| 1 | 1 | 0 | 1 |
| 1 | 1 | 1 | 0 |

Applying Toffoli again to $(a,b,c')$ gives $c'' = c' \oplus (a\wedge b) = c
\oplus (a\wedge b) \oplus (a \wedge b) = c \oplus 0 = c$, using the same
$x\oplus x = 0$ cancellation — for all 8 rows, the second application
restores $c$.

**2.** Toffoli$(a, b, 0)$: the two data bits $a, b$ are the controls, and a
fresh ancilla fixed at $0$ is the target. Output: $a$ and $b$ pass through
unchanged, and the target line becomes $0 \oplus (a\wedge b) = a\wedge b$.

**3.** Toffoli$(1,1,c) = (1, 1, c\oplus(1\wedge 1)) = (1,1,c\oplus 1) =
(1,1,\neg c)$, since $c\oplus 1$ flips $c$. Fixing both controls to the
constant $1$ makes the AND term always $1$, so the target line always gets
flipped — exactly NOT, applied to whatever value sits on the target line.

**4.** $a \vee b = \neg(\neg a \wedge \neg b)$. Using Exercise 3's
construction, compute $\neg a$ and $\neg b$ (2 Toffoli gates, no new
ancilla needed if you're willing to overwrite — though to stay strictly
reversible you'd route these onto fresh ancilla lines and keep $a,b$
untouched, costing 2 more ancillas). Then AND them together via Exercise
2's construction (1 Toffoli gate, 1 fresh ancilla). Then NOT the result
(1 more Toffoli gate). Total: 4 Toffoli gates, at least 3 fresh ancilla
bits (two for $\neg a,\neg b$, one for the AND result — the final NOT can
reuse the AND-result line as its target).

**5.** XOR on 3 bits, $a\oplus b\oplus c$, computed by $\text{CNOT}(a,b)$
then $\text{CNOT}(\text{result}, c)$ — i.e. $(a,b,c) \to (a, a\oplus b, c)
\to (a, a\oplus b, a\oplus b\oplus c)$ — needs **zero** extra ancilla bits.
This is because CNOT is already exactly the kind of "XOR into a target,
controls pass through" gate the theory section describes, and composing
two reversible gates gives another reversible gate (a composition of
bijections is a bijection) — no garbage is created because nothing is
being computed *and* discarded; every line is either an original input or
directly the running XOR.

**6.** By induction on the circuit's gate count. Base case: a circuit with
0 gates is already the identity, trivially reversible. Inductive step:
given a reversible circuit for the first $g-1$ gates (using $O(g-1)$
Toffolis/ancillas by the inductive hypothesis), the $g$-th gate is AND, OR,
or NOT on some existing wires. By the constructions in Exercises 2–4, each
of these can be realized with $O(1)$ Toffoli gates and $O(1)$ fresh
ancilla bits, fed from the existing wires and producing one new output
wire (plus possibly $O(1)$ more garbage, in the OR case). Appending this
$O(1)$-size reversible gadget to the existing reversible circuit keeps the
whole thing reversible (composition of bijections), and the total gate/
ancilla count is $O(g-1) + O(1) = O(g)$.

**7.** $\text{sum} = a\oplus b\oplus c_{in}$ is exactly Exercise 5's 3-bit
XOR: 2 CNOTs, 0 ancillas, writing the result onto a fresh line (or onto
$c_{in}$'s line if you don't need to preserve it — but to stay strictly
reversible and keep all of $a,b,c_{in}$ available, route it to a fresh
line, which then holds sum). $\text{carry} = \text{MAJ}(a,b,c_{in})$ is
exactly the worked example above: 3 Toffolis producing $a\wedge b$,
$b\wedge c_{in}$, $a\wedge c_{in}$ on 3 fresh ancillas, then OR-ing those
three together via the Exercise 4 construction. Garbage: the three
pairwise-AND ancillas and any intermediate OR ancilla are all garbage —
only the final sum and carry lines are "wanted" outputs; $a, b, c_{in}$
remain as unchanged inputs.

**8.** $E \ge kT\ln 2 = (1.38\times10^{-23}\ \text{J/K})(300\ \text{K})
(0.693) \approx 2.87\times10^{-21}\ \text{J}$ per bit erased.

**9.** In every construction above (Exercises 2–5), no step ever
*overwrites* a value that held prior information without also keeping
that information recoverable elsewhere in the (larger) output — the
circuit as a whole remains a bijection from all inputs (data + ancilla) to
all outputs (data + garbage). Landauer's bound applies specifically to
logically irreversible, many-to-one steps — erasure. A NAND-based circuit
that computes an intermediate result and then overwrites that wire with
the next computation's output (the normal, space-efficient way ordinary
processors work) performs exactly this kind of many-to-one erasure at
every overwrite, so each one is individually subject to the
$kT\ln2$ floor from Exercise 8. A reversible circuit that instead routes
every intermediate result to a fresh, never-overwritten wire (accepting
the garbage-accumulation cost quantified in Exercise 7) never performs
that many-to-one step, and so is not bound by Landauer's limit at all —
the trade is more wires (space) for no thermodynamic floor on erasure
energy.

## Journal template

```
## Day 1 — Boolean logic & reversible computation
Key idea in my own words: ...
What confused me: ...
```
