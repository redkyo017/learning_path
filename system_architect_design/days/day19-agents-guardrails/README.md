# Day 19 — Agent orchestration, tool use, guardrails, evaluation

**Teardown target:** agent architectures + LLM-as-judge evaluation (ties to your
Bedrock AgentCore work).
**Design brief:** a tool-using agent with guardrails and an eval harness.
**ADR topic:** single-agent-with-tools vs. multi-agent; guardrail placement.
**Lab:** a minimal agent loop + a guardrail + an eval harness over several cases.
**When NOT this:** a multi-agent swarm for a task a single prompt + one tool solves —
you add latency, cost, and non-determinism for no gain.
**Builds on:** Day 18 (LLM/RAG — the retriever becomes a tool).
**Sets up for:** Day 21 capstone (which may include an AI component).

Theory: read **`content/day19.md`** first. Lab: **`lab/README.md`**.

---

**Beat 1 — Teardown warm-up (~20m).** Read `content/day19.md` and the Day 19 entry
in `reference/real-world-case-studies.md`. Study one agent architecture (Bedrock
AgentCore, or Anthropic's *Building Effective Agents*). Extract: what is the loop,
and what does the *platform* add around it (tools/gateway, memory, guardrails,
eval)? Log your takeaway — especially "agents vs. workflows: when is a loop
actually justified?"

**Beat 2 — Design core (~55m).** Run `reference/design-method.md` in order on: *an
agent that answers a question using 1–2 tools (the Day-18 retriever + a calculator),
with guardrails.*
1. **Requirements:** answer doc-grounded questions; may need 0–N retrievals; can do
   arithmetic; must never leak secrets/PII; output a fixed shape.
2. **Constraints:** LLM via AWS Bedrock (AgentCore/Bedrock runtime) or any API;
   per-request cost/latency budget; the corpus is user-extendable (so: untrusted).
3. **Top-3 NFRs:** pick from `reference/nfr-checklist.md` — likely **reliability**
   (correct under injection/retries), **security** (no leak), **cost** (bounded
   loop/tokens). Set targets.
4. **Options:** (A) single agent + tools; (B) orchestrator–worker multi-agent.
   Compare against the tradeoff table in `content/day19.md`.
5. **Tradeoffs:** table over the top-3 NFRs + latency + complexity.
6. **Decision:** one sentence — "single agent + tools, because for our reliability/
   cost NFRs it is easier to bound and eval, and the task doesn't fan out."
7. **Red-team:** a prompt injection in retrieved content that tries to hijack a tool
   call or exfiltrate a secret. Where does it break, and what stops it?

Write the 7 steps to `design/`; write **one ADR** to `adr/` (single vs. multi-agent,
*and* where guardrails sit) using `reference/adr-template.md`.
**Suggested ADR number:** the next free number in your global sequence (≈ `0019` if
you've been writing ~one per day; ADR numbers are global across all days).

**Beat 3 — Hands-on lab (~55m).** See `lab/README.md`. Implement the minimal agent
loop calling the LLM with tool definitions; wire the Day-18 retriever as a tool; add
an **output guardrail** (reject answers failing a schema / containing blocked
patterns); build an **eval harness** (~6 cases with expected properties, scored by
rules or LLM-as-judge; print a pass rate). **Break-it:** feed a prompt-injection case
and confirm the guardrail catches it (or observe it doesn't, then harden). Record the
pass rate + failures in `lab/results.md`.

**Beat 4 — Journal + teardown (~10m).** Append to `../../journal.md`:
```
### Day 19 — agents, tool use, guardrails, evaluation
Key concept in my own words: …
When would I NOT use an agent: …
Break-it — did the guardrail catch the injection? what leaked / what stopped it: …
Biggest surprise / open question: …
```

---

**Outputs checklist:**
- [ ] `design/` — the filled-in 7-step design (agent + tools + guardrails)
- [ ] `diagrams/` — at least one C4 diagram (`.mmd`); a plan→act→observe sequence is fine
- [ ] `adr/NNNN-*.md` — single vs. multi-agent + guardrail placement
- [ ] `lab/results.md` — pass rate, the injection case result, what you hardened
- [ ] `journal.md` entry appended
