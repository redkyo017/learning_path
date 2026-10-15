# Basic Mathematics (Serge Lang) — The Condensed Companion

*A memory-consolidation version of Serge Lang, **Basic Mathematics** (Addison-Wesley, 1971; Springer reprint). Same
chapters, same order, same proofs — condensed. Written for someone who has read the book once and wants to keep it
for good. The exercises stay in the book: do them there.*

**How this file is laid out**

- **Part 0** — How to make it stick (strategy), the mistakes that waste the effort, and the plan.
- **Parts I–IV** — the book, chapter by chapter. Every axiom, rule, theorem, proposition, lemma and corollary gets:
  the statement, Lang's proof in numbered steps, a one-line intuition, and one worked example. Each chapter ends with
  closed-book **recall prompts**.
- **Labels.** Lang's own labels are kept (N 1, POS 2, Theorem 3, …). *Assumed* = Lang takes it as an axiom or
  intuitive fact, no proof. *Proved* = Lang derives it. *Left to the reader* = the book leaves the proof as an
  exercise. Anything that is not Lang's (an extra example, a note) is marked *ours*. Where the book has a misprint,
  the correct value is used and the note says what the book prints.
- **Map of Results** — the whole book on a few pages, in dependency order. This is what you review from later.

---

# Part 0 — How to Make It Stick

## 0.1 The strategy in one sentence

> **Don't reread the book. Rebuild it from memory, check, repair, and do it again later, after you have started to
> forget.**

Everything below is that sentence made precise. It rests on a handful of findings that are among the best-replicated
in learning research. Where something is my judgment rather than a finding, I say so.

## 0.2 The five principles (and the evidence)

**1. Retrieval beats rereading.** Recalling something from memory strengthens it far more than looking at it again.
In Roediger & Karpicke (2006), students who *tested themselves* on a text remembered more of it a week later than
students who *restudied* it, even though the restudy group felt more confident. Karpicke & Blunt (2011) found
retrieval practice also beat making elaborate concept maps. The large review by Dunlosky et al. (2013) rates
practice testing as one of only two "high utility" techniques, and rates rereading and highlighting as "low
utility".
→ *For you:* every session starts with a **blank page**, not with this file. You write what you remember, then you
check.

**2. Spacing beats cramming.** The same total time, spread over sessions with gaps between them, gives much longer
retention than one block (Cepeda et al., 2006 meta-analysis; Cepeda et al., 2008). The best gap grows with how long
you want to remember. For retention over months to a year, gaps of weeks — then a month or more — work better than
daily repetition. Dunlosky et al. rate distributed practice "high utility" as well.
→ *For you:* a one-week sprint is **not** the plan. It is the first pass of a plan that runs for about 8 months, at
about 30 minutes per session after the sprint.

**3. Interleave problem types.** Math practice where problems of different kinds are shuffled together leads to
better test performance than practice in blocks of one kind (Rohrer & Taylor, 2007). The reason: in a block, you
know which method to use before you read the problem. In a mixed set you must *choose* — and choosing the method is
the skill.
→ *For you:* after each chapter, mix in exercises from earlier chapters.

**4. Explain each step to yourself.** Learners who explain *why* each line of a worked solution follows learn more
from it (Chi et al., 1989). Dunlosky et al. rate self-explanation "moderate utility".
→ *For you:* every proof in this file has numbered steps, and each step names what it uses ("by distributivity",
"by Theorem 2"). Before you read the reason, say it.

**5. Memorise the chain, not the facts** *(judgment, built on 1–4).* Lang's book is a chain. A few axioms come
first (N1–N4 for addition, the multiplication rules, POS 1–2 for order, the distance properties of geometry), and
everything else is *proved* from them. If you hold the chain, any forgotten formula can be rebuilt in a minute:
$(a+b)^2$, the quadratic formula, $\sin(x+y)$, $\log xy$, a 2×2 determinant. Isolated facts decay; a fact you can
rebuild never really goes. This is also the "generation effect": what you produce yourself is remembered better than
what you read (Slamecka & Graf, 1978).
→ *For you:* the **Map of Results** at the end is the chain. It is your main review tool.

> **Desirable difficulty.** Recall from a blank page will feel slow and frustrating compared with rereading. That
> feeling is not a sign that it isn't working; Bjork (1994) calls these "desirable difficulties". The ease of
> rereading is the trap: it makes you *feel* you know the material without making you know it.

## 0.3 The mistakes that waste the effort

Each mistake comes with how you would notice you're making it, and what to do instead.

| # | Mistake | How you notice | Do instead |
|---|---|---|---|
| 1 | **Rereading** the chapter "to refresh it". | You nod along and every line feels familiar — but close the book and you can't state Theorem 2. | Blank page first. Read only to *check* what you wrote. |
| 2 | **Memorising formulas** instead of the 3-line proof that produces them. | You remember $\sin(x+y)$ but not which sign goes where in $\cos(x+y)$. | Memorise the derivation. Rebuild the formula each time you need it, until it becomes automatic. |
| 3 | **Cramming** all of it this week and stopping. | In two months, Chapter 6 is a blur. | Keep the spaced sessions (§0.5). They are short; the schedule does the work. |
| 4 | **Skipping the Interlude on logic** because "it's not real math". | You can't tell whether a proof shows a statement or its converse; you "prove" things by examples. | Learn its few rules (implication, converse, contrapositive, contradiction, "for all / there exists") first. They carry every proof in the book. |
| 5 | **Doing exercises on autopilot**, by pattern-matching the section you just read. | Exercises are easy right after the section, and impossible in a mixed set. | Interleave. Before each exercise, name the result you are going to use. |
| 6 | **Checking too early.** Peeking after 20 seconds of being stuck. | Most recalls end with you reading the answer. | Give each recall an honest attempt (2–3 minutes) — the struggle is where the gain is. Then check and *redo it closed-book*. |
| 7 | **Letting AI write the proof.** | The proof makes sense when you read it, and you can't write it the next day. | Use AI as a *checker and quizzer*, never as a source of the first attempt (see §0.6). |
| 8 | **Treating the geometry as "obvious".** | You draw the picture and believe it, but can't say which property you used. | Lang's geometry chapters use a few explicit properties. Name them, as you do for algebra. |

## 0.4 The plan, part 1 — The 7-day sprint

About **2–3 hours a day**. Each day covers a block of chapters. The load follows the number of results per chapter,
not the page count.

| Day | Chapters | Focus |
|---|---|---|
| 1 | Ch 1 Numbers, Ch 2 Linear equations | The axioms of addition and multiplication; everything proved from them. Fractions. Elimination. |
| 2 | Ch 3 Real numbers, Ch 4 Quadratic equations, Interlude on logic | Positivity (POS) → all inequalities; roots and powers; the quadratic formula. Logic rules. |
| 3 | Ch 5 Distance & angles, Ch 6 Isometries, Ch 7 Area | Pythagoras (its proof!), isometries and how they compose, area under dilation, $\pi$. |
| 4 | Ch 8 Coordinates, Ch 9 Operations on points, Ch 10 Segments, rays, lines | Distance formula, circles, rational points, vectors as points, parametric lines. |
| 5 | Ch 11 Trigonometry, Ch 12 Analytic geometry | Addition formulas (and what they're derived from), rotations, the conics. |
| 6 | Ch 13 Functions, Ch 14 Mappings | Polynomials, exp and log rules, composition and inverses, permutations. |
| 7 | Ch 15 Complex numbers, Ch 16 Induction, Ch 17 Determinants — then the whole book | Polar form, induction proofs, summation, determinant properties, Cramer. **Finish with one blank-page pass over the whole Map of Results.** |

**Daily protocol** (same every day):

1. **Warm-up — yesterday (10 min).** Answer yesterday's recall prompts closed-book. Anything missed goes on a list
   called *Repair*.
2. **Brain dump (15 min).** Blank page. For today's chapters, write every definition and result you remember, and
   sketch each proof in 1–3 lines. No looking.
3. **Check and repair (45–60 min).** Now open this file. Mark what you missed or got wrong. For each miss: read Lang's
   proof steps, close the file, and **write the proof yourself**. Say the reason for each step out loud. Then study the
   worked example: cover it and redo it.
4. **Exercises (45–60 min).** From the book: roughly every other exercise in today's sections, **plus 3–5 from
   earlier chapters**, shuffled. Before each one, write the name of the result you will use. (The remaining exercises
   are for the spaced sessions — you will do all of them, spread over months, which is better than doing all of
   them now.)
5. **Close (10 min).** Today's recall prompts, closed-book. Misses go on *Repair*.

**Day 7 finish.** Rewrite the **Map of Results** from memory as far as you can: chapter by chapter, which results,
in which order, what each depends on. Compare. That comparison is your "repair list" for the first spaced session.

## 0.5 The plan, part 2 — Spaced sessions (the part that makes it long-term)

After the sprint, about **30–45 minutes per session**, at widening intervals counted from the end of the sprint:

| Session | When | What |
|---|---|---|
| S1 | +1 week | Repair list from Day 7 + recall prompts of Ch 1–6 + 10 new book exercises, mixed chapters |
| S2 | +2 weeks | Map of Results blank-page pass + recall prompts of Ch 7–17 + 10 new exercises, mixed |
| S3 | +1 month | Pick 12 results at random; for each, state it and prove it closed-book + 12 new exercises |
| S4 | +2 months | Same as S3, different results; include at least one full proof per Part (I–IV) |
| S5 | +4 months | Map of Results blank-page pass + 15 new exercises |
| S6 | +8 months | Same as S5. After this, a yearly pass is enough. |

**Rule for misses (a simple Leitner system).** Any result you fail to state *or* prove goes to the *Repair* list and is
reviewed again at the next session, whatever its interval — it only rejoins the normal schedule after two clean
recalls in a row.

**Optional: flashcards.** If you use Anki or similar, make **one card per named result**. Front: "State and prove
<label>". Back: the statement and the proof steps, copied from here. The app then handles the spacing for you. Keep
cards about results and derivations, not isolated formulas (Mistake 2).

## 0.6 Where to use AI — and where not

| Use AI for | Don't use AI for |
|---|---|
| **Quizzing you:** "Ask me to state and prove 5 random results from Chapter 3, one at a time, and wait for my answer." | Writing a proof before you have tried it yourself. |
| **Checking your written proof:** paste it in and ask "Is every step justified? Which rule does each step use? Is any step missing?" | Solving a book exercise for you on the first attempt. |
| **Explaining an error** after you've found that your answer differs from the book's. | Summarising a chapter in place of your brain dump. |
| **Generating extra mixed problems** of a type you keep missing. | Deciding that a step is "obvious" — check it against the axioms yourself. |

The line is simple: **AI after your attempt, never instead of it.** The attempt is the part that builds memory.

## 0.7 References

- Bjork, R. A. (1994). Memory and metamemory considerations in the training of human beings. In J. Metcalfe &
  A. Shimamura (Eds.), *Metacognition: Knowing about knowing* (pp. 185–205). MIT Press.
- Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall
  tasks: A review and quantitative synthesis. *Psychological Bulletin, 132*(3), 354–380.
- Cepeda, N. J., Vul, E., Rohrer, D., Wixted, J. T., & Pashler, H. (2008). Spacing effects in learning: A temporal
  ridgeline of optimal retention. *Psychological Science, 19*(11), 1095–1102.
- Chi, M. T. H., Bassok, M., Lewis, M. W., Reimann, P., & Glaser, R. (1989). Self-explanations: How students study
  and use examples in learning to solve problems. *Cognitive Science, 13*(2), 145–182.
- Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning
  with effective learning techniques. *Psychological Science in the Public Interest, 14*(1), 4–58.
- Karpicke, J. D., & Blunt, J. R. (2011). Retrieval practice produces more learning than elaborative studying with
  concept mapping. *Science, 331*(6018), 772–775.
- Roediger, H. L., & Karpicke, J. D. (2006). Test-enhanced learning: Taking memory tests improves long-term retention.
  *Psychological Science, 17*(3), 249–255.
- Rohrer, D., & Taylor, K. (2007). The shuffling of mathematics problems improves learning. *Instructional Science,
  35*, 481–498.
- Slamecka, N. J., & Graf, P. (1978). The generation effect: Delineation of a phenomenon. *Journal of Experimental
  Psychology: Human Learning and Memory, 4*(6), 592–604.

---
# Part One — Algebra (Chapters 1–4 and the Interlude)

- Lang wants fast reflexes with addition, multiplication and division: commutativity, associativity, distributivity, cross-multiplication.
- He assumes only the most basic rules, and enough of them that the others are short proofs. The assumed rules are exactly the ones that recur all over mathematics (functions, complex numbers, ...), so training on them pays off later.
- The list is a description of how numbers behave, not a minimal axiom system. Commutativity can fail for other objects (e.g. composition of mappings), so it is a real property, not a triviality.
- Order of exposition: integers, then rationals, then reals, repeating rules each time. Pattern to remember: each extension solves equations the smaller system cannot ($2x=3$ in $\mathbb{Q}$ not $\mathbb{Z}$; $x^2=2$ in $\mathbb{R}$ not $\mathbb{Q}$; $x^2=-1$ in $\mathbb{C}$ not $\mathbb{R}$).
- Lang says a reader already fluent in this may skip ahead; algebra is the dry part, best motivated by geometry.

## Chapter 1 — Numbers

> We list the rules of arithmetic for integers, assume the basic ones (commutativity, associativity, distributivity, $0$, $1$, additive inverse) and derive everything else from them: sign rules, $0a=0$, the square formulas, parity, lowest form of fractions. Then we pass to rational numbers, add the multiplicative inverse, and prove cross-multiplication from it. The principle "a result proved only from the basic rules holds in every number system satisfying them" is used for $\mathbb{Q}$, then $\mathbb{R}$, and later for polynomials and complex numbers. The irrationality of $\sqrt2$ (Theorem 4) is the first sign that $\mathbb{Q}$ is not enough.

### §1. The integers

**Definitions.**
- **Positive integers**: $1,2,3,\dots$ (counting numbers). **Natural numbers**: positive integers together with $0$. **Origin**: the point $0$ on the number line.
- **Negative integers**: $-1,-2,-3,\dots$, placed on the line on the other side of $0$. **Integers**: positive integers, negative integers and $0$.
- **Minus $a$**: the symbol $-a$. We say "minus $a$", not "negative $a$", because $-a$ is not necessarily negative ($3=-(-3)$ is positive).
- **Additive inverse** of $a$: the number $-a$, because $a+(-a)=0$.
- Adding a positive number moves right on the line; adding a negative number moves left.

**Axiom N 1.** *Statement:* for every integer $a$, $a+0=a$ (and $0+a=a$). *Assumed (axiom).*
*Intuition:* moving $0$ steps changes nothing.
*Example:* $-7+0=-7$.

**Axiom N 2.** *Statement:* for every integer $a$, $a+(-a)=0$ and $-a+a=0$. *Assumed (axiom).*
*Intuition:* $a$ and $-a$ sit symmetrically on opposite sides of $0$.
*Example:* $3+(-3)=0$, and $5=-(-5)$ because $-5$ and $5$ are opposite points.

### §2. Rules for addition

**Definitions.**
- Convention: $a-b$ means $a+(-b)$.
- Sums of several terms need no parentheses once associativity is known.

**Axiom (Commutativity of addition).** *Statement:* $a+b=b+a$ for all integers $a,b$. *Assumed (axiom); not proved in the book.*
*Example:* $-2+5=3=5+(-2)$.

**Axiom (Associativity of addition).** *Statement:* $(a+b)+c=a+(b+c)$. *Assumed (axiom).*
*Intuition:* grouping does not matter, so we write $a+b+c$; by repeated use of both rules, a sum may be taken in any order.
*Example:* $(-2+5)+4=3+4=7$ and $-2+(5+4)=-2+9=7$.

**Rule N 3.**
*Statement:* if $a+b=0$ then $b=-a$ and $a=-b$.
*Proof (Lang's):*
1. Add $-a$ to both sides of $a+b=0$: $-a+a+b=-a+0=-a$.
2. The left side is $(-a+a)+b=0+b=b$ (N 2, N 1, associativity).
3. So $b=-a$. Symmetrically (add $-b$) $a=-b$.
*Intuition:* to test whether $b$ is "minus $a$", check that the sum is $0$.
*Example:* $x+3=5$: add $-3$, $x=5-3=2$.

**Rule N 4.**
*Statement:* $a=-(-a)$ for every integer $a$, whether $a$ is positive, negative or $0$.
*Proof (Lang's):*
1. $a+(-a)=0$ (N 2).
2. Apply N 3 with $b=-a$: it gives $a=-b=-(-a)$.
*Intuition:* reflecting twice about $0$ returns to the start; piling up minus signs alternates $a$, $-a$.
*Example:* $3=-(-3)=-(-(-(-3)))$.

**Rule N 5.**
*Statement:* $-(a+b)=-a-b$.
*Proof (Lang's):*
1. By N 3 it suffices to show $(a+b)+(-a-b)=0$.
2. $(a+b)+(-a-b)=a+b-a-b$ by associativity.
3. $=a-a+b-b$ by commutativity.
4. $=0+0=0$.
*Intuition:* the negative of a sum is the sum of the negatives.
*Example:* $-(-4+5)=-(-4)-5=4-5=-1$; and $-(3-7)=-3-(-7)=-3+7=4$.

**Positivity rule for sums.** *Statement:* if $a,b$ are positive integers, so is $a+b$. *Assumed (axiom).*
**Consequence.** *Statement:* if $a,b$ are negative, $a+b$ is negative.
*Proof (Lang's):* write $a=-n$, $b=-m$ with $n,m$ positive. Then $a+b=-n-m=-(n+m)$ by N 5, and $n+m$ is positive, so $a+b$ is negative.
*Example:* $-3+(-5)=-(3+5)=-8$.

**Solving $a+b=c$.**
*Statement:* if $a+b=c$ then $a=c-b$ and $b=c-a$.
*Proof (Lang's):* add $-b$ to both sides: $a+b-b=c-b$, so $a+0=c-b$, i.e. $a=c-b$. Similarly for $b$.
*Example:* $4-a=3$: add $a$ to get $4=3+a$; subtract $3$ to get $a=1$. And $-2-y=5$ gives $-7=y$.

### §3. Rules for multiplication

**Definitions.**
- **Power**: for a positive integer $n$, $a^n=aa\cdots a$ ($n$ factors), the **$n$-th power** of $a$.
- Multiplication is also written with a dot.

**Axioms (assumed, no proof).**
- Commutativity: $ab=ba$. Associativity: $(ab)c=a(bc)$. Valid for positive, negative or zero integers.
- **N 6.** $1a=a$ and $0a=0$, both boxed together in the book as the rules for multiplication by $1$ and $0$. Lang then remarks that $0a=0$ can be proved from the other rules and does so (next block).
- Distributivity: $a(b+c)=ab+ac$ and $(b+c)a=ba+ca$.
*Intuition:* distributivity is the only rule tying $+$ and $\times$, so every sign rule must come from it.
*Example (reordering factors):* $(2a)(3b)=2(a(3b))=2(3a)b=(2\cdot3)ab=6ab$; likewise $(5x)(7y)=35xy$.

**Remark (one-sided distributivity suffices).** From left distributivity and commutativity: $(b+c)a=a(b+c)=ab+ac=ba+ca$.

**Proposition $0a=0$ (second half of N 6, proved by Lang as an example).**
*Statement:* $0a=0$ for every integer $a$.
*Proof (Lang's):*
1. $0a+a=0a+1a=(0+1)a=1a=a$ (distributivity, N 1, N 6).
2. Add $-a$ to both sides: $0a+a-a=a-a=0$.
3. The left side is $0a+0=0a$. Hence $0a=0$.
*Example:* $0\cdot 7+7=7$, so $0\cdot7=0$.

**Rule N 7.**
*Statement:* $(-1)a=-a$.
*Proof (Lang's):*
1. $(-1)a+a=(-1)a+1a=(-1+1)a=0a=0$ (distributivity, $0a=0$).
2. By the definition of additive inverse (N 3), $(-1)a=-a$.
*Example:* $(-1)\cdot 6=-6$.

**Rule N 8.**
*Statement:* $-(ab)=(-a)b$.
*Proof (Lang's):*
1. We must show $ab+(-a)b=0$ (N 3).
2. By distributivity $ab+(-a)b=(a+(-a))b=0b=0$.

**Rule N 9.**
*Statement:* $-(ab)=a(-b)$. *Proof:* left to the reader in the book (same as N 8 with the roles of $a,b$ exchanged, using commutativity).
*Example:* $-(3a)=(-3)a=3(-a)$; $4(a-5b)=4a-20b$; $-3(5a-7b)=-15a+21b$.

**Rule N 10.**
*Statement:* $(-a)(-b)=ab$.
*Proof:* left as an exercise in the book. Lang proves the special case: $(-1)(-1)=-(1\cdot(-1))=-(-1)=1$, using N 8/N 9 then N 4. The general case follows the same way: $(-a)(-b)=-(a(-b))=-(-(ab))=ab$.
*Intuition:* two minus signs make a plus. So product of two negatives is positive, and negative times positive is negative ($(-4)\cdot7=-(4\cdot7)=-28$).
*Example:* $(-3)(-5)=-(3(-5))=-(-(3\cdot5))=15$.

**Rule N 11 (product of powers).**
*Statement:* for positive integers $m,n$: $a^{m+n}=a^ma^n$.
*Justification (Lang's counting argument, no formal proof):* $a^{m+n}$ is $a$ multiplied by itself $m+n$ times, which is the product of $m$ factors with $n$ factors.
*Example:* $a^2a^3=(aa)(aaa)=a^5$. And $(7x)(2x)(5x)=70x^3$.

**Rule N 12 (power of a power).**
*Statement:* $(a^m)^n=a^{mn}$.
*Justification (Lang's counting argument, no formal proof):* $a^m$ multiplied by itself $n$ times gives $m\cdot n$ factors of $a$.
*Example:* $(a^3)^4=a^{12}$.

**Power of a product.**
*Statement:* $(ab)^n=a^nb^n$.
*Proof (Lang's):* $(ab)^n=abab\cdots ab=aa\cdots a\,bb\cdots b=a^nb^n$ (commutativity and associativity).
*Example:* $(2a^3)^5=2^5(a^3)^5=32a^{15}$.
*Application (Lang's):* a city of 300 thousand doubling every 20 years has $2^3\cdot300$ thousand $=2.4$ million after 60 years.

**Theorem (square formulas).**
*Statement:* $(a+b)^2=a^2+2ab+b^2$, $(a-b)^2=a^2-2ab+b^2$, $(a+b)(a-b)=a^2-b^2$.
*Proof (Lang's):*
1. $(a+b)^2=(a+b)(a+b)=a(a+b)+b(a+b)=aa+ab+ba+bb=a^2+2ab+b^2$ (distributivity, commutativity).
2. $(a-b)^2=a(a-b)-b(a-b)=aa-ab-ba+bb=a^2-2ab+b^2$.
3. $(a+b)(a-b)=a(a-b)+b(a-b)=aa-ab+ba-bb=a^2-b^2$ (the middle terms cancel).
*Intuition:* expand with distributivity twice; learn them "like a poem".
*Example:* $(-2a+5b)^2=4a^2+2(-2a)(5b)+25b^2=4a^2-20ab+25b^2$; $(4a-6)(4a+6)=16a^2-36$.

**Expanding a product of several factors (method).**
*Example:* $(2x+1)(x-2)(x+5)$.
1. $(2x+1)(x-2)=2x^2-4x+x-2=2x^2-3x-2$.
2. $(2x^2-3x-2)(x+5)=2x^3-3x^2-2x+10x^2-15x-10$.
3. Collect: $2x^3+7x^2-17x-10$.

### §4. Even and odd integers; divisibility

**Definitions.**
- **Even** integer: a positive integer of the form $2n$, $n$ a positive integer. **Odd** integer: a positive integer of the form $2m-1$ ($m$ positive), equivalently $2n+1$ with $n$ a natural number.
- **Divisibility**: for $d$ a positive integer and $m$ an integer, **$d$ divides $m$** (or $m$ is **divisible by $d$**) if $m=dk$ for some integer $k$. Even means divisible by 2. Every integer is divisible by $1$; every positive integer by itself. Example: $-30=5(-6)$.

**Theorem 1.**
*Statement:* $a,b$ positive integers. even+even is even; even+odd is odd; odd+even is odd; odd+odd is even.
*Proof (Lang's):* Lang proves the second statement; the others are exercises (same method).
1. Let $a=2n$, $b=2k+1$.
2. $a+b=2n+2k+1=2(n+k)+1$ by distributivity.
3. Put $m=n+k$: $a+b=2m+1$, odd.
*Intuition:* track only the remainder after division by 2.
*Example:* $6+7=2\cdot3+2\cdot3+1=2\cdot6+1=13$.

**Theorem 2.**
*Statement:* $a$ a positive integer. If $a$ is even then $a^2$ is even; if $a$ is odd then $a^2$ is odd.
*Proof (Lang's):*
1. $a$ even, $a=2n$: $a^2=2n\cdot2n=2(2n^2)=2m$ with $m=2n^2$. Even.
2. $a$ odd, $a=2n+1$: $a^2=(2n)^2+2(2n)\cdot1+1=4n^2+4n+1$.
3. $=2(2n^2+2n)+1=2k+1$ with $k=2n^2+2n$. Odd.
*Example:* $7^2=49=2\cdot24+1$; $6^2=36=2\cdot18$.

**Corollary (of Theorem 2).**
*Statement:* if $a^2$ is even then $a$ is even; if $a^2$ is odd then $a$ is odd.
*Proof (Lang's):* pure logic. If $a^2$ is even and $a$ were odd, $a^2$ would be odd by Theorem 2, contradiction. Likewise if $a^2$ is odd and $a$ were even.
*Example:* $49$ is odd, so its root $7$ is odd; $m^2=2n^2$ is even, so $m$ is even (used in Theorem 4).

### §5. Rational numbers

**Definitions.**
- **Rational number**: a quotient $m/n$ with $m,n$ integers, $n\neq0$. We never divide by $0$.
- An integer $m$ is identified with $m/1$.
- A rational number is **positive** if it can be written $m/n$ with $m,n$ positive integers; **negative** if it can be written $-m/n=m/(-n)$ with $m,n$ positive.
- **Common divisor** of $m,n$: an integer dividing both. A positive rational is in **lowest form** $r/s$ ($r,s$ positive integers) if the only common divisor of $r,s$ is $1$.
- **Irrational**: a number which is not rational.
- The same fraction has many representations: $\tfrac12=\tfrac24$.

**Rule (cross-multiplying).**
*Statement:* $m,n,r,s$ integers, $n\neq0$, $s\neq0$. Then $\dfrac mn=\dfrac rs$ if and only if $ms=nr$.
*Proof:* *Assumed (axiom)* in this section. In §6 Lang proves the same rule for rational numbers from inverses.
*Intuition:* multiply both fractions by $ns$.
*Example:* $\tfrac12=\tfrac24$ since $1\cdot4=2\cdot2$ (Lang's first example); $\tfrac{3}{7}=\tfrac{9}{21}$ since $3\cdot21=9\cdot7=63$; $\tfrac{-4}{5}=\tfrac{8}{-10}$ since $(-4)(-10)=8\cdot5=40$.

**Cancellation rule for fractions.**
*Statement:* $a\ne0$ an integer, $n\ne0$: $\dfrac{am}{an}=\dfrac mn$.
*Proof (Lang's):* by cross-multiplying we must check $(am)n=m(an)$, true by associativity and commutativity.
*Example:* if $d$ is a common divisor, $m=dr$, $n=ds$ then $\tfrac mn=\tfrac{dr}{ds}=\tfrac rs$; $\tfrac{10}{15}=\tfrac{2\cdot5}{3\cdot5}=\tfrac23$.

**Moving a minus sign.**
*Statement:* $\dfrac{-m}{n}=\dfrac{m}{-n}$ (and so $-\frac mn$ is well-defined as either).
*Proof (Lang's):* cross-multiply: need $(-m)(-n)=mn$ (N 10).
*Example:* $\tfrac{-4}{5}=\tfrac{4}{-5}$.

**Theorem 3 (lowest form exists).**
*Statement:* every positive rational number can be written as a fraction in lowest form.
*Proof (Lang's):*
1. Write the number as $m/n$ with $m,n$ positive integers.
2. $1$ is a common divisor, and every common divisor is at most $m$ (or $n$), so a greatest common divisor $d$ exists.
3. Write $m=dr$, $n=ds$ with $r,s$ positive; then $m/n=dr/ds=r/s$ by cancellation.
4. Suppose $e>1$ is a common divisor of $r,s$: $r=ex$, $s=ey$.
5. Then $m=dex$, $n=dey$, so $de$ is a common divisor of $m,n$ greater than $d$. Contradiction.
6. So $1$ is the only common divisor of $r,s$.
*Example:* $\tfrac{45}{9}$: gcd $9$, so $\tfrac{9\cdot5}{9\cdot1}=5$.
*Example (Lang's, used in Theorem 4):* a positive rational can be written $m/n$ with $m,n$ positive and not both even (take lowest form: $2$ cannot divide both, so one of them is odd).

**Addition of rational numbers.**
*Statement:* same denominator: $\dfrac ad+\dfrac bd=\dfrac{a+b}{d}$. General ($n,s\ne0$): $\dfrac mn+\dfrac rs=\dfrac{ms+rn}{ns}$ (the book prints $ms+rn$; same as $ms+nr$).
*Justification (Lang's):* the same-denominator rule is stated, motivated by "three-fifths plus eight-fifths is eleven-fifths". For the general case, put both over the common denominator $ns$ by cancellation: $\tfrac mn=\tfrac{ms}{ns}$ and $\tfrac rs=\tfrac{nr}{ns}$, then add numerators.
*Example (Lang's):* $\tfrac35+\tfrac47=\tfrac{3\cdot7+4\cdot5}{35}=\tfrac{21+20}{35}=\tfrac{41}{35}$; $\tfrac{-5}{8}+\tfrac28=\tfrac{-3}{8}$; $\tfrac{-5}2+\tfrac37=\tfrac{(-5)7+2\cdot3}{14}=\tfrac{-29}{14}$; $\tfrac3{-4}+\tfrac57=\tfrac{21-20}{-28}=\tfrac1{-28}$.
*Consequence:* the sum of positive rationals is positive; the sum of negative rationals is negative.

**Properties of $0$ and negatives for rationals.**
- $\dfrac0n=0$ for $n\ne0$: by cross-multiplying, $0\cdot1=0\cdot n$.
- $0+a=a+0=a$: write $a=m/n$; $\tfrac0n+\tfrac mn=\tfrac{0+m}{n}=\tfrac mn$.
- $\dfrac{-m}{n}+\dfrac mn=\dfrac{-m+m}{n}=\dfrac0n=0$, so $\dfrac{-m}{n}=-\dfrac mn$ (N 3). With the earlier remark, $-\dfrac mn=\dfrac{-m}{n}=\dfrac m{-n}$ (boxed in the book: the minus sign moves freely).
- A rational is **negative** if it equals $-\tfrac mn$ with $m,n$ positive. The sum of negative rationals is negative: Lang leaves it to the reader (check with the addition formula).
- Commutativity and associativity of addition hold for rationals (*accepted without proof*, as for integers).

**Transfer principle.**
*Statement:* anything in §2/§3 proved using only commutativity, associativity, distributivity, $0+a=a$, $a+(-a)=0$, $1a=a$ remains valid for rational numbers (and, later, for any number system with these rules). So N 3, N 4, N 5, $0a=0$, N 7, N 8, N 10, the square formulas, and the exercises of §2, §3 all hold in $\mathbb{Q}$.
*Example:* $(\tfrac12+\tfrac13)^2=\tfrac14+2\cdot\tfrac16+\tfrac19$.

**Multiplication of rational numbers.**
*Statement:* $\dfrac mn\cdot\dfrac rs=\dfrac{mr}{ns}$.
*Proof:* given as the definition (rule) in the book.
*Powers:* $\left(\dfrac mn\right)^k=\dfrac{m^k}{n^k}$ for positive integer $k$.
*Example:* $\tfrac27\cdot\tfrac{11}{16}=\tfrac{2\cdot11}{7\cdot2\cdot8}=\tfrac{11}{56}$ (cancel before multiplying); $\tfrac{-4}{5}\cdot\tfrac7{-3}=\tfrac{(-4)7}{5(-3)}=\tfrac{28}{15}$.
*Application (Lang's):* a substance halves every 10 min; $20$ g after $50$ min: $(\tfrac12)^5\cdot20=\tfrac{20}{32}=\tfrac58$ g.

**Basic multiplication rules in $\mathbb{Q}$.** $1a=a$, $0a=0$, commutativity, associativity, distributivity (*assumed*). Hence the transfer principle applies to all of §3.
*Example (solving, Lang's):* $3a-1=7\Rightarrow3a=8\Rightarrow a=\tfrac83$; $\tfrac{3x-7}2+4=2x\Rightarrow3x-7+8=4x\Rightarrow x=1$; $2(x-3)=7\Rightarrow 2x-6=7\Rightarrow 2x=13\Rightarrow x=\tfrac{13}{2}$ (also $x=\tfrac72+3=\tfrac72+\tfrac62$).

**Theorem 4 ($\sqrt2$ is irrational).**
*Statement:* there is no positive rational number whose square is $2$.
*Proof (Lang's):*
1. Suppose $(m/n)^2=2$ with $m/n$ in lowest form (Theorem 3), so $m,n$ are not both even.
2. Then $m^2=2n^2$, so $m^2$ is even.
3. By the Corollary of Theorem 2, $m$ is even: $m=2k$.
4. $m^2=4k^2=2n^2$; cancel $2$: $n^2=2k^2$.
5. So $n^2$ is even, hence $n$ is even (Corollary again).
6. Both $m,n$ are even, contradicting lowest form. So no such rational exists.
*Intuition:* a fraction cannot be both in lowest form and have an even numerator and denominator; "infinite descent" is hiding here.
*Consequence:* any positive $a$ with $a^2=2$ must be irrational.
*Example (the approximation game, Lang's):* $(1.4)^2=1.96<2$, $(1.5)^2=2.25>2$, $(1.41)^2=1.9881$, $(1.42)^2=2.0164$. Rational numbers get squares arbitrarily near $2$ but never exactly $2$.

### §6. Multiplicative inverses

**Definitions.**
- **Multiplicative inverse** of a rational $a\ne0$: the number $a^{-1}$ with $a^{-1}a=aa^{-1}=1$.
- For rational numbers $a,b$ with $b\ne0$: $\dfrac ab$ or $a/b$ means $b^{-1}a=ab^{-1}$.

**Existence of inverses.**
*Statement:* if $a=m/n\ne0$ ($m,n$ nonzero integers) then $a^{-1}=n/m$.
*Proof (Lang's):* $\dfrac mn\cdot\dfrac nm=\dfrac{mn}{nm}=1$.
*Intuition:* this is the property integers lack (no integer inverse of $2$).
*Example:* $(\tfrac12)^{-1}=2$; $(\tfrac37)^{-1}=\tfrac73$.

**Uniqueness of the inverse.**
*Statement:* if $ab=1$ then $b=a^{-1}$.
*Proof (Lang's):*
1. Multiply $ab=1$ by $a^{-1}$: $a^{-1}ab=a^{-1}\cdot1=a^{-1}$.
2. The left side is $(a^{-1}a)b=1b=b$ (associativity).
3. So $b=a^{-1}$.

**No zero divisors.**
*Statement:* if $ab=0$ then $a=0$ or $b=0$.
*Proof (Lang's):*
1. Suppose $a\ne0$. Multiply $ab=0$ by $a^{-1}$: $a^{-1}ab=0\cdot a^{-1}=0$.
2. The left side is $1\cdot b=b$.
3. So $b=0$.
*Example:* $(x-1)(x-3)=0\Rightarrow x=1$ or $x=3$.

**Cross-multiplication (general form).**
*Statement:* $a,b,c,d$ rational, $b\ne0$, $d\ne0$. $\dfrac ab=\dfrac cd$ if and only if $ad=bc$.
*Proof (Lang's):*
1. ($\Rightarrow$) $\tfrac ab=\tfrac cd$ means $b^{-1}a=d^{-1}c$. Multiply by $db$: $dbb^{-1}a=bdd^{-1}c$.
2. Since $bb^{-1}a=1a=a$ and $dd^{-1}c=c$ (commutativity, associativity), we get $da=bc$, i.e. $ad=bc$.
3. ($\Leftarrow$) Suppose $ad=bc$. Multiply by $b^{-1}d^{-1}$ ($=d^{-1}b^{-1}$): $add^{-1}b^{-1}=d^{-1}b^{-1}bc$.
4. This gives $ab^{-1}=d^{-1}c$, i.e. $a/b=c/d$.
*Intuition:* clear both denominators at once. (Lang's remark: some authors take this rule as the definition of the inverse; §5 states it for integers, §6 derives it from inverses.)
*Example:* $\dfrac{3}{x-1}=2\Leftrightarrow 3=2(x-1)=2x-2\Leftrightarrow 5=2x$, so $x=\tfrac52$. Also $\dfrac{4+x}{\frac12x}=5\Leftrightarrow 4+x=\tfrac{5x}2\Leftrightarrow 8+2x=5x$, so $x=\tfrac83$.

**Cancellation law for addition (exercise 22 of §2, not proved in the text).** If $a+b=a+c$ then $b=c$ (add $-a$). Also exercise 23: $a+b=a$ implies $b=0$.

**Cancellation law for multiplication.**
*Statement:* $a\ne0$; if $ab=ac$ then $b=c$.
*Proof (Lang's):* multiply by $a^{-1}$: $a^{-1}ab=a^{-1}ac$, so $b=c$.
*Example:* $7x=7\cdot3\Rightarrow x=3$.

**Cancellation for fractions of rationals.**
*Statement:* $a,b,c$ rational, $a\ne0$, $c\ne0$: $\dfrac{ab}{ac}=\dfrac bc$.
*Proof (Lang's):* cross-multiply: $abc=bac$ by commutativity and associativity.

**Sum of fractions with rational entries.**
*Statement:* $b,d\ne0$: $\dfrac ab=\dfrac{ad}{bd}$, $\dfrac cd=\dfrac{bc}{bd}$, and $\dfrac ab+\dfrac cd=\dfrac{ad+bc}{bd}$.
*Proof (Lang's):* first two from cancellation. For sums with the same denominator: $\tfrac xb+\tfrac yb=b^{-1}x+b^{-1}y=b^{-1}(x+y)=\tfrac{x+y}{b}$ by distributivity. Combine with common denominator $bd$.
*Example:* $\dfrac1{x-y}+\dfrac1{x+y}=\dfrac{(x+y)+(x-y)}{(x-y)(x+y)}=\dfrac{2x}{x^2-y^2}$, assuming $x\ne\pm y$ (Lang's tacit-nonzero-denominator remark).

**Worked equation (Lang's).** $\dfrac{3x+1}{2x-5}=4$ with $2x-5\ne0$: cross-multiply, $3x+1=4(2x-5)=8x-20$, so $5x=21$, $x=\tfrac{21}5$.

**Formula $d=st$ and word problems (Lang's).**
- Constant speed: distance $d$, speed $s$, time $t$ satisfy $d=st$, so $s=d/t$ (e.g. $5\,\mathrm{mi}$ in $\tfrac12$ hr gives $10$ mi/hr).
- Trip: $8$ hr, $400$ mi, $60$ mph on freeway, $30$ mph in towns, $x$ hr in towns: $30x+60(8-x)=400\Rightarrow 80=30x\Rightarrow x=\tfrac83$ hr.
- Antifreeze: $8$ qt, $40\%$ antifreeze, drain $x$, refill with pure antifreeze to reach $90\%$: $\tfrac{40}{100}(8-x)+x=\tfrac{90}{100}\cdot8$, so $\tfrac{60}{100}x=\tfrac{50}{100}\cdot8$, so $x=\tfrac{400}{60}=\tfrac{20}3=6\tfrac23$ qt.

### Recall prompts — Chapter 1
1. State N 1–N 3 as axioms/rules and prove N 3 ($a+b=0\Rightarrow b=-a$), then deduce $a=-(-a)$ (N 4).
2. Prove $-(a+b)=-a-b$ (N 5) and use it to prove that a sum of two negative integers is negative.
3. Prove $0a=0$ from distributivity, $1a=a$, $0+a=a$ and additive inverses. Which step uses which rule?
4. Prove $(-1)a=-a$, then $-(ab)=(-a)b$, and then $(-a)(-b)=ab$. Derive "negative times negative is positive".
5. Prove the three square formulas $(a\pm b)^2$ and $(a+b)(a-b)$ from distributivity and commutativity only.
6. Prove that the square of an odd integer is odd, and deduce the Corollary ($a^2$ even $\Rightarrow$ $a$ even).
7. Prove that every positive rational has a lowest form (greatest common divisor argument), and say where "greatest" is used.
8. Prove that there is no rational with square $2$; point to exactly where the Corollary of Theorem 2 and Theorem 3 enter.
9. Prove cross-multiplication for rationals from inverses (both directions), and the cancellation law $ab=ac,\ a\ne0\Rightarrow b=c$.
10. Prove: $ab=0\Rightarrow a=0$ or $b=0$; and $ab=1\Rightarrow b=a^{-1}$. Then derive $\tfrac mn+\tfrac rs=\tfrac{ms+nr}{ns}$ from the common-denominator and same-denominator cases.

## Chapter 2 — Linear Equations

> We learn to solve systems of linear equations in two and three unknowns by elimination: combine equations so that one unknown disappears, solve the smaller system, then back-substitute. Used later for intersecting lines (Chapter 12) and wherever several conditions on several numbers must hold at once.

### §1. Equations in two unknowns

**Definitions.**
- **Elimination method**: multiply the equations by suitable numbers so that the coefficients of one unknown agree (or are opposite), then subtract (or add) to get one equation in one unknown.
- A **system** may have exactly one solution, none, or (in degenerate cases) many; "usually" it has one.

**Method (elimination).**
*Statement:* To solve a system of two equations in $x,y$, eliminate one unknown, solve the resulting equation in the other, then substitute back.
*Proof (Lang's, on the example):*
1. System: (1) $2x+y=1$, (2) $3x-2y=4$.
2. Multiply (1) by 3 and (2) by 2: $6x+3y=3$, $6x-4y=8$.
3. Subtract the second from the first: $3y-(-4y)=3-8$, so $7y=-5$, $y=-5/7$.
4. From (1): $2x=1-y=1+\tfrac57=\tfrac{12}{7}$, so $x=\tfrac{6}{7}$ ($=\tfrac{12}{14}$).
5. Variation: eliminate $y$ instead. Multiply (1) by 2: $4x+2y=2$; add to (2): $7x=6$, $x=6/7$. Same answer.
*Intuition:* each step replaces the system by an equivalent one, so nothing is lost or invented.
*Example:* the above; check: $2\cdot\frac67-\frac57=1$ and $3\cdot\frac67+2\cdot\frac57=4$.

**Remark (no solution).**
*Statement:* A system may have no solution, e.g. $2x-y=5,\ 2x-y=7$ (obviously inconsistent), and $2x-y=5,\ 6x-3y=7$.
*Proof (Lang's):* any solution of $6x-3y=7$ also solves $2x-y=7/3$ (divide by 3); it cannot also satisfy $2x-y=5$.
*Intuition:* two parallel lines never meet (Chapter 12: each equation is a line, the solution is the intersection point).

**Remark (necessity and sufficiency).**
*Statement:* Elimination shows that if $x,y$ satisfy the system, they must have the values found. Conversely those values are solutions; check it by substitution each time. (Lang: Exercises 9-10 make "usually" precise via $ad-bc\ne0$; the general proof is Exercise 11.)

**Application (two-unknown word problem).**
*Example:* 8 hr, 400 mi, 60 mph on freeway, 30 mph in town. Let $x$ = hours on freeway, $y$ = hours in town.
1. $x+y=8$.
2. $60x+30y=400$.
3. Multiply the first by 60 and subtract the second: $60y-30y=480-400$, so $30y=80$.
4. $y=8/3$ hr in towns.

### §2. Equations in three unknowns

**Method.**
*Statement:* Same pattern: eliminate one unknown from two different pairs of equations, getting two equations in two unknowns; solve those; back-substitute. Choose the order of elimination to make the arithmetic easy.
*Proof (Lang's, on the example):*
1. System: (1) $3x+2y+4z=1$, $-x+y+2z=2$, $x-3y+z=-1$.
2. Add the 2nd and 3rd (the $x$ cancels): (2) $-2y+3z=1$.
3. Multiply the 2nd by 3 and add to the 1st: (3) $5y+10z=7$.
4. Multiply (2) by 5 and (3) by 2 and add ($y$ cancels): $15z+20z=5+14$, so $35z=19$, $z=19/35$.
5. From (2): $2y=3z-1=\frac{57-35}{35}=\frac{22}{35}$, so $y=11/35$.
6. From the 3rd equation: $x=3y-z-1=\frac{33-19-35}{35}=-\frac{21}{35}$.
*Misprint:* the book's last line of the computation prints $x=-\tfrac{91}{35}$; the correct value is $-\tfrac{21}{35}$ (as the book's final answer states).
*Result:* $x=-\tfrac{21}{35}$, $y=\tfrac{11}{35}$, $z=\tfrac{19}{35}$.
*Example:* check in the first equation: $\frac{-63+22+76}{35}=1$.

### Recall prompts — Chapter 2
1. Solve $2x+y=1,\ 3x-2y=4$ closed-book by eliminating $x$, then again by eliminating $y$.
2. Why does the elimination argument show "if a solution exists it equals these values", and why must you still check the converse?
3. Show that $2x-y=5,\ 6x-3y=7$ has no solution, using only division by 3.
4. Set up and solve the freeway/town problem with two unknowns; relate it to the one-unknown version.
5. Solve a 3x3 system by choosing an elimination order that produces a 2x2 system quickly.
6. How does a system of two linear equations relate to two lines in the plane?

---

## Chapter 3 — Real Numbers

> The real numbers are all points of the line (equivalently, all decimal expansions). We list the algebraic properties (addition, multiplication), the two positivity axioms, and the assumed existence of roots and fractional powers. From these we derive the inequality rules and the algebra of exponents. Used throughout: distance (square roots), functions, calculus.

### §1. Addition and multiplication

**Definitions.**
- **Real numbers**: the numbers corresponding to all points of the line; "number" means "real number".
- **Additive inverse** $-a$ of $a$: the number with $a+(-a)=0$.
- **Multiplicative inverse** $a^{-1}=1/a$ of $a\neq 0$; $a/b$ means $b^{-1}a$.

**Properties of addition (assumed).**
*Statement:* For all real $a,b,c$: $a+b=b+a$; $a+(b+c)=(a+b)+c$; $0+a=a$; each $a$ has $-a$ with $a+(-a)=0$.

**Properties of multiplication (assumed).**
*Statement:* $ab=ba$; $a(bc)=(ab)c$; $1a=a$; $0a=0$; distributivity $a(b+c)=ab+ac$ and $(b+c)a=ba+ca$.
*Consequence:* all identities proved earlier from these alone hold for reals, e.g. $(a+b)^2=a^2+2ab+b^2$, $(a-b)^2=a^2-2ab+b^2$, $(a+b)(a-b)=a^2-b^2$.

**Uniqueness of the additive inverse.**
*Statement:* If $a+b=0$ then $b=-a$.
*Proof (Lang's):* add $-a$ to both sides of $a+b=0$.

**Existence of the multiplicative inverse (assumed).**
*Statement:* If $a\ne0$ there is a number $a^{-1}$ with $a^{-1}a=aa^{-1}=1$.
*Consequence:* cross-multiplication, cancellation rules etc. carry over, since their proofs used only the basic properties.

**Uniqueness of the multiplicative inverse.**
*Statement:* If $ab=1$ then $b=a^{-1}$.
*Proof (Lang's):* multiply both sides by $a^{-1}$.

*Intuition:* the reals share these rules with the rationals (and even with a two-element system {even, odd}, Exercise 1); what distinguishes reals is the extra numbers (roots etc.).
*Example (ours, not Lang's):* $(2+\sqrt3)(2-\sqrt3)=4-3=1$, so $(2+\sqrt3)^{-1}=2-\sqrt3$ by uniqueness.

### §2. Real numbers: positivity

**Definitions.**
- **Positive**: $a>0$, to the right of 0.
- **Negative**: not positive and not 0; by POS 2, then $-a$ is positive.
- **Square root** $\sqrt a$ ($a>0$): the unique *positive* number whose square is $a$.
- **Absolute value**: $|x|=\sqrt{x^2}$; so $|-3|=3$ and $|a|=a$ for $a>0$.
- **Rationalizing the denominator / numerator**: rewriting a quotient with square roots as an equal quotient with no root in the denominator / numerator.

**POS 1.** *Statement (assumed):* if $a,b$ are positive, so are $ab$ and $a+b$.
**POS 2.** *Statement (assumed):* for each real $a$, exactly one holds: $a$ positive, $a=0$, or $-a$ positive.

**Result: 1 is positive.**
*Proof (Lang's):*
1. By POS 2, either $1$ or $-1$ is positive. Suppose $1$ is not, so $-1$ is positive.
2. By POS 1, $(-1)(-1)$ is positive.
3. But $(-1)(-1)=1$, so $1$ is positive, contradicting the supposition. Hence $1>0$.
4. By POS 1, $1+1=2$, $2+1=3,\dots$ are positive.

**Sign rules (Exercises 1-3, stated).**
*Statement:* positive$\times$negative is negative; negative$\times$negative is positive; $a>0\Rightarrow 1/a>0$; $a<0\Rightarrow 1/a<0$. *Proof:* left to reader.

**Square roots (existence assumed).**
*Statement:* if $a>0$ there is $b$ with $b^2=a$. Then (with POS 2) there are exactly two numbers whose square is $a$: $b$ and $-b$, one positive.
*Proof (Lang's, for $a=2$):*
1. Let $b^2=2$ and $x^2=2$.
2. Then $x^2-b^2=0$, i.e. $(x+b)(x-b)=0$.
3. So $x+b=0$ or $x-b=0$, i.e. $x=-b$ or $x=b$.
4. Conversely $(-b)^2=(-b)(-b)=b^2=2$.
5. By POS 2 exactly one of $\pm b$ is positive; call it $\sqrt2$. Same argument for any $a>0$.
*Consequences:* solutions of $x^2=a$ are $x=\pm\sqrt a$. If $x^2=y^2$ then $x=y$ or $x=-y$ (not necessarily $x=y$). Always $\sqrt{x^2}\ge 0$, e.g. $\sqrt{(-3)^2}=3$. With Chapter 1, Theorem 4 (§5): $\sqrt2$ exists as a real number but is irrational.

**Absolute-value equations.**
*Example:* $|x+5|=2$ iff $x+5=2$ or $x+5=-2$, so $x=-3$ or $x=-7$.

**Rationalizing (technique).**
*Rule used:* $(x+y)(x-y)=x^2-y^2$ (conjugate trick). Also $\frac1{\sqrt2}=\frac{\sqrt2}{2}$ because $2=\sqrt2\sqrt2$ (cross-multiplication). Lang: not always useful; sometimes the root in the denominator is preferable.
*Example 1 (denominator):* $\dfrac{3}{2+\sqrt5}$. Multiply top and bottom by $2-\sqrt5$:
$\dfrac{3(2-\sqrt5)}{(2+\sqrt5)(2-\sqrt5)}=\dfrac{6-3\sqrt5}{2^2-(\sqrt5)^2}=\dfrac{6-3\sqrt5}{-1}=-6+3\sqrt5$.
*Example 2 (numerator):* $x,x+h>0$. Multiply by $\sqrt{x+h}+\sqrt x$:
$\dfrac{\sqrt{x+h}-\sqrt x}{h}=\dfrac{(x+h)-x}{h(\sqrt{x+h}+\sqrt x)}=\dfrac{h}{h(\sqrt{x+h}+\sqrt x)}=\dfrac1{\sqrt{x+h}+\sqrt x}$.
(This is the form met in calculus.)

### §3. Powers and roots

**Definitions.**
- $a^n$ ($n$ positive integer): product of $n$ copies of $a$; $a^{m+n}=a^ma^n$ for positive integers.
- **$n$-th root** $a^{1/n}=\sqrt[n]a$ of $a>0$: the unique positive $r$ with $r^n=a$ (existence and uniqueness assumed).

**Theorem 1.**
*Statement:* for positive $a,b$: $(ab)^{1/n}=a^{1/n}b^{1/n}$.
*Proof (Lang's):*
1. Let $r=a^{1/n}$, $s=b^{1/n}$, so $r^n=a$, $s^n=b$.
2. $(rs)^n=r^ns^n=ab$.
3. So $rs$ is the $n$-th root of $ab$.

**Fractional powers (assumed).** For $a>0$ and rational $x$ there is a positive number $a^x$, equal to the $n$-th power when $x=n$ and the $n$-th root when $x=1/n$, with:
**POW 1.** $a^{x+y}=a^xa^y$.
**POW 2.** $(a^x)^y=a^{xy}$.
**POW 3.** $(ab)^x=a^xb^x$ for $a,b>0$.

**Consequence: $a^0=1$.**
*Proof (Lang's):*
1. Let $b=a^0$. Then $a=a^1=a^{0+1}=a^0a^1=ba$ (POW 1).
2. Multiply by $a^{-1}$: $1=aa^{-1}=baa^{-1}=b$.

**Consequence: negative powers.**
*Statement:* for positive rational $x$: $a^{-x}=1/a^x$.
*Proof (Lang's):* $1=a^0=a^{x+(-x)}=a^xa^{-x}$ (POW 1), so $a^{-x}$ is the multiplicative inverse of $a^x$. This justifies the notation $a^{-1}$.
*Example:* $a^{-3}=(a^3)^{-1}=1/a^3$; $2^{-4}=1/2^4=1/16$.

**Consequence: rational exponents.**
*Statement:* for positive integers $m,n$: $a^{m/n}=(a^m)^{1/n}=(a^{1/n})^m$.
*Proof (Lang's):* write $\frac mn=m\cdot\frac1n=\frac1n\cdot m$ and use POW 2.
*Examples:* $8^{2/3}=(8^{1/3})^2=2^2=4$. $(\sqrt2)^3=2\sqrt2=2^{3/2}$. $\left(\frac{25}{9}\right)^{3/2}=\frac{25^{3/2}}{9^{3/2}}=\frac{125}{27}$ (POW 3). $(\sqrt2)^{3/4}=(2^{1/2})^{3/4}=2^{3/8}$.

**Remark (what is left out).**
Irrational exponents like $2^{\sqrt2}$ can be defined keeping POW 1-2 but are postponed. Policy: when we need a real number to exist, we assume it and postpone the proof (the "etc." in "roots, exponents, etc." is made precise only in advanced courses).

### §4. Inequalities

**Definitions.**
- $a>b$ means $a-b>0$; $a<0$ means $-a>0$; $b<a$ means $a>b$; $a\ge b$ means "$a>b$ or $a=b$".
- Geometrically $a>b$: $a$ is to the right of $b$.
- **Interval**, for $a\le b$: $a<x<b$ (**open**), $a\le x\le b$ (**closed**), $a\le x<b$ or $a<x\le b$ (**half open**). $a,b$ are the **endpoints**.
- **Infinite interval**: all $x>a$, $x\ge a$, $x<a$ or $x\le a$.

**IN 1.** *Statement:* $a>b,\ b>c\Rightarrow a>c$.
*Proof (Lang's):*
1. $a-b>0$ and $b-c>0$ by definition.
2. By POS 1 the sum $(a-b)+(b-c)>0$.
3. Cancelling $b$: $a-c>0$, i.e. $a>c$.

**IN 2.** *Statement:* $a>b,\ c>0\Rightarrow ac>bc$ (multiplying by a positive number keeps the inequality).
*Proof (Lang's):*
1. $a-b>0$.
2. By POS 1 (product), $(a-b)c>0$.
3. By distributivity $(a-b)c=ac-bc$, so $ac-bc>0$, i.e. $ac>bc$.

**IN 3.** *Statement:* $a>b,\ c<0\Rightarrow ac<bc$ (multiplying by a negative reverses the inequality).
*Proof:* left as an exercise in the book (Exercise 1). (Our sketch, not Lang's: $-c>0$, so $(a-b)(-c)>0$, i.e. $bc-ac>0$.)
*Example:* $1<3$; multiply by $-2$: $-2>-6$.

**Easy consequences (Lang leaves them as Exercises 2-8, "used constantly without further reference"):** adding/subtracting the same number to both sides preserves $<$; $0<a<b,\ c<d,\ c>0\Rightarrow ac<bd$; cross-multiplication of inequalities: for $b,d>0$, $\frac ab<\frac cd\iff ad<bc$; $0<a<b\Rightarrow a^n<b^n$ and $a^{1/n}<b^{1/n}$; $0<x<y\Rightarrow 1/y<1/x$.

**Solving linear inequalities.**
*Example:* $2x-4>5\iff 2x>9\iff x>9/2$.

**Rational inequality by cases.**
*Example:* $\dfrac{3x+5}{x-4}<2$ (undefined at $x=4$).
1. Case $x>4$: $x-4>0$, so equivalent to $3x+5<2(x-4)=2x-8$, i.e. $x<-13$. Incompatible with $x>4$: no solutions.
2. Case $x<4$: $x-4<0$, multiply and reverse: $3x+5>2x-8$, i.e. $x>-13$.
3. Solution set: $-13<x<4$, an interval with endpoints $-13$ and $4$.

### Recall prompts — Chapter 3
1. List the properties of addition and multiplication of real numbers; prove uniqueness of $-a$ and of $a^{-1}$.
2. State POS 1 and POS 2 and prove from them that $1>0$.
3. Prove that $x^2=2$ has exactly two real solutions and define $\sqrt2$ by convention. What is $\sqrt{(-3)^2}$ and why?
4. Rationalize $\frac{3}{2+\sqrt5}$ and $\frac{\sqrt{x+h}-\sqrt x}{h}$, naming the identity used.
5. State POW 1-3; derive $a^0=1$ and $a^{-x}=1/a^x$ from them.
6. Prove $(ab)^{1/n}=a^{1/n}b^{1/n}$ and compute $8^{2/3}$, $(25/9)^{3/2}$.
7. State IN 1-3 and prove IN 1 and IN 2 from POS 1.
8. Solve $\frac{3x+5}{x-4}<2$, explaining why the two cases are needed.
9. Solve $|x+5|=2$ and explain "if $x^2=y^2$ then $x=\pm y$".
10. Name the four interval types and the infinite intervals.

---

## Chapter 4 — Quadratic Equations

> We solve $ax^2+bx+c=0$ by completing the square, giving the quadratic formula. It is the next case after linear equations, used for intersecting lines with circles, parabolas, etc. (Chapter 12), and extended to complex roots later.

### Completing the square (examples)

**Definitions.**
- **Completing the square**: add a number to both sides so the left side becomes a square $(x-s)^2=x^2-2sx+s^2$.

*Example 1:* $x^2-3x+1=0$.
1. Equivalent to $x^2-3x=-1$.
2. Need $2s=3$, so $s=3/2$; add $(3/2)^2=9/4$: $x^2-3x+\tfrac94=-1+\tfrac94=\tfrac54$.
3. Left side is $(x-\tfrac32)^2$, so $(x-\tfrac32)^2=\tfrac54$.
4. Take roots: $x-\tfrac32=\pm\tfrac{\sqrt5}{2}$.
5. $x=\dfrac{3\pm\sqrt5}{2}$.

*Example 2:* $x^2+2x+2=0$. Then $x^2+2x=-2$; add 1: $(x+1)^2=-1$. A negative number is not a real square: no real solution.

*Example 3:* $2x^2-3x-5=0$.
1. Divide by 2: $x^2-\tfrac32x=\tfrac52$.
2. $2s=\tfrac32$, $s=\tfrac34$; add $\tfrac9{16}$: $(x-\tfrac34)^2=\tfrac52+\tfrac9{16}=\tfrac{49}{16}$.
3. $x-\tfrac34=\pm\tfrac74$, so $x=\tfrac{3\pm7}{4}$: $x=\tfrac52$ or $x=-1$.

### The quadratic formula

**Theorem (Quadratic formula).**
*Statement:* Let $a,b,c$ be real, $a\ne0$. The solutions of $ax^2+bx+c=0$ are
$$x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}$$
provided $b^2-4ac\ge0$. If $b^2-4ac<0$ there is no real solution.
*Proof (Lang's):*
1. The equation is equivalent to $ax^2+bx=-c$, and (divide by $a$) to $x^2+\frac bax=-\frac ca$.
2. To complete the square: $x^2+\frac bax=x^2+2sx$ gives $s=\frac b{2a}$. Add $s^2=\frac{b^2}{4a^2}$:
$\left(x+\frac b{2a}\right)^2=\frac{b^2}{4a^2}-\frac ca=\frac{b^2-4ac}{4a^2}$.
3. If $b^2-4ac<0$ the right side is negative, so it is not the square of a real number: no real solution.
4. If $b^2-4ac\ge0$, take roots: $x+\frac b{2a}=\pm\frac{\sqrt{b^2-4ac}}{2a}$.
5. Solve: $x=-\frac b{2a}\pm\frac{\sqrt{b^2-4ac}}{2a}=\frac{-b\pm\sqrt{b^2-4ac}}{2a}$.
*Intuition:* the sign of $b^2-4ac$ decides the number of real roots (the name "discriminant" is ours; the book does not use it here). Lang urges memorising the formula.
*Example 5:* $2x^2+3x-4=0$: $x=\dfrac{-3\pm\sqrt{9+32}}{4}=\dfrac{-3\pm\sqrt{41}}{4}$.

**Remark (number of solutions).**
If $b^2-4ac=0$: exactly one solution $x=-b/2a$. If $>0$: exactly two, $\frac{-b+\sqrt{b^2-4ac}}{2a}$ and $\frac{-b-\sqrt{b^2-4ac}}{2a}$.

*Example 4:* $3x^2-2x+1=0$: $b^2-4ac=4-12=-8<0$, no real solution.

**Remark (complex numbers).**
The proof only used addition, multiplication and square roots. In a larger number system containing square roots of negatives (complex numbers, later chapter) the formula gives the solutions in all cases.

### Recall prompts — Chapter 4
1. Solve $x^2-3x+1=0$ by completing the square without the formula.
2. Derive the quadratic formula from $ax^2+bx+c=0$, indicating where $a\ne0$ is used.
3. What does the sign of $b^2-4ac$ say about the number of real solutions? Give an equation for each case.
4. Solve $2x^2-3x-5=0$ both by completing the square and by the formula.
5. Why does the derivation still work in a larger number system?

---

## Interlude — On Logic and Mathematical Expressions

> A short guide to how Lang writes and reads mathematics: what a proof is, how "if ... then" works, proof by contradiction, how to write complete sentences, what "equality" means, and sets and indexing notation. No technical results, but the conventions are used everywhere after.

### §1. On reading books

**Definitions.** None. Lang's advice (summary): a book is a linear distortion of a non-linear subject. Read in any order: from the middle, back and forth looking up definitions; from the start skipping the obvious; or skim theorem statements first and then go through systematically. Experiment; take courses in book order for safety.

### §2. Logic

**Definitions.**
- **Proof**: a sequence of statements each either assumed or following from earlier ones by an (assumed) rule of deduction; the rules are common sense.
- **Implication** "If $A$, then $B$".
- **Converse** of "If $A$, then $B$" is "If $B$, then $A$".
- **Equivalent assertions** $A,B$: $A$ is true if and only if $B$ is true.
- **Equality**: the objects are the same object (e.g. $2+3=6-1$ both are 5).
- **Equivalent** (for assertions): $A,B$ equivalent means "$A$ true iff $B$ true", e.g. "$x$ satisfies $2x+5=3$" and "$x=-1$". Lang uses "equivalent" in other contexts too, explained as needed.
- **Equation**: symbols such as $2x=5$ alone; they have meaning only inside a complete sentence that qualifies $x$.

**Rule: implication and converse.**
*Statement:* A statement and its converse need not both be true (Lang shows this by examples below). Example: "If $2x=5$ then $x=5/2$" and its converse are both true.
*Example:* "If $x=-3$ then $x^2=9$" is true (Lang); the converse "if $x^2=9$ then $x=-3$" is false ($x$ may be 3).

**Rule: if and only if.**
*Statement:* "$A$ if and only if $B$" means both "If $A$ then $B$" and its converse. So $2x=5$ iff $x=5/2$ is true; "$x^2=9$ iff $x=-3$" is false.
*Convention:* "$A$ only if $B$" means "If $A$ then $B$", but Lang never uses "only if" alone, only inside "if and only if", since English tends to hear "if $B$ then $A$".
*Examples:* "If two lines are perpendicular, they meet" is true; the converse is false. "Two circles are congruent iff they have the same radius" is true.

**Rule: proof by contradiction.**
*Statement:* To prove $A$, suppose $A$ is false, reason to an absurdity (or a contradiction with a known truth), and conclude $A$ is true.
*Proof (Lang's example):* $\sqrt2$ is irrational: assume $\sqrt2$ is a fraction in lowest form; show numerator and denominator are both even, contradicting lowest form. Hence $\sqrt2$ is not rational (Chapter 1, Theorem 4).

**Rule: quantifiers and qualified statements.**
*Statement:* An equation without qualification is not a statement. We must say what $x$ ranges over and how (existence or all). For $2x=5$:
- (a) "There exists a number $x$ with $2x=5$" true.
- (b) "For all numbers $x$, $2x=5$" false.
- (c) "There is no number $x$ with $2x=5$" false.
- (d) "If $x$ is real and $2x=5$ then $x<7$" true.
- (e)-(g) "Determine / express / solve for $x$ ..." are instructions, made precise by context (e.g. (f): express all rational $x$ with $2x=5$ as $m/n$).
*Qualified forms:* (4) "If $x$ is real and $2x=5$, then $x=5/2$"; (5) "Let $x$ be real. Then $2x=5$ iff $x=5/2$."
*Example:* "There exists a rational $x$ with $x^2=2$" is false; "There exists a real $x$ with $x^2=2$" is true. The set matters.

**Rule: write complete sentences.**
*Statement:* Isolated symbols such as $2x=5$ are not assertions; many mistakes come from leaving them unqualified.

**Rule: equality versus equivalence versus congruence.**
*Statement:* We do not use "equal" loosely as in elementary geometry. Two congruent triangles are not equal (different objects), but their areas are equal; two segments are not equal but their lengths may be. Use "correspond" / "represent" when tying a physical quantity to a mathematical one. Two levels of argument: strictly logical (axioms, deductions) and mixed physical/intuitive; both are used.

### §3. Sets and elements

**Definitions.**
- **Set**: a collection of objects; the objects are its **elements**.
- $\mathbf R$: the set of all real numbers; "$x\in\mathbf R$" means "$x$ is a real number".
- **Subset**: $S\subseteq T$ if every element of $S$ is an element of $T$. E.g. integers $\subseteq$ rationals $\subseteq$ $\mathbf R$.
- **Convention**: every set is a subset of itself.
- **Empty set**: a set with no elements. E.g. $\{x: x<0\text{ and }x>0\}$, or $\{x: 2x>1\text{ and }x<-3\}$; also no positive $x$ has $\frac{2x}{x+1}>1$ and $x<\frac12$.

**Rule: set equality.**
*Statement:* To prove $S=S'$, show $S\subseteq S'$ and $S'\subseteq S$.
*Proof (Lang's example):* Let $S=\{x:1\le x\le2\}$, $T=\{5x: x\in S\}$, $T'=\{y:5\le y\le10\}$. Claim $T=T'$.
1. If $x\in S$ then $5\le5x\le10$, so $T\subseteq T'$.
2. If $y\in T'$, put $x=y/5$; then $1\le x\le2$, so $x\in S$ and $y=5x\in T$. So $T'\subseteq T$.
3. Hence $T=T'$.

### §4. Indices

**Definitions.**
- **Convention**: "Let $x,y$ be numbers" allows $x=y$; exclude it explicitly ("distinct", $x\ne y$). Same for points $P,Q$.
- **Indices / subscripts**: $x_1,\dots,x_n$; possibly $x_i=x_j$ for $i\ne j$.
- **Finite sequence** $\{x_1,\dots,x_n\}$: an object $x_j$ for each integer $1\le j\le n$ (sometimes $0\le j\le n$).

*Example:* $x_j=(-1)^j$: $x_1=-1,\ x_2=1,\ x_3=-1,\ x_n=(-1)^n$.
*Example:* a polynomial $a_nx^n+\dots+a_0$ has coefficient sequence $a_0,\dots,a_n$; for $4x^3-2x^2+4x-5$: $a_0=-5,\ a_1=4,\ a_2=-2,\ a_3=4$.

### §5. Notation

**Definitions (conventions Lang follows).**
- Lower-case $a,b,c,x,y,z$: numbers; $m,n$: integers (except as abbreviations, e.g. $m(A)$ = measure of angle $A$).
- Capitals $A,B,P,Q,X,Y$: mostly points (also angles $A,B$, but $P,Q$ reserved for points; do not mix in one section).
- $f,g,F,G$: functions/mappings. (a),(b),(c) label exercises, not numbers.
- Always say what a letter stands for; consistent patterns help reading. Notation can be too slick; correct errors for yourself.

### Recall prompts — Interlude
1. State the converse of "If $x=-3$ then $x^2=9$" and decide truth of both; what does "iff" require?
2. Why does Lang never use "only if" alone?
3. Describe proof by contradiction and apply it to $\sqrt2$.
4. Give three quantified readings of "$2x=5$" and their truth values; why is the bare equation not a statement?
5. Contrast "equal", "equivalent", "congruent" with Lang's triangle/segment examples.
6. Define subset and empty set; prove $\{5x:1\le x\le2\}=\{y:5\le y\le10\}$ via two inclusions.
7. Can "Let $x,y$ be numbers" mean $x=y$? How do you exclude it?
8. Write the coefficient sequence of $4x^3-2x^2+4x-5$.

# Part Two — Intuitive Geometry (Chapters 5–7)

> **Note on the Part Two intro (book pp. 105–106).** Lang does plane geometry in two styles. Here (Part II) the style is **geometric**: we state explicitly a small stock of intuitive properties of lines, segments, angles, distance, perpendicularity, area, and *assume* them; then we *prove* the rest. A proof that uses properties of the plane this way is a **geometric proof**. In Part III, points get coordinates and the same concepts are *defined* by numbers; a proof using only properties of real numbers is an **analytic proof**. Lang's thesis: classical geometry rests on two pillars, the **Pythagoras theorem** and **congruence** (isometries), not on "constructions" and tangled diagrams (example: "the shortest distance from $P$ to a line is the perpendicular segment" is obvious from Pythagoras). The geometric approach also introduces *mappings* and perpendicularity, the seed of linear algebra. Mix both approaches freely; the Greeks stalled by refusing numbers, so do not fall into the opposite inhibition.


---

## Chapter 5 — Distance and Angles

> We fix the basic vocabulary of plane geometry: distance (with its axioms), segments, rays, circles and discs, angles and how to measure them in degrees via area, triangles, rectangles, and the first real theorem, Pythagoras. Everything in Chapters 6–7 (isometries, congruence, area, $\pi$) is built on the assumptions listed here (DIST, SEG, RT, PD, rectangle area).

### §1. Distance

**Definitions.**
- $d(P,Q)$ = the **distance** between points $P,Q$ of the plane; a number (a unit of length is fixed once and for all).
- **Line $L_{PQ}$**: the unique line through two distinct points $P,Q$ (assumed). **Segment $\overline{PQ}$**: the part of this line between $P$ and $Q$. Its length is $d(P,Q)$.
- **Circle** of center $P$, radius $r>0$: all $Q$ with $d(P,Q)=r$. **Disc**: all $Q$ with $d(P,Q)\le r$. The circle is the boundary of the disc (the two words are not interchangeable).
- Unit remark: a unit of length fixes a unit of area (inch, square inch); we speak of lengths and areas as plain numbers.

**DIST 1 (assumed).** *Statement:* $d(P,Q)\ge 0$, and $d(P,Q)=0$ iff $P=Q$.

**DIST 2 (assumed).** *Statement:* $d(P,Q)=d(Q,P)$.

**DIST 3, triangle inequality (assumed).** *Statement:* $d(P,M)\le d(P,Q)+d(Q,M)$.
*Intuition:* one side of a triangle is at most the sum of the other two.

**SEG 1 (assumed).** *Statement:* $d(P,M)=d(P,Q)+d(Q,M)$ iff $Q$ lies on the segment $\overline{PM}$.
*Intuition:* equality in the triangle inequality happens exactly when the triangle is flat with $Q$ between.

**SEG 2 (assumed).** *Statement:* if $d=d(P,M)$ and $0\le c\le d$, there is a unique point $Q$ on $\overline{PM}$ with $d(P,Q)=c$.
*Intuition:* you can mark off any length along a segment, in exactly one way.

*Example.* $P=(0,0)$, $M$ with $d(P,M)=5$, $c=2$: SEG 2 gives a unique $Q$ on $\overline{PM}$ at distance 2; then $d(Q,M)=3$ by SEG 1, since $5=2+3$.

### §2. Angles

**Definitions.**
- Assumed facts on lines: two distinct points lie on exactly one line; non-parallel lines meet in exactly one point; through $P$ there is a unique line parallel to $L$ ("parallel" is transitive: $L_1\parallel L_2\parallel L_3\Rightarrow L_1\parallel L_3$); through $P$ there is a unique perpendicular to $L$; $L_1\perp L_2$ and $L_2\parallel L_3$ imply $L_1\perp L_3$; $L_1\perp L_2$ and $L_2\perp L_3$ imply $L_1\parallel L_3$.
- **Ray** $R_{PQ}$: starts at $P$ (the **vertex**), passes through $Q$, goes on forever. A ray is determined by its vertex and any other point on it.
- **Angle**: two rays $R_{PQ},R_{PM}$ with the same vertex cut the plane into two regions; *each region* is an angle (Lang's choice, not "union of two rays", so that a measure is built in).
- **$\angle QPM$**: the angle containing the arc from $R_{PQ}$ to $R_{PM}$ going counterclockwise. $\angle MPQ$ is the other one. Order matters.
- **Zero angle**: $Q,M$ on the same ray from $P$ (arc is a point); the other region is the **full angle** (whole plane), not written $\angle QPM$.
- **Straight angle**: $Q,P,M$ on a line, $Q,M$ on opposite sides of $P$.
- **Sector** of a disc $D$ centered at the vertex: the part of the angle lying in $D$.
- **Degree**: the full angle has $360$ degrees. Say angle $A$ (vertex $P$, sector $S$ in a disc $D$ centered at $P$) **has $x$ degrees** ($0\le x\le 360$) when
$$\frac{\text{area of sector } S}{\text{area of disc } D}=\frac{x}{360}.$$
Notation $x^\circ$, $m(A)=x^\circ$. $A\le B$ means $x\le y$.
- **Right angle**: half a straight angle, $90^\circ$.

**Assumed (axiom-like) remark.** The ratio sector/disc does not depend on the radius of $D$. Lang assumes this now ("intuitively clear") and promises a more thorough discussion when he treats area and similar figures. (Our note, not Lang's wording: in Chapter 7 a dilation by $r$ scales both the sector's and the disc's area by $r^2$, which is why the ratio is unchanged.)

**Straight angle $=180^\circ$ (proved from the definition).** *Proof:* a straight angle splits the disc into two sectors of equal area, so the ratio is $1/2=x/360$, so $x=180$. A right angle (half of that) is $90^\circ$.

*Example (sector area).* Disc of radius 2 has area $4\pi$ (assuming area $=\pi r^2$). The sector between $30^\circ$ and $45^\circ$ is a $15^\circ$ angle, so area $=\frac{15}{360}\cdot 4\pi=\frac{\pi}{6}$. In radius 5: $\frac{15}{360}\cdot 25\pi=\frac{5\pi}{24}$. We never need the area of the disc, only the ratio. General: sector of angle $\theta$ in disc of radius $r$ has area $\frac{\theta}{360}\pi r^2$.

### §3. The Pythagoras Theorem

**Definitions.**
- **Triangle $\triangle PQM$**: the three segments $\overline{PQ},\overline{QM},\overline{PM}$ ($P,Q,M$ not collinear). "Area of a triangle" abusively means area of the region it bounds.
- **Right triangle**: one of its angles is a right angle; the sides forming it are the **legs**; the third side is the **hypotenuse**.
- **Rectangle** $PQNM$: four segments, opposite sides parallel, adjacent sides perpendicular. **Square**: rectangle with equal sides.
- Distance between parallel lines: the common length of perpendicular segments (property PD).

**RT (assumed).** *Statement:* if right triangles $\triangle PQM$, $\triangle P'Q'M'$ have corresponding legs of equal length ($PQ=P'Q'$, $PM=P'M'$), then (a) corresponding angles have equal measure, (b) areas are equal, (c) $d(Q,M)=d(Q',M')$.
*Intuition:* the two triangles are congruent (can be slid onto each other). Lang assumes RT rather than build congruence first; Theorem 9 of Ch. 6 puts RT back inside congruence theory.

**PD (assumed).** *Statement:* $L\parallel L'$, $P,Q\in L$, perpendiculars at $P,Q$ meet $L'$ at $P',Q'$. Then $d(P,P')=d(Q,Q')$.
*Consequence:* opposite sides of a rectangle have equal length.

**Rectangle area (assumed).** Rectangle with sides $a,b$ has area $ab$; a square of side $a$ has area $a^2$.

**Theorem 1.** *Statement:* for a right triangle with non-right angles $A,B$: $m(A)+m(B)=90^\circ$.
*Proof (Lang's):*
1. Let $\angle MPQ$ be the right angle, $A$ the angle at $Q$, $B$ the angle at $M$ (Lang's Fig. 5-25); complete to the rectangle $P,Q,N,M$ (line through $M$ parallel to $PQ$, line through $Q$ perpendicular to $PQ$ meet at $N$).
2. Opposite sides are equal: $QN=PM$, $NM=QP$ (PD).
3. So $\triangle QPM$ and $\triangle QNM$ are right triangles with equal legs; by RT(a) the corresponding angles are equal; in particular $\angle NQM$ has the same measure as $B$ (the angle of $\triangle QPM$ at $M$).
4. $A$ and $\angle NQM$ together make up the right angle $\angle NQP$, so $m(A)+m(B)=90^\circ$.
*Intuition:* angle sum of a triangle is $180^\circ$, one angle being $90^\circ$.
*Example:* a right triangle with an angle of $30^\circ$ has the other acute angle $60^\circ$.

**Theorem 2.** *Statement:* a right triangle with legs $a,b$ has area $ab/2$.
*Proof (Lang's):* in the rectangle of step 1 above (sides $a,b$, area $ab$ by assumption), the two triangles $\triangle QPM$, $\triangle QNM$ have equal legs, so equal areas by RT(b); together they make the rectangle; each has area $ab/2$.
*Example:* legs 3 and 4: area $6$.

**Pythagoras Theorem.** *Statement:* right triangle with legs $a,b$ and hypotenuse $c$: $a^2+b^2=c^2$. (**Proved**, from RT, Theorem 1, rectangle area.)
*Proof (Lang's):*
1. Draw the right triangle with right angle at $P$, leg $a$ horizontal. Extend along the line $PM$ to $P_1$ with $MP_1=b$, so $PP_1=a+b$. Erect on $PP_1$ a perpendicular $P_1P_2$ of length $a+b$ and complete the big square of side $a+b$.
2. At each corner of the big square, place a right triangle with legs $a,b$ (first at $M$ along the bottom, then repeat around). We get four right triangles with legs $a,b$.
3. By RT(c) the four hypotenuses all have length $c$: the inner four-sided figure has all sides $c$.
4. Let $A,B$ be the acute angles of the triangle and $C$ an angle of the inner figure at a vertex on the bottom side. At that vertex three angles fill a straight line: $B+C+A=180^\circ$ (RT(a) says the neighbouring angles are $A$ and $B$).
5. By Theorem 1, $A+B=90^\circ$, so $C=90^\circ$. The inner figure is a square of side $c$.
6. Area of big square: $(a+b)^2=a^2+2ab+b^2$. Also = four triangles + inner square $=4\cdot\frac{ab}{2}+c^2=2ab+c^2$.
7. Equate: $a^2+2ab+b^2=2ab+c^2$, so $a^2+b^2=c^2$.
*Intuition:* the same big square cut two ways; the $2ab$ cancels.
*Example:* diagonal of the unit square: $\sqrt{1^2+1^2}=\sqrt2$. Diagonal of $3\times4$ rectangle: $\sqrt{9+16}=5$. Leg 10, hypotenuse 15: $b^2=225-100=125$, $b=\sqrt{125}$.

**Lemma (unnumbered, proved).** *Statement:* if $O$ is on the line through $P,Q$ ($P\ne Q$) and $d(O,P)=d(O,Q)$, then $O$ lies on the segment $\overline{PQ}$ (hence is its midpoint).
*Proof (Lang's):* 1. Suppose $O$ is not on the segment; then $P$ lies on $\overline{OQ}$ or $Q$ lies on $\overline{OP}$. 2. Say $P\in\overline{OQ}$: by SEG 1, $d(O,P)+d(P,Q)=d(O,Q)$. 3. Since $d(O,P)=d(O,Q)$, $d(P,Q)=0$, so $P=Q$ by DIST 1: contradiction. The other case is symmetric.

**Corollary (perpendicular bisector).** *Statement:* $P\ne Q$. A point $M$ satisfies $d(P,M)=d(Q,M)$ iff $M$ lies on the perpendicular bisector of $\overline{PQ}$.
*Proof (Lang's):*
1. Let $L$ be the line through $P,Q$; $K$ the perpendicular to $L$ through $M$; $O=K\cap L$.
2. ($\Rightarrow$) Suppose $d(P,M)=d(Q,M)$. Pythagoras in $\triangle POM$ and $\triangle QOM$: $d(P,O)^2+d(O,M)^2=d(P,M)^2=d(Q,M)^2=d(Q,O)^2+d(O,M)^2$.
3. Cancel $d(O,M)^2$: $d(P,O)^2=d(Q,O)^2$, so $d(P,O)=d(Q,O)$ (distances $\ge0$).
4. By the Lemma, $O$ is the midpoint of $\overline{PQ}$; $K\perp L$, so $K$ is the perpendicular bisector and $M\in K$.
5. ($\Leftarrow$) If $M$ is on the perpendicular bisector, $O$ is the midpoint, $d(P,O)=d(Q,O)$; reverse the same computation to get $d(P,M)=d(Q,M)$.
*Intuition:* the points equidistant from two points form the perpendicular bisector. This is the workhorse for Chapter 6.
*Example:* $P=(0,0)$, $Q=(4,0)$, $M=(2,3)$ on the bisector $x=2$: $d(P,M)=\sqrt{4+9}=d(Q,M)$.

### Recall prompts — Chapter 5
1. State DIST 1–3, SEG 1, SEG 2. Which are assumed? What does SEG 1 say about equality in the triangle inequality?
2. Define "angle $A$ has $x$ degrees" via area. Why does a straight angle have $180^\circ$? Why is the choice of disc irrelevant (what is assumed)?
3. Compute the area of the sector of radius 5 between $30^\circ$ and $45^\circ$, from the definition of degrees.
4. State RT and PD. What do they assume, and how do they relate to congruence?
5. Prove Theorem 1 ($m(A)+m(B)=90^\circ$) and Theorem 2 (area $=ab/2$) from the rectangle construction.
6. Prove the Pythagoras theorem with the $(a+b)$-square. Where is the inner figure shown to be a square, and which angle fact is used?
7. Prove the lemma: $O$ on line $PQ$ with $d(O,P)=d(O,Q)$ lies on the segment $\overline{PQ}$.
8. State and prove the corollary (equidistant points = perpendicular bisector).

---

## Chapter 6 — Isometries

> A *mapping* of the plane to itself is a rule sending points to points. An *isometry* is a distance-preserving mapping. We study the standard mappings (reflections, rotations, translations, dilations), prove that isometries preserve segments and lines, that fixed points pin an isometry down (2 fixed points fix a line; 3 non-collinear fixed points force the identity), then classify all isometries (translation + rotation + possible reflection) and use them to define congruence and prove the classical congruence theorems. This replaces the classical "superposition" arguments.

### §1. Some standard mappings of the plane

**Definitions.**
- **Mapping** $F$ of the plane into itself: to each point $P$ associates a point $F(P)$ (the **value**/**image** of $P$). $F=G$ iff $F(P)=G(P)$ for every $P$.
- **Constant mapping** (value $O$ everywhere). **Identity** $I$: $I(P)=P$.
- **Reflection through a line $L$**: for $P$, let $L'$ be the perpendicular to $L$ through $P$, $O=L\cap L'$; $P'$ is the point on $L'$ at the same distance from $O$ on the other side. Denoted $R_L$.
- **Reflection through a point $O$**: $P'$ on line $PO$, other side of $O$, $d(O,P')=d(O,P)$.
- **Dilation by $r>0$ relative to $O$** (also called stretching, or a *similarity transformation*): $F_r(P)=rP$ is the point on ray $R_{OP}$ with $d(O,rP)=r\,d(O,P)$.
- **Rotation $G_A$** (counterclockwise by angle $A$ about $O$): $P'$ on the circle of radius $d(O,P)$ about $O$ with $\angle POP'$ having measure of $A$. Clockwise: $G_{-A}$.
- **Rotation by number $x$**: for $0\le x<360$, $G_x$ = rotation by $x^\circ$. For any real $x$ write $x=360n+w$, $n$ an integer, $0\le w<360$, and **define** $G_x=G_w$.
- **Translation**: fixed direction and distance $d$; $P\mapsto$ the point at distance $d$ from $P$ in that direction. $T_{OM}$ = the translation given by the arrow (ordered pair) $(O,M)$; $T_{OM}(O)=M$, $T_{OO}=I$.
- **Fixed point** of $F$: $F(P)=P$.

**Facts proved in Lang's examples (rotation numbers).**
- $G_{180}=R_O$ (reflection through $O$), and $G_{-180}=R_O$ too. Equal as mappings because values agree at every point.
- $G_0=G_{360}=I$.
- *If $x=y+360m$ ($m$ integer) then $G_x=G_y$.* *Proof:* write $x=360n+w$, $0\le w<360$. Then $y=x-360m=360(n-m)+w$, so by definition $G_x=G_w=G_y$.
- Examples: $500=360+140$ gives $G_{500}=G_{140}$; $-210=-360+150$ gives $G_{-210}=G_{150}$; $-90=-360+270$ gives $G_{-90}=G_{270}$ (clockwise $90^\circ$ = counterclockwise $270^\circ$).
*Intuition:* a rotation depends on the angle only modulo $360$.
*Caution (Lang):* the same letter $A$ for $\angle POP'$ and "an angle of the same measure" is convenient but two angles with equal measure are not necessarily the same angle.

### §2. Isometries

**Definitions.**
- $F$ **preserves distances** (is an **isometry**) if $d(F(P),F(Q))=d(P,Q)$ for all $P,Q$.
- **Image of a set** $S$: $F(S)=\{F(P):P\in S\}$.

**Assumed (no proof).** Reflection through a point, reflection through a line, rotations, and translations are isometries. (Lang proves this later with coordinates.) Dilation by $2$ (and the constant map) is not an isometry: distances double (resp. collapse to 0).

**Remark (proved).** An isometry sends distinct points to distinct points (distance $\ne0$, so by DIST 1 image distance $\ne0$).

**Theorem 1.** *Statement:* an isometry $F$ maps the segment $\overline{PQ}$ onto the segment $\overline{F(P)F(Q)}$.
*Proof (Lang's):* write $X'=F(X)$.
1. Take $X\in\overline{PQ}$. SEG 1: $d(P,Q)=d(P,X)+d(X,Q)$.
2. $F$ preserves distances, so $d(P',Q')=d(P',X')+d(X',Q')$.
3. By SEG 1 again, $X'\in\overline{P'Q'}$. So $F(\overline{PQ})\subseteq\overline{P'Q'}$.
4. Conversely, take $X'\in\overline{P'Q'}$ at distance $r$ from $P'$. By SEG 2 there is $X\in\overline{PQ}$ with $d(P,X)=r$. Then $d(F(X),P')=r$ and $F(X)\in\overline{P'Q'}$ (step 3), so by uniqueness in SEG 2, $F(X)=X'$.
5. Hence the two sets are equal.
*Method:* to prove $A=B$ prove $A\subseteq B$ and $B\subseteq A$.
*Example:* reflection through the center $O$ of a rectangle swaps opposite corners, so by Theorem 1 it swaps opposite sides.

**Corollary.** *Statement:* an isometry maps the line through $P\ne Q$ onto the line through $F(P),F(Q)$. *Proof:* left as an exercise in the book (not proved in the text).

**Theorem 2.** *Statement:* if an isometry $F$ fixes two distinct points $P,Q$, then it fixes every point of the line $L_{PQ}$.
*Proof (Lang's):* Let $M\in L_{PQ}$, $M'=F(M)$.
1. *Case 1: $M\in\overline{PQ}$.* $d(P,M')=d(P,M)$, $d(M',Q)=d(M,Q)$, so $d(P,M')+d(M',Q)=d(P,Q)$. SEG 1: $M'\in\overline{PQ}$. A point of $\overline{PQ}$ at distance $d(P,M)$ from $P$ is unique (SEG 2), so $M'=M$.
2. *Case 2: $M$ beyond $Q$ on ray $R_{PQ}$.* $d(P,M')=d(P,M)=d(P,Q)+d(Q,M)=d(P,Q)+d(Q,M')$. SEG 1: $Q\in\overline{PM'}$; so $P,Q,M'$ are collinear, with $M'$ on ray $R_{PQ}$. Since $d(P,M)=d(P,M')$, $M=M'$.
3. *Case 3: $M$ on the other side of $P$.* Same as Case 2 with $P,Q$ interchanged.

**Theorem 3.** *Statement:* an isometry fixing three non-collinear points $P,Q,M$ is the identity.
*Proof (Lang's):* Let $X$ be any point.
1. Choose $Z\in L_{QM}$, $Z\ne M,Q,X$, with $L_{XZ}$ not parallel to $L_{PQ}$; let $Y=L_{XZ}\cap L_{PQ}$ (so $Y\ne Z$).
2. By Theorem 2 all points of $L_{PQ}$ and $L_{QM}$ are fixed: $F(Y)=Y$, $F(Z)=Z$.
3. Theorem 2 again for $Y\ne Z$: every point of $L_{YZ}$ is fixed, including $X$.
*Intuition:* 3 non-collinear points are a rigid frame.

*Example (our illustration, not Lang's):* a reflection fixes a whole line but is not the identity; consistent with Theorem 3 since all fixed points are collinear.

### §3. Composition of isometries

**Definitions.**
- **Composite** $F\circ G$: $(F\circ G)(P)=F(G(P))$ (apply $G$ first). Composite of isometries is an isometry (proof: $d(P,Q)=d(G(P),G(Q))=d(F(G(P)),F(G(Q)))$).
- **Powers**: $F^2=F\circ F$, $F^n$ ($n$ times), $F^0=I$; then $F^{m+n}=F^m\circ F^n$ for naturals $m,n$.
- Examples: $F$ = rotation by $90^\circ$ and $G$ = reflection through the same point $O$: $G\circ F$ is rotation by $270^\circ$, and $F\circ F=G$. Reflection $G$ through a point: $G^2=I$, $G^3=G$, $G^4=I$ (like powers of $-1$). Rotation $F$ by $90^\circ$: $F^2=$ rot $180^\circ$, $F^3=$ rot $270^\circ$, $F^4=I$, $F^5=F$.

**$I$ acts like $1$.** $F\circ I=I\circ F=F$ (immediate).

**Assumed (no proof).**
- *Rotations about the same point $O$ compose to a rotation about $O$.*
- *For $P,Q\ne O$ with $d(O,P)=d(O,Q)=r$ there is a unique rotation $G_{PQ}$ about $O$ with $G_{PQ}(P)=Q$.*
- *$G_x\circ G_y=G_{x+y}$ (angles add).* E.g. $G_{45}\circ G_{45}=G_{90}$; $G_{180}\circ G_{270}=G_{450}=G_{90}$.
- *Composite of translations is a translation.*
- *For points $P,Q$ there is a unique translation $T_{PQ}$ with $T_{PQ}(P)=Q$.*

**Formulas for rotations (proved from the assumed uniqueness).** $G_{QM}\circ G_{PQ}=G_{PM}$ and $G_{PP}=I$ ($P,Q,M$ at distance $r$ from $O$).
*Proof (Lang's):* 1. $(G_{QM}\circ G_{PQ})(P)=G_{QM}(Q)=M$. 2. $G_{PM}(P)=M$ too. 3. Only one rotation maps $P$ to $M$, hence equal. 4. $G_{PP}=I$ similarly. (Translation analogues $T_{QM}\circ T_{PQ}=T_{PM}$, $T_{PP}=I$ are left as an exercise.)

**Associativity.** *Statement:* $(F\circ G)\circ H=F\circ(G\circ H)$.
*Proof (Lang's):* for each $P$, both sides give $F(G(H(P)))$; equal at every point, hence equal mappings.

**Composition is not commutative in general** (Lang only poses it as an exercise: find $F_1\circ F_2\ne F_2\circ F_1$; no example given in the text).

*Example.* $T$ = translation by 1 in. to the right: $P,T(P),T^2(P),\dots$ lie on a horizontal line, $T^{n+1}(P)$ one inch right of $T^n(P)$.

### §4. Inverse of isometries

**Definitions.**
- An **inverse** of an isometry $F$ is an isometry $G$ with $F\circ G=G\circ F=I$.
- Negative powers: if $F^{-1}$ exists, $F^{-k}=(F^{-1})^k$, $F^0=I$.

**Uniqueness of inverse (proved).** *Statement:* if $G,H$ are inverses of $F$ then $G=H$.
*Proof (Lang's):* $H\circ F\circ G$ equals $H\circ I=H$ (using $F\circ G=I$), and by associativity equals $(H\circ F)\circ G=I\circ G=G$. So $G=H$. Write $F^{-1}$.

**Equivalence (proved).** $P=F(Q)\iff Q=F^{-1}(P)$. *Proof:* if $P=F(Q)$ apply $F^{-1}$: $F^{-1}(P)=F^{-1}(F(Q))=Q$; conversely apply $F$.

**Examples (proved by the defining identity).**
- Reflection $F$ through a line: $F^2=I$, so $F^{-1}=F$.
- $G_x^{-1}=G_{-x}$ since $G_{-x}\circ G_x=G_0=I$; e.g. $G_{90}^{-1}=G_{270}=G_{-90}$ and $G_{90}^{-1}=G_{90}^3$.
- $T_{OM}^{-1}=T_{MO}$, since $T_{MO}\circ T_{OM}=I$ (opposite direction, same distance).
- **Inverse of a composite:** if $F^{-1},G^{-1}$ exist, $(F\circ G)^{-1}=G^{-1}\circ F^{-1}$. *Proof:* $G^{-1}\circ F^{-1}\circ F\circ G=G^{-1}\circ I\circ G=G^{-1}\circ G=I$ and similarly on the other side.
- $F^{m+n}=F^m\circ F^n$ holds for all integers $m,n$ (proof omitted, "easy").
- Translations: if $T$ = 1 in. right, $T^{-1}$ = 1 in. left, $T^{-5}$ = 5 in. left.

**Corollary of Theorem 3.** *Statement:* if $F,G$ are isometries agreeing at three non-collinear points $P,Q,M$ and $F^{-1}$ exists, then $F=G$.
*Proof:* "very easy", left as an exercise in the book (our hint, from Lang's Exercise 5: $F^{-1}\circ G$ fixes $P,Q,M$, so it is $I$ by Theorem 3; compose with $F$).
*Example (Lang's):* $H$ = reflection through horizontal $L$, $V$ = through vertical $K$, both through $O$: $H\circ V=V\circ H$, because both act the same way on three corners of a square centered at $O$ (each corner goes to the opposite corner).

**Remark.** Lang: "it will be proved later that every isometry has an inverse" (it is Exercise 1 after §5, using the characterization Theorems 4–6; not proved in the text).

**Multiplication tables (Lang's device).** Write $FG$ for $F\circ G$. For $I,H,V,HV$: $H^2=V^2=I$, $HV=VH$, $HV\cdot HV=I$, $H\cdot HV=V$. The exercises extend the idea to symmetries of the square, triangle, hexagon (dihedral groups, in modern terms).

### §5. Characterization of isometries

**Theorem 4.** *Statement:* an isometry $F$ that fixes two distinct points $P,Q$ is either the identity or the reflection through the line $L_{PQ}$.
*Proof (Lang's):*
1. Take $M$ on the perpendicular bisector of $\overline{PQ}$, $M\notin\overline{PQ}$. Then $d(P,M)=d(Q,M)$ (Pythagoras corollary).
2. If $F(M)=M$, Theorem 3 gives $F=I$.
3. Otherwise $M'=F(M)\ne M$. $d(P,M')=d(P,M)=d(Q,M)=d(Q,M')$, so by the corollary $M'$ is on the perpendicular bisector.
4. Let $O$ be the midpoint of $PQ$; $F(O)=O$ by Theorem 2, so $d(O,M')=d(O,M)$. $M,M'$ are on the perpendicular bisector at the same distance from $O$ and distinct, so $M'$ is the reflection of $M$ through $L_{PQ}$.
5. Let $R$ be the reflection through $L_{PQ}$ ($R=R^{-1}$). $R\circ F$ fixes $P,Q$ and $R(F(M))=R(M')=M$. By Theorem 3, $R\circ F=I$.
6. Compose with $R$: $R\circ R\circ F=R$, so $F=R$.

**Theorem 5.** *Statement:* an isometry $F$ with a fixed point $O$ is a rotation (about $O$), or a rotation composed with a reflection through a line: $F=G$ or $F=G\circ R$.
*Proof (Lang's):*
1. Pick $P\ne O$. If $F(P)=P$, Theorem 4 applies ($O,P$ fixed): $F=I$ (a rotation by $0$) or a reflection.
2. Otherwise $P'=F(P)\ne P$; $d(O,P)=d(O,P')$ since $F$ preserves distance and fixes $O$.
3. By the assumed rotation fact there is a rotation $G$ about $O$ with $G(P)=P'$; $G^{-1}$ is a rotation and $G^{-1}(P')=P$.
4. So $G^{-1}\circ F$ fixes $P$ and $O$. By Theorem 4, $G^{-1}\circ F=I$ or $=R$ (reflection).
5. If $I$: $F=G$. If $R$: compose with $G$: $F=G\circ R$.

**Theorem 6.** *Statement:* an isometry with no fixed point is a translation $T$, or $T\circ G$ (translation after rotation), or $T\circ G\circ R$.
*Proof (Lang's):* 1. Pick $O$, set $P=F(O)$ ($P\ne O$, since no fixed point). 2. Let $T$ be the translation with $T(O)=P$; $T^{-1}$ is a translation with $T^{-1}(P)=O$. 3. Then $T^{-1}\circ F$ is an isometry fixing $O$. 4. Theorem 5: $T^{-1}\circ F=G$ or $G\circ R$. 5. So $F=T\circ G$ or $F=T\circ G\circ R$.
*Combined meaning:* every isometry is a composite of a translation, a rotation, and possibly a reflection (the section's main result). 
*Intuition:* fix one point by translating, then fix a second by rotating, then fix a third by reflecting (Theorem 3 says this suffices).

### §6. Congruences

**Definition.** Sets $S,S'$ are **congruent** if some isometry $F$ has $F(S)=S'$.

**Basic facts (Exercise 2 of §6, used by Lang; not proved in text).** Congruence is symmetric and transitive; so in proofs we may apply any isometry to one figure and show the image is congruent to the other.

**Theorem 7.** *Statement:* two circles of the same radius are congruent.
*Proof (Lang's):* circles $C(r,O)$ and $C(r,O')$. 1. Let $T$ be the translation with $T(O)=O'$. 2. If $d(P,O)=r$ then $d(T(P),O')=r$ (isometry): $T(C(r,O))\subseteq C(r,O')$. 3. Conversely for $Q\in C(r,O')$, $P=T^{-1}(Q)$ satisfies $d(P,O)=r$ and $T(P)=Q$.

**Theorem 8.** *Statement:* any two segments of the same length are congruent.
*Proof (Lang's):* segments $\overline{PQ},\overline{MN}$, equal length. 1. $T$ = translation with $T(M)=P$. 2. $d(P,T(N))=d(P,Q)$ since $T$ is an isometry. 3. There is a rotation $G$ about $P$ with $G(T(N))=Q$. 4. $G\circ T$ maps $M\mapsto P$, $N\mapsto Q$; by Theorem 1 of §2 it maps $\overline{MN}$ onto $\overline{PQ}$.
*(Alternate phrasing:* reduce to $P=M$ via the congruence facts, then one rotation suffices.)

**Theorem 9 (right-angle SAS, "RT in congruence language").** *Statement:* right triangles $\triangle PQM$, $\triangle P'Q'M'$ with right angles at $Q,Q'$ and corresponding legs equal are congruent.
*Proof:* left as an exercise. (Remark: this puts the old assumption RT inside the theory of congruence.)

**Theorem 10 (SSS).** *Statement:* triangles with three pairs of corresponding sides equal are congruent.
*Proof (Lang's):*
1. A translation maps $P\mapsto P'$, so assume $P=P'$.
2. $d(P,Q)=d(P,Q')$: a rotation about $P$ maps $Q\mapsto Q'$, and it fixes $P$; so assume $P=P'$ and $Q=Q'$.
3. If $M=M'$ we are done. Otherwise $d(P,M)=d(P,M')$, $d(Q,M)=d(Q,M')$; by the corollary of Pythagoras both $P$ and $Q$ lie on the perpendicular bisector of $\overline{MM'}$, so $L_{PQ}$ is that bisector and $M'$ is the reflection of $M$ through $L_{PQ}$.
4. Reflection through $L_{PQ}$ fixes $P,Q$ and sends $M\mapsto M'$; by Theorem 1 (§2) it maps the sides of $\triangle PQM$ onto those of $\triangle P'Q'M'$.
5. Composing the isometries used gives one isometry mapping the first triangle onto the second.

**Regions via segments (remark, definitions).**
- The **triangular region** bounded by $\triangle PQM$: all points on all segments $\overline{PX}$, $X\in\overline{QM}$. Hence an isometry maps it onto the region bounded by the triangle with vertices $F(P),F(Q),F(M)$ (exercise).
- An **angle** (measure $<180^\circ$) between rays $R_{PQ},R_{PM}$: all points on segments $\overline{XY}$, $X\in R_{PQ}$, $Y\in R_{PM}$.

**Area under isometries (assumed, "basic axiom").** *Statement:* if $S$ has area $a$ and $F$ is an isometry, then $F(S)$ has area $a$.
*Motivation (not proof):* it is clear for rotation, reflection, translation, and every isometry is a composite of these (Theorems 4–6).
**Consequence (argued from the axiom).** An isometry maps an angle $A$ to an angle $F(A)$ with the same measure (compare sectors, which are mapped by $F$ and keep area). A reflection reverses the orientation of the ordered rays (counterclockwise order), but measure is preserved.

### Recall prompts — Chapter 6
1. Define mapping, isometry, composite, inverse, fixed point. Which standard maps are isometries (and which of these facts are assumed)?
2. Prove: for $x=y+360m$, $G_x=G_y$. Compute $G_{-210}$ and $G_{500}$ as $G_w$ with $0\le w<360$.
3. State and prove Theorem 1 (image of a segment). Why do you need SEG 2 in the second half?
4. State and prove Theorem 2 (two fixed points fix the line), with all three cases.
5. State and prove Theorem 3 (three non-collinear fixed points force identity). How do you choose $Y,Z$?
6. Prove associativity of composition. Prove uniqueness of inverse, and $(F\circ G)^{-1}=G^{-1}\circ F^{-1}$.
7. State and prove the corollary of Theorem 3 (agree on 3 points + $F^{-1}$ exists $\Rightarrow F=G$).
8. Prove Theorem 4 (two fixed points: identity or reflection), naming where the Pythagoras corollary and Theorem 3 enter.
9. Prove Theorem 5 and Theorem 6 (classification of isometries by number of fixed points).
10. Prove Theorems 7, 8 and 10 (circles, segments, SSS). Which theorem is RT recovered from?
11. What is assumed about area under isometries, and why is it believable?

---

## Chapter 7 — Area and Applications

> Using dilations we see how area and length scale ($r^2$ and $r$). From this we justify (intuitively, via approximation and limits, not rigorously) that the disc of radius $r$ has area $\pi r^2$ and the circle of radius $r$ has length $2\pi r$. Lang calls this a first taste of calculus: approximation + limit.

### §1. Area of a disc of radius $r$

**Assumed.** The notion of area and its basic intuitive properties; area of a rectangle with sides $a,b$ is $ab$ (square: $a^2$), with a fixed unit of length determining a unit of area.

**Area under dilation of a rectangle (proved).** Rectangle $S$ with sides $a,b$; $rS$ has sides $ra,rb$, so area $(ra)(rb)=r^2ab$. Examples: $r=2$ gives $4ab$; $r=3$ gives $9ab$.

**Claim (plausible, assumed): area of $rS=r^2\,(\text{area of }S)$ for any region $S$ approximable by rectangles.** *Justification (Lang's):* approximate $S$ by finitely many rectangles (or squares of a fine grid); each rectangle's area scales by $r^2$, so the total does.

**Area of a disc (plausible, not proved).** Let $D_r$ be the disc of radius $r$, $D_r=rD_1$, and $\pi$ = area of $D_1$. Then
$$\text{area of } D_r=\pi r^2.$$
Here $\pi$ is *defined* as the area of the unit disc; §2 shows it equals circumference/diameter, i.e. the familiar $3.14159\ldots$.

**Approximation by a grid (Lang's discussion).**
1. Draw a grid of squares of side $c$. Squares inside the disc approximate its area.
2. The error is at most the area of the squares meeting the circle. Each such square has diagonal $c\sqrt2$, so all its points are within $c\sqrt2$ of the circle: it lies in a band of width $c\sqrt2$ on each side of the circle.
3. The band's area is plausibly at most $2c\sqrt2\times(\text{length of circle})$ (assumed plausible), which $\to0$ as $c\to0$.
*Intuition:* fine graph paper; count the squares inside.

**General regions.** Same argument: dilating a region by $2$ multiplies area by $4$.

*Example.* Rectangle $2\times\frac12$: area $1$; sides doubled ($4\times1$): area $4=2^2\cdot1$; sides halved: area $\frac14$.

### §2. Circumference of a circle of radius $r$

**Statement (plausible, derived by approximation).** Length of $C_1=2\pi$, length of $C_r=2\pi r$.

**Derivation (Lang's), with limits taken intuitively.**
1. Cut the disc of radius $r$ into $n$ sectors of $360/n$ degrees; join the endpoints on the circle: a regular inscribed $n$-gon, made of $n$ triangles congruent to one triangle $T_n$ with base $b_n$ and height $h_n$.
2. Area of $T_n$ is $\tfrac12 b_nh_n$ (triangle area, proved by Lang in exercises from Theorem 2). So polygon area $A_n=n\cdot\tfrac12 b_nh_n$.
3. Perimeter $P_n=nb_n$, so $A_n=\tfrac12P_nh_n$.
4. As $n\to\infty$: $A_n\to$ area of the disc $=\pi r^2$ (assumed), $P_n\to$ circumference $c$ (assumed), $h_n\to r$.
5. Hence $\pi r^2=\tfrac12 c\,r$, so $c=2\pi r$.
*Intuition:* a thin triangle fan; area = half perimeter $\times$ height, and height $\to$ radius.
*Example:* $r=2$: area $4\pi$, circumference $4\pi$.

**Distances under dilation.** *Statement:* $d(rP,rQ)=r\,d(P,Q)$.
*Status:* Lang says it will be proved with coordinates (and later seen for right angle not at $O$); here it is *justified only for a right triangle with the right angle at $O$*: legs $a,b$ become $ra,rb$, so the hypotenuse becomes $\sqrt{r^2a^2+r^2b^2}=r\sqrt{a^2+b^2}=rc$ (Pythagoras twice).

**Length under dilation (plausible).** Approximating a curve $S$ by segments $S_1,\dots,S_n$, $rS$ is approximated by $rS_1,\dots,rS_n$, with total length $r[\ell(S_1)+\dots+\ell(S_n)]$; hence
$$\text{length of } rS=r\,(\text{length of }S),$$
consistent with $2\pi r=r\cdot2\pi$.

**Remark.** Approximation plus limits are the basic ideas of calculus.

### Recall prompts — Chapter 7
1. Show why dilation by $r$ multiplies the area of a rectangle by $r^2$. Why is it plausible for any region?
2. Why is $\pi$ defined as the area of the unit disc, and how does the area of $D_r$ follow?
3. Explain the grid approximation of a disc: why does the error come from squares near the circle, and how is the band width $c\sqrt2$ obtained?
4. Derive $c=2\pi r$ from the inscribed regular $n$-gon: $A_n=n\cdot\tfrac12 b_nh_n$, $P_n=nb_n$, $A_n=\tfrac12P_nh_n$, then the limits.
5. Justify $d(rP,rQ)=r\,d(P,Q)$ for a right triangle with the right angle at $O$. Why does length scale by $r$ for a curve?
6. List the assumed facts in Chapter 7 that make the derivations "plausible rather than proved".

# Part Three — Coordinate Geometry (Chapters 8–12)

*(Book intro, p. 189, paraphrased.) As stated before, coordinates let us give definitions of geometric terms using only properties of numbers. The three chapters of this part (trigonometry, translations/addition of points, segments-rays-lines) are largely independent of each other: trigonometry can be read right after the coordinates and distance formula of Chapter 8 §1–2, and the chapter on segments, rays and lines does not depend on trigonometry or the analytic geometry; read them in any order. Coordinates give analytic proofs, and let us compute where the intuitive geometry could not: given a coordinatized definition of lines, we can compute the intersection point of two lines explicitly.*


## Chapter 8 — Coordinates and Geometry

> We fix two perpendicular axes and a unit length, so that each point of the plane becomes a pair of numbers. Distance becomes a formula (Pythagoras). Circles become equations. The chapter ends with a number-theory gem: all integer right triangles come from rational points on the unit circle. This is the dictionary "geometry = algebra" that every later chapter uses.

### §1. Coordinate systems

**Definitions.**
- **Origin** $O$: the intersection of a horizontal and a vertical line. These lines are the **coordinate axes**; with a unit length chosen, integers mark both axes (negative: left/down).
- **Coordinates** of a point $P$: draw perpendiculars from $P$ to the two axes; the two numbers obtained are $x,y$, and $P=(x,y)$. Every pair $(x,y)$ determines a point. Order matters: first coordinate, second coordinate. Usually the horizontal axis is the **$x$-axis**, the vertical the **$y$-axis**; other letters ($t,s$ or $u,v$) may be used.
- $O=(0,0)$.
- **Quadrants** I–IV, counterclockwise from upper right (Fig. 8-6). $(x,y)$ is in the first quadrant iff $x>0$ and $y>0$; in the fourth quadrant iff $x>0$ but $y<0$.
- Axes may also be slanted. Changing the coordinate system changes the coordinates of a point.
- **Remark (convention).** The positive direction of the second axis is obtained by rotating the positive direction of the first axis counterclockwise through a right angle.

*Nothing to prove here.* *Intuition:* a coordinate system is a map grid. *Example:* $(-3,-2)$ means 3 left of $O$, 2 down. $(\tfrac12,-1)$ and $(-\sqrt2,3)$ are allowed: coordinates need not be integers.

*Big exercise (flagged in the book):* a point of 3-space is a triple $(x,y,z)$; $\mathbf R^3$ denotes 3-space. Everything in Chapters 8–10 is to be redone in 3-space; it is the same with extra coordinates.

### §2. Distance between points

**Definitions.**
- Distance on a line: for points $x_1,x_2$ the distance is $\sqrt{(x_1-x_2)^2}$ (= $|x_1-x_2|$). The square of the difference does not depend on the order. Example (Lang): points $-2$ and $3$: $(3-(-2))^2=25=(-2-3)^2$, distance $5$.
- The **plane** is *defined* to be the set $\mathbf R^2$ of all pairs $(x,y)$ of real numbers.
- **Distance** between $X=(x_1,y_1)$ and $Y=(x_2,y_2)$ is *defined* by the formula below. $d(P,Q)$ is the notation.

**Pythagoras theorem (recalled from geometry).**
*Statement:* in a right triangle with legs $a,b$ and hypotenuse $c$: $a^2+b^2=c^2$.
*Proof:* not given here (taken from plane geometry).

**Distance formula.**
*Statement:* $d\big((x_1,y_1),(x_2,y_2)\big)=\sqrt{(x_2-x_1)^2+(y_2-y_1)^2}$.
*Proof (Lang's):*
1. Draw the right triangle with the two points as ends of the hypotenuse and legs parallel to the axes.
2. The horizontal leg has square length $(x_2-x_1)^2$ (equal to $(x_1-x_2)^2$); the vertical leg has $(y_2-y_1)^2$ (distance on a line).
3. Pythagoras: $d^2=(x_2-x_1)^2+(y_2-y_1)^2$; take the positive square root.
4. Since squares ignore order, $d(P,Q)=d(Q,P)$ (this is property DIST 2 of Chapter 5). In the analytic program, step 3's formula is then taken as the *definition* of distance.
*Intuition:* the hypotenuse of the "run" and "rise" triangle.
*Example:* $P=(-1,5)$, $Q=(4,-3)$: $d^2=(4-(-1))^2+(-3-5)^2=25+64=89$, so $d=\sqrt{89}$. Also (Lang): $(1,2),(3,5)$ give $d^2=4+9=13$; $(2,4),(1,-1)$ give $d^2=(1-2)^2+(-1-4)^2=26$ (same in either order). Warning (Lang): watch minus signs and parentheses.

### §3. Equation of a circle

**Definitions.**
- The **circle of radius $r>0$ centered at $P$** is the set of all points at distance $r$ from $P$.
- Its **equation** is the condition on $(x,y)$ expressing that.

**Theorem (equation of a circle).**
*Statement:* the circle of radius $r$ centered at $(a,b)$ is the set of all $(x,y)$ with
$$(x-a)^2+(y-b)^2=r^2.$$
In particular $x^2+y^2=r^2$ is the circle of radius $r$ centered at $O$.
*Proof (Lang's, done for the example $P=(1,4)$, $r=3$, where (2) reads $(x-1)^2+(y-4)^2=9$; the general case is stated with the same argument):*
1. $(x,y)$ is on the circle iff $\sqrt{(x-a)^2+(y-b)^2}=r$ (definition of distance).
2. Both sides are $\ge0$ (positive). If (1) holds, squaring gives $(x-a)^2+(y-b)^2=r^2$.
3. Conversely, if the squared equation holds, take the positive square root of both sides to get back the unsquared equation (both sides positive).
4. So the two equations are equivalent; we keep the squared form to avoid the root sign.
*Intuition:* the circle is the level set of squared distance to the center.
*Example:* $(x-2)^2+(y+5)^2=16$: since $y+5=y-(-5)$, the center is $(2,-5)$ and the radius is $4$. Note the sign flip in $y+5$. Lang's next example is $(x+2)^2+(y+3)^2=7$: center $(-2,-3)$, radius $\sqrt7$. *Misprint:* the book (p. 203) prints it as $(x+2)^2+(x+3)^2=7$, with $x$ in place of the second $y$; with $x$ twice it would not be a circle equation in $(x,y)$.

### §4. Rational points on a circle (optional section in the book)

**Definitions.**
- A **rational point** is a point whose coordinates are both rational numbers.
- A **Pythagorean triple** here: positive integers $a,b,c$ with $a^2+b^2=c^2$ (right triangle with integer sides), e.g. $(3,4,5)$, $(8,15,17)$, $(5,12,13)$.

**Equivalence principle.**
*Statement:* integer solutions of $(*)\ a^2+b^2=c^2$ correspond to rational solutions of $(**)\ x^2+y^2=1$, i.e. rational points on the unit circle.
*Proof (Lang's):*
1. If $a,b,c$ are integers ($c\ne0$) with $(*)$, divide by $c^2$: $(a/c)^2+(b/c)^2=1$, so $x=a/c$, $y=b/c$ are rational and solve $(**)$.
2. Conversely, rational $x,y$ with $(**)$ can be written over a common denominator $c\neq0$: $x=a/c$, $y=b/c$, $a,b,c$ integers.
3. Then $(a/c)^2+(b/c)^2=1$; multiply by $c^2$ to get $a^2+b^2=c^2$.
*Intuition:* clearing denominators is the whole trick.

**Parametrization formulas (examples of points).**
*Statement:* for any number $t$, $x=\dfrac{1-t^2}{1+t^2}$, $y=\dfrac{2t}{1+t^2}$ satisfy $x^2+y^2=1$ (algebra, left to the reader). For rational $t$ both coordinates are rational.
*Example:* $t=2$: $x=\frac{1-4}{1+4}=-\frac35$, $y=\frac{2\cdot2}{5}=\frac45$, giving $3^2+4^2=5^2$. $t=5$: $x=\frac{-24}{26}=-\frac{12}{13}$, $y=\frac{10}{26}=\frac5{13}$, giving $5^2+12^2=13^2$. $t=4$ gives $(8,15,17)$. Different values of $t$ give different points (Lang: "can you prove this as an exercise?"; Exercise 2 does it for $t\ge0$). Lang says the formulas are old, history unknown.

**Theorem 1.**
*Statement:* let $x^2+y^2=1$ and $x\ne-1$. Put $t=\dfrac{y}{x+1}$. Then $x=\dfrac{1-t^2}{1+t^2}$ and $y=\dfrac{2t}{1+t^2}$.
*Proof (Lang's):*
1. Multiply $t=y/(x+1)$ by $x+1$: $t(x+1)=y$.
2. Square: $t^2(x+1)^2=y^2$.
3. Use $y^2=1-x^2=(1+x)(1-x)$: $t^2(x+1)^2=(1+x)(1-x)$.
4. Cancel $x+1$ (nonzero): $t^2(x+1)=1-x$.
5. Expand: $t^2x+t^2=1-x$, so $(t^2+1)x=1-t^2$.
6. Divide by $t^2+1$: $x=\frac{1-t^2}{1+t^2}$.
7. Then $y=t(x+1)$ and easy algebra (left to the reader) give $y=\frac{2t}{1+t^2}$.
*Intuition:* $t$ is the slope of the line from $(-1,0)$ to $(x,y)$ (Fig. 8-17); each such line meets the circle once more.
*Example:* $(x,y)=(\tfrac35,\tfrac45)$: $t=\frac{4/5}{8/5}=\frac12$; then $x=\frac{1-1/4}{1+1/4}=\frac{3/4}{5/4}=\frac35$ and $y=\frac{1}{5/4}=\frac45$. ✓

**Corollary.**
*Statement:* if $x,y$ are rational, $x^2+y^2=1$, $x\ne-1$, then there is a rational $t$ with $x=\frac{1-t^2}{1+t^2}$, $y=\frac{2t}{1+t^2}$.
*Proof:* in Theorem 1, $t=y/(x+1)$ is a quotient of rationals, hence rational.
*Consequence:* every rational point of the circle except $(-1,0)$ is obtained from a rational $t$, so these formulas describe all integer right triangles.
*Remarks (no proof):* the analogous problem $x^3+y^3=1$ in rationals has only the solutions $x=0$ or $x=1$; for a positive integer $k$, Lang's "Fermat's equation" $x^k+y^k=1$ (rational, positive $x,y$): for many $k$ it is known there is no solution other than $x=0$ or $x=1$, but the general case is unknown in the book; this is "the famous Fermat problem".

### Recall prompts — Chapter 8
1. State the distance formula in the plane and derive it from the Pythagoras theorem. Why is $d(P,Q)=d(Q,P)$?
2. Define the circle of radius $r$ centered at $(a,b)$; derive its equation and explain why squaring the equation $\sqrt{\cdots}=r$ loses nothing.
3. Read off center and radius from $(x-2)^2+(y+5)^2=16$. Why does $y+5$ give center coordinate $-5$?
4. Show that integer solutions of $a^2+b^2=c^2$ correspond to rational points of $x^2+y^2=1$, in both directions.
5. State Theorem 1 on $t=y/(x+1)$ and prove it step by step (which step needs $x\neq-1$?).
6. State the Corollary. Why do we conclude that $t$ rational comes from $x,y$ rational?
7. Generate the triples $(3,4,5)$ and $(5,12,13)$ from the formula and say which $t$ gives each.
8. Describe the 3-space version of the distance and of the sphere equation (the "big exercise" dictionary).

## Chapter 9 — Operations on Points

> Points of $\mathbf R^2$ are now added and multiplied by numbers componentwise. These operations have exact geometric meanings: multiplication by $r>0$ is dilation about $O$, multiplication by $-1$ is reflection through $O$, addition by $A$ is translation, and sums form parallelograms. Distances become norms of differences, and every property is proved by reducing to the same property for numbers.

### §1. Dilations and reflections

**Definitions.**
- $\mathbf R$ is the set of real numbers; $\mathbf R^2$ is the set of pairs; a point of the plane is an element of $\mathbf R^2$ (fixed coordinate system, point = its coordinates).
- **Product of a number and a point:** for $A=(a_1,a_2)$ and a number $c$, $cA=(ca_1,ca_2)$. Example: $A=(2,5)$, $c=6$: $cA=(12,30)$; $A=(-3,7)$, $c=-4$: $cA=(12,-28)$.
- If $r>0$, $rA$ is the **dilation** of $A$ by $r$; the map $A\mapsto rA$ is **dilation by $r$** (about $O$; $O$ stays fixed). It stretches the coordinates by $r$ (so $r=\tfrac12$ halves).
- $-A=(-1)A=(-a_1,-a_2)$. **Reflection through $O$** is the map $A\mapsto -A$, written $R(A)=-A$.
- For $c=-r$, $r>0$: $cA=-(rA)$, i.e. stretch by $r$, then reflect: it points the opposite way from $A$.
- **Absolute value** of a number: $|c|=\sqrt{c^2}$.

**Theorem 1.**
*Statement:* for $r>0$ and points $A,B$: $d(rA,rB)=r\,d(A,B)$.
*Proof (Lang's):*
1. Write $A=(a_1,a_2)$, $B=(b_1,b_2)$, so $rA=(ra_1,ra_2)$, $rB=(rb_1,rb_2)$.
2. $d(rA,rB)^2=(rb_1-ra_1)^2+(rb_2-ra_2)^2$ (definition of distance).
3. $=(r(b_1-a_1))^2+(r(b_2-a_2))^2$ (factor $r$).
4. $=r^2(b_1-a_1)^2+r^2(b_2-a_2)^2=r^2d(A,B)^2$.
5. Take square roots ($r>0$).
*Intuition:* dilation scales all lengths by the same factor.
*Example:* $A=(1,2)$, $B=(4,6)$, $d=5$. With $r=3$: $3A=(3,6)$, $3B=(12,18)$, $d=\sqrt{81+144}=15=3\cdot5$.

**Theorem 2.**
*Statement:* for any number $c$: $d(cA,cB)=|c|\,d(A,B)$.
*Proof (Lang's):* same as Theorem 1 up to step 4, which gives $d(cA,cB)^2=c^2d(A,B)^2$; taking the square root gives $\sqrt{c^2}=|c|$ in place of $r$. (Lang leaves the write-up to the reader.)
*Intuition:* a negative factor also reflects, which does not change lengths.
*Example:* $c=-3$, $A=(1,0)$, $B=(0,0)$: $cA=(-3,0)$, $d=3=|-3|\cdot1$.

### §2. Addition, subtraction, and the parallelogram law

**Definitions.**
- **Sum:** $A+B=(a_1+b_1,\ a_2+b_2)$ (componentwise). Example: $(-3,6)+(-2,-7)=(-5,-1)$.
- **Difference:** $A-B=A+(-B)$. Example: $(2,-5)-(3,-4)=(-1,-1)$.
- **Translation by $A$:** $T_A(P)=P+A$. Example: $A=(-2,3)$, $P=(1,5)$: $T_A(P)=(-1,8)$.
- **Mapping** of the plane: assigns to each point $P$ a point $F(P)$ (the **value**/**image** of $P$). The **image** of a set $S$ is $F(S)=\{F(P): P\in S\}$.
- **Isometry:** a mapping $F$ with $d(P,Q)=d(F(P),F(Q))$ for all $P,Q$.
- **Norm:** $|A|=d(A,O)=\sqrt{a_1^2+a_2^2}$, so $|A|^2=a_1^2+a_2^2$. It generalizes the absolute value of a number; geometrically it is the length of the segment $OA$.
- Remark: $|A|=|-A|$ (Lang: "Proof?", left to the reader; it holds since $(-a_1)^2=a_1^2$, etc.).

**Properties of addition (A, B, C points).**
*Statement:* (i) commutativity $A+B=B+A$; (ii) associativity $A+(B+C)=(A+B)+C$; (iii) zero: $A+O=O+A=A$; (iv) inverse: $A+(-A)=O$.
*Proof (Lang's):* each is reduced to the same property of numbers, coordinate by coordinate. E.g. (i): $A+B=(a_1+b_1,a_2+b_2)=(b_1+a_1,b_2+a_2)=B+A$ by commutativity for numbers. The others are identical in form.
*Intuition:* the coordinates are independent, so $\mathbf R^2$ inherits all the rules of numbers.
*Example:* $A=(2,-5)$: $-A=(-2,5)$ and $A+(-A)=(0,0)$.

**Parallelogram law (geometric meaning of addition).**
*Statement:* $O,\ A,\ B,\ A+B$ are the corners of a parallelogram. Also $A=(A-B)+B$, so $O,\ A-B,\ A,\ B$ form a parallelogram.
*Proof (Lang's, by example $A=(1,2)$, $B=(3,1)$):*
1. $A+B=(4,3)$ is obtained from $A$ by the same displacement (3 right, 1 up) that gives $B$ from $O$.
2. So the segment from $A$ to $A+B$ is parallel to (same displacement as) $OB$, and the segment from $B$ to $A+B$ is parallel to $OA$.
3. Hence $O,A,A+B,B$ are the four corners of a parallelogram.
4. For subtraction, $A-B=A+(-B)$: starting at $A$ we move in the opposite direction from the one used for $A+B$. Since $A=(A-B)+B$, the same law applies to the corners $O,\,A-B,\,A,\,B$.
*Intuition:* adding $B$ = sliding by the arrow from $O$ to $B$.

**Distance through subtraction.**
*Statement:* $d(A,B)=|A-B|=|B-A|$. Hence a mapping $F$ is an isometry iff $|F(P)-F(Q)|=|P-Q|$ for all $P,Q$. Also, $|cA|=|c||A|$, and $|rA|=r|A|$ for $r>0$ (special case of Theorem 2).
*Proof (Lang's):* $d(A,B)=\sqrt{(b_1-a_1)^2+(b_2-a_2)^2}=|B-A|$, and $=\sqrt{(a_1-b_1)^2+(a_2-b_2)^2}=|A-B|$ (squares do not see the order). The statements $|cA|=|c||A|$ and $|rA|=r|A|$ are Theorem 2 of §1 rewritten with $B=O$.

**Theorem 3.**
*Statement:* the circle of radius $r$ and center $A$ is the translation by $A$ of the circle of radius $r$ and center $O$: $S(r,A)=T_A(S(r,O))$.
*Proof (Lang's):*
1. Let $X$ be on the circle centered at $O$: $|X|=r$.
2. $X+A$ satisfies $|(X+A)-A|=|X|=r$, so it lies on the circle of center $A$ (distance to $A$ is $r$).
3. Conversely, let $Y$ be on the circle of center $A$: $|Y-A|=r$. Put $X=Y-A$.
4. Then $|X|=r$ and $Y=X+A=T_A(X)$, so $Y$ is the image of a point of the circle at $O$.
5. Hence the two sets coincide.
*Intuition:* sliding a circle by $A$ moves its center from $O$ to $A$ and changes nothing else.
*Example:* $A=(1,4)$, $r=3$: $X=(3,0)$ has $|X|=3$ and $X+A=(4,4)$ lies at distance $3$ from $(1,4)$.

**Rules relating number-multiplication and addition.**
*Statement:* for numbers $b,c$ and points $A,B$: $b(cA)=(bc)A$; $(b+c)A=bA+cA$; $c(A+B)=cA+cB$; $1A=A$; $0A=O$.
*Proof (Lang's, for one distributivity):* $(b+c)A=((b+c)a_1,(b+c)a_2)$ by definition $=(ba_1+ca_1,\,ba_2+ca_2)$ by distributivity for numbers $=(ba_1,ba_2)+(ca_1,ca_2)=bA+cA$. The rest are left to the reader (reduce to numbers).

### Recall prompts — Chapter 9
1. Define $cA$, dilation, $-A$ and reflection through $O$. How is multiplication by a negative number $c=-r$ built from them?
2. State and prove: $d(rA,rB)=r\,d(A,B)$ for $r>0$. What changes for a general number $c$, and why does $|c|=\sqrt{c^2}$ appear?
3. List the four properties of addition of points and prove commutativity by reduction to numbers.
4. Explain with coordinates why $O,A,B,A+B$ form a parallelogram, and what the parallelogram looks like for $A-B$.
5. Define translation $T_A$ and isometry. What is the norm $|A|$, and why is $d(A,B)=|A-B|$?
6. State and prove Theorem 3 (circle of radius $r$ at $A$ = translation of circle at $O$), proving both inclusions.
7. Prove $(b+c)A=bA+cA$ from the definitions, naming each step.
8. Show $|A|=|-A|$ and $|cA|=|c||A|$.

## Chapter 10 — Segments, Rays, and Lines

> With addition and dilation, a segment becomes $\{P+tA: 0\le t\le1\}$, a ray $\{P+tA: t\ge0\}$, and a line $\{P+tA: t\in\mathbf R\}$. Parametric form lets us compute intersections (with the $x$-axis, other lines, circles) by solving equations in $t$, and §4 converts it to the ordinary equation $ax+by=c$.

### §1. Segments

**Definitions.**
- The **line segment** between $P$ and $Q$ (with $Q=P+A$, $A=Q-P$) is the set of points $P+tA$ with $0\le t\le1$; denoted $PQ$. It is $T_P(OA)$, the translate by $P$ of the segment $OA=\{tA:0\le t\le1\}$. Its **length** is $d(P,Q)$. Because $A=Q-P$, the segment is the image $T_P(\overline{OA})$; the segment between $P$ and $Q$ is written $\overline{PQ}$.
- The point halfway between $P$ and $P+A$ is $P+\tfrac12A$.
- **Located vector** $\overrightarrow{PQ}$: an *ordered* pair of points, drawn as an arrow; $P$ is the **beginning point** ($\overrightarrow{PQ}$ is **located at** $P$), $Q$ the **end point**. Order matters here: $\overrightarrow{PQ}\neq\overrightarrow{QP}$ (unlike $PQ=QP$ for segments).

**Theorem (symmetry of segments).**
*Statement:* $PQ=QP$ as sets.
*Proof (Lang's):*
1. $PQ=\{P+t(Q-P)\}=\{(1-t)P+tQ: 0\le t\le1\}$ (expand $P+tQ-tP$).
2. Put $s=1-t$. As $t$ runs from $0$ to $1$, $s$ runs from $1$ to $0$, so $PQ=\{sP+(1-s)Q:0\le s\le1\}$.
3. This is the set for $QP$ with parameter $1-s$, so the same points occur.
*Intuition:* the same points, traveled in either direction.
*Example:* $P=(1,2)$, $Q=(5,6)$: midpoint $P+\tfrac12(Q-P)=(1,2)+(2,2)=(3,4)$, and also $\tfrac12P+\tfrac12Q=(3,4)$.

### §2. Rays

**Definitions.**
- For $A\neq O$ and a point $P$, the **ray with vertex $P$ in the direction of $\overrightarrow{OA}$** (or "of $A$") is $\{P+tA: t\ge0\}$. With $P=O$ it is $\{tA:t\ge0\}$; the general ray is the translate by $P$ of that.
- **Ray through $Q$ with vertex $P$** ($P\neq Q$): direction $Q-P$, i.e. $\{P+t(Q-P):t\ge0\}$.
- **Same direction:** for $A,B\ne O$, $A$ and $B$ have the same direction if $B=cA$ for some $c>0$ (equivalently each is a positive multiple of the other; $A=(1/c)B$). Example (Lang): $A=(3,5)$, $B=(9,15)=3A$. For located vectors $\overrightarrow{PQ}$, $\overrightarrow{MN}$: same direction if $Q-P=c(N-M)$ for some $c>0$.
- Example: ray with vertex $(-1,3)$ in direction $(2,1)$ contains $(-1,3)+5(2,1)=(9,8)$ and, for $t=\tfrac13$, $(-\tfrac13,\tfrac{10}3)$. Example: $P=(1,3),Q=(-4,2),M=(7,1),N=(-3,-1)$: $Q-P=(-5,-1)$, $N-M=(-10,-2)=2(Q-P)$, so same direction.

**Ray through a point (Lang's example).** $P=(-1,3)$, $Q=(2,5)$: $Q-P=(3,2)$, so the ray with vertex $P$ through $Q$ is $\{(-1,3)+t(3,2):t\ge0\}=\{(-1+3t,\,3+2t)\}$; $t=1$ gives $Q$. *Misprint:* the book (p. 232) writes the direction as $(2,5)$, i.e. $(-1,3)+t(2,5)=(-1+2t,3+5t)$, which is $Q$ itself and not $Q-P$; it should be $(3,2)$, as the line just above it says.

**Remark (ray invariance).**
*Statement:* if $A\ne O$ and $c>0$, the ray with vertex $P$ in direction $A$ equals the ray with vertex $P$ in direction $cA$.
*Proof (Lang's):*
1. The first ray is $\{P+tA:t\ge0\}$, the second is $\{P+s(cA):s\ge0\}$.
2. Given $P+tA$ on the first, put $s=t/c\ge0$; then $P+s(cA)=P+tA$ lies on the second.
3. Given $P+s(cA)$ on the second, put $t=sc\ge0$; it equals $P+tA$ on the first.
4. So the rays are equal.
*Intuition:* scaling the direction vector by a positive number only changes the speed along the same ray.

**Constructing a vector of prescribed direction and length (worked result).**
Given $P,Q,M$, to find $N$ with $\overrightarrow{MN}$ having the same direction and same length as $\overrightarrow{PQ}$, solve $N-M=Q-P$, so $N=M+Q-P$. Example: $P=(-3,5),Q=(1,2),M=(4,1)$: $N=(4,1)+(1,2)-(-3,5)=(8,-2)$.

**Physical use (stated, not proved).** A force at $P$ is a located vector (direction, with length as magnitude). Two forces $A$, $B$ acting on a body at $O$ give, as verified experimentally, a motion in the direction of $A+B$ with magnitude $|A+B|$.

### §3. Lines

**Definitions.**
- **Parallel** (located vectors/segments $\overrightarrow{PQ}$, $\overrightarrow{MN}$ with $P\ne Q$, $M\ne N$): there is a number $c$ (positive *or* negative) with $Q-P=c(M-N)$. Points are taken in any order. For $A,B\ne O$: $A$ is parallel to $B$ iff $A=cB$ for some $c\ne0$ (i.e. $OA$ parallel to $OB$).
- Lang leaves as exercises (not proved in the book): parallelism is transitive ($P_1Q_1\parallel P_2Q_2$ and $P_2Q_2\parallel P_3Q_3$ imply $P_1Q_1\parallel P_3Q_3$) and symmetric.
- **Line** through $P$ parallel to $A\ne O$: $\{P+tA: t\in\mathbf R\}$ (with $P=O$: $\{tA\}$). It is the translate by $P$ of the line through $O$.
- **Straight line (analytic definition):** through the origin parallel to $A\ne O$: all $tA$, $t\in\mathbf R$; through $P$: all $P+tA$ with $t$ positive, negative or $0$, also written $\{P+tA\}_{t\in\mathbf R}$. Example (Lang): through $(-3,4)$ parallel to $(1,-1)$: $(-3,4)+t(1,-1)$, containing $(-3,4)$ ($t=0$) and $(-2,3)$ ($t=1$). (The book's text says "parallel to $(1,-5)$" but the formula uses $(1,-1)$; the figure matches $(1,-1)$.) Example: $P=(-1,4)$, $A=(2,3)$: $x(t)=-1+2t$, $y(t)=4+3t$.
- **Parametric representation:** $P+tA$; $t$ is the **parameter** (think: time for a bug moving with uniform velocity $A$; $|A|$ is its speed). Coordinates are $x(t),y(t)$.

**Remark (speed does not change the set).** $\{P+3tA\}_{t\in\mathbf R}=\{P+tA\}_{t\in\mathbf R}$: a faster bug covers the same ground. (Substitute $t\mapsto3t$.)

**Line through two points.**
*Statement:* for $P\ne Q$ the line through them is $\{P+t(Q-P)\}_{t\in\mathbf R}$ ($t=0$ gives $P$, $t=1$ gives $Q$).
*Example (Lang's):* $P=(1,5)$, $Q=(-2,3)$: $Q-P=(-3,-2)$, so $x(t)=1-3t$, $y(t)=5-2t$.

**Crossing an axis.** *Example (Lang's):* for the line above, $y(t)=5-2t=0\Rightarrow t=\tfrac52$, so it crosses the $x$-axis at $(1,5)-\tfrac52(3,2)=(-\tfrac{13}2,\,0)$.

**Intersection of two lines.**
*Method (Lang's example):* lines $(1,2)+t(3,4)$ and $(-1,1)+s(2,-1)$ meet where $1+3t=-1+2s$ and $2+4t=1-s$, i.e. $3t-2s=-2$, $4t+s=-1$.
1. From the second, $s=-1-4t$.
2. Substitute into the first: $3t+2+8t=-2$, so $t=-\tfrac4{11}$, and $s=\tfrac5{11}$.
3. Point: $(1,2)-\tfrac4{11}(3,4)=(-\tfrac1{11},\tfrac6{11})$; check: $(-1,1)+\tfrac5{11}(2,-1)$ gives the same.
Exercise 13 in the book asks to prove that non-parallel lines meet in exactly one point (the $2\times2$ system for $s,t$ is solvable); Exercise 12 asks to prove $A\parallel B\iff a_1b_2-a_2b_1=0$. Both are left to the reader.

**Intersection of a line and a circle.**
*Method (Lang's):* substitute $x(t),y(t)$ into the circle equation and solve the quadratic in $t$. (Addition, not stated by Lang in general: the number of real roots, hence of intersection points, is $2,1,0$ according as the discriminant is $>0,=0,<0$; his two examples show the cases $>0$ and $<0$.)
*Example 1:* line $(-1,2)+t(3,-4)$ and $x^2+y^2=4$: $(-1+3t)^2+(2-4t)^2=4\Rightarrow 25t^2-22t+1=0$, discriminant $22^2-100=384=4\cdot96$, so
$$t=\frac{22\pm\sqrt{384}}{50}=\frac{11\pm\sqrt{96}}{25}$$
(*Misprint:* the book (p. 242) writes the quadratic formula correctly with $22$, then simplifies to $\frac{14\pm\sqrt{384}}{50}$ and $\frac{7\pm\sqrt{96}}{25}$ and uses $7\pm\sqrt{96}$ in the coordinates below; $22$ is right, since $\sqrt{384}=2\sqrt{96}$ gives $(11\pm\sqrt{96})/25$.) The two points are $(-1+3t,\,2-4t)$ for these $t$. Lang draws the line through $t=0,1$: $(-1,2)$ and $(2,-2)$.
*Example 2:* line $(-5,0)+t(1,1)$ and the same circle: $(-5+t)^2+t^2=4\Rightarrow 2t^2-10t+21=0$, discriminant $100-168<0$, so no real $t$: the line misses the circle. (Lang uses $t=0,5$ to draw the line: points $(-5,0)$ and $(0,5)$.)

### §4. Ordinary equation for a line

**Definition.** For $L=\{P+tA\}$, the **ordinary equation** is the equation in $x,y$ alone (parameter eliminated). Lang states, without proof, that any equation $ax+by=c$ is the equation of a straight line (he works only the example below; implicitly $(a,b)\ne(0,0)$).

**Theorem (elimination of $t$, via example).**
*Statement:* for $P=(3,5)$, $A=(-2,7)$, the line $L=\{P+tA\}$ is exactly the set of $(x,y)$ with $7x+2y=31$.
*Proof (Lang's):*
1. A point of $L$ has $x=3-2t$, $y=5+7t$.
2. Compute $7x+2y=21-14t+10+14t=31$. So every point of $L$ satisfies $7x+2y=31$.
3. Conversely, let $7x+2y=31$. Put $t=-(x-3)/2$; then $x=3-2t$.
4. $y=(31-7x)/2$, and $5+7t=5-\tfrac{7(x-3)}2=\tfrac{10-7x+21}{2}=\tfrac{31-7x}2$. So $y=5+7t$ too, and $(x,y)\in L$.
*Intuition:* multiply the two parametric equations so that $t$ cancels: use the coefficients $(7,2)$ taken from $A=(-2,7)$ as $(a_2,-a_1)$.
*Example:* $P=(3,5)$, $A=(-2,7)$ above; check $(5,-2)=P+(-1)A$: $7\cdot5+2\cdot(-2)=31$.

### Recall prompts — Chapter 10
1. Define the segment $PQ$, its length, and prove $PQ=QP$.
2. Define a ray with vertex $P$ in direction $A$; prove that direction $A$ and direction $cA$ ($c>0$) give the same ray.
3. When do two located vectors have the same direction? Given $P,Q,M$, find $N$ with $\overrightarrow{MN}$ of the same direction and length as $\overrightarrow{PQ}$.
4. Define parallel vectors/segments (why may $c$ be negative here but not in "same direction"?) and a line $\{P+tA\}$.
5. Write the parametric equations of the line through two points, and find where it meets the $x$-axis.
6. Show how to find the intersection point of two non-parallel lines given parametrically.
7. Explain how to intersect a line with a circle and how the discriminant decides the number of points.
8. Derive the ordinary equation $7x+2y=31$ from $P=(3,5)$, $A=(-2,7)$, showing both inclusions.
9. Explain why the sets $\{P+3tA\}$ and $\{P+tA\}$ coincide.

## Chapter 11 — Trigonometry

> We measure angles by the area of a unit sector (radians), define sine and cosine as coordinates of a point on the unit circle, and extend them to all real numbers so that they are periodic. The tangent is the quotient. Everything else follows from the addition formulas, which we prove by computing one distance in two coordinate systems. The same formulas give the matrix of a rotation, which Chapter 12 uses to rotate the hyperbola $xy=1$.

### §1. Radian measure

**Definitions.**
- $\pi$ is the area of the disc of radius 1 ($\approx 3.14159\ldots$).
- Let $A$ be an angle with vertex $P$, and $S$ the sector it cuts out of the unit disc $D$ centered at $P$. $A$ has **$x$ radians** ($0\le x\le 2\pi$) means $\dfrac{\text{area } S}{\text{area } D}=\dfrac{x}{2\pi}$. So the sector has area $x/2$.
- Degrees to radians: $360^\circ=2\pi$, $180^\circ=\pi$, $60^\circ=\pi/3$, $45^\circ=\pi/4$, $30^\circ=\pi/6$; in general $x$ degrees $=\dfrac{\pi}{180}x$ radians.
- **Arc length.** The unit circle has length $2\pi$, and the arc cut by $A$ satisfies $\dfrac{\text{arc}}{2\pi}=\dfrac{x}{2\pi}$. So $x$ is the length of the arc.
- **Any real $x$.** Write $x=2n\pi+w$ with $n$ an integer, $0\le w<2\pi$. An angle of $x$ radians means the angle of $w$ radians.
- **Negative $x=-z$.** The angle of $z$ radians measured clockwise.

*Intuition:* radians count arc length on the unit circle. The factor $2$ in $2\pi$ is a historical nuisance (Lang: a constant $c$ for the full turn would have been neater).

*Example:* $75^\circ=\dfrac{\pi}{180}\cdot75=\dfrac{5\pi}{12}$. And $\dfrac{14\pi}{3}=4\pi+\dfrac{2\pi}{3}$, so it is the angle of $2\pi/3$ radians ($120^\circ$).

### §2. Sine and cosine

**Definitions.**
- Place angle $A$ with vertex at the origin, one side the positive $x$-axis. Choose $(a,b)\ne O$ on the other side; $r=\sqrt{a^2+b^2}$. Then
$$\sin A=\frac{b}{r},\qquad \cos A=\frac{a}{r}.$$
- On the unit circle ($r=1$): $\sin A=b$, $\cos A=a$. The point of the unit circle at angle $\theta$ is $(\cos\theta,\sin\theta)$.
- Right triangle: $\sin A=\dfrac{\text{opposite}}{\text{hypotenuse}}$, $\cos A=\dfrac{\text{adjacent}}{\text{hypotenuse}}$.
- **Sine and cosine of a number.** For $x=2n\pi+w$, $0\le w<2\pi$: $\sin x=\sin(w\text{ radians})$, $\cos x=\cos(w\text{ radians})$. Hence $\sin(x+2n\pi)=\sin x$, $\cos(x+2n\pi)=\cos x$ (**periodicity**, period $2\pi$).
- **Polar coordinates** $(r,\theta)$ of the point $(x,y)$ (**Cartesian** or rectangular coordinates): $x=r\cos\theta$, $y=r\sin\theta$. This is valid also for $r=0$. Polar coordinates are not unique: $(r,\theta+2n\pi)$ describes the same point. Normally we take $0\le\theta<2\pi$.

**Well-definedness (not numbered).**
*Statement:* $\sin A$ and $\cos A$ do not depend on the choice of $(a,b)$ on the ray.
*Proof (Lang's):*
1. Another point $(a_1,b_1)$ on the ray equals $(ca,cb)$ for some $c>0$.
2. Then $\dfrac{b_1}{\sqrt{a_1^2+b_1^2}}=\dfrac{cb}{\sqrt{c^2a^2+c^2b^2}}$.
3. Factor $c$ out of the root and cancel: $=\dfrac{b}{\sqrt{a^2+b^2}}$. The cosine is the same.

*Intuition:* the triangles are similar (one is a dilation of the other).

**Signs.** First quadrant: $\sin,\cos>0$. Second: $\sin>0$ ($b>0$), $\cos<0$ ($a<0$). Third: both negative. Fourth: $\sin<0$, $\cos>0$.

**Table of values** (found with plane geometry and Pythagoras):

| $x$ | $\sin x$ | $\cos x$ |
|---|---|---|
| $\pi/6$ | $1/2$ | $\sqrt3/2$ |
| $\pi/4$ | $1/\sqrt2$ | $1/\sqrt2$ |
| $\pi/3$ | $\sqrt3/2$ | $1/2$ |
| $\pi/2$ | $1$ | $0$ |
| $\pi$ | $0$ | $-1$ |
| $2\pi$ | $0$ | $1$ |

*Derivation (Lang's):*
1. $\pi/4$: a right triangle with two equal legs $a$ has hypotenuse $\sqrt{2a^2}=\sqrt2\,a$, so $\sin=a/(\sqrt2 a)=1/\sqrt2$.
2. $\pi/6,\pi/3$: take a right triangle $PQM$ with angles $30^\circ,60^\circ$. Reflect $P$ through $M$ to $P'$ (reflect through the side $QM$). Then $PQP'$ has all angles equal, so all sides are equal.
3. Hence the hypotenuse $c=2a$ where $a$ is the short leg, and $a^2+b^2=c^2=4a^2$, so $b^2=3a^2$, $b=\sqrt3\,a$.
4. So $\sin\frac{\pi}{6}=\frac12$ and $\cos\frac{\pi}{6}=\frac{\sqrt3}{2}$. Normalized: sides $1,2,\sqrt3$.

**Basic identity (SC 1).**
*Statement:* for all $x$, $\sin^2x+\cos^2x=1$ (here $\sin^2x=(\sin x)^2$).
*Proof (Lang's):* take $(a,b)$ on the unit circle; $\sin^2x+\cos^2x=b^2+a^2=1$.

**Theorem 1.**
*Statement:* for any number $x$: $\cos x=\sin\!\left(x+\dfrac\pi2\right)$ and $\sin x=\cos\!\left(x-\dfrac\pi2\right)$. (Lang later lists these as **SC 4** and **SC 5**.)
*Proof (Lang's):*
1. Assume $0\le x<2\pi$. Let $P=(a,b)$ be the point of the unit circle on the side of the angle of $x$ radians, and $Q=(a,0)$ its projection to the first axis.
2. Let $G$ be rotation by $\pi/2$, $P'=G(P)$, $Q'=G(Q)=(0,a)$.
3. If $P=Q$ the formula is clear. Otherwise $PQ$ is perpendicular to the first axis, so $P'Q'$ is perpendicular to the second axis (rotation preserves right angles). Hence the second coordinate of $P'$ equals that of $Q'$, which is $a$: $b'=a$.
4. $P$ is on the unit circle, so $\cos x=a$ and $\sin(x+\pi/2)=b'$. Hence $\sin(x+\pi/2)=\cos x$.
5. The second formula: *proved similarly; left to the reader.*

*Intuition (ours, from §6):* rotating by a quarter turn sends $(\cos x,\sin x)$ to $(-\sin x,\cos x)$; the $y$-coordinate is $\cos x$.

**Theorem 2.**
*Statement:* $\sin(-x)=-\sin x$ and $\cos(-x)=\cos x$ (Lang later lists them as **SC 3** and **SC 2**).
*Proof (Lang's):*
1. If $(a,b)$ is on the unit circle on the ray of angle $x$, then $(a,-b)$ is on the ray of angle $-x$ (reflection in the $x$-axis).
2. So $\sin(-x)=-b=-\sin x$ and $\cos(-x)=a=\cos x$.

*Example (boat and river):* observer $O$ is 1000 ft from $P$ on the perpendicular to the river; the boat $B$ is at distance $c$ from $O$, and the angle at $O$ has $\cos\theta=0.7$.
1. Right triangle $POB$: $\cos\theta=\dfrac{1000}{c}$.
2. So $\dfrac{1000}{c}=0.7$, $c=\dfrac{1000}{0.7}=\dfrac{10{,}000}{7}$ ft.

**Polar coordinates, results.**
- From $(x,y)$: $r=\sqrt{x^2+y^2}$, then find $\theta$ with $\cos\theta=x/r$, $\sin\theta=y/r$.
- *Example:* $(1,\sqrt3)$: $r=\sqrt{1+3}=2$, $\cos\theta=\tfrac12$, $\sin\theta=\tfrac{\sqrt3}2$, so $\theta=\pi/3$; polar coordinates $(2,\pi/3)$ (and $(2,\pi/3+2n\pi)$).
- *Fact (unit circle).* If $a^2+b^2=1$ there is a $\theta$ with $a=\cos\theta$, $b=\sin\theta$. Lang's construction: $a^2\le1$ forces $-1\le a\le1$ (he treats $a>0$, so $0<a\le1$); the vertical line through $(a,0)$ meets the unit circle in two points; take $\theta>0$ if $b>0$, $\theta<0$ if $b<0$ (case $a>0$, $-\pi/2<\theta<\pi/2$; $a<0$ similar).
- *Example:* $a=\tfrac12$, $b=-\tfrac{\sqrt3}{2}$: $\theta=-\pi/3$.

### §3. The graphs

**Definitions.** The **graph of the sine** is the set of points $(x,\sin x)$.

*Description (Lang's):* on the unit circle $\sin x=b$, the height of the point.
1. $x$ from $0$ to $\pi/2$: $b$ increases from $0$ to $1$.
2. $\pi/2$ to $\pi$: decreases from $1$ to $0$.
3. $\pi$ to $3\pi/2$: negative, decreases from $0$ to $-1$.
4. $3\pi/2$ to $2\pi$: increases from $-1$ to $0$.
5. Then it repeats (period $2\pi$).

*Intuition:* a wave of height $\pm1$. (The cosine graph, $\sin 2x$ and so on are exercises in the book; that the cosine is the sine wave shifted by $\pi/2$ is our remark from Theorem 1.)

### §4. The tangent

**Definitions.**
- $\tan A=\dfrac{\sin A}{\cos A}$; $\tan x=\dfrac{\sin x}{\cos x}$ when $\cos x\ne0$, i.e. $x\ne\dfrac\pi2+n\pi$.
- Lang defines $\tan$ for angles other than $\pi/2$, $3\pi/2$ (where $\cos A=0$).
- *Not in the text; Lang's Exercises 3–6 only (our addition):* $\cot x=1/\tan x$, $\sec x=1/\cos x$, $\csc x=1/\sin x$, and the exercise to prove $1+\tan^2x=\sec^2x$.

**Property.**
*Statement:* if $(a,b)$ is on the ray of $A$, then $\tan A=b/a$.
*Proof (Lang's):* $\dfrac{b/r}{a/r}=\dfrac ba$; the $r$ cancels.

**Remark (slope).** The tangent of the angle that a line makes with the $x$-axis is its slope. E.g. for $y=-3x$ take the point $(1,-3)$: $\tan=-3$.

*Intuition:* rise over run. $\tan x$ is $0$ at $x=0$ and grows without bound as $x\to\pi/2$ because $\sin x\to1$ and $\cos x\to0^+$ ($1/\cos x$ becomes large). The graph has vertical asymptotes at $\pi/2+n\pi$.

*Example 1:* in a 3-4-5 right triangle, the angle $A$ (opposite the side 4, adjacent to the side 3) has $\tan A=4/3$. Also $\tan\dfrac\pi3=\sqrt3$.

*Example 2 (all possible $\cos x$ given $\tan x=2$):*
1. $\tan x>0$, so $x$ is in the first or the third quadrant (negative in the second and fourth).
2. The right triangle has legs 1 and 2, hypotenuse $\sqrt5$.
3. First quadrant: $\cos x=1/\sqrt5$. Third quadrant: $\cos x=-1/\sqrt5$.

*Example 3 (tower):* the height $y$ and the distance $a$ along the ground satisfy $y/a=\tan A$, so $y=a\tan A$. For $a=100$ ft, $A=\pi/3$: $y=100\sqrt3$ ft.

### §5. Addition formulas

**Theorem 3.**
*Statement:* for any angles $A,B$:
$$\sin(A+B)=\sin A\cos B+\cos A\sin B,\qquad \cos(A+B)=\cos A\cos B-\sin A\sin B.$$
*Proof (Lang's), cosine first:* compute the squared distance $|PQ|^2$ between two points of the unit circle in two coordinate systems.
1. System 1 (usual): $P=(1,0)$, $Q=(\cos(A+B),\sin(A+B))$. Then
$|PQ|^2=\sin^2(A+B)+(\cos(A+B)-1)^2=\sin^2+\cos^2-2\cos(A+B)+1=2-2\cos(A+B)$, by SC 1.
2. System 2: turn the axes (Lang's Fig. 11-31) so that the new first axis lies along the ray at angle $A$ from $P$, i.e. $P$ now sits at angle $-A$ and $Q$ at angle $B$ (the angle from $P$ to $Q$ is still $A+B$). Then $P=(\cos A,\sin(-A))=(\cos A,-\sin A)$ by Theorem 2, and $Q=(\cos B,\sin B)$.
3. $|PQ|^2=(\sin B+\sin A)^2+(\cos B-\cos A)^2=\sin^2B+2\sin A\sin B+\sin^2A+\cos^2B-2\cos A\cos B+\cos^2A=2+2\sin A\sin B-2\cos A\cos B$ (SC 1 twice).
4. Distance does not depend on the coordinate system, so $2-2\cos(A+B)=2+2\sin A\sin B-2\cos A\cos B$. Hence $\cos(A+B)=\cos A\cos B-\sin A\sin B$.
5. Sine (Lang: "by the following device, using Theorem 2"): $\sin(A+B)=\cos\!\left(A+B-\tfrac\pi2\right)$ (Theorem 1). Apply the cosine formula to $A$ and $B-\tfrac\pi2$: $=\cos A\cos(B-\tfrac\pi2)-\sin A\sin(B-\tfrac\pi2)$.
6. Lang's chain: $=\cos A\sin B+\sin A\sin(\tfrac\pi2-B)=\cos A\sin B+\sin A\cos B$. (Justification, ours: $\cos(B-\tfrac\pi2)=\sin B$ and $\sin(B-\tfrac\pi2)=-\sin(\tfrac\pi2-B)$ by Theorems 1, 2; $\sin(\tfrac\pi2-B)=\cos B$ by Theorem 1.)

*Intuition:* rotating by $A$ then $B$ is rotating by $A+B$; the chord length between two unit-circle points depends only on the angle between them.

**Corollary.**
*Statement:* $\sin(x-y)=\sin x\cos y-\cos x\sin y$, $\cos(x-y)=\cos x\cos y+\sin x\sin y$.
*Proof (Lang):* "follows from the theorem by using Theorem 2; write out the details in full", i.e. left to the reader. (Details, ours: replace $y$ by $-y$ in Theorem 3, with $\cos(-y)=\cos y$, $\sin(-y)=-\sin y$.)

**What to memorize (Lang's Remark).** Theorem 3, SC 1 ($\sin^2+\cos^2=1$), SC 2 ($\cos(-x)=\cos x$), SC 3 ($\sin(-x)=-\sin x$), SC 4 ($\sin(x+\tfrac\pi2)=\cos x$), SC 5 ($\cos(x-\tfrac\pi2)=\sin x$). Everything else is derived on demand.

**Double and half-angle formulas (SC 6–9).**
$$\sin2x=2\sin x\cos x,\quad \cos2x=\cos^2x-\sin^2x,$$
$$\cos^2x=\frac{1+\cos2x}2,\quad \sin^2x=\frac{1-\cos2x}2.$$
*Proof:* Lang says these follow easily from Theorem 3 and leaves the proofs to the reader (Exercise 4; hint: for SC 8 start from SC 7 and substitute $1-\cos^2x$ for $\sin^2x$; SC 9 similarly). Steps (ours, following that hint):
1. In Theorem 3 put $A=B=x$: gives SC 6 and SC 7.
2. For SC 8: in SC 7 replace $\sin^2x$ by $1-\cos^2x$: $\cos2x=2\cos^2x-1$, solve for $\cos^2x$.
3. For SC 9: replace $\cos^2x$ by $1-\sin^2x$: $\cos2x=1-2\sin^2x$, solve.

*Example 1 ($\sin\frac\pi{12}$):* $\frac\pi{12}=\frac\pi3-\frac\pi4$. By the Corollary, $\sin\frac\pi{12}=\sin\frac\pi3\cos\frac\pi4-\cos\frac\pi3\sin\frac\pi4=\frac{\sqrt3}2\cdot\frac1{\sqrt2}-\frac12\cdot\frac1{\sqrt2}=\dfrac{\sqrt3-1}{2\sqrt2}$ $(=\tfrac{\sqrt6-\sqrt2}{4})$.

*Example 2 ($\sin2x$ given $\sin x=0.8$, $0<x<\pi/2$):*
1. $\cos x=\sqrt{1-0.64}=\sqrt{0.36}=0.6$ (positive root, since $x$ is in the first quadrant).
2. $\sin2x=2(0.8)(0.6)=0.96$.

*Example 3 ($\cos\frac\pi8$ and $\sin\frac\pi8$):*
1. SC 8 with $x=\pi/8$: $\cos^2\frac\pi8=\dfrac{1+\cos\frac\pi4}2=\dfrac12+\dfrac1{2\sqrt2}$.
2. $\cos\frac\pi8=\sqrt{\tfrac12+\tfrac1{2\sqrt2}}$ (positive, first quadrant).
3. By SC 1: $\sin\frac\pi8=\sqrt{1-\cos^2\frac\pi8}=\sqrt{\tfrac12-\tfrac1{2\sqrt2}}$.

### §6. Rotations

**Definitions.**
- $G_\varphi$: rotation about the origin by $\varphi$ radians.
- A **matrix** (2 x 2) is an array $\begin{pmatrix}a&b\\c&d\end{pmatrix}$. Product with a point: $\begin{pmatrix}a&b\\c&d\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}=\begin{pmatrix}ax+by\\cx+dy\end{pmatrix}$.

**Theorem (coordinates of a rotation; boxed in the book).**
*Statement:* if $P=(x,y)$ and $G_\varphi(P)=P'=(x',y')$ then
$$x'=(\cos\varphi)x-(\sin\varphi)y,\qquad y'=(\sin\varphi)x+(\cos\varphi)y,$$
i.e. $\begin{pmatrix}x'\\y'\end{pmatrix}=\begin{pmatrix}\cos\varphi&-\sin\varphi\\\sin\varphi&\cos\varphi\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}$.
*Proof (Lang's):*
1. Let $(r,\theta)$ be polar coordinates of $P$. Rotation adds $\varphi$ to the angle: $P'$ has polar coordinates $(r,\theta+\varphi)$ (Lang states this from the picture, Fig. 11-32).
2. So $x=r\cos\theta$, $y=r\sin\theta$, $x'=r\cos(\theta+\varphi)$, $y'=r\sin(\theta+\varphi)$.
3. Addition formulas: $x'=r[\cos\theta\cos\varphi-\sin\theta\sin\varphi]$, $y'=r[\sin\theta\cos\varphi+\sin\varphi\cos\theta]$.
4. Distribute $r$ and substitute $x=r\cos\theta$, $y=r\sin\theta$ to get the formulas.

*Intuition (ours):* the columns of the matrix are the images of $(1,0)$ and $(0,1)$.

*Example ($\varphi=\pi/2$):* $\begin{pmatrix}\cos\frac\pi2&-\sin\frac\pi2\\\sin\frac\pi2&\cos\frac\pi2\end{pmatrix}=\begin{pmatrix}0&-1\\1&0\end{pmatrix}$, so $x'=-y$, $y'=x$. (Our numbers:) $(3,1)$ goes to $(-1,3)$. Lang's matrix example: $\begin{pmatrix}2&-1\\3&7\end{pmatrix}$ is a $2\times2$ matrix.
The rotation formulas are the "product" of the matrix with $(x,y)$; Lang's product example: $\begin{pmatrix}3&2\\-1&5\end{pmatrix}\begin{pmatrix}x\\y\end{pmatrix}=\begin{pmatrix}3x+2y\\-x+5y\end{pmatrix}$.

### Recall prompts — Chapter 11
1. Define "$A$ has $x$ radians" through areas and show that $x$ is also the arc length on the unit circle. Convert $x$ degrees to radians.
2. Define $\sin A$, $\cos A$ for an angle with a ray through $(a,b)$, and prove that the values do not depend on the point chosen.
3. Derive the values of sine and cosine at $\pi/4$, $\pi/6$, $\pi/3$ from Pythagoras and a reflected triangle.
4. State and prove $\sin^2x+\cos^2x=1$, and give the sign pattern of $\sin,\cos$ in the four quadrants.
5. State and prove Theorem 1 ($\cos x=\sin(x+\pi/2)$) with a rotation by $\pi/2$, and Theorem 2 (parity of sine and cosine).
6. Define polar coordinates; convert $(1,\sqrt3)$ to polar form; show every $(a,b)$ with $a^2+b^2=1$ is $(\cos\theta,\sin\theta)$.
7. State and prove the addition formula for the cosine by computing a distance in two coordinate systems. Then derive the sine formula from it and the difference formulas.
8. Derive $\sin2x$, $\cos2x$, $\cos^2x$, $\sin^2x$ from Theorem 3, and compute $\cos\frac\pi8$.
9. Define $\tan x$, show $\tan A=b/a$, and explain why $\tan$ of the angle of a line is its slope. Find all possible $\cos x$ when $\tan x=2$.
10. Derive the rotation formulas $x'=x\cos\varphi-y\sin\varphi$, $y'=x\sin\varphi+y\cos\varphi$ and write the matrix for $\varphi=\pi/2$.

## Chapter 12 — Some Analytic Geometry

> We describe a curve by an equation $F(x,y)=c$ and learn to recognize the standard shapes: straight lines, parabolas, ellipses, hyperbolas. The method is one idea: translate the coordinates (complete the square) or stretch/rotate them to bring the equation to a standard form. This gives the background for calculus and for the applications in physics and economics.

### §1. The straight line again

**Definitions.**
- The **graph of an equation** $F(x,y)=c$ is the set of points $(x,y)$ satisfying it.
- A line given by $y=ax+b$ has **slope** $a$.
- A vertical line has equation $x=c$ (no slope in this form).

**Property (lines through the origin).**
*Statement:* the graph of $y=ax$ is a straight line; its points are $x(1,a)$, i.e. the dilations of $(1,a)$ by $x$.
*Intuition:* if $a>0$ it slants to the right, if $a<0$ to the left.

**Property (translation).**
*Statement:* the graph of $y=ax+b$ is the line parallel to $y=ax$ through $(0,b)$.
*Proof (Lang's):*
1. Put $y'=y-b$; then $y=ax+b$ becomes $y'=ax$, a line through the origin of the $(x,y')$-system.
2. A point $(x,y')$ on $y'=ax$ gives the point $(x,y'+b)$ on $y=ax+b$: add $b$ to the second coordinate. This is a translation, so it keeps the line parallel.

*Example:* $y=2x+1$: $x=0\Rightarrow y=1$; $y=0\Rightarrow x=-\tfrac12$. Plot these two points. For $y=-2x-5$: $x=0\Rightarrow y=-5$; $y=0\Rightarrow x=-\tfrac52$.

**Slope from two points.**
*Statement:* if $(x_1,y_1)\ne(x_2,y_2)$ lie on $y=ax+b$, then $a=\dfrac{y_2-y_1}{x_2-x_1}$.
*Proof (Lang's):*
1. $y_1=ax_1+b$ and $y_2=ax_2+b$.
2. Subtract: $y_2-y_1=a(x_2-x_1)$.
3. Two distinct points of a line that is not vertical have $x_2\ne x_1$, so divide.
4. The order of the points does not matter: swapping them changes the sign of numerator and of denominator.

*Intuition:* the ratio of the vertical side to the horizontal side of the triangle.
*Example:* on $y=2x+5$, the points $(1,7)$ and $(-1,3)$ give $\dfrac{7-3}{1-(-1)}=2$.

**Line through two points; line with given slope and point.**
*Statement:* the line through $(x_1,y_1)$ with slope $a$ is $y-y_1=a(x-x_1)$. The line through $(x_1,y_1)$ and $(x_2,y_2)$ is, for $x\ne x_1$, $\dfrac{y-y_1}{x-x_1}=\dfrac{y_2-y_1}{x_2-x_1}$.
*Proof (Lang's, by the method of the examples):* find $a$ (slope) from the two points, write $y=ax+b$, and fix $b$ by inserting one of the points.
*Example 1:* through $(1,2)$ and $(2,-1)$: slope $=\dfrac{-1-2}{2-1}=-3$; $y=-3x+b$; $2=-3+b$ gives $b=5$; the line is $y=-3x+5$.
*Example 2:* slope $-7$ through $(-1,2)$: $y=-7x+b$, $2=(-7)(-1)+b$, $b=-5$; the line is $y=-7x-5$.

**Intersection with a circle (method).** A point lies on both curves iff its coordinates satisfy both equations. Substitute $y=ax+b$ into the circle equation and solve the quadratic in $x$. Lang: two points when the discriminant is positive, no real solution (no intersection) when it is negative (the tangent case, discriminant $0$, is our addition).
*Example 1:* $y=3x+2$, $x^2+y^2=1$.
1. $x^2+(3x+2)^2=1$, so $10x^2+12x+3=0$.
2. $x=\dfrac{-12\pm\sqrt{144-120}}{20}=\dfrac{-6\pm\sqrt6}{10}$.
3. $y=3x+2$ gives two points: $\left(\dfrac{-6\pm\sqrt6}{10},\ \dfrac{2\pm3\sqrt6}{10}\right)$ (same sign choice in both coordinates; the book prints the first coordinate of the second point as $(-6-\sqrt6)/2$, a misprint for $/10$).

*Example 2:* $y=x+5$, $x^2+y^2=1$: $2x^2+10x+24=0$, discriminant $100-192<0$. No real solution, so the line and the circle do not meet. (Exercise 28 asks: two lines $y=ax+b$, $y=cx+d$ with $b\ne d$ are parallel iff same slope, and then have no common point; otherwise exactly one.)

### §2. The parabola

**Definitions.**
- A **parabola** is a curve with equation $(y-b)=c(x-a)^2$ in some coordinate system. The tilted version $x=y^2$ (or $(x-a)=c(y-b)^2$) is also called a parabola.
- A **translation of coordinates**: $x'=x-a$, $y'=y-b$. The point $(a,b)$ becomes the new origin.

**Method (translation).**
*Statement:* the graph of $(y-b)=(x-a)^2$ looks like the graph of $y=x^2$, but with the origin moved to $(a,b)$.
*Proof (Lang's):* with $x'=x-a$, $y'=y-b$ the equation becomes $y'=x'^2$.
*Intuition:* $y=x^2$ is symmetric about the $y$-axis since $(-x)^2=x^2$, positive, increasing for $x>0$ (table: 1,4,9,16 at $x=1,\dots,4$).

*Example 1:* $2y-x^2-4x+6=0$.
1. Complete the square: $x^2+4x=(x+2)^2-4$.
2. Then $2y=(x+2)^2-10$, i.e. $2(y+5)=(x+2)^2$.
3. With $x'=x+2$, $y'=y+5$: $y'=\tfrac12x'^2$, a parabola with vertex at $(-2,-5)$.

*Example 2:* $x-y^2+2y+5=0$.
1. Complete the square in $y$: $y^2-2y=(y-1)^2-1$, so $x+6=(y-1)^2$.
2. A parabola opening to the right with vertex $(-6,1)$.

**Remark (focus, not proved).** A parabolic mirror reflects rays parallel to the axis to a single point, the **focus**. Lang does not give formulas for it.

### §3. The ellipse

**Definitions.**
- **Dilation** of $(x,y)$ by $a>0$: $(ax,ay)$.
- **Mixed dilation** $F_{a,b}$ ($a,b>0$): $(x,y)\mapsto(ax,by)$. It stretches the first coordinate by $a$ and the second by $b$.
- An **ellipse** is a curve with equation $\dfrac{u^2}{a^2}+\dfrac{v^2}{b^2}=1$ in some coordinate system.

**Theorem (ellipse as stretched circle).**
*Statement:* the image of the unit circle $x^2+y^2=1$ under $F_{a,b}$ is the set of points $(u,v)$ with $\dfrac{u^2}{a^2}+\dfrac{v^2}{b^2}=1$.
*Proof (Lang's):*
1. Let $(x,y)$ be on the circle, $u=ax$, $v=by$. Then $\left(\frac ua\right)^2+\left(\frac vb\right)^2=x^2+y^2=1$.
2. Conversely, if $(u,v)$ satisfies the equation, put $x=u/a$, $y=v/b$ (the book prints $y=u/b$, a misprint). Then $x^2+y^2=1$ and $(u,v)=F_{a,b}(x,y)$.

*Intuition:* a circle squashed to semi-axes $a$ (horizontal) and $b$ (vertical).

*Example 1:* $\dfrac{u^2}{3^2}+\dfrac{v^2}{2^2}=1$. $u=0\Rightarrow v=\pm2$; $v=0\Rightarrow u=\pm3$. Draw the oval through $(\pm3,0)$, $(0,\pm2)$.
*Example 2 (translated):* $\dfrac{(x-1)^2}{25}+\dfrac{(y-4)^2}{16}=1$. With $x'=x-1$, $y'=y-4$ it is $\dfrac{x'^2}{5^2}+\dfrac{y'^2}{4^2}=1$: an ellipse centered at $(1,4)$ with semi-axes 5 and 4.

### §4. The hyperbola

**Definitions.**
- A **hyperbola** is a curve with equation $xy=c$ in some coordinate system.

**Graph of $xy=1$.**
*Property:* neither $x$ nor $y$ can be 0. Then $y=1/x$. As $x$ grows, $y$ shrinks toward 0 (table: $x=1,2,3,100\Rightarrow y=1,\tfrac12,\tfrac13,\tfrac1{100}$; also $x=\tfrac12,\tfrac13,\tfrac14\Rightarrow y=2,3,4$), and the graph is symmetric under $(x,y)\mapsto(-x,-y)$. It has two branches, one in the first and one in the third quadrant, approaching the axes.

*Translation.* $y-2=\dfrac1{x+3}$: with $x'=x+3$, $y'=y-2$ it is $x'y'=1$; the center is at $(-3,2)$.

*Example (factor into the standard form):* $xy-2x+3y+4=5$.
1. $(x+3)(y-2)=xy-2x+3y-6$, so the left side is $(x+3)(y-2)+6+4$.
2. So $(x+3)(y-2)=-5$.
3. With $x'=x+3$, $y'=y-2$: $x'y'=-5$, a hyperbola in the second and fourth quadrants (of the new axes).

*Example (physics):* a repelling force with magnitude inversely proportional to distance: $y=k/x$; with $k=2$ the graph is a hyperbola branch. (A table of values is enough to sketch it.)

### §5. Rotation of hyperbolas

**Definitions.** $H$: the hyperbola $xy=1$ ($=H_1$). $H_r$: the hyperbola $xy=r^2$ ($r>0$). $G$: rotation, counterclockwise, as usual. Lang's point: $y^2-x^2=c$ is another standard hyperbola equation, obtained by rotating $xy=1$ and dilating. (The book says this section is slightly less important and may be omitted.)

**Theorem 1.**
*Statement:* let $H=\{(x,y):xy=1\}$ and let $G$ be the rotation by $\pi/4$. Then $G(H)=H'$, where $H'$ is the set of points $(u,v)$ with $v^2-u^2=2$.
*Proof (Lang's):*
1. Rotation by $\theta$: $u=(\cos\theta)x-(\sin\theta)y$, $v=(\sin\theta)x+(\cos\theta)y$ (Chapter 11, §6). For $\theta=\pi/4$, $\cos\theta=\sin\theta=1/\sqrt2$, so
$$u=\frac1{\sqrt2}(x-y),\qquad v=\frac1{\sqrt2}(x+y).\qquad(3)$$
2. $v^2-u^2=\tfrac12[(x+y)^2-(x-y)^2]=\tfrac12[4xy]=2xy$.
3. If $xy=1$ then $v^2-u^2=2$. So $G(H)\subseteq H'$.
4. Conversely, let $(u,v)$ satisfy $v^2-u^2=2$. Rotate back by $-\pi/4$: put $x=\frac1{\sqrt2}(u+v)$, $y=\frac1{\sqrt2}(-u+v)$.
5. Then $xy=\tfrac12(u+v)(v-u)=\tfrac12(v^2-u^2)=1$.
6. Putting this $(x,y)$ into (3) gives back exactly $(u,v)$ (Lang: "you will find", i.e. left to the reader; check: $\tfrac1{\sqrt2}(x-y)=u$, $\tfrac1{\sqrt2}(x+y)=v$). So $(u,v)=G(x,y)$ with $(x,y)\in H$. Hence $H'\subseteq G(H)$.

*Intuition:* in the book's Fig. 12-19 the branches of $xy=1$ (first and third quadrants) turn into branches opening up and down, between the lines $v=\pm u$ (asymptotes: our remark).

**Remark / Property (dilation and rotation).**
*Statement:* $H_r$ ($xy=r^2$) is the dilation of $H$ by $r$; a rotation $G$ commutes with dilation: $G(rP)=rG(P)$. So rotating $H_r$ by $\pi/4$ gives $v^2-u^2=2r^2$.
*Proof (Lang's):*
1. Lang's case $xy=6$ ($H_{\sqrt6}$): write $\frac x{\sqrt6}\cdot\frac y{\sqrt6}=1$, put $x'=x/\sqrt6$, $y'=y/\sqrt6$, so $x'y'=1$ and $x=\sqrt6\,x'$, $y=\sqrt6\,y'$. In general $xy=r^2$ gives $x'=x/r$, $y'=y/r$, $x'y'=1$, $(x,y)=r(x',y')$, so $H_r=rH$ ("the same argument").
2. For any rotation $G$ and $r>0$, $G(rP)=rG(P)$: Lang simply notes this (dilate then rotate equals rotate then dilate: "a rotation commutes with a dilation"); proving $G\circ F_r=F_r\circ G$ is his Exercise 8. (Reason, ours: the rotation formulas are linear in $(x,y)$.)
3. Hence $G(H_r)=rG(H)=r H'$, i.e. $v^2-u^2=2r^2$.

*Example 1:* $v^2-u^2=18$: $2r^2=18$, $r=3$; it is the rotation by $\pi/4$ of $xy=9$.
*Example 2:* $v^2-u^2=10$: $2r^2=10$, $r^2=5$; it is the rotation of $xy=5$ (note $10=2\cdot5$, take $r=\sqrt5$).
*Sketching tip:* for $v^2-u^2=10$, set $u=0$: $v=\pm\sqrt{10}$, the points where the hyperbola crosses the vertical axis; the branches open up and down along the lines $v=\pm u$.

### Recall prompts — Chapter 12
1. Prove that the graph of $y=ax+b$ is the line parallel to $y=ax$ through $(0,b)$, and show how to read the slope from two points.
2. Write the equation of a line from (a) a point and the slope, (b) two points. Why do vertical lines need $x=c$?
3. Intersect a line with a circle: describe the method, and how the discriminant decides between 2, 1, 0 points. Do $y=3x+2$ with $x^2+y^2=1$.
4. What does the substitution $x'=x-a$, $y'=y-b$ do to a graph? Complete the square to put $2y-x^2-4x+6=0$ in standard form and name the vertex.
5. Define the mixed dilation $F_{a,b}$ and prove that it maps the unit circle onto $\frac{u^2}{a^2}+\frac{v^2}{b^2}=1$ (both inclusions).
6. Sketch $xy=1$ and explain its symmetry; transform $xy-2x+3y+4=5$ into $x'y'=c$.
7. State and prove Theorem 1: the image of $xy=1$ under rotation by $\pi/4$ is $v^2-u^2=2$ (both inclusions).
8. Why does $xy=r^2$ rotate to $v^2-u^2=2r^2$? Which hyperbola rotates to $v^2-u^2=18$?

# Part Four — Miscellaneous (Chapters 13–17)

*In the book, Part Four has only a title page — no introduction. Its chapters are largely independent tools: functions, mappings, complex numbers, induction, determinants.*

## Chapter 13 — Functions

> A function turns "one number depends on another" into an object we can add, multiply, graph and study. This chapter treats three families: polynomials (with the root bound and division with remainder), the exponential $a^x$ (axiomatized by EXP 1–4), and its inverse, the logarithm (LOG 1–3). Mappings (Chapter 14) generalize functions, and exponentials/logs reappear whenever growth or decay is modelled.

### §1. Definition of a function

**Definitions.**
- **Function** (defined for all numbers): an association $f: x\mapsto f(x)$ giving each number another number. $f(x)$ is the **value** of $f$ at $x$, or the **image** of $x$ under $f$.
- **Function defined on a set $S$**: an association giving each element of $S$ a number. (Needed for $\sqrt{x}$, defined on $x\ge0$, or $1/x$, defined on $x\ne0$.)
- **Constant function** with value $c$: $x\mapsto c$ for all $x$. Examples of rules: square $x\mapsto x^2$, $g(x)=x+1$, $n$-th power, sine. A function need not be given by a formula: $G(x)=0$ if $x$ is rational, $G(x)=1$ if not, so $G(2)=0$, $G(\sqrt2)=1$.
- **Sum** $f+g$, **product** $fg$ (for $f,g$ on the same $S$): $(f+g)(x)=f(x)+g(x)$, $(fg)(x)=f(x)g(x)$. **Zero function** $0$ and **minus** $-f$: $(-f)(x)=-f(x)$. $1$ denotes the constant function $1$.
- Warning: "let $f(x)$ be a function" is sloppy (no quantification of $x$); it means "the function whose value at $x$ is ...".

**Rule (algebra of functions).** *Statement:* for functions on the same $S$: $(f+g)+h=f+(g+h)$; $f+g=g+f$; $f+0=f$; $f+(-f)=0$; $fg=gf$; $(fg)h=f(gh)$; $1f=f$; $0f=0$; $(f+g)h=fh+gh$. So functions obey the same basic rules as numbers.
*Proof (Lang's):* two functions are equal when their values agree at every $x$, so each rule follows from the same rule for numbers at each $x$. For distributivity:
1. $((f+g)h)(x)=(f+g)(x)\,h(x)$ by definition of product.
2. $=(f(x)+g(x))h(x)$ by definition of sum.
3. $=f(x)h(x)+g(x)h(x)$ by distributivity of numbers.
4. $=(fh)(x)+(gh)(x)=(fh+gh)(x)$. Since this holds for all $x$, $(f+g)h=fh+gh$.
*Intuition:* all operations are done pointwise; nothing new happens.
*Example:* $f(x)=x^2$, $g(x)=\sin x$. $(f+g)(\pi)=\pi^2+\sin\pi=\pi^2$.

### §2. Polynomial functions

**Definitions.**
- **Polynomial**: a function $f$ for which there are numbers $a_0,\dots,a_n$ with $f(x)=a_nx^n+\cdots+a_1x+a_0$ for all $x$. It is of **degree $\le n$** in that form; of **degree $n$** if $a_n\ne0$ (well defined by the Corollary below).
- **Root** of $f$: a number $c$ with $f(c)=0$.
- **Coefficients**, **leading coefficient** $a_n$ (if $a_n\ne 0$), **constant term** $a_0$. Include zero coefficients: $4x^5-7x^3+x-20$ has coefficients $4,0,-7,0,1,-20$ (the book prints the third as $7$: a misprint; leading coefficient $4$, constant term $-20$, degree $5$).
- **Zero polynomial**: $f(x)=0$ for all $x$ (all coefficients $0$). Having a root $c$ does not make $f$ the zero polynomial.
- **Rational function**: quotient $f/g$ of polynomials, $g$ not the zero polynomial; defined where $g(x)\ne0$ (numerator, denominator). Added over a common polynomial denominator like rational numbers.
- Quadratic case ($ax^2+bx+c$): one root $-b/2a$ if $b^2-4ac=0$; two roots $\frac{-b\pm\sqrt{b^2-4ac}}{2a}$ if $b^2-4ac>0$ (Chapter 4).

**Theorem 1 (factor theorem).**
*Statement:* if $f$ has degree $\le n$ and $c$ is a root, there is a polynomial $g$ of degree $\le n-1$ with $f(x)=(x-c)g(x)$ for all $x$.
*Proof (Lang's):*
1. Write $f(x)=a_0+a_1x+\cdots+a_nx^n$ and substitute $x=(x-c)+c$.
2. Expand each $((x-c)+c)^k$ as a sum of powers of $(x-c)$ times numbers. So $f(x)=b_0+b_1(x-c)+\cdots+b_n(x-c)^n$.
3. Put $x=c$: $0=f(c)=b_0$, since all other terms vanish.
4. Factor: $f(x)=(x-c)\big(b_1+b_2(x-c)+\cdots+b_n(x-c)^{n-1}\big)=(x-c)g(x)$.
*Remark (Lang's):* the highest power of $(x-c)$ arises only from $((x-c)+c)^n$, with coefficient $a_n$, so $b_n=a_n$ and $g(x)=a_nx^{n-1}+\text{lower terms}$.
*Intuition:* re-expand $f$ around $c$; no constant term remains, so $(x-c)$ divides out.
*Example:* $f(x)=x^2-3x+2$, $f(1)=0$. Then $f(x)=(x-1)(x-2)$, with $g(x)=x-2$.

**Theorem 2 (root bound).**
*Statement:* if $f(x)=a_nx^n+\cdots+a_0$ with $a_n\ne0$, then $f$ has at most $n$ roots.
*Proof (Lang's):*
1. Let $c_1,\dots,c_r$ be distinct roots. Factor $f(x)=(x-c_1)g_1(x)$, $\deg g_1\le n-1$ (Theorem 1).
2. At $c_2$: $0=f(c_2)=(c_2-c_1)g_1(c_2)$. Since $c_2\ne c_1$, $g_1(c_2)=0$.
3. Factor $g_1=(x-c_2)g_2$, $\deg g_2\le n-2$; then $g_2(c_3)=0$ likewise (since $c_3\ne c_1,c_2$). Repeat.
4. Taking $n$ distinct roots we reach a constant $g_n=c$: $f(x)=(x-c_1)\cdots(x-c_n)\,c$. By the Remark, $c=a_n\ne0$.
5. If $x\ne c_i$ for all $i$, every factor is nonzero, so $f(x)\ne0$. Hence no $(n+1)$-th root exists: at most $n$ roots.
*Intuition:* each root peels off one factor of degree 1 and uses up one degree.
*Example:* $x^2-3x+2$ has degree 2 and exactly the roots $1,2$; a third root is impossible.

**Corollary (uniqueness of coefficients).**
*Statement:* if $a_nx^n+\cdots+a_0=b_nx^n+\cdots+b_0$ for all $x$, then $a_i=b_i$ for all $i$. So degree and coefficients are well defined (e.g. $7x^5-5x^4+2x+1\ne x^6-17x^3+x+1$ as functions).
*Proof (Lang's):*
1. Subtract: $0=(a_n-b_n)x^n+\cdots+(a_0-b_0)$; put $d_i=a_i-b_i$.
2. Suppose some $d_i\ne0$; let $m$ be the largest such index. Then $0=d_mx^m+\cdots+d_0$ for all $x$ with $d_m\ne0$.
3. This contradicts Theorem 2 (a non-zero polynomial of degree $m$ has at most $m$ roots, but every number is a root). So all $d_i=0$.
*Example:* $(x+1)^2=x^2+2x+1$ and $x^2+bx+c$ equal for all $x$ forces $b=2,c=1$.

**Factoring.** Two cases Lang records. (a) $f(x)=ax^2+bx+c$ with $b^2-4ac>0$ and roots $c_1,c_2$: $f(x)=a(x-c_1)(x-c_2)$ (Lang: look back at Theorem 1 / the start of the proof of Theorem 2; the constant is the leading coefficient $a$ by the Remark after Theorem 1). E.g. $3x^2-5x+1$ has roots $\frac{5\pm\sqrt{13}}6$ since $25-12=13$, so $3x^2-5x+1=3\big(x-\frac{5+\sqrt{13}}6\big)\big(x-\frac{5-\sqrt{13}}6\big)$. (b) $x^n-1$ has root $1$ (as $1^n-1=0$), so $x^n-1=(x-1)g(x)$ with $g(x)=x^{n-1}+\cdots+x+1$ (the identity from Chapter 1, §6). Lang remarks that hunting for rational roots by factoring is overrated; the quadratic formula is systematic.

**Euclidean algorithm (division with remainder).**
*Statement:* for non-zero polynomials $f,g$ there are polynomials $q,r$ with $\deg r<\deg g$ and $f=qg+r$. ($r$ is the **remainder**.)
*Proof:* omitted in the book. Lang says it consists of carrying out the long-division procedure with general coefficients; he explains the procedure on examples.
*Procedure (Lang's):*
1. Choose the monomial $m_1$ so that $m_1\cdot(\text{leading term of }g)$ equals the leading term of $f$. Form $f_1=f-m_1g$, of smaller degree.
2. Repeat with $f_1$ to get $m_2$, $f_2=f_1-m_2g$, and so on until the degree drops below $\deg g$.
3. Then $f-(m_1+m_2+\cdots)g=r$, so $q=m_1+m_2+\cdots$.
*Intuition:* analog of $327=19\cdot17+4$ (integers: $n=qd+r$, $0\le r<d$), using only multiplication and subtraction.
*Example:* $f=4x^3-3x^2+x+2$, $g=x^2+1$.
1. $4x\cdot x^2=4x^3$; $f-4x\,g=-3x^2-3x+2$.
2. $-3\cdot x^2=-3x^2$; $(-3x^2-3x+2)-(-3)(x^2+1)=-3x+5$.
3. Degree $1<2$: stop. $q=4x-3$, $r=-3x+5$. Check: $(4x-3)(x^2+1)=4x^3-3x^2+4x-3$; adding $-3x+5$ gives $f$. (The book's displayed long division gives $r=-3x+5$, but its equation (1) prints $\dots+(3x+5)$: a real misprint in the book; the correct remainder is $-3x+5$, as the check above shows.)
Second example: $f=2x^4-3x^2+1$, $g=x^2-x+3$ gives $q=2x^2+2x-7$, $r=-13x+22$.

**Remark (factor theorem again).** *Statement:* if $f(c)=0$ then $f=(x-c)q$.
*Proof (Lang's):* divide by $x-c$: $f=q(x-c)+r$ with $\deg r<1$, so $r$ is a constant $a$. Evaluate at $x=c$: $0=0+a$, so $a=0$.

**Rational functions (example).** Over the common denominator $(x-1)(x-5)$:
$\frac{3x^2-2x+6}{x-1}+\frac{4x+3}{x-5}=\frac{(3x^2-2x+6)(x-5)+(4x+3)(x-1)}{(x-1)(x-5)}$, defined for $x\ne1,5$. Expanding, Lang gets $\frac{3x^3-13x^2+15x-33}{x^2-6x+5}$ (numerator: $3x^3-17x^2+16x-30$ plus $4x^2-x-3$).

### §3. Graphs of functions

**Definitions.**
- **Graph** of $f$ (on $S$): the set of points $(x,f(x))$, $x\in S$. For $f(x)=x^2$ it is the parabola $y=x^2$.
- **Greatest integer function** $[x]$ = largest integer $\le x$: $[2]=2$, $[\tfrac32]=1$; its graph is a staircase.

**Method (sign-chart sketch).** *Statement:* to sketch $y=(x-1)(x-2)$, read off the sign of each factor.
*Argument (Lang's):*
1. $y=0$ exactly at $x=1,2$: the graph crosses the $x$-axis there only.
2. $x<1$: both factors negative, so $y>0$. $x>2$: both positive, so $y>0$.
3. $1<x<2$: $x-1>0$, $x-2<0$, so $y<0$.
4. $x=0$: $y=(-1)(-2)=2$.
This is the parabola $y=x^2-3x+2$; completing the square (Chapter 12) gives the same curve but this method gives a quicker rough picture.
*Other examples:* force $y=3/x^2$ (decreases as $x$ increases, table of values); the sine curve.

### §4. Exponential function

**Definitions.**
- For $a>0$ the powers $a^{m/n}$ are known (Chapter 3). We *assume* each number $x$ gets a number $a^x$ agreeing with $a^{m/n}$ when $x=m/n$ and satisfying EXP 1–4. The function $x\mapsto a^x$ is the **exponential function to the base $a$**. Lang says an analytic development is hard, so these properties are stated, not proved.
- **Exponential growth**: $f(t)=Ca^{t}$; $C=f(0)$ is the initial value (e.g. a population). **Decay**: $f(t)=Ca^{Kt}$ with $K$ a negative constant (substances disintegrate at a rate proportional to the amount present).

**EXP 1–4 (assumed).**
- **EXP 1.** $a^{x+y}=a^xa^y$.
- **EXP 2.** $(a^x)^y=a^{xy}$.
- **EXP 3.** For $a,b>0$: $(ab)^x=a^xb^x$.
- **EXP 4.** If $a>1$ and $x<y$, then $a^x<a^y$ (increasing).
*Intuition:* these are the rules for fractional powers, extended; picture a curve that is very flat to the left of $0$ and climbs steeply to the right.

**Consequences (Lang's).**
1. $a^0=1$ (proof of Chapter 3, §3 still works).
2. $a^{-x}=1/a^x$: by EXP 1, $a^{-x}a^x=a^{-x+x}=a^0=1$.
3. Values are positive. If $a>1$ and $x>0$: $a^x>a^0=1$ by EXP 4. If $x=-z<0$: $a^x=1/a^z>0$, and $a^x<1$.
*Question posed in the book:* how must EXP 4 change for $0<a<1$? (Lang leaves it open; our answer, an addition: reverse it, $x<y\Rightarrow a^x>a^y$.)
*Example:* radium, $f(t)=3a^{-2t}$ with $a=2$, $t$ in years: $f(0)=3$ g; $f(4)=3\cdot2^{-8}=3/256$ g. Population example: $P(t)=100\cdot2^t$ gives $100,200,400,800,\dots$

### §5. Logarithms

**Definitions.**
- For $a>1$: if $y=a^x$, then $x$ is the **log of $y$ to the base $a$**, $x=\log_a y$. E.g. $3=\log_28$ since $8=2^3$.
- **Assumed (axiom):** for every $y>0$ there is a number $x$ with $a^x=y$. So $\log_a$ is a function on the positive numbers, and $a^{\log_ax}=x$, $\log_a(a^x)=x$ (inverse functions, cf. Ch. 14 §2).

**LOG 1.** *Statement:* $\log_a(xy)=\log_ax+\log_ay$ (Lang says "any numbers"; $x,y>0$ is implicit since $\log_a$ is defined on positive numbers).
*Proof (Lang's):*
1. Let $u=\log_ax$, $v=\log_ay$, so $x=a^u$, $y=a^v$.
2. $xy=a^ua^v=a^{u+v}$ by EXP 1.
3. By definition of log, $\log_a(xy)=u+v$.
*Intuition:* log turns multiplication into addition.
*Example:* $\log_2(8\cdot4)=\log_232=5=3+2$.

**LOG 2.** *Statement:* $\log_a1=0$.
*Proof (Lang's):* $a^0=1$, so by definition $0=\log_a1$.

**LOG 3.** *Statement:* if $0<x<y$, then $\log_ax<\log_ay$.
*Proof (Lang's):*
1. Let $u=\log_ax$, $v=\log_ay$; $a^u=x$, $a^v=y$.
2. If $u=v$ then $x=y$: impossible.
3. If $v<u$ then by EXP 4 $y<x$: impossible.
4. Hence $u<v$.
*Question posed in the book:* which of the properties still hold for $0<a<1$ (left to the reader; our remark: LOG 3 reverses).
*Boxed in Exercise 3:* $\log a^x=x\log a$ (hint: $e^{(\log a)x}$ and EXP 2) is a result Lang asks the reader to prove.

**Use: solving exponential equations.** Take the log to the base $a$ of both sides.
*Example 1:* $f(t)=10\cdot2^{kt}$, $f(\tfrac12)=3$. Then $3=10\cdot2^{k/2}$; take $\log_2$: $\log_23=\log_210+\frac k2$, so $k=2(\log_23-\log_210)$.
*Example 2:* $r(t)=C\,3^{-5t}$, find $t$ with $r(t)=\tfrac13C$. Cancel $C$: $\tfrac13=3^{-5t}$; take $\log_3$: $-1=-5t$, so $t=\tfrac15$. The unknown $C$ does not appear in the answer.

### Recall prompts — Chapter 13
1. Define the sum and product of functions and prove $(f+g)h=fh+gh$ from the corresponding rule for numbers.
2. State and prove the factor theorem (Theorem 1), including why the quotient has leading term $a_nx^{n-1}$.
3. State and prove that a polynomial of degree $n$ has at most $n$ roots (Theorem 2). Where is $c=a_n\ne0$ used?
4. Prove that the coefficients of a polynomial are unique, and say why this makes "degree" well defined.
5. Carry out Euclidean division of $4x^3-3x^2+x+2$ by $x^2+1$ and explain why the procedure produces $q,r$ with $\deg r<\deg g$. Deduce the factor theorem from it.
6. State EXP 1–4. Derive $a^{-x}=1/a^x$ and show $a^x>0$ for all $x$. How does EXP 4 change for $0<a<1$?
7. State the assumption that defines $\log_a$, then prove LOG 1, LOG 2, LOG 3 from the exponential properties.
8. Sketch $y=(x-1)(x-2)$ using only signs of the factors.
9. Solve $\tfrac13C=C\,3^{-5t}$ for $t$ and explain why $C$ drops out.

## Chapter 14 — Mappings

> A mapping $f:S\to S'$ generalizes both functions (values numbers) and the plane maps (isometries) met earlier. We collect the formalism: identity, composition (associative), inverse (unique), iterates $f^k$ and the exponent law $f^mf^n=f^{m+n}$. The last section applies it to permutations of $\{1,\dots,n\}$: every permutation is a product of transpositions, and its parity (even or odd number of transpositions) is well defined, proved by counting orbits.

### §1. Definition

**Definitions.**
- **Mapping** $f:S\to S'$: an association giving each $x\in S$ an element $f(x)\in S'$ (**value** or **image** of $x$). Functions and plane maps ($S=S'=\mathbb R^2$) are special cases.
- **Image** of a subset $T\subset S$: $f(T)=\{f(t):t\in T\}$.
- **Convention:** a mapping from a set $S$ into the real numbers is called a **function**. E.g. $X\mapsto d(X,O)$ is the distance function; $(x,y)\mapsto x^2+\cos(xy)$ is a function on $\mathbb R^2$.
- Examples of mappings: $t\mapsto P+tA$ (line parametrization, $\mathbb R\to\mathbb R^2$); $\theta\mapsto(\cos\theta,\sin\theta)$ (image: unit circle); $x\mapsto(x,x^2)$ (image: parabola); $F_{a,b}(x,y)=(ax,by)$ (image of the unit circle: an ellipse); $t\mapsto(t^2,t^3)$ (curve, $x(t)\ge0$, $y(t)$ has the sign of $t$).

*Example (thrown stone).* Building height 50 ft, horizontal throw: position $t\mapsto(ct,\,50-\tfrac12gt^2)$. It lands when $50-\tfrac12gt^2=0$, i.e. $t=\sqrt{100/g}$. With $g=32$: $t=\sqrt{100/32}=\sqrt{25/8}\approx1.8$ s.

### §2. Formalism of mappings

**Definitions.**
- **Identity mapping** $I_S(x)=x$.
- **Composite** of $f:S\to T$ and $g:U\to V$ with $T\subset U$: $(g\circ f)(x)=g(f(x))$, a mapping $S\to V$. Example: $f(x)=x^2$, $g(u)=\sin u$: $g(f(x))=\sin(x^2)$. With $f(x)=3x-2$, $g(u)=1/\cos u$: $g(f(x))=1/\cos(3x-2)$, defined only when $3x-2\ne\frac\pi2+n\pi$.
- **Inverse mapping** of $f:S\to T$: a mapping $g:T\to S$ with $g\circ f=I_S$ and $f\circ g=I_T$; written $f^{-1}$. Examples: square and square root on $\mathbb R^+$; $a^x$ and $\log_a$: $a^{\log_ax}=x$, $\log_a(a^x)=x$.
- **Iterate**: for $f:S\to S$, $f^k=f\circ\cdots\circ f$ ($k$ times), $f^{k+1}=f\circ f^k$; $f^0=I$; and, if $f^{-1}$ exists, $f^{-k}=(f^{-1})^k$.

**Property (identity).** *Statement:* $I\circ f=f\circ I=f$.
*Proof (Lang's):* $(I\circ f)(x)=I(f(x))=f(x)$ and $(f\circ I)(x)=f(I(x))=f(x)$.
*Intuition:* $I$ plays the role of $1$ under composition.

**Property (associativity).** *Statement:* for $f:S\to T$, $g:T\to U$, $h:U\to V$: $(h\circ g)\circ f=h\circ(g\circ f)$.
*Proof (Lang's):* for $x\in S$, $((h\circ g)\circ f)(x)=(h\circ g)(f(x))=h(g(f(x)))$ and $(h\circ(g\circ f))(x)=h((g\circ f)(x))=h(g(f(x)))$.
*Example:* $f=x+1$, $g=x^2$, $h=\sin$: both groupings give $\sin((x+1)^2)$.

**Property (uniqueness of inverse).** *Statement:* if $g,h:T\to S$ are both inverse to $f:S\to T$, then $g=h$.
*Proof:* left as an exercise in the book ("the elementary proof for the inverse of a number applies"). That argument: $g=g\circ I_T=g\circ(f\circ h)=(g\circ f)\circ h=I_S\circ h=h$.

**Iteration examples.** $f(x)=x+1$: $f^k(x)=x+k$. $F(X)=X+A$ (translation, $A=(3,-4)$): $F^k(X)=X+kA$, $F^{-k}(X)=X-kA$. $f(x)=x^3$: $f^2(x)=x^9$, $f^3(x)=x^{27}$, $f^k(x)=x^{3^k}$, $f^{-k}(x)=x^{1/3^k}$. $f(x)=x+3$: $f^{k}(x)=x+3k$, $f^{-k}(x)=x-3k$.

**Rule of exponents.** *Statement:* for $f:S\to S$ and positive integers $m,n$: $f^{m+n}=f^m\circ f^n$. If $f^{-1}$ exists, $f^k\circ f^{-k}=I$ and the law $f^{m+n}=f^m\circ f^n$ holds for all integers $m,n$ (positive, negative, zero; proof omitted).
*Proof (Lang's):*
1. Positive $m,n$: iterating $m+n$ times is iterating $n$ times then $m$ times.
2. With $f^0=I$ the law holds when $m$ or $n$ is $0$ (immediate).
3. $f^k\circ f^{-k}=I$: apply $f^{-1}$ $k$ times to $x$, then $f$ $k$ times; the innermost $f\circ f^{-1}$ is $I$, and so on outward, $k$ times.
4. Induction version: true for $k=1$ by definition; if true for $k$, then $f^{k+1}\circ f^{-(k+1)}=f\circ f^k\circ(f^{-1})^k\circ f^{-1}=f\circ I\circ f^{-1}=f\circ f^{-1}=I$.
*Intuition:* composition behaves like multiplication, with $f^k$ as powers.
*Examples:* $f^5\circ f^{-3}=f^2$. If $f^m=f^n$ and $f^{-1}$ exists, compose with $f^{-n}$: $f^{m-n}=I$. If $f^4=f^{-5}$ then $f^9=I$.

**Example (cancelling an involution product).** *Statement:* if $f_i^2=I$ for $i=1,\dots,m$ and $f_1\circ f_2\circ\cdots\circ f_m\circ f=I$, then $f=f_m\circ f_{m-1}\circ\cdots\circ f_1$.
*Proof (Lang's):* $f_1^{-1}=f_1$. Compose on the left with $f_1$: $f_2\circ\cdots\circ f_m\circ f=f_1$. Compose with $f_2$: $f_3\circ\cdots\circ f_m\circ f=f_2\circ f_1$. Continue through $f_m$: $f=f_m\circ\cdots\circ f_2\circ f_1$. (Used in §3 for Theorem 1.)

### §3. Permutations

**Definitions.**
- $J_n=\{1,\dots,n\}$. A **permutation** of $J_n$ is a mapping $\sigma:J_n\to J_n$ with $i\ne j\Rightarrow\sigma(i)\ne\sigma(j)$. So $\sigma(1),\dots,\sigma(n)$ are $1,\dots,n$ in another order; written as a two-row array $\begin{bmatrix}1&2&\cdots&n\\\sigma(1)&\sigma(2)&\cdots&\sigma(n)\end{bmatrix}$. Example: $\sigma=\begin{bmatrix}1&2&3&4\\3&1&4&2\end{bmatrix}$.
- **Product** $\sigma\sigma'=\sigma\circ\sigma'$ (apply $\sigma'$ first). Not commutative: with $\sigma=\begin{bmatrix}1&2&3&4\\2&3&4&1\end{bmatrix}$, $\sigma'=\begin{bmatrix}1&2&3&4\\3&4&2&1\end{bmatrix}$ we get $\sigma'\sigma=\begin{bmatrix}1&2&3&4\\4&2&1&3\end{bmatrix}$ (e.g. $1\mapsto2\mapsto4$) but $\sigma\sigma'=\begin{bmatrix}1&2&3&4\\4&1&3&2\end{bmatrix}$.
- **Inverse permutation** $\sigma^{-1}$: $\sigma\sigma^{-1}=\sigma^{-1}\sigma=I$; $\sigma(i)=j\iff\sigma^{-1}(j)=i$. For $\sigma=\begin{bmatrix}1&2&3\\3&1&2\end{bmatrix}$: $\sigma^{-1}=\begin{bmatrix}1&2&3\\2&3&1\end{bmatrix}$.
- **Transposition**: swaps two distinct numbers $i\ne j$, fixes the rest. $\tau^2=I$, so $\tau^{-1}=\tau$.
- **Even / odd permutation**: a product of an even / odd number of transpositions. **Sign** $=(-1)^m$ for $m$ transpositions ($1$ if even, $-1$ if odd). $I$ is the product of zero transpositions.
- **Orbit** of $i$ under $\sigma$: $\{i,\sigma(i),\dots,\sigma^{k-1}(i)\}$, $k$ the least positive integer with $\sigma^k(i)=i$ (the **period** of $i$). Its **cycle**: $[i,\sigma(i),\dots,\sigma^{k-1}(i)]$ (**length** $k$); can start anywhere on the circle, e.g. $[1,3,4]=[3,4,1]$. **Orbit decomposition**: $\sigma=\gamma_1\cdots\gamma_m$, product of the cycles of its distinct orbits (e.g. $\sigma=[1,3,4][2,5]$, $I=[1][2]\cdots[n]$, a transposition $=[a,b]$).

**Rule (inverse of a product).** *Statement:* $(\sigma_1\cdots\sigma_r)^{-1}=\sigma_r^{-1}\cdots\sigma_1^{-1}$.
*Proof (Lang's):* multiply: $\sigma_1\cdots\sigma_r\sigma_r^{-1}\cdots\sigma_1^{-1}$; the middle pair gives $I$, then the next pair, and so on, leaving $I$. Same on the other side. (Valid for any invertible mappings.)
*Example:* $(\sigma_1\sigma_2\sigma_3)^{-1}=\sigma_3^{-1}\sigma_2^{-1}\sigma_1^{-1}$.

**Theorem 1.** *Statement:* every permutation of $J_n$ is a product of transpositions.
*Proof (Lang's):*
1. Let $\sigma(n)=k$. If $k=n$ let $\tau_n=I$; otherwise $\tau_n$ is the transposition of $k$ and $n$. Then $\tau_n\sigma$ fixes $n$, so it is a permutation of $J_{n-1}$.
2. Repeat: $\tau_{n-1}$ is $I$ or a transposition of $J_{n-1}$ such that $\tau_{n-1}\tau_n\sigma$ fixes $n$ and $n-1$. Continue down to $\tau_1$.
3. Then $\tau_1\tau_2\cdots\tau_n\sigma$ fixes $1,\dots,n$, so $\tau_1\cdots\tau_n\sigma=I$.
4. Since $\tau_i^2=I$, multiplying on the left by $\tau_1$, then $\tau_2$, etc. gives $\sigma=\tau_n\cdots\tau_1$ (the product of involutions example above).
5. Drop those $\tau_i$ equal to $I$. If all are $I$, $\sigma=I$, the product of zero transpositions (convention).
*Intuition:* fix the last position, then the one before, like sorting by swaps.
*Example:* $\sigma=\begin{bmatrix}1&2&3\\3&1&2\end{bmatrix}$. Let $\tau$ swap $3,1$: $\tau\sigma=\begin{bmatrix}1&2&3\\1&3&2\end{bmatrix}=\tau'$, a transposition. So $\sigma=\tau\tau'$.
Second example: $\sigma=\begin{bmatrix}1&2&3&4\\2&3&4&1\end{bmatrix}$. $\tau_1=(1\,2)$: $\tau_1\sigma=\begin{bmatrix}1&2&3&4\\1&3&4&2\end{bmatrix}$. $\tau_2=(2\,3)$: $\tau_2\tau_1\sigma=\begin{bmatrix}1&2&3&4\\1&2&4&3\end{bmatrix}=\tau_3$. So $\sigma=\tau_1\tau_2\tau_3$. Not unique: also $\sigma=\tau_4\tau_1\tau_3$ with $\tau_4=(1\,3)$, $\tau_3=(3\,4)$.

**Theorem 2 (parity is well defined).** *Statement:* for $\sigma$ a permutation of $J_n$, the number of transpositions in any expression of $\sigma$ as a product of transpositions is always even or always odd.
*Proof (Lang's):* postponed; it needs Theorem 3 and the orbit Lemma below (see "Proof of Theorem 2"). Theorem 4 then follows.
*Examples:* $\begin{bmatrix}1&2&3\\3&1&2\end{bmatrix}$ (2 transpositions) has sign $+1$; $\begin{bmatrix}1&2&3&4\\2&3&4&1\end{bmatrix}$ (3 transpositions) has sign $-1$.

**Theorem 3 (orbits are disjoint or equal).** *Statement:* for $a,b\in J_n$ and a permutation $\sigma$, the orbits of $a$ and $b$ coincide or are disjoint.
*Proof (Lang's):*
1. (Preceding discussion in the book, before Theorem 3: orbits are well-formed.) $i,\sigma(i),\sigma^2(i),\dots$ cannot all be distinct in a finite set, so $\sigma^r(i)=\sigma^s(i)$ with $r<s$; applying $\sigma^{-r}$ gives $\sigma^{s-r}(i)=i$. Take the least such $k$. Then $i,\dots,\sigma^{k-1}(i)$ are distinct: if $\sigma^m(i)=\sigma^n(i)$ with $1\le m<n\le k$, then $\sigma^{n-m}(i)=i$ with $n-m<k$, contradicting minimality.
2. Suppose the orbits of $a,b$ share an element: $\sigma^r(a)=\sigma^s(b)$, $r,s>0$.
3. Apply $\sigma^{-r}$: $a=\sigma^{s-r}(b)=\sigma^m(b)$.
4. Then $\sigma(a)=\sigma^{m+1}(b)$, $\sigma^2(a)=\sigma^{m+2}(b),\dots$, so the orbit of $a$ lies in the orbit of $b$.
5. By symmetry the orbit of $b$ lies in that of $a$. So the orbits are equal.
*Intuition:* following $\sigma$ partitions $J_n$ into disjoint circles.
*Example:* $\sigma=\begin{bmatrix}1&2&3&4&5&6\\5&6&2&1&4&3\end{bmatrix}=[1,5,4][2,6,3]$.

**Lemma (effect of a transposition on orbits)** (unlabelled in the book; it is the discussion after the orbit decomposition, and the name "Lemma" is ours). *Statement:* let $\tau=[a,b]$ be a transposition. Then $\tau\sigma$ has one more orbit than $\sigma$ if $a,b$ lie in the same orbit of $\sigma$, and one fewer if they lie in different orbits.
*Proof (Lang's):*
1. *Case 1:* $a=i_r$, $b=i_s$ ($r<s$) in the same cycle $\gamma_1=[i_1,\dots,i_k]$. Follow $\tau\sigma$ on it: $i_1\mapsto\cdots\mapsto i_{r-1}\mapsto i_s\mapsto i_{s+1}\mapsto\cdots\mapsto i_k\mapsto i_1$ (cycle $\gamma_1'=[i_1,\dots,i_{r-1},i_s,\dots,i_k]$), and $i_r\mapsto i_{r+1}\mapsto\cdots\mapsto i_{s-1}\mapsto i_r$ (cycle $\gamma_1''=[i_r,\dots,i_{s-1}]$), disjoint from $\gamma_1'$. $\tau$ does not touch the other cycles. So the orbit splits into two: one more orbit.
2. *Case 2:* $a,b$ in distinct cycles $[i_1,\dots,i_r]$, $[j_1,\dots,j_s]$. The same bookkeeping shows $\tau\sigma$ joins them into one orbit: one fewer orbit. (Lang says "you work out" this case.)

**Proof of Theorem 2 (Lang's).**
1. Suppose $\sigma=\tau_1\cdots\tau_p$ with $p$ odd.
2. Start from $I$, which has $n$ orbits. Multiplying successively on the left by $\tau_p,\tau_{p-1},\dots,\tau_1$ changes the orbit count by $\pm1$ each time (Lemma). So orbits of $\sigma=n+(\text{odd integer})$.
3. If also $\sigma=\tau'_1\cdots\tau'_q$ with $q$ even, the same argument gives orbits of $\sigma=n+(\text{even integer})$.
4. An integer cannot be both odd and even, so both expressions cannot exist.

**Theorem 4.** *Statement:* if $\sigma$ has $k$ orbits, $\sigma$ is even when $n-k$ is even and odd when $n-k$ is odd.
*Proof:* Lang gives no separate proof ("the general rule following from this discussion"). The argument above: if $\sigma$ is a product of $p$ transpositions, then $k=n\pm1\pm\cdots\pm1$ ($p$ terms), so $n-k\equiv p \pmod 2$; hence $n-k$ even means $\sigma$ even, odd means odd (well defined by Theorem 2).
*Example:* $n=6$, $\sigma=[1,5,4][2,6,3]$ has $k=2$ orbits, $6-2=4$ even: even permutation. $n=5$, $\sigma=\begin{bmatrix}1&2&3&4&5\\3&5&4&1&2\end{bmatrix}=[1,3,4][2,5]$, $5-2=3$ odd: odd permutation.

### Recall prompts — Chapter 14
1. Define the composite and the inverse of mappings. Prove associativity and that $I\circ f=f\circ I=f$.
2. Prove that an inverse mapping, if it exists, is unique.
3. State the exponent law for iterates (including negative exponents). Prove $f^k\circ f^{-k}=I$ by induction, and deduce that $f^4=f^{-5}$ implies $f^9=I$.
4. If $f_i^2=I$ and $f_1\circ\cdots\circ f_m\circ f=I$, derive $f=f_m\circ\cdots\circ f_1$.
5. Show that $\sigma\sigma'\ne\sigma'\sigma$ in general with a concrete pair on $J_4$, and prove $(\sigma_1\cdots\sigma_r)^{-1}=\sigma_r^{-1}\cdots\sigma_1^{-1}$.
6. State and prove Theorem 1 (every permutation is a product of transpositions), stating where $\tau^2=I$ is used.
7. Prove that orbits of a permutation are disjoint or equal (Theorem 3). Why is the period of an element finite and why are $i,\dots,\sigma^{k-1}(i)$ distinct?
8. Prove how multiplying by a transposition changes the number of orbits, in both cases.
9. Deduce Theorem 2 (parity well defined) and Theorem 4 ($n-k$ rule). Compute the sign of $[1,5,4][2,6,3]$ in $J_6$.

## Chapter 15 — Complex Numbers

> We add a square root of $-1$ to the real numbers and get the complex numbers, which fill the plane. We learn their arithmetic (conjugate, inverse, absolute value) and then the polar form $re^{i\theta}$, in which multiplication becomes "multiply lengths, add angles". This is the tool for roots of unity, rotations, and (Ch. 16 exercises) geometric series with complex ratio.

### §1. The complex plane

**Definitions.**
- **Complex numbers**: a set with addition and multiplication such that: addition is commutative and associative; multiplication is commutative, associative, distributive over addition; every real number is complex (with the same sums and products); $1z=z$, $0z=0$; each $z$ has additive inverse $(-1)z$; there is $i$ with $i^2=-1$; every complex number is $a+bi$ with $a,b$ real. Lang assumes all this (he notes one could define $z$ as a pair $(a,b)$ and check the properties by brute force, but omits it).
- The **complex plane**: $z=a+bi$ is the point $(a,b)$; real $a$ is the point $(a,0)$; $i=(0,1)$. Addition is componentwise; $cz=(cx,cy)$ for real $c$.
- **Complex conjugate**: $\bar z=a-bi$ for $z=a+bi$.
- **Multiplicative inverse** $z^{-1}=1/z$ of $z\ne0$: the number $w$ with $zw=wz=1$. We write $w/z$ for $z^{-1}w$.
- **Real part** $\mathrm{Re}(z)=x$, **imaginary part** $\mathrm{Im}(z)=y$ for $z=x+iy$.
- **Absolute value** $|z|=\sqrt{x^2+y^2}$: distance from the origin.

**Fact (the square roots of $-1$).** $i$ and $-i$ are the only complex numbers whose square is $-1$.
*Proof (Lang's):* the same argument as for real square roots: if $z^2=-1=i^2$ then $(z-i)(z+i)=z^2-i^2=0$, so $z=\pm i$. *Intuition:* the product of two numbers is $0$ only if one is $0$.

**Rule (product).** If $z=x+iy$, $w=u+iv$ then $zw=(xu-yv)+(xv+yu)i$.
*Proof (Lang's):* 1. Distribute: $(x+iy)(u+iv)=x(u+iv)+iy(u+iv)$. 2. Expand: $xu+ixv+iyu+i^2yv$. 3. Use $i^2=-1$ and collect: $xu-yv+(xv+yu)i$. (Hence for points, $(x,y)(u,v)=(xu-yv,\,xv+yu)$ is forced.)
*Example:* $z=2+3i$, $w=1-i$. $zw=2(1-i)+3i(1-i)=2-2i+3i-3i^2=2+3+i=5+i$.

**Fact (conjugate times itself).** $z\bar z=a^2+b^2=|z|^2$.
*Proof:* $(a+bi)(a-bi)=a^2-abi+abi-b^2i^2=a^2+b^2$. *Intuition:* $z\bar z$ is the squared distance of $z$ from $0$.

**Fact (inverse).** For $z=a+bi\neq 0$, $z^{-1}=\bar z/(a^2+b^2)=\bar z/|z|^2$, and it is the unique inverse.
*Proof (Lang's):* 1. Put $w=\bar z/(a^2+b^2)$. 2. Then $zw=wz=z\bar z/(a^2+b^2)=1$. 3. Uniqueness: the earlier proof for real numbers applies (if $w,w'$ both invert $z$, then $w=w(zw')=(wz)w'=w'$).
*Example:* $(1+i)^{-1}$: $\overline{1+i}=1-i$, $(1+i)(1-i)=2$, so $(1+i)^{-1}=\tfrac12(1-i)$.

**Theorem 1.** For complex $z,w$: $\overline{zw}=\bar z\,\bar w$, $\overline{z+w}=\bar z+\bar w$, $\overline{\bar z}=z$.
*Proof:* omitted in the book ("follows immediately from the definitions"; left as exercise).
*Intuition:* conjugation is the reflection $b\mapsto -b$ across the real axis and respects both operations.
*Example:* $z=1+i$, $w=2-i$: $zw=3+i$, so $\overline{zw}=3-i$; $\bar z\bar w=(1-i)(2+i)=2+i-2i+1=3-i$.

**Consequences (stated in the text).** $z+\bar z=2\,\mathrm{Re}(z)$, $z-\bar z=2i\,\mathrm{Im}(z)$ (the book prints $z-\bar z=2y=2\,\mathrm{Im}(z)$, a real misprint: $z-\bar z=(x+iy)-(x-iy)=2iy$, so the correct identity is $z-\bar z=2i\,\mathrm{Im}(z)$), and $z^{-1}=\bar z/|z|^2$ because $z\bar z=|z|^2$.

**Theorem 2.** For complex $z,w$: $|zw|=|z||w|$ and $|z+w|\le|z|+|w|$.
*Proof (Lang's):* 1. $|zw|^2=zw\,\overline{zw}$ (since $z\bar z=|z|^2$ applied to $zw$). 2. By Theorem 1 this is $zw\,\bar z\,\bar w=z\bar z\,w\bar w$. 3. That equals $|z|^2|w|^2$. 4. Take square roots (both sides $\ge0$). 5. The inequality is the triangle inequality: draw $z$, $w$, $z+w$; they form a parallelogram, and one side of a triangle is at most the sum of the other two. (An algebraic proof exists; Lang omits it.)
*Example:* $|(1+i)(1-i)|=|2|=2=\sqrt2\cdot\sqrt2$.

### §2. Polar form

**Definitions.**
- **Polar form** of $z\ne0$: $z=r(\cos\theta+i\sin\theta)=re^{i\theta}$ with $r=|z|>0$; $(r,\theta)$ are its **polar coordinates**.
- The symbol $e^{i\theta}$ is **defined** as $\cos\theta+i\sin\theta$.

**Fact (existence of polar form).** Every complex number $z\neq 0$ is $r(\cos\theta+i\sin\theta)$ with $r=|z|$ and some real $\theta$. (Equivalently, as Lang puts it: every complex number is a product of a real number $\ge0$ and a number of absolute value 1.)
*Proof (Lang's):* 1. Let $r=|z|$. 2. Then $z/r$ has absolute value 1 (as $|z/r|=|z|/r$), so it is a point of the unit circle. 3. Points of the unit circle are $(\cos\theta,\sin\theta)$ for some $\theta$. 4. Hence $z/r=\cos\theta+i\sin\theta$ and $z=r(\cos\theta+i\sin\theta)$.
*Example:* $z=1+i\sqrt3$. $|z|=2$. $z/2=(\tfrac12,\tfrac{\sqrt3}2)$, so $\cos\theta=\tfrac12$, $\sin\theta=\tfrac{\sqrt3}{2}$, $\theta=\pi/3$. Polar coordinates $(2,\pi/3)$; $z=2e^{i\pi/3}$.

**Theorem 3.** For real $\theta,\varphi$: $e^{i\theta}e^{i\varphi}=e^{i(\theta+\varphi)}$.
*Proof (Lang's):* 1. By definition $e^{i(\theta+\varphi)}=\cos(\theta+\varphi)+i\sin(\theta+\varphi)$. 2. By the addition formulas for sine and cosine this is $\cos\theta\cos\varphi-\sin\theta\sin\varphi+i(\sin\theta\cos\varphi+\sin\varphi\cos\theta)$. 3. Multiplying out $(\cos\theta+i\sin\theta)(\cos\varphi+i\sin\varphi)$ (using $i^2=-1$) gives exactly the same number.
*Intuition:* the notation $e^{i\theta}$ is justified because it obeys the exponent rule; the addition formulas are the product rule in disguise.
*Example:* $e^{i\pi}=-1$ and $e^{2\pi i}=1$ (from $\cos\pi=-1,\sin\pi=0$ and $\cos 2\pi=1,\sin 2\pi=0$).

**Consequence (product in polar form).** If $z=re^{i\theta}$, $w=se^{i\varphi}$ then $zw=rs\,e^{i(\theta+\varphi)}$: multiply absolute values, add angles.
*Example 1:* a number whose square is $4e^{i\pi/2}$: take $z=2e^{i\pi/4}$; $z^2=4e^{i\pi/4+i\pi/4}=4e^{i\pi/2}$.
*Example 2:* for positive integer $n$, $w=e^{i\pi/2n}$ satisfies $w^n=e^{i\pi/2}$ (apply the rule $n$ times).

### Recall prompts — Chapter 15
1. Derive $(x+iy)(u+iv)=(xu-yv)+(xv+yu)i$ from the listed properties, and explain why this is forced for points of the plane.
2. Prove that $i$ and $-i$ are the only square roots of $-1$.
3. Prove $z\bar z=|z|^2$ and use it to derive the formula and uniqueness for $z^{-1}$; compute $(2+3i)^{-1}$.
4. State Theorem 1 (conjugation) and verify it on an example.
5. Prove $|zw|=|z||w|$ using conjugates; what is the picture behind $|z+w|\le|z|+|w|$?
6. Show that every nonzero complex number has a polar form $re^{i\theta}$ (why is $z/|z|$ on the unit circle?).
7. State and prove Theorem 3 from the addition formulas.
8. Deduce the rule "multiply absolute values, add angles", and use it to find a complex $w$ with $w^n=e^{i\pi/2}$.
9. Why are $e^{i\pi}=-1$ and $e^{2\pi i}=1$?

---

## Chapter 16 — Induction and Summations

> Induction proves statements for all positive integers from a starting case and a step. The sigma notation compactifies sums. We use sums of powers to compute a volume (the cone) by Archimedes' method of approximating with cylinders, then dilations to get the general cone, and finally sum the geometric series, our first "infinite sum" defined as a limit.

### §1. Induction

**Definitions.**
- **Induction**: an axiom letting us prove an assertion $A(n)$ for all positive integers $n$.
- **Sigma notation**: $\sum_{k=1}^n f(k)=f(1)+\cdots+f(n)$. Distributivity: $c\sum_{k=1}^n f(k)=\sum_{k=1}^n cf(k)$.
- **$n!$** is the product of the first $n$ integers ($1!=1$, $2!=2$, $3!=6$, $4!=24$, $5!=120$); $0!=1$ by convention.
- **Binomial coefficient** $C_n^k=\binom nk$: number of ways of selecting $k$ objects out of $n$. For $k<0$ or $k>n$ we define it to be $0$.

**Axiom (Induction), IND 1 and IND 2.** To prove $A(n)$ for all positive integers $n$ it suffices to prove:
- **IND 1.** $A(1)$ is true.
- **IND 2.** Assuming $A$ is true for all positive integers $\le n$ (in practice often just $A(n)$), prove $A(n+1)$.

*Assumed (axiom).* *Intuition:* IND 1 is the starting point; IND 2 gives $A(2)$ from $A(1)$, then $A(3)$ from $A(2)$, and so on.

**Proposition (sum of the first $n$ integers).** For all $n\ge1$: $1+2+\cdots+n=\dfrac{n(n+1)}2$.
*Proof (Lang's):* 1. $n=1$: both sides equal $1$. 2. Assume it for $n$. Then $1+\cdots+n+(n+1)=\frac{n(n+1)}2+(n+1)$. 3. Common denominator: $\frac{n^2+n+2n+2}{2}=\frac{(n+1)(n+2)}2$. 4. This is $A(n+1)$.
*Intuition:* pair the first and last terms (Gauss). *Example:* $n=4$: $1+2+3+4=10=4\cdot5/2$.

**Proposition (multiplicative functions).** If $f(x+y)=f(x)f(y)$ for all $x,y$ and $f(1)=a$, then $f(n)=a^n$ for all positive integers $n$.
*Proof (Lang's):* 1. $n=1$: given. 2. Assume $f(n)=a^n$. Then $f(n+1)=f(n)f(1)=a^na=a^{n+1}$.
*Example:* $f(x)=3^x$ has $f(1)=3$, so $f(4)=81$.

**Theorem (binomial expansion; statement and formula).** $(x+y)^n=\sum_{k=0}^n C_n^k\,x^ky^{n-k}$, where $C_n^k=\dfrac{n!}{k!\,(n-k)!}$.
*Proof (Lang's):* the expansion: in $(x+y)(x+y)\cdots(x+y)$ we choose $x$ from $k$ of the $n$ factors and $y$ from the other $n-k$, and sum over all choices; the number of choices is $C_n^k$. The closed formula "is very simple to prove by induction" — Lang leaves it to Exercise 9 and does not give it.
*Intuition:* $C_n^k$ counts subsets of size $k$ of the $n$ factors. *Example:* $C_4^2=\dfrac{4!}{2!\,2!}=\dfrac{24}{4}=6$, so the coefficient of $x^2y^2$ in $(x+y)^4$ is $6$.

### §2. Summations

**Definitions.**
- **Cylinder** of base radius $r$ and height $h$: volume $\pi r^2h$.
- **Mixed dilation** $F_{a,b,c}:\mathbf R^3\to\mathbf R^3$, $F_{a,b,c}(x,y,z)=(ax,by,cz)$, $a,b,c>0$.
- $[a,b]$ is the set of $x$ with $a\le x\le b$.
- $C(r,h)$: the cone of base radius $r$, height $h$, obtained by revolving $y=\frac rhx$ about the $x$-axis for $0\le x\le h$.

**Theorem (volume of the cone $C(1,1)$).** The volume of the cone obtained by revolving $y=x$ about the $x$-axis, $0\le x\le1$, is $\pi/3$.
*Proof (Lang's, Archimedes' method):* 1. Cut $[0,1]$ into $n$ segments $[k/n,(k+1)/n]$. 2. Over the $k$-th segment put the cylinder of height $1/n$ and base the disc of radius $k/n$. Its volume is $\pi\frac1n\left(\frac kn\right)^2$. 3. Total: $\sum_{k=0}^n\pi\frac1n\frac{k^2}{n^2}=\frac{\pi}{n^3}\sum_{k=0}^nk^2$; the $k=0$ term is $0$, so it is $\frac\pi{n^3}\sum_{k=1}^nk^2$. 4. By Exercise 2(a) of §1 (a result stated there, proved by induction, not in the text), $\sum_{k=1}^nk^2=\frac16n(n+1)(2n+1)$. 5. So the total is $\frac\pi{n^3}\cdot\frac16n(n+1)(2n+1)=\frac\pi6\left(1+\frac1n\right)\left(2+\frac1n\right)$ (divide each of $n,\ n+1,\ 2n+1$ by $n$). 6. As $n$ grows, this approaches $\frac\pi6\cdot2=\frac\pi3$, and it approaches the volume of the cone.
*Intuition:* a stack of thin discs; the error shrinks as the discs get thinner. (Lang's sum runs to $k=n$; the book is loose about the last cylinder, which does not affect the limit.)
*Example:* $n=10$: $\frac\pi6(1.1)(2.1)=\frac{\pi}{6}(2.31)\approx0.385\pi$, against the limit $0.333\pi$.

**Proposition (volume scales under mixed dilation).** If $S$ is a solid of volume $V$, then $F_{a,b,c}(S)$ has volume $abc\,V$.
*Proof (Lang's):* 1. A rectangular solid with sides $t,u,v$ goes to one with sides $at,bu,cv$, volume $abc\,tuv$. 2. Approximate an arbitrary solid by rectangular solids; each volume is multiplied by $abc$, hence so is the total.

**Theorem (volume of a cone).** $\operatorname{vol}C(r,h)=\tfrac13\pi r^2h$.
*Proof (Lang's, via dilation):* 1. Lang first states that $C(r,h)$ is the image of $C(1,1)$ under $F_{h,r,r}$ (geometrically clear; coordinates below). 2. Here $a=h,\ b=r,\ c=r$, so $abc=r^2h$. 3. By the dilation proposition, $\operatorname{vol}C(r,h)=r^2h\cdot\frac\pi3=\frac13\pi r^2h$. 4. Why $C(r,h)=F_{h,r,r}(C(1,1))$, in coordinates: $(x,y,z)\in C(r,h)$ iff $0\le x\le h$ and $y^2+z^2\le\left(\frac rhx\right)^2$, i.e. $\left(\frac yr\right)^2+\left(\frac zr\right)^2\le\left(\frac xh\right)^2$ $(*)$. 5. Put $x'=x/h,\ y'=y/r,\ z'=z/r$. Then $(*)$ becomes $0\le x'\le1,\ y'^2+z'^2\le x'^2$ $(**)$, which says $(x',y',z')\in C(1,1)$; conversely $(**)$ gives $(*)$. So $C(r,h)$ is the image of $C(1,1)$ under $(x',y',z')\mapsto(hx',ry',rz')=F_{h,r,r}$.
Alternative (exercise 1 in the book): repeat the cylinder argument with $[0,h]$ cut into pieces of length $h/n$.
*Example:* $r=3$, $h=2$: $\frac13\pi\cdot9\cdot2=6\pi$.

### §3. Geometric series

**Definitions.**
- The **geometric sum**: $\sum_{k=0}^nc^k=1+c+\cdots+c^n$.
- The **geometric series** $\sum_{k=0}^\infty c^k$ (the book prints the lower limit as $k=1$, a misprint, since $1+c+c^2+\cdots$ starts at $k=0$): the number the sums approach as $n$ becomes arbitrarily large, when $0\le c<1$. The symbol $\infty$ ("infinity") is only an abbreviation for "as $n$ becomes arbitrarily large"; there is no number called infinity.

**Proposition (finite geometric sum).** For $c\ne1$: $1+c+\cdots+c^n=\dfrac{1-c^{n+1}}{1-c}$.
*Proof (Lang's):* 1. By distributivity $(1+c+\cdots+c^n)(1-c)=1-c^{n+1}$, since all middle terms cancel. 2. Divide by $1-c$ ($c\neq1$).
*Example:* $c=2$, $n=3$: $1+2+4+8=15=\frac{1-16}{1-2}$.

**Theorem (geometric series).** If $0\le c<1$, then $\sum_{k=0}^\infty c^k=\dfrac1{1-c}$.
*Proof (Lang's):* 1. $\sum_{k=0}^nc^k=\frac1{1-c}-\frac{c^{n+1}}{1-c}$. 2. For $0\le c<1$, $c^{n+1}\to0$ as $n$ grows (e.g. $c=\frac12$: $c^{n+1}=1/2^{n+1}$, the denominator increases). 3. So the sum approaches $\frac1{1-c}$. (For $c>1$, $c^{n+1}$ becomes large and the sum is not interesting.)
*Intuition:* each step covers half of what remains. *Example (Lang's):* $c=\frac15$: $1+\frac15+(\frac15)^2+\cdots=\frac1{1-1/5}=\frac54$. Also $c=\frac12$: $1+\frac12+\frac14+\cdots=2$.

### Recall prompts — Chapter 16
1. State the induction axiom (IND 1, IND 2) and explain how it yields $A(5)$.
2. Prove $1+2+\cdots+n=n(n+1)/2$ by induction.
3. Prove by induction that $f(x+y)=f(x)f(y)$, $f(1)=a$ implies $f(n)=a^n$.
4. Explain why $(x+y)^n=\sum C_n^kx^ky^{n-k}$ and state the formula for $C_n^k$; compute $C_5^2$.
5. Derive $\operatorname{vol}C(1,1)=\pi/3$ by cylinders, showing the algebra from $\frac\pi{n^3}\sum k^2$ to the limit.
6. How does volume change under $F_{a,b,c}$ and why?
7. Show $C(r,h)=F_{h,r,r}(C(1,1))$ in coordinates and deduce $\frac13\pi r^2h$.
8. Derive $1+c+\cdots+c^n=\frac{1-c^{n+1}}{1-c}$ and the value of the infinite series for $0\le c<1$; why is "infinity" not a number?

---

## Chapter 17 — Determinants

> A determinant turns a square array of numbers into one number which detects when a linear system has a unique solution. We define it for $2\times2$ and $3\times3$, isolate four properties (D1–D4: linear in each column, equal to 1 on the unit matrix, zero for equal columns), derive D5 and D6 from them, and use them to prove Cramer's rule. The same pattern works in all dimensions.

### §1. Matrices

**Definitions.**
- A **$2\times2$ matrix** $A=\begin{pmatrix}a&b\\c&d\end{pmatrix}$ is an array of four numbers; $3\times3$ likewise with nine.
- **Row vector / column vector**: a pair (or triple) of numbers written horizontally / vertically; we add them and multiply by numbers componentwise. Writing vertically is only notation.
- **Components** $a_{ij}$: $i$ = row, $j$ = column (e.g. $a_{12}$ is row 1, column 2). Rows $A_1,A_2,(A_3)$; columns $A^1,A^2,(A^3)$.
- **Transpose** ${}^tA=(a_{ji})$ if $A=(a_{ij})$: flip across the diagonal, rows become columns.
- **Diagonal components** $a_{11},a_{22},(a_{33})$; they do not change under transposition.
- *Example:* for $A=\begin{pmatrix}3&-5\\7&1\end{pmatrix}$: $a_{11}=3,a_{21}=7,a_{12}=-5,a_{22}=1$; the transpose is $\begin{pmatrix}3&7\\-5&1\end{pmatrix}$.

### §2. Determinants of order 2

**Definitions.**
- The **determinant** of $A=\begin{pmatrix}a&b\\c&d\end{pmatrix}$ is $ad-bc$, written $|A|$ or $D(A)$.
- *Example:* $\begin{vmatrix}-2&-5\\4&8\end{vmatrix}=(-2)(8)-(-5)(4)=-16+20=4$.

**Theorem 1.** If $ad-bc\neq0$, the system $ax+by=u,\ cx+dy=v$ has a unique solution, namely
$$x=\frac{du-bv}{ad-bc}=\frac{\begin{vmatrix}u&b\\v&d\end{vmatrix}}{\begin{vmatrix}a&b\\c&d\end{vmatrix}},\qquad y=\frac{av-cu}{ad-bc}=\frac{\begin{vmatrix}a&u\\c&v\end{vmatrix}}{\begin{vmatrix}a&b\\c&d\end{vmatrix}}.$$
*Proof (Lang's):* 1. Elimination: multiply the first equation by $d$, the second by $b$, subtract: $adx-bcx=du-bv$, i.e. $x(ad-bc)=du-bv$. So any solution has $x$ as stated. 2. Eliminating $x$ instead gives $y$ as stated. 3. Conversely these values do solve the system: $ax+by=\frac{a(du-bv)+b(av-cu)}{ad-bc}=\frac{adu-abv+abv-bcu}{ad-bc}=u$ (the $abv$ terms cancel, then $ad-bc$ cancels); similarly $cx+dy=v$.
*Intuition:* the column $(u,v)$ replaces the first column for $x$, the second for $y$; denominator always $D(A)$.
*Example:* $3x-2y=5$, $4x+7y=-4$: $D=21+8=29$; $x=\dfrac{\begin{vmatrix}5&-2\\-4&7\end{vmatrix}}{29}=\dfrac{35-8}{29}=\dfrac{27}{29}$, $y=\dfrac{\begin{vmatrix}3&5\\4&-4\end{vmatrix}}{29}=\dfrac{-12-20}{29}=-\dfrac{32}{29}$. (For $2\times2$ in practice, plain elimination is easier.)

**Theorem 2.** $D(A)=D({}^tA)$ for $2\times2$ $A$.
*Proof (Lang's):* $|A|=ad-bc$ and $|{}^tA|=\begin{vmatrix}a&c\\b&d\end{vmatrix}=ad-cb$, the same.

### §3. Properties of $2\times2$ determinants

**Definitions.**
- Write $D(A)=D(A^1,A^2)$; for columns $B=\binom{b_1}{b_2}$, $C=\binom{c_1}{c_2}$: $D(B,C)=b_1c_2-c_1b_2$. We view $D$ as a "product" of columns.
- **Unit vectors** $E^1=\binom10$, $E^2=\binom01$; **unit matrix** $E$ with these columns.

**D1 (distributivity).** $D(B'+B'',C)=D(B',C)+D(B'',C)$ and $D(B,C'+C'')=D(B,C')+D(B,C'')$.
*Proof (Lang's):* 1. $D(B'+B'',C)=(b_1'+b_1'')c_2-(b_2'+b_2'')c_1$. 2. Expand: $b_1'c_2+b_1''c_2-b_2'c_1-b_2''c_1$. 3. Regroup: $D(B',C)+D(B'',C)$. The other side is similar.

**D2 (scalars).** $D(xB,C)=x\,D(B,C)=D(B,xC)$.
*Proof:* $D(xB,C)=xb_1c_2-xb_2c_1=x(b_1c_2-b_2c_1)$; other side similar.

**D3.** $D(E)=D(E^1,E^2)=1$. *Proof:* obvious: $1\cdot1-0\cdot0$.

**D4.** $D(B,B)=0$. *Proof:* $b_1b_2-b_1b_2=0$.

These four are fundamental; the rest follow from them without components.

**D5 (add a multiple of a column).** $D(B+xC,C)=D(B,C)$ and $D(B,C+xB)=D(B,C)$.
*Proof (Lang's):* $D(B+xC,C)=D(B,C)+D(xC,C)$ (D1) $=D(B,C)+xD(C,C)$ (D2) $=D(B,C)$ (D4). Other case similar.
*Example:* $D\left(\binom12,\binom34\right)=4-6=-2$; replacing $B$ by $B-C=\binom{-2}{-2}$ gives $(-2)(4)-(3)(-2)=-8+6=-2$.

**D6 (swap columns).** $D(B,C)=-D(C,B)$.
*Proof (Lang's):* 1. $0=D(B+C,B+C)$ by D4. 2. By D1 on the first slot then the second: $=D(B,B+C)+D(C,B+C)=D(B,B)+D(B,C)+D(C,B)+D(C,C)$. 3. D4 kills $D(B,B),D(C,C)$, leaving $0=D(B,C)+D(C,B)$.
*Intuition:* $D$ is anticommutative, not commutative; the same pattern stays neat in higher dimension.

**Cramer's rule, $2\times2$ via the properties.** Solving $a_1x+b_1y=c_1,\ a_2x+b_2y=c_2$, i.e. $xA+yB=C$ (columns $A=\binom{a_1}{a_2}$, etc.): if $x,y$ is a solution then $D(C,B)=D(xA+yB,B)=xD(A,B)+yD(B,B)=xD(A,B)$ (D1, D2, D4). So $x=\dfrac{D(C,B)}{D(A,B)}$ (when $D(A,B)\neq0$), the same quotient as before. (Lang leaves $y=D(A,C)/D(A,B)$ as an exercise.)

### §4. Determinants of order 3

**Definitions.**
- For $A=(a_{ij})$ ($3\times3$), $A_{ij}$ is the $2\times2$ matrix obtained by deleting row $i$ and column $j$.
- The **determinant** is defined by **expansion by the first row**:
$$D(A)=a_{11}D(A_{11})-a_{12}D(A_{12})+a_{13}D(A_{13}).$$
- Sign pattern for the entry $(i,j)$: $+$ if $i+j$ is even, $-$ if odd:
$\begin{pmatrix}+&-&+\\-&+&-\\+&-&+\end{pmatrix}$.
- Fully expanded (six terms; do not memorize):
$D(A)=a_{11}a_{22}a_{33}-a_{11}a_{32}a_{23}-a_{12}a_{21}a_{33}+a_{12}a_{23}a_{31}+a_{13}a_{21}a_{32}-a_{13}a_{22}a_{31}$.

**Fact (expansion along any row or column).** Expanding along any row or any column, with the sign pattern above, gives the same six terms, hence the same value.
*Proof (Lang's):* write out the two terms of each $2\times2$ determinant in the expansion and compare with the six-term formula (checked for the second row and first column in the text; the others are Exercise 1).
*Example:* $D=\begin{vmatrix}3&0&1\\1&2&5\\-1&4&2\end{vmatrix}$ along the second column (the $0$ kills a term): $2\begin{vmatrix}3&1\\-1&2\end{vmatrix}-4\begin{vmatrix}3&1\\1&5\end{vmatrix}=2(6+1)-4(15-1)=14-56=-42$. Along the third column: $1\begin{vmatrix}1&2\\-1&4\end{vmatrix}-5\begin{vmatrix}3&0\\-1&4\end{vmatrix}+2\begin{vmatrix}3&0\\1&2\end{vmatrix}=6-60+12=-42$.
*Example (first row, Lang's):* $A=\begin{pmatrix}2&1&0\\1&1&4\\-3&2&5\end{pmatrix}$. $A_{11}=\begin{pmatrix}1&4\\2&5\end{pmatrix}$, $A_{12}=\begin{pmatrix}1&4\\-3&5\end{pmatrix}$, $A_{13}=\begin{pmatrix}1&1\\-3&2\end{pmatrix}$, so $D(A)=2(5-8)-1(5+12)+0=-6-17=-23$.

**Theorem 3.** For $3\times3$ $A$: $D(A)=D({}^tA)$.
*Proof (Lang's):* expanding $D(A)$ by rows or by columns gives the same value, and expanding $D({}^tA)$ by a row is expanding $D(A)$ by the corresponding column.

### §5. Properties of $3\times3$ determinants

Write $D(A)=D(A^1,A^2,A^3)$; all vectors have 3 components.

**D1.** If $A^1=B+C$ then $D(B+C,A^2,A^3)=D(B,A^2,A^3)+D(C,A^2,A^3)$; the same holds for the 2nd and 3rd columns.
*Proof (Lang's):* use the first-row expansion, with $A^1=B+C$ (so $a_{i1}=b_i+c_i$). 1. First term: $(b_1+c_1)D(A_{11})=b_1D(A_{11})+c_1D(A_{11})$. 2. Second and third terms: the minors $A_{12},A_{13}$ have first column $\binom{b_2+c_2}{b_3+c_3}$, so by the $2\times2$ D1 each splits into a $B$-minor plus a $C$-minor. 3. Collect the $B$-pieces (with signs $+,-,+$): that is $D(B,A^2,A^3)$; likewise the $C$-pieces give $D(C,A^2,A^3)$. Lang writes out the splitting of each term for the first column and says the other columns are similar (Exercise 1).

**D2.** $D(xA^1,A^2,A^3)=x\,D(A^1,A^2,A^3)$, similarly for other columns.
*Proof (Lang's):* in the first-row expansion each term picks up a factor $x$ (either from $xa_{11}$ or from the minor by the $2\times2$ D2); factor $x$ out.

**D3.** $D(E)=1$ for the $3\times3$ unit matrix ($E^1,E^2,E^3$ the unit vectors). *Proof:* obvious from the first-row expansion.

**D4.** Two equal columns give $D=0$.
*Proof (Lang's):* if $A^1=A^2$ then $a_{11}=a_{12}$ and the first two terms of the first-row expansion cancel; the third is $0$ since its $2\times2$ minor has equal columns. The cases $A^2=A^3$, $A^1=A^3$ are similar.

(D1–D4 need the definition; the rest follow from them alone.)

**D5.** Adding a multiple of one column to another leaves $D$ unchanged, e.g. $D(A^1,A^2+xA^1,A^3)=D(A^1,A^2,A^3)$.
*Proof (Lang's):* $D(A^1,A^2+xA^1,A^3)=D(A^1,A^2,A^3)+D(A^1,xA^1,A^3)$ (D1) $=D(A^1,A^2,A^3)+xD(A^1,A^1,A^3)$ (D2) $=D(A^1,A^2,A^3)$ (D4).

**D6.** Interchanging two adjacent columns changes the sign, e.g. $D(A^1,A^3,A^2)=-D(A^1,A^2,A^3)$.
*Proof (Lang's):* 1. $0=D(A^1,A^2+A^3,A^2+A^3)$ (D4). 2. By D1 $=D(A^1,A^2,A^2+A^3)+D(A^1,A^3,A^2+A^3)$. 3. Again by D1, $=D(A^1,A^2,A^2)+D(A^1,A^2,A^3)+D(A^1,A^3,A^2)+D(A^1,A^3,A^3)$. 4. D4 kills the first and last, leaving $0=D(A^1,A^2,A^3)+D(A^1,A^3,A^2)$.

**Computing efficiently.** Use D5 to create zeros (Lang's examples subtract rows; this is justified by Theorem 3, since rows of $A$ are columns of ${}^tA$; Lang leaves D5, D6 for rows as Exercise 7), then expand along the row or column with the zeros.
*Example:* $\begin{vmatrix}3&0&1\\1&2&5\\-1&4&2\end{vmatrix}$: subtract 2 times row 2 from row 3: $\begin{vmatrix}3&0&1\\1&2&5\\-3&0&-8\end{vmatrix}$. Expand along column 2: only the entry $2$ remains, sign $+$: $2\begin{vmatrix}3&1\\-3&-8\end{vmatrix}=2(-24+3)=-42$.
*Example:* $\begin{vmatrix}4&7&10\\3&7&5\\5&-1&10\end{vmatrix}$: subtract 2 times row 2 from rows 1 and 3: $\begin{vmatrix}-2&-7&0\\3&7&5\\-1&-15&0\end{vmatrix}$. Expand along column 3: entry $5$ at position $(2,3)$, sign $-$: $-5\left((-2)(-15)-(-7)(-1)\right)=-5(30-7)=-115$.

### §6. Cramer's rule

**Setup.** The system $a_{11}x_1+a_{12}x_2+a_{13}x_3=b_1$, etc., is $x_1A^1+x_2A^2+x_3A^3=B$ in column notation.

**Theorem 4 (Cramer's rule).** If $x_1,x_2,x_3$ solve the system and $D(A)\ne0$ then
$$x_1=\frac{D(B,A^2,A^3)}{D(A^1,A^2,A^3)},\quad x_2=\frac{D(A^1,B,A^3)}{D(A^1,A^2,A^3)},\quad x_3=\frac{D(A^1,A^2,B)}{D(A^1,A^2,A^3)}.$$
*Proof (Lang's):* 1. $D(B,A^2,A^3)=D(x_1A^1+x_2A^2+x_3A^3,A^2,A^3)$. 2. By D1 and D2 this is $x_1D(A^1,A^2,A^3)+x_2D(A^2,A^2,A^3)+x_3D(A^3,A^2,A^3)$. 3. By D4 the last two vanish, leaving $x_1D(A)$. 4. Divide by $D(A)\neq0$. $x_2,x_3$ are handled the same way (Exercise 2).
*Note.* The theorem says: *if* a solution exists, it is given by these formulas. It does not prove existence.
*Example:* $3x+2y+4z=1$, $2x-y+z=0$, $x+2y+3z=1$. $D(A)=\begin{vmatrix}3&2&4\\2&-1&1\\1&2&3\end{vmatrix}=3(-5)-2(5)+4(5)=-5$. Numerators (column $B=(1,0,1)$ substituted): $D_x=1(-5)-2(-1)+4(1)=1$, $D_y=3(-1)-1(5)+4(2)=0$, $D_z=3(-1)-2(2)+1(5)=-2$. So $x=-\tfrac15$, $y=0$, $z=\tfrac25$. (Check in eq. 1: $-\tfrac35+0+\tfrac85=1$.)

**Theorem 5.** If $D(A)\ne0$ ($3\times3$), then for every column $B$ there are numbers $x_1,x_2,x_3$ with $x_1A^1+x_2A^2+x_3A^3=B$; i.e. the system has a solution.
*Proof:* omitted in the book ("slightly more involved than the $2\times 2$ case").
*Intuition (ours):* together with Theorem 4, $D(A)\neq 0$ gives exactly one solution.

### Recall prompts — Chapter 17
1. Define $D(A)$ for $2\times2$; derive the formulas for $x,y$ in Theorem 1 by elimination and verify they solve the system.
2. Prove $D(A)=D({}^tA)$ for $2\times2$.
3. State D1–D4 for $2\times2$ and prove each from the formula.
4. From D1, D2, D4 derive D5 and D6 (2x2), writing out each step.
5. Use the properties to derive $x=D(C,B)/D(A,B)$ and, in the same way, $y$.
6. Define the $3\times3$ determinant by first-row expansion with the sign pattern; why do other rows/columns give the same value, and why $D(A)=D({}^tA)$?
7. Prove D1, D2, D4 for $3\times3$ from the definition.
8. Prove D5 and D6 for $3\times3$ using only D1, D2, D4.
9. State and prove Cramer's rule (Theorem 4); what does it not claim (Theorem 5)?
10. Compute a $3\times3$ determinant by first making zeros with D5, then expanding.

---

# Map of Results — the whole book on a few pages

**How to use it.** This is your review tool for the spaced sessions (§0.5). Cover the right-hand side, or the chain
after each arrow, and rebuild it. *Italic* = assumed by Lang. Plain = proved. ⇒ = "is used to prove". (L) = left to
the reader / exercise in the book.

## Part One — Algebra

**Ch 1 Numbers**
- *Addition:* *comm., assoc., N 1 ($0+a=a$), N 2 ($a+(-a)=0$)* ⇒ **N 3** ($a+b=0 \Rightarrow b=-a$) ⇒ **N 4**
  ($-(-a)=a$), **N 5** ($-(a+b)=-a-b$) ⇒ solving $a+b=c$; *positive + positive is positive* ⇒ negative + negative is
  negative.
- *Multiplication:* *comm., assoc., distributivity, N 6 ($1a=a$)* ⇒ $0a=0$ ⇒ **N 7** ($(-1)a=-a$) ⇒ **N 8**, **N 9**
  (L), **N 10** ($(-a)(-b)=ab$, L) ⇒ square formulas $(a\pm b)^2$, $(a+b)(a-b)=a^2-b^2$. **N 11, N 12** (power rules,
  by counting factors).
- *Parity:* **Thm 1** (sums of even/odd) · **Thm 2** ($a$ even/odd ⇒ $a^2$ even/odd) ⇒ **Cor.** ($a^2$ even ⇒ $a$ even).
- *Rationals:* *cross-multiplication $m/n=r/s \iff ms=nr$* ⇒ cancellation $am/an=m/n$ ⇒ **Thm 3** (lowest form) ⇒
  **Thm 4** ($\sqrt2$ is not rational — uses Thm 3 + Cor. of Thm 2, by contradiction). Addition
  $\frac mn+\frac rs=\frac{ms+rn}{ns}$. *Transfer:* what is proved from the basic rules holds in $\mathbb Q$.
- *Inverses:* $a\neq0 \Rightarrow a^{-1}=n/m$ ⇒ uniqueness of inverse ⇒ **no zero divisors** ($ab=0 \Rightarrow a=0$ or
  $b=0$) ⇒ cross-multiplication for rationals, cancellation law, $\frac ab+\frac cd=\frac{ad+bc}{bd}$.

**Ch 2 Linear equations** — elimination: eliminate one unknown, solve, substitute back, **check the converse**
(elimination gives *necessary* values). Some systems have no solution.

**Ch 3 Real numbers**
- Same rules as $\mathbb Q$; *every $a\neq0$ has an inverse*.
- *POS 1* (positive · positive and positive + positive are positive), *POS 2* (exactly one of $a>0$, $a=0$, $-a>0$) ⇒
  $1>0$ ⇒ sign rules ⇒ $x^2\ge0$.
- *Square root exists for $a>0$* ⇒ exactly two roots $\pm\sqrt a$ (via $(x-b)(x+b)=0$ + no zero divisors) ⇒
  $|x|=\sqrt{x^2}$, rationalising with $(x+y)(x-y)$.
- *$n$-th root exists and is unique* ⇒ **Thm 1** $(ab)^{1/n}=a^{1/n}b^{1/n}$ ⇒ **POW 1–3** for rational exponents ⇒
  $a^0=1$, $a^{-x}=1/a^x$.
- $a>b$ means $a-b>0$ ⇒ **IN 1** (transitivity), **IN 2** (× positive keeps), **IN 3** (× negative reverses, L) ⇒
  solving inequalities by cases on signs.

**Ch 4 Quadratic equations** — complete the square ⇒ **quadratic formula**
$x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}$; $b^2-4ac<0$ ⇒ no real root (because squares are $\ge0$, POS).

**Interlude — Logic** — implication vs **converse**; "iff" = both directions; **proof by contradiction**; "for all" /
"there exists"; set equality = **two inclusions** ($S\subset S'$ and $S'\subset S$).

## Part Two — Intuitive Geometry

**Ch 5 Distance and angles**
- *DIST 1–3* (positivity, symmetry, triangle inequality); *SEG 1–2* (when $Q$ lies on segment $PM$).
- Degrees by area of sector; straight angle $=180°$.
- *RT* (right triangles with equal legs match), *PD*, *rectangle area $ab$* ⇒ **Thm 1** (acute angles sum to $90°$) ⇒
  **Thm 2** (right-triangle area $ab/2$) ⇒ **Pythagoras** ($(a+b)^2 = c^2 + 4\cdot\frac{ab}2$, the square with four
  triangles inside) ⇒ **Lemma** (midpoint) ⇒ **Cor.** ($d(P,M)=d(Q,M) \iff M$ on the perpendicular bisector).

**Ch 6 Isometries**
- *Reflections, rotations, translations are isometries.*
- **Thm 1** (segments ↦ segments, from SEG 1) ⇒ Cor. lines ↦ lines (L) ⇒ **Thm 2** (fixing $P,Q$ fixes line $PQ$) ⇒
  **Thm 3** (fixing 3 non-collinear points ⇒ identity) ⇒ Cor. (agree on 3 points ⇒ equal, L).
- Composition: associativity, $(F\circ G)^{-1}=G^{-1}\circ F^{-1}$, $G_x\circ G_y=G_{x+y}$.
- **Thm 4** (2 fixed points: identity or reflection) ⇒ **Thm 5** (1 fixed point: rotation, or rotation∘reflection) ⇒
  **Thm 6** (every isometry = $T$, $TG$ or $TGR$).
- Congruence: **Thm 7** (circles, equal radius) · **Thm 8** (segments) · **Thm 9** (right triangles, L) · **Thm 10** (SSS).
  *Isometries preserve area.*

**Ch 7 Area** — *area($rS$) = $r^2$ area($S$)* (proved for rectangles) ⇒ disc area $\pi r^2$ ⇒ circumference $2\pi r$ (by
polygon approximation); $d(rP,rQ)=r\,d(P,Q)$.

## Part Three — Coordinate Geometry

**Ch 8** — Pythagoras ⇒ **distance formula** $\sqrt{(x_2-x_1)^2+(y_2-y_1)^2}$ ⇒ **circle**
$(x-a)^2+(y-b)^2=r^2$ ⇒ rational points: $x=\frac{1-t^2}{1+t^2}$, $y=\frac{2t}{1+t^2}$; **Thm 1** (every point with
$x\ne-1$ comes from $t=\frac{y}{x+1}$) ⇒ **Cor.** (rational points ↔ rational $t$ ↔ Pythagorean triples).

**Ch 9** — points as pairs: $cA$, $A+B$ (componentwise) ⇒ **Thm 1** $d(rA,rB)=r\,d(A,B)$ ⇒ **Thm 2**
$d(cA,cB)=|c|\,d(A,B)$; **parallelogram law**; $T_A(P)=P+A$; $d(A,B)=|A-B|$ ⇒ **Thm 3** (circle$(r,A)$ =
$T_A$(circle$(r,O)$)).

**Ch 10** — segment $\{P+t(Q-P): 0\le t\le1\}$ ⇒ ray $\{P+tA: t\ge0\}$ ⇒ line $\{P+tA: t\in\mathbb R\}$ ⇒ parallel
($A=cB$), same direction ($c>0$) ⇒ intersections (solve for $s,t$; line–circle gives a quadratic in $t$) ⇒ ordinary
equation $ax+by=c$.

**Ch 11 Trigonometry**
- Radians by sector area ($x$ = arc length on the unit circle) ⇒ $\sin A=b/r$, $\cos A=a/r$ (independent of the point,
  by scaling) ⇒ **SC 1** $\sin^2+\cos^2=1$; **SC 2–3** (sin odd, cos even); **SC 4–5 = Thm 1/2** ($\cos x=\sin(x+\pi/2)$,
  $\sin x = \cos(x-\pi/2)$).
- **Thm 3** (addition formula for $\cos(A+B)$: the squared distance between two points of the unit circle, computed in
  two coordinate systems; then $\sin(A+B)=\cos(A+B-\pi/2)$ via Thm 1–2) ⇒ **Cor.** ($x-y$ formulas) ⇒ **SC 6–9** (double angle and half angle, L).
- Rotation: $x'=x\cos\varphi-y\sin\varphi$, $y'=x\sin\varphi+y\cos\varphi$ (from the addition formulas, in polar form).

**Ch 12 Analytic geometry** — $y=ax+b$, slope, point-slope; parabola $(y-b)=c(x-a)^2$ by translation (complete the
square); ellipse = mixed dilation $F_{a,b}$ of the unit circle; hyperbola $xy=c$ ⇒ **Thm 1** (rotating $xy=1$ by $\pi/4$
gives $v^2-u^2=2$) ⇒ $xy=r^2 \mapsto v^2-u^2=2r^2$.

## Part Four — Miscellaneous

**Ch 13 Functions** — function arithmetic obeys the number rules ⇒ **Thm 1** (factor theorem:
$f(c)=0 \Rightarrow f=(x-c)g$) ⇒ **Thm 2** (degree $n$ ⇒ at most $n$ roots) ⇒ **Cor.** (coefficients are unique). Euclidean algorithm
$f=qg+r$ (procedure, not proved). *EXP 1–4* ⇒ $a^0=1$, $a^x>0$; *log exists* ⇒ **LOG 1** $\log xy=\log x+\log y$,
**LOG 2**, **LOG 3** (increasing); $\log a^x = x\log a$ (L).

**Ch 14 Mappings** — identity, associativity of $\circ$, unique inverse (L), $f^{m+n}=f^m\circ f^n$ ⇒ permutations:
**Thm 1** (product of transpositions) · **Thm 3** (orbits are equal or disjoint) ⇒ **Lemma** (a transposition changes
the number of orbits by $\pm1$) ⇒ **Thm 2** (parity well defined) ⇒ **Thm 4** ($k$ orbits: $\sigma$ even $\iff n-k$ even).

**Ch 15 Complex numbers** — *$\mathbb C$ with $i^2=-1$ obeys the rules* ⇒ $z\bar z=|z|^2$ ⇒ $z^{-1}=\bar z/|z|^2$; **Thm 1**
(conjugation, proof omitted) ⇒ **Thm 2** ($|zw|=|z||w|$, triangle inequality) ⇒ polar form $z=re^{it}$ ⇒ **Thm 3**
($e^{it}e^{ip}=e^{i(t+p)}$, which *is* the addition formulas of Ch 11) ⇒ multiply: multiply moduli, add angles.

**Ch 16 Induction** — *IND* ⇒ $1+\dots+n=\frac{n(n+1)}2$; $f(x+y)=f(x)f(y) \Rightarrow f(n)=a^n$; binomial theorem
(induction L); $\sum k^2 = \frac{n(n+1)(2n+1)}6$ (L) ⇒ cone volume $\frac13\pi r^2h$; geometric sum
$\frac{1-c^{n+1}}{1-c}$ ⇒ series $\frac1{1-c}$ for $0\le c<1$.

**Ch 17 Determinants** — 2×2: **Thm 1** ($ad-bc\ne0$ ⇒ unique solution) · **Thm 2** ($D(A)=D({}^tA)$) · **D1–D6** (linear
in each column, $D(E)=1$, equal columns ⇒ 0, adding a multiple of a column leaves it unchanged, swap ⇒ sign change) ⇒ 3×3:
expansion by first row ⇒ **Thm 3** (transpose) ⇒ D1–D6 ⇒ **Thm 4 Cramer** $x_j=\frac{D(A^1,\dots,B,\dots,A^n)}{D(A)}$;
**Thm 5** ($D(A)\ne0$ ⇒ a solution exists, omitted).

## Rebuild drills (one line each — derive, don't recall)

| Formula | Rebuild it from |
|---|---|
| $(a+b)^2=a^2+2ab+b^2$ | distributivity twice + commutativity |
| $(-a)(-b)=ab$ | N 7: $(-a)(-b)=(-1)(-1)ab$, and $(-1)(-1)=1$ by N 4 + N 7 |
| $\sqrt2\notin\mathbb Q$ | lowest form $m/n$ + "$m^2$ even ⇒ $m$ even" twice ⇒ both even, contradiction |
| quadratic formula | divide by $a$, add $(b/2a)^2$ to both sides, take $\pm\sqrt{\ }$ |
| Pythagoras | big square side $a+b$ = inner square $c^2$ + four triangles $ab/2$ |
| distance formula | Pythagoras on the horizontal and vertical legs |
| rational points on circle | line through $(-1,0)$ with slope $t$ meets the circle again |
| $\cos(A+B)$ | $\lvert PQ\rvert^2$ for $P$ at angle $0$, $Q$ at $A+B$; turn the axes so $P$ is at $-A$, $Q$ at $B$; equate $2-2\cos(A+B)$ with the second computation |
| $\sin 2x$, $\cos^2 x=\frac{1+\cos2x}2$ | put $A=B=x$ in Thm 3, then SC 1 |
| rotation formulas | $(r\cos\theta, r\sin\theta) \mapsto (r\cos(\theta+\varphi), r\sin(\theta+\varphi))$ + addition formulas |
| $\log xy=\log x+\log y$ | $x=a^u$, $y=a^v$ ⇒ $xy=a^{u+v}$ (EXP 1) |
| $1+c+\dots+c^n$ | multiply the sum $S$ by $(1-c)$: everything telescopes |
| Cramer 2×2 | eliminate $y$: $(ad-bc)x = ud-bv$ |
| permutation parity | count orbits: each transposition changes the count by $\pm1$ |
