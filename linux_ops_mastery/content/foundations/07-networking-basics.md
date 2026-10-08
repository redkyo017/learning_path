# Foundations 07 — Networking basics

**Prepares you for:** Day 6.
**Time:** about 45 minutes with the try-it steps.

Day 6 asks why one container cannot reach another although both are
"up". The cause is always one of: the name did not resolve, there is no
route, something blocks the packets, nothing is listening, or it listens
in the wrong place. This chapter builds the vocabulary for that list.

## What you'll be able to explain

- A network interface is a doorway between a machine and a network,
  carrying an address and a prefix. The routing table says, for each
  destination, which doorway and which next hop to use. The longest
  matching prefix wins. *Where the analogy breaks:* a virtual interface
  like `lo` is a door that leads back into the same machine.
- A port picks one socket on a host. A TCP connection is named by
  source address, source port, destination address, destination port
  and protocol. A socket is a file descriptor, like chapter 04's.
- A TCP server runs socket, bind, listen, accept; a client runs connect.
  The three-way handshake sets up the connection. UDP has no connection.
- `127.0.0.1` is reachable only inside one network namespace; `0.0.0.0`
  means every address of that namespace. That difference is Day 6's
  classic fault.
- A name becomes an address by the order in `nsswitch.conf`, then
  `/etc/hosts`, then the DNS servers in `/etc/resolv.conf`. In Docker
  that server is `127.0.0.11`.

## The mental model

### Interfaces, addresses and prefixes

A **network interface** is the kernel's handle for one attachment to a
network: a wired card, a Wi-Fi radio, or a virtual link. Each has a name
(`eth0`, `lo`) and holds one or more **IP addresses**. An IPv4 address
is four numbers, such as `172.18.0.3`, identifying the interface.

An address always comes with a **CIDR prefix**: a slash and a number,
as in `172.18.0.3/16`. The number says how many of the address's 32
bits name the *network*; the remaining bits name the *host* inside it.
`/16` means the first 16 bits (`172.18`) are the network, so every
`172.18.` address is "on the same wire", reachable directly. `/24` is smaller (256 addresses); `/32` is one address.

The **loopback** interface, `lo`, goes nowhere: whatever is sent to it
comes straight back into the same machine. Its address is `127.0.0.1` (also called `localhost`). It lets programs on one host talk over the network machinery.

```
  one machine (one network namespace)
  +--------------------------------------------------+
  |  lo    127.0.0.1/8        <- talks to itself     |
  |  eth0  172.18.0.3/16      <- door to the network |
  +--------------------------------------------------+
```

### Routes: where does this packet go?

When a program sends to an address, the kernel decides which interface
to use, and to whom, from the **routing table**: rules of the form "for
destinations in this range, send via that interface, optionally through
that next-hop machine".

```
  destination        via              dev
  172.18.0.0/16      (direct)         eth0     <- same network
  default            172.18.0.1       eth0     <- everything else
```

The first line is a **connected** route: `eth0`'s own prefix, "these
machines are on my wire, send directly". The second is the **default
route**, written `default` or `0.0.0.0/0` (zero bits match everything).
It names the **default gateway**, a machine on the same network (here
`172.18.0.1`) that forwards packets towards the rest of the world. If
nothing matches, the send fails with "network is unreachable".

Several rules can match one destination. The kernel picks the one with
the **longest matching prefix**, the most specific. A `/32` route to one
address beats a `/16` that also covers it, and both beat the default
route, no matter the order they were added. Only a tie is broken by
a metric (lower wins). Day 6 shows `ip route get <ip>`, which asks the
kernel which route it would use.

### Ports and the connection tuple

An address finds a machine; many programs on it want to talk at once.
A **port** is a number from 1 to 65535 that picks one conversation
endpoint on that machine, so `172.18.0.3:8080` means "port 8080 on that
address". By convention, a web server uses 80, HTTPS 443, PostgreSQL
5432. Ports below 1024 are privileged: binding one needs root or the
capability chapter 05 mentioned (Docker relaxes this inside containers
via `net.ipv4.ip_unprivileged_port_start=0`).

A **protocol** says how the bytes are carried: **TCP**, a reliable
ordered stream with a connection, or **UDP**, loose single messages with
no connection or delivery guarantee (DNS mostly uses it).

A running TCP connection is identified by five values, its
**four-tuple plus protocol**:

```
  (source IP, source port, destination IP, destination port, TCP)
```

Many clients can connect to one server port, since their source
addresses or ports differ and each tuple is unique. The kernel assigns
the client a random free **ephemeral port** from a high range; that pool
is finite, which Day 6 revisits.

### A socket is a file descriptor

A **socket** is the kernel object a program uses as one end of a
network conversation. To the program it is just a number in its
file-descriptor table, exactly the fd of chapter 04: you `read` and
`write` it, you `close` it, a child inherits it across `fork`. This is
chapter 00's "everything is a file" idea, though a socket has no bytes
on disk; it is a live kernel object. A socket shows up in
`/proc/PID/fd` as a link of the form `socket:[inode]`, and `lsof` lists
it like any open file.

```
  process fd table            kernel
  0, 1, 2 -> terminal
  3 -> socket:[884213] -----> socket object
                               local  0.0.0.0:8080
                               state  LISTEN
```

### The server and the client sides

A TCP server builds its socket in four system calls (chapter 00):

1. `socket`: create the endpoint; the program gets an fd.
2. `bind`: attach it to a local address and port. The address chosen is
   the **bind address**, next section.
3. `listen`: mark it a **listening socket** ("ready for callers"); the
   kernel accepts connection attempts on its behalf.
4. `accept`: take the next completed connection. This returns a *new*
   fd for that conversation; the listening socket keeps taking callers.

A client does `socket` then `connect`, naming the server's address and
port. The kernel picks the ephemeral source port.

Setting up a TCP connection takes the **three-way handshake**:

```
  client                                server
    |  ---- SYN  (let's talk, my number) -->  |  LISTEN
    |  <--- SYN-ACK (ok, and mine) ---------  |
    |  ---- ACK  (got it) ----------------->  |
    |        connection ESTABLISHED           |
```

The kernel does this itself, before the server's `accept` returns.

TCP sockets move through **states**, in plain words:

- **LISTEN**: a server socket waiting for callers.
- **ESTABLISHED**: handshake finished, data may flow.
- **TIME_WAIT**: the side that closed first lingers briefly (about a
  minute) so late stray packets of the old connection cannot be mixed
  into a new one using the same tuple. A busy client can pile up many
  and run out of ephemeral ports; Day 6 goes further on this.

Day 6 also names `SYN_SENT`, the client state after sending the first
packet. A socket stuck there means nothing answered, or a
**firewall** (kernel rules deciding which packets pass) silently dropped
it. If the server's kernel answers "refused" at once, nothing listens
at that address and port.

UDP skips all of this: a program `bind`s a port, then sends and receives
single messages. No handshake, no state, no `LISTEN`.

### Bind address: 127.0.0.1 versus 0.0.0.0

When a server binds, it picks which local address it answers on:

- `127.0.0.1` (loopback): connections only from inside the **same
  network namespace**. The loopback is private to that namespace.
- `0.0.0.0` ("any address"): connections arriving on *any* interface
  of the namespace, `lo` included.

```
  ws --connect 172.18.0.3:8080--> app bound to 127.0.0.1:8080
                                  lo   127.0.0.1    [listener here]
                                  eth0 172.18.0.3   (nothing) -> refused

  ws --connect 172.18.0.3:8080--> app bound to 0.0.0.0:8080
                                  lo   127.0.0.1    [listener here]
                                  eth0 172.18.0.3   [listener here] -> ok
```

A service on `127.0.0.1` is **unreachable from another container**:
each has its own network namespace (chapter 06) and so its own loopback. From another namespace a loopback-only bind gives an immediate
"connection refused", not a hang. Day 6 proves the bind in
`/proc/net/tcp`, where `0.0.0.0` is `00000000` and `127.0.0.1` is
`0100007F`.

### From name to address: DNS

People use names; packets need addresses. The C library asks the
**resolver**, the code (and the servers behind it) that turns a name
like `app` into an address. The path has three stops:

```
  program asks for "app"
        |
        v
  /etc/nsswitch.conf   line "hosts: files dns" gives the ORDER
        |
        +--1. files --> /etc/hosts        (static name -> address list)
        |
        +--2. dns   --> servers listed in /etc/resolv.conf
                          nameserver 127.0.0.11
```

`/etc/nsswitch.conf` says which sources to ask, in order; `hosts: files
dns` means the hosts file first, then DNS. `/etc/hosts` is a plain list
of "address name" pairs. `/etc/resolv.conf` lists the **DNS** (Domain
Name System) servers to query, DNS being the global distributed
database of name-to-address answers.

Inside a Docker container the DNS server in `resolv.conf` is
`127.0.0.11`, Docker's **embedded DNS server**, answered by the Docker
engine on the container's own loopback. It resolves other containers'
service names (`app`, `db`, `proxy`) to addresses on the shared network
and passes other names outside, so the fleet containers reach each other
by name. `getent hosts app` follows exactly this path. Day 6 goes further: `search` suffixes and `ndots`
decide how many lookups a short name costs.

### The whole path, ws to app

Put it together for `curl http://app:8080/` typed in `ws`:

```
  ws (own network namespace)
  1. name   "app" --nsswitch--> /etc/hosts miss
                  --> DNS 127.0.0.11 --> 172.18.0.3
  2. route  172.18.0.3 matches the connected route 172.18.0.0/16
                  --> out through eth0
  3. iface  eth0 sends the SYN (handshake begins)
                      |
                      v   shared virtual network
  app (own network namespace)
  4. eth0 receives; kernel finds listening socket 0.0.0.0:8080
     (a 127.0.0.1 bind would NOT match here)
  5. handshake finishes; accept returns; app reads the request
```

### Words Day 6 adds on top

- **Packet**: one chunk of data on the network, with source and
  destination addresses on its front.
- **RST versus no reply**: a refused connection gets an immediate **RST**
  (reset) back, so the failure is instant. A dropped one gets silence and
  the client waits until timeout.
- **ICMP**: the network's error-message protocol ("destination
  unreachable", "packet too big"); `ping` uses it.
- **MTU**: the largest packet one link carries (often 1500 bytes). If a
  path's MTU is smaller and the ICMP "too big" message is filtered, large
  packets silently vanish while small ones work.
- **TLS handshake, certificate, SNI**: TLS encrypts HTTPS. In its
  handshake the server presents a **certificate** that must match the
  name the client asked for; **SNI** is that name, sent in the handshake.
- **Firewall rules**: nftables and iptables hold **tables** of
  **chains** of **rules**; the first matching rule wins, else the
  chain's **policy** (accept or drop) applies.
- **tcpdump**: prints the packets crossing an interface, live.

Day 6 goes further on each.

## How it connects

Chapter 06's **network namespace** is the unit all of this lives in:
each one has its own interfaces, its own loopback, its own routing
table, its own sockets and its own firewall rules. Two containers in
two namespaces share none of these unless a virtual link joins them,
which is what Docker's network does with `eth0`. Chapter 00's "everything
is a file" and chapter 04's fd table explain why a socket appears in
`/proc/PID/fd`; `/proc/net/tcp` is the kernel's table of them, generated
on read like any `/proc` file. `ss` asks the kernel through netlink instead, so
the two views can be compared.

## See it yourself

Run these inside `ws`; all read-only.

```bash
ip -br addr
```

**What to look for:** `lo` with `127.0.0.1/8`, `eth0` with a private
address and a prefix such as `/16` (ignore unused `DOWN` devices like
`tunl0`). State is `UP` (loopback may show `UNKNOWN`: normal).

```bash
ip route
```

**What to look for:** a `default via ...` line naming the gateway, and a
connected line for `eth0`'s own prefix. Match `eth0`'s address against
that prefix and see why it is "direct".

```bash
cat /etc/resolv.conf
getent hosts app
```

**What to look for:** `nameserver 127.0.0.11` (Docker's embedded DNS)
plus an `options` line (`search` on some setups). `getent` prints the
address `app` resolves to, via the same path.

```bash
ss -tlnp
```

**What to look for:** `-t` TCP, `-l` listening only, `-n` numbers not
names, `-p` owning process. Each row is a `LISTEN` socket; the "Local
Address:Port" column shows its bind address, `0.0.0.0` or `127.0.0.1`
or `*` for any. Expect one row on `127.0.0.11:<random port>` with no
process name: Docker's embedded DNS, held by the engine from outside and
bound to loopback. `ws` runs no servers of its own.

```bash
ss -tn
cat /proc/net/tcp | head -3
```

**What to look for:** `ss -tn` lists non-listening TCP sockets such as
`ESTABLISHED` ones; it may be empty on an idle `ws`. `/proc/net/tcp` is
the same table as raw text: addresses are hex in the machine's byte
order (`0100007F` is `127.0.0.1`); ports are plain hex (`0050` is 80).
Just see the header line and a state code such as `0A` for `LISTEN`.

```bash
curl -si http://proxy/ | head -5
```

**What to look for:** an HTTP status line from the `proxy` service,
which listens on port 80 (so no port in the URL), followed by headers
such as `Server: nginx`. A `502` status means the proxy answered but its
own onward trip to `app` failed; no answer at all would mean a failure
before the proxy. `-i` shows headers; a plain GET changes nothing.

## Words you'll meet in the course

- **longest matching prefix** — Day 6, *The routing table as a decision procedure* ([glossary](../GLOSSARY.md))
- **`nsswitch.conf`** — Day 6, *DNS resolution order, and the `ndots` trap* ([glossary](../GLOSSARY.md))
- **`ndots`** — Day 6, *DNS resolution order, and the `ndots` trap* ([glossary](../GLOSSARY.md))
- **`/etc/resolv.conf`** — Day 6, *DNS resolution order, and the `ndots` trap* ([glossary](../GLOSSARY.md))
- **`0.0.0.0`** — Day 6, *Listening on `127.0.0.1` versus `0.0.0.0`* ([glossary](../GLOSSARY.md))
- **`/proc/net/tcp`** — Day 6, *Listening on `127.0.0.1` versus `0.0.0.0`* ([glossary](../GLOSSARY.md))
- **three-way handshake** — Day 6, *TCP states, the handshake, and port exhaustion* ([glossary](../GLOSSARY.md))
- **`SYN_SENT`** — Day 6, *TCP states, the handshake, and port exhaustion* ([glossary](../GLOSSARY.md))
- **`TIME_WAIT`** — Day 6, *TCP states, the handshake, and port exhaustion* ([glossary](../GLOSSARY.md))

## Self-check

1. A host has `eth0` at `10.0.5.9/24` and routes `10.0.0.0/16 via
   10.0.5.1` and `default via 10.0.5.254`. Where does a packet for
   `10.0.5.77` go, one for `10.0.9.4`, and one for `8.8.8.8`? Why?
2. Two browsers on one laptop both connect to the same server's port 443.
   Why do their connections not collide?
3. Describe the system calls a TCP server makes before it can serve a
   caller, and which of them the three-way handshake happens behind.
   Why does `accept` return a new fd?
4. In `app` a service is healthy and listens on `127.0.0.1:8080`. From
   `ws`, `curl` to `app:8080` fails with "connection refused", though the
   name resolves. Why, and what single change fixes it? How does that
   differ from a firewall drop?
5. In a container, `getent hosts db` works but the name `db` appears in
   no file. Which components answered, in what order, and at what
   address?

<details><summary>Answers</summary>

1. `10.0.5.77` is inside `eth0`'s own `/24`, so it goes direct out
   `eth0`. `10.0.9.4` matches `10.0.0.0/16`, so it goes via `10.0.5.1`.
   `8.8.8.8` matches only the default route, so via `10.0.5.254`. In each
   case the longest matching prefix wins, and default matches everything
   but loses to anything more specific.
2. A connection is the tuple of source IP, source port, destination IP,
   destination port and protocol. The destination parts are equal, but
   each connection gets its own ephemeral source port, so tuples differ.
3. `socket`, `bind`, `listen`, then `accept`. The handshake happens
   behind `listen`: the kernel completes it for callers itself, before
   `accept` returns; `accept` just hands over a finished connection. It
   returns a new fd for that conversation so the listening socket stays
   free to take more callers.
4. `127.0.0.1` is in `app`'s own network namespace, and `ws` arrives on
   `app`'s `eth0`, where nothing listens on that address, so the kernel
   refuses at once. Binding `0.0.0.0` fixes it. A firewall DROP instead
   makes the connect hang until timeout (client stuck in `SYN_SENT`).
5. `nsswitch.conf` says `files` first, `/etc/hosts` misses, then DNS:
   the server in `resolv.conf`, which is Docker's embedded DNS at
   `127.0.0.11`. It knows the service name `db` and answers with its
   address on the shared network.

</details>
