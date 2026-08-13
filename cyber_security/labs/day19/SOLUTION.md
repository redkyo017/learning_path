# Day 19 Lab — Solution / IOC Reference

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against this lab's
own `target` container, on `cyberlab`.

## All planted IOCs

| # | IOC | Marker string | Location (inside `target`) | Category |
|---|---|---|---|---|
| 1 | Webshell dropped via unrestricted upload | `IOC:WEBSHELL` | `/var/www/html/uploads/shell.php` | Initial access |
| 2 | Attacker request lines (upload + webshell exec) | `203.0.113.77` | `/var/log/app/access.log` | Initial access (log evidence) |
| 3 | Disguised persistence cron entry | `IOC:PERSISTENCE-CRON` | `/etc/cron.d/sysmon-check` | Persistence |
| 4 | Self-healing persistence script | `IOC:PERSISTENCE-SCRIPT` | `/usr/local/bin/sysmon-check` | Persistence |
| 5 | Backdoor account with passwordless sudo | `svc-monitor` | `/etc/passwd`, `/etc/sudoers.d/svc-monitor` | Persistence |
| 6 | Attacker SSH public key | `mallory@c2` | `/root/.ssh/authorized_keys` | Persistence |
| 7 | Trojanized binary (functionally identical, hash differs) | `IOC:TROJANIZED-BINARY` | `/bin/true` | Defense evasion |
| 8 | Recovered attacker command history | `svc-monitor`, `sysmon-check` | `/root/.bash_history` | Corroborating evidence |
| 9 | SSH login as backdoor account + cron firing | `svc-monitor`, `sysmon-check` | `/var/log/auth.log` | Corroborating evidence |

## Scripted `grep` check confirming every IOC is present in the built image

This requires an actual build (`docker compose up -d --build`), not just
`docker compose config -q` — the config check only validates the compose YAML, it
doesn't build or start anything.

```sh
cd cyber_security/labs/day19
docker compose up -d --build
docker compose exec target sh -c '
set -e
grep -q "IOC:WEBSHELL" /var/www/html/uploads/shell.php          && echo "IOC1 webshell: OK"
grep -q "203.0.113.77" /var/log/app/access.log                  && echo "IOC2 access-log: OK"
grep -q "IOC:PERSISTENCE-CRON" /etc/cron.d/sysmon-check         && echo "IOC3 cron: OK"
grep -q "IOC:PERSISTENCE-SCRIPT" /usr/local/bin/sysmon-check    && echo "IOC4 script: OK"
id svc-monitor >/dev/null 2>&1                                  && echo "IOC5 backdoor-account: OK"
grep -q "mallory@c2" /root/.ssh/authorized_keys                 && echo "IOC6 ssh-key: OK"
grep -q "IOC:TROJANIZED-BINARY" /bin/true                       && echo "IOC7a trojan-marker: OK"
sha256sum -c /opt/evidence/baseline-hashes.txt >/dev/null 2>&1 || echo "IOC7b hash-mismatch-confirmed: OK"
grep -q "svc-monitor" /root/.bash_history                       && echo "IOC8 bash-history: OK"
grep -q "svc-monitor" /var/log/auth.log                         && echo "IOC9 auth-log: OK"
echo ALL_IOCS_PRESENT
'
```

**Expected output:** each `IOC<n> ...: OK` line, in order, followed by
`ALL_IOCS_PRESENT`. Note IOC 7 is checked in **two** parts deliberately: 7a confirms
the marker string is readable in the file (proving it's not the original binary at
all), and 7b confirms the *reason a hash comparison would catch it even without ever
reading the file's contents* — `sha256sum -c` against the pre-tampering baseline
**must fail** (non-zero exit) for `/bin/true`, which is why the check is
`... || echo "... OK"` rather than `&&` — the failure itself is the confirmation.

Evidence copied by `entrypoint.sh` at boot (the acquisition path README.md's
"Primary path" investigates) contains the same content under
`/loot/day19/evidence/*` — confirm from `labs/base`:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c '
set -e
test -s /loot/day19/evidence/shell.php               && echo "acquired: shell.php OK"
test -s /loot/day19/evidence/access.log              && echo "acquired: access.log OK"
test -s /loot/day19/evidence/sysmon-check.cron        && echo "acquired: sysmon-check.cron OK"
test -s /loot/day19/evidence/sysmon-check.sh          && echo "acquired: sysmon-check.sh OK"
test -s /loot/day19/evidence/root_authorized_keys     && echo "acquired: authorized_keys OK"
test -s /loot/day19/evidence/root_bash_history        && echo "acquired: bash_history OK"
test -s /loot/day19/evidence/auth.log                 && echo "acquired: auth.log OK"
diff -q /loot/day19/evidence/baseline-hashes.txt /loot/day19/evidence/current-hashes.txt >/dev/null 2>&1 \
    || echo "acquired: hash-mismatch-confirmed OK"
echo ACQUISITION_OK
'
```

## Initial access

**Vector:** an unrestricted file-upload endpoint (`POST /uploads.php`) let the
attacker (`203.0.113.77`) upload a PHP webshell, then invoke it directly at
`GET /uploads/shell.php?cmd=...` to run arbitrary commands. Evidence:
`/var/log/app/access.log`:

```
203.0.113.77 - - [10/Aug/2026:14:02:55 +0000] "POST /uploads.php HTTP/1.1" 200 512 "-" "curl/7.88.1"
203.0.113.77 - - [10/Aug/2026:14:03:07 +0000] "GET /uploads/shell.php?cmd=id HTTP/1.1" 200 45 "-" "curl/7.88.1"
```

The `POST /uploads.php` at `14:02:55` is the actual foothold moment — everything after
is post-exploitation through the shell it created; the first webshell-invoking `GET`
seven seconds later is the earliest confirmed *use* of that foothold, a useful
distinction when a report asks "when did the attacker actually get in" versus "when
did we first see them do something."

## Persistence mechanisms and eradication

| Mechanism | Eradication |
|---|---|
| Cron entry `/etc/cron.d/sysmon-check` | Delete the file; verify with `crontab -l` and a full listing of `/etc/cron.d/` that nothing else was added alongside it. |
| Script `/usr/local/bin/sysmon-check` | Delete the file (removing only the cron entry but leaving this in place would let a re-added cron entry, or any other scheduler, immediately restore the backdoor). |
| Backdoor account `svc-monitor` | `userdel -r svc-monitor` (removes the account and its home directory); also remove `/etc/sudoers.d/svc-monitor`. |
| Attacker SSH key in `/root/.ssh/authorized_keys` | Remove the specific `mallory@c2` line — don't just delete the whole file if legitimate keys share it; diff against a known-good copy if one exists. |
| Trojanized `/bin/true` | Do not attempt to "fix" it in place — restore from a trusted source (package reinstall, e.g. `apt-get install --reinstall coreutils`, or a verified clean snapshot), then re-hash and compare against baseline again. |

Eradicating the cron entry **without** also removing the script and the account/key it
maintains is the single most common mistake here: the script is what's self-healing,
not the cron entry alone — miss it, and any other trigger (a different cron job, a
systemd timer, manual re-execution) can re-plant the account/key again. All five rows
should be treated as one unit, removed together, then re-verified.

## Evidence to preserve (chain of custody)

In rough order of volatility (most volatile / most likely to change or disappear
first) for a **real** host — this container's static IOCs don't decay, but the order
still matters as the general principle to internalize:

1. Running processes / open network connections (gone the instant the box reboots or
   the process exits).
2. In-memory artifacts relevant to the incident (nothing container-specific here, but
   on a real host: injected code, decrypted secrets only ever held in RAM).
3. Logs that rotate or get truncated (`access.log`, `auth.log`) — copy them before
   log rotation or an attacker's cleanup script can touch them.
4. Command history (`.bash_history`) — attackers frequently clear this
   deliberately (this lab's own `bash_history` even ends with `history -c`, left
   in place so you can see the attempt); recovering it before it's cleared, or from a
   backup/journal that survives clearing, is often the single most useful piece of
   evidence for reconstructing intent.
5. On-disk artifacts that are stable once written (the webshell file, the persistence
   script, the cron entry, `authorized_keys`) — least urgent to grab first, but still
   copied, hashed, and preserved before any remediation touches them, since
   remediation (Eradication) necessarily destroys them from the live system.

Practically, in this lab: `target/entrypoint.sh` performs the acquisition step (item
3–5 above, copied to `/loot/day19/evidence/` before you do anything else), and
`sha256sum` over each copied file (recorded once you run your own investigation) is
what would let you prove later that your copy wasn't altered after acquisition — the
same reason `current-hashes.txt` records hashes of the state *as found*, before any
eradication step touches the live system.

## Example filled-in incident report (excerpt)

Full template: [`incident-report-template.md`](incident-report-template.md). Key
sections filled from this investigation:

- **Initial access:** unrestricted upload endpoint (`/uploads.php`) → webshell
  (`/uploads/shell.php`) → arbitrary command execution as the web server user.
- **Timeline (abridged):**

  | Timestamp (UTC) | Event | Evidence |
  |---|---|---|
  | 2026-08-10 14:02:55 | Webshell uploaded | `access.log` |
  | 2026-08-10 14:03:07–14:04:12 | Webshell used to recon + fetch persistence script | `access.log` |
  | 2026-08-10 14:04:20 | Backdoor account `svc-monitor` created | `auth.log` |
  | 2026-08-10 15:10:02 | Attacker SSH login as `svc-monitor` | `auth.log` |
  | 2026-08-11 03:00:01 | Persistence cron fires (first observed) | `auth.log` |

- **Persistence found:** cron + script + backdoor account + SSH key (all four, one
  unit — see table above).
- **Evidence preserved:** `access.log`, `auth.log`, `sysmon-check.{cron,sh}`,
  `authorized_keys`, `bash_history`, `/bin/true` hash mismatch — all copied to
  `/loot/day19/evidence/` before any eradication step.

## Verify (static validation)

```sh
cd cyber_security/labs/day19
docker compose config -q
```

**Expected output:** nothing, exit code 0.
