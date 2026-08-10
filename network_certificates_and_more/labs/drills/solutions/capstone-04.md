# Capstone 04 — Solution: a hardened floor with nothing below it to catch a legacy ceiling

## Hint ladder

1. **Nudge:** `unsupported protocol` names nothing about certificates,
   ciphers, or hostnames — this is Day 3's territory, before any
   `Certificate` message is ever sent.
2. **Tool to run:** find each side's actual range.
   ```
   grep -E 'no_ssl3|no_tls1|no_tls1_1|no_tls1_2' /work/drills/capstone/capstone-04/repro.sh
   grep -- '--tls-max' /work/drills/capstone/capstone-04/repro.sh
   ```
3. **Partial diagnosis:** the server's floor was raised to TLS 1.3 only.
   The client's ceiling is TLS 1.2. Compare the two ranges directly.

## Full walkthrough

The server disabled SSLv3, TLS 1.0, TLS 1.1, **and** TLS 1.2, leaving only
TLS 1.3 — a deliberate "1.3 only" hardening policy. The client capped
itself at `--tls-max 1.2`, meaning its highest offer is TLS 1.2. Sketching
both ranges the way drill-09's solution did:

```
server:  [------------------------- 1.3 ]
client:  [-- 1.0 -- 1.1 -- 1.2 --]
overlap: (none)
```

This is drill-09's exact mechanism, just with the roles reversed: there,
an old server had a *floor* the new client's *ceiling* couldn't clear; here,
a hardened server's *floor* is *above* an old client's *ceiling*. Either
direction produces the identical failure class — the `ClientHello`/
`ServerHello` exchange itself fails to find any mutually acceptable
version, so **no `Certificate` message is ever sent**, and none of Day 1's
four checks get a chance to run at all. The alert is conceptually
`protocol_version` (70); curl surfaces it as exit `35` with the
`unsupported protocol` OpenSSL error text, exactly as Day 3's theory
table predicted.

This scenario is deliberately realistic: "we hardened the server, an old
integration broke" is one of the single most common real-world outcomes
of a TLS-version security policy rollout, and it is very easy to
misdiagnose as a certificate problem if you don't check versions first —
there's no certificate anywhere in this failure to even look at.

**Fix:** either the legacy client needs to be upgraded to actually support
TLS 1.3 (the real fix, since anything capped at 1.2 has weaker
forward-secrecy and encryption guarantees than 1.3 provides), or, if that
integration genuinely cannot be touched yet, the server's hardening policy
needs a temporary, tracked exception lowering its floor back to 1.2 for
just that one caller — never a silent, permanent rollback of the whole
policy for everyone.

## Lesson

"Unsupported protocol" is a version-negotiation failure, full stop — it
happens before certificates enter the picture at all, in either
direction (old client vs. new server, or new client vs. old server).
Tightening a security floor is a real, deliberate tradeoff against
whatever's still calling you from below that floor; a hardening rollout
should audit every current caller's minimum supported version *before*
flipping the floor, not discover the gap from a broken integration
afterward.
