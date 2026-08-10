# Day 2 — Become a CA: Building the Chain of Trust

Read this before starting the lab. Budget: ~3 hours (60–75 min
theory/reading, ~90 min guided lab, ~30 min exercises + drills).

---

## Learning objectives

By the end of today you should be able to:
- Explain what a root CA and an intermediate CA each are, and state
  precisely *why* real-world PKI never lets the root sign leaf certificates
  directly.
- Build a root CA, an intermediate CA signed by that root, and a leaf server
  certificate signed by the intermediate — typing the raw `openssl` commands
  yourself, then checking them against the scripts that already do this.
- Name the fields that actually matter for verification (SAN,
  basicConstraints, keyUsage/EKU), state what each one constrains, and
  explain why the Subject CN carries zero weight for hostname matching.
- Wire an issued certificate into a running nginx server and reproduce, on
  purpose, both a failed and a successful `curl` verification against it —
  naming exactly which of Day 1's four checks each result exercises.
- Explain why a SAN set via `openssl req -addext` on a CSR can silently
  fail to appear in the final signed certificate, given how this lab's CA
  config is written.

---

## Mental model: the chain of trust, and why intermediates exist

Yesterday's sentence: **a certificate is a signed statement binding a name
to a public key.** Today you build the thing that *produces* signed
statements — a Certificate Authority — and you'll do it as three separate
entities stacked on top of each other, because that's how every real CA on
the internet is actually built.

- **Root CA.** A self-signed certificate (`Issuer` == `Subject`) whose
  private key is the single most valuable secret in the entire system. This
  is the certificate that has to be sitting in somebody's trust store *out
  of band* — nothing about the root's own document proves it should be
  trusted; trust in it is a decision made outside the cryptography
  entirely. This is check 4's anchor, made concrete.
- **Intermediate CA.** A certificate that is itself signed *by* the root,
  but which is also allowed (via `basicConstraints: CA:TRUE`) to sign
  further certificates. This is the CA that does the actual day-to-day
  issuing.
- **Leaf (end-entity) certificate.** A server or client certificate, signed
  by the intermediate, with `basicConstraints: CA:FALSE` — it cannot sign
  anything else. This is what nginx will present to a browser or `curl`.

**Why not have the root sign leaf certs directly?** Because the root's
private key is the one secret whose compromise is catastrophic and
*global*: if it leaks, every certificate ever issued under it is suspect,
and the only real fix is pulling that root out of every trust store on
earth and starting over. Real CAs respond to this by keeping the root key
almost entirely offline — generated once, used a handful of times to sign
an intermediate, then locked away — and doing all routine issuance with an
intermediate instead. If an *intermediate's* key is ever compromised, the
blast radius is contained: you revoke that one intermediate (and everything
under it), and the root — untouched, still offline — mints a fresh
replacement. This is the entire reason the two-tier structure exists. It is
not ceremony; it is blast-radius containment for the worst secret in the
system.

Notice what this means for verification: checking a leaf certificate is now
**check 1 (signature chain) applied recursively, twice, before check 4 even
gets evaluated**:

1. Does the leaf's signature verify against the intermediate's public key?
2. Does the *intermediate's* signature verify against the root's public
   key?
3. Is that root — the thing sitting at the top, self-signed — actually in
   the verifier's trust store? (Check 4.)

Every additional link in a chain is just check 1, run again, one level up.
The chain only terminates — and only becomes trustworthy — at check 4. A
chain of any length that is internally perfect but rooted in something
nobody decided to trust is exactly Day 1 Exercise 4's scenario, now built
by your own hands instead of described on paper.

One more structural detail you'll see in the CA configs today:
`ca/openssl-root.cnf`'s `[ v3_intermediate_ca ]` section sets
`basicConstraints = critical, CA:TRUE, pathlen:0`. The `pathlen:0` means
*this specific intermediate may sign leaf certificates, but may not sign
another intermediate underneath itself.* That bounds how deep a chain
rooted at your CA can ever get — one more structural guard against the
chain-of-trust idea being abused to nest fraudulent sub-CAs.

---

## Theory: the fields that actually matter

An `openssl x509 -text` dump has dozens of fields. Only a handful of them
do real verification or policy work; the rest are administrative
window-dressing. Know the difference.

### SAN (Subject Alternative Name) — check 3, and *only* check 3

The `X509v3 Subject Alternative Name` extension is the complete, authoritative
list of names (DNS entries, IPs, occasionally email addresses) a verifier
checks the connection target against. If you're connecting to
`example.local` and it's not in this list, check 3 fails — full stop,
regardless of how correct everything else is.

### CN (Common Name) — deprecated for hostname matching

The Subject's `CN` field used to be the hostname-matching field, back before
SAN existed as a standard. It is **not anymore**. Modern browsers (Chrome
dropped CN matching around version 58, in 2017) and modern `curl`/OpenSSL
ignore the Subject CN entirely for check 3. It still appears in the
`Subject` line for human-readable display (and this lab's scripts still set
it, for exactly that reason — logs and `openssl x509 -subject` output are
more legible with one), but it carries **zero verification weight**. If a
cert's SAN doesn't include the name you're connecting to, having the right
CN does not save it.

### basicConstraints — structural policy, not one of the four checks

`CA:TRUE` vs `CA:FALSE` (plus, for CAs, an optional `pathlen`) is a hard
architectural boundary: only a certificate marked `CA:TRUE` is legally
allowed to sign other certificates. A verifier building a chain checks this
at every link — a leaf presented as though it could sign further certs (or
a `CA:TRUE` cert missing the `keyCertSign` bit below) gets rejected before
the four checks even finish evaluating. Like Day 1's field-mapping table
said about this same extension: it's *policy*, not one of the four checks
themselves, but real verifiers enforce it just as strictly.

### keyUsage / extendedKeyUsage (EKU) — also policy

`keyUsage` constrains what operations a key is *allowed* to perform:
`keyCertSign, cRLSign` for CA certs (this key may sign other certs and
revocation lists); `digitalSignature, keyEncipherment` for a TLS server
leaf (this key may sign the handshake and, for older RSA key-exchange
suites, decrypt a key blob — see Day 3). `extendedKeyUsage` narrows this
further by *purpose*: `serverAuth` means "this cert is scoped to
authenticating a TLS server," `clientAuth` means "scoped to authenticating
a TLS client." A cert issued with `extendedKeyUsage = serverAuth` and
presented as a *client* certificate in Day 4's mutual-TLS lab should be —
and, on a strict verifier, will be — rejected on EKU policy grounds, even
though its signature, dates, and SAN might all be flawless. Hold onto that;
it's Exercise 4 below.

### Summary table

| Field | Governs | One of the four checks? |
|---|---|---|
| Signature + Issuer | Whether this cert was really produced by its claimed issuer | Check 1 |
| Validity dates | Whether the vouching is currently in effect | Check 2 |
| **SAN** | Whether the cert is *about* the name you're connecting to | Check 3 |
| Root at chain top, in your trust store | Whether you actually trust the top of the chain | Check 4 |
| Subject CN | Human-readable display only | **No** — never used for matching |
| basicConstraints (CA:TRUE/FALSE, pathlen) | Whether this cert is legally allowed to sign other certs, and how deep | No — structural policy |
| keyUsage / EKU | What operations/purposes this key is scoped to | No — structural policy |

---

## Guided lab

All commands run through the `toolbox` container, from `labs/`:

```
docker compose run --rm toolbox <command>
```

You are about to type, by hand, the commands that `ca/make-root.sh`,
`ca/make-intermediate.sh`, and `ca/issue-server-cert.sh` already automate.
Type them yourself first — the scripts exist as your **answer key**, to
check against once you've built each piece, not as a shortcut to skip the
typing.

### Part A — Build the root CA

Set up the directory layout the `openssl ca` command expects (an
index/serial database, exactly like a real CA registrar keeps):

```bash
docker compose run --rm toolbox bash -c '
  mkdir -p ca/root/certs ca/root/crl ca/root/newcerts ca/root/private ca/root/csr
  chmod 700 ca/root/private
  touch ca/root/index.txt
  echo "unique_subject = no" > ca/root/index.txt.attr
  echo 1000 > ca/root/serial
'
```

Generate the root's private key (RSA 4096 — this key gets used only a
handful of times over years, so the extra cost of a larger key is free):

```
docker compose run --rm toolbox openssl genrsa -out ca/root/private/ca.key.pem 4096
docker compose run --rm toolbox chmod 600 ca/root/private/ca.key.pem
```

Self-sign the root certificate, 20 years' validity, using the
`v3_ca` extensions block from `ca/openssl-root.cnf` (`CA:TRUE`,
`keyCertSign,cRLSign`):

```
docker compose run --rm toolbox openssl req -config ca/openssl-root.cnf \
    -key ca/root/private/ca.key.pem \
    -new -x509 -days 7300 -sha256 -extensions v3_ca \
    -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Root CA/CN=TLS Mastery Root CA" \
    -batch \
    -out ca/root/certs/ca.cert.pem
```

**Checkpoint:** open `ca/make-root.sh` now and confirm every line you just
typed has a matching line in the script. Same directories, same key size,
same `-extensions v3_ca`, same validity. If something differs, that's a bug
in your typing, not a different valid approach — this script *is* the
answer key.

### Part B — Build the intermediate CA, signed by the root

Same directory setup, this time under `ca/intermediate/`:

```bash
docker compose run --rm toolbox bash -c '
  mkdir -p ca/intermediate/certs ca/intermediate/crl ca/intermediate/newcerts ca/intermediate/private ca/intermediate/csr
  chmod 700 ca/intermediate/private
  touch ca/intermediate/index.txt
  echo "unique_subject = no" > ca/intermediate/index.txt.attr
  echo 1000 > ca/intermediate/serial
'
docker compose run --rm toolbox openssl genrsa -out ca/intermediate/private/intermediate.key.pem 4096
docker compose run --rm toolbox chmod 600 ca/intermediate/private/intermediate.key.pem
```

The intermediate doesn't self-sign — it creates a CSR (Certificate Signing
Request: "here's my public key and identity, please sign this") and hands
it to the root:

```
docker compose run --rm toolbox openssl req -config ca/openssl-intermediate.cnf \
    -key ca/intermediate/private/intermediate.key.pem \
    -new -sha256 \
    -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Intermediate CA/CN=TLS Mastery Intermediate CA" \
    -batch \
    -out ca/intermediate/csr/intermediate.csr.pem
```

Now the root signs it, using the `v3_intermediate_ca` extensions block
(`CA:TRUE, pathlen:0` — the constraint from the mental-model section
above):

```
docker compose run --rm toolbox openssl ca -config ca/openssl-root.cnf \
    -extensions v3_intermediate_ca -days 3650 -notext -md sha256 \
    -in ca/intermediate/csr/intermediate.csr.pem \
    -out ca/intermediate/certs/intermediate.cert.pem \
    -batch
```

Build the chain file — everything a client needs to walk from the leaf all
the way up to the root, concatenated in order (this is exactly
`ca-chain.cert.pem`, reused every remaining day of this course):

```
docker compose run --rm toolbox bash -c \
  "cat ca/intermediate/certs/intermediate.cert.pem ca/root/certs/ca.cert.pem > ca/intermediate/certs/ca-chain.cert.pem"
```

**Checkpoint:** compare against `ca/make-intermediate.sh` — same signing
authority config (`openssl-root.cnf`, because the *root* is doing the
signing here), same extension, same chain-building `cat`.

### Part C — Issue the leaf cert (and a subtlety worth understanding)

Generate the server key and CSR, same shape as before:

```
docker compose run --rm toolbox openssl genrsa -out ca/intermediate/private/example.local.key.pem 2048
docker compose run --rm toolbox openssl req -config ca/openssl-intermediate.cnf \
    -key ca/intermediate/private/example.local.key.pem \
    -new -sha256 \
    -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Servers/CN=example.local" \
    -batch \
    -out ca/intermediate/csr/example.local.csr.pem
```

Here's the subtlety. You might reach for `openssl req -addext
"subjectAltName=DNS:example.local"` on the command above, expecting it to
land in the final cert. **It won't** — not with this lab's config. Open
`ca/openssl-intermediate.cnf` and find `copy_extensions = none` in
`[ CA_default ]`. That setting tells `openssl ca` (the *signing* step,
which happens next) to ignore whatever extensions the CSR requested and
instead pull `subjectAltName` from whatever `[ alt_names ]` section the
*signing config* points at. A SAN attached to the CSR via `-addext` is
silently discarded at signing time. (This is Exercise 2 below — work
through *why* the config is deliberately written this way before reading
the solution.)

So, to get `DNS:example.local` into the signed cert, you rewrite the
`[ alt_names ]` section in a scratch copy of the signing config before
calling `openssl ca` — exactly what `issue-server-cert.sh` automates via
`sed`:

```bash
docker compose run --rm toolbox bash -c '
  sed "/^\[ alt_names \]/,\$d" ca/openssl-intermediate.cnf > ca/intermediate/csr/example.local.ext.cnf
  printf "[ alt_names ]\nDNS.1 = example.local\n" >> ca/intermediate/csr/example.local.ext.cnf
'
```

Now sign, using the `server_cert` extensions (`CA:FALSE`,
`digitalSignature,keyEncipherment`, `serverAuth`, and — because of the
scratch config you just built — the correct SAN):

```
docker compose run --rm toolbox openssl ca -config ca/intermediate/csr/example.local.ext.cnf \
    -extensions server_cert -days 375 -notext -md sha256 \
    -in ca/intermediate/csr/example.local.csr.pem \
    -out ca/intermediate/certs/example.local.cert.pem \
    -batch
```

Confirm the SAN actually landed:

```
docker compose run --rm toolbox bash -c \
    "openssl x509 -in ca/intermediate/certs/example.local.cert.pem -noout -text | grep -A1 'Subject Alternative Name'"
# Expected: DNS:example.local
```

**Checkpoint:** `issue-server-cert.sh` does exactly this `sed`-rewrite
trick for every SAN you hand it, DNS or IP, for any CN — that's the whole
reason the script exists rather than a one-line `-addext` call. From this
point on in the course, use the script:
`docker compose run --rm toolbox bash ca/issue-server-cert.sh <cn> [san...]`
does everything you just typed by hand, safely and repeatably. Confirm it
against what you already built (`openssl verify -CAfile
ca/intermediate/certs/ca-chain.cert.pem ca/intermediate/certs/example.local.cert.pem`
→ `OK`) before moving on.

### Part D — Serve it from nginx, and watch curl fail, then succeed

nginx reads certs from `labs/certs/` (mounted to `/etc/nginx/certs/`), not
from `ca/` directly, so copy the leaf key and the full chain (leaf +
intermediate + root, in that order — the order TLS requires) into place:

```bash
docker compose run --rm toolbox bash -c '
  cat ca/intermediate/certs/example.local.cert.pem ca/intermediate/certs/ca-chain.cert.pem \
      > certs/example.local.fullchain.pem
  cp ca/intermediate/private/example.local.key.pem certs/example.local.key.pem
'
```

`labs/services/nginx-day02.conf` points `ssl_certificate` at that fullchain
and `ssl_certificate_key` at the key — but nginx itself only ever reads
`services/active.conf` (see `docker-compose.yml`'s bind mount), so activate
today's config there before starting nginx:

```
cp services/nginx-day02.conf services/active.conf
docker compose up -d nginx        # first start; if already running use: docker compose restart nginx
```

Now hit it twice — once with no idea who your CA is, once armed with the
chain:

```
docker compose run --rm toolbox curl --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
# Expected: FAIL — self-signed/unknown issuer. curl and nginx are two
# separate containers on the certlab network, so "--connect-to
# example.local:8443:nginx:443" is what actually gets you to nginx here:
# it tells curl "when you'd normally connect to example.local:8443, dial
# the nginx service's container-internal port 443 instead" — while still
# sending SNI and the Host header as example.local:8443, exactly as if you
# had DNS pointing example.local at nginx. (A plain --resolve pointing at
# 127.0.0.1 would NOT work here — 127.0.0.1 *inside the toolbox container*
# is the toolbox container itself, not nginx.) curl's own trust store (the
# container's system CA bundle) has never heard of "TLS Mastery Root CA."
# nginx sent the full chain (leaf, intermediate, root — see Part D's cat
# above), so curl CAN walk the signatures all the way up to the root
# (check 1 passes, link by link) — but that root, though present in the
# chain it received, isn't in curl's trusted store. This is check 4
# failing on an otherwise internally-consistent chain: expect wording close
# to "self signed certificate in certificate chain" or "unable to get
# local issuer certificate" depending on exactly what curl's bundle
# contains.

docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
# Expected: SUCCESS. --cacert adds BOTH the intermediate and the root to
# curl's trust store for this one invocation. Check 1 passes (same chain
# as before), check 2 passes (fresh leaf, nowhere near expiry), check 3
# passes (SAN has example.local, which --connect-to leaves untouched as
# the SNI/Host value — only the actual TCP destination changed, not the
# name being verified), and now check 4 passes too, because the root at
# the top of the chain is sitting right there in the file you just handed
# --cacert. Nothing about the certificate changed between these two
# commands — only what the VERIFIER was told to trust changed. That is the
# entire lesson of Day 1's check-1-vs-check-4 distinction, now happening to
# you on a live socket instead of on paper.
```

If the first command instead reports connection-level errors (`Failed to
connect`, `Connection refused`), the problem is nginx not being up or not
listening where expected — re-check `docker compose ps` and the
`8443:443` port mapping in `docker-compose.yml` before assuming anything
about certificates.

---

## Exercises

Each has a hint ladder — try without looking, then peel back one hint at a
time.

### Exercise 1

**Why does the first `curl` command above fail, but a browser pointed at
the exact same URL might show you a *different*-looking error (a full-page
warning rather than a one-line message)? Are they failing for the same
underlying reason?**

<details>
<summary>Hints</summary>

- Nudge: think about *where* trust decisions live — is there exactly one
  trust store on your machine, or several?
- Tool to run: nothing new — reason about it. What entity decided curl's
  default CA bundle, and is that the same entity that decides Chrome's?
- Partial diagnosis: both are failing check 4 for the identical reason (our
  root isn't a trust anchor for either of them) — the *presentation*
  differs, not the underlying cause.

</details>

<details>
<summary>Solution</summary>

Same underlying failure, different presentation. `curl` and a browser each
maintain their **own** trust store — curl typically uses the OS/distro CA
bundle (`ca-certificates` in the toolbox container), while browsers
increasingly ship or manage their own root program (Chrome's own root
store, independent of the OS). Neither has ever heard of "TLS Mastery Root
CA," so both fail check 4. curl, being a CLI tool, reports this tersely on
stderr and exits non-zero. A browser, built for a general audience, renders
a full interstitial page (`NET::ERR_CERT_AUTHORITY_INVALID` in Chrome, or
similar) with a "your connection is not private" warning and a bypass
button. The *check that failed* is identical; only the UI around reporting
it differs, because the two tools are built for very different audiences.

</details>

### Exercise 2

**`ca/openssl-intermediate.cnf` sets `copy_extensions = none`. Explain, in
terms of what could go wrong if it were set to `copyall` instead, why this
lab's CA config deliberately refuses to trust extensions requested by the
CSR itself.**

<details>
<summary>Hints</summary>

- Nudge: who controls the CSR's requested extensions — the CA, or whoever
  is asking to be issued a certificate?
- Tool to run: nothing to run — reread the CSR-generation command in
  Part C. What if that `-subj`/`-addext` line were typed by an attacker
  instead of you?
- Partial diagnosis: `copyall` means "trust whatever extensions the
  *requester* asked for." Ask what a malicious requester could ask for.

</details>

<details>
<summary>Solution</summary>

A CSR is, fundamentally, an unauthenticated request: "please sign a
certificate saying I am `<subject>` with SAN `<whatever I put here>` and
these extensions." The CA's job is to *decide* what actually goes into the
signed document, not to rubber-stamp the requester's wish list. If
`copy_extensions = copyall`, a requester could put `basicConstraints =
CA:TRUE` in their own CSR's requested extensions, or a SAN listing a
hostname they don't actually control, and — depending on what other checks
the operator forgot to add — potentially get the CA to sign it. Setting
`copy_extensions = none` forces every security-relevant extension
(`basicConstraints`, `keyUsage`, `extendedKeyUsage`, `subjectAltName`) to
come from the **signing config's own extension section** (`[ server_cert
]` / `[ alt_names ]`), which the CA operator controls, not the requester.
This is why `-addext` on the CSR silently does nothing here, and why
`issue-server-cert.sh` has to build a scratch `[ alt_names ]` block on the
*signing* side instead of trusting whatever the CSR asked for.

</details>

### Exercise 3

**You issue a leaf cert with `extendedKeyUsage = serverAuth` (exactly what
`[ server_cert ]` in `ca/openssl-intermediate.cnf` sets). In Day 4's mutual
TLS lab, you'll try presenting a certificate as a *client* identity. Predict
whether a `serverAuth`-only cert works as a client cert, and say which
field is responsible either way — is this one of Day 1's four checks?**

<details>
<summary>Hints</summary>

- Nudge: re-read the keyUsage/EKU subsection above — what's the difference
  between `serverAuth` and `clientAuth`?
- Tool to run: nothing to run yet (Day 4 builds the actual mTLS setup) —
  this is a prediction exercise based on today's theory.
- Partial diagnosis: nothing about signature, dates, or SAN is in question
  here. This is purely a *purpose* restriction on the key.

</details>

<details>
<summary>Solution</summary>

A strict verifier should reject it. `extendedKeyUsage = serverAuth`
explicitly scopes this certificate's key to authenticating a TLS *server* —
it does not carry `clientAuth`, the purpose a verifier checks for when a
certificate is presented as a client identity during mTLS. This has
nothing to do with signature validity, expiry, or SAN — the cert could be
flawless on all three counts and still be the wrong *kind* of certificate
for the role it's being used in. EKU/keyUsage are **policy constraints
layered on top of the four checks**, exactly as this day's theory section
states — not one of Day 1's four checks themselves, but real verifiers
(nginx with `ssl_verify_client on`, in particular) enforce them just as
strictly. The fix, when you get to Day 4, is issuing a *separate*
certificate with `extendedKeyUsage = clientAuth` for the client identity —
which is exactly why the real world issues visibly different "server" and
"client" certs rather than reusing one cert for both roles.

</details>

### Exercise 4

**A colleague suggests: "Let's just skip the intermediate — have the root
sign `example.local`'s cert directly, one less step." List the concrete
operational downside of taking that shortcut, using the blast-radius
argument from this day's mental-model section.**

<details>
<summary>Hints</summary>

- Nudge: this isn't a trick question about the cryptography (a root-signed
  leaf verifies exactly as well as an intermediate-signed one). It's about
  what happens *after* something goes wrong.
- Tool to run: nothing to run — reread the "why not have the root sign leaf
  certs directly" paragraph above.
- Partial diagnosis: think about what has to happen to the root key itself
  under each design, day to day, versus what has to happen only rarely.

</details>

<details>
<summary>Solution</summary>

Cryptographically, a root-signed leaf verifies exactly the same way — the
shortcut isn't a math problem. The problem is **exposure**: signing leaf
certs is a routine, frequent operation (every new server, every renewal,
every day of this course from here on), and every routine operation that
touches the root's private key is an opportunity for that key to leak —
via a compromised build machine, a careless key-handling mistake, a bug in
whatever automation calls `openssl ca`. Keep the root doing *one rare
thing* (signing an intermediate, maybe once every several years) and it
can live almost entirely offline, touched by a human on purpose, a handful
of times ever. Push all the frequent, automatable, error-prone work onto an
intermediate instead, and if *that* key ever does leak, the fix is
"revoke this one intermediate and everything under it, mint a fresh one
from the still-untouched root" — contained, recoverable, and it doesn't
require getting a new root into every trust store on the planet. Skipping
the intermediate doesn't break anything today; it just means the day
something *does* go wrong, there's no smaller blast radius to fall back
on.

</details>

---

## Drills

Four drills are waiting for you in `labs/drills/drill-05/` through
`drill-08/`, each targeting a different way a chain-of-trust setup breaks:

- **drill-05** — the server sends only the leaf cert, no intermediate
- **drill-06** — the wrong certificate (issued for a different name) gets
  served
- **drill-07** — the chain is fine, but the client never trusted the root
  in the first place
- **drill-08** — the leaf's signature and chain are perfectly valid, but
  it's expired

Each drill directory has a `SYMPTOM.md` stating only the observed output
and the command that produced it — no diagnosis. Work the drill yourself
first. Full graduated-hint walkthroughs live in
`labs/drills/solutions/drill-NN.md` if you get stuck.

## Journal template

```
### Day 2 — Become a CA
Key concept in my own words: ...
Why intermediates exist, in my own words: ...
What confused me and how I resolved it: ...
Drill I found hardest and what finally gave it away: ...
```
