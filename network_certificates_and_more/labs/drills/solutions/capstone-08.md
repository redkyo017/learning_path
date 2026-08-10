# Capstone 08 — Solution: "no warning" is not the same as "should be trusted"

## Hint ladder

1. **Nudge:** every single successful connection in this course, on every
   prior day, needed an explicit `--cacert` pointing at your own CA. This
   command has none. Ask why it succeeded anyway.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox grep -c "SecureVault" /etc/ssl/certs/ca-certificates.crt
   docker compose run --rm toolbox grep -c "TLS Mastery" /etc/ssl/certs/ca-certificates.crt
   ```
3. **Partial diagnosis:** `SecureVault` is present in this container's
   default trust store; your real `TLS Mastery` root is not, and never
   has been. Something installed an unfamiliar root into this container.

## Full walkthrough

The tell isn't the certificate's own fields — its subject, issuer, dates,
and SAN could all be completely well-formed, and in this scenario they
are. The tell is the **absence of `--cacert`**. Every prior day of this
course has been explicit, repeatedly, about exactly this: your private
CA is not in any OS, browser, or language-runtime trust store by default
(Day 4's theory section, Part D of Day 4's guided lab, Day 2's Exercise 1
— this point has been made from multiple angles on purpose), which is
*why* every single command that connects to your own CA-issued certs has
passed `--cacert` explicitly. A bare `curl` with no `--cacert` succeeding
against a certificate for a name you've never issued anything for is
itself the anomaly — it should be impossible under this course's normal
rules.

```
docker compose run --rm toolbox grep -c "SecureVault" /etc/ssl/certs/ca-certificates.crt
# 1
docker compose run --rm toolbox grep -c "TLS Mastery" /etc/ssl/certs/ca-certificates.crt
# 0
```

Something installed a root called `SecureVault Trust Root G2` into this
container's **default** trust store — the store `curl` falls back to
whenever no `--cacert` is given. That root is not a real, publicly
audited CA (there is no such thing as verifying that from inside this
lab, but the giveaway is structural, not reputational: it appeared in
*this specific container's* store, for a name nobody registered a
legitimate certificate for through any process this course has ever
used). `vault.internal.local`'s certificate chains up to that root
perfectly — checks 1 through 4 all pass, cleanly, exactly the way any
correctly built rogue-CA chain does. This is precisely today's guided
attack lab's mechanism (`labs/attack/rogue-mitm-demo.sh`), just discovered
cold instead of walked through step by step: build a rogue root, issue a
rogue leaf for the target name, install the rogue root into a trust
store, and every check downstream of that installation passes honestly.

**Fix:** find and remove whatever installed `SecureVault Trust Root G2`
(`ls /usr/local/share/ca-certificates/`, then `rm` the offending `.crt`
and re-run `update-ca-certificates`), and never trust "no warning shown"
as evidence of legitimacy on any machine whose trust store you don't
control and haven't audited — a security incident that successfully
installs a rogue root produces a connection that looks, to every tool
involved, exactly as clean as a real one.

## Lesson

Every one of the four checks can pass and the connection can still be
compromised, because check 4 only asks "is the top of this chain in my
trust store" — it has no way to ask "should that root actually be in my
trust store in the first place." A trust store is only as trustworthy as
whatever process controls what gets installed into it; if that process is
ever compromised (a rogue provisioning step, a coerced install, a
malicious MDM policy, or — as in this capstone — a security drill you
weren't told the details of), a perfectly clean-looking, no-warning
connection is exactly what a successful attack looks like from the
inside.
