# Drill 18 — Solution: wrong challenge type for the plugin in use

## Hint ladder

1. **Nudge:** `--preferred-challenges` only *ranks* which challenge type
   to prefer among the ones offered — it doesn't grant your certbot
   *plugin* a new ability it doesn't have. Which plugin is actually
   answering challenges here, and what can it actually do?
2. **Tool to run:** nothing to run against a live Pebble needed for this
   one — read `authz-challenges-excerpt.json` in this directory (what
   Pebble is willing to offer for `test.local`) side by side with
   certbot's own docs/`--help standalone` output (which challenge types
   the `standalone` plugin implements).
3. **Partial diagnosis:** Pebble is offering three challenge types for
   this authorization. The plugin you told certbot to use can only ever
   answer two of them itself.

## Full walkthrough

`authz-challenges-excerpt.json` shows Pebble offering all three challenge
types for `test.local` — `http-01`, `dns-01`, `tls-alpn-01` — exactly as
today's theory table described (Pebble, like a real ACME server, always
offers what it supports; it's the **client** that has to pick one it can
actually satisfy).

certbot's `--standalone` plugin, however, only implements **two** of
those three: it can run a temporary web server to answer `http-01`, and
it can run a temporary TLS listener with the right ALPN extension to
answer `tls-alpn-01`. It has **no** DNS-01 implementation at all — DNS-01
requires actually writing a DNS record somewhere, which is exactly what
certbot's `--manual` mode (with an auth hook) or a DNS-provider-specific
plugin is for, never `--standalone`.

`--preferred-challenges dns` tells certbot "if the CA offers a DNS
challenge, prefer it" — but preference only matters among challenges the
currently active plugin can actually solve. Since `--standalone` can't
solve DNS-01 at all, certbot has no valid combination of
(offered challenge) × (plugin capability) left to attempt, and gives up
before ever contacting Pebble's challenge-response step:

```
Client with the currently selected authenticator does not support any
combination of challenges that will satisfy the CA.
```

**Fix:** either drop `--preferred-challenges dns` and let certbot pick
`http-01` (which `--standalone` *can* solve, and which the guided lab's
Part B already wires up via `challtestsrv`'s DNS-only role), or, if you
genuinely want to exercise DNS-01, switch plugins entirely to
`--manual` with an auth/cleanup hook that calls `challtestsrv`'s
`/set-txt` and `/clear-txt` endpoints — sketched in `day05.md`'s
Exercise 4.

## Lesson

A "wrong challenge type" failure isn't a network problem or a trust
problem at all — it's a **capability mismatch** between what the CA is
willing to accept and what your chosen client plugin actually knows how
to do. Match the plugin to the challenge type you actually intend to
satisfy before touching flags like `--preferred-challenges`.
