# Day 2 — Load Balancers

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- State which OSI layer ALB, NLB, and GWLB operate at and what that means for
  routing capability
- Design ALB listener rules using path-based, host-based, and header-based routing
- Explain why NLB preserves the client source IP while ALB does not
- Configure a target group health check and explain what happens when all
  targets are unhealthy
- Explain the trade-offs of enabling cross-zone load balancing on NLB
- Choose ALB vs NLB vs GWLB for a given requirement and articulate the reason

---

## The OSI layer mental model

Before memorising any load balancer feature, internalise the question that
drives every choice:

> **Every AWS load balancer routes packets at a specific OSI layer. The layer
> determines what information the balancer can read, what routing decisions it
> can make, and what it costs. Choose the layer first, then pick the product.**

| Load balancer | OSI layer | Protocol | What it can read |
|---|---|---|---|
| ALB | L7 — Application | HTTP / HTTPS / gRPC | URL path, host header, query string, HTTP method, cookie |
| NLB | L4 — Transport | TCP / UDP / TLS | Source IP, source port, destination IP, destination port |
| GWLB | L3 — Network | All IP traffic | Raw IP packets — used for inline security appliances |

ALB can route `/api/*` to backend-A and `/web/*` to backend-B because it reads
the URL. NLB cannot — it only sees the TCP connection. This is not a
limitation; it is a design choice. NLB is faster precisely because it does
less.

---

## Application Load Balancer (ALB)

ALB operates at **L7** and reads the full HTTP request before making a routing
decision. This is the right default for any HTTP or HTTPS workload.

A **listener** is a port-and-protocol pair (e.g. HTTP:80 or HTTPS:443). Each
listener holds an ordered list of **rules** evaluated top to bottom by
priority, where 1 is the highest priority. Each rule has a condition and an
action.

Rule conditions ALB can evaluate:
- `path-pattern` — e.g. `/api/*`
- `host-header` — e.g. `api.example.com`
- `http-header` — any arbitrary header name and value
- `http-request-method` — GET, POST, etc.
- `query-string` — key/value pairs in the URL
- `source-ip` — CIDR range of the client

Rule actions:
- `forward` — send to a named target group
- `redirect` — return an HTTP redirect (e.g. HTTP → HTTPS upgrade)
- `fixed-response` — return a static status code and body (useful for
  returning a 404 or maintenance page)
- `authenticate-cognito` / `authenticate-oidc` — enforce identity provider
  login before forwarding

Every listener must have a **default rule** at the bottom (priority "last").
It catches all requests that no other rule matched. Forgetting to configure it
means unmatched traffic gets an implicit 503.

**SSL termination:** ALB decrypts HTTPS at the load balancer and forwards
plain HTTP to the targets. This offloads TLS processing from your EC2
instances and centralises certificate management in ACM.

**Sticky sessions** bind a client to the same target for a session duration
using a cookie. Use this only when the application genuinely requires it —
sticky sessions concentrate traffic on individual targets and undermine the
even distribution that makes load balancing valuable.

**ALB IPs are not static.** ALB resolves to multiple IPs that change without
notice. If a downstream system needs to allowlist by IP, ALB is the wrong
choice.

---

## Network Load Balancer (NLB)

NLB operates at **L4** and makes its routing decision based solely on the TCP
or UDP header — it never reads the HTTP body or URL. The result is
single-digit millisecond latency, roughly 5–30ms faster per request than ALB
for HTTP workloads.

**Static Elastic IP per AZ:** each AZ node of an NLB gets a fixed Elastic IP
that you can pre-announce to firewalls and DNS. This is the primary reason to
choose NLB over ALB for non-HTTP protocols.

**Source IP preservation:** NLB does not perform source NAT. The EC2 instance
sees the real client IP directly in the packet header. ALB, by contrast,
replaces the source IP with its own address and places the original client IP
in the `X-Forwarded-For` HTTP header. Applications behind ALB must read that
header to log the real client address.

**TLS passthrough:** an NLB TLS listener can forward the encrypted stream to
the target without decrypting it. The target handles TLS termination
end-to-end. This is required when compliance rules prohibit a shared
termination point or when mutual TLS (mTLS) must reach the application.

**Cross-zone load balancing is disabled by default on NLB.** Each AZ node
only routes to targets registered in its own AZ. See the cross-zone section
below for the cost and behaviour implications.

When not to use NLB: HTTP path-based routing, WAF attachment, HTTP header
inspection, targets that are Lambda functions.

---

## Gateway Load Balancer (GWLB)

GWLB operates at **L3** and routes raw IP packets — it never reads TCP or HTTP
headers. Its purpose is not to balance application traffic but to insert
a fleet of network security appliances (firewalls, IDS, DLP tools) transparently
in the traffic path.

GWLB uses the **GENEVE protocol on port 6081** to encapsulate the original
packet and forward it to a registered security appliance. The appliance
inspects the original packet unchanged, then returns it to GWLB, which either
forwards it onward or drops it.

The traffic path with GWLB:
1. A route table entry directs traffic to a **GWLB endpoint** (a VPC endpoint
   inserted in the routing path).
2. The endpoint forwards packets to GWLB.
3. GWLB distributes packets across a pool of appliance instances via GENEVE.
4. Each appliance inspects the packet and signals allow or drop.
5. Allowed packets return to GWLB and are forwarded to their destination.

This is **not a common application developer need**. It is platform and
security team territory. Choose GWLB when a Palo Alto, Check Point, or
AWS Network Firewall appliance must inspect all traffic in a centralised hub
VPC.

---

## Target groups

A **target group** is a named pool of destinations that a load balancer
forwards traffic to. Each target group has a type:

| Type | Targets | Required for |
|---|---|---|
| `instance` | EC2 instance IDs | Classic EC2 backends |
| `ip` | IP addresses | Fargate tasks, on-prem via Direct Connect, PrivateLink |
| `lambda` | Lambda function ARN | Serverless HTTP handlers (ALB only) |
| `alb` | Another ALB | NLB fronting an ALB for fixed-IP + HTTP routing |

**Health checks** are probes the load balancer sends to each target on a
configurable path and interval. You define the interval (default 30s),
timeout, healthy threshold (consecutive passes before marking healthy), and
unhealthy threshold (consecutive failures before marking unhealthy). For
HTTP/HTTPS probes you also define the expected success codes (e.g. `200-299`).

**What happens when all targets are unhealthy:** ALB returns HTTP 503 to the
client — it does not forward the request. NLB passes the connection through
and lets the target reset it, which the client sees as a connection refused.
In both cases, fix the health check definition first — a misconfigured
success-code range is the most common cause of spurious 503s.

**Deregistration delay** (also called connection draining) is the window
ALB waits after a target is deregistered before forcibly closing its
in-flight connections. The default is 300 seconds. Set this to at least
the maximum expected request duration for your application. Too short and
you will see 502 errors during rolling deployments as requests are cut off
mid-flight.

**Slow start mode** ramps a newly registered target's traffic share up
gradually over a period you configure. This prevents a cold EC2 instance from
receiving full production traffic before its JVM or connection pool has warmed.

---

## Cross-zone load balancing

| | ALB | NLB |
|---|---|---|
| Default | Enabled (no extra cost) | Disabled |
| Cost when cross-AZ traffic occurs | Free | $0.01 per GB |
| Behaviour when disabled | N/A | Routes only to targets in the same AZ |

When cross-zone load balancing is **disabled on NLB**, each AZ node only
distributes traffic among the targets registered in its own AZ. DNS routes
roughly 50% of connections to each AZ node regardless of how many targets
that AZ contains. If AZ-a has 2 targets and AZ-b has 8 targets, each target
in AZ-a absorbs 4× the traffic of each target in AZ-b.

Enabling cross-zone LB on NLB solves the distribution problem but adds
cross-AZ data transfer charges. The right answer: keep equal target counts
per AZ and leave cross-zone disabled — you get even distribution for free.

---

## Best practices

1. Default to ALB for any HTTP/HTTPS workload — it gives the richest routing
   options and integrates with ACM, WAF, and Cognito.
2. Use NLB when you need a stable IP per AZ (firewall allowlisting) or when
   the protocol is not HTTP (MySQL, Redis, MQTT, raw TCP).
3. Never enable sticky sessions on a stateless service — it concentrates load
   on individual targets and breaks the guarantee you bought from the load
   balancer.
4. Always enable ALB access logs to S3 — they are the fastest way to diagnose
   unexpected 5xx responses and measure per-target latency.
5. Set deregistration delay to at least the maximum expected request duration
   (30–120 seconds for most REST APIs, longer for file uploads or
   long-polling).
6. Use path-based routing rules on a single ALB rather than deploying a
   separate ALB per service — one ALB is cheaper and simpler to maintain.

---

## Common pitfalls

- **Using ALB when a stable IP is required.** ALB IPs rotate without warning.
  Any downstream firewall rule that allowlists by IP will break silently. Use
  NLB, then optionally put the ALB behind the NLB as an `alb` target type.
- **Reading source IP directly from the socket behind ALB.** ALB performs
  source NAT; the socket peer address is the ALB's private IP. Read the real
  client address from the `X-Forwarded-For` HTTP header — always validate
  that your application is configured to do this before going live.
- **Deregistration delay set to 0.** An aggressive ASG scale-in combined with
  a zero-second drain window drops in-flight requests immediately, causing
  502 errors during every deployment.
- **Misconfigured health check success codes.** If your application returns
  `200` but the target group expects `200-302`, the target is marked unhealthy
  and ALB returns 503. Check the health check configuration before assuming the
  application is broken.
- **Cross-zone NLB with unequal target counts per AZ.** Targets in the
  smaller AZ receive disproportionate traffic and saturate first. Keep target
  counts equal or enable cross-zone and accept the data transfer cost.
- **Expecting ALB to handle non-HTTP protocols.** ALB cannot route TCP or UDP
  traffic. If a single endpoint must serve both WebSocket (HTTP Upgrade) and
  raw TCP on the same port, NLB is the right choice.

---

## Exercises

Answer before starting the lab:

1. You need to expose a WebSocket API to the internet. The WebSocket endpoint
   must have a stable IP address for firewall allowlisting. Which load balancer
   do you choose, and why?
2. An ALB listener has three rules: priority 1 routes `/api/*` to
   target-group-A, priority 2 routes `/admin/*` to target-group-B, and the
   default rule returns 404. A request arrives for `/api/admin/users`. Which
   rule matches, and why?
3. Your EC2 instances receive traffic from an ALB. The application logs show
   every request originates from the same private IP — the ALB's own address.
   What HTTP header should the application read to log the real client IP?
4. All targets in a target group are healthy except one. That one is receiving
   requests and returning 500. How quickly will ALB stop sending it traffic?
   What two configuration values control this?

## Lab reference

Follow Day 2 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 2 — Load Balancers
Key concept — OSI layer decision: ...
When would I NOT use ALB (choose NLB instead): ...
Break-it — what the 503 taught me about health checks: ...
```
