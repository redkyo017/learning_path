# Encoding Primers Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 22 "encoding primer" companion files (plus an index README) that front-load intuition, pictures, memory hooks, proof scaffolding, and daily spaced retrieval for each content day of the linear algebra 30-day plan — originals byte-untouched.

**Architecture:** Pure additive companion, same pattern as `content/solutions_expanded/`. Each primer lives in `content/primers/dayNN.md`, is read *before* `content/dayNN.md`, and follows a fixed six-section structure. All creative/mathematical decisions are locked in the per-task **Brief** below; the implementer expands briefs into prose, pulling exact theorem statements from the main day file.

**Tech Stack:** Plain GitHub-flavored markdown with LaTeX math (`$...$`), ASCII/unicode diagrams in fenced code blocks. No tooling, no images, no code.

## Global Constraints

- **NO GIT COMMITS — ever.** The user handles all version control. Any "commit" step convention from process skills is void for this project.
- Originals byte-untouched: never edit `content/dayNN.md`, `solutions_expanded/`, code, or docs other than this plan's checkboxes.
- Spec: `docs/superpowers/specs/2026-08-04-encoding-primers-companion-design.md` — six fixed sections per primer, in this order: **Warm-up → The hook → The pictures → Concrete-first walkthrough → Proof roadmaps → Flashcards**.
- Target length ~150–250 lines per primer. Hard rules: never restate a full proof; cite the main file's Definition/Theorem numbers exactly (verify against the file, the Brief's numbering is authoritative only if it matches); no forward references except flagged "coming on Day NN" teasers.
- Flashcard format, exactly: a `### Flashcards` section of repeated pairs `**Q:** …` / `**A:** …` (blank line between pairs). 6–10 cards/day.
- Warm-up section format: "Before reading anything new, answer the flashcards at the end of `primers/dayNN.md` for: Day A, Day B, Day C (~10 min). Say each answer out loud or on paper *before* flipping." Day 1 has no warm-up section (nothing prior exists) — its file starts at The hook.
- Tone: plain language, second person, same register as the existing "Plain-language review" sections in the main files.
- Every task's implementer MUST read the target day's main file (`content/dayNN.md`) before writing, and reconcile the Brief's theorem numbering against the actual headings.

## File Structure

```
content/primers/
  README.md      # Task 0 — purpose, usage, warm-up schedule table
  day01.md … day06.md, day08.md … day12.md, day14.md … day17.md,
  day19.md … day23.md, day25.md, day26.md    # Tasks 1–22
```

## Standard steps for every primer task (Tasks 1–22)

Each primer task uses these four steps (checkboxes repeated per task):

1. Read `content/dayNN.md` in full; note exact Definition/Theorem headings.
2. Write `content/primers/dayNN.md` from the task's Brief, following the six-section structure and Global Constraints.
3. Verify: all six sections present in order (five for Day 1); 150–250 lines; every theorem cited exists in the main file with matching number; no full proofs; flashcard count 6–10; warm-up days match the Brief.
4. Run `git status --short content/` and confirm the ONLY change is the new primer file. Do not commit.

---

### Task 0: primers/README.md

**Files:**
- Create: `content/primers/README.md`

**Interfaces:**
- Produces: the warm-up schedule table that every primer's Warm-up section must agree with.

- [ ] **Step 1: Write README** containing: (a) what primers are (encoding-side companion: read the primer, then the main day file; ~10 min warm-up + 15–20 min read); (b) why (concrete-before-abstract, pictures, graduated proof hints, daily spaced retrieval between the plan's review days); (c) the six-section structure; (d) the full warm-up schedule table below, verbatim; (e) note that review days (7, 13, 18, 24, 27) and days 28–30 have no primers by design.

| Primer day | Warm up with flashcards from |
|---|---|
| 1 | — (first day) |
| 2 | 1 |
| 3 | 2, 1 |
| 4 | 3, 2, 1 |
| 5 | 4, 3, 1 |
| 6 | 5, 4, 1 |
| 8 | 6, 5, 1 |
| 9 | 8, 6, 2 |
| 10 | 9, 8, 3 |
| 11 | 10, 9, 4 |
| 12 | 11, 10, 5 |
| 14 | 12, 11, 6 |
| 15 | 14, 12, 8 |
| 16 | 15, 14, 9 |
| 17 | 16, 15, 10 |
| 19 | 17, 16, 11 |
| 20 | 19, 17, 12 |
| 21 | 20, 19, 14 |
| 22 | 21, 20, 15 |
| 23 | 22, 21, 16 |
| 25 | 23, 22, 17 |
| 26 | 25, 23, 19 |

(Rule encoded: the two most recent content days + one from ~a week back.)

- [ ] **Step 2: Verify** table matches the above exactly; `git status` shows only the new file.

---

### Task 1: Primer Day 1 — Vector spaces, subspaces, span

**Files:** Create: `content/primers/day01.md` (main file: `content/day01.md`)

**Brief:**

- **Warm-up:** none — omit the section; open with a one-line note that warm-ups start on Day 2.
- **Hook:** You have two ingredients $v=(1,2,0)$ and $w=(0,1,1)$ in $\mathbb{R}^3$ and you may mix them: $av+bw$. Can you make $(2,5,1)$? (Yes: $a=2,b=1$.) Can you make $(1,1,1)$? (No — solve and hit a contradiction.) So the reachable set is not everything: what *shape* is it? A plane through the origin. Today's material is the vocabulary for "the set of everything you can mix" (span) and for which sets deserve the name "space."
- **Pictures:** (1) Two arrows in $\mathbb{R}^3$ with the plane they sweep out — caption: span = the flat sheet of all mixtures. (2) A line through the origin vs. a parallel line missing it — the offset line fails closure ($v+w$ leaves it): subspaces must contain $0$. (3) Two distinct lines through the origin forming an X, with $u$ on one, $w$ on the other, and $u+w$ off both — the union of subspaces is not a subspace (matches the Day 1 Remark).
- **Walkthrough & memory hooks:** Def 1.1 (vector space) — "a room where adding and scaling never take you outside; the axioms are just the rules of arithmetic you already use, promoted to law." Def 1.2 (subspace) — "a flat through the origin; test 3 things: has 0, closed under +, closed under scaling." Def 1.3 (span) — "everything you can mix." Thm 1.1 — slogan: "the mixing set is itself a room." Thm 1.2 — "the overlap of two flats is flat." Remark — "an X is not flat." Give a tiny numeric instance before each definition (reuse hook vectors).
- **Proof roadmaps:** Thm 1.1 — key trick: *don't chase shapes, check the three subspace conditions on generic mixtures.* Hints: (1) first move: write two arbitrary elements of the span as explicit combinations; (2) middle: their sum is again a combination — collect coefficients; watch the two combinations using different index sets (pad with zero coefficients); (3) sketch: same for scalar multiples; $0$ = the all-zero combination. Thm 1.2 — key trick: *membership in an intersection is two memberships.* Hints: (1) take $u,v \in W_1 \cap W_2$; (2) apply closure inside each $W_i$ separately; (3) conclude for $u+v$ and $cu$.
- **Flashcards (7):** Q: The three-point subspace test? A: contains 0; closed under addition; closed under scalar multiplication. / Q: Define span(S) precisely. A: the set of all finite linear combinations $a_1v_1+\dots+a_nv_n$ of vectors in S. / Q: Is a line not through the origin a subspace? Why? A: No — it fails to contain 0 (and closure fails). / Q: Slogan for Theorem 1.1? A: "The mixing set is itself a room" — span(S) is always a subspace. / Q: Is $W_1 \cup W_2$ a subspace in general? A: No — sums of vectors from different lines leave the union (X shape isn't flat); intersection IS. / Q: What's the only subspace-membership fact you get for free from the axioms? A: $0v = 0$, so every subspace contains the zero vector. / Q: Why does span(∅) = {0}? A: By convention the empty combination is 0.

Then the four standard steps:

- [ ] Step 1: Read `content/day01.md` fully.
- [ ] Step 2: Write `content/primers/day01.md` from the Brief (five sections — no warm-up).
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 2: Primer Day 2 — Linear independence, basis, dimension

**Files:** Create: `content/primers/day02.md` (main file: `content/day02.md`)

**Brief:**

- **Warm-up:** Day 1.
- **Hook:** Take $u=(1,0)$, $v=(0,1)$, $w=(1,1)$ in $\mathbb{R}^2$. Every point is a mix of them — but $w = u+v$ is a freeloader: throw it out and you lose nothing. Question with numbers: can you write $(3,5)$ *in more than one way* using all three? (Yes — infinitely many ways; e.g. $3u+5v+0w$ or $2u+4v+1w$.) Redundancy = ambiguity. Today: how to detect freeloaders (independence), what a minimal non-redundant kit is (basis), and why every kit for the same space has the same size (dimension).
- **Pictures:** (1) Three arrows in the plane, the third drawn dashed as $u+v$ — caption: dependent = someone is a mix of the others. (2) A basis as a grid: two independent arrows generating graph paper; every point gets exactly one address. (3) The exchange idea: a shelf of $n$ spanning vectors; each independent $w_i$ walks in and one $v$ must leave — independent sets can never outnumber a spanning set (Steinitz).
- **Walkthrough & memory hooks:** Def 2.1 — "independent = the only way to mix to zero is all-zeros; no freeloaders." Thm 2.1 — "dependent ⟺ someone is a mix of the others" (show with $u,v,w$ above first). Def 2.2 (basis, dimension) — "a basis is a minimal spanning kit and a maximal independent set at once; dimension = the kit size, once we know all kits match." Thm 2.2 — "every spanning set contains a kit: evict freeloaders one at a time." Lemma 2.3 (Steinitz) — "trade one $v$ for each $w$; you can never run out of $v$'s before the $w$'s are all in." Etymology note: *basis* = Greek "foundation." Thm 2.3 — "all rulers agree — dimension is well-defined."
- **Proof roadmaps:** Thm 2.1 — trick: *move the offender to one side.* (1) If $v_i = \sum_{j\ne i} c_j v_j$, rearrange into a combination equal to 0 whose $v_i$-coefficient is $1 \ne 0$. (2) Converse: given a nontrivial relation with $a_k \ne 0$, divide by $a_k$ and isolate $v_k$. (3) Both directions are the same rearrangement read in opposite ways. Thm 2.2 — trick: *evicting a freeloader never shrinks the span.* (1) If dependent, some $v_i$ is a mix of the rest (Thm 2.1); (2) substitute that expression wherever $v_i$ appears — span unchanged; (3) sizes strictly drop, so the process stops at an independent spanning subset. Lemma 2.3 (Steinitz) — **hardest of the day; use the ladder, don't expect to invent it.** Trick: *swap the w's in one at a time, keeping "spans V" true after every swap.* (1) First move: set up induction on $k$ = number of $w$'s already swapped in; state $P(k)$: after relabeling, $\{w_1..w_k, v_{k+1}..v_n\}$ spans. (2) Middle rung: to swap in $w_{k+1}$, expand it over the current spanning set; some $v$-coefficient must be nonzero — if all were zero, $w_{k+1}$ would be a mix of $w_1..w_k$, contradicting independence. That nonzero coefficient is also why $k<n$ must hold. (3) Sketch: solve for that $v$, substitute it away — the new set still spans; induction ends at $P(m)$, giving $m \le n$. Thm 2.3 — trick: *Steinitz twice, once in each direction:* two bases each span and are each independent, so $m \le n$ and $n \le m$.
- **Flashcards (8):** Q: Definition of linear independence (precise)? A: $a_1v_1+\dots+a_nv_n=0$ only for $a_1=\dots=a_n=0$. / Q: Dependence in one slogan? A: Someone is a mix of the others (Thm 2.1). / Q: Two requirements for a basis? A: spans the space AND linearly independent. / Q: Steinitz Exchange in one sentence? A: If n vectors span V, no independent set in V can have more than n vectors. / Q: Why is dimension well-defined? A: Two bases each span and are independent, so Steinitz gives both $m\le n$ and $n\le m$. / Q: What does a redundant spanning vector cost you? A: Uniqueness of coordinates — points get many addresses. / Q: Key move to prove a set with a nontrivial relation is dependent per Thm 2.1? A: Divide by a nonzero coefficient and isolate that vector. / Q: dim{0}? A: 0 — its basis is the empty set, by convention.

Then the four standard steps:

- [ ] Step 1: Read `content/day02.md` fully.
- [ ] Step 2: Write `content/primers/day02.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 3: Primer Day 3 — Linear transformations, matrix representation

**Files:** Create: `content/primers/day03.md` (main file: `content/day03.md`)

**Brief:**

- **Warm-up:** Days 2, 1.
- **Hook:** Rotate the plane by 90°. That's a rule moving *infinitely many* points — yet you can write it down with 4 numbers. Why: rotation sends $e_1=(1,0)\mapsto(0,1)$ and $e_2=(0,1)\mapsto(-1,0)$, and *linearity forces everything else*: $(3,2) = 3e_1+2e_2 \mapsto 3(0,1)+2(-1,0) = (-2,3)$. Check it against geometry. Today formalizes: which maps allow this trick (linear ones), and how the 4 numbers are organized (the matrix — columns are the images of the basis).
- **Pictures:** (1) Before/after grid under the rotation — grid lines stay straight, parallel, evenly spaced; origin fixed. Caption: that's what "linear" looks like. (2) The matrix as a filing cabinet: column $j$ = where the $j$-th basis vector lands. (3) Two machines in series: $v \to T \to S \to$ out; caption: composition of maps = product of matrices, applied right-to-left.
- **Walkthrough & memory hooks:** Def 3.1 — "a linear map respects mixing: $T(au+bv)=aT(u)+bT(v)$; geometrically, grids stay grids." Def 3.2 — "the matrix is a phone book: column $j$ lists where basis vector $j$ went." **Pre-teach the mechanics** (the main file uses matrix–vector multiplication without defining it): show with the rotation numbers that $A x$ = "mix the columns of $A$ using the entries of $x$ as recipe amounts" — one worked 2×2 instance, then one 2×2 times 2×2 as "apply to each column." Lemma 3.1 — "two-term linearity extends to any number of terms (induction)." Thm 3.1 — "know the basis images, know everything — and there's only one linear map doing it." Thm 3.2 — "do-then-do = multiply: the matrix of $S\circ T$ is $[S][T]$, in that order." Flag: matrix product order reads right-to-left, like function composition.
- **Proof roadmaps:** Thm 3.1 — trick: *expand, push, and use uniqueness of coordinates.* (1) Any $v$ is $\sum a_i b_i$ in the basis; apply $T$ and push linearity through (Lemma 3.1). (2) Existence: *define* $T$ by that formula; check it's linear. (3) Well-definedness rests on each $v$ having exactly one coordinate list — pause and convince yourself of that fact (independence kills any second representation: subtract the two and use Def 2.1). Thm 3.2 — trick: *chase one basis vector, and let indices do the bookkeeping.* (1) First move: compute $(S\circ T)(e_j)$ by feeding $T$'s $j$-th column through $S$. (2) Middle: write $T(e_j)=\sum_k A_{kj} f_k$, then $S(f_k)=\sum_i B_{ik} g_i$; substitute and swap the finite sums. (3) The coefficient of $g_i$ is $\sum_k B_{ik}A_{kj}$ — recognize it as the $(i,j)$ entry of $BA$. Advice: keep a legend of which index runs over which basis; the proof is bookkeeping, not ideas.
- **Flashcards (7):** Q: The one defining property of a linear map? A: $T(au+bv) = aT(u)+bT(v)$ — respects mixing. / Q: What is column $j$ of the matrix of $T$? A: The coordinates of $T(\text{basis vector } j)$. / Q: How do you compute $Ax$ conceptually? A: Mix A's columns using x's entries as amounts. / Q: Why is a linear map determined by its values on a basis? A: Every vector expands uniquely in the basis; linearity pushes T through the expansion. / Q: Matrix of $S\circ T$? A: $[S][T]$ — product in composition order, applied right-to-left. / Q: What do grid pictures of linear maps always preserve? A: Straightness, parallelism, even spacing of grid lines, and the origin. / Q: Which earlier fact makes coordinates well-defined? A: Independence of the basis — two different coordinate lists would give a nontrivial relation.

Then the four standard steps:

- [ ] Step 1: Read `content/day03.md` fully.
- [ ] Step 2: Write `content/primers/day03.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 4: Primer Day 4 — Kernel, image, invertibility, rank-nullity

**Files:** Create: `content/primers/day04.md` (main file: `content/day04.md`)

**Brief:**

- **Warm-up:** Days 3, 2, 1.
- **Hook:** Project $\mathbb{R}^3$ flat onto the floor: $(x,y,z)\mapsto(x,y,0)$. Two questions with numbers: what gets crushed to zero? (the whole vertical line $(0,0,z)$ — 1 dimension); where can you land? (the floor — 2 dimensions). Notice $1+2=3$. Coincidence? Never: crushed + kept = total, always (rank-nullity). Follow-up: could ANY map from $\mathbb{R}^3$ to $\mathbb{R}^2$ be reversible? (No — something must be crushed; count dimensions.)
- **Pictures:** (1) The projection: vertical line collapsing to the origin dot, floor plane surviving. Labels: kernel (crushed), image (landing zone). (2) A pipe diagram: $n$ dimensions flow in, split into "lost" (nullity) and "delivered" (rank). (3) Invertible = perfect matchmaking: every input to a unique output, every output hit — no crush (injective), no miss (surjective).
- **Walkthrough & memory hooks:** Def 4.1 — "kernel = what gets crushed to 0; image = where you can actually land." Def 4.2 — "invertible = there's an exact undo; isomorphism = the two spaces are the same space wearing different clothes." Lemma 4.1 — "injective ⟺ only 0 is crushed" — slogan: "the kernel is the injectivity meter." Thm 4.1 (rank-nullity) — "conservation law: crushed + kept = total, $\dim\ker + \dim\mathrm{im} = \dim V$." Thm 4.2 — "for square (equal-dimension) maps, one virtue buys them all: injective ⟺ surjective ⟺ invertible."
- **Proof roadmaps:** Lemma 4.1 — trick: *difference detection.* (1) $T(u)=T(v) \iff T(u-v)=0 \iff u-v \in \ker T$. (2) So trivial kernel ⟺ no two inputs collide. Thm 4.1 — **the day's main event.** Trick: *build a basis in two installments: kernel first, then extend; the extension's images are a basis of the image.* (1) First move: take a basis $u_1..u_k$ of $\ker T$, extend to a basis $u_1..u_k, w_1..w_r$ of $V$ (this is exactly Day 2, Exercise 6's theorem — re-derive it if shaky, today leans on it). (2) Middle: show $T(w_1)..T(w_r)$ spans the image — apply $T$ to any expanded vector; kernel terms vanish. (3) Sketch: show they're independent — a relation $\sum c_iT(w_i)=0$ puts $\sum c_i w_i$ in the kernel, so it's a mix of $u$'s; independence of the full basis forces all $c_i=0$. Count: $k + r = \dim V$. Thm 4.2 — trick: *rank-nullity is a seesaw.* When $\dim V = \dim W = n$: injective ⟺ nullity 0 ⟺ rank $n$ ⟺ surjective; each equivalence is one glance at $n = \text{rank} + \text{nullity}$.
- **Flashcards (7):** Q: Define kernel and image. A: $\ker T = \{v: T(v)=0\}$; $\mathrm{im}\,T = \{T(v): v \in V\}$. / Q: Rank-nullity in one sentence? A: $\dim\ker T + \dim\mathrm{im}\,T = \dim V$ — crushed plus kept equals total. / Q: Injectivity test via kernel? A: Injective ⟺ $\ker T = \{0\}$. / Q: Why can't a map $\mathbb{R}^3 \to \mathbb{R}^2$ be invertible? A: Rank ≤ 2, so nullity ≥ 1 — something nonzero is crushed; not injective. / Q: For a map between equal-dimensional spaces, injective implies…? A: Surjective (and hence invertible) — rank-nullity seesaw. / Q: The proof skeleton of rank-nullity? A: Basis of kernel, extend to basis of V; images of the extension form a basis of the image. / Q: What earlier result does the rank-nullity proof silently need? A: Basis extension (Day 2, Exercise 6).

Then the four standard steps:

- [ ] Step 1: Read `content/day04.md` fully.
- [ ] Step 2: Write `content/primers/day04.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 5: Primer Day 5 — Gaussian elimination, row reduction, rank

**Files:** Create: `content/primers/day05.md` (main file: `content/day05.md`)

**Brief:**

- **Warm-up:** Days 4, 3, 1.
- **Hook:** Solve $x+y+z=6$, $2x+y+3z=13$, $x+2y+2z=11$ the high-school way (substitution) — feel the mess. Now the same system as a grid of numbers, cleaning one column at a time with three legal moves — mechanical, error-resistant, and it scales to 100 unknowns. Two questions today answers: why are the moves *legal* (they never change the solutions), and what does the leftover staircase tell you (rank = how many equations were real)?
- **Pictures:** (1) The staircase: an REF matrix with pivots boxed, zeros below, caption: each step = one genuinely new equation. (2) Row ops as reversible knobs: each move has an exact inverse move — that's WHY solutions are preserved. (3) Three planes intersecting in a point; row operations tilt the planes but the intersection point never moves.
- **Walkthrough & memory hooks:** Def 5.1 — "three legal moves: swap, scale by nonzero, add a multiple of another row — each one reversible." Def 5.2 — "REF = staircase; pivot = the step corner; rank = number of steps." Thm 5.1 — slogan: "cleanup never changes the answer set — because every move can be undone." Thm 5.2 — "everyone's staircase has the same number of steps: rank is a property of the matrix, not of your cleaning order."
- **Proof roadmaps:** Thm 5.1 — trick: *reversibility gives two-way containment.* (1) First move: show each operation maps solutions to solutions (plug in and check — do it for the "add a multiple" move, the other two are easier). (2) Middle: the inverse operation maps solutions back, so the two solution sets contain each other. (3) One case per move type; keep them separate and short. Thm 5.2 — trick: *rank is secretly the dimension of the row space.* (1) Each move replaces rows by combinations of rows — the row space never changes. (2) The nonzero rows of an REF are independent (look at pivot positions: each has a leading entry where later rows have zeros). (3) So any REF of $A$ has $\dim(\text{row space})$ nonzero rows — same count for every cleaning order.
- **Flashcards (7):** Q: The three elementary row operations? A: Swap two rows; multiply a row by a nonzero scalar; add a multiple of one row to another. / Q: Why do row operations preserve solutions? A: Each is reversible — solution sets map into each other both ways. / Q: Define rank via REF. A: The number of pivots (nonzero rows) in any row echelon form. / Q: Why is rank well-defined regardless of elimination order? A: Row ops preserve the row space; REF's nonzero rows are a basis of it. / Q: What does rank mean in plain terms? A: How many of the equations are genuinely independent (non-redundant). / Q: The three possible solution-set shapes for a linear system? A: Empty (inconsistent), one point, or infinitely many (free variables). / Q: What signals inconsistency in an augmented REF? A: A pivot in the constants column — a row saying 0 = nonzero.

Then the four standard steps:

- [ ] Step 1: Read `content/day05.md` fully.
- [ ] Step 2: Write `content/primers/day05.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 6: Primer Day 6 — The four fundamental subspaces

**Files:** Create: `content/primers/day06.md` (main file: `content/day06.md`)

**Brief:**

- **Warm-up:** Days 5, 4, 1.
- **Hook:** One small matrix, e.g. $A=\begin{pmatrix}1&2&3\\2&4&6\end{pmatrix}$ (rank 1) — and FOUR subspaces hiding inside it: what it can produce (column space), what it silences (null space), the same two for $A^T$. With numbers: $C(A)$ = the line through $(1,2)$; $N(A)$ = a plane in $\mathbb{R}^3$; check $1+2=3$ and $1+1=2$. Today is a synthesis day — no new machinery, just the full map of what Days 4–5 built.
- **Pictures:** (1) The "four rooms" diagram: domain $\mathbb{R}^n$ split into row space (dim $r$) + null space (dim $n-r$); codomain $\mathbb{R}^m$ split into column space (dim $r$) + left null space (dim $m-r$); arrows showing $A$ carries row space onto column space and kills the null space. (2) Rank as a bottleneck: whatever $A$ does, only $r$ dimensions survive the passage — and the SAME $r$ counts both row and column stories (Lemma 6.1). Note: perpendicularity of these pairs is real but arrives on Days 14–15 — draw the rooms adjacent, not perpendicular, and say so ("the right angles come later").
- **Walkthrough & memory hooks:** Def 6.1 — "one matrix, four shadows: $C(A)$ = everything $A$ can produce; $N(A)$ = everything $A$ silences; $C(A^T)$ = row space; $N(A^T)$ = left null space." **Pre-teach transpose** (the main file uses it structurally without a formal definition): $A^T$ = rows become columns; one 2×3 numeric instance; mention $(AB)^T = B^TA^T$ ("socks-shoes for transposes" — reversal appears because rows and columns trade roles) since Day 6 Ex 7 uses it. Lemma 6.1 — slogan: "rows and columns tell the same rank story — pivot count counts both." Thm 6.1 (FTLA part 1) — "the dimension ledger: $r + (n-r) = n$ in the domain, $r + (m-r) = m$ in the codomain."
- **Proof roadmaps:** Lemma 6.1 — **the day's one hard write-out.** Trick: *elimination doesn't change column DEPENDENCIES, because $Ax=0$ has the same solutions as $Rx=0$.* (1) First move: rank = pivot count = dim(row space) is Day 5's Thm 5.2. (2) Middle rung: to show pivot columns of the ORIGINAL $A$ are independent: any dependency among columns of $A$ is a solution of $Ax=0$, which is also a solution of $Rx=0$ — and $R$'s pivot columns are visibly independent. (3) Sketch: same solution-set argument shows non-pivot columns of $A$ are combinations of pivot columns — so pivot columns of $A$ form a basis of $C(A)$: $\dim C(A) = r$ too. Thm 6.1 — trick: *assembly, not invention:* rank-nullity (Day 4) gives $\dim N(A) = n - r$; apply everything to $A^T$ for the other pair.
- **Flashcards (7):** Q: Name the four fundamental subspaces of an $m\times n$ matrix and where each lives. A: $C(A)\subseteq\mathbb{R}^m$, $N(A)\subseteq\mathbb{R}^n$, $C(A^T)\subseteq\mathbb{R}^n$, $N(A^T)\subseteq\mathbb{R}^m$. / Q: All four dimensions in terms of $r, m, n$? A: $\dim C(A)=\dim C(A^T)=r$; $\dim N(A)=n-r$; $\dim N(A^T)=m-r$. / Q: Why does row rank equal column rank, in one sentence? A: Elimination preserves the solutions of $Ax=0$, hence preserves column dependencies — pivot columns of A are a basis of C(A). / Q: What is $A^T$ and the transpose product rule? A: Rows↔columns; $(AB)^T = B^TA^T$ (order reverses). / Q: What does $b \in C(A)$ mean for the system $Ax=b$? A: The system is consistent — b is producible. / Q: What's in $N(A^T)$, in words? A: Combinations of the ROWS that vanish — "left" because $y^TA=0$. / Q: Which day supplies the right angles between these pairs? A: Days 14–15 (orthogonal complements) — foreshadowed only, today is dimensions.

Then the four standard steps:

- [ ] Step 1: Read `content/day06.md` fully.
- [ ] Step 2: Write `content/primers/day06.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 7: Primer Day 8 — Determinants

**Files:** Create: `content/primers/day08.md` (main file: `content/day08.md`)

**Brief:**

- **Warm-up:** Days 6, 5, 1.
- **Hook:** Take $A=\begin{pmatrix}3&1\\1&2\end{pmatrix}$ and apply it to the unit square. The image is a parallelogram — compute its area by counting: it's $3\cdot 2 - 1\cdot 1 = 5$. One number that predicts everything about invertibility: if the area factor is 0, the square got flattened to a line segment — and you can't unflatten. Today: that number (the determinant), why the familiar formula is *forced* by three axioms about how volume must behave, and why $\det \ne 0 \iff$ invertible.
- **Pictures:** (1) Unit square → parallelogram with area factor labeled; a second matrix flattening the square to a segment (det = 0). (2) Row swap flipping orientation — the sign of det tracks "did the space get mirrored?" (3) The multiplicative picture: apply $B$ (scale volumes by $\det B$), then $A$ (scale by $\det A$) — total scaling $\det A \cdot \det B$ = why $\det(AB)=\det(A)\det(B)$ has to be true before any algebra.
- **Walkthrough & memory hooks:** Def 8.1 — "det is the volume-scaling factor with a sign; the axioms just say: volume is linear in each row, degenerate rows give zero, the unit cube has volume 1." Def 8.2 — "cofactor expansion = compute the volume one row at a time." Lemma 8.1 — "a zero row = a flattened box: volume 0." Def 8.3 / Lemma 8.3 — "elementary matrices are the three cleanup moves wearing matrix costumes; left-multiplying performs the move." Lemma 8.2 — "each move has a known volume effect: swap flips sign, scale scales, shear does NOTHING." (Shear-does-nothing is the day's most useful fact — say it twice.) Cor 8.1 + Thm 8.1 — "volume factors multiply." Lemma 8.5 — "triangular volume = product of the diagonal — the box is already axis-aligned-ish." Thm 8.2 — "flattened ⟺ volume 0 ⟺ no way back." Practical hook: to compute a det fast, row-reduce tracking swaps/scalings, then multiply the diagonal.
- **Proof roadmaps:** Lemma 8.2, swap case — trick (NOT discoverable — follow the ladder): *feed $u+v$ into a repeated-row slot and expand by linearity.* (1) First move: a matrix with two EQUAL rows has det 0 (degenerate axiom). (2) Middle: build the matrix with row $u+v$ in BOTH positions; expand by row-linearity in each slot — four terms, two of which are zero. (3) Sketch: the survivors say $\det(\dots u \dots v\dots) = -\det(\dots v \dots u \dots)$. Thm 8.1 — trick: *split by invertibility; invertible A is a product of elementary matrices (Day 9's Thm 9.2 idea appears here — the main file handles it; follow its case split).* (1) Singular case: both sides are 0 (rank argument). (2) Invertible case: write $A = E_1\cdots E_k$, peel one $E$ at a time with Cor 8.1. Lemma 8.5 — trick: *expand along the first column, induct on size.* Thm 8.2 — trick: *row-reduce; each move multiplies det by a NONZERO factor, so det-zero-ness never changes; at REF, det = product of diagonal ⟺ full rank.*
- **Flashcards (8):** Q: The three determinant axioms, informally? A: Linear in each row; zero when degenerate (equal/zero rows); det(I) = 1. / Q: Effect of the three row ops on det? A: Swap → ×(−1); scale row by c → ×c; add multiple of another row → unchanged. / Q: Which row op is "free" and why does it matter? A: Shear (add multiple of a row) — so you can row-reduce and just track swaps/scalings. / Q: det of a triangular matrix? A: Product of the diagonal entries. / Q: det(AB)? A: det(A)·det(B) — volume factors multiply. / Q: Geometric meaning of det = 0? A: The unit cube is flattened to lower dimension — the map is not invertible. / Q: What does the SIGN of det track? A: Orientation — whether the space got mirrored. / Q: Fastest hand method for a 3×3+ det? A: Row-reduce to triangular tracking swap signs and scalings, multiply the diagonal.

Then the four standard steps:

- [ ] Step 1: Read `content/day08.md` fully.
- [ ] Step 2: Write `content/primers/day08.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 8: Primer Day 9 — Invertibility, inverse, LU

**Files:** Create: `content/primers/day09.md` (main file: `content/day09.md`)

**Brief:**

- **Warm-up:** Days 8, 6, 2.
- **Hook:** You must solve $Ax=b$ for the SAME $A$ but 1000 different $b$'s (this is what real computation looks like). Re-running elimination 1000 times is waste: the cleanup moves depend only on $A$. Two fixes today: (a) compute $A^{-1}$ once ("the exact undo"); (b) even better, keep the *receipt* of elimination — $A = LU$ — and replay it cheaply per $b$. Warm-up puzzle: to undo "put on socks, then shoes," what order do you undo in? That's $(AB)^{-1} = B^{-1}A^{-1}$.
- **Pictures:** (1) $[A \mid I] \to [I \mid A^{-1}]$: the same moves that kill $A$ into $I$, applied to a tag-along $I$, BUILD $A^{-1}$ — show why in one line: the moves are $E_k\cdots E_1$, and applying them to both sides gives $E_k\cdots E_1 A = I$, so $E_k\cdots E_1 = A^{-1}$, which is exactly what the right half accumulates. (2) LU as a receipt: $U$ = the cleaned staircase, $L$ = the multipliers used, stored below the diagonal in the exact spots they eliminated. (3) Socks-shoes diagram for inverse of a product.
- **Walkthrough & memory hooks:** Def 9.1 — "the inverse is the exact undo; only square matrices can have one, and not all do." Def 9.2 / Lemma 9.1 — "same elementary-matrix idea as Day 8 — déjà vu is intentional, move fast here." Thm 9.1 — "undo is unique; undo of do-then-do is undo-then-undo, reversed (socks & shoes)." Lemma 9.2 — "every cleanup move is undoable by a cleanup move of the same type." Thm 9.2 — "invertible = reachable from I by cleanup moves." Lemma 9.3 + Thm 9.3 — "elimination without swaps, written as algebra: $A = LU$, L = the memory of the multipliers." Practical hook: solve $LUx=b$ by two triangular sweeps (forward, then back) — never form $A^{-1}$ in practice.
- **Proof roadmaps:** Thm 9.1 uniqueness — trick: *sandwich:* if $B$ and $C$ both invert $A$, evaluate $BAC$ two ways: $B(AC) = BI = B$ and $(BA)C = IC = C$. Product rule: verify $(B^{-1}A^{-1})(AB) = I$ directly — the middle collapses first. Thm 9.2 — trick: *row-reduce A to I (possible iff invertible — rank argument), record the moves, then invert the equation $E_k\cdots E_1A = I$.* Lemma 9.3 — trick: *don't fear the index chase; ask one question per entry: which products can land BELOW the diagonal?* (1) First move: compute the $(i,j)$ entry of a product of two unit lower-triangular matrices as $\sum_k L_{ik}M_{kj}$; note $L_{ik} \ne 0$ needs $k \le i$ and $M_{kj} \ne 0$ needs $j \le k$. (2) Middle: diagonal entries come only from $k=i=j$: product of two 1's = 1. (3) Inverse: induct or solve $LX = I$ column by column with forward substitution. Thm 9.3 — trick: *each elimination step is left-multiplication by a unit lower elementary matrix; collect them, invert the collection (stays unit lower by Lemma 9.3), name it L.*
- **Flashcards (7):** Q: $(AB)^{-1}$? A: $B^{-1}A^{-1}$ — socks & shoes: undo in reverse order. / Q: Why does Gauss-Jordan on $[A|I]$ produce $A^{-1}$? A: The right half accumulates $E_k\cdots E_1$, and $E_k\cdots E_1 A = I$ means that product IS $A^{-1}$. / Q: What do L and U store in A = LU? A: U = the eliminated (upper) result; L = the multipliers used, in the positions they eliminated. / Q: Why is LU better than $A^{-1}$ for many right-hand sides? A: Two cheap triangular solves per b; no inverse ever formed (faster, numerically safer). / Q: Can a non-square matrix be invertible? A: No — rank-nullity forces a crushed direction or a missed one. / Q: Is the inverse unique? Proof idea? A: Yes — sandwich BAC two ways. / Q: When does A = LU without row swaps exist? A: When elimination never needs a swap (all pivots appear without exchanging rows).

Then the four standard steps:

- [ ] Step 1: Read `content/day09.md` fully.
- [ ] Step 2: Write `content/primers/day09.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 9: Primer Day 10 — Eigenvalues and eigenvectors

**Files:** Create: `content/primers/day10.md` (main file: `content/day10.md`)

**Brief:**

- **Warm-up:** Days 9, 8, 3.
- **Hook:** Apply $A=\begin{pmatrix}3&1\\0&2\end{pmatrix}$ to a few vectors and repeat: most directions drift and turn under repeated application. But feed it $(1,0)$: you get $(3,0)$, then $(9,0)$ — the direction never changes, only the length (×3 each time). Find the other such direction by experiment: $(1,-1) \mapsto (2,-2)$ — stretch ×2. Two special directions tame the whole matrix: on them, $A$ is just a number. Today: how to FIND them without guessing — turn the vector search into root-finding.
- **Pictures:** (1) A fan of arrows before/after $A$: generic arrows rotate; the two eigendirections stay on their own lines (one stretching ×3, one ×2). (2) The shear $\begin{pmatrix}1&1\\0&1\end{pmatrix}$: only ONE eigendirection — some matrices don't have enough (Day 11's cliffhanger, flag it as a teaser). (3) The rotation matrix: NO real eigendirection — every arrow turns (complex eigenvalues exist, teaser for the exercises).
- **Walkthrough & memory hooks:** Def 10.1 — "an eigenvector is a direction $A$ doesn't turn; the eigenvalue is the stretch factor." Etymology: *eigen* = German "own" — $A$'s own directions. Def 10.2 — "the characteristic polynomial is the det-test with a dial: $p(\lambda) = \det(A - \lambda I)$." Thm 10.1 — slogan: "**vector search → root finding**: $\lambda$ is an eigenvalue ⟺ $\det(A-\lambda I)=0$." Show the chain in words BEFORE symbols: eigenvector exists ⟺ $(A-\lambda I)v = 0$ has a nonzero solution ⟺ $A - \lambda I$ singular ⟺ det = 0 (Day 8's Thm 8.2 — this is why determinants came first). Thm 10.2 — "different stretch factors ⇒ automatically independent directions — no check needed."
- **Proof roadmaps:** Thm 10.1 — trick: *chain three known equivalences; nothing new is invented.* (1) Rewrite $Av = \lambda v$ as $(A-\lambda I)v = 0$, $v \ne 0$. (2) Nonzero kernel ⟺ singular (Day 4 Lemma 4.1 + Day 4 Thm 4.2). (3) Singular ⟺ det = 0 (Day 8 Thm 8.2). Thm 10.2 — trick (the day's clever one — follow the ladder): *minimal counterexample + "apply A vs. multiply by λ, then subtract."* (1) First move: suppose a smallest dependent set of eigenvectors for distinct eigenvalues; write the dependence $\sum c_i v_i = 0$ with all $c_i \ne 0$ (why can you assume that? minimality). (2) Middle: hit the relation with $A$ (each term picks up ITS OWN $\lambda_i$); separately multiply the original relation by $\lambda_k$ (one fixed eigenvalue); subtract — the $v_k$ term cancels. (3) Sketch: the survivors form a SHORTER dependence with coefficients $c_i(\lambda_i - \lambda_k) \ne 0$ (distinctness!) — contradicting minimality.
- **Flashcards (8):** Q: Define eigenvalue/eigenvector precisely. A: $Av = \lambda v$ with $v \ne 0$. / Q: Why the $v \ne 0$ requirement? A: $v=0$ satisfies the equation for every λ — it carries no information. / Q: The three-step chain behind "eigenvalues = roots of det(A−λI)"? A: Nonzero solution ⟺ nonzero kernel ⟺ singular ⟺ det zero. / Q: Eigen-etymology memory hook? A: German "eigen" = "own" — the matrix's own directions. / Q: Can a real matrix have no real eigenvalues? Example? A: Yes — rotations; every direction turns. / Q: Eigenvectors for distinct eigenvalues are…? A: Automatically linearly independent (Thm 10.2). / Q: The subtraction trick in Thm 10.2's proof? A: Apply A to the relation, multiply the relation by λ_k, subtract — one vector cancels, contradiction with minimality. / Q: Where do eigenvalues of a triangular matrix sit? A: On the diagonal (det of triangular = product of diagonal).

Then the four standard steps:

- [ ] Step 1: Read `content/day10.md` fully.
- [ ] Step 2: Write `content/primers/day10.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 10: Primer Day 11 — Diagonalization, multiplicities

**Files:** Create: `content/primers/day11.md` (main file: `content/day11.md`)

**Brief:**

- **Warm-up:** Days 10, 9, 4.
- **Hook:** Compute $A^{100}$ for $A=\begin{pmatrix}4&1\\2&3\end{pmatrix}$. Directly: hopeless. But $A$ has eigenpairs $\lambda=5$ at $(1,1)$ and $\lambda=2$ at $(1,-2)$ (verify by multiplying!). In the coordinate system OF THOSE DIRECTIONS, $A$ is just $\mathrm{diag}(5,2)$, and $A^{100}$ is $\mathrm{diag}(5^{100},2^{100})$. Today: when can you switch to eigen-coordinates entirely ($A = PDP^{-1}$), and what goes wrong when a matrix doesn't have enough eigendirections (the shear from Day 10's picture).
- **Pictures:** (1) The change-of-glasses pipeline: $P^{-1}$ (translate into eigen-language) → $D$ (pure scaling) → $P$ (translate back); caption: $A = PDP^{-1}$ = "same map, better glasses." (2) The defective shear: only one eigendirection — you can't build a full grid out of one direction; caption: diagonalizable needs a FULL BASIS of eigenvectors. (3) Multiplicity budget bars per eigenvalue: algebraic (root count) as the budget ceiling, geometric (eigenspace dim) as what's actually delivered; diagonalizable ⟺ every bar filled to its ceiling.
- **Walkthrough & memory hooks:** Def 11.1 — "algebraic multiplicity = how many times the root appears; geometric = how many independent directions it actually delivers." Def 11.2 — "similar = same map in different glasses; diagonalizable = there exist glasses in which A is pure scaling." Thm 11.1 — "glasses don't change the physics: similar matrices share char. poly, eigenvalues, trace, det." Thm 11.2 — "diagonalizable ⟺ n independent eigendirections; the columns of P ARE the eigenvectors." Lemma 11.1 — "delivery never exceeds budget: geometric ≤ algebraic." Lemma 11.2 + Cor 11.1 — "eigenspaces for different eigenvalues don't overlap and stack independently — total delivery = sum of geometrics." Thm 11.3 — "diagonalizable ⟺ every eigenvalue delivers its full quota (all real roots, geometric = algebraic)." Trap to plant early: distinct eigenvalues ⇒ diagonalizable is SUFFICIENT, never necessary ($I$ has one eigenvalue, fully diagonal).
- **Proof roadmaps:** Thm 11.1 — trick: *slide $P^{-1}, P$ through the det:* $\det(P^{-1}AP - \lambda I) = \det(P^{-1}(A-\lambda I)P)$ — factor $\lambda I = P^{-1}(\lambda I)P$ first — then multiplicativity kills the P's. Thm 11.2 — trick: *read $AP = PD$ column by column: column $j$ says $Ap_j = d_j p_j$.* Both directions are that one observation plus "P invertible ⟺ columns form a basis." Lemma 11.1 — **hardest of the day; follow the ladder.** Trick: *extend an eigenspace basis and look at the block shape.* (1) First move: take a basis $v_1..v_g$ of the λ₀-eigenspace, extend to a basis of the whole space (Day 2 again), and form $P$ with those columns. (2) Middle: compute $P^{-1}AP$: its first $g$ columns are $\lambda_0 e_j$ — the top-left block is $\lambda_0 I_g$; shape: $\begin{pmatrix}\lambda_0 I_g & *\\ 0 & C\end{pmatrix}$. (3) Sketch: char. poly of a block-upper-triangular matrix factors as (top block)·(bottom block) — the main file leans on Day 8 here but Day 8 proved only the ENTRYWISE triangular case; the primer should give the honest two-line patch: expand $\det$ along the first $g$ columns, or accept the block fact as today's one IOU and verify it on a 3×3 with $g=1$. Then $(\lambda_0-\lambda)^g$ divides the char. poly, so $g \le a$. Cor 11.1 — trick: *stack the eigenspace bases; Lemma 11.2 says no cross-eigenvalue relation can exist (a relation would be a dependence between eigenvectors of distinct eigenvalues — Thm 10.2's territory).*
- **Flashcards (8):** Q: A = PDP⁻¹ — what are P and D, exactly? A: P's columns = n independent eigenvectors; D = diagonal of matching eigenvalues, same order. / Q: Similar matrices share what? A: Characteristic polynomial — hence eigenvalues, trace, determinant (NOT eigenvectors: those transform by P). / Q: Geometric vs algebraic multiplicity — inequality and slogan? A: g ≤ a; "delivery never exceeds budget." / Q: Diagonalizability criterion (full version)? A: Char. poly splits over ℝ AND geometric = algebraic for every eigenvalue. / Q: Is "n distinct eigenvalues" necessary for diagonalizability? A: No — sufficient only (identity matrix: one eigenvalue, diagonal). / Q: Classic non-diagonalizable matrix? A: The shear [[1,1],[0,1]]: a=2, g=1 for λ=1. / Q: Why compute A¹⁰⁰ via PDP⁻¹? A: Aᵏ = PDᵏP⁻¹ — the inner P⁻¹P pairs telescope away. / Q: First move to prove g ≤ a? A: Basis of the eigenspace, extend to full basis, conjugate — read off the block-triangular shape.

Then the four standard steps:

- [ ] Step 1: Read `content/day11.md` fully.
- [ ] Step 2: Write `content/primers/day11.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 11: Primer Day 12 — Diagonalization applications

**Files:** Create: `content/primers/day12.md` (main file: `content/day12.md`)

**Brief:**

- **Warm-up:** Days 11, 10, 5.
- **Hook:** Fibonacci: 1, 1, 2, 3, 5, 8, … What is $F_{50}$ — without doing 50 additions? Trick: stack memory into a state vector $\binom{F_{n+1}}{F_n}$; one step of the recurrence is ONE matrix multiplication by $\begin{pmatrix}1&1\\1&0\end{pmatrix}$. So $F_{50}$ lives inside a matrix POWER — and Day 11 made powers trivial. Bonus: the eigenvalues are $\varphi = (1+\sqrt5)/2$ and its conjugate — the golden ratio was hiding inside the addition rule all along (Binet's formula).
- **Pictures:** (1) The pipeline again, now with n: $A^n = PD^nP^{-1}$ — translate once, scale n times, translate back. (2) Dominant-eigenvalue takeover: iterate a random starting vector; arrows swing toward the top eigendirection because $|\lambda_1|^n$ outruns everything — caption: long-run behavior = largest |λ| wins, direction = its eigenvector. (3) Recurrence-to-matrix: the "shift register" picture of stacking $F_{n+1}, F_n$ into a state.
- **Walkthrough & memory hooks:** Thm 12.1 — "power the pieces, not the matrix: $A^n = PD^nP^{-1}$, because the inner $P^{-1}P$'s telescope." Technique hook (recurrences): "any linear recurrence becomes a matrix by stacking a window of history into a state vector." Long-run hook: "|λ|>1 grows, |λ|<1 dies, |λ|=1 persists or oscillates — read the fate of a system off its spectrum." This day is deliberately light: consolidation + payoff; spend the spare energy on Day 11's leftovers.
- **Proof roadmaps:** Thm 12.1 — trick: *induction where the inductive step is one telescoping cancellation:* $A^{n+1} = A\cdot A^n = (PDP^{-1})(PD^nP^{-1})$ — the middle collapses. Base case n = 1 is the definition.
- **Flashcards (6):** Q: Formula for Aⁿ when A = PDP⁻¹? A: Aⁿ = PDⁿP⁻¹ — inner pairs telescope. / Q: How do you matrix-ify a recurrence like $F_{n+1} = F_n + F_{n-1}$? A: State vector of a history window: $\binom{F_{n+1}}{F_n} = \begin{pmatrix}1&1\\1&0\end{pmatrix}\binom{F_n}{F_{n-1}}$. / Q: Long-run fate of $A^n x$ (diagonalizable, one dominant λ)? A: Aligns with the dominant eigenvector, grows/decays like $\lambda_1^n$. / Q: What decides growth vs decay vs oscillation? A: |λ| vs 1 (and sign/complexity of λ for oscillation). / Q: Where does the golden ratio enter Fibonacci? A: It's the dominant eigenvalue of the Fibonacci matrix — Binet's formula. / Q: Why is computing PDⁿP⁻¹ cheap? A: Powering a diagonal matrix = powering n scalars.

Then the four standard steps:

- [ ] Step 1: Read `content/day12.md` fully.
- [ ] Step 2: Write `content/primers/day12.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 12: Primer Day 14 — Inner products, norms, Cauchy-Schwarz

**Files:** Create: `content/primers/day14.md` (main file: `content/day14.md`)

**Brief:**

- **Warm-up:** Days 12, 11, 6.
- **Hook:** Two users rate 3 movies: $u = (5,3,1)$, $v = (4,4,2)$. How SIMILAR are their tastes, as one number? Compute $\langle u,v \rangle = 5\cdot4+3\cdot4+1\cdot2 = 34$, $\|u\| = \sqrt{35}$, $\|v\| = 6$; the ratio $34/(6\sqrt{35}) \approx 0.958$ — nearly parallel tastes. This ratio is $\cos\theta$… but wait: who promised that ratio is always between −1 and 1? Nobody obvious — that's the Cauchy-Schwarz inequality, and it's today's main theorem, not a triviality.
- **Pictures:** (1) Dot product as shadow: $\langle u,v\rangle = \|u\|\,\|v\|\cos\theta$ — the shadow of one arrow on the other, times lengths. (2) Cauchy-Schwarz as "the shadow never exceeds the arrow." (3) Triangle inequality: the detour $u$ then $v$ is never shorter than the straight shot $u+v$. (4) Parallelogram law: the two diagonals' squares vs. the four sides' squares — the litmus test a norm must pass to secretly come from an inner product.
- **Walkthrough & memory hooks:** Def 14.1 — "an inner product is a length-and-angle machine: symmetric, linear in each slot, positive on nonzero vectors. The dot product is one such machine; today's axioms describe EVERY such machine." Def 14.2 — "norm = length manufactured from the machine: $\|v\| = \sqrt{\langle v,v\rangle}$." Thm 14.1 (Cauchy-Schwarz) — slogan: "$|\langle u,v\rangle| \le \|u\|\|v\|$ — shadows don't out-length arrows; equality ⟺ parallel." Thm 14.2 — "detours never shorten." Thm 14.3 — "the parallelogram identity is the fingerprint of inner-product-ness."
- **Proof roadmaps:** Thm 14.1 — **the discriminant trick is famous and NOT inventable; learn it as a pattern.** (1) First move: the quadratic $q(t) = \|u + tv\|^2$ is ≥ 0 for ALL real t — expand it into $\|v\|^2t^2 + 2\langle u,v\rangle t + \|u\|^2$. (2) Middle rung: a quadratic that never goes negative has discriminant ≤ 0 — write that out. (3) Sketch: the discriminant inequality IS Cauchy-Schwarz after dividing by 4 and taking a square root; equality ⟺ q has a real root ⟺ $u = -tv$ (parallel). Thm 14.2 — trick: *square both sides and let C-S eat the cross term:* expand $\|u+v\|^2$, bound $2\langle u,v\rangle \le 2\|u\|\|v\|$, recognize $(\|u\|+\|v\|)^2$. Thm 14.3 — trick: *expand both diagonals and watch the cross terms cancel.*
- **Flashcards (7):** Q: The three inner-product axioms? A: Symmetry; linearity in each argument; positive definiteness (⟨v,v⟩ > 0 for v ≠ 0). / Q: Cauchy-Schwarz statement + equality case? A: |⟨u,v⟩| ≤ ‖u‖‖v‖, equality iff u, v parallel. / Q: The C-S proof in one move? A: ‖u+tv‖² ≥ 0 for all t ⇒ discriminant of that quadratic ≤ 0. / Q: Why does C-S license defining angles? A: It guarantees ⟨u,v⟩/(‖u‖‖v‖) ∈ [−1,1], so it IS a cosine. / Q: Triangle inequality proof skeleton? A: Square, expand, apply C-S to the cross term, factor. / Q: What is the parallelogram law FOR? A: Litmus test — a norm satisfying it comes from an inner product; one failing it (e.g. max-norm) does not. / Q: Define the norm induced by an inner product. A: ‖v‖ = √⟨v,v⟩.

Then the four standard steps:

- [ ] Step 1: Read `content/day14.md` fully.
- [ ] Step 2: Write `content/primers/day14.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 13: Primer Day 15 — Orthogonal complements, Gram-Schmidt

**Files:** Create: `content/primers/day15.md` (main file: `content/day15.md`)

**Brief:**

- **Warm-up:** Days 14, 12, 8.
- **Hook:** You have a tilted plane $W$ in $\mathbb{R}^3$ spanned by the messy pair $(1,1,0)$ and $(1,0,1)$ — usable, but every computation with them drags cross-terms around. Goal: a "square grid" for the same plane — two perpendicular unit vectors. Method, feel it with numbers: keep the first vector; from the second, SUBTRACT ITS SHADOW on the first (compute it: shadow $= \frac{1}{2}(1,1,0)$, leftover $(\frac12,-\frac12,1)$ — check it's ⊥ to $(1,1,0)$); normalize both. That subtraction-of-shadows loop is Gram-Schmidt, and it works in any inner-product space.
- **Pictures:** (1) Floor-and-pole: $W$ = the floor, $W^\perp$ = the vertical pole; every vector = its floor shadow + its pole part, uniquely. (2) The G-S step: $v_2$ minus its shadow on $q_1$ leaves the genuinely-new perpendicular part. (3) Dimension bookkeeping: $\dim W + \dim W^\perp = n$ — the floor and pole dimensions always total the room.
- **Walkthrough & memory hooks:** Def 15.1 — "$W^\perp$ = everything at right angles to ALL of $W$." Lemma 15.1 — "the perpendicular world is itself a subspace." Def 15.2 — "orthonormal = perpendicular unit vectors: the square grid." Thm 15.1 — slogan: "**every vector splits uniquely: shadow on W + perpendicular leftover** ($V = W \oplus W^\perp$)." Thm 15.2 (Gram-Schmidt) — slogan: "keep what's new: subtract the shadows on everything so far, normalize, repeat." **Reading-order note (structural fix from the 2026-08-04 review):** the main file proves Thm 15.1 USING Thm 15.2, which appears after it. Instruct the learner: read BOTH statements first; attempt Gram-Schmidt's proof first (it's self-contained), then 15.1's — in that order the write-before-check protocol works.
- **Proof roadmaps:** Thm 15.2 (G-S) — trick: *induction where each step is the same two checks.* (1) First move: define $w_k = v_k - \sum_{i<k}\langle v_k, q_i\rangle q_i$ (subtract all shadows). (2) Middle: check $\langle w_k, q_j\rangle = 0$ for $j < k$ — the sum telescopes to $\langle v_k,q_j\rangle - \langle v_k,q_j\rangle$ because the $q_i$ are already orthonormal. (3) Sketch: $w_k \ne 0$ because $v_k \notin \mathrm{span}(v_1..v_{k-1})$ (independence of the input); normalize; spans match at every stage. Thm 15.1 — trick: *existence by construction, uniqueness by the zero-overlap.* (1) Build an orthonormal basis $q_1..q_k$ of $W$ (G-S — now legal); define the shadow of $v$ as $\sum \langle v,q_i\rangle q_i$ and check the leftover is ⊥ to each $q_i$. (2) Uniqueness: two decompositions differ by a vector in $W \cap W^\perp$. (3) But anything in both is ⊥ to itself: $\langle x,x\rangle = 0 \Rightarrow x = 0$.
- **Flashcards (7):** Q: Define $W^\perp$. A: All vectors orthogonal to every vector of W. / Q: The orthogonal decomposition theorem in one sentence? A: Every v splits uniquely as w + w' with w ∈ W, w' ∈ W⊥. / Q: Why is the decomposition UNIQUE? A: A difference of two would lie in W ∩ W⊥ = {0} (only 0 is ⊥ to itself). / Q: The Gram-Schmidt step, in words? A: New vector minus its shadows on all previous q's; normalize what's left. / Q: Why is the G-S leftover never zero? A: The inputs are independent — v_k isn't in the span of its predecessors. / Q: Formula for the shadow (projection) of v on an orthonormal basis of W? A: Σ ⟨v,qᵢ⟩ qᵢ. / Q: dim W + dim W⊥ = ? A: n (dim V) — floor plus pole fills the room.

Then the four standard steps:

- [ ] Step 1: Read `content/day15.md` fully.
- [ ] Step 2: Write `content/primers/day15.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 14: Primer Day 16 — Orthogonal projections, least squares

**Files:** Create: `content/primers/day16.md` (main file: `content/day16.md`)

**Brief:**

- **Warm-up:** Days 15, 14, 9.
- **Hook:** Fit a straight line through the points $(0,1), (1,3), (2,4)$. Write the three "equations" $b = 1$, $m + b = 3$, $2m + b = 4$: three equations, two unknowns, NO exact solution (check: the first two force $m=2, b=1$, the third then reads $5 = 4$ — false). Reframe: $Ax = b$ has no solution because $b$ isn't in $A$'s column space — so aim for the CLOSEST point of the column space instead. Closest = perpendicular drop = projection. This is linear regression, derived from Day 15's floor-and-shadow picture.
- **Pictures:** (1) $b$ floating above the plane $C(A)$; its shadow $p$; the error $e = b - p$ as the vertical drop — caption: least squares = drop the perpendicular. (2) Right triangle for the Best Approximation Theorem: to any other candidate $w$, the path from b is hypotenuse — longer (Pythagoras). (3) Normal-equations picture: the error must be ⊥ to EVERY column of A simultaneously — that's the system $A^T(b - A\hat x) = 0$.
- **Walkthrough & memory hooks:** Def 16.1 — "the projection of v onto W is its shadow: the unique W-part from Day 15's split." Lemma 16.1 — "Pythagoras still runs the show: perpendicular parts add in squares." Lemma 16.2 — "the leftover is ⊥ to the whole floor." Thm 16.1 — slogan: "**the shadow beats every other candidate** — nearest point = foot of the perpendicular." Thm 16.2 — slogan: "**make the error invisible to every column**: $A^TA\hat x = A^Tb$." **Prerequisite patch (from the 2026-08-04 review):** Thm 16.2 leans on $C(A)^\perp = N(A^T)$, which the main file attributes incorrectly; the primer supplies the honest 3-line argument: $y \perp$ every column of $A$ ⟺ every column's inner product with $y$ is 0 ⟺ $A^Ty = 0$ — read it here, then the theorem's step is transparent. Payoff hook: this is the FTLA right angle Day 6 promised.
- **Proof roadmaps:** Thm 16.1 — trick: *insert-and-Pythagoras.* (1) For any competitor $w \in W$: $b - w = (b - p) + (p - w)$ — first part ⊥ W, second part inside W. (2) Pythagoras: $\|b-w\|^2 = \|b-p\|^2 + \|p-w\|^2 \ge \|b-p\|^2$. (3) Equality ⟺ $w = p$: uniqueness free of charge. Thm 16.2 — trick: *translate "error ⊥ column space" into matrix language.* (1) $\hat x$ minimizes ⟺ $A\hat x = p$ (projection) ⟺ $b - A\hat x \perp C(A)$ (Thm 16.1 + Lemma 16.2). (2) Apply the 3-line fact above: $A^T(b - A\hat x) = 0$. (3) Rearrange: $A^TA\hat x = A^Tb$. Also preview why $A^TA$ is invertible when A has independent columns ($A^TAx = 0 \Rightarrow \|Ax\|^2 = x^TA^TAx = 0$).
- **Flashcards (7):** Q: Least squares in one geometric sentence? A: Project b onto the column space — the closest achievable point is the foot of the perpendicular. / Q: The normal equations? A: $A^TA\hat x = A^Tb$. / Q: Why "normal"? A: Normal = perpendicular — they say the residual is ⊥ to every column. / Q: State $C(A)^\perp = N(A^T)$ in words + 1-line why. A: What's ⊥ to everything A produces is exactly what A^T kills; ⟨column, y⟩ = 0 for all columns ⟺ A^Ty = 0. / Q: Best Approximation proof trick? A: Insert the projection: b−w = (b−p)+(p−w), Pythagoras, drop a nonneg term. / Q: When is $A^TA$ invertible? A: Iff A's columns are independent (A^TAx=0 ⇒ ‖Ax‖²=0 ⇒ x ∈ N(A) = {0}). / Q: What everyday method is this whole day? A: Linear regression — fitting by minimizing squared errors.

Then the four standard steps:

- [ ] Step 1: Read `content/day16.md` fully.
- [ ] Step 2: Write `content/primers/day16.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 15: Primer Day 17 — Orthogonal matrices, QR decomposition

**Files:** Create: `content/primers/day17.md` (main file: `content/day17.md`)

**Brief:**

- **Warm-up:** Days 16, 15, 10.
- **Hook:** Which matrices are perfectly RIGID — moving space without stretching, squashing, or bending, like rotating a photograph? Test drive: the rotation $Q=\begin{pmatrix}\cos\theta&-\sin\theta\\\sin\theta&\cos\theta\end{pmatrix}$ — check $\|Qx\| = \|x\|$ on one vector, then notice $Q^TQ = I$ (verify by multiplying!). "Transpose is the undo" is the fingerprint of rigidity. Second act: package Day 15's Gram-Schmidt as a REUSABLE factorization $A = QR$ — same idea as LU ("keep the receipt"), but the receipt of straightening instead of eliminating.
- **Pictures:** (1) Rigid motion: grid rotates as a whole, no distortion — lengths and angles all preserved. (2) $A = QR$ anatomy: Q's columns = the straightened (orthonormal) directions; R = upper-triangular receipt — entry $(i,j)$ = how much of $q_i$ was inside the original $a_j$; upper-triangular BECAUSE $a_j$ only ever involved $q_1..q_j$. (3) Why QR beats normal equations numerically (teaser for the lab): squaring a matrix squares its error-amplification.
- **Walkthrough & memory hooks:** Def 17.1 — "orthogonal matrix = orthonormal columns = $Q^TQ = I$ = transpose is the inverse. Naming gripe to remember it by: they should be called 'orthonormal matrices' — the columns are orthoNORMAL." Thm 17.1 — slogan: "**rigid ⟺ orthonormal columns**: preserving inner products, lengths, and angles are all the same demand." Thm 17.2 — slogan: "QR = Gram-Schmidt with the receipt kept" — R records the shadows subtracted, so $A$ reassembles as $QR$. Practical hook: with QR, least squares becomes $R\hat x = Q^Tb$ — one rigid rotation, one back-substitution, no $A^TA$ ever formed.
- **Proof roadmaps:** Thm 17.1 — trick: *one identity does the heavy direction:* $\langle Qx, Qy\rangle = x^TQ^TQy$. (1) If $Q^TQ = I$, inner products survive automatically. (2) Converse: assume preservation, test on basis pairs $e_i, e_j$ — the equations $\langle Qe_i, Qe_j\rangle = \delta_{ij}$ say exactly "columns orthonormal." Thm 17.2 — trick: *run G-S on A's columns and TRANSCRIBE.* (1) G-S gives orthonormal $q_1..q_n$ with $\mathrm{span}(q_1..q_j) = \mathrm{span}(a_1..a_j)$. (2) Express each $a_j$ back in the q-basis: $a_j = \sum_{i\le j} r_{ij}q_i$ — coefficients above the diagonal only. (3) Stack those expressions as columns: that IS $A = QR$; $r_{jj} \ne 0$ ⟺ columns independent.
- **Flashcards (7):** Q: Three equivalent definitions of an orthogonal matrix? A: Orthonormal columns; QᵀQ = I; Q⁻¹ = Qᵀ. / Q: What do orthogonal matrices preserve? A: Inner products — hence lengths and angles: rigid motions (rotations/reflections). / Q: det of an orthogonal matrix? A: ±1 (+1 rotation, −1 reflection). / Q: What is R in A = QR, in words? A: The Gram-Schmidt receipt: rᵢⱼ = how much of qᵢ was in aⱼ; upper-triangular since aⱼ uses only q₁..qⱼ. / Q: Least squares via QR? A: R x̂ = Qᵀb — rotate rigidly, back-substitute; avoids forming AᵀA. / Q: Why avoid AᵀA numerically? A: Conditioning squares: κ(AᵀA) = κ(A)² — error amplification blows up. / Q: Eigenvalue magnitudes of an orthogonal matrix? A: All |λ| = 1 — rigid maps can't stretch any direction.

Then the four standard steps:

- [ ] Step 1: Read `content/day17.md` fully.
- [ ] Step 2: Write `content/primers/day17.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 16: Primer Day 19 — Symmetric matrices, Spectral Theorem

**Files:** Create: `content/primers/day19.md` (main file: `content/day19.md`)

**Brief:**

- **Warm-up:** Days 17, 16, 11.
- **Hook:** Day 11 left scars: matrices can have complex eigenvalues, or too few eigenvectors (the shear). Now meet the perfect citizens: SYMMETRIC matrices ($A = A^T$ — and they're everywhere: covariance matrices, quadratic forms, anything of the form $B^TB$). Experiment first: take $A=\begin{pmatrix}2&1\\1&2\end{pmatrix}$ — eigenvalues 3 and 1 (real!), eigenvectors $(1,1)$ and $(1,-1)$ — PERPENDICULAR (check the dot product!). Today's theorem: that always happens. Every symmetric matrix has real eigenvalues, perpendicular eigendirections, and a full diagonalization $A = Q\Lambda Q^T$ with a RIGID $Q$.
- **Pictures:** (1) The ellipse picture: a symmetric matrix maps the unit circle to an ellipse whose axes ARE the eigenvectors — perpendicular by nature. (2) $A = Q\Lambda Q^T$ as rotate → scale along axes → rotate back (compare Day 11's $PDP^{-1}$: now the glasses are rigid, $P^{-1} = P^T$). (3) Contrast panel: the shear (defective) vs. any symmetric matrix (always a full perpendicular set) — symmetry heals both Day 11 diseases.
- **Walkthrough & memory hooks:** Def 19.1 — "symmetric = mirror across the diagonal; secretly 'self-adjoint': you can move A across an inner product, $\langle Av, w\rangle = \langle v, Aw\rangle$ — THE move all three proofs use." Thm 19.1 — slogan: "symmetric ⇒ eigenvalues stay on the real line." Thm 19.2 — "symmetric ⇒ different eigenvalues live at right angles." Thm 19.3 (Spectral Theorem) — slogan: "**every symmetric matrix is a rotation, a scaling, and the rotation undone**: $A = Q\Lambda Q^T$." Name hook: "spectrum" = the set of eigenvalues — the theorem splits A into its pure colors like a prism. Set expectations honestly: Thm 19.3's induction is the hardest proof so far — the primer ladder is there to make the ATTEMPT productive, not to guarantee success.
- **Proof roadmaps:** Thm 19.1 — trick: *the conjugate sandwich.* (1) Let $Av = \lambda v$ with possibly complex $v$; compute $\bar v^T A v$ two ways: directly ($= \lambda \bar v^Tv$) and via symmetry moved to the other side ($= \bar\lambda \bar v^Tv$). (2) $\bar v^Tv = \sum |v_i|^2 > 0$, so $\lambda = \bar\lambda$: real. Thm 19.2 — trick: *evaluate $\langle Av, w \rangle$ both ways.* $\lambda\langle v,w\rangle = \langle Av,w\rangle = \langle v,Aw\rangle = \mu\langle v,w\rangle$; since $\lambda \ne \mu$, $\langle v,w\rangle = 0$. Thm 19.3 — trick: *peel one eigenpair, then show A respects the leftover perpendicular world; induct.* (1) First move: grab one real eigenpair $(\lambda_1, q_1)$ (exists by Thm 19.1 + fundamental theorem of algebra). (2) Middle rung — THE key step: A maps $q_1^\perp$ into itself: if $v \perp q_1$ then $\langle Av, q_1\rangle = \langle v, Aq_1\rangle = \lambda_1\langle v,q_1\rangle = 0$ — symmetry is exactly what makes the complement invariant. (3) Sketch: restrict A to the $(n-1)$-dim world $q_1^\perp$, it's still symmetric there; induction delivers an orthonormal eigenbasis of the complement; prepend $q_1$.
- **Flashcards (7):** Q: The spectral theorem, full statement? A: Real symmetric A = QΛQᵀ: orthonormal eigenvectors in Q, real eigenvalues in Λ. / Q: The ONE algebraic move powering all three proofs today? A: Move A across the inner product: ⟨Av,w⟩ = ⟨v,Aw⟩ (symmetry). / Q: Why are symmetric eigenvalues real, in one line? A: v̄ᵀAv equals both λ·v̄ᵀv and λ̄·v̄ᵀv; v̄ᵀv > 0 forces λ = λ̄. / Q: Eigenvectors of a symmetric matrix for λ ≠ μ are…? A: Orthogonal — evaluate ⟨Av,w⟩ two ways. / Q: What TWO Day-11 diseases does symmetry cure? A: Complex eigenvalues and defectiveness (too few eigenvectors). / Q: Geometric reading of A = QΛQᵀ? A: Rotate to the eigen-axes, scale along them, rotate back. / Q: The key induction step in the spectral theorem? A: A maps q₁-perp into itself, so restrict and recurse.

Then the four standard steps:

- [ ] Step 1: Read `content/day19.md` fully.
- [ ] Step 2: Write `content/primers/day19.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 17: Primer Day 20 — Quadratic forms, positive definiteness

**Files:** Create: `content/primers/day20.md` (main file: `content/day20.md`)

**Brief:**

- **Warm-up:** Days 19, 17, 12.
- **Hook:** Is $q(x,y) = x^2 + 4xy + y^2$ always positive (except at 0)? It LOOKS positive — squares everywhere. Test it: $q(1,-1) = 1 - 4 + 1 = -2$. Ouch. The cross term is a trap the eye can't price. Machine that never falls for it: write $q(x) = x^TAx$ with symmetric $A = \begin{pmatrix}1&2\\2&1\end{pmatrix}$, eigenvalues 3 and −1 — one negative eigenvalue = a downhill direction, guaranteed. Today: the eigenvalue signs ARE the shape of the surface.
- **Pictures:** (1) Three surfaces over the plane: bowl (all λ > 0), saddle (mixed signs), dome (all λ < 0). (2) Level curves: ellipses (definite) vs. hyperbolas (indefinite), with the eigen-axes drawn — the spectral theorem rotates the picture straight. (3) The cross-term kill: rotating coordinates by Q turns $x^TAx$ into $\lambda_1 y_1^2 + \lambda_2 y_2^2$ — no mixed term, shape readable at sight.
- **Walkthrough & memory hooks:** Def 20.1 — "a quadratic form is the energy of a direction: $q(x) = x^TAx$, always taken with SYMMETRIC A." Def 20.2 — "five labels: positive/negative definite (strict bowl/dome), semi-definite (flat directions allowed), indefinite (saddle). Correction to carry (from the 2026-08-04 review): the classes are NOT mutually exclusive as defined — definite is a special case of semidefinite; report the STRONGEST label that applies." Thm 20.1 + Cor 20.1 — slogan: "**the eigenvalue signs are the shape**: all >0 bowl, mixed saddle, all <0 dome; zeros allow flat valley floors." Practical hook: pos. def. tests you'll actually use — eigenvalues all positive, or (stated fact in the main file) leading minors all positive, or $A = B^TB$ with B full-rank.
- **Proof roadmaps:** Thm 20.1 — trick: *rotate to the eigen-axes and read it off.* (1) First move: spectral theorem: $A = Q\Lambda Q^T$; substitute $y = Q^Tx$ (a rigid re-labeling, $x \ne 0 \iff y \ne 0$): $x^TAx = y^T\Lambda y = \sum\lambda_i y_i^2$. (2) If all $\lambda_i > 0$: a positive combination of squares — positive unless y = 0. (3) Converse: plug in the eigenvector $q_i$ itself: $q_i^TAq_i = \lambda_i$ — a non-positive eigenvalue hands you a bad direction explicitly. Cor 20.1 — same substitution, read each case.
- **Flashcards (6):** Q: What does the quadratic form of a direction measure, informally? A: The "energy" A assigns: q(x) = xᵀAx. / Q: Definiteness ⟷ eigenvalues (all five cases)? A: PD: all > 0; PSD: all ≥ 0; ND: all < 0; NSD: all ≤ 0; indefinite: both signs. / Q: Why can't you judge definiteness by inspecting entry signs? A: Cross terms hide downhill directions (x²+4xy+y² fails at (1,−1)). / Q: The proof move for Thm 20.1? A: y = Qᵀx turns xᵀAx into Σλᵢyᵢ² — shape readable. / Q: How to EXHIBIT non-definiteness concretely? A: Plug in the eigenvector of the offending eigenvalue: qᵢᵀAqᵢ = λᵢ. / Q: Is a positive definite matrix also positive semidefinite? A: Yes — definite is the strict special case; report the strongest label.

Then the four standard steps:

- [ ] Step 1: Read `content/day20.md` fully.
- [ ] Step 2: Write `content/primers/day20.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 18: Primer Day 21 — SVD part 1: existence

**Files:** Create: `content/primers/day21.md` (main file: `content/day21.md`)

**Brief:**

- **Warm-up:** Days 20, 19, 14.
- **Hook:** All the beautiful eigen-machinery demands square matrices — and the good stuff (spectral theorem) demands symmetric ones. But DATA is a rectangular matrix: 1000 users × 20 features. Is there an eigen-story for EVERY matrix, any shape? Yes — the SVD, and here's the free insight it rides on: $A^TA$ is always square, always symmetric, always PSD (the "symmetric shadow" of A) — so the spectral theorem applies to IT, and A's structure can be pulled out of it. Geometric preview: any 2×2 A maps the unit circle to an ellipse; the ellipse's semi-axes are the singular values.
- **Pictures:** (1) THE SVD picture: unit circle → ellipse; $v_1, v_2$ = the special perpendicular input directions, $u_1, u_2$ = the perpendicular output axes, $\sigma_1, \sigma_2$ = the stretches. Caption: $Av_i = \sigma_i u_i$ — perpendicular in, perpendicular out. (2) $A = U\Sigma V^T$ as rotate → stretch (rectangular diagonal!) → rotate: works for ANY shape because there are TWO rotations, one per side. (3) The factory diagram: eigen-decompose $A^TA$ → $v$'s and $\sigma^2$'s; push each $v_i$ through A and normalize → $u_i$'s.
- **Walkthrough & memory hooks:** Def 21.1 — "SVD: $A = U\Sigma V^T$ — two orthonormal bases (input's V, output's U) and a diagonal of non-negative stretches, sorted DESCENDING (the sorting is part of the definition — remember it; a Day 24 review problem trips on exactly this)." Lemma 21.1 — "$A^TA$ is the symmetric engine under any A: symmetric by transposing, PSD because $x^TA^TAx = \|Ax\|^2$." Thm 21.1 — slogan: "**eigenvectors of $A^TA$ in, normalized images out**: $\sigma_i = \sqrt{\lambda_i}$, $u_i = Av_i/\sigma_i$." Relation hooks: rank = number of nonzero σ's; SVD of a symmetric PSD matrix = its spectral decomposition.
- **Proof roadmaps:** Thm 21.1 — **the plan's hardest construction; treat the ladder as the assignment.** (1) First move: spectral theorem on $A^TA$: orthonormal $v_1..v_n$, eigenvalues $\lambda_1 \ge \dots \ge \lambda_n \ge 0$ (PSD ⇒ non-negative — Lemma 21.1); set $\sigma_i = \sqrt{\lambda_i}$, let r = count of nonzero ones. (2) Middle rung — the one computation to internalize: for $i,j \le r$, $\langle Av_i, Av_j\rangle = v_i^T A^TA v_j = \lambda_j v_i^Tv_j = \lambda_j\delta_{ij}$ — so the images $Av_i$ are orthogonal with lengths $\sigma_i$: define $u_i = Av_i/\sigma_i$, orthonormal for free. (3) Sketch: for $i > r$, $\|Av_i\| = 0$ so $Av_i = 0$; extend $u_1..u_r$ to an orthonormal basis of $\mathbb{R}^m$ (Gram-Schmidt on any completion); check $AV = U\Sigma$ column by column — both sides send $v_i \mapsto \sigma_i u_i$ or 0. Note where each earlier day fires: spectral (19), PSD (20), G-S extension (15), rank (4–6).
- **Flashcards (7):** Q: The SVD equation and the three ingredients? A: A = UΣVᵀ; U, V orthogonal (output/input bases), Σ diagonal ≥ 0, descending. / Q: Singular values from AᵀA? A: σᵢ = √λᵢ(AᵀA). / Q: Why is AᵀA PSD? A: xᵀAᵀAx = ‖Ax‖² ≥ 0. / Q: How are the uᵢ built and why orthonormal? A: uᵢ = Avᵢ/σᵢ; ⟨Avᵢ,Avⱼ⟩ = λⱼδᵢⱼ makes them orthogonal with unit norm. / Q: Geometric picture of SVD in one sentence? A: Every matrix maps the unit sphere to an ellipsoid: rotate, stretch by σ's, rotate. / Q: rank(A) from the SVD? A: The number of nonzero singular values. / Q: Why does SVD exist for EVERY matrix when diagonalization doesn't? A: Two independent orthonormal bases (input & output) instead of one — asymmetry absorbed by using AᵀA.

Then the four standard steps:

- [ ] Step 1: Read `content/day21.md` fully.
- [ ] Step 2: Write `content/primers/day21.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 19: Primer Day 22 — Low-rank approximation, Eckart–Young

**Files:** Create: `content/primers/day22.md` (main file: `content/day22.md`)

**Brief:**

- **Warm-up:** Days 21, 20, 15.
- **Hook:** A 1000×1000 image is a million numbers. The SVD rewrites it as $\sigma_1 u_1v_1^T + \sigma_2 u_2v_2^T + \dots$ — a stack of rank-1 "layers," LOUDEST FIRST (σ's are sorted). Keep just the top 50 layers: 50·(1000+1000+1) ≈ 100k numbers — 10× compression. Two questions today: exactly how much did we lose (answer: the discarded σ's, in squares), and could any OTHER rank-50 matrix do better (answer: no — Eckart–Young)?
- **Pictures:** (1) The layer stack: $A$ = transparencies $\sigma_iu_iv_i^T$ stacked, opacity decreasing with i; truncation = keep the top k sheets. (2) Energy bar chart: $\sigma_1^2, \sigma_2^2, \dots$ with the tail shaded = the squared error of truncation. (3) For Thm 22.2's key step: the dimension-collision cartoon — a (k+1)-dim room and an (n−k)-dim room inside n-dim space MUST share a nonzero vector (k+1 + n−k = n+1 > n).
- **Walkthrough & memory hooks:** Def 22.1 — "truncation $A_k$ = keep the k loudest layers." Lemma 22.1 — "for orthonormal-layer sums, Frobenius norm behaves like Pythagoras: $\|\sum c_i u_iv_i^T\|_F^2 = \sum c_i^2$." Thm 22.1 — slogan: "**error² = the discarded tail**: $\|A - A_k\|_F^2 = \sigma_{k+1}^2 + \dots + \sigma_r^2$." Thm 22.2 (Eckart–Young) — slogan: "**nobody beats the SVD tail** — among ALL rank-k matrices, $A_k$ is closest to A." **Prerequisite patch (from the 2026-08-04 review):** stage 1 of the proof needs "two subspaces with dim sum > n intersect nontrivially," never proved in this course. Primer supplies the 3-line argument: take bases of both, together > n vectors, dependent (Day 2/Steinitz); a dependence relation with vectors from both sides rearranges into one nonzero vector lying in both spans. Learn it here; the theorem's proof then opens legally.
- **Proof roadmaps:** Lemma 22.1 — trick: *expand the square; orthonormality kills every cross term.* Thm 22.1 — trick: *A − A_k IS an orthonormal-layer sum (the tail layers); apply Lemma 22.1.* Thm 22.2, stage 1 — trick: *find one vector two rooms must share, and let it testify.* (1) First move: let B be ANY rank-k competitor; its null space has dim ≥ n − k; the span of $v_1..v_{k+1}$ has dim k+1; total > n ⇒ they share a unit vector w (the patched fact). (2) Middle: for that w: $\|(A-B)w\|^2 = \|Aw\|^2$ (Bw = 0), and $\|Aw\|^2 = \sum_{i\le k+1}\sigma_i^2\langle v_i,w\rangle^2 \ge \sigma_{k+1}^2$ (expand w over the v's; the σ's involved are the k+1 largest). (3) Sketch: so the error of any B is ≥ σ_{k+1} in operator norm; stage 2 (Frobenius version) is a read-only sketch in the main file — read it as labeled, don't attempt.
- **Flashcards (6):** Q: What is A_k (rank-k truncation)? A: Keep the k largest SVD layers: Σᵢ≤k σᵢuᵢvᵢᵀ. / Q: Frobenius error of truncation? A: ‖A − A_k‖²_F = σ²ₖ₊₁ + … + σ²ᵣ — the discarded tail, in squares. / Q: Eckart–Young in one sentence? A: No rank-k matrix approximates A better than the SVD truncation A_k. / Q: The dimension-counting move in the proof? A: null(B) (dim ≥ n−k) and span(v₁..vₖ₊₁) (dim k+1) must intersect: dims sum past n. / Q: Why do two subspaces with dim sum > n intersect nontrivially? A: Their combined bases exceed n vectors ⇒ dependent ⇒ rearrange the relation into a shared nonzero vector. / Q: Storage cost of A_k for an m×n matrix? A: k(m + n + 1) numbers vs mn — the compression ratio.

Then the four standard steps:

- [ ] Step 1: Read `content/day22.md` fully.
- [ ] Step 2: Write `content/primers/day22.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 20: Primer Day 23 — SVD to PCA

**Files:** Create: `content/primers/day23.md` (main file: `content/day23.md`)

**Brief:**

- **Warm-up:** Days 22, 21, 16.
- **Hook:** A cloud of 2-feature data points, strongly correlated (use the main file's worked-example numbers after reading it). Project them onto the x-axis: some spread survives. Onto y: similar. Onto the DIAGONAL: nearly ALL the spread survives — one number per point tells almost the whole 2-number story. Question: which direction keeps the MOST spread, and how much, exactly? Today derives the answer from scratch — the top eigenvector of one special symmetric matrix built from the data. That's PCA: the spectral theorem pointed at data.
- **Pictures:** (1) Scatter cloud with its long axis drawn — the best line; short perpendicular axis = what you lose by projecting. (2) Projection-spread comparison: same cloud, three candidate directions, the projected points' spread marked under each. (3) The covariance ellipse with principal axes = eigenvectors of C, axis lengths tied to eigenvalues.
- **Walkthrough & memory hooks:** Thm 23.1 — "the bridge lemma: the variance of projections onto direction w is exactly $w^TCw$ — one clean quadratic form; from here PCA is Day 19+20 material." Def 23.1 — "the covariance matrix C is the spread machine: feed it a direction, out comes the variance along it. Built as $\frac{1}{n-1}X^TX$ on CENTERED data (center first — always; the n−1 is a statistics convention, take it as given)." Thm 23.2 — "C is symmetric PSD — same argument shape as Lemma 21.1, spot the rhyme." Thm 23.3 — slogan: "**best direction = top eigenvector; best variance = top eigenvalue.**" Cor 23.3.1 — "then repeat at right angles: component 2 = runner-up eigenvector, etc." Def 23.2 + Remark 23.1 — "explained-variance ratio = how much of the story each axis tells; and in practice the whole thing is read off the SVD of the centered data matrix (Day 21's machinery)."
- **Proof roadmaps:** Thm 23.3 — **route note (deliberate, per spec): attempt the EIGENBASIS proof. The main file leads with a Lagrange-multiplier/calculus proof — treat that as an optional read; it needs multivariable calculus outside this course's prerequisites. The eigenbasis argument (in the main file as a parenthetical) is the real proof for this course.** Ladder: (1) First move: expand the unit direction w over C's orthonormal eigenbasis (spectral theorem — Day 19): $w = \sum c_iq_i$ with $\sum c_i^2 = 1$. (2) Middle: compute $w^TCw = \sum \lambda_i c_i^2$ — a weighted AVERAGE of the eigenvalues with weights $c_i^2$. (3) Sketch: a weighted average can't beat its largest ingredient: $\sum\lambda_ic_i^2 \le \lambda_1\sum c_i^2 = \lambda_1$, equality at $w = q_1$. The same one-liner proves Cor 23.3.1 within the remaining perpendicular directions. Thm 23.1 — trick: *write the projected variance as an explicit average of squares $\frac{1}{n-1}\sum(x_i^Tw)^2$ and factor the w's out of the sum.* Thm 23.2 — trick: *mirror Lemma 21.1: $w^TX^TXw = \|Xw\|^2 \ge 0$.*
- **Flashcards (7):** Q: What single object turns "find the best direction" into linear algebra? A: The covariance matrix: Var(direction w) = wᵀCw. / Q: PCA's answer, in one sentence? A: Top eigenvector of C = direction of max variance; that variance = top eigenvalue. / Q: The calculus-free proof of Thm 23.3? A: Expand w in C's eigenbasis: wᵀCw = Σλᵢcᵢ², a weighted average ≤ λ₁, equality at w = q₁. / Q: Component #2 comes from…? A: Maximizing variance among directions ⊥ q₁ — the runner-up eigenvector. / Q: Why must data be centered before PCA? A: Otherwise the mean offset masquerades as spread — C must measure variation around the mean. / Q: Explained variance ratio of component i? A: λᵢ / Σλⱼ — the share of total spread that axis tells. / Q: PCA via SVD — the connection? A: Right singular vectors of centered X are C's eigenvectors; σᵢ² = (n−1)λᵢ.

Then the four standard steps:

- [ ] Step 1: Read `content/day23.md` fully.
- [ ] Step 2: Write `content/primers/day23.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 21: Primer Day 25 — Change of basis, similarity

**Files:** Create: `content/primers/day25.md` (main file: `content/day25.md`)

**Brief:**

- **Warm-up:** Days 23, 22, 17.
- **Hook:** Two observers describe the SAME rotation of the plane. One uses the standard grid; the other uses a tilted grid $b_1 = (1,1)$, $b_2 = (-1,1)$. Their matrices for the identical physical map have completely different entries. Neither is wrong — a matrix is a *description in a language*, not the map itself. Today: the dictionary between languages (change-of-basis matrix P), the translation rule ($[T]_B = P^{-1}[T]_{std}P$), and the recognition that Day 11's "similar matrices" were exactly this all along — this day is the plan's grand consolidation.
- **Pictures:** (1) Two grids over the same plane (standard + tilted) with one vector carrying two coordinate labels. (2) The commuting square: $[v]_B \xrightarrow{P} [v]_{std} \xrightarrow{A} [Av]_{std} \xrightarrow{P^{-1}} [Av]_B$ — translate in, act, translate out. (3) Callback panel: diagonalization $A = PDP^{-1}$ IS this picture with B = the eigenbasis — "Day 11 was a change of glasses; now you know the glasses shop."
- **Walkthrough & memory hooks:** Def 25.1 — "P's columns = the new basis vectors written in the old language; P converts B-coordinates to standard ones." Direction check to plant (the classic confusion): P carries NEW→OLD; $P^{-1}$ carries OLD→NEW — memorize via 'columns are the new guys in old clothes.' Thm 25.1 — slogan: "**translate in, act, translate out**: $[T]_B = P^{-1}AP$." Remark — "similar = same map, different glasses (now literal); every similarity invariant (Day 11: char. poly, trace, det, rank) is a property of the MAP, not the description."
- **Proof roadmaps:** Thm 25.1 — trick: *chase one vector around the square.* (1) Take any $[v]_B$; convert to standard ($P[v]_B$), apply the map ($AP[v]_B$), convert back ($P^{-1}AP[v]_B$). (2) That composite is, by definition, what the B-matrix of T does to $[v]_B$. (3) Since it holds for every coordinate vector, the matrices are equal.
- **Flashcards (6):** Q: What are the columns of the change-of-basis matrix P? A: The new basis vectors expressed in the old (standard) coordinates. / Q: Which direction does P translate? A: New(B)-coordinates → old(standard); P⁻¹ goes the other way. / Q: The change-of-basis formula for a map's matrix? A: [T]_B = P⁻¹AP — translate in, act, translate out. / Q: What is "similarity" geometrically? A: Same linear map described in two bases. / Q: Diagonalization restated in today's language? A: Change to the eigenbasis: D = P⁻¹AP with P's columns the eigenvectors. / Q: Name four similarity invariants. A: Characteristic polynomial, eigenvalues, trace, determinant (also rank).

Then the four standard steps:

- [ ] Step 1: Read `content/day25.md` fully.
- [ ] Step 2: Write `content/primers/day25.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 22: Primer Day 26 — Trace, determinant, Cholesky bridge

**Files:** Create: `content/primers/day26.md` (main file: `content/day26.md`)

**Brief:**

- **Warm-up:** Days 25, 23, 19.
- **Hook:** Free error-detectors for every eigenvalue computation you'll ever do: the eigenvalues of ANY matrix must SUM to its trace (add the diagonal — 5 seconds) and MULTIPLY to its determinant. Try it: $A=\begin{pmatrix}4&1\\2&3\end{pmatrix}$ from Day 11 had λ = 5, 2. Trace = 7 = 5+2 ✓; det = 10 = 5·2 ✓. Had you computed λ = 5, 3 you'd catch the slip instantly. Today: WHY the checksums hold (coefficient-matching in the characteristic polynomial), plus a bridge fact — Cholesky, "the matrix square root" — closing the positive-definite story.
- **Pictures:** (1) The characteristic polynomial written two ways — expanded from $\det(A - \lambda I)$ vs. factored $\prod(\lambda_i - \lambda)$ — with arrows matching coefficient slots: $\lambda^{n-1}$ slot ↔ trace; constant slot ↔ det. (2) Checksum workflow card: compute eigenvalues → add (=trace?) → multiply (=det?) → only then trust them. (3) Cholesky as square root: PD matrix $A = LL^T$ mirrors positive number $a = (\sqrt a)^2$.
- **Walkthrough & memory hooks:** Thm 26.1 — slogan: "**trace = Σλ, det = Πλ: the two conserved checksums.**" Why-it-works hook: det(A − λI) EXPANDED collects its λ^{n-1} term only from the all-diagonal product (every off-diagonal choice costs at least two diagonal factors), and its constant term is det(A) itself (set λ = 0). Cholesky Remark — "every positive definite matrix has a triangular square root $A = LL^T$ — stated fact here, proof deferred; it's why PD matrices are computationally friendly (fast solves, sampling). Careful reading note (from the 2026-08-04 review): for SEMI-definite matrices the strict positive-diagonal Cholesky fails, though non-unique factorizations can exist — the main file's Ex 5 phrasing 'does not apply' means the strict version."
- **Proof roadmaps:** Thm 26.1 — trick: *one polynomial, two costumes; match coefficients.* (1) First move: write $p(\lambda) = \det(A-\lambda I) = \prod_i(\lambda_i - \lambda)$ (roots = eigenvalues, with multiplicity — over ℂ if needed). (2) Middle: constant term: set λ = 0 in both costumes — $\det A = \prod\lambda_i$, done. (3) Sketch for the trace: in the Leibniz/cofactor expansion of $\det(A - \lambda I)$, argue the $\lambda^{n-1}$ coefficient comes only from expanding $\prod(a_{ii} - \lambda)$ — any term using an off-diagonal entry skips ≥ 2 diagonal factors, so its degree ≤ n−2; compare with the factored form's $\lambda^{n-1}$ coefficient: $\pm\sum\lambda_i$ vs $\pm\sum a_{ii}$.
- **Flashcards (6):** Q: The two eigenvalue checksums? A: Σλᵢ = trace(A); Πλᵢ = det(A). / Q: How do you get det = Πλ in one move? A: Set λ = 0 in det(A−λI) = Π(λᵢ−λ). / Q: Why does only the diagonal product feed the λⁿ⁻¹ coefficient? A: Using any off-diagonal entry forfeits at least two diagonal factors — degree drops to ≤ n−2. / Q: What is the Cholesky decomposition and for which matrices? A: A = LLᵀ, L lower-triangular positive-diagonal; exists uniquely for positive DEFINITE A. / Q: Everyday use of the checksums? A: Instant self-check after any eigenvalue computation — catches arithmetic slips before they propagate. / Q: Cholesky's number analogy? A: The matrix version of √a for a > 0.

Then the four standard steps:

- [ ] Step 1: Read `content/day26.md` fully.
- [ ] Step 2: Write `content/primers/day26.md` from the Brief.
- [ ] Step 3: Verify per standard checklist.
- [ ] Step 4: `git status --short content/` — only the new file. No commit.

---

### Task 23: Final verification pass

**Files:** none created — verification only.

- [ ] **Step 1: Inventory.** Run `ls content/primers/` — expect exactly 23 files: README.md + day01, 02, 03, 04, 05, 06, 08, 09, 10, 11, 12, 14, 15, 16, 17, 19, 20, 21, 22, 23, 25, 26 (.md each).
- [ ] **Step 2: Originals untouched.** Run `git status --short content/` — the ONLY entries are untracked files under `content/primers/` (plus this plan/spec under docs/). Any modified (`M`) file is a failure — report it, do not fix silently.
- [ ] **Step 3: Warm-up consistency.** For each primer, confirm its Warm-up section lists exactly the days in the README table (Task 0). Spot-fix any mismatch toward the table.
- [ ] **Step 4: Structure sweep.** For each primer confirm the section order (Warm-up → The hook → The pictures → Concrete-first walkthrough → Proof roadmaps → Flashcards; Day 1 without Warm-up), flashcard count 6–10, length 150–250 lines (up to ~280 tolerated for the heavy days 8, 11, 21 — do not pad thin ones).
- [ ] **Step 5: Citation sweep.** `grep -o 'Thm [0-9.]*\|Theorem [0-9.]*\|Def [0-9.]*\|Definition [0-9.]*\|Lemma [0-9.]*\|Cor [0-9.]*' content/primers/dayNN.md` per file; verify each cited number exists in the matching `content/dayNN.md` headings. Fix any drift.
- [ ] **Step 6: Report.** Summarize to the user: file list, line counts, any deviations. NO COMMIT — the user handles version control.

---

## Self-Review (performed at authoring time)

1. **Spec coverage:** 22 primer days ✓ (Tasks 1–22 = days 1–6, 8–12, 14–17, 19–23, 25–26); README ✓ (Task 0); six-section structure fixed in Global Constraints ✓; Day 1 no-warm-up exception ✓ (Task 1 + constraints); flashcards 6–10 with exact format ✓; warm-up schedule explicit per day and centralized in README table ✓; Day 23 eigenbasis-route exception ✓ (Task 20); Day 4 avoids the calculus exercise dependency ✓ (Task 4 roadmap uses only basis-extension); originals untouched + verification ✓ (Task 23); no-commit rule ✓ (Global Constraints + every task).
2. **Placeholder scan:** no TBD/TODO; every hook has concrete numbers or an explicit instruction to lift them from the main file's worked example (Day 23); every roadmap has a named trick + 3 rungs; every flashcard has both Q and A.
3. **Consistency:** warm-up lists in Tasks 1–22 match the Task 0 table (verified row by row at authoring time); theorem numbering matches the heading inventory extracted from the content files on 2026-08-04; Task 23's file list matches the File Structure section.
4. **Known intentional deviations from main files** (all traceable to the 2026-08-04 feasibility review, none contradicting correct math): Day 3 pre-teaches matrix-multiplication mechanics; Day 6 pre-teaches transpose + $(AB)^T$; Day 11 patches the block-triangular determinant IOU; Day 15 reorders proof attempts (15.2 before 15.1); Day 16 supplies the $C(A)^\perp = N(A^T)$ three-liner; Day 20 corrects the "mutually exclusive" phrasing; Day 21 stresses the descending-σ convention; Day 22 supplies the subspace-intersection dimension fact; Day 23 promotes the eigenbasis proof; Day 26 tightens the Cholesky "does not apply" phrasing.
