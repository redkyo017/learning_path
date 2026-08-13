# Lab Base — Attacker Toolbox + `cyberlab` Network

## Authorized use only

Everything in this container is offensive security tooling (`nmap`,
`hashcat`, `hydra`, `sqlmap`, `tshark`, ...). Only use it against:

- containers started by this learning path on the `cyberlab` docker
  network, or
- your own AWS sandbox account (Phase 3+ labs).

Never point this toolbox at any system you do not own or do not have
explicit written authorization to test.

## What this is

This is the shared infrastructure every day-lab in `cyber_security/labs/`
builds on:

- **`attacker` service** — a Kali-rolling-based container with the core
  toolset installed (`nmap`, `tcpdump`, `tshark`, `netcat-traditional`,
  `curl`, `dnsutils`, `john`, `hashcat`, `hydra`, `sqlmap`, `gobuster`,
  `whatweb`, `jq`, `git`, `openssl`, `iproute2`, `iputils-ping`, `vim`).
- **`cyberlab` network** — a dedicated docker bridge network. Day-labs
  attach their own `target`/`victim`/`server` containers to this same
  network (declared as `external: true`, `name: cyberlab`) so the
  attacker container can always reach them by service name.
- **`./loot` volume** — mounted at `/loot` inside the attacker container.
  Shared scratch space for scan output, cracked hashes, captures, etc.
  Day-labs may write into a day-scoped subdirectory here
  (e.g. `/loot/day02/`) to avoid collisions.

Image size note: `kalilinux/kali-rolling` plus this tool list is a large
image (multiple GB after the first build). This is expected — the build
is a one-time cost per machine, cached by Docker afterward. If
`kalilinux/kali-rolling` is not pullable in your environment, edit
`attacker/Dockerfile` and swap the `FROM` line for `debian:bookworm-slim`
(the fallback is documented as a comment in that file); every listed
package is also available in Debian's repos.

## How to build and start

```sh
cd cyber_security/labs/base
./up.sh
```

This builds the attacker image and starts it (detached) on the
`cyberlab` network.

## How to shell in

```sh
docker compose exec attacker bash
```

## How `cyberlab` is reused by later labs

Each `labs/dayNN/docker-compose.yml` declares the same network as
external instead of redefining it:

```yaml
networks:
  cyberlab:
    external: true
    name: cyberlab
```

That lets a day-lab's `target`/`victim` service join the same network
the `attacker` container is already on, so `docker compose exec attacker
sh -c "nmap target"` (or similar) works without extra wiring. Because the
network is created here in `labs/base`, **`./up.sh` must be run before**
any day-lab's `docker compose up`.

## Verifying the toolbox

```sh
cd cyber_security/labs/base
./up.sh
docker compose exec attacker sh -c "nmap --version >/dev/null && sqlmap --version >/dev/null && hashcat --version >/dev/null && hydra -h >/dev/null 2>&1; echo TOOLS_OK"
```

Expected: each tool prints a version banner, and the last line is
`TOOLS_OK`.

**Note on `hydra`:** `hydra -h`/`hydra` with no target always exits with
status `255` by that tool's own design (it is not a "success" exit code
the way `--version` is for the other tools). A naive
`hydra -h >/dev/null 2>&1 && echo TOOLS_OK` chain will therefore never
print `TOOLS_OK`, even though hydra is installed and working correctly.
The command above tolerates that; if you'd rather sanity-check hydra
directly, run `docker compose exec attacker sh -c "hydra -h 2>&1 | head -1"`
and confirm it prints hydra's usage banner instead of "command not
found."

## Teardown

```sh
cd cyber_security/labs/base
./down.sh
```

Runs `docker compose down -v`, removing the attacker container, the
`cyberlab` network, and the compose-managed volumes. Tear down any
day-lab still attached to `cyberlab` first (Docker will otherwise refuse
to remove the network until nothing is attached to it).
