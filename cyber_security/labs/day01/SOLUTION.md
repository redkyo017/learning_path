# Day 1 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against the `target`
container this lab starts on `cyberlab`, or your own AWS sandbox in later phases.

## Step-by-step, with actual verified output

All output below was captured from a real run of this lab (`labs/base` up, then
`labs/day01` built and started with `docker compose up -d --build`).

**Note:** All `docker compose exec attacker` commands below must be run from `cyber_security/labs/base` (where the `attacker` service is defined).

### 1. Banner grabbing

```sh
docker compose exec attacker sh -c "curl -sI http://target/"
```

Confirmed output:

```
HTTP/1.1 200 OK
Server: nginx/1.21.6
Date: Wed, 12 Aug 2026 12:26:04 GMT
Content-Type: text/html
Content-Length: 355
Last-Modified: Wed, 12 Aug 2026 12:25:05 GMT
Connection: keep-alive
ETag: "6a7c6621-163"
Accept-Ranges: bytes
```

```sh
docker compose exec attacker sh -c "nc -w2 target 2121"
```

Confirmed output:

```
220 LegacyMail SMTP Server 2.3.1 (Ubuntu) ready
```

### 2. Tech fingerprinting

```sh
docker compose exec attacker sh -c "whatweb http://target/"
```

Confirmed output (colors stripped):

```
http://target/ [200 OK] Country[RESERVED][ZZ], Email[root@legacycorp.internal], HTML5,
HTTPServer[nginx/1.21.6], IP[172.19.0.3], Title[LegacyCorp Internal Portal], nginx[1.21.6]
```

Note the `Email[root@legacycorp.internal]` field — that's the admin address from the
HTML comment, surfaced automatically because `whatweb` scans page content for
email-shaped strings. Nobody had to go looking for it by hand.

### 3. DNS lookups

```sh
docker compose exec attacker sh -c "dig target +short"
```

Confirmed output: `172.19.0.3` (the container's address on `cyberlab` — will differ per
run/environment).

```sh
docker compose exec attacker sh -c "host target"
```

Confirmed output:

```
target has address 172.19.0.3
Host target not found: 3(NXDOMAIN)
```

The `NXDOMAIN` line is `host` also trying an `AAAA` (IPv6) lookup and getting no
record — expected and harmless, since this lab has no IPv6 configured.

### 4. Initial port sweep

```sh
docker compose exec attacker sh -c "nmap -sV target"
```

Confirmed output:

```
Starting Nmap 7.99 ( https://nmap.org ) at 2026-08-12 12:26 +0000
Nmap scan report for target (172.19.0.3)
Host is up (0.0000040s latency).
rDNS record for 172.19.0.3: cyberlab-day01-target.cyberlab
Not shown: 998 closed tcp ports (reset)
PORT     STATE SERVICE      VERSION
80/tcp   open  http         nginx 1.21.6
2121/tcp open  ccproxy-ftp?
1 service unrecognized despite returning data. If you know the service/version, please
submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port2121-TCP:V=7.99%I=7%D=8/12%Time=6A7C6665%P=aarch64-unknown-linux-gn
SF:u%r(NULL,30,"220\x20LegacyMail\x20SMTP\x20Server\x202\.3\.1\x20\(Ubuntu
SF:\)\x20ready\n");
MAC Address: 9A:5C:81:8F:DD:9A (Unknown)

Service detection performed. Please report any incorrect results at
https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 6.75 seconds
```

Notice nmap guesses `ccproxy-ftp?` (a wrong guess, marked uncertain with `?`) for port
2121, and even says the service is "unrecognized despite returning data" — but the raw
fingerprint it captured (`SF-Port2121-TCP`) contains the *exact* banner text
(`LegacyMail SMTP Server 2.3.1`), URL-escaped, right there in its own output. This is
the "unidentified is not the same as safe" point from the content file: the data was
there for nmap to capture even though its guess was wrong.

### 5. Verify command

```sh
docker compose exec attacker sh -c "nmap -sV target | tee /loot/day01.txt | grep -q open && echo ATTACK_OK"
```

**Confirmed output:** `ATTACK_OK`

## Defense lab — before/after, with confirmed output

The three changes below were applied and rebuilt in a throwaway image during
verification of this lab; the numbers confirm each fix actually suppresses what Section
2 found. To reproduce them yourself, edit the files in `target/` directly:

1. **Suppress the version banner** — add a config file (e.g.
   `target/nginx-hardened.conf`) containing `server_tokens off;`, `COPY` it to
   `/etc/nginx/conf.d/hardened.conf` in the Dockerfile (nginx's stock `nginx.conf`
   already includes everything under `conf.d/*.conf`), and rebuild.

   **Confirmed re-verify** (`curl -sI`):
   ```
   HTTP/1.1 200 OK
   Server: nginx
   ```
   (version number gone — compare to `nginx/1.21.6` before.)

2. **Remove the disclosive HTML comment** — delete the `<!-- generator: ... -->` and
   `<!-- admin contact: ... -->` lines from `target/index.html`, and rebuild.

   **Confirmed re-verify** (`whatweb`):
   ```
   http://target/ [200 OK] Country[RESERVED][ZZ], HTML5, HTTPServer[nginx],
   IP[...], Title[LegacyCorp Internal Portal], nginx
   ```
   (no `Email[...]` field, no version — compare to the Step 2 output above.)

3. **Close the unneeded port** — remove the `busybox nc -l` loop from
   `target/entrypoint.sh` (and the `busybox-extras` install / port 2121 `EXPOSE` from
   the Dockerfile, if you want the image itself to reflect the service is gone), and
   rebuild.

   **Confirmed re-verify** (`nmap -sV`):
   ```
   PORT   STATE SERVICE VERSION
   80/tcp open  http    nginx
   ```
   (port 2121 doesn't appear at all — not open-but-unidentified, simply not there.)

After all three changes, re-running the full Section 2 command sequence against the
hardened target should show: a version-less `Server` header, a `whatweb` result with
no leaked email or version, and an `nmap -sV` scan with exactly one open port and no
version string.

## If something doesn't match

- **`target` not resolvable / connection refused:** confirm `labs/base` is up first
  (`cd ../base && docker compose ps`) — `target` depends on the `cyberlab` network that
  `labs/base` creates.
- **`nmap -sV` shows different ports/services than above:** rebuild
  (`docker compose up -d --build`) to make sure you're running the current
  `target/Dockerfile`, not a stale cached image from an earlier edit.
- **IP addresses differ from this file:** expected — container IPs on `cyberlab` are
  assigned by Docker per-run and will differ across machines/sessions. Only the
  banners/headers/service names matter for comparison, not the specific IP.

## Answers reused from the content file

The attack-surface-mapping table and all three drills for Day 1 live in
[`content/day01-recon.md`](../../content/day01-recon.md) (Section 2's closing table,
and Section 4) — worked answers are inline there.
