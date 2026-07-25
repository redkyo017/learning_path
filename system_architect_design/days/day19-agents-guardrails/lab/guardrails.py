"""Guardrails: the deterministic checks that bracket the non-deterministic model.

These are the parts you CAN unit-test. Keep them cheap and put the strictest checks
at the boundaries that matter (tool args, final output).

Provided:
  * input_guardrail(text)  -> before the model
  * output_guardrail(text) -> after the model (schema + blocked patterns)

Left as a clearly-marked TODO for you: a GROUNDEDNESS check (does the answer's claim
actually appear in the retrieved context, and do its citations reference real doc
ids?). That is the check that turns "the answer looks fine" into "the answer is
supported" — and it is your real backstop against a confidently-wrong or injected
answer that happens to dodge the blocked-pattern regexes.
"""
from __future__ import annotations

import re
import json
from dataclasses import dataclass, field


@dataclass
class GuardrailResult:
    ok: bool
    reasons: list = field(default_factory=list)
    parsed: dict | None = None


# --- input -------------------------------------------------------------------------

_MAX_INPUT = 2000
_JAILBREAK = re.compile(r"ignore (all|previous|prior).{0,20}instructions", re.IGNORECASE)


def input_guardrail(text: str) -> GuardrailResult:
    reasons = []
    if len(text) > _MAX_INPUT:
        reasons.append("input_too_long")
    if _JAILBREAK.search(text):
        reasons.append("jailbreak_phrase_in_input")
    return GuardrailResult(ok=not reasons, reasons=reasons)


# --- output ------------------------------------------------------------------------

# Blocked patterns: things that must never appear in an answer we ship.
_BLOCKED = [
    ("aws_access_key", re.compile(r"AKIA[0-9A-Z]{12,}")),
    ("secret_keyword", re.compile(r"secret[_ ]?access[_ ]?key", re.IGNORECASE)),
    ("email_pii", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
]


def output_guardrail(text: str) -> GuardrailResult:
    reasons = []

    # 1. schema: must be JSON {answer: str, citations: [str]}
    try:
        parsed = json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return GuardrailResult(ok=False, reasons=["invalid_json"], parsed=None)

    if not isinstance(parsed, dict) or not isinstance(parsed.get("answer"), str) \
            or not isinstance(parsed.get("citations"), list):
        reasons.append("schema_mismatch")

    # 2. blocked patterns / leaked secrets / PII (scan the whole payload text)
    for label, rx in _BLOCKED:
        if rx.search(text):
            reasons.append(f"blocked:{label}")

    # 3. TODO(learner): groundedness. Signature suggestion:
    #        def is_grounded(answer: str, retrieved_docs: list, cited_ids: list) -> bool
    #    Verify (a) every cited id exists in retrieved_docs, and (b) the answer's
    #    claims are supported by the cited text (substring/entailment or an
    #    LLM-as-judge call — see evals.py::llm_judge). Append "ungrounded" to reasons
    #    when it fails, and thread the retrieved docs in from agent.py.

    return GuardrailResult(ok=not reasons, reasons=reasons, parsed=parsed)
