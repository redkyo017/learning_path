# Day 1 solution — two faults, one symptom

Symptom: "h1 can reach h2 only sometimes, and never h3. Nobody changed an IP address."

Two faults were injected. Fault A: h3 carries h2's MAC address. Fault B: h1 has a
PERMANENT neighbour entry for h3 with a MAC that nobody owns. A background `ping` in h3
(started by `break.sh`) keeps h3 transmitting, which the flapping in step 4 needs.

## Chain of evidence

1. **The ping fails.** `ip netns exec h1 ping -c3 -W1 10.1.0.3` prints 100% loss. An
   IP address was not changed, so the fault is below IP: the frame never reaches the
   right NIC.
2. **No ARP request for .3.** In shell A run `ip netns exec h1 tcpdump -eni eth0 arp or icmp`,
   and in shell B `ip netns exec h1 ping -c2 -W1 10.1.0.3`. You see ICMP echo requests
   addressed to `02:00:00:00:01:99`, and no `who-has 10.1.0.3` from h1. A host only
   sends ARP when it has no usable entry: the entry exists and h1 trusts it. (Lines
   from h3, such as `who-has 10.1.0.1 tell 10.1.0.3` with source MAC `02:00:00:00:01:02`,
   come from its background ping. That source MAC is itself a clue.)
3. **A PERMANENT neighbour with the wrong MAC.** `ip -n h1 neigh show` lists
   `10.1.0.3 dev eth0 lladdr 02:00:00:00:01:99 PERMANENT`. PERMANENT never ages, never
   re-ARPs and never expires. No NIC owns `…:99`, so the bridge floods the echo to every
   port and nobody accepts it.
4. **A MAC that moves between ports.** In shell A run
   `ip netns exec h1 ping -i 0.5 10.1.0.2` (it shows about half the replies missing; one
   run lost 6 of 12). In shell B poll the table:

   ```bash
   for i in 1 2 3 4 5 6; do bridge -n sw fdb show br br0 | /usr/bin/grep 02:00:00:00:01:02; sleep 1; done
   ```

   Observed: `dev p3`, `dev p2`, `dev p2`, `dev p3`, `dev p2` on successive polls. The
   entry moves because both h2 and h3 transmit frames with source MAC `…:02`, and the
   bridge re-learns the address from whichever frame it saw last. Frames for h2 go to
   h3 half the time. That is the "sometimes" in the symptom.
5. **Confirm the duplicate.** `ip -n h2 -br link show eth0` and `ip -n h3 -br link show eth0`
   both print `02:00:00:00:01:02`.

Order matters: the PERMANENT entry masks the duplicate for traffic to h3, so you find it
first. The duplicate explains the intermittent loss to h2.

## Fixes

1. Remove the static entry. It is a fault, not a feature:

   ```bash
   ip -n h1 neigh del 10.1.0.3 dev eth0
   ```

2. Restore h3's own MAC, and drop stale neighbour state learned while the duplicate
   existed:

   ```bash
   ip -n h3 link set eth0 address 02:00:00:00:01:03
   ip -n h1 neigh flush dev eth0
   ```

Then `bash labs/day01/verify.sh`. Expect four `ok` lines and PASS.

Partial repairs: after fix 1 alone, `MACs on h1..h3 are unique` stays FAIL, and the
ping checks can fail at random while the duplicate exists (the symptom, still on).
After fix 2 alone, `h1 reaches h3` and `h1 has no PERMANENT neighbour entries` stay FAIL.
The `neigh flush` matters: without it h1 can hold a STALE entry for h3 learned during
the duplicate, so the first pings still go to the wrong MAC until the entry re-probes.

## What this proves

The IP layer was never wrong. Layer 2 delivery depends on two tables: the neighbour
table on each host (IP to MAC) and the bridge FDB (MAC to port). Fault B poisoned the
first with an entry that never expires. Fault A corrupted the second by making a MAC
address ambiguous.
