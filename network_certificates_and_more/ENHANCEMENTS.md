# Enhancements — deferred work (instructions for a future session)

This file lists improvements that were **deliberately not made** during the
2026-09-30 review-and-fix pass. None of them breaks the course; each makes it
clearer, more current, or more polished.

**How to use:** tell Claude "work on ENHANCEMENTS.md item E3" (or "all P1
items"). Each item is self-contained: it says where, why, what to do, and how to
know it's done. When an item is finished, tick it and add the date.

---

## Ground rules for any session working from this file

- **Git:** don't stage, commit or push — the course owner does that.
- **grep:** use `/usr/bin/grep` in checks; plain `grep` is an aliased shim here.
- **Real OpenSSL only.** macOS `openssl` is LibreSSL. Use the toolbox container,
  or `/opt/homebrew/opt/openssl@3/bin/openssl` for quick offline checks.
- **Never trust expected output you didn't run.** Anything that changes a
  command or an expected-output block must be re-run live (procedure below)
  before the item counts as done.
- **Keep facts dated.** When touching anything time-sensitive (lifetimes,
  revocation, browser behaviour), re-check a primary source and write the date
  next to the claim.

### Live verification procedure

1. Start Docker Desktop.
2. Copy the course to the session scratchpad (never run labs inside the repo —
   generated keys land in `labs/`; `.gitignore` covers them, but keep the repo
   clean anyway): `rsync -a network_certificates_and_more/ <scratch>/course/`.
3. From `<scratch>/course/labs/`, follow the day files literally, in order:
   Day 1 → 6 guided labs, then `drills/drill-01…20`, then
   `drills/capstone/capstone-01…10`. Run one compose project at a time — the
   stack uses static IPs on `10.77.30.0/24`.
4. For each step record expected vs actual and a verdict: MATCH, MINOR-DRIFT
   (wording only), MISMATCH (different behaviour), BROKEN.
5. `docker compose down -v` at the end.

Baseline versions verified on 2026-09-30: toolbox Ubuntu 24.04 (OpenSSL 3.0.13,
curl 8.5.0, TShark 4.2.2, certbot 2.9.0), `nginx:stable` 1.30.5,
`ghcr.io/letsencrypt/pebble{,-challtestsrv}:2.10.1`. If any of these change,
re-run the full procedure — error strings drift between versions.

---

## P1 — highest value

### [ ] E1. Cut the wordiness by ~25%
- **Where:** all of `content/day01.md`–`day06.md`.
- **Why:** every day restates the core sentence and the four checks almost
  verbatim; sentences are long and em-dash heavy; some code blocks carry
  paragraph-length comments (e.g. Day 2 Part D's curl block). This slows
  readers down more than it helps retention.
- **Do:** keep the one-sentence model + four checks as a single short recap box
  at the top of Days 2–6 (Day 1 keeps the full version). Move explanations out
  of code-block comments into prose below the block. Split sentences over ~35
  words. Don't drop any concept, exercise, or hint.
- **Done when:** each day file is ≥20% shorter (`wc -w` before/after), every
  exercise and learning objective still present, no code block has a comment
  longer than 3 lines.

### [ ] E2. One consistent command style
- **Where:** all day files, drill `SYMPTOM.md`s, solutions.
- **Why:** most commands are one-off `docker compose run --rm toolbox …` calls
  (slow — a new container each time — and noisy), paths switch between
  `/work/...` and relative, and host-side commands (`cp services/...`) sit in
  the same blocks without saying so.
- **Do:** at the start of each lab, open one shell: `docker compose run --rm
  toolbox bash`, and show commands as `toolbox$ …` (inside) vs `host$ …`
  (host, for `docker compose up/restart/logs` and `cp services/...`). Use
  paths relative to `/work` throughout. Keep one-shot `docker compose run`
  only where a single command is genuinely clearer (e.g. drill SYMPTOM
  reproduction lines). Exception: Day 6's attack script must stay one
  container invocation.
- **Done when:** every command block is unambiguously host or toolbox, and
  the live verification passes with the new style.

### [ ] E3. Add three diagrams (Mermaid)
- **Why:** the course has zero diagrams; three concepts are much easier seen
  than read. Mermaid is already used elsewhere in this repo
  (`wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md`).
- **Do:**
  1. Day 2 — chain of trust: root (offline, self-signed) → intermediate
     (`pathlen:0`) → leaf, with which key signs which cert, and where the
     trust store sits.
  2. `labs/README.md` — lab topology: toolbox (10.77.30.10), nginx
     (`nginx:443`, host `8443`), pebble (10.77.30.20, :14000 ACME, :15000
     mgmt), challtestsrv (10.77.30.30, DNS :8053, API :8055), the `certlab`
     network, and the bind mounts (`.:/work`, `services/active.conf`,
     `certs/`).
  3. Day 3 — TLS 1.3 vs 1.2 handshake sequence diagrams side by side, marking
     where encryption starts and where the four checks run.
- **Done when:** diagrams render in GitHub's Markdown preview and match the
  prose (re-read the surrounding text after adding each).

---

## P2 — worth doing

### [ ] E4. Stop fixture names from giving away the answer
- **Where:** `drill-04/expired.cert.pem` (CN `expired.local`),
  `drill-08/example.local.expired.cert.pem`, `drill-13/client01-wrongca.*`,
  `drill-15/client01-skew.*`, `capstone-06` imposter cert (`client01-imposter`),
  `drill-16` cert CN `client01-nokey`.
- **Why:** the drills promise "symptom only, no diagnosis", but the file name
  or CN states the diagnosis.
- **Do:** rename to neutral names (e.g. `server.cert.pem`, `client01.cert.pem`)
  and regenerate certs whose CN leaks the answer. Update every reference in
  `SYMPTOM.md`, `repro.sh`, and `solutions/`.
- **Done when:** `/usr/bin/grep -rniE 'expired|wrongca|skew|imposter|nokey'
  labs/drills --include=SYMPTOM.md` finds nothing that names the cause in a
  file name, and all affected drills still reproduce live.

### [ ] E5. Error-wording drift in symptom files
- **Where / what the live run found:**
  - Drills 01–03: surrounding OpenSSL error-stack lines missing
    (casing already fixed where touched).
  - Drills 04, 05, 07, 08, 15, capstone-03: `openssl verify` output format —
    OpenSSL 3 prints `error N at D depth lookup: …` then a final
    `error <path>: verification failed`; drill-04 shows a phantom depth-1
    line; 05/07 use old `lookup:unable…` spacing; 07 should say `self-signed`.
  - drill-05 SYMPTOM says "the two files" but ships three.
  - capstone-03: says the cert expired "nearly two years" ago — its notAfter is
    2023-04-01 (~3.5 years before 2026-09-30); make the wording
    date-independent ("years ago").
  - capstone-08: server line is `HTTP/1.0 200 ok` (s_server `-www`).
  - capstone-10: real curl output has no trailing `!`.
- **Done when:** each listed SYMPTOM matches a fresh live run character for
  character in the lines that matter.

### [ ] E6. Add two modern incidents to Day 6
- **Why:** all three incidents are 2011–2018. Two recent ones teach the same
  lessons with current mechanics.
- **Do:** add short entries (same shape as the existing three: mechanism →
  lesson), and matching GLOSSARY entries if not present:
  - **Entrust distrust (2024):** Chrome distrusted Entrust-issued certs with
    SCTs after 2024-11-11 (Apple 2024-11-15, Mozilla 2024-11-30) over a
    long pattern of compliance failures — Symantec's lesson, repeated.
  - **DigiCert mass revocation (July 2024):** a domain-validation bug (missing
    underscore prefix in CNAME validation) forced revocation of ~83,000 certs
    on a Baseline-Requirements deadline of days — revocation at scale, and
    why automation (ACME/ARI) matters.
  - Re-check dates against primary sources (Chrome Root Program blog,
    DigiCert incident report) before writing.
- **Done when:** entries exist with sources checked and dates stated.

### [ ] E7. Refresh pinning guidance (Day 6)
- **Why:** the advice to "pin an intermediate" ages badly — public CAs now
  rotate intermediates routinely, and platform guidance (e.g. Android's
  network-security docs) discourages pinning for most apps.
- **Do:** check current Android/Apple guidance and Let's Encrypt's intermediate
  rotation practice (primary sources), then update the brittleness paragraph:
  pin your own keys (SPKI) with a backup pin, or prefer CT-based monitoring
  and short lifetimes over pinning.
- **Done when:** paragraph reflects current primary-source guidance, dated.

### [ ] E8. Upgrade the toolbox to show 2026-era TLS
- **Why:** Ubuntu 24.04's OpenSSL 3.0.13 can't show the post-quantum hybrid
  key exchange (`X25519MLKEM768`, default in OpenSSL 3.5+ and browsers) or
  ECH, and its certbot 2.9 predates ARI (renewal timing from the CA).
- **Do:** evaluate a newer base (e.g. Ubuntu 26.04 LTS, or a pinned
  `openssl:3.5+` build) and certbot ≥ 4.1. Then add small optional lab steps:
  Day 3 — capture a handshake and point at `X25519MLKEM768` in the
  ClientHello's `key_share`; Day 5 — show certbot using ARI against Pebble
  (Pebble supports ARI).
- **Risk:** every error string in drills may shift — this item requires the
  full live verification procedure and SYMPTOM updates.
- **Done when:** full live run passes on the new image and the new optional
  steps produce the described output.

### [ ] E9. Optional DNS-01 run in Day 5
- **Why:** Exercise 4 explains DNS-01 with challtestsrv hooks but it's never
  run; wildcard issuance is only described.
- **Do:** add an optional Part D: certbot `--manual` with
  `--manual-auth-hook`/`--manual-cleanup-hook` scripts (in `labs/acme/`) that
  call challtestsrv's `set-txt`/`clear-txt`, issuing `*.test.local`.
- **Done when:** the optional part issues a wildcard cert live.

---

## P3 — polish

### [ ] E10. Day 4: make the browser trust-store paragraph concrete
The Chrome paragraph hedges ("verify against that browser's documentation").
State it (re-check first): the Chrome Root Store and verifier are used on
Windows, macOS, Linux, ChromeOS and Android since Chrome 105+; iOS is
excluded by Apple policy.

### [ ] E11. drill-15's premise
Containers share the host kernel's clock, so "the verifier's clock is wrong"
can't literally happen inside this lab; the drill simulates it with
`-attime`. Say so in the SYMPTOM story (e.g. "a VM/embedded device whose
clock drifted") so the learner doesn't try to reproduce a skewed container
clock.

### [ ] E12. Server leaf `keyEncipherment`
`[ server_cert ]` sets `keyEncipherment`, which only matters for TLS 1.2
static-RSA key exchange (gone in TLS 1.3, disabled by default in modern
stacks). Add one sentence in Day 2's keyUsage paragraph noting it's legacy;
optionally drop it from the config (then re-verify Days 2–6).

### [ ] E13. Concurrent `docker compose run toolbox` collides
`toolbox` has a static IP (10.77.30.10, needed by Day 5's challtestsrv
record), so two simultaneous `run` commands fail. Either document "one
toolbox at a time" in `labs/README.md`, or give Day 5 a dedicated static
`certbot` service and drop the static IP from `toolbox`.

### [ ] E14. Journal nudges
`journal.md` exists but no day's closing text links to it; add a one-line
"write today's entry in ../journal.md" after each day's journal template.

### [ ] E15. Do drills 01–03 give away too much?
After the 2026-09-30 re-verification, the drill-01–03 SYMPTOMs show the
full OpenSSL error stack, which is what a learner really sees. But the
stack's reason text is a strong clue: `invalid padding` points at a wrong
key (drill-01) and `bad signature` at a changed file (drill-02). Decide
whether to keep the stack (realistic) or trim it to the one-line
`Verification failure` (harder). If trimmed, add a note that the full stack
will appear when the learner reproduces the drill.

### [ ] E16. capstone-01 `repro.sh` noise
`repro.sh` prints `openssl ca` output because stderr isn't silenced.
Redirect it (`2>/dev/null` or a `-quiet`-style flag) so the learner sees
only the symptom. Re-run the capstone afterwards.

---

## Done log

- 2026-09-30 — review + live verification + fix pass (see
  `docs/superpowers/` history and the course owner's commit). Essential fixes
  applied: Pebble images/flags, `.gitignore` + `certs/`, client-cert
  extension + `issue-client-cert.sh`, nginx mTLS behaviour, Day 5 ACME
  expected outputs and check-4 verification, tshark filter, drill/capstone
  error codes, 2026 fact updates (revocation, lifetimes, ACM, ECH,
  post-quantum key exchange, clientAuth removal), glossary refresh + links.
  A second live run confirmed all 6 days, 20 drills and 10 capstones. It
  also removed Pebble's `shortlived` profile: Pebble 2.10.1 picks a random
  profile when certbot 2.9 names none, so half the issued certs were 6-day.
