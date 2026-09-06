# Day 6 lab — the connectivity ladder

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

Write your chain of evidence into `journal.md`, in the chain-template
format, **before** you fix anything — see `STRATEGY.md`, "The daily loop,"
step 5. `SOLUTION.md` in this directory holds a full model chain for all
five faults; open it only after your own attempt, or after `verify.sh` has
failed you in a way you cannot explain from `content/day06.md` alone.
