# TLS/Certificates Lab Infrastructure

This directory holds the Docker-based lab environment used by every day of the
TLS/certificates mastery course. It is the scaffold that later labs (cert
generation, mTLS, ACME/pebble, packet inspection, etc.) build on top of.

## Why everything runs inside the `toolbox` container

macOS ships **LibreSSL**, not OpenSSL, behind the `openssl` command on the
host. LibreSSL's CLI output and flag support diverge from real OpenSSL in
ways that will silently break or misinform several labs in this course
(certificate extensions, some `-provider` options, TLS 1.3 details, etc.).

To avoid that trap entirely, this lab never runs `openssl`, `curl`, or
`tshark` on the host. Instead, the `toolbox` service builds an Ubuntu 24.04
image with real OpenSSL 3.x, curl, tshark, and bash pre-installed, and every
lab command is run through it via:

```
docker compose -f labs/docker-compose.yml run --rm toolbox <command>
```

The current directory (`labs/`) is bind-mounted into the container at
`/work`, so files you create or inspect from inside `toolbox` show up on the
host at `labs/` and vice versa.

## Services

- **toolbox** — built from `labs/toolbox/Dockerfile` (Ubuntu 24.04 +
  openssl, curl, tshark, ca-certificates, bash, coreutils, **certbot**).
  Mounts `.:/work` with `working_dir: /work`. `entrypoint: []` so any
  binary on PATH can be invoked directly, e.g. `docker compose run --rm
  toolbox openssl version`, or `docker compose run --rm --entrypoint
  certbot toolbox certonly ...` for the Day 5 ACME lab. Has a static IP
  (`10.77.30.10`) on `certlab` so Pebble has a stable address to validate
  challenges against across separate `run --rm` invocations.
- **nginx** — `nginx:stable`, used as the TLS-terminating server in later
  labs. Mounts `./services/active.conf` to `/etc/nginx/conf.d/default.conf`
  (the single config nginx actually loads; each day activates its own config
  by copying `services/nginx-dayNN.conf` over `services/active.conf` and
  restarting nginx) and `./certs` to `/etc/nginx/certs` (generated
  certificates/keys). Exposes `8443:443` on the host.
- **pebble** — `letsencrypt/pebble`, Let's Encrypt's own test ACME server
  (Day 5). Serves its ACME directory at `https://pebble:14000/dir` and a
  management API at `:15000`, both over HTTPS signed by Pebble's own test
  CA. Configured via `./acme/pebble-config.json` (bind-mounted) and
  `-dnsserver`, pointed at `challtestsrv`, so it can resolve the lab's
  test domain without touching real DNS.
- **challtestsrv** — `letsencrypt/pebble-challtestsrv` (Day 5), Pebble's
  companion DNS backend for challenge validation. Its own HTTP-01/HTTPS-01/
  TLS-ALPN-01 responders are disabled in this lab; certbot's own
  `--standalone` plugin answers the actual challenge itself, on `toolbox`.
  Management API on `:8055` (e.g. `POST /add-a` to register a test domain).

All services share a single user-defined bridge network, `certlab`
(`10.77.30.0/24`, fixed since Day 5 so `toolbox`/`pebble`/`challtestsrv`
can have static IPs), so containers can reach each other by service name
(e.g. `toolbox` can `curl https://nginx:443`).

## Verify setup

Run these from the repo root once Docker Desktop (or another Docker engine)
is running:

```
docker compose -f labs/docker-compose.yml run --rm toolbox openssl version
# Expected: OpenSSL 3.x  (NOT LibreSSL)
docker compose -f labs/docker-compose.yml run --rm toolbox tshark --version
# Expected: TShark (Wireshark) 4.x
```

If you see `LibreSSL` in the output, the command ran on the host instead of
in the container — double-check the `docker compose run` invocation.

## Verify CA

The persistent root + intermediate CA lives under `labs/ca/` and is built and
used entirely through the `toolbox` container (never on the host — see
"Why everything runs inside the `toolbox` container" above). Run from
`labs/` once Docker is up:

```
docker compose run --rm toolbox bash ca/make-root.sh
docker compose run --rm toolbox bash ca/make-intermediate.sh
docker compose run --rm toolbox bash ca/issue-server-cert.sh example.local example.local
docker compose run --rm toolbox openssl verify -CAfile ca/intermediate/certs/ca-chain.cert.pem \
    ca/intermediate/certs/example.local.cert.pem
# Expected final line: example.local.cert.pem: OK
```

You can also confirm the issued cert's SAN was set correctly:

```
docker compose run --rm toolbox bash -c \
    "openssl x509 -in ca/intermediate/certs/example.local.cert.pem -noout -text | grep -A1 'Subject Alternative Name'"
# Expected: DNS:example.local
```

`ca/make-root.sh` and `ca/make-intermediate.sh` are idempotent — re-running
them leaves an existing root/intermediate in place rather than regenerating
it (which would invalidate every cert already issued). `ca/issue-server-cert.sh
<cn> [san...]` can be called repeatedly for different CNs (e.g. `client01`,
`nginx`) since it only appends to the intermediate CA's existing
`index.txt`/`serial`. See `labs/ca/openssl-root.cnf` and
`labs/ca/openssl-intermediate.cnf` for the certificate extension policy
(basicConstraints, keyUsage, subjectAltName) each script relies on.

## Layout

```
labs/
├── docker-compose.yml   # toolbox + nginx + pebble + challtestsrv on the certlab network
├── ca/                  # persistent root + intermediate CA (built Day 2, reused every later day)
│   ├── openssl-root.cnf
│   ├── openssl-intermediate.cnf
│   ├── make-root.sh
│   ├── make-intermediate.sh
│   ├── issue-server-cert.sh
│   ├── root/            # generated: root CA db (certs/private/newcerts/csr/index.txt/serial)
│   └── intermediate/    # generated: intermediate CA db + issued leaf certs
├── toolbox/
│   └── Dockerfile       # Ubuntu 24.04 + openssl/curl/tshark/bash/certbot
├── acme/                # Day 5 — Pebble config + certbot/ACME wiring notes (see acme/README.md)
│   ├── pebble-config.json
│   ├── README.md
│   └── certbot/         # generated: certbot's --config-dir/--work-dir/--logs-dir state
├── services/            # active.conf (mounted into nginx) + per-day nginx-dayNN.conf
│                        # templates copied onto active.conf to activate
├── certs/               # generated certs/keys (mounted into nginx and toolbox)
└── README.md            # this file
```
