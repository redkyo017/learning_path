# Day 0 Lab — Bootstrap the Attacker Toolbox

## Authorized use only

This lab starts no vulnerable target — it only brings up the shared attacker toolbox.
That toolbox (`nmap`, `hashcat`, `hydra`, `sqlmap`, `tshark`, ...) is offensive security
tooling. From Day 1 onward, only ever point it at containers this learning path starts
on the `cyberlab` docker network, or your own AWS sandbox account (Phase 3+). Never
target a system you don't own or don't have explicit written authorization to test.

## What this lab is

Day 0 has no dedicated `docker-compose.yml` — there's nothing to break yet. Instead,
this lab is the entry point to [`labs/base`](../base/README.md), the shared
infrastructure every later day-lab depends on:

- the `attacker` container (the Kali-rolling-based toolbox), and
- the `cyberlab` docker bridge network that later day-labs attach their targets to.

Confirming this works today means every day from Day 1 on can assume it's already
in place.

## Setup

```sh
cd cyber_security/labs/base
./up.sh
```

This builds the attacker image (large — a multi-GB Kali-rolling image; expect several
minutes on the first run, cached afterward) and starts the container detached on the
`cyberlab` network.

## Verify

Run the exact command below (this is the Day 0 lab verify from the implementation
plan), from `cyber_security/labs/base`:

```sh
docker compose exec attacker sh -c "echo LAB_READY"
```

**Expected output:** `LAB_READY`

That single line confirms three things at once: the image built successfully, the
container is running and attached to `cyberlab`, and `docker compose exec` can reach a
shell inside it — the exact mechanism every later day's lab verify command relies on.

### Optional deeper check

If you want to confirm the actual toolset (not just that the container is reachable),
reuse the fuller check from `labs/base` (run from `cyber_security/labs/base`):

```sh
docker compose exec attacker sh -c "nmap --version >/dev/null && sqlmap --version >/dev/null && hashcat --version >/dev/null && hydra -h >/dev/null 2>&1; echo TOOLS_OK"
```

Expected: version banners scroll by, ending in `TOOLS_OK`. (Note: `hydra -h` always
exits non-zero by hydra's own design, even when it's working correctly — the `;`
before `echo TOOLS_OK` is intentional so that quirk doesn't block the check. See
`labs/base/README.md` for detail.)

## Walkthrough

1. `./up.sh` from `labs/base` — builds and starts the attacker container.
2. Shell in interactively if you want to poke around (from `cyber_security/labs/base`):
   `docker compose exec attacker bash`. Try `nmap --version`, `which hashcat`, `ls /loot`
   — there's nothing to attack yet, but this is your chance to confirm the environment
   feels usable before Day 1 asks you to do real work in it.
3. Run the verify command above and confirm `LAB_READY`.
4. Leave the container running (it's shared infra reused every day) or tear it down —
   your choice; see below.

## Teardown

```sh
cd cyber_security/labs/base
./down.sh
```

You can also simply leave `labs/base` running between sessions — it has no target
attached yet, so there's no exposure to worry about beyond the toolbox container
itself. If you do tear it down, remember to `./up.sh` again before starting Day 1's
lab, since Day 1's target container attaches to the `cyberlab` network created here.

See [`labs/day00/SOLUTION.md`](SOLUTION.md) for the full verify walkthrough and expected
output, and [`content/day00-ignition.md`](../../content/day00-ignition.md) for the
STRIDE concept, defense-lab exercise, and drills this lab supports.
