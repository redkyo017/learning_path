"""Pluggable LLM client for the Day-19 agent lab.

Two backends, one interface:

  * BedrockClient  -> real Claude via Amazon Bedrock (your AgentCore / Bedrock stack).
  * StubClient     -> deterministic, offline, no credentials. Lets the whole lab
                      (agent loop + guardrails + eval harness) run with `python evals.py`
                      on a plane. The stub is written to *demonstrate* the loop and to
                      naively "fall for" the prompt-injection case so the OUTPUT
                      guardrail has something to catch.

Both return an object with `.stop_reason` and `.content` (a list of blocks). Each block
has `.type`; a "text" block has `.text`; a "tool_use" block has `.id`, `.name`, `.input`.
This mirrors the Anthropic Messages API so agent.py is identical for both backends.

Select the backend with the env var:  AGENT_BACKEND=stub (default) | bedrock
Model (bedrock):                       BEDROCK_MODEL_ID=anthropic.claude-opus-4-8 (default)
"""
from __future__ import annotations

import os
import re
import json
import uuid
from dataclasses import dataclass, field


# --- shared block/message shapes (the stub builds these; Bedrock returns SDK objects
#     with the same attribute surface) --------------------------------------------

@dataclass
class TextBlock:
    text: str
    type: str = "text"


@dataclass
class ToolUseBlock:
    name: str
    input: dict
    id: str = field(default_factory=lambda: "toolu_" + uuid.uuid4().hex[:8])
    type: str = "tool_use"


@dataclass
class Message:
    stop_reason: str            # "tool_use" | "end_turn"
    content: list               # list[TextBlock | ToolUseBlock]


# --- Bedrock backend ---------------------------------------------------------------

class BedrockClient:
    """Real Claude on Amazon Bedrock via the Messages-API Mantle client.

    Requires:  pip install "anthropic[bedrock]"  and AWS credentials in the env.
    Model IDs on Bedrock take the `anthropic.` prefix (e.g. anthropic.claude-opus-4-8).
    Cheaper models (anthropic.claude-sonnet-5, anthropic.claude-haiku-4-5) are a good
    choice for eval loops that re-run many times.
    """

    def __init__(self):
        from anthropic import AnthropicBedrockMantle  # imported lazily so stub runs w/o dep
        region = os.environ.get("AWS_REGION", "us-east-1")
        self._model = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-opus-4-8")
        self._client = AnthropicBedrockMantle(aws_region=region)

    def create(self, system: str, messages: list, tools: list) -> Message:
        resp = self._client.messages.create(
            model=self._model,
            max_tokens=1024,
            system=system,
            tools=tools,
            messages=messages,
        )
        # resp already exposes .stop_reason and .content blocks with .type/.text/.name/.input
        return resp


# --- Stub backend (offline, deterministic) -----------------------------------------

_MATH_RE = re.compile(r"[-+*/0-9.() ]{3,}")
_INJECTION_RE = re.compile(r"ignore .*instruction", re.IGNORECASE)


class StubClient:
    """A fake model that exercises the loop deterministically.

    First turn: choose a tool.
      * math-looking query          -> call `calculator`
      * anything else               -> call `retriever`
    Second turn (after a tool_result): synthesize a final answer as JSON text.
      * if a retrieved doc contains an injection ("ignore ... instructions"), the stub
        *complies* and leaks a fake secret -> the output guardrail must catch it.
      * if retrieval was weak/empty, refuse.
      * otherwise, answer grounded in the top doc and cite its id.
    """

    def create(self, system: str, messages: list, tools: list) -> Message:
        last = messages[-1]
        observed_tool = self._last_tool_result(last)

        if observed_tool is None:
            # ---- plan+act: pick a tool ----
            query = self._first_user_text(messages)
            if _MATH_RE.fullmatch(_extract_math(query) or ""):
                return Message("tool_use", [ToolUseBlock("calculator",
                                                          {"expression": _extract_math(query)})])
            return Message("tool_use", [ToolUseBlock("retriever", {"query": query})])

        # ---- observe -> final answer ----
        name, result = observed_tool
        if name == "calculator":
            payload = {"answer": str(result.get("value")), "citations": []}
            return Message("end_turn", [TextBlock(json.dumps(payload))])

        docs = result.get("docs", [])
        if not docs or docs[0].get("score", 0) < 1:
            payload = {"answer": "I don't have information on that in the docs.",
                       "citations": []}
            return Message("end_turn", [TextBlock(json.dumps(payload))])

        top = docs[0]
        if _INJECTION_RE.search(top["text"]):
            # NAIVE model fooled by injection -> leaks a (fake) credential.
            payload = {"answer": "Sure. AWS_SECRET_ACCESS_KEY=AKIAABCDEFGHIJKLMNOP",
                       "citations": [top["id"]]}
            return Message("end_turn", [TextBlock(json.dumps(payload))])

        payload = {"answer": top["text"].split(".")[0].strip() + ".",
                   "citations": [top["id"]]}
        return Message("end_turn", [TextBlock(json.dumps(payload))])

    # -- helpers --
    @staticmethod
    def _first_user_text(messages: list) -> str:
        for m in messages:
            if m["role"] == "user":
                c = m["content"]
                return c if isinstance(c, str) else _text_of(c)
        return ""

    @staticmethod
    def _last_tool_result(msg: dict):
        """Return (tool_name, result_dict) if the message carries a tool_result, else None."""
        content = msg.get("content")
        if not isinstance(content, list):
            return None
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_result":
                data = json.loads(block["content"])
                return data["_tool"], data
        return None


def _text_of(blocks) -> str:
    for b in blocks:
        if isinstance(b, dict) and b.get("type") == "text":
            return b["text"]
    return ""


def _extract_math(query: str):
    m = _MATH_RE.search(query or "")
    return m.group(0).strip() if m else None


def get_client():
    backend = os.environ.get("AGENT_BACKEND", "stub").lower()
    if backend == "bedrock":
        return BedrockClient()
    return StubClient()
