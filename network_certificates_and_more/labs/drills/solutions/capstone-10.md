# Capstone 10 — Solution: pinning doesn't know the difference between an attacker and a renewal

## Hint ladder

1. **Nudge:** nobody attacked anything here — "ops did a routine
   certificate renewal" is stated as fact. So what, specifically, changed
   between the pin being set and the pin failing?
2. **Tool to run:** compare the pinned connection against the same
   connection with the pin removed.
   ```
   docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
       --connect-to secure-api.local:8600:127.0.0.1:8600 https://secure-api.local:8600/
   ```
3. **Partial diagnosis:** without `--pinnedpubkey`, the exact same
   connection succeeds cleanly. The certificate itself was never the
   problem — only the specific key the dashboard was told to expect was.

## Full walkthrough

Dropping `--pinnedpubkey` entirely and connecting the same way every other
capstone and every prior day has — `--cacert ca-chain.cert.pem` only —
succeeds without complaint. That immediately isolates the failure to
pinning specifically: checks 1 through 4 all pass on the *current*
`secure-api.local` certificate exactly as they would on any freshly
issued, correctly signed, currently valid, correctly named cert from your
real CA.

`curl: (90) SSL: public key does not match pinned public key!` is a
distinct failure mode from every other capstone in this gauntlet — it is
**not** one of Day 1's four checks, and it doesn't map onto any of them.
Public-key pinning is a check curl runs *in addition to*, and
independently of, the four-check model: "does the leaf certificate's
public key match this one specific key I already know about" — a
question that has nothing to do with signatures, dates, names, or trust
anchors, and everything to do with a single specific keypair.

Trace what actually happened: the dashboard recorded a pin against
`secure-api.local`'s public key *at the time it was first set up*. Ops
then ran `ca/issue-server-cert.sh secure-api.local secure-api.local`
again for a routine renewal — and, per that script's own header comment,
**every invocation generates a brand-new RSA keypair**, even for the same
CN. The new certificate is issued by the same CA, carries the same name,
and is every bit as trustworthy as the old one — but it is backed by a
*completely different key*, and the dashboard's pin was never updated to
match. The pin isn't wrong about anything; it's doing exactly what
pinning is designed to do (reject any key that isn't the one specific key
it was told to expect) — it simply was never told about the rotation.

**Fix:** update the dashboard's pin to the new key's hash
(`openssl x509 -pubkey -noout | openssl pkey -pubin -outform der |
openssl dgst -sha256 -binary | base64`, against the *current* cert) as
part of the renewal process itself — and, going forward, pin the
*upcoming* key in advance of a planned rotation (a "backup pin"), not
only the currently active one, so a routine renewal never has to be a
synchronized, all-at-once cutover across every pinned client.

## Lesson

This is exactly today's theory section's brittleness warning, reproduced
end to end: pinning collapses check 4 into "trust this exact key," which
makes it powerful against a rogue CA (nothing about a trust-store
compromise can forge the *specific key* you pinned) and simultaneously
fragile against your own legitimate key rotations (nothing about pinning
knows the difference between "an attacker's key" and "our own new key
after a renewal" — both are simply "not the pinned key"). Any team that
adopts pinning takes on an operational obligation that ordinary CA-based
trust doesn't have: every planned key rotation must ship updated pins to
every pinned client *before* or *during* the rotation, never after — get
that ordering wrong and you've caused an outage indistinguishable, from
the client's point of view, from a real attack.
