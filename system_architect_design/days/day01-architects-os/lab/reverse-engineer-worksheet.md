# Reverse-engineer: <system name>

> Copy this to `../design/reverse-engineer.md` and fill every section. Run the
> steps **in order** (`reference/design-method.md`). Treat it as if you were
> designing this system fresh today — that's what surfaces the decisions you made
> implicitly.

## 0. One-line description
<What is this system, in one sentence a newcomer understands?>

## 1. Requirements
- **Functional (verbs):** <core use cases — "ingest X", "route Y", "expose Z">
- **Scale & shape:** users/tenants ≈ ___ ; RPS avg/peak ≈ ___ ; data size ≈ ___ ;
  read:write ≈ ___ ; spiky or steady? ___
- **Explicitly out of scope:** <what this system does NOT do>

## 2. Constraints
- Budget / team / deadline: ___
- Latency SLA / availability target / compliance / data-residency: ___
- Existing stack you had to live with: ___
- Build-vs-buy posture: ___

## 3. Top-3 NFRs (the ones it lives or dies by)
Pick exactly three from `reference/nfr-checklist.md`, each with a *number*:
1. ___ — target: ___
2. ___ — target: ___
3. ___ — target: ___
- **The "-ility" I deliberately did NOT optimize:** ___ (and why that was OK)

## 4. Options that existed at decision time (≥2)
- **Option A —** <name>: <one-line description>
- **Option B —** <name>: <one-line description>
- (Option C, if any): ___

## 5. Tradeoff table (options × top-3 NFRs)
| Option | NFR-1 (___) | NFR-2 (___) | NFR-3 (___) | Cost | Complexity |
|--------|-------------|-------------|-------------|------|------------|
| A      |             |             |             |      |            |
| B      |             |             |             |      |            |

## 6. Decision
- **We chose:** <the option you shipped>
- **One-sentence why over the runner-up:** "We chose ___ over ___ because, for our
  top NFR of ___, ___ gives us ___ while ___ would have cost us ___."

## 7. How it breaks (self-red-team — name at least 5)
1. **Load spike / 10× growth:** first bottleneck = ___
2. **A dependency is down/slow:** does it cascade? ___
3. **Network partition:** which side wins, is that correct? ___
4. **A bad deploy:** blast radius + rollback path = ___
5. **A hot key / hot partition / poison message:** ___
6. (bonus) **Data loss / duplicate delivery under retries:** ___

> For any scenario you can't answer, that's a real gap in the system — note it as a
> follow-up, don't hand-wave it.
