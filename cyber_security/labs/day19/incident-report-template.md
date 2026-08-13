# Incident Report — [Incident ID / short name]

Fill this in as you triage `labs/day19`'s `target` ("prod-web01"). Every field maps
directly to a step in the IR lifecycle (see `content/day19-ir-forensics.md` Section 1)
— if a field feels hard to fill in, that's usually a sign to go collect one more piece
of evidence, not to guess.

## 1. Summary

- **Detected by / date:** _(who or what noticed something was wrong, and when)_
- **Affected system(s):** _(hostname, role — e.g. "prod-web01, public web server")_
- **One-paragraph summary:** _(what happened, in plain language, for a reader who
  wasn't in the investigation)_

## 2. Timeline

List every event you can support with a specific piece of evidence, in chronological
order. Each row needs a **source** you could point to if challenged — "I assumed" is
not a source.

| Timestamp (UTC) | Event | Evidence / source |
|---|---|---|
| | | |
| | | |
| | | |

## 3. Initial Access

- **Vector:** _(exactly how the attacker first got in — endpoint, method, payload)_
- **Supporting evidence:** _(file/log path + the specific line(s))_
- **Attacker-controlled indicator(s):** _(IP, user agent, filename — anything you'd
  block or watch for elsewhere)_

## 4. Persistence Mechanisms Found

List every distinct way the attacker arranged to keep access, even after the initial
foothold is closed. One row per mechanism.

| Mechanism | Where found | Eradication step |
|---|---|---|
| | | |
| | | |

## 5. Indicators of Compromise (IOCs)

| IOC | Type (file / account / log / key / hash) | Location |
|---|---|---|
| | | |

## 6. Evidence Preserved (Chain of Custody)

- **What was copied off the live system, and when:** _(what acquisition step ran, and
  the resulting artifact paths)_
- **Order evidence was collected in, and why that order:** _(most volatile first —
  name what you treated as most volatile here and what you treated as safe to collect
  last)_
- **Hashes recorded for integrity:** _(what you hashed, and the hash values)_

## 7. Containment

_(what was done, or should be done, to stop the bleeding without destroying evidence —
e.g. isolate the host from the network, block the attacker's source IP, disable the
vulnerable endpoint)_

## 8. Eradication

_(what was actually removed, for each persistence mechanism in Section 4 — be
specific: file paths deleted, accounts removed, keys revoked)_

## 9. Recovery

_(how the system is safely returned to production — rebuild vs. patch-in-place,
credential/key rotation, monitoring added before trusting it again)_

## 10. Lessons Learned

- **Root cause:** _(the underlying weakness that let initial access happen at all)_
- **What would have caught this sooner:** _(a detection rule, an alert, a control)_
- **One concrete follow-up action:** _(something with an owner and a deadline, not
  just "be more careful")_

## Sign-off

- **Investigator:** ___________________
- **Date closed:** ___________________
