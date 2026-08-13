# Glossary

Every term this path introduces, defined in plain English, grouped alphabetically. Each
Day task appends its new terms here as it ships — this file grows with the path rather
than being written all at once. If a term you need isn't here yet, it likely belongs to
a day you haven't reached.

## A

**Access Analyzer (IAM Access Analyzer)** — an AWS IAM feature with two distinct
analyzer types: *external access* analysis, which flags resource-based policies (S3
bucket policies, role trust policies, etc.) granting access to principals outside your
account/organization; and *unused access* analysis, which flags permissions granted to
a principal but never exercised in the observed CloudTrail history. It reasons about
usage and cross-account exposure, not privilege-escalation reachability — that's
pmapper's job.

**AEAD** (Authenticated Encryption with Associated Data) — an encryption mode (most
commonly **GCM**) that provides both confidentiality (the data is unreadable without the
key) and integrity/authenticity (any tampering with the ciphertext is detected) in one
primitive, instead of needing to bolt a separate integrity check onto a plain encryption
mode. The modern default choice for symmetric encryption in transit and at rest — e.g.
`AES-256-GCM` in TLS 1.3.

**ARP spoofing** (ARP poisoning) — sending forged ARP replies that claim an IP address
belongs to your own MAC address, so other hosts on the same local network segment
route that IP's traffic to you instead of its real owner. Works because ARP has no
authentication — any host can claim any IP and every other host believes it
unconditionally. The usual first step toward becoming a man-in-the-middle on a local
network.

**Asymmetric encryption** (public-key encryption) — encryption using a *key pair*: a
public key anyone can use to encrypt (or verify a signature), and a private key only
the owner holds, used to decrypt (or sign). Solves the key-distribution problem
**symmetric encryption** has — no shared secret needs to travel anywhere — at the cost
of being far slower per byte, which is why real protocols (TLS included) use asymmetric
encryption only to establish a shared session key, then switch to fast symmetric
encryption for the actual data.

**Attack surface** — every point where an attacker could try to interact with or affect
a system: open ports, exposed endpoints, input fields, APIs, files, and the people who
use them. The larger the attack surface, the more places there are to attack.

**Attack surface reduction** — removing or minimizing exactly the things that make up an
attack surface: suppressing version banners, closing unneeded ports, deleting
disclosive comments/metadata, and turning off unused services. It doesn't make
remaining software more secure by itself — it removes the free information an attacker
would otherwise use to target that software.

**auditd** — a Linux kernel-level audit framework that, given configured rules
(e.g. watching `execve` calls where effective UID doesn't match real UID), logs
privileged actions for later detection/review; a second-line, after-the-fact
control, not a preventive one.

**Authorization (authz)** — the check of "what is this already-authenticated caller
allowed to do," distinct from authentication ("who are they"). Most access-control
bugs (IDOR, broken access control) live on this side of that line.

**Auto-remediation** — an automated, typically Lambda-driven response triggered
directly by a detection event (e.g. an EventBridge rule on a GuardDuty finding),
taking a containment action (such as rolling back an escalating IAM policy version)
without waiting for a human to read an alert first.

**AWS Config** — a service that continuously records a resource's current
*configuration state* over time and evaluates it against **Config rules**, flagging
resources as **noncompliant**. Unlike CloudTrail/GuardDuty, it doesn't require any new
action to happen — it catches a bad configuration that's been sitting unchanged.

## B

**Banner grabbing** — connecting to a service and reading whatever it announces about
itself unprompted or in response to a simple request (an HTTP `Server` header, an FTP
or SMTP greeting line, etc.) — usually a software name and version. Often the fastest
way to learn what's running behind an open port.

**Blind SQL injection** — SQLi where the response never shows the query's data or a
distinguishing error; the only signal is behavioral (boolean-based: does the page
change at all; time-based: does the response take measurably longer).

**Block Public Access (S3 Block Public Access, BPA)** — four independent S3
settings (`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`,
`RestrictPublicBuckets`), settable at the bucket or account level, that can
categorically forbid a bucket from ever being made public regardless of what ACL or
bucket policy is applied later. Independent of (and a stronger guarantee than) simply
not writing a public bucket policy, since it also blocks a *future* misconfiguration
from taking effect.

**Broken access control** — the umbrella OWASP Top 10 (A01, 2021) category for any
missing, wrong, or bypassable authorization check; IDOR is its most common shape.

**Brute force** — repeatedly guessing credentials (or, in Day 3's crypto context, a
key/hash preimage) one attempt at a time until one works, relying on volume rather
than any weakness in the target's logic. An **online** brute force (guessing directly
against a live endpoint, like `hydra` against a login form) is limited by network
round-trips and, ideally, stopped by **rate limiting**/lockout; an **offline** brute
force (guessing against a hash or signature you already have a local copy of — a
cracked password hash, or a JWT's HMAC secret) is limited only by local compute, which
is why offline targets need to be hard to compute against in the first place (a slow
**KDF**, or a long random secret) rather than merely rate-limited.

**Bucket policy** — a resource-based IAM policy attached directly to an S3 bucket,
written in the same JSON policy language as identity-based IAM policies, that can
grant or deny access to specific principals — including, if written with
`"Principal": "*"`, anyone on the internet, unauthenticated. Distinct from an
identity-based policy (attached to a user/role): a bucket policy is attached to the
*resource*, and evaluates alongside any identity-based policies the requester holds.

## C

**Capability** — a Linux mechanism that splits root's monolithic privilege into
individually grantable pieces (e.g. `CAP_NET_BIND_SERVICE`, `CAP_SETUID`), letting a
binary get one narrow privilege instead of full SUID-root — safer in principle, but
not automatically safe, since some individual capabilities are functionally
equivalent to full root.

**CBC** (Cipher Block Chaining) — a symmetric-encryption mode that XORs each plaintext
block with the *previous* ciphertext block (an **IV**, initialization vector, standing
in for block "zero") before encrypting it. Chaining means two identical plaintext blocks
produce different ciphertext blocks, fixing **ECB**'s pattern-leakage problem — but CBC
still needs a separate integrity check (it only provides confidentiality), and,
historically, a system that leaks whether decrypted padding was valid has let attackers
fully decrypt CBC-mode traffic without ever learning the key (a **padding oracle**
attack).

**Chain of custody** — the documented, unbroken record of who collected a piece of
evidence, when, how, and who has had access since; a broken chain makes evidence hard
to trust or use. The practical fix is to acquire a copy first and investigate the
copy, never the live system.

**CIA triad** — the three properties security aims to protect: **Confidentiality**
(only the right parties can read data), **Integrity** (data isn't tampered with
undetected), and **Availability** (the system works when it's needed). Most
vulnerabilities map to a break in one or more of these.

**Claim** — a single piece of information encoded inside a **JWT**'s payload — e.g.
`sub` (subject/username), `role`, `exp` (expiry timestamp), `iss` (issuer), `aud`
(audience). Claims are just JSON key-value pairs; nothing about them is secret or
protected from *reading* by anyone holding the token — only a valid signature protects
them from being *changed* undetected.

**CloudTrail** — an AWS service that records every control-plane API call made in an
account (who, what, when, from where, full request/response) as a neutral, complete
audit log. It does not judge whether an action was malicious — it's the record other
detection layers (GuardDuty, Athena queries, incident timelines) are built from.

**Command injection** — untrusted input reaching a function that hands a string to a
shell (`system()`, `exec()`, `os.system()`) unsanitized, letting shell metacharacters
(`;`, `&&`, `||`, `|`, backticks, `$()`) chain on an entirely separate command.

**Compensating control** — a control that does not remove an underlying vulnerability
but bounds the damage it can still cause if exploited (e.g. scoping a stolen
credential's IAM policy to one bucket instead of `s3:*` on every resource — the
credential can still be stolen, but is worth far less once stolen).

**Containment** — the IR phase that stops an incident from getting worse without
destroying the evidence needed for eradication/lessons-learned; isolating a host is
containment, immediately wiping/reimaging it is not.

**Cookie** — a small piece of data a server asks a browser to store and send back
automatically on every subsequent request to that server, most commonly used to carry
a **session** identifier. Attributes like `HttpOnly` (unreadable to JavaScript),
`Secure` (sent only over HTTPS), and `SameSite` (restricts cross-site sending) control
how much a cookie exposes if something else on the page or the network goes wrong.

**CORS (Cross-Origin Resource Sharing)** — the header-based mechanism a server uses
to explicitly relax **SOP** for named origins (`Access-Control-Allow-Origin`, preflight
`OPTIONS` requests); dangerous when the allowed origin is reflected from the request's
own `Origin` header instead of checked against a real allowlist.

**CSP (Content-Security-Policy)** — a response header restricting which origins
scripts/styles/frames may load from, the primary header-level mitigation against XSS
payloads executing or exfiltrating data.

**CSRF (Cross-Site Request Forgery)** — exploiting a browser's cookie-attachment
behavior (cookies travel based on request *destination*, not request *origin*) so a
page on any site can trigger a state-changing request against a site the victim is
already logged into, carrying their session cookie automatically.

**CVE** (Common Vulnerabilities and Exposures) — a unique public identifier
(`CVE-YYYY-NNNNN`) for one specific, publicly disclosed vulnerability; a name, not a
severity score.

**CVSS** (Common Vulnerability Scoring System) — a standardized 0.0–10.0 severity
score for a CVE (bands: 9.0–10.0 Critical, 7.0–8.9 High, 4.0–6.9 Medium, 0.1–3.9 Low),
used to triage which vulnerability to fix first.

## D

**Defense-in-depth** — designing so that a single control's failure isn't the whole
story; multiple independent layers each have to fail before an attacker reaches the
objective.

**Detection engineering** — the discipline of writing and tuning detection rules so
they catch real attacks (true positives) without either missing them (false
negatives) or drowning analysts in noise (false positives) — never a one-time act,
since thresholds and patterns need re-tuning as both normal traffic and attacker
behavior change.

**Detective control** — a control that notices an attack happened (CloudTrail,
GuardDuty, Config, and every IDS), as distinct from a **preventive control** that
stops it from succeeding in the first place. The two fail independently and neither
substitutes for the other.

## E

**ECB** (Electronic Codebook) — the simplest symmetric-encryption mode: encrypt each
fixed-size block of plaintext independently, with the same key and nothing else as
input. Its fatal flaw is that identical plaintext blocks always produce identical
ciphertext blocks, so any repeating structure in the plaintext (like the flat-color
regions of an image — the famous "ECB penguin") remains visible in the ciphertext even
without the key. **CBC** and **GCM** both fix this by making each block's ciphertext
depend on more than just its own content.

**Egress control** — deliberately restricting or monitoring *outbound* traffic (not
just inbound), e.g. a private subnet's NAT-only egress path, or an explicit NACL/SG
outbound rule — the often-neglected other half of network exposure, since most
misconfiguration attention defaults to inbound only.

**Enumeration** — systematically listing out *every* instance of some category of thing
on a target — every open port, every directory/file, every user, every IAM
permission — rather than checking items one at a time by hand. The goal is coverage:
nothing gets missed because nobody thought to check for it.

**EventBridge** — AWS's event bus: routes events (GuardDuty findings, and most
CloudTrail-recorded API calls, delivered automatically as "AWS API Call via
CloudTrail" events) to targets like SNS (human alert) or Lambda (automated response).
It detects nothing itself — pure routing between "something happened" and "something
should happen next."

## F

**fail2ban** — a log-watching daemon that matches a configured pattern (a **filter**)
against a log file and, once a source crosses a threshold within a time window (a
**jail**'s `maxretry`/`findtime`), runs a **ban action** — typically inserting a
firewall rule that blocks that source. Signature-based by construction: it matches an
exact log-line shape, not a learned baseline.

**Findings report** — the artifact that makes an attack matter to a defender: scope,
methodology, one block per vulnerability (description/evidence/impact/severity), and
an attack narrative precise enough for someone who never ran a command to reproduce
the work from the document alone.

**Fingerprinting** — identifying the specific technology stack behind a target (web
server, framework, CMS, language runtime) by matching observed signals — headers, HTML
structure, error pages, file paths — against known signatures, rather than relying on a
single self-reported banner.

## G

**GCM** (Galois/Counter Mode) — an **AEAD** mode built on top of a counter-mode block
cipher; the standard modern choice for symmetric encryption (e.g. `AES-256-GCM` in
TLS 1.3) because it gives both confidentiality and built-in integrity/authenticity in a
single, fast pass. GCM has no padding at all, so the **padding oracle** attack class
that targets plain CBC simply doesn't apply to it.

**GTFOBins** — a curated catalog (gtfobins.github.io) mapping specific Unix binaries
to the exact commands that turn them into privilege-escalation or restriction-bypass
primitives when reachable via SUID, sudo, or a capability.

**GuardDuty** — a managed AWS threat-detection service that continuously analyzes
CloudTrail, VPC Flow Logs, and DNS query logs against threat intelligence and
behavioral models, and emits pre-classified, named, severity-scored **findings**
instead of requiring you to write the detection logic yourself.

## H

**Hash** — a one-way function that turns input of any size into a fixed-size output (a
digest), such that the same input always produces the same digest, a tiny change in
input produces a wildly different digest, and — for a cryptographic hash — there's no
practical way to reverse the digest back into the input. Used to verify integrity (does
this file match what it should?) and, historically, to store passwords — but a *fast*
general-purpose hash like MD5 or SHA-1/256 is the wrong tool for password storage
specifically, because being fast is exactly what makes it cheap to brute-force; see
**KDF**.

**Header (HTTP header)** — a `Name: Value` metadata line on a request or response,
standard (`Content-Type`, `Host`) or application-defined; several conventional
response headers (CSP, HSTS, X-Frame-Options, etc.) exist specifically to tell a
browser to apply an extra security restriction.

**HSTS (Strict-Transport-Security)** — a response header telling the browser to
never downgrade this site from HTTPS back to HTTP for a set duration, closing an
SSL-stripping MITM window; meaningless without TLS actually present.

**HTTP method** — the verb naming what a request asks a server to do (`GET`, `POST`,
`PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`); each has a **safe** (no side effects)
and/or **idempotent** (repeating it yields the same end state) profile that browsers,
caches, and crawlers are entitled to assume holds.

## I

**IAM policy** — a JSON document (`Version` + `Statement` entries, each with an
`Effect`, `Action`, and `Resource`) that grants or denies specific API calls; attached
directly to a user/role/group as an identity-based policy, or to a resource (e.g. an
S3 bucket policy).

**IAM principal** — anything that can make an authenticated request to AWS: an IAM
user, an IAM role (a temporary identity anything can assume), or an AWS service
acting on your behalf.

**IAM privilege escalation (IAM privesc)** — using IAM permissions a principal already
legitimately holds to increase that principal's own effective access, without
guessing a password or exploiting a code vulnerability. Three classic primitives:
`iam:PassRole` + `ec2:RunInstances` (borrow a more-privileged role's credentials via a
launched instance), `iam:CreatePolicyVersion` (rewrite and activate a new version of a
policy attached to yourself), and `iam:AttachUserPolicy`/`iam:PutUserPolicy` (attach a
more-privileged policy directly to yourself).

**IAM role** — a temporary identity anything can assume, distinguished from a user by
having two separate documents: a trust policy (who may assume it) and a permission
policy (what it can do once assumed).

**IDOR (Insecure Direct Object Reference)** — an endpoint that identifies which object
to act on by a client-supplied value (an ID in a URL/body) and never separately checks
whether the calling identity actually owns that specific object.

**IDS** (Intrusion Detection System) — a system that watches traffic or logs for
suspicious activity and raises an alert, without necessarily blocking anything itself
(contrast an **IPS**, Intrusion Prevention System, which acts on what it sees).
Detection rules are either **signature-based** (matching a known-bad pattern, like a
specific scan tool's packet shape or a fixed log-line format) or **anomaly-based**
(flagging behavior that deviates from a baseline, like an IP suddenly claiming a new
MAC address). Signature-based detection is fast and precise but blind to novel
variants; anomaly-based detection catches novelty but needs a real baseline and
produces more false positives. A single `iptables` log rule or a manual `arp -a` diff
is a first taste of the idea; a real IDS (e.g., Suricata, or a `fail2ban` jail) runs
these checks continuously and at scale.

**IMDS (Instance Metadata Service)** — a service every EC2 instance can reach at the
fixed link-local address `169.254.169.254`, answering only from inside that
instance's own network path, that hands back information about the instance
including, if an instance role is attached, that role's live temporary AWS
credentials. Exists so instances never need credentials baked into an AMI or config
file.

**IMDSv2** — the token-gated version of IMDS: retrieving data requires first sending
a `PUT` to `/latest/api/token` (with a TTL header) to obtain an opaque session
token, then repeating the request with that token in an `X-aws-ec2-metadata-token`
header; also caps the request to a configurable network-hop limit
(`--http-put-response-hop-limit`). Defeats SSRF gadgets that can only issue a `GET`
with no custom headers — the common, realistic shape of most real-world SSRF
findings — without requiring any change to the vulnerable application's own code.
Contrast **IMDSv1**, which answers plain, unauthenticated `GET` requests directly.

**Instance role** — an IAM role whose trust policy allows the EC2 service to assume
it, attached to an EC2 instance at launch. Nothing on the instance needs to know a
secret; the instance queries IMDS and receives live, temporary credentials for
whatever that role is currently allowed to do — which is also the risk: anything able
to make the instance issue a request to IMDS on its behalf (e.g. an SSRF bug in an
unrelated app on that instance) can walk out with those same credentials.

**IOC (Indicator of Compromise)** — an artifact or observation (a file, a log line,
an account, a hash mismatch) that provides evidence a system has been compromised.

**IR lifecycle** — the six-phase structure for handling a security incident:
Preparation, Detection, Containment, Eradication, Recovery, Lessons Learned; each
phase depends on the previous having happened first.

## J

**JWT** (JSON Web Token) — a compact, self-contained token format: three
base64url-encoded parts (`header.payload.signature`) separated by dots. The header
names the signing algorithm; the payload holds **claims**; the signature — for the
common `HS256` algorithm — is `HMAC-SHA256(secret, header + "." + payload)`, which
means anyone who can guess or crack that secret can compute a valid signature over
*any* claims they want, including an elevated role, without ever needing a real
password. A historically real, separate vulnerability class is a verifier that trusts
the algorithm named inside the token itself and accepts `alg: none` as "no signature
needed" — dangerous even though it's a library-implementation bug, not a property of
JWT as a format; see `content/day04-auth.md`.

## K

**KDF** (Key Derivation Function) — a function purpose-built to turn a password (or
other low-entropy secret) into cryptographic key material, deliberately made *slow* and
memory-hard (unlike a general-purpose **hash**) so that brute-forcing every possible
password is expensive even for an attacker with cracking hardware. **bcrypt**,
**scrypt**, and **argon2** are KDFs designed specifically for password storage, and
normally combine the password with a per-user **salt** automatically.

**Kill chain** — the recurring shape of an attack (recon → foothold → escalation →
lateral movement → objective), borrowed from Lockheed Martin's original model; used
as a shared vocabulary for describing an attack precisely rather than narrating it as
an unstructured sequence of actions.

## L

**Lateral movement** — moving from one compromised system to another within an
environment, typically to reach a network segment or resource the attacker's original
point of access has no direct route to.

**Least privilege** — granting the minimum privilege a task requires and nothing
more, so that removing an unnecessary privilege (a SUID bit, a broad sudo rule, an IAM
wildcard like `s3:*`/`Resource: "*"`, a world-writable file) eliminates an escalation
path outright rather than merely making it detectable.

**Link-local metadata (address)** — `169.254.169.254`, the fixed address every major
cloud provider (AWS/GCP/Azure) uses for their Instance Metadata Service; an
unauthenticated-by-design endpoint an instance uses to fetch its own temporary IAM
credentials — the concrete real-world target SSRF reaches when it escalates from a
toy internal service to real cloud credentials.

## M

**MFA** (Multi-Factor Authentication) — requiring a second, independent proof of
identity beyond a password (something you *have*, like a one-time code or hardware
key, or something you *are*, like a fingerprint), so that a stolen or guessed password
alone is no longer sufficient to log in. The single most effective mitigation against
both the brute-force and credential-reuse attack classes.

**Mitigation** — a control or countermeasure applied to reduce the likelihood or impact
of a threat — e.g., input validation, encryption in transit, network segmentation, or
least-privilege access controls. Every trust boundary should have at least one
mitigation covering it.

**MITM** (man-in-the-middle) — a position where an attacker sits between two
communicating parties and can read (and, if also relaying traffic, silently tamper
with) what passes between them, without either party's own protocol necessarily
detecting the interception. ARP spoofing is a common way to gain a MITM position on a
local network; the interception itself typically happens at a lower layer (e.g., L2)
than the data being exposed (e.g., an application-layer cleartext credential exchange).

## N

**NACL (Network ACL)** — a stateless, subnet-level firewall with ordered
allow-and-deny rules (first match wins by ascending rule number); every instance in
the subnet inherits it, and unlike a security group it can actively block traffic
other layers would allow.

**Network segmentation** — deliberately splitting a network into isolated zones (via
VLANs, subnets, or separate physical/virtual networks) so that reachability into one
zone doesn't automatically grant reachability into another. Doesn't stop an attack
already inside a segment, but stops an attacker from *getting into* a segment they
haven't separately compromised a path into — the first and often most effective layer
of defense against local-network attacks like ARP spoofing.

## O

**OIDC** (OpenID Connect) — an identity layer built on top of **OAuth 2.0** that lets
an application delegate "who is this user?" to a trusted external identity provider
(IdP) rather than handling passwords itself, returning a signed **JWT** (an ID token)
asserting the user's identity. The practical shift it represents: instead of every app
rolling its own login form and password database, most modern systems federate that
responsibility to one hardened, purpose-built provider.

**Output encoding** — transforming untrusted data so characters that would be
interpreted as HTML/JS structure (`<`, `>`, `&`, `"`, `'`) become inert text instead;
must match the *context* the data lands in (HTML body vs. attribute vs. `<script>`
vs. URL each need different encoding).

## P

**Packet capture** — recording raw network frames off the wire (with tools like
`tcpdump` or `tshark`) so traffic can be inspected at the protocol level, independent
of what any higher-level tool reports about it. What turns a MITM position, or a scan
in progress, from an abstract claim into bytes you can actually read.

**Padding oracle** — a vulnerability where a system leaks (via a distinct error
message, response time, or status code) whether decrypted data had valid padding,
without ever revealing the plaintext directly. Because **CBC**-mode decryption depends
on XOR relationships between adjacent ciphertext blocks, an attacker who can repeatedly
query this valid/invalid signal — and nothing else — can still recover the entire
plaintext one byte at a time, without ever learning the encryption key. A real,
historically damaging attack class (Vaudenay, 2002; tools like PadBuster), not just
theory.

**PassRole (`iam:PassRole`)** — the IAM permission that authorizes a principal to
hand an IAM role to an AWS service (e.g. attaching a role's instance profile to an
EC2 instance, or a role as a Lambda execution role) so that service can act with that
role's permissions. Legitimate and necessary for normal AWS operation; dangerous when
granted unrestricted (`Resource: "*"`, no `iam:PassedToService` condition) alongside a
permission that can execute code under a passed role, since it lets a low-priv
principal borrow a highly-privileged role's credentials.

**Permission boundary** — a managed policy attached to a single user or role that
caps the maximum permissions that identity's own policies can ever grant; effective
permission is the intersection of the identity policy and the boundary, never their
union.

**Persistence** — a mechanism an attacker plants to keep access after the initial
foothold is closed (a cron job, a backdoor account, a planted SSH key); often
multi-part, and eradicating only part of it leaves it functionally intact.

**Pivot** — the specific lateral-movement technique of using an already-compromised
host's own network position and tools as a stepping stone into a segment the attacker
could not reach directly; contrasted with **SSRF**, which crosses a network boundary
by tricking a *different* server into making the request instead.

**pmapper (Principal Mapper)** — an open-source tool (NCC Group) that builds a graph
of every IAM principal, policy, and resource in an account and computes, offline,
every reachable privilege-escalation path between principals — reasoning about
structural *reachability* rather than observed *usage*, which is what distinguishes it
from IAM Access Analyzer's unused-access findings.

**Policy evaluation** — AWS's fixed precedence for deciding allow/deny across every
applicable policy: explicit deny beats any explicit allow, which beats the default
implicit deny.

**Policy version** — customer-managed IAM policies keep up to five versions of their
document simultaneously; exactly one is the *default version*, which is the one
actually enforced. `iam:CreatePolicyVersion` creates a new version;
`iam:SetDefaultPolicyVersion` activates it. A principal granted `CreatePolicyVersion`
on a policy attached to itself can rewrite what that policy grants without ever
calling `iam:AttachUserPolicy`.

**Prepared statement** (parameterized query) — a query where structure and data
travel to the database separately via placeholders bound in after parsing, so
untrusted values can never be interpreted as SQL syntax; closes the entire SQLi class
structurally rather than patching individual payloads.

**Privilege escalation** — moving from a lower-privilege account/context to a
higher-privileged one (commonly root, or a more-privileged cloud identity) by
exploiting a misconfiguration or bug, rather than through legitimate authorization.

**Proxy** — an intermediary between client and server; a forward proxy relays traffic
unchanged, an intercepting proxy (mitmproxy, Burp) can read and rewrite
requests/responses in flight — the same capability a legitimate tester or an
unauthorized MITM would both have.

**Public/private subnet** — a **public subnet**'s route table sends `0.0.0.0/0` to
an Internet Gateway (so an instance in it *can* be reached from the internet, if it
also has a public IP and a permissive security group); a **private subnet** has no
IGW route, so it can't be reached directly from the internet regardless of its
security group, though it can still reach out via a NAT Gateway.

## R

**Rate limiting** — capping how many requests (login attempts, API calls) a client can
make in a given time window, so an attacker gains nothing by simply sending more
requests faster. The direct mitigation against online **brute force**; usually paired
with account lockout (blocking further attempts after N failures, regardless of rate)
for the highest-value targets like login endpoints.

**Reconnaissance (recon)** — the information-gathering phase of an attack, and the
first stage of the cyber kill chain. Splits into **passive recon** (gathering
information without directly interacting with the target — WHOIS, public DNS records,
search engines, Shodan) and **active recon** (directly interacting with the target —
port scanning, banner grabbing, sending requests), where only the latter can be logged
or detected by the target itself.

**Remediation** — a fix that removes the underlying vulnerability itself, so the
attack class cannot recur regardless of what an attacker tries (contrasted with a
**compensating control**, which bounds impact without removing the bug).

**Residual risk** — what remains true, honestly named, after every reasonable control
has been applied to a system; not a confession of failure, but failing to name it is
one.

## S

**Salt** — a random value generated fresh per password and stored alongside its hash
(not secret, just unique), then combined with the password before hashing. Salting
defeats precomputed **rainbow table** lookups and, critically, ensures two users with
the same password get completely different stored hashes — without a salt, cracking one
hash in a leaked database cracks every other account that reused that password too.

**SameSite** — a cookie attribute (`Strict`/`Lax`/`None`) telling the browser itself
whether to attach a cookie to cross-site requests at all; `Strict`/`Lax` is one of the
two independent fixes for CSRF (the other being anti-CSRF tokens).

**SBOM** (Software Bill of Materials) — a complete, machine-readable inventory of
every direct and transitive component in a build (name, version, license, origin),
answering "what exactly is in this build" so a newly published CVE can be checked
against already-shipped artifacts without re-scanning each one.

**SCP** (Service Control Policy) — an AWS Organizations-level policy applied to an
account or OU that caps what every identity in scope can ever do, overriding any
identity policy inside that account.

**Secrets manager** — a dedicated, access-controlled, audited service (AWS Secrets
Manager, SSM Parameter Store) that stores and serves secrets to authorized callers at
runtime, so no credential needs to live in a file in a repo.

**Secrets sprawl** — the failure mode where credentials accumulate scattered across
many small, easy-to-miss places (`.env` files, config, comments, scratch notes) over
time, rather than leaking from one obvious location — meaning manual review doesn't
scale to finding them; a whole-tree scanner does.

**Security group (SG)** — a stateful, allow-only firewall attached to an
instance/ENI; an allowed inbound request's reply is automatically allowed outbound
with no matching rule needed.

**Session** — server-side state associated with one logged-in user, referenced by a
**cookie** holding a session identifier. Two distinct attack classes target sessions:
**session fixation** (an attacker gets a victim to authenticate under a session ID the
attacker already knows — possible whenever a server accepts a client-supplied session
ID instead of always issuing a fresh one at login) and **session hijacking** (an
attacker steals an already-authenticated session ID directly, e.g. by reading it off
the network or out of client-side storage). The fix for fixation is always
regenerating the session ID at the moment of successful login, discarding whatever ID
the client had before.

**Shared responsibility model** — AWS's division of security duties: AWS owns
security "of" the cloud (physical/hypervisor/network hardware); the customer owns
security "in" the cloud (IAM, data, configuration, and — for IaaS like EC2 — the guest
OS), with the customer's share narrowing as the service becomes more fully managed
(e.g. S3 vs. EC2).

**SIEM** (Security Information and Event Management) — a system that ingests
telemetry from many sources (network IDS, host logs, cloud audit trails), normalizes
it, and gives an analyst one place to query and correlate across all of it.

**SOP (Same-Origin Policy)** — the browser default that a script on one origin
(scheme+host+port) cannot read the response of a cross-origin request; it does not
block the cross-origin request from being sent, only a script from reading its
response.

**SQL injection** — a SQL injection point exists wherever untrusted input reaches a
SQL query as literal text rather than as a bound parameter, letting an attacker alter
the query's logic or structure. **UNION-based** SQL injection (see `## U`) and
**blind** SQL injection are two of its common shapes.

**SSRF (Server-Side Request Forgery)** — tricking a server-side process into making a
request, to a destination the attacker chose, that the attacker could not have
reached directly themselves; the vulnerability is in the pivot, not in the
destination alone.

**SSRF-to-cloud** — the specific escalation of an SSRF bug when the
attacker-reachable internal target is `169.254.169.254` (IMDS) rather than some other
internal service: an SSRF finding that would otherwise only leak an internal API
response instead yields live, valid AWS credentials for the instance's own role,
turning a web-app bug into cloud-account credential theft.

**STRIDE** — a threat-modeling mnemonic covering six categories of security failure:
**S**poofing (impersonating something or someone), **T**ampering (unauthorized
modification of data or code), **R**epudiation (denying having performed an action),
**I**nformation disclosure (exposing data to unauthorized parties), **D**enial of
service (degrading or blocking availability), and **E**levation of privilege (gaining
capabilities beyond what's authorized). Used as a five-minute checklist to threat-model
any system, one category at a time.

**Subnet** — a slice of a VPC's address space pinned to one Availability Zone;
whether it's public or private is determined by its route table, not by anything
inherent to the subnet itself.

**SUID/SGID** — special file permission bits that make an executable run with the
file owner's (SUID) or file group's (SGID) privileges instead of the caller's, rather
than the caller's own.

**Symmetric encryption** — encryption using the *same* key to both encrypt and decrypt
(e.g. AES). Fast and simple, but requires both parties to already share that key
through some secure channel — the problem **asymmetric encryption** solves. Modern
protocols (TLS included) typically use asymmetric encryption only to set up a shared
symmetric key, then do the bulk of the actual data encryption symmetrically, because
it's dramatically faster.

**SYN scan** — nmap's default port-scanning technique (`-sS`): send a TCP `SYN` packet
and read whether a `SYN-ACK` (port open) or `RST` (port closed) comes back, then tear
the connection down with a `RST` instead of completing the three-way handshake with an
`ACK`. Faster than a full **connect scan** (`-sT`), and often quieter, since many
services only log *completed* connections at the application layer — a half-open scan
frequently never reaches that layer at all.

## T

**Telemetry** — the deliberate, cross-system instrumentation that turns individual
logs into something a detector can watch continuously and alert on — contrast a bare
**log** (one system's record of one event); telemetry is what makes "did anyone
brute-force a login in the last hour" an answerable question instead of a manual grep
through one file.

**Temporary credentials** — an `AccessKeyId`/`SecretAccessKey`/`SessionToken` triple
with a real `Expiration` timestamp, typically valid for hours, issued by AWS STS
(directly via IMDS for an instance role). Automatically rejected by AWS after
`Expiration` regardless of anything the holder does — unlike a leaked long-lived IAM
user access key, a leaked temporary credential set has a hard, automatic, unextendable
expiry, though anything done with it *before* expiration is not undone by that expiry.

**Threat actor** — the party who might carry out a threat: an external attacker, a
malicious insider with legitimate credentials, an automated bot/worm, or even an
unintentional actor (a misconfigured script, a careless employee). Naming the threat
actor for a given threat clarifies its likelihood and motivation.

**Threat model** — a structured way of answering "what could go wrong, and who would
make it go wrong?" for a specific system, so defenses can be prioritized against real
threats instead of guesswork.

**Timeline** — a chronological reconstruction of incident events, each entry backed by
a specific, citable piece of evidence rather than inference.

**Transitive dependency** — a package pulled in indirectly (a dependency of a
dependency), never named directly in your own manifest, but still executing in your
process with your process's permissions — still your problem to patch.

**Triage** — the fast, time-pressured first pass over an alert or report deciding
whether it's a real incident, how severe, and what needs to happen immediately versus
what can wait for full investigation.

**True positive / false positive / false negative / true negative** — the four
possible outcomes of a detection rule: it fires correctly (**true positive**), fires
incorrectly (**false positive** — costs analyst time and, at scale, trains people to
ignore alerts), stays silent when it shouldn't (**false negative** — the attack
succeeds undetected), or stays silent correctly (**true negative** — the overwhelming
majority of all traffic, always). Detection engineering's whole job is tuning the
trade-off between these, never eliminating false positives/negatives outright.

**Trust boundary** — a line in a system's architecture where the level of trust changes
— e.g., between a browser (untrusted) and a web server (trusted), or between a web
server and a database. Anything crossing a trust boundary needs to be validated,
authenticated, or otherwise checked; that's where a large share of vulnerabilities live.

**Typosquatting** — publishing a malicious package under a name deliberately one
keystroke/visual-slip away from a real, popular package's name, betting a developer's
typo installs the fake one; categorically different from a legitimate package having
a real CVE, since there is no real project behind a typosquatted name to "upgrade."

## U

**UNION-based SQL injection** — an in-band SQLi technique that appends a second
`SELECT` via `UNION` whose results render in the same place the original query's
results would have; requires the injected `SELECT` to return the same column count,
in compatible types, as the original query.

## V

**VPC** (Virtual Private Cloud) — an isolated virtual network you define inside an
AWS account; nothing inside it is reachable from outside unless a path is explicitly
built in.

**VPC Flow Logs** — a capture of connection metadata (source/dest IP:port, protocol,
byte/packet counts, and an ACCEPT/REJECT decision reflecting the SG/NACL outcome) at
the ENI, subnet, or VPC level — never payload content, unlike a packet capture.

## X

**XSS (Cross-Site Scripting)** — injection aimed at a browser's HTML/JS parser, split
into three types by where the payload lives between planting and execution:
**reflected** (lives only in the current request/response, needs a per-victim
crafted link), **stored** (saved server-side, fires for every future viewer with no
per-victim link needed), and **DOM-based** (never touches the server at all —
client-side JS reads and writes untrusted data into the page, e.g. via `innerHTML`).
