# Book-condense prompts

Prompts for turning one book (usually a PDF you have already read) into a single condensed companion file for
long-term memory. They pair with the sub-skill `skill_book_condense.md`. For learning a whole subject as a multi-day
path, use `basic_prompt.md` + `skill.md` instead.

<!-- ===== v1 — the original request (2026-10-15), kept as written =====
Produced basic_mathematics_lang.md. Answers given in the question round are listed after it. -->

I want to master the basic maths knowledge in the book of Serge Lang at '/Users/hunghd/Downloads/Basic Mathematics - Serge Lang.pdf' as fast as humanly possible. Skip the traditional learning path - give me the unconventional strategy that the top 1% use, the exact mistakes to avoid that waste 80% of beginners' time, and a aggreesive practive plan the fast-tracks real results. keep the format, spirit and the simplicity explaination style of the author, alongside the number of practicing exercises make the new and comprehensive content of the book based on above, the output will be a markdown file as a concise version of tnis book but still include comprehensive statements, detailed step-by-step proofs, intuitive explanations, and fully worked-out examples for every major axiom, proposition, theorem, lemma, and corollary

Answers in the question round: purely revise to consolidate; last studied ~17 years ago, fast learner; read the book
once a week ago, want long-term memory; just one markdown file, no directory or git; no exercises in the file (I do the
book's); use exactly the book's proofs, condensed.


<!-- ===== v2 template (2026-10-16) — same intent, slotted =====
What changed vs v1, and why:
- Goal, output, exercises and proofs are slots: these four answers decided the whole design last time.
- "Top 1%" / "80%" are figures of speech: the strategy must cite learning research or say it is judgment.
- The source PDF is the source of truth, checked against the page IMAGES: OCR text garbles formulas and theorem numbers.
- Misprints in the book are kept visible ("the book prints X"), never fixed silently.
- One capped question round with defaults, so it doesn't stall.
Fill the [BRACKETS]; delete optional lines you don't need. -->

Condense the book at '[PDF PATH]' ([AUTHOR], *[TITLE]*, [edition if known]) into one markdown file I can keep for long-term memory.

Goal: [consolidate — I read it [when] / learn it for the first time]. About me: see LEARNER_PROFILE.md, plus: [last time I studied this subject, current level].

Keep the author's structure, order, spirit and plain explaining style. For every major definition, axiom, proposition, theorem, lemma and corollary give: the precise statement, [the author's own proof, condensed into numbered steps / a clearer proof of your own], a short intuition, and one fully worked example. Keep the author's own labels.

Exercises: [none in the file — I'll do the book's / new exercises with hints and solution sketches, about [N] per chapter].

Also give me:
1. The strategy that actually makes this stick long-term — backed by learning research, cited.
2. The mistakes that waste the effort — for each, how I'd notice it and what to do instead.
3. An aggressive practice plan: a [7]-day sprint at [2–3] h/day, then spaced review sessions for the months after.
4. A one-page map of the whole book's results in dependency order, for later reviews.

Output: [one file at the repo root, untracked / path]. [No directory, no git.]

Rules for you:
- Accurate over impressive. The PDF is the source of truth: check formulas, statements and examples against the page images, not only the extracted text. Say what you could not verify.
- If the book has a misprint, use the correct value and note what the book prints.
- "Top 1%" and "80%" are figures of speech — don't invent statistics; cite the research or label it as your judgment.
- Mark what the author assumes, proves, or leaves to the reader, and mark anything you add as yours.
- Use the local skill_book_condense.md file as the standard skill.

Ask me questions before starting: one round, at most 5, each with a suggested default I can accept by replying "defaults".
