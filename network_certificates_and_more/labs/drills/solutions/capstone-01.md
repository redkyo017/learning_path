# Capstone 01 — Solution: missing intermediate, and a CA file that doesn't cover it either

## Hint ladder

1. **Nudge:** "here's the CA cert" from IT could mean the root, the
   intermediate, or a fullchain — don't assume which one you were handed.
   Separately, ask what the *server* actually sent over the wire.
2. **Tool to run:** look at both ends independently.
   ```
   docker compose run --rm toolbox openssl x509 -in /work/ca/root/certs/ca.cert.pem -noout -subject
   docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/reports.local.cert.pem -noout -issuer
   ```
3. **Partial diagnosis:** the file you were handed is the root, whose
   subject is `TLS Mastery Root CA`. The leaf's issuer is `TLS Mastery
   Intermediate CA` — a *different* certificate that neither the CA file
   you have, nor (because `repro.sh`'s `s_server` was only pointed at the
   single leaf file) the server's own response, ever supplied.

## Full walkthrough

Two independent facts, either one enough on its own to break this:

```
docker compose run --rm toolbox openssl x509 -in /work/ca/root/certs/ca.cert.pem -noout -subject
# subject=CN = TLS Mastery Root CA

docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/reports.local.cert.pem -noout -issuer
# issuer=CN = TLS Mastery Intermediate CA
```

`reports.local` was signed by the **intermediate**, not the root directly —
exactly Day 2's chain-of-trust structure (root → intermediate → leaf). To
walk check 1 all the way up, a verifier needs the intermediate's
certificate somewhere: either the server sends it as part of the chain, or
the verifier's own `--cacert`/`-CAfile` includes it as an extra (untrusted,
but usable-to-complete-the-chain) certificate alongside the trusted root.

Here, **both** of those are missing at once: `repro.sh`'s `openssl
s_server -cert reports.local.cert.pem` was pointed at the bare leaf file
only (no chain concatenation, unlike every prior day's
`cat leaf ca-chain.cert.pem`), so the server never sends the intermediate
over the wire at all; and the `--cacert` you were handed
(`ca/root/certs/ca.cert.pem`) is the root alone, with no intermediate in
it either. curl has the leaf and the root, and nothing that links them —
it cannot even attempt check 1's second hop (intermediate → root),
because the intermediate itself is nowhere in sight. That's precisely
`unable to get local issuer certificate`: not "I don't trust the issuer,"
but "I can't even find a certificate matching the issuer this leaf
claims."

Confirm this is exactly a missing-link problem, not a trust problem, by
handing curl the piece that's missing instead of the root alone:

```
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --connect-to reports.local:8600:127.0.0.1:8600 \
    https://reports.local:8600/
```

`ca-chain.cert.pem` is intermediate + root concatenated — handing curl that
instead succeeds immediately, with the server-side gap (no chain sent)
completely unchanged. The fix in a real deployment is on the **server**
side: always serve leaf + intermediate together (a "fullchain"), exactly
as every prior day's `cat` step built it, so a client only ever needs the
root in its trust store, never the intermediate as a separate hand-off.

## Lesson

"Here's the CA cert" is not a well-formed sentence in a two-tier PKI —
there are at least three different files someone could mean by it (root
alone, intermediate alone, or a concatenated chain), and hostname-only
symptoms like `unable to get local issuer certificate` don't tell you
which piece is actually missing or on which side. Always check both ends
independently: what did the server actually send (`openssl s_client
-showcerts` lists every certificate that arrived), and what does your
trust file actually contain (`openssl x509 -noout -subject` against
each cert in it)? A gap on either side produces the identical symptom.
