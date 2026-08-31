# Day 14 Lab — Log Analysis: Token Failure Scenario

## Goal

Read `log_samples/token_failure.log` and answer the three questions below without
looking at `SOLUTION.md`.  Use only the log file and your knowledge of WSO2 IS
log line anatomy from Day 14 content.

---

## The log file

`log_samples/token_failure.log` contains 17 log lines covering three events:

1. A successful token issuance for one client.
2. A client authentication failure for a second client.
3. An introspection of a token that turns out to be expired.

---

## Questions

**Question 1 — Which client successfully issued a token?**

Identify the client name, the scope granted, and the log line that proves it.

**Question 2 — Which client failed authentication, and why?**

Identify the client name, the reason given in the log, and the two log lines
that describe the failure (hint: there are two WARN lines for the same event).

**Question 3 — What happened during introspection?**

Identify who called introspection, what token state was reported, and the specific
reason the token was rejected.  Quote the exact log line that contains the reason.

---

## Bonus

Write a `grep` command that extracts only the WARN and INFO lines from the log file.
What does the output tell you at a glance?

See `SOLUTION.md` for full answers.
