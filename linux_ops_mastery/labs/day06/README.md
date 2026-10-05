# Day 6 lab — the connectivity ladder

**At a glance:**
- **Run from:** repo root — `bash labs/day06/break.sh <1-5|random>`,
  `bash labs/day06/verify.sh`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); diagnose across `proxy`,
  `app`, and `db`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop deviates:** iterate — run `break.sh 1` through
  `break.sh 5` in order (name the rung, journal, fix, verify, each time),
  then `break.sh random` to re-practice blind.

## Start here — plain steps

1. **Start rung 1:** on your Mac, in `linux_ops_mastery/`, make sure the fleet (the lab's Docker containers) is up with `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`. Then run `docker compose -p linuxops ps proxy`. It must say `Up`. If it has exited, rebuild it with `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d --build proxy` — a dead `proxy` makes every rung look like a DNS failure. Then run `bash labs/day06/break.sh 1`. A rung is one step of the connectivity ladder: DNS, route, firewall, listener, application.
2. **Get a shell where you will look:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops exec proxy sh`. The ladder is walked from `proxy`, because `proxy` is the one that cannot reach `app`. For the listener rung you will also need an `app` shell: try `docker compose -p linuxops exec app sh`, and if it says `service "app" is not running`, use `docker exec -it linuxops-app-1 sh` instead. `docker compose -p linuxops exec ws bash` gives you a plain client.
3. **Look at the symptom:** on your Mac, run `docker compose -p linuxops exec ws curl -sv http://proxy/`. It prints nothing useful, and every one of the five faults looks like this. That is on purpose.
4. **Name the rung before you touch anything.** Write down which of the five you think is broken and the one command whose output would prove it. Then ask the ladder questions in order, from DNS down, and stop at the first "no". Do not run a fix until you have named it.
5. **Write the chain in `journal.md` first.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style.
6. **Fix only that rung.** If you recreate a container and Docker reports a name conflict, remove the old one first with `docker rm -f <the container name in the error>`, then bring it back up with `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d <service>`. Then, on your Mac in `linux_ops_mastery/` (type `exit` first if you are still inside a container), run `bash labs/day06/verify.sh`. It exits 0 and prints which rung was at fault.
7. **Repeat for rungs 2 to 5:** on your Mac, in `linux_ops_mastery/` (type `exit` first if you are still inside a container), go one at a time: `bash labs/day06/break.sh 2`, and so on up to `5`. Then try `bash labs/day06/break.sh random` to practice blind.
8. **Strip drill, then tidy up:** on your Mac, run `docker compose -p linuxops exec slim sh` and do the drill in "Strip the toolbox" in `content/day06.md`. Then follow `labs/day06/teardown.md`.

## Goal

"The service is unreachable" resolves to exactly one of five rungs: DNS,
route, firewall, listener, application. Given the fleet with one of those
five broken, name the rung, then fix only that rung.

## Success signal

`bash labs/day06/verify.sh` exits `0` and prints which rung was at fault.

## How to run

```bash
cd linux_ops_mastery/labs/fleet && docker compose -p linuxops up -d --build
bash ../day06/break.sh 1
```

Run all five in order the first time, so you see each rung once before any
repeats:

```bash
bash ../day06/break.sh 1
# name the rung, write the chain in journal.md, fix it, then:
bash ../day06/verify.sh
bash ../day06/break.sh 2
# ... and so on through 5
```

After that, re-practice with a fault you don't get to see in advance:

```bash
bash ../day06/break.sh random
```

Every rerun of `break.sh` — including `random` — first undoes whatever the
previous fault left behind, so exactly one rung is ever broken at a time.

## The rule: name the rung before touching anything

Every one of the five faults prints the identical symptom line:

> `http://localhost:8080/ through proxy returns nothing useful.`

That is deliberate. Five distinct causes producing one indistinguishable
symptom is the entire point of this lab — an operator who reaches for a fix
before naming which rung failed is guessing, not diagnosing. Before running
any command that changes state, write down which of the five rungs you
believe is broken and the one command whose output would prove it. Only
then act. `content/day06.md`'s **Core concepts** and **Lab** sections give
you the ladder; this file does not repeat it.

## No spoilers

If you get stuck, use **Stuck? Hints** at the bottom of this file before opening `SOLUTION.md`. They are opt-in.

Write your chain of evidence into `journal.md`, in the chain-template
format, **before** you fix anything — see `STRATEGY.md`, "The daily loop,"
step 5. `SOLUTION.md` in this directory holds a full model chain for all
five faults; open it only after your own attempt, or after `verify.sh` has
failed you in a way you cannot explain from `content/day06.md` alone.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next. Each ladder is for one `break.sh` number. Hint 1 only tells you which question to ask first; naming the rung is your job.

### Rung 1

<details><summary>Hint 1 — where to look</summary>

From `proxy`, ask the first question on the ladder: can `proxy` turn the name `app` into an address at all?
</details>

<details><summary>Hint 2 — what proves it</summary>

In the `proxy` shell run `getent hosts app`, then `cat /etc/resolv.conf`. Check whether the lookup answers promptly, and which `nameserver` address the file names. Docker's own resolver is `127.0.0.11`.
</details>

<details><summary>Hint 3 — almost there</summary>

`proxy` is asking a resolver at `10.255.255.1` (a DNS server: the name-to-address phone book), and nothing answers there. So `app`'s name never resolves and nginx cannot even try to connect.
</details>

### Rung 2

<details><summary>Hint 1 — where to look</summary>

DNS answers. Next question: does the kernel on `proxy` have a way to send packets to that address?
</details>

<details><summary>Hint 2 — what proves it</summary>

In the `proxy` shell run `ip route get <app-address>`, using the address `getent hosts app` gave you. Then run `ip route show type unreachable`.
</details>

<details><summary>Hint 3 — almost there</summary>

The routing table has a special `unreachable` entry for exactly `app`'s address. The most specific route wins, so the kernel refuses to send anything to `app` and no packet ever leaves.
</details>

### Rung 3

<details><summary>Hint 1 — where to look</summary>

The route is fine. Next question: could something on `proxy` be throwing its own outgoing packets away?
</details>

<details><summary>Hint 2 — what proves it</summary>

In the `proxy` shell run `nft list ruleset` (nft is the Linux firewall tool). Also run `curl -v http://app:8080/healthz` and see that it hangs instead of being refused.
</details>

<details><summary>Hint 3 — almost there</summary>

A firewall table on `proxy`, `table inet day06`, has an output rule that drops every packet going to TCP port 8080. The connection attempt is sent, then silently thrown away, so it hangs.
</details>

### Rung 4

<details><summary>Hint 1 — where to look</summary>

Names, routes and firewall are fine. Next question: is anything actually listening on `app`'s port, and on which address?
</details>

<details><summary>Hint 2 — what proves it</summary>

`curl -v http://app:8080/healthz` from `proxy` fails instantly with "Connection refused". Then, in the `app` shell (see step 2 of Start here for how to get in), run `cat /proc/net/tcp` and find the line ending `:1F90` (port 8080 in hex) with state `0A` (LISTEN). Read its address column.
</details>

<details><summary>Hint 3 — almost there</summary>

`app` is listening only on `127.0.0.1` (`0100007F:1F90`), its own loopback. Other containers cannot reach that address, so `proxy` is refused. `app` was started with `BIND_ADDR` set to `127.0.0.1`.
</details>

### Rung 5

<details><summary>Hint 1 — where to look</summary>

Everything under the application works. Next question: when you do connect to `app`, what does it actually say back?
</details>

<details><summary>Hint 2 — what proves it</summary>

From `proxy`, run `curl -v http://app:8080/healthz`. The connection succeeds. Read the HTTP status line that comes back, then run it again a few seconds later.
</details>

<details><summary>Hint 3 — almost there</summary>

`app` has been switched into a sticky failure mode (it keeps answering with an error status until it is told to stop). The network is healthy; the application itself returns `502`.
</details>

Still stuck: read `SOLUTION.md`.
