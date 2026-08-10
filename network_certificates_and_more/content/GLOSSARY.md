# Glossary — Network Certificates & More (TLS Mastery)

*Lookup for catch-up: scan for the term you forgot — this is not meant to be read in order. Full treatments live in the day files named in each entry.*

→ [Jump index](#jump-index)

## Acronyms at a glance

| Acronym | Stands for | One-line meaning |
|---|---|---|
| CA | Certificate Authority | entity that signs certificates, vouching for a name-to-key binding |
| CSR | Certificate Signing Request | "here's my key and identity, please sign this" |
| SAN | Subject Alternative Name | the actual list of names a verifier checks the connection target against |
| CN | Common Name | old, now-ignored hostname field in the Subject line |
| EKU | Extended Key Usage | narrows a key's allowed *purpose* (serverAuth, clientAuth, ...) |
| SNI | Server Name Indication | the hostname sent in the clear so a server picks the right cert |
| ALPN | Application-Layer Protocol Negotiation | negotiates `h2`/`http/1.1` inside the TLS handshake |
| mTLS | mutual TLS | both sides present and verify a certificate |
| ACME | Automatic Certificate Management Environment | protocol that automates proving domain control before issuance |
| CRL | Certificate Revocation List | CA's signed list of revoked serial numbers |
| OCSP | Online Certificate Status Protocol | live "is this cert still good?" query to the CA |
| CT | Certificate Transparency | public log every trusted cert must appear in |
| HSTS | HTTP Strict Transport Security | header that forces a browser to always use HTTPS for a host |
| MITM | Man-in-the-Middle | an attacker positioned on the network path, impersonating one side to the other |
| PEM | Privacy-Enhanced Mail (format) | base64-wrapped text encoding for certs/keys, framed with `-----BEGIN/END-----` |
| PKI | Public Key Infrastructure | the whole system of CAs, certs, and trust stores that makes name-to-key bindings verifiable |

## Jump index

[A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) · [H](#h) · [I](#i) · [K](#k) · [L](#l) · [M](#m) · [N](#n) · [O](#o) · [P](#p) · [R](#r) · [S](#s) · [T](#t) · [U](#u) · [V](#v) · [W](#w) · [X](#x)

## A

**ACM (AWS Certificate Manager)** — AWS's own ACME-issuing CA, wired directly into ALB/NLB and other AWS services. Requesting a public cert through it runs the same domain-control validation as this course's Pebble lab — DNS validation is the ACME-equivalent of DNS-01; the older email validation predates ACME and should generally be avoided. (see Day 5)

**ACME (Automatic Certificate Management Environment)** — The protocol that automates *proving you control a name* before a public CA will issue a certificate for it, plus requesting the signature, receiving the cert, and renewing it before expiry. It doesn't change what a certificate is or how it's verified — it automates everything upstream of issuance. (see Day 5)

**AEAD (Authenticated Encryption with Associated Data)** — A cipher mode, like GCM, that provides confidentiality and integrity in one primitive, replacing the older pattern of a separate cipher plus a separate MAC. Every modern TLS 1.2/1.3 cipher suite uses an AEAD mode. (see Day 3)

**AES (Advanced Encryption Standard)** — The bulk symmetric cipher named in most modern cipher suites (e.g. `AES_128_GCM`), used to encrypt the actual handshake and application traffic once keys are derived. (see Day 3)

**ALB (Application Load Balancer)** — An AWS load balancer that terminates TLS using a certificate you attach from ACM (or import), directly analogous to nginx's `ssl_certificate`/`ssl_certificate_key` in this course's labs — ACM is just where the cert/key material lives and stays current. (see Day 5)

**ALPN (Application-Layer Protocol Negotiation)** — A TLS extension letting client and server agree on the next-layer protocol (`h2`, `http/1.1`) inside the handshake itself. The client's offer always rides in the clear inside `ClientHello`; the server's chosen answer is in the clear in TLS 1.2 but moves into the encrypted `EncryptedExtensions` in TLS 1.3. (see Day 3)

**Asymmetric cryptography (public key / private key)** — A scheme generating two mathematically linked keys where an operation done with one key can only be checked or undone with the *other*, and deriving the private key from the public one is computationally infeasible. The private key is kept secret by its owner; the public key is shared freely — signing requires the private key, verifying requires only the public key, and that direction can never be reversed. (see Day 1)

**Avalanche effect** — A property of cryptographic hash functions: changing even one bit of the input produces a completely different, unpredictable digest. There's no "close" match — a digest is either exactly right or tells you nothing about how similar the inputs were, which is why tampering with signed content is always detectable. (see Day 1)

## B

**basicConstraints** — The X.509 extension setting `CA:TRUE` or `CA:FALSE` (plus, for CAs, an optional `pathlen` capping how many more CA links can exist beneath it). It's a hard architectural boundary — only a `CA:TRUE` cert may legally sign other certificates — but it is *policy*, not one of the four verification checks; a verifier enforces it separately. (see Day 2)

## C

**CA (Certificate Authority)** — The entity whose private key signs certificates, vouching for a name-to-public-key binding. Real-world CAs are built as a stack (root → intermediate → leaf) rather than one flat entity, specifically to contain the blast radius if a signing key is ever compromised. (see Day 2)

**Certbot** — The most widely used ACME client. It handles talking to the ACME server, satisfying whichever challenge type is configured, and (with `certbot renew`, ideally on a cron/timer) renewing certificates before they expire. (see Day 5)

**Certificate** — A signed statement binding a name to a public key: a structured (X.509) document containing, among other fields, a subject name and that subject's public key, with the whole document signed by the issuer's private key. This one sentence is the foundation the entire course is built on. (see Day 1)

**Certificate chain (chain of trust)** — The sequence of certificates from a leaf up through zero or more intermediates to a root: leaf signed by intermediate, intermediate signed by root. Verifying a chain is check 1 (signature chain) applied recursively, one link at a time, until it terminates at check 4 (is that root actually in my trust store). (see Days 1–2)

**Certificate message (TLS handshake)** — The handshake message carrying the server's (or, in mTLS, the client's) certificate chain. It's sent in the clear in TLS 1.2 but encrypted in TLS 1.3, which is exactly why a passive network observer can see the certificate on 1.2 but not on 1.3. (see Day 3)

**Certificate pinning (public-key pinning)** — A check that sits alongside, not instead of, the four checks: it hardcodes the expected public key (as a SHA-256 hash of the key, not the whole cert) for a given host and refuses the connection if the presented key doesn't match, regardless of whether the four checks would otherwise pass. It defeats a rogue CA outright, because a rogue CA doesn't hold the real server's key — but it also bricks legitimate clients against a routine key rotation unless the new key was pinned in advance. (see Day 6)

**Certificate Transparency (CT) log** — A public, append-only, cryptographically verifiable log that every publicly trusted certificate must be submitted to before major browsers accept it. It's a *detection* mechanism, not prevention — it makes CA mis-issuance impossible to hide, rather than stopping it from happening. (see Days 5–6)

**CertificateVerify** — The TLS 1.3 handshake message where the server signs the transcript so far with its certificate's private key, proving live possession of that key on this specific connection — not just replay of captured certificate bytes. TLS 1.2's equivalent proof is folded into `ServerKeyExchange`. This signature is separate from, and not one of, the four verification checks. (see Day 3)

**ChangeCipherSpec** — A TLS 1.2 message signaling that everything from this point on will be encrypted with the just-negotiated keys. TLS 1.3 keeps the message on the wire for middlebox compatibility but no longer gives it real protocol meaning.

**Cipher suite** — The bundle of algorithms a TLS connection will use. A TLS 1.3 name like `TLS_AES_128_GCM_SHA256` names only the bulk cipher (AES-128-GCM, an AEAD mode) and the handshake hash (SHA-256) — key exchange is always (EC)DHE and the certificate's key type is negotiated separately. A TLS 1.2 name like `ECDHE-RSA-AES128-GCM-SHA256` additionally names the key-exchange algorithm (ECDHE) and the required certificate key type (RSA), because 1.2 still had choices on those axes that 1.3 removed. (see Day 3)

**ClientHello** — The first handshake message, sent by the client, always unencrypted in every TLS version: client random, supported versions and cipher suites, an ephemeral key-exchange guess, and — critically — the SNI and ALPN offer. Everything in it is visible to a passive network observer, on TLS 1.2 and 1.3 alike. (see Day 3)

**ClientKeyExchange** — The TLS 1.2 message where the client sends its own ephemeral ECDHE public key. TLS 1.3 has no equivalent standalone message — the client's key share travels inside `ClientHello` itself.

**CN (Common Name)** — A field in a certificate's Subject line, once used for hostname matching before SAN existed. Modern browsers (Chrome dropped it around 2017) and modern curl/OpenSSL ignore it entirely for check 3 — it's display-only now and carries zero verification weight. (see Day 2)

**CRL (Certificate Revocation List)** — A CA-signed list of every serial number it has revoked, meant to be downloaded and checked by verifiers. In practice it scales badly — the list can be huge and re-fetching it per connection is impractically slow — so almost nothing checks it reliably for ordinary TLS connections. (see Day 5)

**Cross-signing** — Having a new root or intermediate additionally signed by an *older*, already-widely-trusted CA, so clients whose trust stores haven't yet picked up the new root can still validate through the old one. Let's Encrypt's ISRG Root X1 was cross-signed by the older DST Root CA X3 for exactly this reason during its own trust-store rollout. (see Day 4)

**CSR (Certificate Signing Request)** — "Here's my public key and identity, please sign this": the document a would-be certificate holder generates and hands to a CA. A CSR is fundamentally unauthenticated — anything it requests (a SAN, an extension) is a *request*, not a fact, which is why a well-configured CA ignores CSR-requested extensions (`copy_extensions = none`) and decides the real content itself. (see Day 2)

## D

**DER (Distinguished Encoding Rules)** — The raw binary encoding of a certificate or key, as opposed to PEM's base64-wrapped text form. Certificate-pinning tooling hashes a key's DER bytes specifically (`openssl pkey -pubin -outform der`), not the base64 text, because the hash has to match a single canonical byte representation. (see Day 6)

**Digital signature** — Proof that the private-key holder, and only they, produced a given result over a message: hash the message, then run that digest through an operation only the private key can perform. Anyone with the matching public key can verify the signature without ever touching the secret. (see Day 1)

**DigiNotar (2011)** — A trusted commercial CA breached in 2011; the attacker used DigiNotar's own compromised issuance systems to mint fraudulent certificates (including for Google domains), reportedly used for real interception of Iranian users. A Chrome-embedded pin for Google's own domains is part of what caught it — a direct real-world demonstration of certificate pinning defeating what the four checks alone could not. Every major browser fully distrusted DigiNotar afterward, not just the fraudulent certs. (see Day 6)

**DNS-01 challenge** — An ACME challenge proving domain control by having the CA query a `TXT` record at `_acme-challenge.<domain>`. It needs no inbound port at all (only a DNS record change), and it's the *only* challenge type that can issue wildcard certificates, because it proves control of the whole zone rather than one specific reachable host. (see Day 5)

**Domain control validation** — The check a public CA runs before issuing a certificate: does whoever is asking for `example.com`'s cert actually control `example.com`? ACME automates this step; without it, "signed by a CA" would mean nothing more than "someone typed a name into a form." (see Day 5)

**Downgrade attack (SSL stripping)** — An attack on the moment *before* HTTPS starts, not on the certificate itself: an on-path attacker intercepts a victim's initial plaintext `http://` request, relays the real session over genuine HTTPS on the attacker's side, and serves the victim a plain-HTTP copy with `https://` links rewritten to `http://`. Because no TLS handshake happens on the victim's side, none of the four checks ever run — there's no certificate to accept or reject. HSTS is the specific defense. (see Day 6)

## E

**ECDHE (Elliptic Curve Diffie-Hellman, Ephemeral)** — The key-exchange method every modern TLS suite uses to derive a shared secret that never travels on the wire, independently of the certificate. It's ephemeral (a fresh keypair per connection), which is what gives modern TLS forward secrecy. (see Day 3)

**ECDSA** — An asymmetric signature algorithm based on elliptic curves, an alternative to RSA for a certificate's key type. A cipher suite naming `ECDSA` as its authentication field (e.g. `ECDHE-ECDSA-AES128-GCM-SHA256`) can only be negotiated against a server whose certificate actually holds an ECDSA key. (see Day 3)

**ECH (Encrypted Client Hello)** — A newer, still-maturing TLS extension designed to close SNI's remaining gap by encrypting the hostname itself. Unlike ordinary TLS 1.3 (which still sends SNI in the clear), ECH is built specifically to hide even that from a passive network observer. (see Day 3)

**EKU (Extended Key Usage / extendedKeyUsage)** — A certificate extension narrowing a key's allowed *purpose*: `serverAuth` scopes a cert to authenticating a TLS server, `clientAuth` to authenticating a TLS client. It's policy layered on top of the four checks, not one of them, but strict verifiers enforce it — a `serverAuth`-only cert presented as a client identity in mTLS should be rejected on EKU grounds alone. (see Days 2, 4)

**EncryptedExtensions** — The first encrypted message a TLS 1.3 server sends, immediately after `ServerHello`. This is where the ALPN *answer* (as opposed to the offer) lives in 1.3, hidden from passive observers. (see Day 3)

## F

**Finished (TLS message)** — An HMAC (or transcript hash) over the entire handshake, sent by both sides, proving each derived the same keys and saw the same messages. On a resumed session, an abbreviated exchange jumps straight to this step without re-sending or re-verifying a certificate. (see Day 3)

**Forward secrecy** — The property that even if a server's long-term private key is later compromised, past recorded traffic can't be decrypted, because the actual encryption keys were derived from ephemeral (one-per-connection) ECDHE values that never appeared on the wire in recoverable form. (see Day 3)

**Four checks (verification order)** — The complete verification model this course is built around, always run in this order: **1. signature chain** (was this document really produced by its claimed issuer, unaltered, all the way up the chain), **2. validity dates** (is the vouching currently in effect for every cert in the chain), **3. name match** (does the connection target match a name the certificate actually claims, via SAN — never CN), **4. trust anchor** (does the chain terminate at a root you've already decided, out of band, to trust). A chain can pass checks 1–3 perfectly and still fail check 4, because anyone can self-sign a root and build an internally consistent chain underneath it — internal consistency (check 1) is not the same as trustworthiness (check 4). (see Day 1, and every later day)

**Fullchain** — Shorthand (and a common filename, `fullchain.pem`) for a leaf certificate concatenated with its intermediate(s) — everything a client needs, short of the root itself, to walk the signature chain upward. A server presents this so clients don't need the intermediate cert separately. (see Days 2, 4)

## G

**GCM (Galois/Counter Mode)** — An AEAD cipher mode combined with AES in most modern cipher suites (`AES_128_GCM`), providing both confidentiality and integrity in one primitive, which is why these suites don't need a separate MAC hash for per-record authentication. (see Day 3)

## H

**Hash (cryptographic hash function)** — A function taking input of any size and producing a fixed-length digest that is deterministic (same input, same output), one-way (infeasible to reverse), and exhibits the avalanche effect. SHA-256 (used throughout this course) always produces a 256-bit digest; signing operates on a message's hash rather than the message itself because signing algorithms are defined over fixed-size blocks. (see Day 1)

**Heartbleed (2014)** — CVE-2014-0160, an OpenSSL buffer over-read bug letting an attacker repeatedly read up to 64KB of a server's process memory, potentially including its private key. It's the canonical case for why revocation exists: a cert whose key may have leaked can't just wait out its `notAfter` — the correct response is revoke-and-reissue on a fresh keypair, and Heartbleed's mass reissuance event exposed exactly how poorly CRLs and OCSP scale under real load. (see Day 6)

**HPKP (HTTP Public Key Pinning)** — A now-deprecated, browser-wide pinning mechanism (RFC 7469) that let a site declare its own pins via an HTTP header. Chrome removed support because the operational failure mode — a misconfigured pin bricking a whole site for every visitor with no way back — proved too easy to trigger at web scale for the benefit it offered; browsers now rely on app-level or mobile-app pinning instead of a standard header. (see Day 6)

**HSTS (HTTP Strict Transport Security)** — A response header, `Strict-Transport-Security: max-age=<seconds>; includeSubDomains`, telling the browser to silently upgrade every future request to this host to HTTPS *before it ever leaves the browser*, removing the plaintext bootstrap request that SSL stripping depends on. It only protects visits after the browser has already seen the header once (or the domain is preloaded). (see Day 6)

**HSTS preload list** — A hardcoded list, shipped inside Chromium and Firefox, of domains that get the HSTS upgrade rule applied even on a genuinely first-ever visit. It exists specifically to close HSTS's own trust-on-first-use gap for domains that opt in ahead of time. (see Day 6)

**HTTP-01 challenge** — An ACME challenge proving domain control by having the CA fetch `http://<domain>/.well-known/acme-challenge/<token>` and checking the response body. It's the simplest to automate if you already run a web server on port 80, but it fails outright if port 80 is firewalled, and the ACME spec forbids it for wildcard certificates. (see Day 5)

## I

**Intermediate CA** — A certificate signed by the root, itself allowed (`CA:TRUE`) to sign further certificates, that does the actual day-to-day issuing. Real CAs keep the root almost entirely offline and route all routine signing through an intermediate so that, if the intermediate's key ever leaks, only it (and everything under it) needs revoking — the root, untouched, mints a replacement. (see Day 2)

## K

**Keystore (JKS / PKCS12) & keytool** — Java's own certificate/trust store format, entirely separate from the OS bundle — a cert trusted by the OS is invisible to a JVM until it's imported into the keystore too, using the `keytool` command. It's one concrete example of the general lesson that "the OS trusts it" and "this specific process trusts it" are different facts. (see Day 4)

**keyUsage** — A certificate extension constraining what operations a key may perform, e.g. `keyCertSign, cRLSign` for a CA cert or `digitalSignature, keyEncipherment` for a TLS server leaf. Like EKU and basicConstraints, it's policy enforced by verifiers, not one of the four checks itself. (see Day 2)

## L

**Leaf certificate (end-entity certificate)** — A server or client certificate, signed by an intermediate, marked `basicConstraints: CA:FALSE` so it cannot sign anything else. This is the certificate actually presented to a browser, curl, or (in mTLS) a server. (see Day 2)

## M

**MITM (Man-in-the-Middle)** — An attacker positioned on the network path (DNS poisoning, a rogue Wi-Fi AP, a compromised router, ARP spoofing) who needs, in addition to that position, something to present as a certificate that the victim's client will accept. A rogue CA installed into the victim's trust store is one way to satisfy that second requirement; SSL stripping sidesteps the requirement entirely by making sure TLS never starts. (see Day 6)

**mTLS (mutual TLS)** — TLS where verification runs twice, in mirror image: the client verifies the server's certificate (as in ordinary TLS), and *independently* the server verifies the client's certificate, each against its own trust anchor — which need not be the same CA. Configured in nginx with `ssl_verify_client` and `ssl_client_certificate`. (see Day 4)

## N

**Name match (check 3)** — The third of the four verification checks: does the connection target (a hostname, an email address, a client identity) match one of the names the certificate actually claims, via its SAN — never the deprecated CN. Hostname verification is not part of the TLS protocol itself; it's an application-layer decision made by the TLS library's *caller* after the handshake already succeeded. (see Days 1, 3)

**NewSessionTicket** — A post-handshake TLS 1.3 message carrying an opaque ticket a later connection can present to resume a session (skip the full asymmetric handshake) via the `pre_shared_key` extension. TLS 1.2's equivalent mechanisms are Session IDs and Session Tickets (RFC 5077). (see Day 3)

**NLB (Network Load Balancer)** — An AWS load balancer that can either pass TLS straight through to the backend (which then does its own termination, exactly like nginx in this course) or terminate TLS itself using an ACM certificate, functionally the same termination point as an ALB at a lower network layer. (see Day 5)

**notBefore / notAfter** — The validity-window fields (check 2) on every certificate in a chain, not just the leaf. Current time must fall inside this window on *every* link for the chain to pass check 2. (see Day 1)

## O

**OCSP (Online Certificate Status Protocol)** — A live, per-connection query to the CA asking "is this one serial number still good?" — avoiding a full CRL download, but adding a round trip (and a real privacy leak, since the CA learns what you're connecting to). Browsers have historically soft-failed (proceeded anyway) when an OCSP responder is slow or unreachable. (see Day 5)

**OCSP stapling** — The fix for OCSP's latency and reliability problems: the *server*, not the client, periodically fetches its own signed OCSP response ahead of time and attaches ("staples") it to the handshake it sends every client. The client checks that locally-attached, CA-signed statement instead of making its own live call. (see Day 5)

## P

**Pebble** — Let's Encrypt's own lightweight, test-only ACME server, used throughout Day 5's lab so the real ACME issuance workflow can be exercised entirely offline, without touching a real domain or a real CA. (see Day 5)

**PEM** — A text encoding (base64, wrapped in `-----BEGIN <TYPE>-----`/`-----END <TYPE>-----` lines) used throughout this course for certificates, keys, and CSRs. It's a container format, not a statement about what's inside — the same `.pem` extension holds public certs, private keys, or full chains depending on content. (see Day 1)

**PKI (Public Key Infrastructure)** — The overall system of CAs, certificates, and trust stores that makes name-to-public-key bindings verifiable at scale. Real-world PKI is why a root never signs leaf certs directly — the two-tier (or more) CA structure is a defining feature of how PKI contains the blast radius of a compromised signing key. (see Day 2)

**PSK (pre-shared key)** — The mechanism TLS 1.3 session resumption rides on: a secret derived from an earlier full handshake, referenced via an opaque ticket, letting a later connection skip the asymmetric handshake entirely. If used with 0-RTT (`early_data`), application data can flow in the very first flight, at the cost of replayability, since 0-RTT data lacks the liveness proof an ordinary handshake's `Finished` exchange provides. (see Day 3)

## R

**Reload vs. restart** — The distinction behind zero-downtime certificate rotation. `nginx -s reload` tells the running master process to re-read config and re-open cert files, spawning new workers while old workers finish in-flight connections undisturbed — nothing ever stops listening. A full restart kills every worker immediately and leaves nothing listening until the new process boots, a real (if brief) outage. (see Day 4)

**Revocation** — The decision, made *after* issuance, that a certificate should no longer be trusted even though it's otherwise valid by every one of the four checks — typically because its private key leaked or the underlying domain changed hands. It's a genuinely separate concept layered on top of the four checks, and in practice it's poorly enforced, since CRLs don't scale and OCSP is often soft-failed. (see Day 5)

**Rogue CA** — An attacker-controlled CA (self-signed root, or a real CA whose signing infrastructure was compromised) whose root has somehow gotten into a victim's trust store. Once there, it can sign a certificate for *any* name, and that certificate passes checks 1–3 perfectly and legitimately — only check 4 (trust anchor) stands between the attacker and full acceptance, which is exactly why check 4 is described as the sole barrier against this attack. (see Day 6)

**Root CA** — A self-signed certificate (`Issuer` == `Subject`) whose private key is the single most valuable secret in a PKI. Nothing about the root's own document proves it should be trusted — trust in it is a human/organizational decision made entirely outside the cryptography, which is exactly what check 4 (trust anchor) evaluates. (see Day 2)

**RSA** — The most common asymmetric algorithm for certificate keys, resting on the difficulty of factoring the product of two large primes. A cipher suite naming `RSA` as its authentication field requires the server's certificate to actually hold an RSA key — an ECDSA-only certificate cannot satisfy it. (see Days 1, 3)

## S

**SAN (Subject Alternative Name)** — The X.509 extension listing every name (DNS entries, IPs, occasionally emails) a certificate is actually issued for. It's the complete, authoritative source for check 3 (name match) — if the connection target isn't in this list, check 3 fails regardless of how correct everything else is. (see Days 1–2)

**Self-signed certificate** — A certificate whose `Issuer` equals its `Subject` — it vouches for itself. This isn't inherently untrustworthy (every root CA is self-signed by definition); the only question is whether *that specific* self-signed cert happens to sit in the verifier's trust store, which is exactly check 4. (see Day 1)

**ServerHello** — The server's reply to `ClientHello`: chosen cipher suite and the server's own ephemeral key-exchange value. It's the last plaintext message the server sends in TLS 1.3 — everything after it is encrypted with keys derived right after this message. (see Day 3)

**ServerHelloDone** — A TLS 1.2 message signaling the server has finished its first flight (`ServerHello`, `Certificate`, `ServerKeyExchange`). TLS 1.3 has no equivalent — its single-round-trip design doesn't need an explicit "done" marker.

**ServerKeyExchange** — In TLS 1.2, the message carrying the server's ephemeral ECDHE key plus a signature over it made with the certificate's private key — the 1.2 equivalent of TLS 1.3's `CertificateVerify`, proving live possession of the key. (see Day 3)

**Session resumption** — Skipping a full asymmetric handshake (and re-sending/re-verifying a certificate) on a later connection by reusing secrets from an earlier one. TLS 1.3 does this via PSK/`NewSessionTicket`; TLS 1.2 via Session IDs or Session Tickets. No certificate re-validation happens on a resumed connection — the four checks already ran once, during the original full handshake. (see Day 3)

**Signature chain (check 1)** — The first of the four verification checks: is the signature on this certificate mathematically valid for the claimed issuer's key, and does that hold recursively all the way up the chain? It answers "was this document actually produced by whoever it claims signed it, unaltered" — a question entirely separate from whether you trust whoever's at the top (check 4). (see Day 1)

**SNI (Server Name Indication)** — A `ClientHello` extension carrying the hostname the client intends to reach, needed because a server has to pick which certificate to present before any encryption exists. It travels unencrypted in every mainstream TLS version, including 1.3, which is why a network observer can always see which hostname you're connecting to over HTTPS even when it can't see anything else. (see Day 3)

**Soft-fail** — The historical browser behavior of proceeding with a connection anyway when an OCSP/CRL revocation check is slow, unreachable, or simply skipped, rather than blocking the connection on a CA's uptime. It's the specific gap that lets a revoked-but-not-expired, unstapled certificate still get accepted. (see Day 5)

**ssl_verify_client** — The nginx directive that turns on mutual TLS: it tells nginx to require and verify a client certificate against whatever CA file `ssl_client_certificate` names, running checks 1, 2, and 4 against the client's cert (by default it does not check EKU on the client cert). (see Day 4)

**Subject / Issuer** — Two X.509 fields: `Subject` names the entity a certificate was issued *to* (display purposes — never used for name matching); `Issuer` names who signed it. When `Issuer` equals `Subject`, the certificate is self-signed. (see Day 1)

**Symantec distrust (2017–2018)** — A sustained pattern of improperly validated certificates found in Symantec's CA business through ordinary Certificate Transparency monitoring, not a single breach. Browsers phased in full distrust of Symantec's legacy roots after DigiCert acquired the CA business; it's the case that shows CT's value as a *detection* mechanism even without an attack, and that being a large, longstanding CA grants no immunity once mis-issuance is proven. (see Day 6)

## T

**TLS-ALPN-01 challenge** — An ACME challenge proving domain control over a TLS connection to port 443, using a special `acme-tls/1` ALPN protocol and a self-signed certificate containing the expected token. It fits the niche where 443 is reachable but arbitrary HTTP paths on port 80 aren't servable (e.g. a TCP-passthrough load balancer). (see Day 5)

**TLS 1.2 vs. TLS 1.3** — TLS 1.3 collapses the full handshake into one round trip and encrypts the `Certificate` message (and everything after `ServerHello`); TLS 1.2 needs one extra round trip and sends the certificate in the clear. The four checks run at the same conceptual point in both — the instant the client has the certificate — but on 1.2 a passive observer can read that certificate off the wire, and on 1.3 they can't. (see Day 3)

**TLS handshake** — The protocol exchange doing two jobs at once: proving identity (the server, and in mTLS the client, sends a certificate the other side runs the four checks against, purely locally) and agreeing on keys (an independent ECDHE exchange deriving a shared secret that never travels on the wire). The two are linked by exactly one live signature (`CertificateVerify` in 1.3, folded into `ServerKeyExchange` in 1.2) proving the sender currently holds the certificate's private key. (see Day 3)

**Trust anchor / trust store** — A trust store is a set of certificates (usually self-signed roots) some piece of software has been told, out of band, to treat as check-4 anchors. Different layers keep their own and don't automatically share: the OS bundle (`/etc/ssl/certs/ca-certificates.crt` on Debian/Ubuntu, refreshed by `update-ca-certificates`), language runtimes (Python's `certifi`, Java's keystore, Node's `NODE_EXTRA_CA_CERTS`), and browsers (which increasingly maintain their own root program) are all separate stores — "the OS trusts it" and "this process trusts it" are different facts. (see Day 4)

**Trust-on-first-use (TOFU)** — The structural gap shared by HSTS and certificate pinning: protection only kicks in *after* a client has already seen the relevant rule (an HSTS header, a pinned key) at least once — the very first visit or first pin-setting is still exposed, unless a preload list or pre-shipped pin closes that specific gap in advance. (see Day 6)

## U

**update-ca-certificates** — The Debian/Ubuntu command that rebuilds the OS-level CA bundle from `/usr/local/share/ca-certificates/` (custom certs) and `/usr/share/ca-certificates/` (distro-shipped certs). RHEL/Fedora use the equivalent `update-ca-trust`. A private lab CA that's never been run through this tool stays invisible to anything relying on the default OS bundle. (see Day 4)

## V

**Validity dates (check 2)** — The second of the four verification checks: is the current time within `notBefore`/`notAfter` for *every* certificate in the chain, not just the leaf? It answers "is this vouching still in effect right now" — distinct from whether the vouching was ever legitimate (check 1) or aimed at the right name (check 3). (see Day 1)

## W

**Wildcard certificate** — A certificate covering an entire subdomain pattern (`*.example.com`) rather than one specific host. It can only be issued via the DNS-01 challenge, because HTTP-01 and TLS-ALPN-01 both prove control by reaching one specific host, and a wildcard name isn't a single reachable host at all. (see Day 5)

## X

**X.509** — The standardized document format certificates use: a structured container for a subject name, a public key, an issuer, validity dates, extensions (SAN, basicConstraints, keyUsage, EKU), and the issuer's signature over the whole thing. Every certificate in this course, from a hand-built lab root to an ACME-issued leaf, is an X.509 document. (see Day 1)
