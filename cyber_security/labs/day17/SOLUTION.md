# Day 17 Lab — Solution

Full worked answers for the Attack/Assess findings, the Defense Lab fixes, and the
drills in `content/day17-cloud-network.md`. Try the lab and drills yourself first.

## 1. The security group's rules, and which are risky

`setup.sh` creates exactly three ingress rules on `day17-exposed-sg`:

| # | Protocol | Port(s) | Source | Verdict |
|---|---|---|---|---|
| A | tcp | 80 | 0.0.0.0/0 | **Not risky** — this is the instance's actual job (a public web server). HTTP to the world is exactly what this rule should say. |
| B | tcp | 22 | 0.0.0.0/0 | **Risky.** SSH is a management port; it should never be reachable from the entire internet, only from a specific bastion/admin CIDR (or not exposed at all, if no interactive access is needed — which is this lab's actual case). |
| C | tcp | 0-65535 | 0.0.0.0/0 | **Risky, and the worst rule in the group.** A full TCP port range open to the world means anything that ever starts listening on this instance — today or in six months, by design or by accident (a forgotten debug server, a misconfigured test service) — is automatically internet-reachable with zero additional SG change required. This is the single most dangerous *category* of SG misconfiguration: not a specific bad port, but the complete absence of a gate for whatever opens next. |

### The fix

```sh
SG_ID=<from setup.sh output>
# Remove both risky rules.
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0
# If SSH access is genuinely needed, re-add it scoped to only your own IP
# (or a real bastion/admin CIDR in a production account) rather than the world:
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32"
```

Rule A (`80/tcp` from `0.0.0.0/0`) is left untouched — it's the intended, correctly
scoped rule, and "least privilege" means removing what's *not* needed, not removing
everything.

### Confirming the fix with the same external scan used to find the problem

Before the fix:

```sh
nmap -Pn -p 22,80 <PUBLIC_IP>
# 22/tcp open, 80/tcp open
```

After the fix (from any vantage point other than the `MY_IP` you scoped SSH to):

```sh
nmap -Pn -p 22,80 <PUBLIC_IP>
# 22/tcp filtered (or closed), 80/tcp open
```

Same tool, same target, same command — a materially different, independently
verified result, purely because the SG rules changed. This before/after discipline
(re-attack with the identical tool used to find the issue) is what turns "I fixed it"
from a claim into a demonstrated fact.

## 2. Security group vs NACL — the mechanical difference, and when each applies

| | Security Group | NACL |
|---|---|---|
| Attaches to | The instance/ENI | The subnet (every instance in it inherits the same NACL) |
| State | Stateful — an allowed inbound request's reply is automatically allowed outbound, no matching rule needed | Stateless — inbound and outbound are two entirely separate rule sets; a reply needs its own explicit rule (typically an ephemeral-port range) |
| Rule types | Allow only — nothing not explicitly allowed gets through, and there's no way to write an explicit "deny" | Allow **and** explicit **Deny** — a NACL can actively block traffic that something else would otherwise allow |
| Evaluation | All attached SGs' rules evaluated together; if any rule allows the traffic, it's allowed | Rules evaluated **in ascending rule-number order**; the **first matching rule wins**, so order matters |
| Default state | A new custom SG denies all inbound by default | The VPC's default NACL allows all inbound/outbound by default — so out of the box, SGs are doing the real filtering |

**When a security group is the right tool:** per-instance, day-to-day rules about what
that specific instance's job requires — e.g. "this web server accepts `443` from
anywhere and SSH only from the bastion." Stateful behavior (not having to separately
allow the reply) and allow-only semantics (nothing here needs an explicit block) make
an SG simpler for this than a NACL would be.

**When a NACL is the right tool:** a rule that must hold regardless of what any
individual instance's SG says — e.g. "block this known-bad CIDR from reaching
*anything* in this subnet," or Defense Lab Step 2's backstop deny on `22/tcp`, which
keeps working even if someone later reopens SSH on the SG by mistake. A NACL is the
tool specifically because it doesn't consult the SG at all (and vice versa) — losing
one layer doesn't silently lose both.

**Why you generally want both, not one instead of the other:** the SG is the primary,
precise, per-instance control you tighten to least privilege first. The NACL is a
coarser, subnet-wide safety net for rules you never want to depend on every instance's
SG staying correct forever.

## 3. What Flow Logs show for the external scan

VPC Flow Logs record **connection metadata**, not payload: source/destination IP,
source/destination port, protocol, packet/byte counts, and — the field that matters
most here — whether the flow was **ACCEPT**ed or **REJECT**ed, which directly
reflects the SG/NACL decision at the time.

**Before Defense 1's fix,** querying the log group for the scan window:

```sh
aws logs filter-log-events --log-group-name /cyberlab/day17/vpc-flow-logs \
  --filter-pattern "ACCEPT"
```

shows records like (fields abbreviated): `srcaddr=<your scanning IP> dstport=22
protocol=6 action=ACCEPT` and the same for `dstport=80` — matching exactly what
`nmap` independently reported as open, from a completely separate source of evidence
than the scan itself.

**After Defense 1's fix,** re-running the identical scan and querying again:

```sh
aws logs filter-log-events --log-group-name /cyberlab/day17/vpc-flow-logs \
  --filter-pattern "REJECT"
```

now shows a `REJECT` record for `dstport=22` from the same source IP — the SG's new
decision, made durably visible after the fact, without anyone needing to have watched
it happen live.

**What the Flow Log records do *not* tell you, in either case:**
- No payload or banner content — you cannot recover *what* was sent or received, only
  that a connection attempt happened and whether it was allowed. (Day 2's
  `tcpdump`/`tshark` is the tool for payload-level inspection, not Flow Logs.)
- No specific nmap scan *technique* — Flow Logs can't distinguish a SYN scan from a
  full TCP connect scan from a UDP scan; they record the connection attempt's outcome
  at the routing/filtering layer, not the packet-level protocol behavior that
  distinguishes those techniques.

This is exactly the right level of detail for "did someone probe me, and did my
defenses hold" — durable, queryable evidence of allow/deny outcomes — without the
storage cost or sensitivity of capturing full traffic content.

## Verify command reference

```sh
nmap -Pn -p 22,80 <PUBLIC_IP> | grep -c "open"
```
Expected before the fix: `2`. Expected after Defense 1: `1` (only `80/tcp`, unless
scanned from the specific IP scoped for SSH).

```sh
./teardown.sh
```
Expected final line: `TEARDOWN_OK - no cyberlab-day17-tagged VPC remains.`
