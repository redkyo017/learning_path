# Enhancements — deferred, not blocking

Everything below is optional polish. Each item was found in review, judged non-blocking,
and left on purpose. The course was live-verified without them (see
`labs/netlab/PROBE.md`, "Verification log").

## Labs and tooling

- `labs/verify-teardown.sh` treats a failing `docker compose ps` (for example a missing
  compose plugin) as CLEAN, and plain `ps -q` does not see stopped containers. Check the
  command's exit status and use `ps -aq`.
- `labs/netlab/probe.sh` re-executes itself with `bash "$0"`, so it only works when run
  from `/course`. Resolve its own path from `BASH_SOURCE` instead.
- `labs/lib/common.sh` `frr_up` does not check that the FRR config file is readable by
  user `frr`. Days 5 and 7 work on the bind mount today. A config created with mode 0600
  would fail silently.

## Content

- `README.md` "Cost" paragraph has two adjacent parentheticals (one names what drives the
  cost, the other lists what runs). Merge them into one sentence.
- Day 7's gauntlet draws on the failure classes of Days 2–6. No incident comes from Day 1
  (L2: duplicate MAC, stale neighbour). A sixth, optional incident would close that.
- Day 4 teaches "conntrack table full" in theory and an exercise only. A lab step that
  lowers `nf_conntrack_max` in a namespace is the missing proof on the wire. Check first
  whether the limit is per-namespace on your kernel.
- The fact-check optional additions not applied: a note that TGW VPN attachments stay at
  MTU 1500, and a note on NLB UDP client-IP preservation.

## Closing a gap later

The skipped topics and the cheapest local recipe for each are in `COVERAGE.md`,
"Deliberately skipped, and why".
