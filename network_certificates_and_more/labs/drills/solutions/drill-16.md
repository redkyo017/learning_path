# Drill 16 — Solution: missing client key

## Hint ladder

1. **Nudge:** read the curl error text literally before assuming it's a
   network or nginx problem. Did this request even leave the container?
2. **Tool to run:** check what actually exists in the drill directory:
   ```
   docker compose run --rm toolbox ls -la /work/drills/drill-16/
   ```
3. **Partial diagnosis:** curl exit code `58` is `CURLE_SSL_CERTPROBLEM` —
   "problem with the local client certificate," which curl raises while
   assembling the TLS client identity *before* it ever opens a connection.
   The error text names the exact file path it couldn't load.

## Full walkthrough

```
docker compose run --rm toolbox ls -la /work/drills/drill-16/
# client01.cert.pem
# SYMPTOM.md
```

There is no `client01.key.pem` anywhere in this directory — the `--key`
flag in the command points at a file that simply doesn't exist. curl's error
58 fires at the point where it tries to load the private key you told it to
pair with `--cert`, and because that file isn't there, curl aborts with:

```
curl: (58) unable to set private key file: '/work/drills/drill-16/client01.key.pem' type PEM
```

This never reaches nginx, never touches the `certlab` network, and has
nothing to do with the CA, the chain, or dates. It's a purely local failure:
curl cannot construct the client side of the mTLS handshake at all without
the private key, because the point of presenting a certificate during
mTLS is proving *possession of the private key that matches the public key
the certificate vouches for* — that's the `CertificateVerify` message in the
handshake, and it's produced with the private key, the same sign/verify
mechanics from Day 1 (the private key signs; the public key — embedded in
the cert — only lets the other side check that signature). A cert with no
key behind it is exactly like an ID card you can't actually use: someone can
look at it, but you can't produce the signature that proves it's really
yours.

**Fix:** get the certificate's actual matching key, not just the
certificate. If this is genuinely your own `client01` identity, its real key
lives at `ca/intermediate/private/client01.key.pem` (issued alongside the
cert by `ca/issue-server-cert.sh client01 client01`) — never split a cert
from its key when handing it to someone, and never accept just the `.cert.pem`
half of an identity from a teammate and assume you can "figure out" or reuse
some other key for it; a certificate only vouches for the *one specific*
public key it was issued with.

## Lesson

A client certificate without its matching private key is inert for mTLS —
the failure happens entirely on your own machine, before any network
traffic or server-side check is even attempted, because the private key is
what proves the certificate is actually yours to present.
