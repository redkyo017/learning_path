# Capstone 05 — Solution: a cipher-suite family the certificate simply cannot satisfy

## Hint ladder

1. **Nudge:** "faster than RSA" is a claim about the *algorithm*, not
   about what key type your *specific certificate* actually holds. Check
   that before trusting the hardening guide's advice as-is.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem \
       -noout -text | grep "Public Key Algorithm"
   ```
3. **Partial diagnosis:** the certificate's key is RSA. The suite you
   forced requires the certificate's key to be ECDSA. There is no suite
   name that bridges those two requirements.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem \
    -noout -text | grep "Public Key Algorithm"
# Public Key Algorithm: rsaEncryption
```

Reading `ECDHE-ECDSA-AES128-GCM-SHA256` field by field, exactly as Day 3's
theory table walks it: `ECDHE` is the key exchange (irrelevant here — both
sides can do ECDHE regardless of certificate type), `ECDSA` is the
**authentication** field — it names the required key type of the
certificate the server signs `ServerKeyExchange`'s ephemeral parameters
with — `AES128-GCM` and `SHA256` are the bulk cipher and handshake hash
(also irrelevant to this failure). `example.local`'s certificate holds an
RSA key. There is no certificate the server could present that would let
it complete an `ECDHE-ECDSA-*` suite, no matter how the rest of
negotiation goes, because the one certificate it has is the wrong key
type for that entire suite family — this is Day 3 Exercise 2's exact
scenario, now hit for real instead of reasoned about on paper.

The failure surfaces as a generic handshake-failure alert (wording varies
by OpenSSL/curl build — some builds report `no shared cipher` explicitly
on the server side, others a generic `handshake failure` alert on the
client side, as shown here) rather than anything mentioning "wrong key
type" directly, which is exactly why this is easy to misread as a
transient network issue rather than a fundamental mismatch.

**Fix:** either drop the forced `--ciphers` restriction (let curl and the
server negotiate their best mutually supported suite automatically — this
is almost always the right call unless you have a specific, verified
reason to restrict suites) or, if ECDSA suites are genuinely required by
policy, issue a *second*, ECDSA-keyed certificate for this service and
configure the server to offer ECDSA suites against that cert specifically
— never assume any TLS 1.2 cipher-suite name is interchangeable with the
certificate you happen to already have.

## Lesson

A cipher-suite name's authentication field (`RSA` or `ECDSA` in TLS 1.2
naming) is a hard requirement on the certificate's own key type, not a
runtime negotiation knob independent of what's actually deployed. Forcing
a suite family without checking what key type your certificate actually
holds turns "faster" advice into "completely broken" the moment they
don't match — always confirm the certificate's `Public Key Algorithm`
before restricting suites to a specific authentication family.
