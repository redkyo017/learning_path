# AWS Security Mastery — Journal

One entry per day, written right after teardown while the details are still
fresh. This is a war-story log, not a notes dump: the goal is that six months
from now you can open this file and tell any of these stories cold in an
interview.

## Template (copy per day)

```
### 2026-MM-DD — Day N: <title>

**What I broke:** <the attack/misconfig you exploited, one or two lines —
be specific: which principal, which resource, which API call>

**What stopped it:** <the control that (eventually) blocked it — name the
exact policy statement / rule / finding, not just "IAM">

**The engine trace:** <which door in the evaluation order this attached to
— explicit deny / SCP / resource policy / permission boundary / session
policy / identity policy — and the one-line "why allowed / why denied" trace>

**One thing for an interview:** <the single sentence you'd say to a
hiring manager if they asked "tell me about a time you found a security
gap and fixed it" — this is the line you're banking today's rep for>
```

---

### 2026-08-19 — Day 1: The engine + target deploy (example — read this, then delete or keep as reference)

**What I broke:** The `labs/base` ECS task role shipped with `s3:*` on
`Resource: "*"` instead of just the app bucket. Using the task's own
credentials (fetched from the ECS credential endpoint, not IMDS — this
workload is Fargate), I ran `aws s3 ls` and listed a bucket that has
nothing to do with the app. The role could see resources it had no
business touching.

**What stopped it:** Nothing did, yet — that was the point of the break.
The harden step replaced the wildcard with a scoped identity policy:
`s3:GetObject`/`s3:PutObject` restricted to `arn:aws:s3:::<app-bucket>/*`
only. Re-running the same `aws s3 ls <other-bucket>` call under the
tightened role returned `AccessDenied` (User: arn:...task-role is not
authorized to perform: s3:ListBucket).

**The engine trace:** Identity policy door. No explicit deny, no SCP, no
resource policy on the other bucket granting cross-access, no boundary in
play — the *only* thing that was ever gating this call was the task's own
identity policy, and it was too broad. Fix = shrink the identity policy's
`Resource` element. Nothing else in the evaluation order needed to change.

**One thing for an interview:** "I found that our Fargate task role had
wildcard S3 access left over from bootstrapping, proved it could reach
unrelated buckets, then scoped it to exactly the ARNs the app needs and
re-verified with a real `AccessDenied` — least privilege isn't a policy
you write once, it's a claim you re-test."

---

<!-- Append your daily entries below this line. Keep the four-field
     shape even on days that feel "easy" — the discipline of naming the
     engine door is what makes this different from a generic notes file. -->
