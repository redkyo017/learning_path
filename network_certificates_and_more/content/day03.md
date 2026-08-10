# Day 3 — The Handshake on the Wire

Read this before starting the lab. Budget: ~3.5 hours (75–90 min
theory/reading, ~75 min guided lab — capture, walk the packets, compare
versions — ~45 min exercises before starting the drills).

---

## Learning objectives

By the end of today you should be able to:
- State, unaided, what happens in a full TLS 1.3 handshake, message by
  message, from `ClientHello` through `Finished`.
- Explain the two concrete differences between a TLS 1.2 and a TLS 1.3 full
  handshake: the extra round trip, and whether the `Certificate` message is
  sent in the clear or encrypted.
- Locate, precisely, where in the handshake the certificate is exchanged and
  where the four verification checks — **signature chain → validity dates →
  name match → trust anchor** — actually run.
- Explain what SNI and ALPN are, why SNI is visible on the wire in *both*
  TLS versions, and why only ALPN's *answer* is hidden in 1.3.
- Read any TLS cipher suite name field by field, for both a TLS 1.3 suite
  (`TLS_AES_128_GCM_SHA256`) and a TLS 1.2 suite
  (`ECDHE-RSA-AES128-GCM-SHA256`).
- Capture a live handshake with `tshark`, extract the SNI from a
  `ClientHello`, and explain why the same filtering approach returns nothing
  once you point it at an encrypted TLS 1.3 `Certificate` message.

---

## The mental model: prove identity, then agree on keys

Day 1 gave you the sentence that everything in this course is a variation
on: **a certificate is a signed statement binding a name to a public key**,
verified by four checks in order — signature chain, validity dates, name
match, trust anchor. Today's job is to place that sentence *inside* a real
protocol exchange and see exactly where it fires.

Every TLS handshake, in either version, is doing two jobs, and it helps to
keep them mentally separate even though they overlap in time on the wire:

1. **Prove identity.** The server sends a certificate. The client runs the
   four checks against it, entirely on its own, using nothing but the
   certificate chain it just received and the trust anchors it already
   carries. No further network round trip is needed to do this — it's pure
   local computation the instant the `Certificate` message has arrived.
2. **Agree on keys.** Independently of the certificate, client and server
   run a Diffie-Hellman key exchange (ECDHE, in every modern suite) to
   derive a shared secret that never travelled on the wire. This secret
   becomes the traffic keys that encrypt everything after the handshake.

These two jobs are *linked* by exactly one signature: the server proves it
currently holds the private key matching the certificate it just sent (TLS
1.3 calls this signature `CertificateVerify`; TLS 1.2 folds the same proof
into `ServerKeyExchange`). That signature is **not** one of the four checks
— the four checks validate the certificate *document itself* (was it
legitimately issued, is it still valid, is it for the right name, does it
chain to something you trust); `CertificateVerify`/`ServerKeyExchange`
proves something different: that whoever is on the other end of *this*
specific TCP connection, right now, actually possesses the private key —
not just a copy of someone else's certificate bytes they captured off the
wire. Without that live proof-of-possession step, an attacker could replay
a captured certificate without ever holding the key it names.

Hold both halves in mind as you read the message-by-message walkthrough
below: at every step, ask "is this proving identity, agreeing on keys, or
proving live possession of the key the identity claims?"

---

## Theory

### The TLS 1.3 full handshake, message by message

TLS 1.3 (RFC 8446) collapses the full handshake into a single round trip.
Here is every message, in order, with what it carries and who sends it:

| # | Message | Sender | Encrypted? | Carries |
|---|---|---|---|---|
| 1 | `ClientHello` | Client | No (never is) | client random, supported TLS versions, cipher suites (only the 5 TLS 1.3 suites), a guessed `key_share` (ephemeral ECDHE public key, e.g. for X25519), `signature_algorithms`, **SNI (`server_name` extension)**, **ALPN offer list** |
| 2 | `ServerHello` | Server | No — last plaintext server message | server random, chosen cipher suite, server's `key_share` (its own ephemeral ECDHE public key) |
| — | *(key derivation happens here)* | both | — | Both sides now have enough to compute the ECDHE shared secret and derive **handshake traffic keys**. Everything the server sends from this point on is encrypted with those keys. |
| 3 | `EncryptedExtensions` | Server | **Yes** | extensions that don't need to be public — this is where the **ALPN answer** lives in 1.3 |
| 4 | `Certificate` | Server | **Yes** | the server's certificate chain — **this is where the certificate is sent** |
| 5 | `CertificateVerify` | Server | **Yes** | a signature, made with the certificate's private key, over the handshake transcript so far — proof of live key possession (see mental model above) |
| 6 | `Finished` | Server | Yes | an HMAC over the entire transcript, proving both sides derived the same keys and saw the same messages |
| 7 | `Finished` | Client | Yes | the client's own transcript HMAC |
| — | *(application data)* | both | Yes | HTTP request/response, etc. |

**This is where the four checks run:** the instant the client has received
and decrypted message 4 (`Certificate`) — before it ever sends its own
`Finished`, before any application data flows — the client runs signature
chain → validity dates → name match → trust anchor entirely offline,
against the chain it just decrypted. If any check fails, the client aborts
the handshake with a fatal alert instead of sending `Finished`. Common
(though implementation-dependent — TLS doesn't rigidly mandate a 1:1
mapping) alert choices per failed check:

| Check | Typical alert |
|---|---|
| 1. Signature chain | `bad_certificate` (42) or `decrypt_error` (51) |
| 2. Validity dates | `certificate_expired` (45) |
| 3. Name match | *(not a TLS alert at all — see below)* |
| 4. Trust anchor | `unknown_ca` (48) |

Check 3 is worth calling out specifically: **hostname verification is not
part of the TLS protocol** — TLS itself has no "wrong name" alert. It's an
application-layer decision made by the TLS *library's caller* (curl,
a browser, your HTTP client) after the TLS handshake has already
succeeded at the protocol level. That's why curl's error for a SAN
mismatch looks completely different from a protocol alert — you'll see it
directly in the guided lab.

### What TLS 1.2 did differently

TLS 1.2's full handshake needs **one extra round trip**, and it sends the
certificate **in the clear**:

| Flight | Sender | Contents |
|---|---|---|
| 1 | Client | `ClientHello` — cipher suites (each one bundling key exchange + auth + cipher + hash into a single name), SNI, ALPN offer — all in the clear, same as 1.3 |
| 2 | Server | `ServerHello`, **`Certificate` (in the clear — no encryption exists yet)**, `ServerKeyExchange` (server's ephemeral ECDHE key + a signature over it, made with the certificate's private key — the 1.2 equivalent of `CertificateVerify`), `ServerHelloDone` |
| 3 | Client | `ClientKeyExchange` (client's ephemeral ECDHE key), `ChangeCipherSpec`, `Finished` (the client's *first* encrypted message) |
| 4 | Server | `ChangeCipherSpec`, `Finished` |
| — | both | application data |

Count the round trips: `ClientHello` → `[flight 2]` → `[flight 3]` →
`[flight 4]` → app data. That's **two full round trips before application
data can flow**, versus TLS 1.3's **one**. The four checks still run in
exactly the same place conceptually — the instant the client has received
flight 2's `Certificate` — but here that certificate arrived over the wire
completely unencrypted, so **anyone passively watching the network sees the
full certificate chain**, not just the SNI. TLS 1.3 doesn't hide the
certificate from an *active* attacker who can complete the ECDHE exchange
themselves (nobody can hide anything from a genuine man-in-the-middle who
terminates the connection) — but it does hide it from a *passive* observer
who can only read packets off the wire, since the `Certificate` message is
now wrapped in a record encrypted with a key derived from an ephemeral
secret that never appeared on the wire in recoverable form.

### SNI: visible in the clear, in *both* versions

Server Name Indication is a `ClientHello` extension carrying the hostname
the client intends to reach — the TLS-layer equivalent of HTTP's `Host:`
header, needed because a single IP can host many TLS virtual hosts and the
server has to pick which certificate to present before any encryption
exists. That "before any encryption exists" is the whole story: SNI **must**
travel unencrypted in every mainstream TLS version deployed today, TLS 1.3
included, because the server needs to read it before it can derive any
keys at all. This is why a network operator, ISP, or on-path box can always
see which hostname you're connecting to over HTTPS, even on TLS 1.3, even
though it can't see anything else about the connection. (Encrypted Client
Hello, ECH, is a newer, still-maturing extension designed specifically to
close this gap — out of scope for today, but worth knowing it exists so you
aren't surprised later.)

### ALPN: offer always visible, answer hidden only in 1.3

Application-Layer Protocol Negotiation lets client and server agree on the
next-layer protocol (`h2`, `http/1.1`, ...) inside the same TLS handshake,
avoiding a separate negotiation round trip. The client's *offer* (its list
of supported protocols) rides inside `ClientHello`, in the clear, in both
versions — same visibility problem as SNI. The difference is the *answer*:
in TLS 1.2 the server's chosen protocol is announced in `ServerHello`
itself, in the clear; in TLS 1.3 it moves into `EncryptedExtensions`
(message 3 above), so an eavesdropper can see that ALPN was *offered* and
what was offered, but not which protocol was actually *selected*.

Per RFC 7301 §3.2: if a server has ALPN protocols configured and none of
them appear in the client's offered list, the server **must** send a fatal
`no_application_protocol` alert (120) and abort — this isn't optional
graceful fallback, it's a mandated hard failure. That's the mechanism
behind drill 12.

### Session resumption

**TLS 1.3** rides on PSK (pre-shared key) machinery: after a full
handshake, the server sends a post-handshake `NewSessionTicket` message
carrying an opaque ticket. A later connection can present that ticket in
its `ClientHello`'s `pre_shared_key` extension to skip the asymmetric
handshake entirely, re-deriving keys from the earlier session's secret. If
the client also sends `early_data`, application data can flow in the very
first flight — "0-RTT" — but 0-RTT data has no fresh-randomness proof of
liveness the way the 1-RTT `Finished` exchange does, so it's replayable by
a network attacker and is typically restricted to idempotent requests.

**TLS 1.2** resumes via Session IDs (server caches session state, client
echoes a `session_id` in `ClientHello`) or Session Tickets (RFC 5077,
stateless, same idea, issued during the original full handshake). Either
way, resumption skips `Certificate`/`ServerKeyExchange` entirely and jumps
straight to an abbreviated `ChangeCipherSpec`+`Finished` exchange on both
sides — no certificate re-validation happens on a resumed connection,
because the four checks already ran once, during the original full
handshake that issued the ticket.

### Reading a cipher suite name

**TLS 1.3 — `TLS_AES_128_GCM_SHA256`:**

| Field | Value | Meaning |
|---|---|---|
| Protocol prefix | `TLS` | — |
| Bulk cipher + mode | `AES_128_GCM` | AES, 128-bit key, GCM (Galois/Counter Mode) — an AEAD mode giving confidentiality *and* integrity in one primitive |
| Hash | `SHA256` | used for the handshake's key derivation (HKDF) and the `Finished` MAC — **not** used to encrypt anything itself |

Notice what's **absent**: no key-exchange algorithm, no authentication
algorithm. TLS 1.3 always uses (EC)DHE for key exchange, and the
certificate's own key type (RSA or ECDSA) is signalled separately via the
`signature_algorithms` extension — decoupled entirely from the cipher
suite name. This is a deliberate 1.3 simplification.

**TLS 1.2 — `ECDHE-RSA-AES128-GCM-SHA256`** (OpenSSL's display form of
`TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`):

| Field | Value | Meaning |
|---|---|---|
| Key exchange | `ECDHE` | Elliptic Curve Diffie-Hellman, Ephemeral — forward-secret key agreement |
| Authentication | `RSA` | **the server's certificate must contain an RSA public key**, and `ServerKeyExchange`'s signature over the ephemeral ECDHE parameters is computed with that RSA key |
| Bulk cipher | `AES128-GCM` | AES, 128-bit, GCM (AEAD, same as above) |
| Hash | `SHA256` | here, purely the handshake PRF hash — because this is an AEAD suite, GCM itself handles integrity, so `SHA256` is *not* doing a separate per-record HMAC job the way it would in an older, pre-AEAD suite like `...AES128-CBC-SHA` |

The `RSA` field is load-bearing, not decorative: an `ECDHE-ECDSA-*` suite
can only be selected if the server's certificate holds an **ECDSA** key —
offer that suite to a server whose only certificate is RSA (as ours is;
Day 2's `issue-server-cert.sh` issues RSA 2048 leaf keys) and there is
*no* certificate the server could present that would satisfy it, no matter
how the rest of negotiation goes. That's the exact mechanism drill 10
exploits.

---

## Guided lab

All commands run through `toolbox`, from `labs/`:

```
docker compose run --rm toolbox <command>
```

`mkdir -p tmp` first if `labs/tmp/` doesn't exist yet — the capture file
lands there via the bind mount.

> **Before you start:** this lab reuses Day 2's running nginx, so
> `services/active.conf` must still be Day 2's config and the `nginx`
> service must be up: `cp services/nginx-day02.conf services/active.conf`,
> then `docker compose up -d nginx` (or `docker compose restart nginx` if
> it's already running).
>
> The `curl` below uses `--connect-to example.local:8443:nginx:443`, not
> `--resolve`. `toolbox` and `nginx` are separate containers on the shared
> `certlab` bridge network — not sharing a network namespace — so
> `127.0.0.1` inside `toolbox` refers to `toolbox` itself, never `nginx`;
> `--resolve example.local:8443:127.0.0.1` would just connect back to the
> toolbox container and fail with a connection error, not a TLS-layer
> result. `--connect-to` redirects the TCP connection to `nginx:443` over
> the container network while still sending `example.local` as SNI and the
> `Host` header — exactly as if DNS pointed `example.local` at `nginx`.
> **This entire lab was authored without a live Docker session available
> — every command below is reasoned through carefully, but none of it has
> actually been run; treat every output block marked "expected — not
> captured" accordingly, and confirm live before trusting it blindly.**

### Capture a handshake

```
docker compose run --rm toolbox bash -c \
  "tshark -i any -w /work/tmp/hs.pcap -a duration:5 & sleep 1; \
   curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
        --connect-to example.local:8443:nginx:443 https://example.local:8443/ ; wait"
```

`tshark` starts capturing on all interfaces for 5 seconds; after a 1-second
head start, `curl` performs the actual TLS handshake and HTTP request
against Day 2's nginx; `wait` blocks until both background/foreground jobs
finish so the container doesn't exit early. You should see curl print
nginx's default response body, and `tmp/hs.pcap` should now exist on the
host at `labs/tmp/hs.pcap` (openable directly in Wireshark on your host —
no container needed for the GUI walk).

### Inspect the ClientHello — SNI in the clear

```
tshark -r /work/tmp/hs.pcap -Y 'tls.handshake.type==1' -V | grep -i server_name
```

Expected output (**expected — not captured**; reasoned from how Wireshark's
TLS dissector renders the SNI extension, not from an actual run):

```
Server Name Indication extension
    Server Name Type: host_name (0)
    Server Name: example.local
```

`tls.handshake.type==1` filters for `ClientHello` specifically (handshake
type `1`, per the IANA TLS HandshakeType registry) — and this filter works
identically regardless of whether the session negotiates TLS 1.2 or 1.3,
because `ClientHello` is *never* encrypted in either version. That's
exactly why this command reliably shows you the SNI no matter which
protocol version curl and nginx agree on underneath.

### Walk the rest of the messages, and watch TLS 1.3 hide the certificate

Confirm which protocol version was actually negotiated, then walk each
message type by filtering the same capture:

```
# Negotiated version (look in the ServerHello)
tshark -r /work/tmp/hs.pcap -Y 'tls.handshake.type==2' -V | grep -i version

# ServerHello itself
tshark -r /work/tmp/hs.pcap -Y 'tls.handshake.type==2' -V

# Certificate
tshark -r /work/tmp/hs.pcap -Y 'tls.handshake.type==11' -V

# Finished
tshark -r /work/tmp/hs.pcap -Y 'tls.handshake.type==20' -V
```

If curl and nginx negotiated **TLS 1.2** (possible if nginx's configured
`ssl_protocols` excludes 1.3), the `Certificate` and `Finished` filters
above will show you real, dissected content — the certificate arrived in
the clear, and tshark can parse it directly.

If they negotiated **TLS 1.3** — the likely default, since modern
OpenSSL-linked curl and nginx both prefer the highest mutually supported
version — the `tls.handshake.type==11` and `tls.handshake.type==20` filters
will return **nothing at all**. Not because those messages weren't sent —
they were, right on schedule — but because RFC 8446 deliberately wraps
every post-`ServerHello` server message in a record whose *outer* type is
`23` (`application_data`), the exact same outer type used for real HTTP
response bytes. Without the session keys, tshark cannot even tell that
those records are handshake messages, let alone which type. Confirm this
directly:

```
tshark -r /work/tmp/hs.pcap -Y 'tls.record.content_type==23'
```

(older Wireshark builds use the field name `ssl.record.content_type` — try
that if `tls.record.content_type` returns nothing on your version.) This
will list several records — some of these opaque, identically-labelled
`application_data` records are actually the encrypted `Certificate`,
`CertificateVerify`, and `Finished` messages; others are the real HTTP
response. From the wire, without keys, you cannot tell which is which —
which is exactly the confidentiality property TLS 1.3 buys you for the
certificate exchange, and exactly why a passive network observer sees your
certificate on TLS 1.2 but not on TLS 1.3, while seeing your SNI on both.

---

## Exercises

Answer these before moving to the drills. Each has a hint ladder — try
without looking, then peel back one hint at a time.

### Exercise 1

**Identify every field in `TLS_AES_128_GCM_SHA256` and state what each one
does. Then say what's conspicuously absent compared to a TLS 1.2 suite
name, and why.**

<details>
<summary>Hints</summary>

- Nudge: split on underscores first — `TLS`, `AES`, `128`, `GCM`, `SHA256`
  — then decide which chunks are one logical field.
- Tool to run: nothing to run — this is a pure read-the-theory exercise.
  Re-read the "Reading a cipher suite name" section's TLS 1.3 row above.
- Partial diagnosis: TLS 1.3 suite names describe the *bulk symmetric
  cipher* and the *handshake hash* only. Ask yourself: how does the client
  even know whether it's talking to an RSA-keyed or ECDSA-keyed server,
  if the suite name doesn't say?

</details>

<details>
<summary>Solution</summary>

- `TLS` — protocol prefix, not a field with independent meaning.
- `AES_128_GCM` — the bulk cipher: AES with a 128-bit key, run in GCM
  (an AEAD mode: one primitive provides both confidentiality and
  integrity, replacing the separate cipher+MAC combination older suites
  needed).
- `SHA256` — the hash function used for the handshake's key derivation
  (HKDF) and the `Finished` message's transcript MAC. It does **not**
  encrypt or authenticate application data itself — GCM already does
  that job.

**Absent:** any key-exchange algorithm (e.g. `ECDHE`) and any
authentication/certificate-key-type algorithm (e.g. `RSA` or `ECDSA`).
TLS 1.3 always uses an (EC)DHE key exchange — there is no cipher-suite
choice on that axis anymore — and the certificate's key type is negotiated
through a separate extension (`signature_algorithms`), completely
decoupled from which bulk cipher gets used. TLS 1.3 suite names describe
strictly less than TLS 1.2 names precisely because 1.3 removed choices
(static RSA key exchange, non-AEAD ciphers, weak hashes) that 1.2 still
had to let a suite name distinguish between.

</details>

### Exercise 2

**Identify every field in `ECDHE-RSA-AES128-GCM-SHA256` (a TLS 1.2 suite,
OpenSSL's display form of `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`). A
server's only certificate is ECDSA-keyed. Can this suite ever be
negotiated against that server? Why or why not?**

<details>
<summary>Hints</summary>

- Nudge: this suite name has one more field than the 1.3 one in
  Exercise 1. Which field is new, and what does it constrain?
- Tool to run: nothing to run — reasoning exercise. Re-read the `RSA`
  row's explanation in the theory section above.
- Partial diagnosis: `RSA` here isn't describing the bulk cipher or the
  key exchange — it's naming a required property of the certificate
  itself.

</details>

<details>
<summary>Solution</summary>

- `ECDHE` — key exchange: Elliptic Curve Diffie-Hellman, Ephemeral
  (forward-secret).
- `RSA` — authentication: the server's certificate must hold an **RSA**
  public key, because `ServerKeyExchange`'s signature over the ephemeral
  ECDHE parameters is computed using that certificate's private key, and
  the signature algorithm has to match the key type.
- `AES128-GCM` — bulk cipher: AES, 128-bit key, GCM (AEAD).
- `SHA256` — handshake PRF hash (not a separate per-record MAC, since GCM
  is already an AEAD mode).

**No, this suite cannot be negotiated** against a server whose only
certificate is ECDSA-keyed. `ECDHE-RSA-*` suites require the server to
sign `ServerKeyExchange` with an RSA private key — an ECDSA certificate
has no RSA key to sign with. The server would need a suite from the
`ECDHE-ECDSA-*` family instead, which requires exactly the opposite:
an ECDSA-keyed certificate. This is the identical mechanism — just
mirrored — behind drill 10, where the client insists on `ECDHE-ECDSA-*`
suites against a server whose only certificate is RSA.

</details>

### Exercise 3

**An on-path network observer — no keys, no ability to intercept and
re-terminate the connection, purely passive — watches a TLS 1.3 connection
to `https://billing.internal.example/invoices`. List everything they can
learn, and everything they specifically cannot, from the handshake alone.**

<details>
<summary>Hints</summary>

- Nudge: separate "what's in `ClientHello`" from "what's in every message
  after `ServerHello`" — that boundary is exactly where TLS 1.3's
  encryption kicks in.
- Tool to run: nothing to run — re-read the SNI and ALPN theory sections
  above, plus the "what TLS 1.3 hides" paragraph.
- Partial diagnosis: the observer sees everything sent before keys are
  derived, and only outer record metadata (type, length, timing) for
  everything after.

</details>

<details>
<summary>Solution</summary>

**Learnable, purely from the plaintext `ClientHello`:**
- The SNI: `billing.internal.example` (the hostname, in the clear, always).
- The client's offered ALPN protocol list (e.g. `h2`, `http/1.1`).
- The offered TLS versions and cipher suites, and the client's
  `key_share` guesses.
- Nothing about the URL **path** (`/invoices`) — that's an HTTP-layer
  detail that only exists inside the encrypted application data, long
  after the handshake.

**Not learnable**, because it only exists inside records encrypted with
handshake or application traffic keys the observer never derives:
- Which ALPN protocol was actually **selected** (that answer lives in
  `EncryptedExtensions` in 1.3).
- The server's certificate contents (issuer, SAN list, validity dates —
  all inside the encrypted `Certificate` message).
- The HTTP request/response entirely, including the `/invoices` path,
  headers, and body.

The observer can still see record *sizes*, *timing*, and *count* — traffic
analysis is a real, separate concern this course doesn't cover — but
nothing about *content* beyond the hostname and the offered (not
selected) ALPN list.

</details>

### Exercise 4

**At what exact point in the handshake do the four verification checks
run, and what does the client do differently if check 3 (name match)
fails versus if the underlying TLS library detects a version mismatch
(check-independent, a protocol-level failure)?**

<details>
<summary>Hints</summary>

- Nudge: one of these is a TLS **protocol** failure with a defined alert;
  the other is a decision made by *code that calls* the TLS library, after
  the handshake already succeeded at the protocol level.
- Tool to run: nothing to run — re-read the "This is where the four checks
  run" paragraph and the "Check 3 is worth calling out" note above.
- Partial diagnosis: a version mismatch means the handshake itself never
  completes — no certificate is ever exchanged. A name mismatch means the
  handshake completes just fine; the certificate arrives, is otherwise
  perfectly valid, and something *outside* TLS decides to reject it anyway.

</details>

<details>
<summary>Solution</summary>

The four checks run the instant the client has received (and, in TLS 1.3,
decrypted) the `Certificate` message — before it sends its own `Finished`,
before any application data flows. This is a fixed point in the handshake
regardless of version.

**A version mismatch** (drill 9's scenario) means the client's and
server's supported-version lists never overlap — the handshake fails
during the `ClientHello`/`ServerHello` exchange itself, before any
`Certificate` message is ever sent. This is a genuine TLS protocol-layer
failure with a defined fatal alert (`protocol_version`, 70). None of the
four checks even get a chance to run, because there's no certificate yet
to check.

**A name mismatch** (check 3) is fundamentally different: the handshake
*succeeds completely* at the protocol level — the certificate arrived,
its signature chain validated, its dates are current, it chains to a
trusted root. TLS has no opinion about hostnames; it delivers the
certificate to whatever code called it and considers its own job done.
**Hostname verification is a decision made by the caller** (curl, a
browser's HTTP stack, an SSH client, a JWT library) *after* TLS itself
reports success. That's why it doesn't produce a TLS alert at all — it
produces an application-level error (curl's `SSL: no alternative
certificate subject name matches target host name '...'`, exit code 60),
generated entirely outside the TLS handshake, after that handshake already
finished.

</details>

---

## Drills

Four drills are waiting for you in `labs/drills/drill-09/` through
`drill-12/`, each targeting a different way a handshake can fail before
application data ever flows:

- **drill-09** — protocol-version mismatch (client capped below the
  server's version floor)
- **drill-10** — no shared cipher (client insists on an authentication
  algorithm the server's certificate can't satisfy)
- **drill-11** — SNI mismatch causing an unexpected certificate
- **drill-12** — ALPN mismatch (RFC 7301's mandated fatal alert)

Each drill directory has a `SYMPTOM.md` stating the observed symptom, the
exact command that produced it, and a minimal reproduction asset — no
diagnosis. Work the drill yourself first. Full graduated-hint walkthroughs
live in `labs/drills/solutions/drill-NN.md` if you get stuck; resist
opening them until you've actually reasoned about (or, once Docker is
available to you, run) something.

## Journal template

```
### Day 3 — The handshake on the wire
Key concept in my own words: ...
Where the four checks actually run, in my own words: ...
TLS 1.2 vs 1.3 — the two concrete differences, from memory: ...
What confused me and how I resolved it: ...
Drill I found hardest and what finally gave it away: ...
```
