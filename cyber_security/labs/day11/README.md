# Day 11 Lab — Replay Three Earlier Attacks, Detect All Three

## Authorized use only

This lab's `target` and `detection` containers exist only to be attacked and to
detect those attacks, from the shared `attacker` toolbox, over the `cyberlab` network
(and `detection`'s shared network namespace with `target` — see below). Never point
any of today's replayed attacks (port scan, brute force, SQL injection) at a system you
don't own or don't have explicit written authorization to test.

## What this lab is

`labs/day11/docker-compose.yml` adds two services. It does **not** redefine the
`attacker` service — that container is shared infrastructure, already running from
Day 0 (`labs/base`).

- **`target`** ([`target/`](target)) — one small Flask app carrying three attack
  surfaces at once, all logged as structured JSON to `/var/log/webapp/access.log`
  (shared with `detection` via the `weblogs` volume):
  - Port `5000` itself is scannable — today replays Day 2's `nmap -sS` technique
    against it.
  - `POST /login` is a weak, unlimited login (`admin` / `hunter2`, no rate limiting, no
    lockout) — today replays Day 4's brute-force technique against it.
  - `GET /search?q=` is UNION-based-SQLi-vulnerable — today replays Day 8's planned
    injection technique against it. **Scope note:** Day 8 ("Web attacks I: injection &
    XSS") hasn't shipped yet in this path's build order at the time this lab was
    written, so rather than pretend to reuse a target that doesn't exist yet, this lab
    builds its own minimal SQLi surface. Once Day 8 ships, its target is the more
    complete version of this same lesson.
- **`detection`** ([`detection/`](detection)) — three detectors, all consolidating
  into one file: `/var/log/detect.log`.
  - **Suricata**, loaded with only [`rules/suricata/local.rules`](rules/suricata/local.rules)
    (one signature-based rule: 5+ bare-SYN packets to port 5000 from the same source
    within 10 seconds).
  - **fail2ban**, loaded with the [`target-bruteforce`](rules/fail2ban) jail/filter (5
    failed `/login` attempts within 60 seconds → banned for 300 seconds).
  - A small jq-based watcher ([`detection/sqli_watch.sh`](detection/sqli_watch.sh)) —
    the "structured JSON logs + jq" half of the Global Constraints' lightweight-stack
    requirement — that flags any `search_query` log line whose `query` field looks like
    a SQLi payload (`UNION SELECT`, a trailing `--` comment, or an `OR 1=1` tautology).

### Why `detection` shares `target`'s network namespace

`detection` runs with `network_mode: "service:target"` instead of joining `cyberlab`
on its own. Two concrete reasons, not an accident:

1. **Suricata needs to sniff the SAME interface the scan traffic actually arrives
   on** — `target`'s own `eth0`, not some other container's.
2. **fail2ban's ban action edits iptables in that same network namespace** — so a ban
   actually blocks the attacker's traffic from reaching `target`, the same way a real
   fail2ban/Suricata pair is normally deployed (on the same host as the service they
   protect).

A consequence worth knowing before you start: `docker compose exec detection ...`
works exactly like any other exec (Compose only needs the container running, not
network-reachable), but `detection` has no IP address of its own on `cyberlab` — it is
literally `target`, network-wise.

## Resource notes (keep this laptop-friendly)

- `detection`'s image adds Suricata + fail2ban + jq on top of `debian:bookworm-slim` —
  noticeably smaller than a real ELK stack (no JVM, no Elasticsearch, no Logstash).
  Expect roughly 150–300 MB of resident memory once Suricata is running (its default
  protocol-parser set is loaded even though only one custom rule is active) and low,
  bursty CPU — spikes only while a scan or brute force is actively in progress, idle
  otherwise.
- `target` itself is a single-process Flask dev server plus an in-memory SQLite
  database — negligible resource use.
- **`cap_add: [NET_ADMIN, NET_RAW]`** is scoped to `detection` only — `target` and
  `attacker` remain unprivileged.
- If your Docker environment doesn't support AF_PACKET capture inside a container
  (some restricted/sandboxed hosts don't), Suricata's `-i eth0` invocation in
  [`detection/entrypoint.sh`](detection/entrypoint.sh) may need to fall back to
  `--pcap=eth0` (libpcap mode) — see "If something doesn't match" in
  [`SOLUTION.md`](SOLUTION.md).

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's targets:

```sh
cd cyber_security/labs/day11
docker compose up -d --build
```

Give `detection` a few seconds after startup — Suricata's protocol-parser
initialization and fail2ban's own startup both take a moment before either is
actually watching.

## Running `docker compose exec` for this lab

Exactly like every earlier day: `attacker` is defined in
`labs/base/docker-compose.yml`, not in this lab's compose file. Run every
`docker compose exec attacker ...` command **from `labs/base`**:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s target:5000/"
```

`detection` (and `target`) exec commands run **from `labs/day11`**, since both are
defined there:

```sh
cd cyber_security/labs/day11
docker compose exec detection sh -c "tail -20 /var/log/detect.log"
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "for i in $(seq 1 6); do curl -s -X POST target:5000/login -d 'username=admin&password=wrong' >/dev/null; done"
cd ../day11
docker compose exec detection sh -c "grep -Eiq 'ban|alert|fail' /var/log/detect.log && echo DETECT_OK"
```

**Expected output:** `DETECT_OK`. The six failed logins cross the
`target-bruteforce` jail's `maxretry = 5` threshold, fail2ban bans the attacker's
source IP, and the consolidator in `entrypoint.sh` writes an `ALERT [bruteforce] ...`
line into `/var/log/detect.log` that the final `grep` matches.

## Walkthrough

1. Bring up `labs/base` and `labs/day11` as above.
2. From `labs/base`, work through Section 2 of
   [`content/day11-detection.md`](../../content/day11-detection.md) in order — replay
   the port scan, the brute force, and the injection against `target`.
3. From `labs/day11`, work through Section 3 (detection) — confirm each detector's
   own native log (`suricata/fast.log`, `fail2ban.log`) fired, then confirm all three
   land in the consolidated `/var/log/detect.log`.
4. Run the Verify command above and confirm `DETECT_OK`.
5. Try Drill 2 (tuning out a false positive) yourself before checking `SOLUTION.md`.

Full expected output for every command above, including the Suricata alert, the
fail2ban ban line, and the jq match on the injected query:
[`labs/day11/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day11
docker compose down -v
```

This removes `target`, `detection`, and the `weblogs` volume — `labs/base`'s
`attacker` container and the `cyberlab` network are untouched, since they're shared
infrastructure other days depend on too. Tear down `labs/base` separately (`cd
../base && ./down.sh`) only once you're done with the whole session.
