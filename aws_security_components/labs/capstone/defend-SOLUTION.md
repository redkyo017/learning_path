# IR Runbook — Defend: SOLUTION

Record your actual run's outputs here (redact account IDs). This file
mirrors `labs/day12/SOLUTION.md`'s technical expected-output tables,
scoped to the capstone narrative phases — fill in the checkboxes as
you complete each phase against your own account. If you want a fully
worked example of expected command output (not just the fill-in
template below) before you run your own, see `labs/day12/SOLUTION.md`'s
"Success signal — attack now blocked" section — it has the exact
credential-export steps and sample `AccessDenied`/`UnauthorizedOperation`
messages this file's Phase 4 template asks you to reproduce.

## Phase 1 — CONTAIN — completion record

- [ ] Leaked access key deactivated — `InvalidClientTokenId` confirmed on retry
- [ ] Leaked access key deleted — `InvalidAccessKeyId` confirmed on retry
- [ ] Break-glass `Deny *` attached to task role — app `/whoami` now 5xx (confirmed intentional)
- [ ] (optional) ECS service scaled to 0 — task count confirmed 0

**Timestamp contain started:** `____`
**Timestamp contain completed:** `____`
(Time-to-contain is worth tracking — real IR is scored partly on this.)

## Phase 2 — ERADICATE — completion record

- [ ] `terraform plan` reviewed in `labs/day12/` — confirmed only the
  expected resources (Deny policy, WAF Web ACL + association,
  leaked-user fixture if enabled) are in the plan
- [ ] `terraform apply` completed
- [ ] Break-glass policy removed (`aws iam delete-role-policy
  --policy-name emergency-quarantine`)
- [ ] App-code SSRF-fix follow-up filed (out of Terraform's reach —
  note where you filed it, e.g. `journal.md` or a tracked TODO)

## Phase 3 — RECOVER — completion record

- [ ] ECS desired count restored
- [ ] Force-new-deployment completed
- [ ] Allow path re-tested and passing: `/whoami` → 200, `/fetch?url=https://example.com` → 200
- [ ] App's own S3/DynamoDB access within its real prefix confirmed still working

## Phase 4 — blocked-signal record (the required proof)

Fill in the ACTUAL command output you got, not the expected shape —
this is the evidence the incident is closed.

**Credentials first — no `stolen-creds` profile exists anywhere.**
These are STS temporary credentials (key + secret alone will fail on
an invalid-token error, independent of any policy — a session token is
required too). Export all three, matching Day 11's `attack.sh`
pattern:
```
$ export AWS_ACCESS_KEY_ID="<stolen AccessKeyId>"
$ export AWS_SECRET_ACCESS_KEY="<stolen SecretAccessKey>"
$ export AWS_SESSION_TOKEN="<stolen SessionToken>"
```

```
SSRF re-run:
$ curl -s -o /dev/null -w "%{http_code}\n" "http://<alb_dns_name>/fetch?url=http://169.254.170.2/v2/credentials/<GUID>"
<paste actual result>

s3:DeleteObject re-run:
$ aws s3api delete-object --bucket <bucket> --key app-data/anything
<paste actual result>

s3:GetObject-outside-prefix re-run:
$ aws s3api get-object --bucket <bucket> --key some/other-prefix/file /tmp/out
<paste actual result>

dynamodb:Scan re-run:
$ aws dynamodb scan --table-name <project>-appdata
<paste actual result>

kms:Decrypt direct-call re-run:
$ aws kms decrypt --ciphertext-blob fileb://exfiltrated.bin
<paste actual result>

ec2:RunInstances --dry-run pivot re-run (Day 11 may have recorded DryRunOperation
or UnauthorizedOperation for the PRE-fix call — this POST-fix re-run should be
UnauthorizedOperation, not AccessDenied: EC2's dry-run convention is its own,
DryRunOperation = would have succeeded, UnauthorizedOperation = denied):
$ aws ec2 run-instances --dry-run --instance-type m5.24xlarge --image-id ami-00000000000000000
<paste actual result>
```
Unset the exported credentials once done:
`unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`

**Pass condition for this capstone:** every line above shows
`AccessDenied` (S3/DynamoDB/KMS lines), `403` (WAF line), or
`UnauthorizedOperation` (EC2 line only — not `AccessDenied`, see the
note above). If any line instead succeeds, eradication is incomplete —
go back to Phase 2, do not mark this lab done.

## Phase 5 — retro (fill in your own answers, not a canned one)

1. Door the attacker used:
2. Single earlier control that would have prevented the damage, and why (engine-order argument):
3. Control that closes the entry point, and why network layer couldn't:
4. Did Day 9's automated response fire? If not, why not:
5. What's still open after today:

## CERT-MAP self-assessment — record your scores

| Domain | Score (1–4) | If < 3, which day you're re-running |
|---|---|---|
| 1. Threat Detection and Incident Response | | |
| 2. Security Logging and Monitoring | | |
| 3. Infrastructure Security | | |
| 4. Identity and Access Management | | |
| 5. Data Protection | | |
| 6. Management and Governance | | |

## Final sweep — completion record

- [ ] `labs/day12` destroyed
- [ ] Every other applied day module destroyed
- [ ] `labs/base` destroyed (first and only time this sprint)
- [ ] GuardDuty confirmed off in every region checked
- [ ] Security Hub confirmed off in every region checked
- [ ] Macie confirmed off in every region checked
- [ ] Detective confirmed off/no graphs, in every region checked
- [ ] Every customer-managed KMS key scheduled for deletion (7-day
  window noted, not treated as a leftover)
- [ ] Cross-region sweep run (`labs/day12/README.md` § 6) — all lists empty
- [ ] Billing dashboard checked 24–48h later, no unexpected charge
