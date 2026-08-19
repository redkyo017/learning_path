# `labs/day11` — IR capstone: attack

> **⚠️ Authorized testing only.** This lab, and every asset it points to,
> targets **your own AWS account and your own `labs/base` deployment
> only.** See
> [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement)
> — the canonical statement, repeated in every offensive lab in this
> path.

## Why this directory is almost empty

Day 11 adds **no new Terraform** on top of `labs/base` — unlike most
other days, there is no `main.tf`/`variables.tf`/`outputs.tf` here. The
day's entire lab is the scripted attack, and it lives in
`labs/capstone/` because Days 11 and 12 share the same incident (Day 11
attacks it, Day 12 defends it) and the assets need to sit somewhere both
days read from without duplication.

**Everything you actually run today is here:**

- [`labs/capstone/attack-runbook.md`](../capstone/attack-runbook.md) —
  the full narrated runbook: prerequisites, the "leaked key" and
  credential-endpoint-GUID notes, the stage-by-stage table, and the
  capture checklist.
- [`labs/capstone/attack.sh`](../capstone/attack.sh) — the runnable
  version of the same stages, with pauses between each so you actually
  capture artifacts instead of racing through.
- [`labs/capstone/attack-SOLUTION.md`](../capstone/attack-SOLUTION.md) —
  the expected artifact for every stage, and a timeline template to fill
  in from your own run.

Day 12 owns the `defend*` files in that same `labs/capstone/` directory
(contain → eradicate → recover, run against the incident you generate
today) — this lab never touches those.

## Prerequisites

- `labs/base` applied and healthy.
- The Day 8 detection Terraform module (re-)applied so **GuardDuty and
  Security Hub are running** — Day 9's teardown turned them off at the
  end of the free-trial checkpoint; today re-opens the same 30-day trial
  window for the Day 11–12 capstone (see the Day 11 content file for
  the cost math). Macie and Detective stay off.
- AWS CLI v2, `curl`, `jq`, `python3` on your machine (`attack.sh` shells
  out to `python3` to URL-encode the SSRF target).
- Read `content/day11-ir-capstone-attack.md` first — it has the full
  incident storyline and the engine-lens framing this lab exercises.

## The break

Run `labs/capstone/attack.sh` (or walk `attack-runbook.md` by hand) to
land the full six-stage incident against your own workload: leaked key
→ recon → SSRF exploit → task-role credential theft → S3/DynamoDB exfil
→ a safe `--dry-run` stand-in for a crypto-mining-flavored API call.

**Expected result:** every stage succeeds against your own resources,
and a detection artifact exists somewhere (CloudTrail at minimum; most
stages also produce a GuardDuty finding, a Security Hub finding, or
both) — see `attack-SOLUTION.md` for exactly what to expect at each
stage.

## The harden

**Not today.** Day 11 is attack-and-capture only. Day 12
(`labs/day12/` + `labs/capstone/defend*`) is the harden half of this
two-day pair — it contains, eradicates, and recovers using the evidence
you build today.

## Success signal

A completed timeline in `labs/capstone/attack-SOLUTION.md`'s template,
filled in with real values from your own account: at least one
CloudTrail event ID, one GuardDuty finding ID, one Security Hub finding
ARN, and the Config resource-history result (expected: no configuration
changes during the window), each cross-referenced to the incident stage
that produced it.

## Teardown checklist

- [ ] No new Terraform state to destroy — this lab created none.
- [ ] Stolen credentials unset from your shell (`attack.sh` does this
      automatically at the end; they're short-lived and expire on their
      own regardless).
- [ ] **Leave GuardDuty and Security Hub running.** They stay up into
      Day 12 by design — do not disable them today. Day 12 performs the
      final sweep.
- [ ] Keep `./capstone-evidence/` (or wherever you saved artifacts) —
      Day 12 reads from it. Nothing in it should contain a real account
      ID or a credential that's still valid by the time you're done
      (task-role session credentials expire on their own within hours).
