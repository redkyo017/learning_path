# Day 5 — Security Fundamentals: SASL/SCRAM, ACLs, mTLS

## Learning objectives

By the end of today you should be able to:
- State the distinction between authentication and authorization precisely,
  and say which Kafka mechanism (SASL/SCRAM, mTLS, ACLs) belongs to which
  side of that line.
- Explain why SASL/SCRAM doesn't send a plaintext password over the wire,
  and what protection that does and doesn't give without TLS.
- Explain why an authorizer denies by default, and describe the
  chicken-and-egg problem that creates when bootstrapping a fresh cluster.
- Diagnose "connects fine but every operation is denied" as an
  authorization problem, not an authentication one.
- Describe mTLS as authentication structurally parallel to SASL/SCRAM — a
  certificate's identity instead of a password-derived credential — feeding
  the same authorizer and ACL model.

## Reference material

- Kafka Security Overview — how authentication, encryption, and
  authorization compose on a listener.
- SASL/SCRAM docs — mechanism config, credential storage via
  `kafka-configs.sh --entity-type users`, and the handshake itself.
- Authorization and ACLs docs — the `Authorizer` interface, `kafka-acls.sh`,
  and the principal/resource/operation model every request is checked
  against.
- SSL/TLS docs — encrypted transport, and `ssl.client.auth`, the setting
  that turns plain TLS into mutual TLS (mTLS).

## Theory

### Authentication vs. authorization

Every secured request answers two independent questions, in order:

1. **Authentication — "who are you?"** Established once, when a
   connection/session starts, via whichever mechanism the listener uses:
   SASL/SCRAM (username plus a password-derived credential), mTLS (a
   certificate whose subject becomes the principal), or nothing at all on
   an unauthenticated `PLAINTEXT` listener, which Kafka represents as
   `User:ANONYMOUS`.
2. **Authorization — "what are you allowed to do?"** For *every request* on
   that connection — produce, fetch, join a group, alter configs — the
   broker asks its `Authorizer`: does *this principal* have a grant for
   *this operation* on *this resource*? The answer comes from ACL entries
   stored for that principal/resource pair.

These are separate systems that happen to run in sequence on one
connection. A principal can be fully authenticated — valid credentials, no
error — and still have zero permissions, because authentication only
answers *who*, and authorization is a distinct lookup against *what that
identity may do*. Conflating the two is the most common conceptual error in
operating a secured cluster; today's labs are built to make you feel that
difference directly.

### How SASL/SCRAM avoids sending a plaintext password

A naive check has the client send its password for the broker to compare
against a stored copy — meaning an eavesdropper who captures the exchange
could replay it forever. SCRAM (Salted Challenge Response Authentication
Mechanism) avoids this with a challenge-response protocol over a **salted
hash**: the broker stores only a salt and a hash of `password + salt`
(what `kafka-configs.sh --add-config 'SCRAM-SHA-256=[password=...]'`
computes), and the client/broker exchange nonces and hashed proofs derived
from that credential — never the password itself, and never the same proof
twice.

This makes SCRAM resistant to a **passive eavesdropper** even without TLS —
a real protection, and stronger than sending a raw password. It does
**not** protect against an **active man-in-the-middle** intercepting or
impersonating the broker; that gap is what TLS closes, by verifying server
(and, with mTLS, client) identity and encrypting the channel. Production
deployments run SASL/SCRAM *over* TLS (`SASL_SSL`) to get both properties
together. Today's lab uses `SASL_PLAINTEXT` deliberately, as a teaching
simplification for an isolated local Docker network — not a pattern to
carry into anything real.

### Deny-by-default, and the bootstrap chicken-and-egg problem

Kafka's `StandardAuthorizer` follows **deny-by-default**: for a given
principal/resource/operation, no matching ACL means denied — there's no
implicit baseline access tier. This is the only sane default (allow-by-
default would leave every new identity with unknown access), but it
creates a real bootstrapping problem: **the first ACL grant on a fresh
cluster must be created by someone, and that someone needs a way to talk
to the authorizer before any ACL exists to authorize them.**

Every deny-by-default system hits this same shape of problem and solves it
by carving out one trusted path that exists *outside* the normal ACL-checked
flow. Kafka's answer is `super.users`: a fixed list of principals,
configured directly on the broker rather than as ACL entries, that bypass
the authorizer entirely and can create the first real ACLs for everyone
else. Today's plan spells out this lab's specific mechanism (including why
`User:ANONYMOUS` appears as a superuser and how it's guarded); the general
shape to internalize is that **something must be trusted unconditionally
before any ACL exists**, and how tightly you scope that trust is itself a
security decision.

### mTLS as authentication, parallel to SCRAM

Mutual TLS authenticates using X.509 certificates instead of a password-
derived credential: client and broker each present a certificate signed by
a CA the other trusts and verify the signature cryptographically. The
certificate's subject (commonly its CN) becomes the principal — `CN=client`
authenticates as `User:client`, the exact same principal shape ACLs are
written against for a SASL/SCRAM user. mTLS and SASL/SCRAM are two
different answers to the same question, "who are you?" — both feed the
*same* authorizer and ACL model, and nothing about how you write ACLs
changes based on which one established the principal.

## Best practices

- **Least privilege on every ACL grant** — scope to the specific topic (or
  a tight prefix) and operation actually needed (`Read`+`Describe` on
  `orders`, not `Read` on `*`). A wildcard grant is a standing liability
  nobody revisits until it's exploited.
- **Prefer mTLS or SASL/SCRAM over `PLAINTEXT`/`SASL_PLAINTEXT`** for
  anything beyond an isolated local lab. `PLAINTEXT` has no authentication;
  `SASL_PLAINTEXT` authenticates but doesn't encrypt, leaving it open to
  active MITM. Real deployments run `SASL_SSL` or `SSL` (mTLS) so verified
  identity and an encrypted channel hold together.
- **Treat security as done from day one, not bolted on later.** This is a
  direct callback to a mistake the plan flags explicitly: broker-level auth
  and authorizer settings can't be hot-added to a running KRaft cluster the
  way a topic config can — today's cluster needed a full rebuild
  (`docker compose down -v`) precisely because security was retrofitted
  instead of present from the first `up`. In a real deployment that's far
  costlier than a local rebuild. Decide your security posture before the
  first broker starts.
- **One credential per service/application**, not a shared credential reused
  across callers — otherwise least privilege is theoretical, since you can't
  scope or revoke access per-caller.

## Common pitfalls

- **Confusing "authenticated" with "authorized."** A clean SCRAM login says
  the credential was valid, nothing about what it can do — `app-consumer`
  in today's lab authenticates fine and still gets denied every read
  (`SaslAuthenticationException` vs. `TopicAuthorizationException` are
  different failure modes).
- **Forgetting ACL checks happen per-request, not just at connect time.**
  Revoking an ACL doesn't disconnect anyone — the authorizer re-evaluates on
  the client's next request. Good for incident response (revocation is
  immediate, no forced disconnect needed); bad if you assume a running
  client is "already past" the check.
- **Leaving a legacy `PLAINTEXT` listener open "temporarily."** Today's
  cluster keeps `PLAINTEXT` open deliberately, scoped to `localhost` for a
  time-boxed bootstrap purpose. "We'll close it once everything's migrated"
  is exactly how unauthenticated access outlives its justification — track
  closing it as an explicit follow-up.
- **Assuming a topic ACL covers the consumer group, or vice versa.**
  Consuming requires *both* `Read` on the topic *and* `Read` on the
  consumer-group resource, checked separately — granting only one and
  assuming it's enough is a common "I already fixed it, why still denied?"

## Real-world use cases

1. **Onboarding an external system to a shared cluster.** A new partner or
   internal team's service should get a dedicated SASL/SCRAM (or mTLS)
   identity plus ACLs scoped to exactly what it needs — never a shared
   admin/superuser credential handed out to unblock things quickly. A
   scoped identity bounds blast radius and stays independently auditable
   and revocable.
2. **Incident response on a compromised credential.** Revoke that specific
   principal's ACLs immediately (`kafka-acls.sh --remove --allow-principal
   User:<service>`) — today's chaos lab is exactly this — without touching
   any other consumer. Because authorization is per-request, revocation
   takes effect on the compromised service's very next call; rotating the
   underlying credential is a separate follow-up.
3. **Access audits before compliance review.** `kafka-acls.sh --list`
   against every principal directly answers "who can read/write what, and
   why" — but only if ACLs were granted narrowly per service rather than via
   a few broad, shared credentials that make the honest answer "we're not
   sure."

## Worked example: a support-ticket walkthrough

**Ticket:** "Our consumer authenticates fine — no login errors — but it
never receives messages from `orders`, and we're seeing
`TopicAuthorizationException` after a while."

1. **Auth vs. authz?** A `SaslAuthenticationException` (or handshake
   failure) means authentication. A `TopicAuthorizationException` surfacing
   *after* the client is already connected and polling means authentication
   already succeeded — this is purely authorization. The ticket already
   tells us: no login errors, exception is `TopicAuthorizationException`.
2. **Confirm the principal.** Check the client's `username=` in its
   `sasl.jaas.config` (or certificate CN for mTLS) — that's the exact
   `User:<name>` the authorizer checks against. A typo or stale credential
   pointing at the wrong principal is a common, easy-to-miss root cause.
3. **List current ACLs** for that principal with `kafka-acls.sh
   --bootstrap-server <broker>:<sasl-port> --command-config <admin-creds>
   --list`. Look for both a `Read`/`Describe` grant on the `orders` topic
   *and* a separate `Read` grant on the consumer-group resource
   (`group.id`).
4. **Identify what's missing.** The most common version: one of the two
   grants exists, the other doesn't — e.g. topic access is fine but nobody
   granted `Read` on the group, so the client can't join/commit offsets,
   and the symptom is still "no messages ever arrive."
5. **Grant it** with `kafka-acls.sh --add --allow-principal User:<name>
   --operation <Read|Describe> --topic <name>` or `--group <name>`, using
   admin/superuser credentials.
6. **Verify without restarting the client.** Since authorization is checked
   per-request, the already-running consumer should recover on its next
   poll — no redeploy needed. If it doesn't, re-check the resource name and
   principal for a mismatch (a typo'd topic name is the next most likely
   cause).

## Exercises

1. A client connects over `SASL_PLAINTEXT` with valid SCRAM credentials, no
   authentication error logged. Five seconds later `poll()` throws
   `TopicAuthorizationException`. Authentication failure, authorization
   failure, or could it be either? Justify from the symptom alone.
2. True or false, with justification: a principal with `Read`+`Describe` on
   topic `orders` can successfully consume `orders` in a consumer group.
3. A teammate says: "We're using SASL/SCRAM, so we're already protected
   against network attackers, no need for TLS." What's incomplete about
   this? Name the attack it does protect against and the one it doesn't.
4. On a brand-new cluster with an authorizer configured and no ACLs yet, an
   admin runs `kafka-acls.sh --add` over a plain `PLAINTEXT` connection and
   it succeeds. Explain why, given deny-by-default, and name the specific
   broker setting that makes it possible.
5. While a consumer is actively consuming, an operator revokes its `Read`
   ACL. Does its current connection drop immediately, keep working until
   reconnect, or fail on its next request without disconnecting? Explain.
6. An mTLS client with certificate `CN=billing-svc` needs read access to
   topic `invoices`. What principal name does the ACL use, and does using
   mTLS instead of SASL/SCRAM change how the `kafka-acls.sh` command looks?

## Answers

1. **Authorization failure.** Had authentication failed, the client would
   never reach a state where it can call `poll()` — it would fail during
   session setup with a `SaslAuthenticationException`. Reaching the poll
   loop cleanly means a principal was already established; the exception
   moments later is the separate per-request authorization check finding no
   matching ACL.
2. **False.** Topic-level `Read`/`Describe` authorizes reading the topic's
   partitions, but consuming via a group also needs a separate `Read` grant
   on the *consumer-group* resource — checked independently. Without it,
   expect a `GroupAuthorizationException` even with fine topic access.
3. **It conflates two threat models.** SCRAM's salted challenge-response
   protects against a **passive eavesdropper** — genuinely true, even
   without TLS. It does not protect against an **active
   man-in-the-middle**, who can intercept or impersonate the broker; without
   TLS there's no verification of the broker's identity or encryption of
   the channel. TLS closes that second gap; SCRAM alone answers only the
   eavesdropping threat.
4. **The `super.users` configuration** (`KAFKA_SUPER_USERS`), which includes
   `User:ANONYMOUS` — the principal for any unauthenticated `PLAINTEXT`
   connection. Superusers bypass the ACL check entirely rather than holding
   an ACL that grants everything; this is the general solution to the
   bootstrap problem — some principal must be trusted unconditionally,
   outside the ACL flow, to create the first ACLs for everyone else.
5. **Fails on its next request, without disconnecting.** The TCP connection
   and session stay intact; authorization isn't tied to connection
   lifecycle. The next `Fetch` request is re-evaluated against the now-empty
   ACL set and denied (`TopicAuthorizationException` on the next `poll()`),
   which is exactly why ACL revocation is an effective, immediate
   incident-response tool.
6. **`User:billing-svc`**, taken from the certificate's CN, and the command
   is identical in shape to a SASL/SCRAM principal's grant (`--add
   --allow-principal User:billing-svc --operation Read --topic invoices`).
   The authorizer has no awareness of which mechanism produced a principal
   — mTLS and SASL/SCRAM both funnel into the same authorization check.

## Hands-on lab

Today's lab spans a few files:

- `kafka_practice/docker/generate-certs.sh` generates the CA, broker, and
  client keystores/truststores for the mTLS portion. Treat its password and
  CA as lab-only, never reused.
- `kafka_practice/labs/config/local-sasl.properties` and
  `kafka_practice/labs/config/admin-superuser.properties` are the Java-track
  SASL/SCRAM configs — credentials are carried in a single
  `sasl.jaas.config` JAAS string.
- The Go track has equivalent files under `kafka_practice/labs-go/config/`
  with the same bootstrap servers and mechanism, but no JAAS string — flat
  `sasl.username`/`sasl.password` keys instead, since there's no JAAS layer
  to configure. Same credentials, different shape.

Follow **Day 5** in
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` for
the exact commands: rebuilding the cluster with the new `SASL_PLAINTEXT`
listener and authorizer, creating SCRAM users, confirming deny-by-default,
granting ACLs, the mTLS certificate lab, the ACL-revocation chaos lab, and
the Phase 1 closed-book review questions. This document covers the *why*;
the plan has the exact commands, ports, and file contents.

## Journal template

```
## Day 5 — Security fundamentals
Key idea in my own words: ...
What confused me: ...
```
