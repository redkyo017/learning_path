# The Top 1% Strategy for Network Engineering

`ping`, `traceroute`, `ss`, `dig`, `curl -v` and the AWS console's Reachability
Analyzer are not knowledge. They are pretty-printers over headers and state
machines.

Every packet on every network, from a Linux bridge to a Transit Gateway, is a stack
of headers followed by a payload. Every protocol that moves those packets is a header
format plus a small state machine: ARP has a neighbour table, TCP has eleven states,
BGP has a session FSM, conntrack has a tuple and a timer. A tool prints one view of
that machinery. If you memorized the view, you own a vocabulary that fails on the
first symptom you have not seen. If you can draw the header and walk the state
machine, you can predict what any tool will print, and you can predict what it will
print when something is broken.

This is the network form of the doctrine in `linux_ops_mastery`, where "the file is the
truth". Here, **the header is the truth**. You came into this course able to operate
VPCs, Transit Gateway, VPN and Route 53 Resolver, and unable to rebuild the model
underneath them. This course rebuilds that model, proves each piece in a capture, and
then names the AWS construct that hides it. AWS networking is TCP/IP behind an API. If
you own the protocols, you can reason about any AWS construct, including ones this
course never mentions.

## The header is the truth

The doctrine has one move, practised on every day of the course:

> **symptom → header or state machine → the capture or table line that proves it**

A claim about the network survives only if you can point at a `tcpdump` or `tshark`
line, a routing-table lookup, a neighbour entry or a conntrack entry that supports it.
"It's probably a security group" is not a diagnosis. It is a guess. The move forces the
guess into a protocol, the protocol into a specific field or state, and the field into
a command that confirms or kills the theory before you change anything.

Two worked examples follow. Both come up in real incidents, and both are decoded from
the header alone.

### Worked example 1: "Connection timed out" versus "Connection refused"

Your service calls an internal API and the client logs one of two errors. They look
close. They mean opposite things, and the TCP header tells you which one you have.

TCP opens a connection with a SYN. What comes back, or fails to come back, is the
whole diagnosis:

| What the client sees on the wire | Client error | What it proves |
|---|---|---|
| SYN goes out, SYN-ACK comes back | none, connection opens | The path works end to end and something is listening |
| SYN goes out, a packet with the **RST** flag comes back | `Connection refused` | A host answered. The packet reached the far end, and nothing listens on that port, or something rejected it on purpose |
| SYN goes out, nothing comes back, SYN is retransmitted at 1 s, 2 s, 4 s | `Connection timed out` | Silence. Something dropped the SYN, or the reply, and said nothing |

The RST case is the more useful result, even though it feels worse. A RST is a
message: the far end's TCP stack (or a device speaking for it) read your SYN, looked up
the 4-tuple, found no listener and answered. You now know the route out works, the
filter in the middle (if any) lets this port through, and the host is up. The fault is
in one place only: the process that should be listening on that port.

The timeout case proves much less. Silence has many causes: a route missing on the way
out, a route missing on the way back, a security group or NACL dropping the packet, a
firewall configured to drop instead of reject, an MTU black hole that eats large
packets, or a dead host. You narrow it with captures at each hop. You find the last
point where the SYN is visible and the first point where it is not.

You can prove the difference in 20 seconds on any Linux box. Run `tcpdump -ni any
'tcp[tcpflags] & (tcp-syn|tcp-rst) != 0'` in one shell and `curl -m 5 <ip>:<port>` in
another. A closed port shows `Flags [S]` then `Flags [R.]`. A dropped port shows
`Flags [S]` three times, with the gaps doubling. Day 3 builds both cases and labs the
difference.

### Worked example 2: "A security group is conntrack"

An AWS security group is stateful: you allow inbound TCP 443, and the replies leave
without any outbound rule. The documentation says this and moves on. The header
explains how.

A stateful filter does not remember packets. It remembers **flows**, keyed by the
5-tuple: protocol, source IP, source port, destination IP, destination port. When the
first SYN of a flow arrives, the filter checks its rules. If the rules allow it, the
filter creates an entry in a table (in Linux, the conntrack table) holding that tuple
and its state. Every later packet, in both directions, is matched against the table
before any rule runs. The reply has the tuple's source and destination swapped, and
the table knows to treat that swapped tuple as the same flow.

```
SYN     10.0.1.5:51514 -> 10.0.2.9:443    rule check: allow tcp/443      -> entry created (NEW)
SYN-ACK 10.0.2.9:443 -> 10.0.1.5:51514    table lookup: reply of an entry -> pass
ACK     10.0.1.5:51514 -> 10.0.2.9:443    table lookup: ESTABLISHED       -> pass
```

Two consequences fall out of that, and both are failure modes you meet at work:

- **The return path must come back through the same filter.** If the SYN-ACK arrives at
  a different firewall, that firewall has no entry for the tuple. It sees a packet
  claiming to belong to a flow it never saw, and it marks it INVALID. This is exactly
  why centralized inspection in AWS needs TGW appliance mode (Day 4).
- **Entries expire.** The table holds each flow for a timer. Idle past the timer and the
  entry goes. The next packet is not a new flow and it is not in the table, so it is
  dropped or reset. This is the idle-timeout signature of NLB and NAT Gateway (Day 3).

So when you read "a security group is conntrack", read it as a prediction: a
tracked flow with an entry in a bounded table, a timer, and a requirement that both
directions pass through the same box. A NACL is the contrasting case. It keeps no table,
so it must allow the return ephemeral port range explicitly, and you can predict that
failure before you hit it.

## The daily loop

Every day in this course runs the same five steps. The loop, not the topic list, is the
product. Internalize it and any network incident becomes tractable, including the ones
this curriculum never lists.

1. **Draw it first.** On a blank page, draw today's header or state machine from memory
   before you read anything. Then correct the drawing against the content.
   *Why:* retrieval before review is the fastest path back to decayed knowledge. You
   learned this material once. Pulling it out of memory, and finding exactly where it is
   wrong, rebuilds it faster than reading the page a second time. The errors you make
   are the map of what to study.

2. **Build it from nothing.** Create the interfaces, bridges, routes, NAT rules and
   peers by hand in network namespaces. Do not paste a topology you do not understand.
   *Why:* AWS networking is these primitives behind an API. A VPC router is a routing
   table, an ENI is a veth, and a security group is a conntrack policy. When you have
   built the primitive yourself, the managed version stops being magic and starts being
   a configuration of something you know.

3. **Prove it in a capture.** No claim counts until a `tcpdump` or `tshark` line, a
   routing-table lookup (`ip route get`) or a conntrack entry confirms it.
   *Why:* a tool's summary is an interpretation. A capture is the packet. When the two
   disagree, the capture wins, and the disagreement is where the learning is. This
   step is also what separates knowing a protocol from being able to recite it.

4. **Break, then diagnose from evidence.** Run `break.sh`. It injects a fault and
   prints a symptom with no explanation. Write the chain of evidence in `journal.md`
   *before* you fix anything.
   *Why:* a diagnosis you were handed is not a diagnosis you can repeat on someone
   else's incident at 2 a.m. Writing the chain first forces the model to do the work.
   A fix that happens to work before the chain is written teaches nothing about why it
   worked.

5. **Name the AWS construct.** End every concept as one sentence of the form "X in AWS
   is Y on the wire". Write it in `journal.md`. Examples: "a security group is
   conntrack", "a TGW route table is a VRF", "GWLB is GENEVE".
   *Why:* this is the step that turns protocol knowledge into work knowledge. Each day
   also emulates one AWS construct locally (a two-AZ inspection layout, TGW route tables as policy-routing tables,
   a GENEVE appliance path), so the sentence is something you have already built,
   not a claim from documentation.

**Where Exercises fit:** the exercises in each `content/dayNN.md` sit outside the loop.
They are theory drills (subnet math, header decoding, best-path puzzles, capture
reading), each with a hint and a solution sketch inline. Do them before the lab, after
it, or in the gaps between days. Nothing in the lab depends on them, though the
Day 7 gauntlet rewards anyone who did them.

## The eight mistakes

These are the mistakes that waste most of the time learners spend on networking. Each
one gets a callout on the day where it bites, in that day's "Anti-patterns / Common
mistakes" section.

1. **Memorizing the OSI model instead of the actual headers.** (Days 0-1)
   Seven layer names tell you nothing about a failure. The Ethernet, IP and TCP headers
   do: a MAC mismatch, a TTL of 1, a RST flag. *Habit:* when someone says "layer 2
   problem", ask which field in which header, and draw it. Day 1 starts every concept
   from the frame on the wire, not the layer diagram.

2. **Learning tool flags instead of the protocol underneath.** (Day 1)
   A flag set is a vocabulary that goes stale with the tool version and vanishes when the
   tool is missing from a minimal ECS task. *Habit:* before you run a command, say what
   packet or table it reads. If you cannot, you are reciting, so go back to step 1 of the
   loop.

3. **Treating AWS networking as magic separate from TCP/IP.** (Day 2)
   "The VPC router" and "the IGW" are real forwarding behaviour you can rebuild with
   `ip route` and a namespace. *Habit:* finish every AWS concept with the "X in AWS is Y
   on the wire" sentence. If you cannot write the Y, you have not learned the concept
   yet.

4. **Debugging without a capture.** (Day 3)
   Reading logs and console screens gives you what each layer says about itself. A
   capture shows what actually crossed the wire. *Habit:* when a path is in doubt, capture
   at both ends and compare. The first place the packet is missing is the fault domain.

5. **Confusing a timeout with a reset: they mean opposite things.** (Day 3)
   A RST is a reply from the far side. A timeout is silence. They send you to different
   places, as worked example 1 shows. *Habit:* read the error as a wire event first
   (a RST arrived, or nothing arrived), and only then as a message.

6. **Assuming a filter is stateless, or stateful, without checking.** (Day 4)
   A security group tracks flows. A NACL does not. An `iptables` rule that mentions only
   `ESTABLISHED` does. Getting this wrong gives you either a missing return-port rule or
   a flow dropped as INVALID. *Habit:* for each filter in the path, write down whether it
   keeps a table, and what the timer and the limit are.

7. **Assuming routing is symmetric.** (Day 4, Day 5)
   The forward path and the return path are chosen independently, by different tables
   and, in BGP, by different best-path decisions. A stateful device on only one of them
   sees half a flow. *Habit:* for every path, trace the return packet's route lookups
   separately. Never assume it mirrors the way out.

8. **Blaming DNS by reflex, or never testing it at all.** (Day 6)
   Both halves are expensive. Blaming DNS for every outage wastes hours. Never testing
   it leaves the real DNS failures (a wrong resolver, a stale cached answer, a
   split-horizon miss) undiagnosed. *Habit:* test it in 10 seconds with a direct
   `dig @<resolver> <name>` and compare answers across resolvers. Then rule it in or out
   with evidence.

## How this course fits

This course sits between two existing ones, and it does not repeat either.

| Course | What it teaches | What it leaves out | How this course connects |
|---|---|---|---|
| [`linux_ops_mastery`](../linux_ops_mastery/) (the box) | Reading one Linux host through its kernel files. Day 6 reads the network from one box: sockets, routes, firewall, DNS. | The protocols themselves: why a frame, a segment or a BGP UPDATE looks the way it does. | This course rebuilds the model under `linux_ops_mastery` Day 6, by capture. Day 3 here explains the socket states you read there. |
| [`aws_network_components`](../aws_network_components/) (the constructs) | The AWS constructs hands-on: VPC, TGW, VPN, PrivateLink, Resolver, with one growing topology. | The protocol layer beneath each construct. | Every day here ends with "X in AWS is Y on the wire" and points to the sibling day that labs the construct on AWS. |
| This course (the protocols) | Headers and state machines from L2 to BGP and overlays, proven in local namespaces. | TLS and certificates, ALB/NLB feature depth, WAF, Shield and CloudFront. | Links out: [`network_certificates_and_more`](../network_certificates_and_more/), [`aws_computing_loadbalancing_communication_components`](../aws_computing_loadbalancing_communication_components/), [`aws_security_components`](../aws_security_components/). |

Day 0 ("The map") comes first and draws the whole path from a laptop to a server: the home router box, the modem, the ISP, the Internet's structure and DHCP. Days 1-7 then zoom into one hop of that map each. It teaches the OSI and TCP/IP models the way mistake 1 asks: as a map from real headers to the devices that read them, never as trivia.

The weighting is about 70% protocol theory and proof, and about 30% AWS mapping and
work application. Every core lab is local Docker and costs nothing. The one optional AWS
lab (Day 4, TGW appliance mode) exists because that behaviour exists nowhere but AWS.

## Rejected approaches

Three other designs were considered and rejected. Knowing why helps you use this course
properly, because each rejected design is a strength you can borrow on your own.

**Follow one packet as the main spine.** This is the most work-shaped option: take a
request from an ECS task to an on-prem API and teach each hop in order. It loses
because hop order is not dependency order. A packet crosses DNS, the VPC router, a TGW
and a VPN in one pass, but you cannot understand the TGW hop without subnetting and
longest-prefix match, and you cannot understand the TCP behaviour across the VPN
without the TCP state machine. Teaching in hop order fragments each of those subjects
across several days. The approach is kept where it fits: Day 7 is a capstone that
follows one packet end to end, with no new theory.

**Incident-first, in the style of `linux_ops_mastery`.** Starting from a broken system
and working back to the model is strong reinforcement, and this course uses it in the
break step every day. It loses as the spine because of who this course is for. The
stated gap is forgotten concepts, not lack of incident practice. You can already fix
networks by habit. An incident-first path would hand you more habit and leave the
model underneath it unchanged. Concepts go first here, and incidents prove them.

**Extend one of the two existing courses.** Each already has a coherent spine:
`linux_ops_mastery` has four kernel truths, and `aws_network_components` has one growing
AWS topology. Adding protocol days to either one would break that spine, and would hide
the protocol content in a course whose title says something else. A separate course
that links to both keeps all three clean, and costs one line in each sibling's README.
