# Day 6 — Rogue-CA attack lab

This directory holds the assets for Day 6's guided attack lab: build a
rogue CA, use it to mint a fraudulent `example.local` certificate, present
that certificate to a client, and watch the client trust it — then defend
with certificate pinning and watch the exact same rogue certificate get
rejected.

## Why this needs no `docker-compose.yml` changes at all

Every earlier day's labs reached the real `nginx` service across the
`certlab` network. This lab deliberately does **not** touch `nginx` or
`docker-compose.yml` — the "attacker" is `openssl s_server`, run **inside
the same `toolbox` container** that also plays the client. `curl`'s
`--connect-to example.local:8443:127.0.0.1:<port>` then redirects the
*destination* of the connection from the real `nginx` service to that
`s_server` process on `toolbox`'s own loopback, while still sending
`example.local` as SNI and the `Host` header — exactly the same
`--connect-to` idiom every prior day used to reach `nginx`, just pointed at
a different destination. This is the same trick a real MITM (a poisoned
DNS record, a rogue Wi-Fi access point, a compromised router) uses to get
your traffic to *it* instead of the real server — nothing about the
victim's request URL, SNI, or `Host` header ever has to change for the
attack to work.

## Files

- **`rogue-mitm-demo.sh`** — the single, self-contained script Day 6's
  guided lab runs. It builds a rogue root CA and a rogue `example.local`
  leaf cert (entirely separate from `ca/` — your real course CA is never
  touched), starts the attacker `s_server`, shows a `curl` attempt failing
  *before* the rogue root is trusted, installs the rogue root into
  **this one container's** trust store, shows the identical `curl` command
  now succeeding (the "aha"), then defends by pinning the REAL
  `example.local` leaf's public key and shows the rogue cert fail against
  that pin even though it's still "trusted" by the polluted store.

  Run from `labs/`:
  ```
  docker compose run --rm toolbox bash /work/attack/rogue-mitm-demo.sh
  ```

  Requires Day 2's CA and `example.local` cert to already exist
  (`ca/intermediate/certs/example.local.cert.pem`) — the script reads that
  real cert only to extract its public key for the defense step; it never
  modifies it.

## Why everything has to run in ONE container invocation

`update-ca-certificates` (used to "install" the rogue root) mutates
`/etc/ssl/certs` inside whatever container it runs in. `docker compose run
--rm` tears the container down the instant the command exits, so that
mutation never survives past a single invocation. Splitting the
build/install/attack/defend steps across separate `run --rm` calls (the way
most other days' commands are shown one-per-line) would lose the installed
rogue root between steps and the "aha" would never actually reproduce. That
is the one deliberate structural difference between this script and every
prior day's guided lab: it has to be one script, not a sequence of
separately copy-pastable commands.

## Cleanup

Nothing here persists. Because `docker compose run --rm` always removes the
container afterward, the rogue root you "installed" and every rogue key/cert
this script generated under `attack/rogue/` on the *container* side
disappear the moment the script exits — only the files under
`labs/attack/rogue/` on the **host** (bind-mounted) survive, and they are
inert outside a container that has actually run `update-ca-certificates`
against them. Nothing about your real `ca/` CA, your real `example.local`
cert, or any other day's lab state is ever touched.
