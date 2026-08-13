# Day 10 Lab — Solution / Expected-Output Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against
`sample-repo/`/`cyberlab/day10-vulnapp:latest`, or your own repos/images.

## A note on how this file was produced

Every other day-lab's `SOLUTION.md` in this path is captured from a real, live run of
the lab. This one is **not**: this task's build/validation step was scoped to static
checks only (`docker compose config -q` against [`docker-compose.yml`](docker-compose.yml),
which passed), and today's five scanners (`gitleaks`/`trufflehog`/`trivy`/`grype`/
`syft`) aren't installed anywhere in this environment by default (see README.md's
Toolbox section). The output below is therefore **expected output**, reconstructed from
each tool's real, documented report format and each secret's/CVE's actual known
properties (the AWS/Stripe key shapes gitleaks' own default rules match on; the real
NVD-published CVSS scores for `CVE-2020-1747`/`CVE-2019-11324`) — not a pasted capture.
Exact byte-for-byte formatting (banner art, timestamps, column widths) will differ
slightly by tool version; the **substance** (which secrets, which CVEs, which
severities) is accurate and is what you should expect to see when you actually run this
lab yourself with the tools installed per README.md.

## Step 1 — gitleaks findings

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "gitleaks detect --source /loot/day10/sample-repo --no-git -v"
```

Expected findings (one block per secret, gitleaks `-v` format):

```
Finding:     AKIA_IOSFODNN7_EXAMPLE
Secret:      AKIA_IOSFODNN7_EXAMPLE
RuleID:      generic-api-key (matched via the `AWS_ACCESS_KEY_ID=` context keyword)
File:        .env
Line:        9

Finding:     wJalrXUtnFEMI_K7MDENG_bPxRfiCY_EXAMPLE_FAKE
Secret:      wJalrXUtnFEMI_K7MDENG_bPxRfiCY_EXAMPLE_FAKE
RuleID:      generic-api-key (matched via the `AWS_SECRET_ACCESS_KEY=` context keyword)
File:        .env
Line:        10

Finding:     sk_live_51NfZTBHcgp_EXAMPLE_FAKE_KEY_DONOTUSE_00
Secret:      sk_live_51NfZTBHcgp_EXAMPLE_FAKE_KEY_DONOTUSE_00
RuleID:      generic-api-key (matched via the `api_key:` context keyword)
File:        config/fake_srts.yml
Line:        8

NOTE: these three values are deliberately not byte-for-byte identical to
AWS's/Stripe's real key formats -- a few characters were swapped for
underscores so this repo doesn't trip GitHub's own push-protection secret
scanning (which blocks a push containing a string matching those exact
vendor patterns, regardless of how clearly "FAKE"/"EXAMPLE" the rest of the
string is). They're still secret-shaped enough, next to their real
`AWS_ACCESS_KEY_ID=`/`AWS_SECRET_ACCESS_KEY=`/`api_key:` context keywords,
for gitleaks' keyword+entropy rules to flag them -- just under
`generic-api-key` rather than the vendor-specific `aws-access-token`/
`aws-secret-key`/`stripe-access-token` rule names a byte-for-byte match
would hit. Which exact rule fires is version-dependent either way (see the
note at the bottom of this file); the finding itself is what matters for
the drill.

Finding:     correct-horse-battery-staple-2024
Secret:      correct-horse-battery-staple-2024
RuleID:      generic-api-key
File:        config/fake_srts.yml
Line:        10

Finding:     SuperSecretPass123!Fake
Secret:      SuperSecretPass123!Fake
RuleID:      generic-api-key (matched via the `password:` context keyword)
File:        deploy/notes.txt
Line:        5

10:00AM WRN leaks found: 5
```

**The leaked secret + fix, per file (Drill 1's answer worked out in full):**

| File | Secret | Immediate fix | Structural fix |
|---|---|---|---|
| `.env` | AWS access key ID + secret access key | Deactivate/rotate the key pair in IAM immediately | Workload should assume an IAM role (no static key); if unavoidable, AWS Secrets Manager |
| `config/fake_srts.yml` | Stripe `sk_live_...` key | Roll the key in the Stripe dashboard | AWS Secrets Manager (supports rotation hooks for third-party API keys) |
| `config/fake_srts.yml` | Flask `secret_key` | Regenerate a new random value | SSM Parameter Store `SecureString` |
| `deploy/notes.txt` | SSH password | Rotate the password immediately | Switch to SSH key-based auth; no password to store at all |

Note gitleaks also flags the **commented-out** `legacy_db_password` line in
`config/fake_srts.yml` if scanning includes comments (depends on ruleset/version) —
exactly Section 1's point about secrets sprawl including dead code nobody scrubbed, not
just live config.

## Step 2 — trufflehog findings (filesystem mode, no live verification)

```sh
docker compose exec attacker sh -c "trufflehog filesystem /loot/day10/sample-repo --no-verification"
```

Expected: the same handful of secrets, reported in trufflehog's own JSON-per-line (or
human-readable, depending on flags) format, each tagged with a detector name (e.g.
`AWS`, `Stripe`) and `Verified: false` (since `--no-verification` was passed and none of
these are real live credentials). Two tools agreeing on the same findings, via different
detection engines, is the expected and useful outcome here — not redundant.

## Step 3 — trivy image scan

```sh
docker compose exec attacker sh -c "trivy image cyberlab/day10-vulnapp:latest"
```

Expected table (planted findings; the real run will also list additional Debian
OS-package CVEs inherited from the `python:3.9-slim` base layer, which drift over time
and aren't part of this lab's planted set):

```
sample-repo (python-pkg)
=========================
Total: 2 (CRITICAL: 1, HIGH: 1)

┌──────────┬────────────────┬──────────┬───────────────────┬───────────────────┬──────────────────────────────────────────┐
│ Library  │ Vulnerability  │ Severity │ Installed Version │ Fixed Version      │ Title                                    │
├──────────┼────────────────┼──────────┼───────────────────┼───────────────────┼──────────────────────────────────────────┤
│ PyYAML   │ CVE-2020-1747  │ CRITICAL │ 5.1                │ 5.3.1              │ Arbitrary code execution via yaml.load()  │
├──────────┼────────────────┼──────────┼───────────────────┼───────────────────┼──────────────────────────────────────────┤
│ urllib3  │ CVE-2019-11324 │ HIGH     │ 1.24.1              │ 1.24.2             │ Improper certificate validation           │
└──────────┴────────────────┴──────────┴───────────────────┴───────────────────┴──────────────────────────────────────────┘
```

**Highest-severity CVE to fix (Drill 2's answer): `CVE-2020-1747` in `PyYAML 5.1`,
CVSS 9.8 (Critical).** It outranks `CVE-2019-11324` (CVSS 7.5, High) because it's
full arbitrary code execution reachable via a single `yaml.load()` call on untrusted
input with no restricted loader — `src/app.py`'s own `load_config()` makes exactly that
call — versus a narrower certificate-validation weakness. Fix: bump the pin to
`PyYAML>=5.3.1` (or, better, switch the call site itself to `yaml.safe_load()`, which
is the actual root-cause fix independent of version — CVE-2020-1747 exists precisely
because `yaml.load()` without a restricted `Loader=` was ever the default-reached-for
call).

## Step 4 — grype cross-check

```sh
docker compose exec attacker sh -c "grype cyberlab/day10-vulnapp:latest"
```

Expected: the same two planted CVEs, in grype's own report format (`NAME / INSTALLED /
FIXED-IN / TYPE / VULNERABILITY / SEVERITY` columns) — confirming trivy's findings via
an independent scanner/matching engine rather than trusting one tool's database alone.

## Step 5 — syft SBOM

```sh
docker compose exec attacker sh -c "syft cyberlab/day10-vulnapp:latest -o table"
```

Expected: a full component table — `PyYAML 5.1`, `urllib3 1.24.1`, `Flask 2.3.3`, every
package Flask itself transitively pulls in (e.g. `Werkzeug`, `Jinja2`, `click`,
`itsdangerous`, `blinker`, `MarkupSafe`), plus the base `python:3.9-slim` image's
Debian OS packages — the complete inventory, not filtered to vulnerable entries the way
Steps 3–4's output was.

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "gitleaks detect --source /loot/day10/sample-repo --no-git -v 2>&1 | grep -qi 'secret' && echo ATTACK_OK"
```

Expected output: `ATTACK_OK` — gitleaks' verbose output includes the literal word
"Secret:" in every finding block (see Step 1's expected output above), so the grep
condition is satisfied by any successful detection run, independent of exactly which/how
many secrets are found.

## Defense Lab — where each secret actually belongs (full mapping)

Repeats and completes Section 3 of
[`content/day10-secrets-supplychain.md`](../../content/day10-secrets-supplychain.md):

| Secret | Destination | Why this one |
|---|---|---|
| AWS access key pair (`.env`) | IAM role (preferred) or AWS Secrets Manager | Short-lived, auto-rotating credentials via a role eliminate the static key entirely; Secrets Manager is the fallback only if a static key is genuinely unavoidable |
| Stripe API key (`config/fake_srts.yml`) | AWS Secrets Manager | Real third-party credential; Secrets Manager's built-in rotation hooks are worth the extra setup for this one |
| Flask `secret_key` (`config/fake_srts.yml`) | SSM Parameter Store `SecureString` | Simpler/cheaper than Secrets Manager; no rotation workflow needed for an app-internal signing key |
| SSH password (`deploy/notes.txt`) | Nothing — switch to SSH key-based auth | The fix isn't a better place to store a password; it's not having a password at all |

## Teardown

```sh
cd cyber_security/labs/day10
docker compose down
docker image rm cyberlab/day10-vulnapp:latest
```

This removes only this lab's built image — `labs/base`'s `attacker` container, the
`cyberlab` network, and the staged files under `labs/base/loot/day10/` are untouched.
Tear down `labs/base` separately (`cd ../base && ./down.sh`) only once you're done with
the whole session.
