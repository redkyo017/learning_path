# Day 5 — SOLUTION

Two independent incidents, two chains, in `journal.md`'s exact chain
template. Compare your own chain against these claim by claim — a chain
that reaches the same diagnosis by a different, equally file-backed route
is not wrong.

## Chain 1 — the 0777 file that still denies read

### Day 5 — 0777 file, appuser still denied

**Symptom (verbatim, no interpretation):**
`appuser cannot read /srv/reports/q3.txt (mode 777)`, per `break.sh`'s
`symptom` line.

**Resource class:** process table (identity: appuser's uid crossing the
mode bits of every component in the path, not just the target file)

**Chain of evidence:**
1. Claim: the file itself is not the problem — its own mode already grants
   everyone read, write, and execute. | Proof:
   `stat -c '%A %U %G %a' /srv/reports/q3.txt` →
   `-rwxrwxrwx root root 777`
2. Claim: `ls -l` on the file alone cannot explain a denial, because it
   only describes the file, never the path that leads to it (Mistake 2 —
   trusting the summary tool, applied here to a single `ls -l` line
   instead of a full path check). | Proof: the line above is the entire
   output; nothing in it mentions `/srv/reports` itself.
3. Claim: the file's mode is deliberately misleading; the claim must move
   up the path, to every directory component between `/` and the file.
   | Proof: `namei -l /srv/reports/q3.txt` →
   ```
   f: /srv/reports/q3.txt
   drwxr-xr-x root root /
   drwxr-xr-x root root srv
   drw------- root root reports
   -rwxrwxrwx root root q3.txt
   ```
4. Claim: `/srv/reports` is the actual denial — mode `600` gives owner
   `root` read and write but **no execute (search) bit at all**, for
   anyone, including root's own non-capability path. `appuser` is neither
   the owner nor in the owning group, so it lands in the "other" triad,
   which here is `---`. | Proof: the `reports` line above, `drw-------`,
   has no `x` in any of the three triads.

**Diagnosis:**
The directory execute bit, not the file's own mode, is the denial.
Traversing a path requires the execute (search) permission on *every*
directory component along it, independent of the permissions on the
file at the end — a file can be world-readable and still unreachable if
one directory above it lacks `x` for the caller's uid/gid class. `appuser`
fails the search on `/srv/reports` itself and never gets far enough to
have its `0777` permissions on `q3.txt` evaluated at all.

**Fix applied:**
`chmod o+rx /srv/reports` — adds search (traverse) and directory-listing
read to the "other" triad only, leaving owner and group bits untouched.
Directory mode goes from `600` to `605` (owner `rw-` unchanged, group
`---` unchanged, other `r-x` added). Note the owner triad still has no
`x` at `605` — root can still traverse the directory as owner, but only
because root bypasses the directory-search check entirely
(`CAP_DAC_READ_SEARCH`); a non-root owner of this same directory would be
just as locked out as `appuser` was.

**Rejected fix — `chmod 777 /srv/reports`:** this "works," in the sense
that it also clears the symptom, which is exactly the danger (Mistake 6 —
deferring the permission model until `chmod 777` becomes the reflex). It
grants strangers write access to the directory itself — the ability to
create, rename, and delete entries inside it, including files they do not
own — when the only bit that was ever missing was `x` for one triad. It
also leaves the actual root cause (a directory created too restrictively
by the deploying process) undiagnosed, so the next directory this same
process creates fails the identical way, and this time `777` gets reached
for by habit instead of by evidence.

**Proof the fix worked (same file re-read):**
`namei -l /srv/reports/q3.txt` now shows `drw----r-x root root reports`,
and `sudo -u appuser cat /srv/reports/q3.txt` prints `quarterly numbers`.

**What I would check first next time:**
Run `namei -l <path>` on the very first permission denial, before looking
at the target file at all — it is the one command that renders every
component's owner/group/mode in a single pass, and it would have made
this a five-second diagnosis instead of a `chmod 777` guess.

## Chain 2 — the unit that will not start

### Day 5 — labs-api.service fails at exec

**Symptom (verbatim, no interpretation):**
`labs-api.service will not start`, per `break.sh`'s `symptom` line.

**Resource class:** process table (systemd is the process that forks and
execs the unit's process; the failure is in that exec, not in a resource
limit)

**Chain of evidence:**
1. Claim: the unit loaded and attempted to run, but is not active now.
   | Proof: `systemctl status labs-api.service` →
   `Active: failed (Result: exit-code)`
2. Claim: the failure happened at the exec step itself, not after the
   process was running. | Proof: `journalctl -u labs-api -b` →
   ```
   labs-api.service: Failed at step EXEC spawning /usr/local/bin/labs-api: No such file or directory
   labs-api.service: Main process exited, code=exited, status=203/EXEC
   ```
3. Claim: `203/EXEC` means the kernel's `execve()` itself failed — the
   binary named in `ExecStart` does not exist at that path. | Proof: same
   journal line as above; `203` is systemd's fixed exit code for "could
   not exec the configured command," distinct from the service's own exit
   status.
4. Claim: the binary exists, just under a different name. | Proof:
   `ls -l /usr/local/bin` → lists `labs-apid`, not `labs-api`.
5. Claim: even with the path fixed, this unit's start order relative to
   `labs-db.service` was never guaranteed. | Proof: reading
   `/etc/systemd/system/labs-api.service` directly shows
   `Requires=labs-db.service` and no `After=` line anywhere in the file.

**Diagnosis:**
Two independent defects, both visible only by reading files directly, not
by guessing from the symptom:

- `ExecStart=/usr/local/bin/labs-api …` names a path `break.sh` never
  creates; the stub it installs is `/usr/local/bin/labs-apid`. Every start
  attempt fails at `execve()` with `203/EXEC`.
- `Requires=labs-db.service` with no matching `After=` means systemd
  guarantees `labs-db.service` is *present* (started, or the unit fails)
  but makes no promise about *sequence* — `labs-api` can be told to start
  concurrently with, or even fractionally before, `labs-db`. It happens to
  come up fine here because `labs-db`'s own `ExecStart` is `sleep
  infinity` and never fails, but a real client that dials the database on
  its first line of code would race it.

**Fix applied:**
1. `ExecStart=/usr/local/bin/labs-apid --port 8080` in
   `/etc/systemd/system/labs-api.service`.
2. Add `After=labs-db.service` next to the existing `Requires=labs-db.service`
   — `Requires=` alone is not deleted; the pair is what's correct, because
   `After=` orders without requiring and `Requires=` requires without
   ordering. Either alone leaves half the bug in place.
3. `systemctl daemon-reload` — systemd parses unit files into an in-memory
   graph at load time and does not watch `/etc/systemd/system/*.service`
   for edits; without this step the edited file on disk is invisible to
   `systemctl`, and `systemctl start` would repeat the exact same
   `203/EXEC` failure against the stale in-memory definition.
4. `systemctl restart labs-api.service`.

**Proof the fix worked (same file re-read):**
`systemctl is-active labs-api.service` → `active`.
`journalctl -u labs-api -b --since "1 min ago"` → `labs-api listening`.
Re-reading the unit file, `grep -E 'After=|Requires=' \
/etc/systemd/system/labs-api.service` now shows both
`Requires=labs-db.service` and `After=labs-db.service`.

**What I would check first next time:**
Any `203/EXEC` in `journalctl -u <unit>` means "go read `ExecStart=`'s
path with `ls -l`, do not assume permissions or the service's own logic" —
and any unit carrying `Requires=` for another unit gets grepped for a
matching `After=` on sight, because the two directives look like a pair
and are not one.
