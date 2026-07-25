# Day 1 Lab — reverse-engineer a system into C4 + your first ADR

Day 1 is design-heavy: there's little to "run." The lab is producing **artifacts** —
two C4 diagrams and one ADR — for a real system you operate, plus a short
"decision vs detail" drill. The only thing to "execute" is verifying the Mermaid
renders. No docker needed today.

## What you'll produce

1. `../design/reverse-engineer.md` — the 7-step method on your system (Beat 2).
2. `../diagrams/context.mmd` (C1) and `../diagrams/containers.mmd` (C2).
3. `../adr/0001-<title>.md` — one real decision, re-justified.
4. `results.md` — the decision-vs-detail drill + render check + reflections.

Worksheets to copy and fill are in this folder:
- `reverse-engineer-worksheet.md` → copy to `../design/reverse-engineer.md`, fill it.
- `context.mmd`, `containers.mmd` → copy to `../diagrams/`, replace the TODOs.
- `decision-vs-detail.md` → do the drill, record answers in `results.md`.

## Step-by-step

### 1. Pick the system (2m)
Choose a system you've built or operate and know deeply — an integration pipeline, a
Kafka-backed service, an internal platform. Deep knowledge > impressive scope.

### 2. Run the method (Beat 2, ~60m)
```bash
cp reverse-engineer-worksheet.md ../design/reverse-engineer.md
```
Fill every section. Do not skip step 7 (5 failure modes) — that's the red-team rep.

### 3. Draw C1 + C2 (~20m)
```bash
cp context.mmd    ../diagrams/context.mmd
cp containers.mmd ../diagrams/containers.mmd
# edit both: replace every TODO with your system's real boxes/arrows
```
Keep the C4 rules (see `reference/c4-guide.md`): one zoom level per diagram, every box
has name + technology + one-line responsibility, every arrow has a label + protocol,
≤ ~7 elements each.

### 4. Verify the diagrams render (the only "run" step, ~5m)
Pick whichever you have:
- **VS Code:** install the "Markdown Preview Mermaid Support" or "Mermaid" extension,
  open the `.mmd`, preview.
- **Browser (offline-capable):** the Mermaid Live Editor (mermaid.live) — paste the
  file contents. Works from a cached page; no data leaves the browser.
- **CLI (if installed):** `npx @mermaid-js/mermaid-cli -i diagrams/context.mmd -o /tmp/c1.svg`
  and open the SVG.

If `C4Context`/`C4Container` don't render in your tool, fall back to the plain
`flowchart LR` form shown in `reference/c4-guide.md` — it renders everywhere.
**Expected:** two valid diagrams, no syntax errors.

### 5. Write ADR 0001 (~15m)
Copy the template and fill it for one real decision in the system (ideally the one
from step 6 of your method):
```bash
cp ../../../reference/adr-template.md ../adr/0001-<short-title>.md
```
The **Alternatives considered** section must be real — name the runner-up and why it
lost against your top NFR. Apply the one-sentence test from `content/day01.md`.

### 6. The decision-vs-detail drill (~10m)
Work `decision-vs-detail.md` and record your classifications + reasoning in
`results.md`. This is the core Day-1 skill: telling one-way doors from two-way doors.

## "Break-it" for a design day
There's no system to overload, so the break-it is **adversarial review of your own
artifacts**:
- Cover the "Decision" in your ADR and ask a colleague (or yourself, cold) to guess it
  from the Context + Alternatives alone. If they can't, the ADR isn't self-contained —
  fix it.
- Find one box in your C2 that you *cannot* give a one-line responsibility to. That's
  either a missing decision or an accidental detail on the diagram — resolve it.

Record what broke and how you fixed it in `results.md`.
