# Capstone — Self-red-team + tradeoff table

Attack your own design. Answer "what happens?" for **every** dimension. If you can't
answer one, that's your next design task — and a `BACKLOG.md` entry.

## How it breaks

| Dimension | What happens? | What absorbs / bounds it? | Residual risk |
|-----------|---------------|---------------------------|---------------|
| **10× load** — first bottleneck? | | | |
| **Region / cell loss** — blast radius? failover? | | | |
| **Dependency down or slow** — cascade or degrade? | | | |
| **Bad deploy** — blast radius? rollback path? | | | |
| **Hot partition / hot key** — one tenant sinks all? | | | |
| **Data loss / duplicate delivery** — correct under retries? | | | |

## Tradeoff table — my single most contested decision

Decision: ____________________________________________

| Option | NFR-1 (____) | NFR-2 (____) | NFR-3 (____) | Cost | Complexity |
|--------|--------------|--------------|--------------|------|------------|
| A (chosen) | | | | | |
| B | | | | | |
| C | | | | | |

**Chosen: ____** — one-sentence why over the runner-up:
> "For our top NFR of ______, ____ gives us ______ while ____ would have cost us ______."

## Gaps surfaced (→ BACKLOG.md)

-
-
