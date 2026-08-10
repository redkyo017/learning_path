# Capstone 03 — Solution: expired, whether you asked for it or not

## Hint ladder

1. **Nudge:** nothing about *reusing* an old cert changes anything about
   what its own document says about itself. Read the dates before
   touching anything else.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/old-report.local.cert.pem -noout -dates
   ```
3. **Partial diagnosis:** `notAfter` is nearly two years before today. This
   is entirely independent of who signed it or what name it's for.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/old-report.local.cert.pem -noout -dates
# notBefore=Jan  1 00:00:00 2023 GMT
# notAfter=Apr  1 00:00:00 2023 GMT
```

Both dates are in the past — this certificate's entire three-month
validity window opened and closed nearly two years ago. `openssl verify`
reports **error 10, certificate has expired**, which is **check 2:
validity dates**, and only that check. Nothing here says anything about
the signature (it's a completely legitimate certificate, correctly signed
by your real intermediate CA — you'd see `error 20` instead if the issue
were trust or chain-related) or the name (the SAN correctly says
`old-report.local`, matching what it was issued for). The document itself
is exactly as valid as it ever was for the three months it was actually
current; the calendar has simply moved on since then.

This is Day 1 drill-04's exact mechanism, just self-inflicted by *reusing*
an old artifact instead of being handed a pre-baked expired fixture — the
scenario this capstone is really testing is recognizing "this cert used to
work" as no evidence at all about whether it still does, and reaching for
`-dates` before assuming a chain or trust problem.

**Fix:** issue a fresh certificate for whatever this service actually is —
`ca/issue-server-cert.sh <real-cn> <real-cn>` — never redeploy an
old cert just because it once worked and the config still references it.

## Lesson

A certificate's validity window is a fixed, closed interval baked into the
document at issuance time — it has no concept of "still basically fine"
or "worked last time I checked." Reusing an old cert/key pair someone
finds lying around a config directory is exactly how expired-certificate
incidents actually happen in production; the fix is always "issue a new
one," never "extend the old one."
