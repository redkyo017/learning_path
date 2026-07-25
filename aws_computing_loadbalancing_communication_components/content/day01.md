# Day 1 — EC2 Depth

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Identify the correct EC2 instance family for a given workload by mapping the
  bottleneck (CPU, memory, IOPS, GPU) to the right family
- Choose the appropriate EBS volume type based on measured IOPS and throughput
  requirements, and explain why gp3 is almost always preferable to gp2
- Explain why instance store data is non-persistent and name the events that
  wipe it
- Select the optimal purchasing option for a given workload pattern (steady-state,
  bursty, fault-tolerant, compliance-bound)
- Distinguish between cluster, spread, and partition placement groups and the
  failure scenario each addresses
- Describe what an ENI is and give two concrete reasons to attach a secondary ENI

---

## The four-dimension mental model

Before memorising any EC2 option, internalise the framework you will use every
time something breaks or a cost review arrives:

> **An EC2 instance is four independent dimensions: compute (instance family/type),
> storage (EBS vs instance store), network (ENI, placement group), and cost
> (purchasing option). When something is wrong or slow, identify which dimension
> is the problem.**

A performance complaint is never just "the instance is slow" — it is
CPU-bound (wrong family), IOPS-bound (wrong volume type), network-latency-bound
(wrong placement group), or cost-misaligned (wrong purchasing option).

---

## Instance families and when to choose them

Every instance type name encodes four pieces of information.

`c6i.xlarge` breaks down as:
- `c` — family (compute-optimised)
- `6` — generation (prefer the highest available; older generations are not
  cheaper in practice)
- `i` — processor variant (`i` = Intel, `a` = AMD, `g` = Graviton/ARM)
- `xlarge` — size (nano < micro < small < medium < large < xlarge < 2xlarge…)

| Family | Optimised for | Typical use cases | Example types |
|---|---|---|---|
| T (burstable) | Baseline CPU with burst credits | Dev/test, low-traffic web, small dbs | t3.micro, t4g.small |
| M (general purpose) | Balanced CPU/memory | Web servers, app servers, most workloads | m6i.large, m7g.xlarge |
| C (compute-optimised) | High CPU:memory ratio | Batch, video encoding, ML inference | c6i.2xlarge, c7g.4xlarge |
| R (memory-optimised) | High memory:CPU ratio | In-memory dbs, big-data analytics, caching | r6i.4xlarge, r7g.8xlarge |
| G / P (GPU) | GPU compute | ML training, graphics rendering, HPC | g5.xlarge, p4d.24xlarge |
| I (NVMe-optimised) | Extremely high local IOPS | High-IOPS databases, distributed filesystems | i3en.xlarge, i4i.2xlarge |
| D (dense HDD) | High storage density, low cost | Data warehousing, Hadoop, cold analytics | d3en.12xlarge |

**Rule of thumb:** Profile first. If CPU > 70% and memory < 30%, move to C. If
memory > 80% and CPU < 40%, move to R. Default to M until you have real data.

Graviton (`g` suffix: `c7g`, `m7g`, `r7g`) offers 20–40% better price/performance
than equivalent Intel instances. Use it unless your software requires x86 binary
compatibility.

---

## EBS volume types

EBS (Elastic Block Store) is network-attached block storage that persists
independently of the instance lifecycle and can be detached and reattached.

| Type | Use case | Max IOPS | Max throughput | Notes |
|---|---|---|---|---|
| gp3 | Default for most workloads | 16,000 | 1,000 MiB/s | 3,000 IOPS baseline free; IOPS and size are independent |
| io2 | Mission-critical databases (RDS, Oracle) | 256,000 | 4,000 MiB/s | 99.999% durability; multi-attach supported |
| io2 Block Express | Highest-performance databases | 256,000 | 4,000 MiB/s | Sub-millisecond latency; requires Nitro instances |
| st1 | Sequential reads, log streaming | 500 | 500 MiB/s | Throughput-optimised HDD; good for Kafka logs, EMR |
| sc1 | Infrequent access, cold data | 250 | 250 MiB/s | Cold HDD; lowest cost per GiB |

**The gp3 vs gp2 difference you must understand:**
gp2 tied IOPS to size at 3 IOPS/GiB — a 100 GiB gp2 could never exceed
300 IOPS. gp3 decouples them: every volume gets a free 3,000 IOPS baseline
regardless of size, provisionable up to 16,000 IOPS independently. A 20 GiB
gp3 can have 10,000 IOPS. A 20 GiB gp2 was capped at 60. Always prefer gp3.

---

## Instance store vs EBS

This is the most common cause of unexpected data loss in EC2.

| | Instance store | EBS |
|---|---|---|
| Attachment | Physically attached NVMe on the host | Network-attached; independent of host |
| Persistence | **Non-persistent** — lost on stop, hibernate, termination, or host failure | Persists independently of instance lifecycle |
| Performance | Extremely fast — no network hop | High, but subject to network latency |
| Cost | Free with the instance | Billed per GiB-month plus IOPS/throughput |
| Detach / reattach | Not possible | Yes — reattach to any instance in the same AZ |

**Instance store data is wiped by these events:**
- Instance stop (even a graceful `sudo halt`)
- Instance hibernate
- Instance termination
- Underlying host hardware failure

**Use instance store for:**
- Redis/Memcached scratch buffers (they reload from the primary store on restart)
- Spark/Hadoop shuffle space (ephemeral intermediate data between stages)
- Temporary build artefacts and anything you would put in `/tmp`

**Never use instance store for:**
- A database, regardless of how fast it is
- Any file whose loss would require manual recovery

**The classic trap:** engineers pick `i3en` for its NVMe IOPS and store a
database on instance store. A host replacement destroys all data. Always put
databases on EBS; use instance store only for data you can regenerate.

---

## Purchasing options

| Option | When to use | Discount vs on-demand | Commitment |
|---|---|---|---|
| On-demand | Default; unpredictable or short-term workloads | None | None |
| Reserved Instances (RI) | Steady-state, fixed instance type + region | 40–60% | 1 or 3 years |
| Savings Plans | Steady-state, flexible family / region / OS | 40–66% | 1 or 3 years |
| Spot | Fault-tolerant, interruptible: batch, ML training, stateless web | Up to 90% | None (2-min termination notice) |
| Dedicated Host | Compliance or per-socket licensing (Oracle, Windows Server) | Variable | On-demand or RI terms |

**Decision tree:**

```
Is the workload steady-state (running most of the time)?
├─ Yes → Does it need a fixed instance type and region?
│         ├─ Yes → Reserved Instance
│         └─ No  → Compute Savings Plan (flexible family/region)
└─ No  → Is it fault-tolerant and restartable?
          ├─ Yes → Spot (up to 90% savings)
          └─ No  → On-demand
```

**Spot interruption:** AWS sends a 2-minute termination notice. Well-designed
Spot workloads checkpoint state and restart cleanly. ASGs support mixed
On-demand + Spot with the `capacity-optimized` allocation strategy.

**Savings Plans vs RIs:** Compute Savings Plans cover any family, size,
region, and OS — use them for new workloads. RIs only make sense when you
know the exact instance type will not change for 1–3 years.

---

## Placement groups

Placement groups control how AWS physically places your instances on the
underlying hardware. Choose based on your failure-tolerance vs latency tradeoff.

**Cluster placement group**
All instances land on the same rack within the same AZ, giving the lowest
network latency and up to 10 Gbps between instances. Tradeoff: a single rack
failure takes down every instance simultaneously. Use for HPC, tightly coupled
distributed computing, and Hadoop where inter-node latency is the bottleneck.

**Spread placement group**
Each instance is placed on a different physical rack — no two instances share
a failure domain. Maximum 7 instances per AZ per group. Use for small critical
sets: a 3-node ZooKeeper ensemble, a primary/standby database pair, etc.

**Partition placement group**
Instances are divided into logical partitions, each mapped to a separate rack.
Up to 7 partitions per AZ with hundreds of instances total; each partition
fails independently. Use for HDFS, Cassandra, Kafka — large distributed
systems that need partial-failure tolerance beyond the 7-instance spread cap.

| Type | Max instances per AZ | Failure domain | Typical use case |
|---|---|---|---|
| Cluster | No hard limit | Shared rack | HPC, low-latency distributed compute |
| Spread | 7 | One rack per instance | Small critical sets (ZooKeeper, HA pairs) |
| Partition | 7 partitions, hundreds of instances | One rack per partition | HDFS, Kafka, Cassandra |

---

## Elastic Network Interfaces (ENI)

An ENI (Elastic Network Interface) is a virtual network card attached to an
EC2 instance. Every instance has at least one ENI (`eth0`, the primary).

Each ENI carries:
- One or more private IPv4 addresses
- Optionally one public IPv4 or Elastic IP
- Security group associations
- A MAC address

**Secondary ENIs — when you need them:**
- **Management interface:** put management traffic on a separate ENI in its own
  subnet with a tighter security group, isolating it from application traffic
- **Dual-homed instances:** connect one instance to two different subnets
  simultaneously (e.g. a firewall or proxy appliance)
- **License-bound software:** some software licences are tied to the MAC
  address. Move the ENI to a replacement instance and the software sees the
  same MAC — no re-licensing required.

**ENI constraints to know:**
- ENIs are AZ-scoped. You cannot move an ENI from `us-east-1a` to `us-east-1b`.
- The primary ENI cannot be detached from a running instance.
- The maximum number of ENIs per instance scales with instance size — larger
  instance types support more attached ENIs.

---

## Best practices

- Use gp3 by default; only upgrade to io2 when IOPS requirements exceed 16,000
  or you need 99.999% durability and multi-attach.
- Never use instance store for persistent data — it is wiped on stop or
  termination without warning.
- Prefer Compute Savings Plans over Reserved Instances — flexibility to change
  instance family or region is almost always worth the marginal cost difference.
- Use Graviton (`c7g`, `m7g`, `r7g`) for 20–40% better price/performance unless
  your software requires x86 binary compatibility.
- Tag every instance with `Purpose`, `Owner`, and `Environment` — without tags,
  cost attribution across teams is impossible.
- Enable IMDSv2 (token-based metadata) on every instance — IMDSv1 is vulnerable
  to SSRF attacks that can leak IAM credentials from `169.254.169.254`.

---

## Common pitfalls

- **Choosing instance type before profiling.** Selecting a large C instance
  without measuring CPU, memory, and IOPS wastes money when M or R fits better.
- **Using gp2 instead of gp3.** A 100 GiB gp2 delivers only 300 IOPS; a
  100 GiB gp3 delivers 3,000. There is almost no scenario where gp2 wins.
- **Instance store confusion on stop.** Stopping an instance migrates it to a
  different host and wipes all instance store data — it is not a reboot.
- **Over-reserving with 3-year RIs.** Workloads whose sizing will change in
  6 months should use Savings Plans or On-demand, not 3-year RIs.
- **Ignoring Graviton.** Teams default to x86 out of habit and leave 20–40%
  cost savings on the table on every long-running instance.
- **Cluster placement group for critical non-HPC instances.** A single rack
  failure kills all instances in the group. Use spread for critical low-count
  instances.

---

## Exercises

Answer before starting the lab:

1. You have a MySQL primary database that needs 5,000 IOPS on a 100 GiB volume.
   Which EBS type do you choose, and what is the minimum IOPS configuration
   needed on that volume?
2. Your data processing job runs for 4 hours every night, is stateless, and can
   restart from a checkpoint if interrupted. Which purchasing option minimises
   cost, and what is the approximate maximum discount over on-demand pricing?
3. A `c6i.2xlarge` instance (8 vCPU, 16 GiB RAM) runs consistently CPU-bound
   at 95% utilisation but uses only 2 GiB RAM. What instance family and
   processor variant would you migrate to for better price/performance, and why
   would you stay in the same generation?
4. You need three EC2 instances that must never share a physical rack. Which
   placement group type do you choose, and what is the maximum number of
   instances per AZ that this group type supports?

## Lab reference

Follow Day 1 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 1 — EC2 Depth
Key concept in my own words: ...
When would I NOT use instance store: ...
Break-it exercise — what I misconfigured and how I found it: ...
```
