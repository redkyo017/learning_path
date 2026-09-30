# Drill 09 — Solution: protocol-version mismatch

## Hint ladder

1. **Nudge:** `tlsv1 alert protocol version` names nothing about
   certificates, ciphers, or hostnames. It's an alert the *server* sent.
   Where in the handshake could a failure happen before *any* of those even
   come into play?
2. **Tool to run:** check what versions each side was actually configured
   to speak. Re-read the version flags in `repro.sh`:
   ```
   grep -E 'tls1_1|tls1_2|tlsv1|tls-max|no_ssl3|no_tls1|SECLEVEL' /work/drills/drill-09/repro.sh
   ```
3. **Partial diagnosis:** the server explicitly disabled everything below
   TLS 1.2 (`-no_ssl3 -no_tls1 -no_tls1_1`). The client explicitly capped
   itself at TLS 1.1 (`--tlsv1.0 --tls-max 1.1`). Compare those two ranges.

## Full walkthrough

The server's allowed range is **TLS 1.2 and up** (everything below 1.2 was
explicitly disabled). The client's allowed range is **TLS 1.0 through 1.1**
(explicitly capped with `--tls-max 1.1`). Those two ranges do not overlap
anywhere:

```
server:  [-------- 1.2 --------- 1.3 ---]
client:  [-- 1.0 -- 1.1 --]
overlap: (none)
```

The client sends a `ClientHello` offering at most TLS 1.1 (legacy version
field `0x0302`, no `supported_versions` extension reaching 1.2+). The
server has no version it's willing to speak in that range, so it answers
with a fatal `protocol_version` alert (70) and closes. curl reports that
alert as `error:0A00042E:SSL routines::tlsv1 alert protocol version`, exit
code `35` (`CURLE_SSL_CONNECT_ERROR`). On the server's side of the same
output, OpenSSL logs its own view of it: `0A000102 ... unsupported
protocol`.

This happens during the very first exchange — **before any `Certificate`
message is ever sent**. None of the four verification checks from Day 1
get a chance to run, because there's no certificate yet to check.

**Why the `--ciphers 'DEFAULT:@SECLEVEL=0'`?** A modern OpenSSL 3 client
won't offer TLS 1.0/1.1 at its default security level. Remove that flag
and curl fails *locally* with
`error:0A0000BF:SSL routines::no protocols available` — it refuses before
sending anything, so the server's floor never comes into play. That's a
different failure: a client-side policy refusal (security level /
`MinProtocol`), not a negotiation mismatch. The flag makes the client
behave like a genuinely old client so you can see the server reject it.

**Exit codes:** `repro.sh` ends each command with `|| true`, so the script
always exits `0`. The `35` is curl's own code, printed in the
`curl: (35)` prefix.

**Fix:** raise the client's ceiling to overlap with the server's floor —
drop `--tls-max 1.1` (and the SECLEVEL override) entirely, and curl will
negotiate the highest mutually supported version:

```
docker compose run --rm toolbox bash -c \
  "openssl s_server -accept 8444 \
     -cert /work/ca/intermediate/certs/example.local.cert.pem \
     -key  /work/ca/intermediate/private/example.local.key.pem \
     -no_ssl3 -no_tls1 -no_tls1_1 -naccept 1 -quiet -www & \
   sleep 1; \
   curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
        --resolve example.local:8444:127.0.0.1 \
        https://example.local:8444/; \
   wait"
# A TLS 1.3 handshake, then s_server's -www status page as the body.
```

## Lesson

A version-mismatch failure happens strictly *before* the certificate
exchange — it's not one of the four checks failing, it's the handshake
never reaching the point where a certificate could be sent. If you see a
version/protocol error, look at what versions *each side* allows, not at
the certificate. And tell the two shapes apart: `alert protocol version`
means the server said no; `no protocols available` means your own client
refused before it ever connected.
