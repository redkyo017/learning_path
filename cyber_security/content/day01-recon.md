# Day 1 — Attacker Mindset, Threat Modeling, Recon

## Objectives

By the end of today you should be able to:

- Explain the CIA triad from the attacker's side — what each property looks like the
  moment it *fails*, not just its textbook definition.
- Place reconnaissance in the kill chain and explain why every later attack in this path
  starts here.
- Distinguish **passive** recon (no interaction with the target) from **active** recon
  (direct interaction, which can be logged or detected) and classify a given action as
  one or the other.
- Perform banner grabbing, tech fingerprinting, DNS lookups, and an initial port sweep
  against a real target, and read the results as a map of its attack surface.
- Reduce a target's attack surface by removing version banners, closing unneeded ports,
  and minimizing leaky headers — and re-verify the reduction with the same tools.

## 1. Concept — The CIA Triad Through an Attacker's Eyes, and Why Recon Comes First

### CIA, restated as "what breaks first"

`GLOSSARY.md` already defines the CIA triad as Confidentiality, Integrity, and
Availability — the three properties security protects. Today, invert that framing.
Instead of asking "how do I protect confidentiality," an attacker asks:

- **Confidentiality breaks** when I can read something I shouldn't — a version banner
  in an HTTP header, a comment left in HTML source, an open port that shouldn't be
  reachable, a DNS record that shows the entire internal naming scheme. Recon is
  *entirely* about causing confidentiality to break, on purpose, in small, cumulative
  ways.
- **Integrity breaks** when I can change something I shouldn't — that's next week's
  problem (injection, tampering). Recon doesn't change anything; it only observes.
- **Availability breaks** when I can degrade or block the system — also a later
  concern (denial of service). A noisy recon pass (an aggressive scan) can accidentally
  cause this, which is one reason attackers who care about staying undetected scan
  carefully.

The reframe that matters for today: **every piece of information a system leaks is a
small confidentiality failure, and attackers accumulate those small failures into a
plan.** No single banner or open port is "the vulnerability" — the *picture* they add up
to is what an attacker actually uses.

### Recon is step one of the kill chain, for a reason

The (Lockheed Martin) **cyber kill chain** describes an intrusion as a sequence of
stages: **Reconnaissance → Weaponization → Delivery → Exploitation → Installation →
Command & Control → Actions on Objectives**. You'll meet later stages as this path
progresses (injection and exploitation from Day 8 onward, persistence and detection from
Day 11 onward). Today is entirely about the first stage, and it's worth understanding
*why* it's first rather than skipped:

- You cannot choose the right exploit for a service you haven't identified.
- You cannot know which credentials to try (Day 4) without knowing which login
  mechanism exists.
- You cannot pick the right injection payload (Day 8) without knowing the tech stack.

Every later day in this path assumes the target has already been recon'd, even when
the content file doesn't say so explicitly — this is the step that makes every
subsequent attack *targeted* instead of a blind guess.

### Passive vs. active: the line is "did I touch it?"

Recon splits into two modes, and the distinction is one you'll be asked to apply
constantly, not just today:

| | Passive recon | Active recon |
|---|---|---|
| **Definition** | Gathering information *without* sending traffic to (or otherwise directly interacting with) the target | Gathering information by directly interacting with the target |
| **Detectability** | Invisible to the target — nothing in its logs shows you did anything | Potentially visible — the target (or a monitoring system in front of it) can see the interaction and, if watching, detect it |
| **Examples** | WHOIS lookups, public DNS records via a third-party resolver, search-engine ("Google dorking") results, Shodan/Censys searches, reading a company's public job postings for their tech stack | Port scanning, banner grabbing, sending an HTTP request, `whatweb`/`gobuster` against the live target, any direct DNS query *to the target's own resolver* |

Notice the DNS example splits the two: looking up a domain's public WHOIS/registrar
record is passive; querying the *target's own* DNS server directly is active, because
now you've sent it a packet it can log. The line is always "did traffic cross to the
target," not "is this a fancy tool or a simple one."

Real engagements plan around this: passive recon first (free, invisible, and it tells
you what's even worth actively probing), then active recon deliberately, knowing it may
be seen. Today's attack lab is entirely active recon, against a target built to be
recon'd safely.

### Information disclosure *is* attack surface

`GLOSSARY.md` defines **attack surface** as every point where an attacker could try to
interact with a system. Today adds the piece that connects it to Day 0's STRIDE:
**information disclosure doesn't just leak secrets — it directly enlarges the attack
surface**, because every version string, every open port, and every stack-technology
hint tells an attacker *which* attacks are even worth trying next. A banner that says
"nginx/1.21.6" isn't itself a vulnerability, but it turns "try things against this
server" into "look up nginx 1.21.6 CVEs" — a targeted search instead of a blind one.
That's why attack-surface *reduction* (today's defense lab) is mostly about suppressing
disclosure, not about closing some exotic hole.

## 2. Attack Lab — Recon the `target` Container

**Authorized use only:** the attacker toolbox in `labs/base` is offensive tooling
(`nmap`, `whatweb`, and friends). Only ever point it at containers this path starts on
the `cyberlab` network — including today's `target` — or your own AWS sandbox in later
phases. Never target a system you don't own or don't have explicit written
authorization to test.

### What you're attacking

Today's lab (`labs/day01/`) adds one `target` container to the shared `cyberlab`
network. It runs two deliberately leaky things, and nothing exploitable beyond
information disclosure — the point of Day 1 is to *map* a target, not break into one:

- **nginx on port 80**, left at stock configuration, serving a small page. Stock nginx
  reports its own version in the `Server` response header, and the page itself has an
  HTML comment naming a fictional CMS, version, and an admin email address.
- **A "legacy" service on port 2121** that immediately announces an outdated,
  fictional software name and version the moment a connection opens — standing in for
  the kind of stale, forgotten internal service every recon phase eventually finds.

Full setup: [`labs/day01/README.md`](../labs/day01/README.md). Bring it up (after
`labs/base/up.sh` if you haven't already):

```sh
cd cyber_security/labs/day01
docker compose up -d
```

### Step 1 — Banner grabbing

A **banner** is whatever a service announces about itself the moment you connect —
often a name, a version, sometimes an OS. Grab the web server's banner via its HTTP
headers, and the legacy service's banner directly over TCP:

```sh
docker compose exec attacker sh -c "curl -sI http://target/"
docker compose exec attacker sh -c "nc -w2 target 2121"
```

`curl -sI` sends a `HEAD` request and prints only the response headers — enough to see
the `Server:` line without pulling the whole page. `nc` (netcat) just opens a raw TCP
connection to port 2121 and prints whatever the service sends unprompted; some services
(like this one, and real SMTP/FTP servers) announce a banner without you asking for
anything.

**What you should see:** the `Server` header names nginx and a specific version; the
netcat connection to 2121 immediately prints a full software name and version string,
unprompted.

### Step 2 — Tech fingerprinting

`whatweb` goes beyond a single header — it runs a battery of signature checks (headers,
HTML structure, meta tags, common file paths) to identify the technology stack behind a
web target:

```sh
docker compose exec attacker sh -c "whatweb http://target/"
```

**What you should see:** confirmation of the nginx version (corroborating Step 1 from a
second, independent source — always worth doing, since a single header can be spoofed
or missing), the page `Title`, and — because `whatweb` also surfaces email addresses it
finds in page content — the admin email address left in the HTML comment. That last one
is a good example of *incidental* disclosure: nobody meant to leak an email address via
a version comment, but a fingerprinting tool doesn't care about intent.

### Step 3 — DNS lookups

```sh
docker compose exec attacker sh -c "dig target +short"
docker compose exec attacker sh -c "host target"
```

**What you should see:** an IP address for `target`. (Note: inside `cyberlab`, name
resolution is served by Docker's own embedded DNS resolver rather than a
production-style DNS server — but the *technique* — resolving a hostname to plan your
next move, and noticing what a DNS answer reveals about internal naming — is identical
to querying a real organization's DNS. `host` may also print an `NXDOMAIN` line for a
record type the target doesn't have; that's normal and itself informative — it tells
you which record types exist and which don't.)

### Step 4 — Initial port sweep

```sh
docker compose exec attacker sh -c "nmap -sV target"
```

`-sV` asks nmap to not just report which ports are open, but to actively probe each one
and try to identify the service and version running behind it.

**What you should see:** port 80 identified confidently as `nginx` with its version;
port 2121 reported open but with nmap *unable* to confidently match it to a known
service fingerprint (it may guess a wrong or generic name, or mark the service
unrecognized) — even though the raw banner text nmap captured while probing is right
there in its output. That gap is worth sitting with: **an open port is attack surface
whether or not a tool can name it.** An unidentified service is not a safe service — it's
one that needs a human to go look, exactly like Step 1's netcat connection did.

This step is also your first taste of **enumeration** — systematically listing out
*every* instance of some category of thing on a target, rather than checking one item
by hand. A single banner grab (Step 1) tells you about one service you already knew to
ask about; a port sweep enumerates *all* listening ports so nothing gets missed because
you didn't think to check it. You'll enumerate other categories later in this path —
directories and files (`gobuster`, Day 7+), users, and cloud IAM permissions (Day 13+)
— but the principle is the same one nmap just demonstrated: enumerate first, so your
attack surface map isn't missing rows you never thought to look for.

### Verify

```sh
docker compose exec attacker sh -c "nmap -sV target | tee /loot/day01.txt | grep -q open && echo ATTACK_OK"
```

Expected: `ATTACK_OK`. Full walkthrough with real captured output:
[`labs/day01/SOLUTION.md`](../labs/day01/SOLUTION.md).

### Reading the results as an attack surface map

Line up everything Steps 1–4 gave you and you have a map, not just a pile of output:

| Finding | What it tells an attacker |
|---|---|
| `Server: nginx/1.21.6` | Exact web server + version → look up nginx 1.21.x CVEs before trying anything blind |
| HTML comment: CMS name/version + admin email | A (fictional) tech stack to research, and a real-looking username/email to try against any login form found later |
| Port 2121 banner: legacy software name + version | A second, independently-versioned service — a whole additional CVE search, and evidence the host runs more than "just a web server" |
| Port 2121 open but nmap can't confidently name it | A forgotten or unusual service is often the least-patched one on a host — worth escalating attention, not ignoring because a tool didn't label it |
| DNS resolves `target` to an IP | Confirms the host is live and reachable, and (in a real org) reveals naming-scheme conventions if repeated across many hostnames |

That table *is* today's attack surface — five rows, five leaks, zero exploits used.

## 3. Defense Lab — Reduce the Attack Surface, Then Re-Verify

**Attack-surface reduction** means removing or minimizing exactly the kind of
disclosure Section 2 just harvested — not adding a new control, but taking things away.
Apply these three changes and re-run Section 2's commands to confirm each one worked.

### Change 1 — Suppress the version banner

nginx's version disclosure is controlled by the `server_tokens` directive, which
defaults to `on`. Add a minimal config that turns it off:

```nginx
# nginx.conf (or a conf.d snippet)
server_tokens off;
```

**Re-verify:** `curl -sI http://target/` — the `Server` header should now read just
`nginx` with no version number.

### Change 2 — Remove the disclosive HTML comment

The CMS name/version and admin email in `index.html`'s `<head>` serve no purpose for a
real visitor — they're pure disclosure. Delete both comment lines from the page.

**Re-verify:** `whatweb http://target/` — the email-address field should no longer
appear, and no fictional CMS name/version should show up in the output.

### Change 3 — Close the unneeded port

The port 2121 legacy service isn't used by anything and exists only as forgotten
infrastructure — the single best fix for a service nobody needs is to **not run it at
all**. Remove the banner-listener block from `entrypoint.sh` (or drop the service
entirely from the image) and rebuild.

**Re-verify:** `nmap -sV target` — port 2121 should no longer appear as open at all
(rather than open-but-unidentified). A port that doesn't exist can't be probed,
banner-grabbed, or eventually exploited — that's a strictly stronger position than an
open port with a suppressed banner.

Full before/after diffs and rebuild steps: [`labs/day01/SOLUTION.md`](../labs/day01/SOLUTION.md).

### The pattern to internalize

Every one of today's three fixes is the same move: **stop announcing something an
attacker would otherwise have to work to discover.** None of them make the underlying
software more secure — nginx 1.21.6 has the exact same code whether or not it reports
its version. What changes is the *cost* to an attacker of finding out what they're
up against, and every bit of that cost you add back is time you get before the next
stage of the kill chain even becomes possible.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Given nmap output, list the attack surface

You run `nmap -sV` against a host and get:

```
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 7.6p1 Ubuntu
80/tcp   open  http    Apache httpd 2.4.29
3306/tcp open  mysql   MySQL 5.7.21
```

List this host's attack surface (every distinct thing an attacker now knows to target)
and, for each item, name one concrete next research step you'd take.

**Hint:** attack surface isn't just "three open ports" — separate what's *open* from
what's *identified*, and think about what's unusual about a database port being
reachable at all versus the other two.

**Solution sketch:**

- **Port 22, OpenSSH 7.6p1 on Ubuntu** — a specific, versioned SSH implementation.
  Next step: check for known OpenSSH 7.6p1 CVEs, and note the Ubuntu tag narrows the OS
  family for later privilege-escalation research (Day 5).
- **Port 80, Apache httpd 2.4.29** — a specific, versioned web server. Next step: check
  Apache 2.4.29 CVEs, then move to Day 1-style fingerprinting of *what's running behind*
  Apache (a CMS? a custom app?) since the web server itself is rarely the final target.
- **Port 3306, MySQL 5.7.21** — the real red flag here isn't the version, it's that a
  **database port is exposed to whatever network this scan ran from at all.** In a
  well-segmented design (Day 2), MySQL should only be reachable from the application
  tier, not from wherever an nmap scan can reach it. Next step: try connecting directly
  (`mysql -h <host> -u root`) to test for default/blank credentials, and flag the
  exposure itself as a finding independent of whatever credentials turn out to be.
- The three rows together also tell you this is a full application stack on one host
  (web + DB + remote admin access) rather than a single-purpose server — useful context
  for prioritizing where to dig next.

### Drill 2 — Which headers leak info, and how do you suppress them?

Given this response:

```
HTTP/1.1 200 OK
Server: Apache/2.4.41 (Ubuntu)
X-Powered-By: PHP/7.2.24
X-AspNet-Version: 4.0.30319
Content-Type: text/html
```

Identify every header that leaks information an attacker could use, what it leaks, and
one concrete way to suppress or remove it.

**Hint:** one of these four headers is *not* disclosive in the same way as the others —
which one, and why is it different in kind?

**Solution sketch:**

- **`Server: Apache/2.4.41 (Ubuntu)`** — web server software, version, and OS
  distribution, all in one header. Suppress with `ServerTokens Prod` (and
  `ServerSignature Off` for error pages) in Apache config.
- **`X-Powered-By: PHP/7.2.24`** — backend language and exact version. Suppress with
  `expose_php = Off` in `php.ini`.
- **`X-AspNet-Version: 4.0.30319`** — .NET Framework version (this header is emitted by
  IIS/ASP.NET, so its *presence* on a response that already claims to be Apache/PHP is
  itself a signal something is misconfigured or fronted by multiple stacks — worth
  flagging on its own). Suppress by disabling it in `web.config`
  (`<httpRuntime enableVersionHeader="false" />`) or stripping it at a reverse proxy.
- **`Content-Type: text/html`** is the odd one out — it's a *functional* header the
  client needs to render the response correctly, not a disclosure of software identity.
  Removing or changing it breaks the page rather than reducing attack surface; the fix
  here is "don't touch it."

The general pattern: any header naming a specific software product, version, or
language runtime is disclosure and a suppression candidate; headers describing the
content itself (`Content-Type`, `Content-Length`, `Cache-Control`, etc.) are not, and
"suppressing" them would just break the response.

### Drill 3 — Passive vs. active: classify 5 actions

Classify each action as **passive** or **active** recon, and justify each in one
sentence:

1. Looking up a domain's registrar and creation date via WHOIS.
2. Running `nmap -sV` against a target's IP address.
3. Searching Shodan for devices matching a company's IP range.
4. Sending a `curl -I` request directly to a target's web server.
5. Reading a company's public job postings to infer their tech stack (e.g., "5 years of
   Kubernetes experience required").

**Hint:** re-apply the definition from Section 1 literally — for each action, ask "does
this send any traffic to a system the target itself operates?" If the answer is "no, I'm
querying someone else's database/index about the target," it's passive, no matter how
targeted or specific the query feels.

**Solution sketch:**

1. **Passive** — WHOIS queries a third-party registrar's database, not the target
   itself; the target's own systems never see this lookup.
2. **Active** — `nmap` sends packets directly to the target's IP; the target (or
   anything monitoring it) can observe and log this.
3. **Passive** — Shodan queries Shodan's own pre-collected index; you interact with
   Shodan's servers, not the target's.
4. **Active** — `curl` opens a direct TCP connection and sends an HTTP request straight
   to the target's own web server; this can appear in the target's access logs.
5. **Passive** — you're reading a public job board, not touching anything the target
   operates directly; the information happens to be *about* their infrastructure, but
   gathering it involves zero interaction with that infrastructure.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** the `target` container — name the specific leaks you found
  (version banner, HTML comment, legacy-service banner, open port) rather than writing
  just "recon."
- **How:** which of the four techniques (banner grabbing, fingerprinting, DNS, port
  sweep) gave you the *most* useful single piece of information, and why that one over
  the others?
- **What defended it:** which of the three attack-surface-reduction changes in Section 3
  do you think matters most in a real production system, and which matters least —
  argue for a ranking rather than treating all three as equally important.
- **What confused me:** anything about the passive/active distinction, or about why an
  unidentified open port (Section 2, Step 4) is still worth worrying about, that didn't
  click on first pass.
- **One thing to revisit:** pick one term from today (recon, banner grabbing,
  fingerprinting, enumeration, attack surface reduction) to re-explain from memory
  before Day 2, without looking back at this file.
