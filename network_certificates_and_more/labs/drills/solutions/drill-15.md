# Drill 15 — Solution: clock skew makes a valid cert look expired

## Hint ladder

1. **Nudge:** the certificate file's bytes did not change between the two
   runs (you checked its checksum). What's the *other* input to a validity
   check besides the certificate itself?
2. **Tool to run:** compare the certificate's real validity window against
   the timestamp you fed `-attime`:
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-15/client01-skew.cert.pem -noout -dates
   docker compose run --rm toolbox date -u -d @1829562708   # or: python3 -c "..." if `date -d` isn't available
   ```
3. **Partial diagnosis:** check 2 (validity dates) isn't comparing the
   cert against some absolute, externally-fetched notion of "now" — it's
   comparing it against whatever the *verifying machine's own clock* reports
   at the moment it runs. Change that clock's reading and you change the
   check's outcome, with zero changes to the certificate.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-15/client01-skew.cert.pem -noout -dates
# notBefore=Jul 31 11:51:48 2026 GMT
# notAfter=Jul 31 11:51:48 2027 GMT
```

The epoch `1829562708` passed to `-attime` in the second run corresponds to
`Thu Dec 23 11:51:48 UTC 2027` — roughly five months **past** `notAfter`.
`-attime` tells `openssl verify` "pretend the current time is this epoch
instead of asking the system clock," which is exactly what a container whose
clock has drifted forward would effectively be doing to every verification
it performs, transparently, with no `-attime` flag needed in real life — the
container just asks its own clock and gets a wrong answer back.

Both verify runs used the *identical* certificate and the *identical* CA
file. The only variable was the verifier's belief about "now." That's
**check 2: validity dates**, and it is deliberately evaluated relative to
local time on whichever machine is doing the verifying — there is no
network call to a trusted time authority baked into X.509 verification. A
container (or a host) with a skewed clock — no NTP sync, a VM that's been
suspended and resumed, a manually-set test clock left in place — will get
check 2 wrong in *either* direction: clock too far ahead makes valid certs
look expired (this drill); clock too far behind makes an *actually expired*
cert look valid, and makes a cert whose `notBefore` hasn't arrived yet look
prematurely valid.

**Fix:** this isn't a certificate problem at all, so re-issuing fixes
nothing. Check and correct the clock of whichever machine is running the
verification:

```
docker compose run --rm toolbox date -u
```

Compare that against a trusted reference. Docker containers don't keep an
independent hardware clock — they read the host's — so a skewed container
clock almost always means the *host* (or, in a cloud VM, the hypervisor) has
an NTP problem, not something specific to the `toolbox` image.

## Lesson

Check 2 is only as trustworthy as the verifier's own clock. This is why
correct time synchronization (NTP) is a *security-relevant* dependency of
TLS, not just an operational nicety — a machine with a wrong clock can be
tricked into accepting an expired certificate, or into rejecting a perfectly
good one, with the certificate itself never touched at all.
