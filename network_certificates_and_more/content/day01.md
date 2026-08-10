# Day 1 — How Trust Actually Works: The Verification Mental Model

Read this before starting the lab. Budget: ~3 hours (60–75 min theory/reading,
~90 min guided lab, ~30 min exercises + drills).

---

## Learning objectives

By the end of today you should be able to:
- State, unaided, the definition: *a certificate is a signed statement binding
  a name to a public key.*
- Recite the four-check verification order — **signature chain → validity
  dates → name match → trust anchor** — and explain what each check actually
  tests, in plain English.
- Explain what a cryptographic hash is and why signing operates on a hash of
  a message rather than the message itself.
- State precisely what "signing" and "verifying" mean: the private key signs,
  the public key verifies — and explain why that direction can't be reversed.
- Hand-sign a file with `openssl dgst -sign` and verify it with
  `openssl dgst -verify`, and predict the output when something about the
  setup is wrong.
- Read an `openssl x509 -text` dump and map each field to one of the four
  checks.

---

## The verification mental model

Before touching a single certificate, internalize one sentence. Every later
day in this course — CA-building, the TLS handshake, mutual TLS, ACME,
attacking rogue CAs — is a variation on this sentence, so get it exactly
right now:

> **A certificate is a signed statement binding a name to a public key.**

That's it. Strip away the ASN.1 encoding, the field names, the CLI flags —
a certificate says "the public key attached to this document belongs to
*this name*," and it is signed by someone (an issuer) who is vouching for
that binding.

Verification, then, is the process of deciding whether to believe that
statement. Every verifier on earth — a browser, curl, an nginx client-cert
check, an SSH client checking a host key, a JWT library — runs some version
of the same four checks, always **in this order**:

1. **Signature chain** — Is the signature on this certificate mathematically
   valid for the claimed issuer's public key, and (if the issuer is itself
   a certificate rather than a directly-trusted anchor) does *its* signature
   check out against *its* issuer, all the way up? This check answers: "was
   this document actually produced by whoever it claims signed it, unaltered,
   link by link?"
2. **Validity dates** — Is the current time within the `notBefore`/`notAfter`
   window, for *every* certificate in the chain, not just the leaf? This
   check answers: "is this vouching still in effect right now?"
3. **Name match** — Does the name you're trying to reach (a hostname, an
   email address, a client identity) match one of the names the certificate
   actually claims (the Subject Alternative Names, not the deprecated
   Common Name)? This check answers: "is this statement even about the
   thing I'm talking to?"
4. **Trust anchor** — Does the chain terminate at a root certificate that
   *you* have already decided, out of band, to trust (something sitting in
   your OS/browser/language trust store)? This check answers: "do I actually
   trust whoever is at the top of this chain, or is it just an internally
   consistent story someone made up?"

The order matters, and check 1 and check 4 are the two that get confused
most often, so hold this distinction firmly: **check 1 asks whether the
chain is *internally consistent*** (every signature really was produced by
the key it claims); **check 4 asks whether the *top* of that chain is
someone you actually trust.** A chain can pass check 1 perfectly — every
signature verifies, cleanly, with no tampering anywhere — and still fail
check 4, because anyone can generate a private key, self-sign a root, and
build a perfectly self-consistent chain underneath it. Internal consistency
is not the same as trustworthiness. That gap is exactly what Day 6's
rogue-CA attack exploits, and exactly what today's theory is building you
toward being able to explain.

Write the four-check order down somewhere you'll see it again. You will use
this exact phrasing for the rest of the course.

---

## Theory: hashing, keypairs, and what "signing" actually means

You do not need to derive RSA to operate TLS at a professional level. You
need *operational* understanding: what each primitive does, what it
guarantees, and what breaks when a step is skipped or done wrong. That's the
depth target for everything below.

### Cryptographic hashing

A cryptographic hash function takes input of any size and produces a
fixed-length output (a "digest") with three properties that matter here:

- **Deterministic** — the same input always produces the same digest.
- **One-way** — given a digest, you cannot feasibly work backward to find an
  input that produces it.
- **Avalanche effect** — changing even one bit of the input produces a
  completely different, unpredictable digest. There's no "close" — a digest
  is either an exact match or it tells you nothing about how similar the
  inputs were.

SHA-256 (used throughout this course) always produces a 256-bit (32-byte)
digest, whether you hash one byte or one gigabyte. That fixed size is why
hashing exists in the signing pipeline at all: asymmetric signing operations
are computationally expensive and mathematically defined over fixed-size
blocks. Instead of signing an entire (possibly huge) message directly, you
hash the message down to a small fixed-size fingerprint and sign *that*.
Verifying later means: re-hash the message yourself, and check that the
signature corresponds to a digest that matches what you just computed. If a
single byte of the original message changed, your freshly computed digest
is completely different from the one that was signed — verification fails,
deterministically, every time. This is the mechanism behind Exercise 1
below and behind drill-02.

### Public/private keypairs

Asymmetric cryptography generates two mathematically linked keys — a
private key and a public key — with a specific property: an operation done
with one key can only be undone or checked with the *other* key, and it is
computationally infeasible to derive the private key from the public key
(that infeasibility is the entire security foundation; for RSA it rests on
the difficulty of factoring the product of two large primes, but you do not
need the number theory to operate this course — you need to trust, as the
entire internet does, that this asymmetry holds).

The private key is kept secret by its owner. The public key is, by design,
shared freely — that's the point of the name.

### Digital signatures: signing vs. verifying

A digital signature over a message is produced like this:

1. Hash the message (see above) to get a fixed-size digest.
2. Run that digest through a mathematical operation that only the holder of
   the **private key** can perform correctly. The result is the signature.

Verifying is the mirror operation:

1. Independently hash the same message (the verifier does this themselves —
   they don't trust a digest the signer hands them).
2. Use the **public key** to check that the signature is consistent with
   that freshly computed digest.

The critical, precise fact to hold onto — this is the fact every later day
assumes you already know cold:

> **The private key signs. The public key verifies.** Signing requires the
> secret; verifying requires only the (freely shared) public counterpart.
> This is why a signature is meaningful proof: only the private key holder
> could have produced it, but *anyone* holding the public key can check that
> claim without ever touching the secret.

This is also why the direction can't be reversed. If the public key could
*produce* valid signatures, anyone could forge one, and the entire scheme
would be worthless. The asymmetry — one key locks, the other unlocks, and
never the other way — is the whole point.

### From "sign a file" to "this is a certificate"

Once signing and verifying make sense for an arbitrary file, a certificate
is a small conceptual step away: a certificate is a structured document
containing (among other fields) a subject name and a subject's public key,
and the **issuer's private key signs the whole document**. Anyone holding
the issuer's public key can verify that the issuer really did vouch for that
name-to-key binding — exactly the sign/verify mechanics above, just applied
to a specific, standardized document (X.509) instead of an arbitrary
message. Today's lab does both: raw sign/verify on a plain file, then
reading a real certificate and mapping its fields onto the four checks.

---

## Guided lab

All commands run through the `toolbox` container built in the lab
infrastructure setup — never against the host's `openssl` (macOS ships
LibreSSL, which diverges from real OpenSSL in ways that will misinform later
days). Run every command from `labs/`:

```
docker compose run --rm toolbox <command>
```

### Part A — Hand-sign and verify a file

This is the sign/verify mechanic from the theory section above, done by
hand, with no certificates involved yet — just a raw keypair, a message, and
a signature.

```bash
# Generate a private key and derive its public key
docker compose run --rm toolbox openssl genrsa -out /work/tmp/priv.pem 2048
docker compose run --rm toolbox openssl rsa -in /work/tmp/priv.pem -pubout -out /work/tmp/pub.pem

# Create a message and sign it with the PRIVATE key
docker compose run --rm toolbox bash -c 'echo "hello trust" > /work/tmp/msg.txt'
docker compose run --rm toolbox openssl dgst -sha256 -sign /work/tmp/priv.pem \
    -out /work/tmp/msg.sig /work/tmp/msg.txt

# Verify the signature with the PUBLIC key
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/tmp/pub.pem \
    -signature /work/tmp/msg.sig /work/tmp/msg.txt
# Expected: Verified OK
```

Note `mkdir -p tmp` first if `/work/tmp` doesn't exist yet on your host —
the container writes through the bind mount, so files land in `labs/tmp/`.

Stop and confirm you can narrate what just happened without looking back at
the theory section: which key produced `msg.sig`? Which key checked it? What
would you expect if you ran the verify command against a *different*
message than the one you signed? (You'll test that directly in Exercise 1.)

### Part B — Dissect a real certificate

The certificate at `ca/intermediate/certs/example.local.cert.pem` only
exists after you run Day 2's CA-issuing script — you haven't built that yet.
For today, use the offline sample shipped for exactly this purpose:
`labs/samples/sample.local.cert.pem`. (Once you *have* run Day 2, the same
command works unchanged against the real issued cert — just swap the path.)

```bash
docker compose run --rm toolbox openssl x509 -in /work/samples/sample.local.cert.pem -noout -text
```

Walk the output and map each field to one of the four checks:

| Field in the output | Maps to check | What it's for |
|---|---|---|
| `Signature Algorithm` (both occurrences) + the trailing signature bytes | 1. Signature chain | The actual cryptographic proof that the issuer signed this document — this is what an `openssl verify` call mathematically checks |
| `Issuer` | 1. Signature chain / 4. Trust anchor | Names *who* signed this cert. Check 1 asks "does the math check out against this issuer's key?"; check 4 asks "do I trust whoever is ultimately at the top of the chain this issuer belongs to?" |
| `Validity` → `Not Before` / `Not After` | 2. Validity dates | The window during which this vouching is considered in effect |
| `Subject` | — (context only) | The entity the cert is issued to. Note: **do not use this for name matching** — modern verifiers ignore the Subject CN for hostname checks |
| `X509v3 Subject Alternative Name` | 3. Name match | The actual list of names/IPs a verifier checks the connection target against — this is what matters, not the Subject CN |
| `X509v3 Basic Constraints`, `Key Usage`, `Extended Key Usage` | — (policy, not one of the four) | Constrains what this cert is *allowed* to be used for (e.g. `CA:FALSE` means it can't sign other certs; `TLS Web Server Authentication` means it's scoped to server auth) — Day 2 covers these in depth |

Important caveat about the sample: its `Issuer` field reads
`TLS Mastery Intermediate CA` for illustration, but that intermediate
doesn't exist anywhere in your lab yet — you haven't built it. Don't run
`openssl verify` against this sample expecting it to succeed; there's no
matching CA certificate for it to chain to. That full chain-verification
experience — watching a cert actually pass all four checks against a CA
you built yourself — is Day 2's guided lab. Today's job is purely reading
and mapping fields, not full verification.

---

## Exercises

Answer these before moving to the drills. Each has a hint ladder — try
without looking, then peel back one hint at a time.

### Exercise 1

**You changed one byte of `msg.txt` after signing it. Predict the `-verify`
output, and say which of the four checks this maps to.**

<details>
<summary>Hints</summary>

- Nudge: think about what verifying actually recomputes from scratch.
- Tool to run: reproduce it — `echo "hello trusZ" > /work/tmp/msg.txt` then
  re-run the same `dgst -verify` command against the *original* `msg.sig`.
- Partial diagnosis: the verifier doesn't compare bytes of `msg.txt` against
  anything stored in `msg.sig`. It hashes the current file content itself.

</details>

<details>
<summary>Solution</summary>

Output: `Verification Failure`, exit code `1`.

The signature was produced over the SHA-256 digest of the *original*
`msg.txt` content. Because of the avalanche effect, changing even one byte
produces a completely different digest when the verifier re-hashes the
(now-modified) file. The public key check then fails, because the signature
mathematically corresponds to the old digest, not the new one — there is no
partial match; a digest is either an exact match or meaningless.

This maps to **check 1: signature chain**. Concretely, this check is asking
"was this exact content actually vouched for by the signer, unaltered?" —
tampering with the content after signing is precisely what this check
exists to catch. It has nothing to do with dates, names, or trust anchors;
those checks never even get evaluated for a raw signature like this one
(they're certificate-specific), but the *mechanism* — hash, then check the
signature against that hash — is identical to what check 1 does for a
certificate's signature.

</details>

### Exercise 2

**You're given two `openssl x509 -text` dumps for two different certificates
claiming to identify the same server. Cert A has `Issuer: CN=Acme Corp Root
CA` and a SAN of `DNS:app.acme.test`. Cert B has `Issuer: CN=app.acme.test`
(self-signed — Issuer equals Subject) and the same SAN. Your trust store
contains a root for "Acme Corp Root CA" and nothing else. Which cert passes
all four checks, and which specific check does the other one fail?**

<details>
<summary>Hints</summary>

- Nudge: both certs might have perfectly valid signatures, current dates,
  and correct SANs. Where do they actually differ?
- Tool to run: nothing to run here — this is a reasoning exercise about
  chain endpoints. Sketch each cert's chain on paper: what's at the top?
- Partial diagnosis: self-signed doesn't mean untrustworthy by definition —
  it means the chain terminates at that cert itself. The question is
  whether *that specific* self-signed cert is sitting in your trust store.

</details>

<details>
<summary>Solution</summary>

Cert A can pass all four checks: signature chain checks out against the
Acme Corp Root CA's key, dates are (assumed) valid, SAN matches
`app.acme.test`, and the chain terminates at a root that *is* in your trust
store — check 4 passes.

Cert B fails **check 4: trust anchor**, and only that check. Its signature
chain is internally perfectly consistent (a self-signed cert's signature
validates against its own embedded public key — that's what self-signed
means), dates could be fine, and the SAN matches. But the entity at the top
of Cert B's chain — itself — is not present in your trust store. Nothing is
mathematically wrong with Cert B; it's simply vouching for itself, and you
haven't decided to trust that particular self-vouching entity. This is
exactly the check-1-vs-check-4 distinction from the mental model section:
internal consistency (check 1) is not the same as being someone you trust
(check 4).

</details>

### Exercise 3

**A certificate's signature verifies cleanly, its dates are valid today,
but its SAN list is `DNS:www.example.com` only. You connect to
`api.example.com` and present this cert. Which check fails, and what would
this typically look like as a curl or browser error?**

<details>
<summary>Hints</summary>

- Nudge: this has nothing to do with the cryptographic math at all.
- Tool to run: `openssl x509 -in <cert> -noout -text | grep -A2
  "Subject Alternative Name"` — practice extracting just the SAN block from
  a larger dump.
- Partial diagnosis: the cert is completely legitimate and correctly signed
  *for a different name* than the one you're trying to reach.

</details>

<details>
<summary>Solution</summary>

**Check 3: name match** fails. The certificate may be entirely valid,
correctly signed by a trusted CA, within its validity window — but it
simply was never issued for `api.example.com`. A verifier explicitly checks
the connection target's hostname against the SAN list (never the Subject
CN, which is deprecated for this purpose and ignored by modern browsers and
curl), and `api.example.com` isn't in `{www.example.com}`.

In curl this surfaces as something like:
`SSL: no alternative certificate subject name matches target host name
'api.example.com'`. In a browser it's typically presented as
`NET::ERR_CERT_COMMON_NAME_INVALID` or an equivalent "this certificate is
not valid for this site" interstitial. The other three checks all passed —
this is purely a name-match failure, and it's one of the most common
real-world cert errors (usually caused by a SAN list that's missing a SAN
someone forgot to add, e.g. after adding a new subdomain).

</details>

### Exercise 4

**A chain is built: leaf signed by an intermediate, intermediate signed by a
root. Every signature in the chain mathematically checks out — you verified
this yourself with `openssl verify`. Every date is valid. The SAN matches.
But the root at the top of the chain is not present in your trust store —
it's some CA you've never heard of. Does verification succeed? Which check
fails and why isn't this the same failure as an ordinary tampered
signature?**

<details>
<summary>Hints</summary>

- Nudge: re-read the check-1-vs-check-4 paragraph in the mental model
  section above.
- Tool to run: nothing new to run — this is the theory's central
  distinction, made concrete.
- Partial diagnosis: "the math checks out" and "I trust this" are two
  separate questions. This exercise is deliberately testing whether you
  can tell them apart.

</details>

<details>
<summary>Solution</summary>

Verification does **not** succeed overall, even though checks 1–3 all
individually passed. **Check 4: trust anchor** fails.

This is a different *kind* of failure than a tampered signature (which
fails check 1, because the math itself doesn't check out — the signature
doesn't correspond to the claimed key/content). Here, the math is flawless
at every link: leaf→intermediate verifies, intermediate→root verifies. The
chain is internally airtight. It fails purely because *you* never decided
to trust the root sitting at the top of it. Anyone can generate a keypair,
self-sign a root cert, and build a perfectly self-consistent intermediate
and leaf underneath it — internal consistency is cheap and available to
anyone, including an attacker. Trust has to come from somewhere outside the
chain itself: your OS, browser, or language runtime's curated trust store,
which is a human/organizational decision about which root operators are
believed to follow real identity-vetting practices before they issue
certificates. This exact gap — a mathematically perfect chain rooted in
something nobody actually decided to trust — is what Day 6's rogue-CA
attack lab walks you through building and then exploiting.

</details>

---

## Drills

Four drills are waiting for you in `labs/drills/drill-01/` through
`drill-04/`, each targeting a failure in the signing model you just learned:

- **drill-01** — verifying a signature with the wrong public key
- **drill-02** — verifying a message that was tampered with after signing
- **drill-03** — a digest-algorithm mismatch between signing and verifying
- **drill-04** — reading a certificate and spotting an expired `notAfter`

Each drill directory has a `SYMPTOM.md` stating only the observed output and
the command that produced it — no diagnosis. Work the drill yourself first.
Full graduated-hint walkthroughs live in `labs/drills/solutions/drill-NN.md`
if you get stuck; resist opening them until you've actually run something.

## Journal template

```
### Day 1 — How trust actually works
Key concept in my own words: ...
The four-check order, from memory (no peeking): ...
What confused me and how I resolved it: ...
Drill I found hardest and what finally gave it away: ...
```
