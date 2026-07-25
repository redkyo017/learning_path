Put your filled-in 7-step design here (see `reference/design-method.md`).

Today: the Order → Payment → Inventory saga + the outbox reliability decision.
Include the tradeoff table (orchestrated saga+outbox vs choreographed vs direct
publish vs 2PC) and the "how it breaks" red-team (failed compensation, poison
message, orchestrator crash, duplicate publish).
