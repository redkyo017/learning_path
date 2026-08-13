# Day 10 — Secrets & Supply Chain

## Objectives

By the end of today you should be able to:

- Explain what **secrets sprawl** actually looks like in a real repo (not just "a
  password in code") — secrets scattered across `.env` files, config, comments, and
  scratch notes, each one a separate leak surface.
- Run `gitleaks`/`trufflehog` against a codebase, read their findings, and say
  precisely which secret leaked, where, and what the fix is.
- Read a `trivy`/`grype` vulnerability report on a built image and pick out the
  **highest-severity CVE**, using **CVSS** to justify the ranking, not just gut feel.
- Explain what a **transitive dependency** is and why a vulnerability three levels deep
  in your dependency tree is still your problem.
- Recognize **typosquatting** as a distinct supply-chain attack from "an old package has
  a real CVE" — one is a vulnerable *legitimate* package, the other is an attacker
  *impersonating* a legitimate package name.
- Generate an **SBOM** with `syft` and say what question an SBOM answers that a
  point-in-time vulnerability scan doesn't.
- Name where each class of secret in today's lab should actually live (a **secrets
  manager**, not a repo), and why that's a categorically different fix than "just
  rotate it."

## 1. Concept — Secrets Sprawl and the Software Supply Chain

### Two different problems that get lumped together, and shouldn't be

Today covers two failure modes that both show up as "stuff in this repo can hurt you,"
but they're mechanically unrelated and need different tools and different fixes:

1. **Secrets sprawl** — actual credentials (API keys, passwords, tokens) sitting in
   places a human or a scanner can read them: source files, config, `.env` files, shell
   history, CI logs, even old commits nobody looked at again. The fix is *removing the
   secret from the codebase entirely* and putting it somewhere access-controlled.
2. **Vulnerable/malicious dependencies** — the third-party code your project *pulls in*
   (via `pip`, `npm`, `maven`, a base image, ...) has a real, known vulnerability (a
   **CVE**), or — a different and worse case — was never a legitimate package at all.
   The fix is *upgrading, patching, or not installing that package in the first place*.

Both get called "supply chain security" loosely, and both matter for the same reason:
neither is a bug in code your team wrote — they're risk your project *inherited*, from
a config file someone left behind or a `pip install` someone ran once and forgot about.

### Secrets sprawl — why it's a sprawl problem, not a single-file problem

**Secrets sprawl** is the specific failure mode where a secret doesn't leak from *one*
predictable place — it leaks because credentials accumulate in many small, easy-to-miss
places over time: a `.env` file committed "just for local dev," a config value
hardcoded "temporarily" and never revisited, a password left in a scratch text file
during a migration, an old value commented out instead of deleted. Today's
`labs/day10/sample-repo/` plants exactly this pattern on purpose — three unrelated
files (`.env`, `config/fake_srts.yml`, `deploy/notes.txt`), three unrelated secrets, none
of them the "one obvious place" a quick manual read-through would catch by checking a
single file. That's the actual lesson: manual review doesn't scale to sprawl; a scanner
that walks the whole tree does.

**Why `.env` files are a recurring offender specifically:** they exist to hold
environment-specific config (which is a legitimate need — different DB URLs per
environment, etc.), but "environment-specific" quietly becomes "secret-shaped" the
moment a real API key or password goes in one, and `.env` files get committed far more
often than anyone intends, because the whole point of the file is to *not* require a
manual export step, which also means no manual "wait, should this be committed?" step
ever happens either.

### Hardcoded credentials vs. environment injection vs. a secrets manager

There are three tiers here, in order of how much a leak actually costs you:

- **Hardcoded in source or config, committed to the repo** (today's `config/fake_srts.yml`,
  `deploy/notes.txt`) — worst tier. The secret is readable by anyone with repo access,
  forever, in every clone, and rotating it requires a code change and a redeploy.
- **Injected via environment variables at runtime, not committed** — better: the value
  isn't in the repo, but it still has to come from *somewhere* at deploy time (a CI
  variable, an orchestrator config), and if that somewhere is itself loosely access-
  controlled, you've just moved the sprawl one layer, not eliminated it.
- **Fetched at runtime from a secrets manager** (AWS Secrets Manager, SSM Parameter
  Store) — the value never sits in a file anywhere; the app authenticates to the
  secrets service (using IAM, not a static key) and pulls the value at startup. Rotation
  becomes a config change in one place, access is auditable (CloudTrail logs every
  fetch), and a leaked *repo* leaks zero real credentials, because none were ever in it.

**Secrets manager** — the general term for the third tier: a dedicated, access-
controlled, audited service whose entire job is storing and serving secrets to
authorized callers, so no application has to store a real credential in a file. Section
3 (Defense Lab) maps today's three planted secrets to exactly where each belongs.

### CVE, CVSS, and reading a vulnerability report

**CVE** (Common Vulnerabilities and Exposures) — a unique public identifier
(`CVE-YYYY-NNNNN`) assigned to one specific, publicly disclosed vulnerability in a
specific piece of software. It's a name, not a severity — "this CVE exists" tells you
nothing yet about how bad it is; that's what CVSS is for.

**CVSS** (Common Vulnerability Scoring System) — a standardized 0.0–10.0 severity
score for a CVE, computed from factors like: can it be exploited remotely with no
authentication (worse) or does it need local access and valid credentials (less bad);
does it fully compromise confidentiality/integrity/availability, or only degrade one.
The score maps to a qualitative band: 9.0–10.0 **Critical**, 7.0–8.9 **High**, 4.0–6.9
**Medium**, 0.1–3.9 **Low**. When a scanner reports five CVEs across your dependencies,
CVSS is what lets you correctly triage "fix this one today" from "backlog it" —
severity, not alphabetical order or gut feel about which package "sounds scarier."

### Transitive dependencies — why "I didn't even install that" isn't a defense

A **transitive dependency** is a package your project depends on *indirectly* — you
installed package A, and A itself depends on package B, so B ends up in your
environment even though you never named it in `requirements.txt`/`package.json`
yourself. The uncomfortable fact this creates: a CVE in some package four levels deep
in your dependency graph is still running inside your process, with your process's
permissions, and is still your problem to patch — "I never directly chose to depend on
that" doesn't change what code is actually executing. This is exactly why dependency
scanners walk the *full* resolved tree, not just your direct `requirements.txt`/
`package.json` entries — and why a **lockfile** (which pins the exact resolved
versions, transitive included) matters for reproducing a scan result at all.

### SBOM — the inventory a point-in-time scan doesn't give you

An **SBOM** (Software Bill of Materials) is a complete, machine-readable inventory of
every component (direct and transitive) that goes into a piece of software — name,
version, license, and origin for each. The distinction that matters: a vulnerability
scan (`trivy`/`grype`) answers *"is anything in this image currently known-vulnerable,
right now?"* — but that answer changes the moment a new CVE is published against a
package you already shipped, and you'd have no way to know which of your already-
deployed images contain it without re-scanning every one of them. An SBOM answers a
different, longer-lived question: *"exactly what is in this build?"* — so that when a
new CVE drops next month for a package you've never manually thought about, you can
grep existing SBOMs instead of re-scanning every artifact you've ever shipped. `syft`
(Section 3) generates one; a real supply-chain security program keeps them per-build,
indefinitely.

### Typosquatting — a different attack, not just an old-version problem

**Typosquatting** is publishing a malicious package under a name deliberately chosen to
be one keystroke or one visual slip away from a real, popular package's name (a common
misspelling, a hyphen swapped for an underscore, a transposed letter) — betting that a
developer's typo, or a stale tutorial, installs the fake one instead of the real one.
This is a **categorically different** threat than "PyYAML 5.1 has a real CVE" (today's
planted, hands-on example): a vulnerable legitimate package is code its real maintainers
wrote, with a real flaw, fixable by upgrading; a typosquatted package was **never
legitimate at all** — it's attacker-authored code, installed because of a naming
mistake, and "upgrading" it does nothing, because there is no real project behind the
name to upgrade to. Drill 4 below works through spotting one.

## 2. Attack Lab — Find the Leaked Secrets and the Vulnerable Dependency

**Authorized use only:** everything below scans `labs/day10/sample-repo/`, a static lab
fixture this path ships with fake-but-realistic-shaped secrets and two real, historical
CVEs planted on purpose — never run these same scanners against a codebase you don't
own or don't have explicit authorization to scan. Note also: `sample-repo/` is
deliberately **not a git repository** — no `.git/` anywhere in it. Every command below
uses `--no-git`/file-mode scanning for that reason; see the callout after Step 1 for
exactly why.

Bring up `labs/base` if it isn't already, and stage this lab's fixture into the shared
loot dir with a plain `cp` (no extra container needed):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day10
mkdir -p ../base/loot/day10
cp -r sample-repo ../base/loot/day10/
```

Unlike day04's `target`, today's `vulnapp` image is only ever **built**, never started
— there's no live service to reach over `cyberlab`:

```sh
docker compose build vulnapp
```

### Toolbox note — none of today's five scanners ship in the base attacker image

`labs/base/attacker/Dockerfile` installs `nmap`, `hydra`, `sqlmap`, and friends — but
**not** `gitleaks`, `trufflehog`, `trivy`, `grype`, or `syft`. Install each with its
official install script, once per running attacker container session (installs don't
persist across `docker compose down -v`, since nothing here modifies the base image):

```sh
docker compose exec attacker bash
# --- inside the attacker container ---
curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
gitleaks version && trufflehog --version && trivy --version && grype version && syft version
```

(If `gitleaks`'s install-script URL ever moves, its GitHub Releases page always has a
`linux_x64` tarball as a fallback — same idea for the other four.) Full detail and
exactly what each tool needs: [`labs/day10/README.md`](../labs/day10/README.md).

### Step 1 — Scan for secrets with `gitleaks`

```sh
docker compose exec attacker sh -c "gitleaks detect --source /loot/day10/sample-repo --no-git -v"
```

**Why `--no-git` is required here, not optional:** gitleaks defaults to scanning git
*history* (every commit, via `git log -p`) — which requires the target to actually be a
git repository. `sample-repo/` intentionally isn't one (this lab's fixture must not be a
real, committable git repo — see [`labs/day10/README.md`](../labs/day10/README.md) for
why). `--no-git` switches gitleaks to plain filesystem mode: it walks the files on disk
as they are right now, no `.git/` required. This is a real, documented gitleaks mode,
not a workaround — and it's actually the *more* realistic mode for scanning something
you don't control the git history of at all, like a vendor drop or a downloaded archive.

**What you should see:** findings for the AWS key pair in `.env`, the Stripe-shaped key
and Flask `secret_key` in `config/fake_srts.yml`, and the SSH password in
`deploy/notes.txt` — each reported with its rule name, the file and line, and the
matched (redacted-in-report) secret. Full expected finding-by-finding output:
[`labs/day10/SOLUTION.md`](../labs/day10/SOLUTION.md).

### Step 2 — Confirm with `trufflehog` (a second scanner, different detection strategy)

```sh
docker compose exec attacker sh -c "trufflehog filesystem /loot/day10/sample-repo --no-verification"
```

**Why run a second tool at all:** gitleaks matches mostly by **regex pattern** (does
this string's *shape* match a known secret format); trufflehog additionally does
**entropy analysis** and, when not disabled, live **verification** (does this credential
actually still work, by testing it against the real service's API) — a genuinely
different detection strategy, not just a different UI on the same technique.
`--no-verification` is used here because none of today's planted secrets are real
live credentials — there's nothing to verify against, and skipping it avoids
trufflehog making live network calls out to AWS/Stripe with fake keys as part of an
offline lab. **What you should see:** trufflehog's own findings for the same handful of
secrets, in its own report format — a useful sanity check that gitleaks' findings
weren't a fluke of one tool's specific ruleset.

### Step 3 — Scan the built image for vulnerable dependencies with `trivy`

```sh
docker compose exec attacker sh -c "trivy image cyberlab/day10-vulnapp:latest"
```

**What you should see:** a table of findings including `PyYAML 5.1` → `CVE-2020-1747`
(Critical, CVSS 9.8) and `urllib3 1.24.1` → `CVE-2019-11324` (High, CVSS 7.5) — both
planted on purpose in `requirements.txt` (see that file's header comment for exactly
why each was chosen) — plus possibly additional OS-package-level findings from the
`python:3.9-slim` base image itself, which drift over time as new CVEs get published
against Debian packages already baked into that base layer; those extra findings are
expected and not part of this lab's planted set.

### Step 4 — Cross-check with `grype`

```sh
docker compose exec attacker sh -c "grype cyberlab/day10-vulnapp:latest"
```

**What you should see:** the same two planted CVEs (trivy and grype both consume the
same underlying NVD/vendor advisory data, just with different matching engines and
report formats) — running both isn't redundant busywork, it's the same "don't trust one
tool's ruleset alone" habit as Step 2's gitleaks/trufflehog pairing.

### Step 5 — Generate an SBOM with `syft`

```sh
docker compose exec attacker sh -c "syft cyberlab/day10-vulnapp:latest -o table"
```

**What you should see:** a full component inventory — `PyYAML 5.1`, `urllib3 1.24.1`,
`Flask 2.3.3`, every transitive dependency Flask itself pulls in, plus the base image's
OS packages — each with type and version. Note this list is **not** filtered to "only
the vulnerable ones" the way Steps 3–4's output was: an SBOM is the *complete* inventory
regardless of current vulnerability status, which is exactly Section 1's point — it's
useful again next month when a new CVE drops against something in this list that's
clean today.

### Verify

```sh
docker compose exec attacker sh -c "gitleaks detect --source /loot/day10/sample-repo --no-git -v 2>&1 | grep -qi 'secret' && echo ATTACK_OK"
```

Expected: `ATTACK_OK`. Full detail: [`labs/day10/SOLUTION.md`](../labs/day10/SOLUTION.md).

## 3. Defense Lab — Where Each Secret Actually Belongs, and Catching This Before It Ships

### Defense 1 — Move every planted secret to a real secrets manager

Today's three secrets map to two different AWS services, by shape:

- **`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in `.env`** — these shouldn't exist as
  long-lived static keys *at all* in a properly designed system: a service running on
  EC2/ECS/Lambda should assume an **IAM role** and get short-lived, auto-rotating
  credentials from the instance/task metadata service, with zero static key ever
  written to disk anywhere. If a static key is genuinely unavoidable (a third-party
  tool that only supports key/secret auth), it belongs in **AWS Secrets Manager**,
  fetched at runtime, never in a file.
- **`config/fake_srts.yml`'s Stripe key and Flask `secret_key`** — application-level
  config secrets with no natural AWS-native alternative to "just don't have a static
  value" (unlike IAM roles for AWS-internal auth) — these belong in **Secrets Manager**
  (Stripe key: it's a real third-party API credential, and Secrets Manager supports
  automatic rotation hooks) or **SSM Parameter Store** with type `SecureString` (Flask's
  `secret_key`: simpler, cheaper, no built-in rotation workflow needed for this one).
- **`deploy/notes.txt`'s SSH password** — the fix here isn't "move it to a secrets
  manager," it's "this shouldn't exist as a password at all": SSH key-based auth (no
  password login), and if a break-glass credential is genuinely needed, a Secrets
  Manager entry with tightly scoped IAM access and CloudTrail-logged reads — never a
  scratch text file in a repo that nobody remembers to delete or keep in sync.

### Defense 2 — Dependency scanning in CI (catch it before merge, not after deploy)

Today's Attack Lab ran `trivy`/`grype` manually, after the image already existed. The
actual fix is running the identical scan as a CI pipeline step, on every pull request,
**before** merge — failing the build on any Critical/High finding (a CVSS threshold,
tying directly back to Section 1's CVSS discussion: this is exactly where that score
becomes an automated gate, not just a reading exercise). This flips the economics: a
vulnerable dependency caught in a PR costs one changed line in `requirements.txt`; the
same dependency caught after it's already deployed to production costs an incident.

### Defense 3 — Pre-commit secret-scanning hooks (catch it before it's ever committed)

`gitleaks` ships a `protect` mode designed to run as a **pre-commit hook** — scanning
only the staged diff, before a commit is created, so a secret never enters git history
in the first place (as opposed to `detect` mode, which finds secrets *already*
committed, after the fact). The asymmetry that makes this worth the setup cost: once a
secret is committed, rotating it is necessary but often not sufficient — the leaked
value already existed in history and may have already been cloned, mirrored, or
scraped; a pre-commit hook is the one control that prevents the leak from ever
happening rather than detecting it afterward. (This lab's `sample-repo/` is
intentionally not a git repo, so `protect` mode isn't demonstrated hands-on here — a
named, not re-verified, defense, same honesty pattern Day 4 used for MFA/OIDC.)

### Defense 4 — SBOM as a standing artifact, not a one-time report

Section 1 named the gap an SBOM fills: today's Step 5 (`syft`) generated one manually,
once. In a real pipeline, SBOM generation runs on every build, and the resulting SBOM
gets stored alongside the artifact it describes (many CI systems attach it directly to
the build/release). The payoff arrives later, not immediately: when a new CVE is
published next month against some package buried in your dependency tree, you grep
stored SBOMs for every artifact that contains it, instead of re-scanning every image
you've ever shipped from scratch.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Run gitleaks, list the leaked secret, and name the fix

Run Section 2 Step 1's `gitleaks` command yourself against `sample-repo/`. Pick any
**one** of its findings and answer, specifically: which file, which secret (by type,
not by leaking the literal value in your answer), and what's the concrete fix — not
"rotate it," but *where should this value live instead*.

**Hint:** "the fix" has two parts for a secret that's already committed: an *immediate*
part (rotate the leaked credential — assume anyone could already have it) and a
*structural* part (stop it from being in a file at all going forward). Section 3
Defense 1 maps each of today's three secrets to a specific destination — use that
mapping.

**Solution sketch:** e.g. for the AWS key pair in `.env` — gitleaks flags it under an
`aws-access-token` (or equivalent AWS-key) rule, in `.env`, matching the
`AKIA`-prefixed access key ID and its paired secret key. Immediate fix: rotate/deactivate
that key pair in IAM (assume it's burned the moment it's committed anywhere). Structural
fix: the workload should assume an IAM role for AWS-internal calls (no static key at
all), or, if a static key is unavoidable, it belongs in AWS Secrets Manager fetched at
runtime — never in a file checked into a repo, `.env` included.

### Drill 2 — Read the trivy report and pick the highest-severity CVE

Run Section 2 Step 3's `trivy image` command yourself. Two CVEs are the planted focus
of this lab (ignore any extra OS-package findings from the base image for this drill).
Which one is the higher priority to fix, and *why*, in terms of CVSS — not "it sounds
scarier"?

**Hint:** Section 1 gave you the CVSS band definitions and named both planted CVEs'
approximate scores directly in `requirements.txt`'s own header comment — read that
comment, then confirm it against trivy's actual report output.

**Solution sketch:** `PyYAML 5.1` → `CVE-2020-1747` (CVSS 9.8, Critical) outranks
`urllib3 1.24.1` → `CVE-2019-11324` (CVSS 7.5, High). The concrete reason it's worse,
not just numerically higher: CVE-2020-1747 is arbitrary code execution triggered by
calling `yaml.load()` on untrusted input with no restricted loader — full compromise of
confidentiality, integrity, *and* availability, remotely exploitable if untrusted YAML
ever reaches that call (exactly the call `src/app.py` makes). CVE-2019-11324 is a
certificate-validation weakness — serious, but narrower: it degrades one specific
security property (transport authenticity) under specific conditions, not full remote
code execution. Fix priority: patch `PyYAML` first.

### Drill 3 — Where should each secret actually live

For each of today's three planted secrets (AWS keys, Stripe/Flask keys, SSH password),
name the specific AWS service or mechanism it should be migrated to, and say why that
one, not a different option.

**Hint:** Section 3 Defense 1 already answers this directly — the point of this drill
is reconstructing the reasoning yourself (static-key-vs-role for AWS-internal auth,
third-party-API-key needing rotation support, password-vs-key-based-SSH-auth), not
re-reading it.

**Solution sketch:** AWS access key pair → ideally eliminated entirely via an IAM role
(short-lived, auto-rotating, workload identity — no static key to leak in the first
place); if a static key is genuinely unavoidable, AWS Secrets Manager. Stripe API key →
AWS Secrets Manager specifically (supports rotation hooks, and it's a real third-party
credential worth that extra capability). Flask `secret_key` → SSM Parameter Store
`SecureString` (simpler/cheaper, no rotation workflow needed for this one, still
access-controlled and audited via CloudTrail). SSH password in `deploy/notes.txt` →
not a secrets-manager problem at all — the actual fix is switching to SSH key-based
authentication so there's no password to store anywhere; a Secrets Manager entry is
only relevant if a genuine break-glass credential is still needed after that switch.

### Drill 4 — Spot the typosquat

You're reviewing a teammate's `requirements.txt` diff before approving a PR. One line
was added:

```diff
+ python-dateutil==2.8.2
+ requessts==2.31.0
  flask==2.3.3
```

Something's wrong with one of the new lines, and it isn't a version number. What is it,
and what would you tell your teammate to do right now (not "after investigating for a
week")?

**Hint:** Section 1 defined typosquatting precisely: a name one keystroke away from a
real, popular package. Read each new package name character by character against the
real package you'd expect it to be, rather than skimming.

**Solution sketch:** `requessts` is not a real package name — the real, extremely
popular HTTP library is `requests` (one `s`, no extra `s`/`t`). `requessts==2.31.0` is
exactly Section 1's typosquatting pattern: a name one small edit away from a legitimate,
widely-used package, betting on a typo or a copy-paste slip getting it installed
instead. The right immediate action is **not** "check if this specific version has a
CVE" (Drill 2's kind of question) — there is no real project behind that name to check
a CVE database against. The action is: don't merge, don't run `pip install` against it
to "just see," and flag it for removal/correction to `requests` — treating an unknown
package name as guilty until verified against the actual intended dependency, not the
other way around.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name specifically which secret(s) `gitleaks`/`trufflehog` found
  in `sample-repo/`, and which CVE `trivy`/`grype` flagged as highest severity — versus
  which part (typosquatting, Drill 4) you only reasoned through on paper, not against a
  live scan.
- **How:** which of the two toolbox pairings — gitleaks/trufflehog for secrets, or
  trivy/grype for dependencies — felt more like "two tools agreeing" versus "two tools
  telling you something different"? Name a specific finding where that showed up.
- **What defended it:** of Section 3's four defenses, which one would you actually
  implement first on a real project you maintain, and why that one before the others?
- **What confused me:** anything about *why* a vulnerable-but-legitimate dependency and
  a typosquatted package need entirely different responses, or about what an SBOM gives
  you that a vulnerability scan alone doesn't, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (secrets sprawl, SBOM, CVE, CVSS,
  transitive dependency, typosquatting, secrets manager) to re-explain from memory
  before Day 11, without looking back at this file.
