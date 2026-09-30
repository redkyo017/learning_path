# Capstone 09 — Solution: nothing was ever asked, so nothing could be caught

## Hint ladder

1. **Nudge:** revocation is not one of Day 1's four checks — go back to
   Day 5's theory section and reread the sentence that says so explicitly.
   Ask what mechanism *would* have to fire for a compromised-key incident
   to actually be caught.
2. **Tool to run:** nothing new — re-read the repro's two lines, then
   Day 5's "What the industry actually does now" list. Where does a 2026
   browser actually get revocation data from?
3. **Partial diagnosis:** the OCSP line says "no response sent," yet
   "Verify return code: 0 (ok)." The question isn't how to make a staple
   appear. It's whether the handshake was ever the place revocation shows
   up.

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
response (Day 5's stapling theory). `no response sent` means the server
attached none — `openssl s_server` here got no `-status_file`, and this
private CA runs no OCSP responder anyway. The handshake succeeds looking
identical to a clean one.

It's tempting to conclude "the fix is stapling." In 2026 that's the wrong
conclusion, for three reasons (Day 5's revocation section):

- **Stapling can't catch the real attack.** Someone holding the stolen key
  runs their own server, and simply doesn't staple. Without the rarely
  used Must-Staple extension, a missing staple is soft-fail.
- **Public OCSP is going away.** OCSP is optional for public CAs since
  2024; Let's Encrypt shut its responders down in August 2025. Stapling an
  LE certificate does nothing.
- **Browsers don't ask the handshake anyway.** Firefox checks its pushed
  CRLite data; Chrome checks its pushed CRLSets. Both are built from the
  CAs' CRLs, not from staples.

So `no response sent` isn't the root cause. The real finding is that this
check looks in the wrong place: revocation status in 2026 lives in the
CA's CRL and in browser-pushed data, and the exposure window is bounded
by `notAfter`. This capstone doesn't simulate a revoked cert. It isolates
the false assumption that a handshake is where revocation "shows up."

**Fix — what a 2026 operator actually does after a key compromise:**

1. **Revoke through the CA** (for this lab: `openssl ca -revoke` against
   the intermediate, then publish a fresh CRL with `openssl ca -gencrl`;
   for a public cert: the ACME `revokeCert` call, reason
   `keyCompromise`). The serial lands in the CA's CRL, which is what
   CRLite/CRLSets are built from.
2. **Rotate the key.** Issue a new certificate on a **new** key pair and
   deploy it. Reusing the compromised key makes the new cert compromised
   too.
3. **Rely on short lifetimes for the tail.** Whatever clients miss the
   revocation, the stolen cert still dies at `notAfter`. That's why
   lifetimes are shrinking (200 days now, 47 by 2029). Automate renewal
   so a short lifetime costs nothing.

For clients you control (internal services on a private CA like this
one), you can go further and make them check your CRL — e.g.
`openssl verify -crl_check -CRLfile ...`, or nginx's `ssl_crl` for mTLS
client certs.

## Lesson

Passing all four checks and having zero revocation exposure are two
independent facts. Never treat "the handshake succeeded" as evidence a
compromised key would be caught. But don't answer that with "turn on
stapling" either: the 2026 answer is revoke at the CA (so the serial
reaches the CRL and browser-pushed data), rotate the key, and keep
lifetimes short enough that anything missed expires soon.
