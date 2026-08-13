# Day 10 Lab — Find the Leaked Secrets and the Vulnerable Dependency

## Authorized use only

Everything below scans [`sample-repo/`](sample-repo/), a static lab fixture this path
ships with fake-but-realistic-shaped secrets and two real, historical CVEs planted on
purpose, and `cyberlab/day10-vulnapp:latest`, the image built from it. Only ever point
`gitleaks`/`trufflehog`/`trivy`/`grype`/`syft` at fixtures this learning path ships (here
or in any other day's lab) or your own repos/images — never at a codebase or container
registry you don't own or don't have explicit written authorization to scan.

## Why `sample-repo/` is deliberately not a git repository

Every other day-lab's "target" is a running container reached over the network. Today's
is different on purpose: a repo with secrets planted **in git history** (old commits,
never rewritten) is the more realistic real-world case, and the original task spec for
this lab called for exactly that. This lab intentionally does **not** do that — no
`git init`, no commits, no `.git/` anywhere under `sample-repo/` — so that nothing in
this repository is ever a git repo containing planted "leaked" credentials that could
later get committed for real. `sample-repo/` is plain files on disk instead, and every
scan command below runs the relevant tool in its **filesystem mode**
(`gitleaks --no-git`, `trufflehog filesystem`) rather than its git-history mode. This is
a real, supported mode for both tools, not a workaround — and it's the correct mode
for scanning anything you don't have (or don't want) git history for, which includes a
surprising amount of real-world code (vendor drops, extracted archives, someone's
unpacked zip of "the old service").

## What this lab is

- [`sample-repo/`](sample-repo/) — a toy "payment-notifier" app with three secrets
  planted across three different files (`.env`, `config/fake_srts.yml`,
  `deploy/notes.txt` — see each file's own comments for exactly what's planted and
  why), plus a `requirements.txt` pinning two packages with real, historical CVEs
  (`PyYAML==5.1`, `urllib3==1.24.1` — see that file's header comment for CVE IDs and
  CVSS scores).
- [`docker-compose.yml`](docker-compose.yml) — builds `sample-repo/`'s `Dockerfile` into
  `cyberlab/day10-vulnapp:latest`. Unlike every earlier day's `target`, this image is
  **never started** — `docker compose build` only, no `up`, no ports, nothing reachable
  over `cyberlab`. It exists purely to give `trivy`/`grype`/`syft` a built filesystem to
  scan.
- No live network target — today's "attack" is static analysis (file + image scanning),
  not network exploitation.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Stage the fixture into the shared loot directory (plain `cp -r`, no container involved):

```sh
cd cyber_security/labs/day10
mkdir -p ../base/loot/day10
cp -r sample-repo ../base/loot/day10/
```

Build (do not start) the vulnerable image:

```sh
docker compose build vulnapp
```

## Toolbox: installing today's five scanners

`labs/base/attacker/Dockerfile` does **not** include `gitleaks`, `trufflehog`, `trivy`,
`grype`, or `syft` — the base toolbox is scoped to the tools Days 1–9 use
(`nmap`/`hydra`/`sqlmap`/etc.), and none of those five are among them. Install each with
its official install script, inside the running `attacker` container, once per
container session:

```sh
cd cyber_security/labs/base
docker compose exec attacker bash
```

Then, inside the container:

```sh
curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
gitleaks version && trufflehog --version && trivy --version && grype version && syft version
```

**These installs do not persist** across `docker compose down -v` on `labs/base` (they
write into the running container's writable layer, not into the base image) — re-run
them if you tear down and bring the toolbox back up in a later session. If you want them
to persist across sessions, the durable fix is adding these five install lines to
`labs/base/attacker/Dockerfile` and rebuilding — out of scope for this lab, named here
as the obvious next step if you find yourself reinstalling often.

**If an install-script URL ever 404s** (scripts occasionally move): each project's
GitHub Releases page publishes a `linux_x64`/`linux_amd64` tarball or binary directly —
download and extract it to `/usr/local/bin` as a fallback, same end result.

## Running commands for this lab

Same pattern as every earlier day: `attacker` is defined in
`labs/base/docker-compose.yml`, not here. Run every `docker compose exec attacker ...`
command **from `labs/base`**:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "gitleaks detect --source /loot/day10/sample-repo --no-git -v"
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "gitleaks detect --source /loot/day10/sample-repo --no-git -v 2>&1 | grep -qi 'secret' && echo ATTACK_OK"
```

**Expected output:** `ATTACK_OK`.

**Note on this differing from the original task spec's verify command:** the plan this
lab was built from proposed a verify command that ran gitleaks once in git mode and once
with `--no-git`, implying `sample-repo/` would have secrets planted in git history. This
build deliberately does not create that git history (see the callout above), so the
verify command here uses `--no-git` filesystem-mode scanning throughout, consistently
with the rest of this lab.

## Walkthrough

1. Bring up `labs/base`, stage `sample-repo/` into the shared loot dir, and build
   `vulnapp`, as above.
2. Install today's five scanners into the running `attacker` container (Toolbox section
   above).
3. Work through Section 2 of
   [`content/day10-secrets-supplychain.md`](../../content/day10-secrets-supplychain.md)
   in order: `gitleaks` (Step 1), `trufflehog` (Step 2) for secrets; `trivy` (Step 3),
   `grype` (Step 4) for the vulnerable dependencies; `syft` (Step 5) for the SBOM.
4. Run the verify command above and confirm `ATTACK_OK`.
5. Read Section 3 (defense) and work out, yourself, which AWS service each planted
   secret should move to, before checking `SOLUTION.md`.

Full expected output for every command above, the exact secrets/CVEs found, and the
highest-severity CVE analysis: [`labs/day10/SOLUTION.md`](SOLUTION.md).

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
