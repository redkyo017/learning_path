# Drill 17 — Solution: HTTP-01 challenge port unreachable

## Hint ladder

1. **Nudge:** the error says `Connection refused` on a very specific port
   number. certbot's `--standalone` plugin has a default port of its own —
   is that the same port the error mentions?
2. **Tool to run:** compare the port in the error against this lab's own
   Pebble config:
   ```
   docker compose run --rm toolbox cat /work/acme/pebble-config.json
   ```
   and check what port certbot's `--standalone` plugin binds to when you
   don't pass `--http-01-port` at all (its documented default is `80`).
3. **Partial diagnosis:** two different, perfectly reasonable defaults —
   certbot's own and Pebble's own — don't happen to agree with each other
   in this lab, and nothing forces them to.

## Full walkthrough

```
docker compose run --rm toolbox cat /work/acme/pebble-config.json
# "httpPort": 5002
```

Pebble is configured (`labs/acme/pebble-config.json`) to validate HTTP-01
challenges by connecting to port `5002` on whatever IP the domain resolves
to — deliberately, so nothing in this lab needs root or
`CAP_NET_BIND_SERVICE` to bind a privileged port. certbot's `--standalone`
plugin, on the other hand, defaults to binding port `80` unless you
explicitly pass `--http-01-port <port>`. Drop that flag, as this drill's
command does, and you get exactly this mismatch: certbot's standalone
server binds and listens happily on `80` (no error on certbot's side at
all — it succeeded at what it was told to do), while Pebble dutifully
tries to connect to `test.local:5002` to check the challenge — and finds
nothing listening there, because nothing is. Hence `Connection refused`,
reported as a **domain-control validation failure**, not a certbot config
error, even though the actual root cause is entirely a local port
mismatch between two tools that were never told to agree.

**Fix:** add the flag back, matching what Pebble is actually configured
to expect:

```
--http-01-port 5002
```

as the guided lab's Part B step 3 command does.

## Lesson

An HTTP-01 "connection refused" doesn't always mean a firewall or a
genuinely unreachable host — it can just as easily mean the validator and
the responder agree on the *domain* but not the *port*. Always check what
port the CA (or, in this lab, Pebble's own config) is actually going to
connect to before assuming the network itself is the problem — this is
the same class of "look at the config, not just the error string" habit
Day 1's exercises were building from the very first drill.
