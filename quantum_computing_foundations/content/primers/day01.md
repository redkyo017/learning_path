# Day 1 — Before You Read: Boolean Logic & Reversible Computation

## The hook

Erasing a single bit of information has a physical cost. Landauer's principle
gives the exact minimum: $E \ge kT\ln 2 = (1.38\times10^{-23}\ \text{J/K})(300\
\text{K})(0.693) \approx 2.87\times10^{-21}$ J of heat must be released at room
temperature every time you irreversibly destroy one bit. That number sounds tiny,
but it is a hard thermodynamic floor — not an engineering limitation of current
transistors, but a consequence of the second law of thermodynamics applied
directly to the act of destroying information. As chip densities continue to
rise and individual transistors shrink toward atomic scales, this floor becomes
an increasingly relevant physical constraint on all computing.

The bridge to today's material is this: a circuit built entirely from reversible
gates never erases information in the logically irreversible sense, so it is not
subject to Landauer's bound on a per-gate basis. Quantum computers are built from
exactly such circuits — reversible gates are not optional extra structure but a
physical requirement. Today's reading gives you the classical foundation: what
reversibility means precisely, which gates have it, how to build everything useful
from a single universal reversible gate, and why the trade-off manifests as
"garbage bits" you cannot simply discard.

## The pictures

The first picture to hold in mind is a circuit as a bundle of horizontal wires
running left to right, one wire per bit, with gates drawn as vertical connectors
between wires at various points along the way. Information flows strictly left to
right; nothing is consumed or destroyed at any gate. In a reversible circuit
every wire that enters a gate also exits it, possibly with a changed value, and
the gate's joint action on all its wires is a bijection. If you ran the circuit
backwards from right to left you would recover the original input exactly. The
key visual intuition is that the wire count stays constant throughout: no wire
vanishes, no wire appears from nothing.

The second picture is the Toffoli gate specifically. Think of two control keys
and one locked target. The target flips only when both keys are turned at once —
that is, only when both control bits hold 1. Both control keys exit the gate
unchanged regardless of whether the flip happened. Keeping the controls as
outputs alongside the target is precisely what makes the gate reversible: if you
apply it a second time with the same controls, the flip cancels and the target
returns to its original value.

The third picture is Landauer's bound as a piston compressing a one-molecule gas.
Logically erasing a bit corresponds to collapsing two distinct physical
microstates — the bit is 0, the bit is 1 — into a single state. This shrinks
the accessible phase space by a factor of two. The second law requires that the
entropy removed from the information-bearing system be exported as heat into the
surrounding environment; the piston does work on the gas to compress it, and the
heat flows out. Reversible circuits never perform this compression: every gate
is a bijection, so the phase space stays the same size from input to output.

## Concrete-first walkthrough

Start in **Boolean gates and reversibility**. The definition hinges on a single
word: bijection. A gate on $n$ bits is reversible exactly when its input-output
function is one-to-one and onto — every possible output pattern traces back to
exactly one input pattern, so you can always reconstruct the input from the
output alone. Apply the test directly to NOT: 0 maps to 1 and 1 maps to 0, a
perfect bijection on one bit. Apply it to AND: the three inputs 00, 01, and 10
all produce output 0, so the function is many-to-one, and AND is irreversible.
That single test — bijection or not — is the lens for everything that follows.

Move to **CNOT and Toffoli**. CNOT acts on two bits: the control passes through
unchanged, and the target is XOR'd with the control. Toffoli acts on three bits:
both controls pass through unchanged, and the target is XOR'd with the AND of
the two controls. Both gates are reversible for the same structural reason —
each one XORs some function of the control bits into the target, so applying the
gate twice cancels the effect: $x \oplus x = 0$ restores the original target
value. This self-inverse property is not accidental; it is the design principle
underlying essentially every reversible classical gate in the reading. XOR is
the algebraic trick that makes reversibility cheap to engineer: any operation of
the form "XOR something into a target, leave controls alone" is automatically
its own inverse.

In **Building AND, OR, NOT reversibly**, the Toffoli gate becomes a toolkit.
Feed two data bits as controls and a fresh ancilla fixed at 0 as the target:
the ancilla exits holding the AND of the two data bits, while both data bits
pass through unchanged. Fixing both controls to the constant 1 turns the Toffoli
into a plain NOT on the target line. OR then follows from De Morgan's law —
$a \vee b = \neg(\neg a \wedge \neg b)$ — by composing the AND and NOT gadgets
in sequence. The key point to absorb before the reading is that this is not a
special trick for three gates: it is a general method, and any classical Boolean
function can be realized entirely with Toffoli gates and constant ancillas.

A trap that many readers fall into: overwriting a bit via a bijection is still
reversible. Applying NOT in-place to a single bit does not violate reversibility,
because NOT is a bijection on one bit. Irreversibility enters only when the
function is many-to-one. The fresh ancilla in the reversible AND construction
serves a different purpose than reversibility — it is there to keep the original
values of $a$ and $b$ available on output, so that downstream gates in the same
circuit can use them. The reversibility of the gate itself follows entirely from
the XOR-into-target structure, not from having a fresh ancilla.

**Universality and garbage bits** extends the local gadgets to full circuits.
Any classical circuit of $g$ AND/OR/NOT gates converts mechanically into a
reversible circuit by replacing each gate with its Toffoli construction, one at
a time, feeding a fresh zero-ancilla to each new gate. The result is a circuit
that is a bijection from input to output as a whole. The cost is that every
fresh ancilla now exits holding some intermediate value you did not request —
a garbage bit. Because the entire circuit is a bijection, you cannot erase these
garbage bits mid-circuit or at the end; doing so would introduce a many-to-one
step and violate reversibility. The garbage must be carried along, making the
output considerably wider than the answer you cared about.

Close with **Landauer's principle**. The floor $kT\ln 2 \approx 2.87\times10^{-21}$
J at room temperature is set by thermodynamics, not by transistor physics. A
reversible circuit that preserves all its garbage bits never crosses this floor,
because no step is logically irreversible. This is the physical motivation for
building quantum computers — and reversible classical circuits — at all: not a
mathematical preference for bijections, but the only computing architecture that
is not fundamentally penalized by thermodynamics on every operation that discards
a bit.

## Derivation roadmaps

The **Claim:** in the worked example asks you to verify that Toffoli gates and
constant ancillas can compute the majority function MAJ on three bits. The key
trick is to decompose MAJ as three pairwise ANDs — compute $a\wedge b$,
$b\wedge c$, and $a\wedge c$ each onto a fresh zero-ancilla using three Toffoli
calls — and then OR the three AND-results together using the De Morgan
construction. What you need to fill in is the OR reduction: the exact Toffoli
sequence that ORs three bits, plus an honest count of every wire exiting the
circuit — three original inputs unchanged, three pairwise-AND garbage bits, one
intermediate OR garbage bit, one final MAJ answer — confirming the eight-line
total and the four-garbage-bit figure stated in the reading.

The universality argument is a second roadmap. The key trick is that each
classical gate is replaced by a constant-size reversible gadget — a fixed,
$g$-independent number of Toffoli gates and ancillas — so total gate and
ancilla counts grow as $O(g)$. What you need to fill in is the inductive
structure: a base case (zero gates, trivially reversible), and an inductive step
arguing that appending one more constant-size gadget to an already-reversible
circuit yields another reversible circuit, because composition of bijections is
a bijection. Assembling those two pieces into a formal proof is the exercise.

## Flashcards

Q: What property makes a Boolean gate reversible?
A: Its input-output function must be a bijection — every output pattern
corresponds to exactly one input, so the input is always recoverable from
the output alone.

Q: What does CNOT do, and why is it its own inverse?
A: CNOT$(a,b) = (a,\ a\oplus b)$: the control passes through; the target is
XOR'd with the control. Applying it twice gives $a\oplus(a\oplus b)=b$,
restoring the original — XOR with the same value cancels.

Q: How is AND computed reversibly using a Toffoli gate?
A: Toffoli$(a, b, 0)$: the two data bits are controls; a fresh ancilla fixed
at 0 is the target. The ancilla exits holding $a\wedge b$; both data bits
pass through unchanged.

Q: What is a garbage bit and why can it not be erased?
A: An ancilla that exits a reversible circuit holding an intermediate value
not requested as output. Erasing it would introduce a many-to-one map step,
making the overall circuit irreversible and violating Landauer's bound.

Q: State Landauer's principle with the room-temperature number.
A: Erasing one bit irreversibly releases at least $kT\ln 2 \approx
2.87\times10^{-21}$ J at $T = 300$ K — a thermodynamic floor, not an
engineering limit.

Q: Why is applying NOT in-place to a bit still reversible?
A: NOT is a bijection on one bit (0 maps to 1, 1 maps to 0), so overwriting
a bit with NOT does not destroy information. Irreversibility requires a
many-to-one function; NOT is one-to-one.

Q: How many output lines does the MAJ reversible circuit produce, and how
many are garbage?
A: Eight lines total: 3 original inputs (unchanged), 1 MAJ answer, and
4 garbage bits — the three pairwise-AND results plus one intermediate OR value.

Q: Why are reversible gates physically necessary for quantum computing?
A: Quantum evolution is unitary and therefore inherently reversible; any
irreversible gate would violate unitarity. Reversible circuits also sidestep
Landauer's per-erasure energy floor, making them the only thermodynamically
unconstrained computing model.
