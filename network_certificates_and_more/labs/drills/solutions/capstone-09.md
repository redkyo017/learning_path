# Capstone 09 — Solution: nothing was ever asked, so nothing could be caught

## Hint ladder

1. **Nudge:** revocation is not one of Day 1's four checks — go back to
   Day 5's theory section and reread the sentence that says so explicitly.
   Ask what mechanism *would* have to fire for a compromised-key incident
   to actually be caught.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox openssl s_client -connect 127.0.0.1:8600 \
       -servername example.local -status </dev/null 2>/dev/null | grep -A3 "OCSP"
   ```
3. **Partial diagnosis:** the OCSP response line says "no response sent."
   The handshake still reports "Verify return code: 0 (ok)." Those two
   facts together are the entire finding.

## Full walkthrough

```
OCSP response: no response sent
Verify return code: 0 (ok)
```

Walk this through Day 5's theory framing directly: none of Day 1's four
checks were ever designed to catch "the CA (or the key holder) changed
its mind about this cert after issuing it" — that is what revocation
covers, and it is a genuinely separate mechanism layered *on top of* the
four checks, not one of them. `Verify return code: 0` only tells you that
checks 1, 2, and 4 (chain, dates, trust anchor) passed against the
presented certificate — it says nothing about revocation status,
because nothing in this handshake ever asked.

`-status` is the client-side flag that requests a **stapled** OCSP
response from the server as part of the handshake (Day 5's "OCSP
stapling" theory). `no response sent` means the server never attached
one — `openssl s_server` here was started with no `-status_file` at all,
so there is nothing to staple. Without a staple, the *only* remaining way
a client could learn about a revocation is to make its own live OCSP
query or fetch a CRL — and, per Day 5's theory, real browsers have
historically **soft-failed** (proceeded anyway) when that live check is
slow, unreachable, or simply never attempted, which is exactly what
happened here: nothing was ever configured to ask, so nothing was ever
answered, and the connection succeeds looking identical to a genuinely
clean one.

This capstone deliberately does not simulate an actual revoked
certificate — there is no real OCSP responder anywhere in this lab's
infrastructure to revoke anything against. What it isolates is the
**blind spot itself**: a stated security goal ("prove a compromised-key
incident would be caught before `notAfter`") that this specific setup
categorically cannot deliver on, regardless of whether a real incident
ever occurs, because nothing in the handshake was ever wired to check for
one.

**Fix:** enable OCSP stapling on the real server
(`ssl_stapling on; ssl_stapling_verify on;` in nginx, backed by a
`ssl_trusted_certificate` pointing at the issuer chain) so the server
itself periodically fetches and attaches a signed status statement, and
configure clients/browsers to actually reject a handshake when a stapled
response is expected but absent or says `revoked` — "OCSP configured" and
"OCSP enforced" are two different settings, and only the second one
closes this gap.

## Lesson

Passing all four checks and having zero revocation exposure are two
completely independent facts about a connection. Never treat "the
handshake succeeded" as evidence that a compromised-key or revoked-cert
scenario would have been caught — check specifically whether OCSP
stapling is configured and enforced, because absent that, revocation is
not a safety net that's merely slow; it's a safety net that was never
actually deployed.
