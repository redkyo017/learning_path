# Day 10 Lab — Protocol Composition

## Goal

Complete the composite flow checklist for a PSD2 payment initiation scenario **without referring back to Days 01–09**. This is a recall and synthesis exercise: if you need to look something up, note which protocol you forgot — that is a signal for further review.

## Success signal

You can trace a full PSD2 payment flow end-to-end and name the protocol responsible for each security guarantee. You can also describe the data dependency between any two adjacent protocols in the chain.

## Steps

1. Open `config/composite_flow_checklist.md`.
2. For each row, fill in the `Protocol` and `Day covered` columns from memory.
3. For any row you are unsure about, write a question mark and come back to it after attempting all rows.
4. After completing the checklist, draw the full composite flow on paper or in a diagramming tool, labelling each arrow with the protocol responsible.
5. Check your work against `SOLUTION.md`.

## Stretch exercise

Pick any two adjacent protocols in Scenario 1 (customer-facing PSD2 payment). Write a one-paragraph description of the *handoff point*: what data does protocol A produce that protocol B consumes? What happens if that handoff is broken?

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — lab instructions |
| `diagram.md` | Grand composite Mermaid sequence diagram for the full PSD2 flow |
| `config/composite_flow_checklist.md` | Blank checklist — fill in before checking SOLUTION.md |
| `SOLUTION.md` | Filled checklist with protocol names and explanations |
