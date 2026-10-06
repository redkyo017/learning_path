# Day 2 — Docker Networking, Volumes & Compose

## Why this matters

In microservice architectures, single isolated containers rarely deliver value. Real systems consist of multiple collaborating processes: an API gateway routing to downstream services, services querying shared relational stores, and background workers processing event streams.

Engineers who only understand `docker run -p 8080:80` constantly battle local development friction: "Why can't service A connect to `localhost:5432` inside container B?", "Why did all test database tables vanish when I recreated the container?", or "Why did our Compose stack fail in CI because Postgres wasn't ready yet?"

To orchestrate microservices locally with confidence, and to understand Kubernetes Pod and Service networking later in the week, you need to know how Linux virtual ethernet pairs (`veth`), bridge networks, firewall rules, Docker's embedded DNS resolver (`127.0.0.11`), volumes and deterministic Compose orchestration actually work.

**Mac note:** every bridge, veth, iptables rule and volume directory in this day lives in Docker Desktop's Linux VM, not on your Mac. `ip link` on the Mac shows nothing useful. The lab uses privileged helper containers (`--net=host` shares the *VM's* network namespace) to look at them. Day 2 is Docker engine only, no Kubernetes.

---

## The layer this covers

```
┌─────────────────────────────────────────────────────────────────────────┐
│          Engine host network namespace (the VM on Docker Desktop)       │
│                                                                         │
│  nat table:  DOCKER chain  127.0.0.1:8080 ──DNAT──► 172.28.0.5:8080     │
│              POSTROUTING   172.28.0.0/24 ! -o br-… ──MASQUERADE         │
│  filter:     FORWARD → DOCKER-FORWARD → DOCKER-CT / DOCKER-BRIDGE       │
│              DOCKER chain: "! -i br-X -o br-X -j DROP" (isolation)      │
│                                                                         │
│  Linux bridge br-<net-id> 172.28.0.1/24    (L2 switch + L3 gateway)     │
│       ├── vethAAAA ◄──────────────────┐                                 │
│       └── vethBBBB ◄───────┐          │                                 │
└────────────────────────────┼──────────┼─────────────────────────────────┘
                             │ veth pair│ veth pair
      ┌──────────────────────┴───┐  ┌───┴──────────────────────────┐
      │ order-api netns          │  │ payment-service netns        │
      │ eth0@ifN 172.28.0.5/24   │  │ eth0@ifM 172.28.0.2/24       │
      │ lo 127.0.0.1             │  │ lo 127.0.0.1                 │
      │ resolv.conf: 127.0.0.11  │  │ resolv.conf: 127.0.0.11      │
      │ (resolver listens in the │  │ (own DNAT rules to dockerd's │
      │  netns, answered by      │  │  resolver, same trick)       │
      │  dockerd)                │  │                              │
      └──────────────────────────┘  └──────────────────────────────┘
```

---

## Core concepts

### 1. Docker Networking Internals

#### A. Linux Virtual Ethernet Pairs (`veth`) & Bridges
When Docker creates a container on a bridge network:
1. It creates a dedicated network namespace (`netns`) for the container.
2. It allocates a **veth pair** (a virtual cable with two ends).
3. One end (`vethXXXX`) stays in the engine host's namespace, attached (`master`) to a Linux bridge: `docker0` for the default network, `br-<first 12 chars of the network ID>` for user-defined ones.
4. The other end moves into the container namespace and is renamed `eth0`. Its name shows its peer: `eth0@if183` means "the other end has interface index 183 in the host namespace".
5. The bridge is an L2 switch between the attached veths, and the bridge interface itself holds the gateway address (`172.28.0.1`), so the host namespace routes between the bridge and the outside world.

#### B. Embedded DNS Server (`127.0.0.11`)
- On the **default bridge (`docker0`)** there is no name resolution between containers: you get IPs or the legacy `--link`.
- On **user-defined bridge networks** (including the one Compose creates), `/etc/resolv.conf` contains `nameserver 127.0.0.11`. Nothing listens on that address in the usual sense: dockerd opens a resolver *inside each container's netns* and installs `DOCKER_OUTPUT` iptables DNAT rules there that redirect `127.0.0.11:53` to the resolver's real ephemeral port. Queries for other names are forwarded to the host's DNS servers.
- Resolution is **scoped per network**: a container only resolves names of containers that share a network with it. A service name, any `aliases:` you declare on that network, and the container name all resolve; round-robin if several containers share an alias.
- `ndots:0` in the generated `resolv.conf` means short names are queried as-is (no search-domain expansion), unlike Kubernetes pods (Day 4).

#### C. Port Mapping, DNAT and Masquerade
Publishing `-p 127.0.0.1:8080:8080` makes the engine add, in the VM's `nat` table (`DOCKER` chain):
```
-A DOCKER -d 127.0.0.1/32 -p tcp --dport 8080 -j DNAT --to-destination 172.28.0.5:8080
```
- Without the `127.0.0.1` prefix the rule matches any destination (all host interfaces), which is why `-p 8080:8080` exposes a service to your LAN. Bind published ports to loopback unless you mean it.
- The `filter` table gets a matching ACCEPT for that container IP and port in the `DOCKER` chain, and a per-network `! -i br-X -o br-X -j DROP` after it. The ACCEPT rules apply to traffic arriving from *any other* interface, so a published port is reachable from containers on other networks via the container IP; unpublished ports are not.
- **Outbound** traffic from a container to the outside is source-NATed: `-A POSTROUTING -s 172.28.0.0/24 ! -o br-… -j MASQUERADE`. Container-to-container traffic on the same bridge is neither DNATed nor masqueraded: it is plain L2/L3 between the two IPs (tcpdump in the lab shows `172.28.0.5 > 172.28.0.2:8081`).
- Port mapping is only for traffic entering from *outside* the network. Containers never need it to talk to each other.
- **Docker Desktop:** the Mac-side `localhost:8080` is opened by Docker Desktop's own forwarder and carried into the VM; the iptables rules above exist only in the VM. The userland `docker-proxy` is not what serves loopback publishes here (no `docker-proxy` processes in the VM during the lab).

#### D. Network Isolation Is Firewall Rules
Two bridge networks are two separate L2 segments, but the thing that actually keeps them apart is **firewall policy**, not L2 alone: the host namespace *routes* between its bridges, so without rules a container on `frontend-net` could reach one on `backend-net` by IP. Docker closes that with a DROP rule per bridge (`-A DOCKER ! -i br-X -o br-X -j DROP`, the traffic is only allowed in from the same bridge) plus the DNS scoping above. Chain names depend on the engine: Engine 28+ uses `DOCKER-FORWARD` (jump point from `FORWARD`), `DOCKER-CT` (established/related), `DOCKER-BRIDGE`, `DOCKER-INTERNAL` and `DOCKER`; older engines used `DOCKER-ISOLATION-STAGE-1/2`. Rules go in iptables or nftables depending on engine configuration (the VM here uses iptables-nft). Consequences:
- Isolation can be weakened by a user rule or by `docker network connect` (that is how multi-homing works).
- `docker network create --internal` removes the default route/masquerade: no outbound traffic from that network at all. Use it for backend-only networks.
- Kubernetes NetworkPolicy (Day 4) solves the same problem with a different mechanism and a policy API.

#### E. Network Drivers and Modes

| Mode / driver | Flag | Isolation | Use case |
|:---|:---|:---|:---|
| **bridge** (user-defined) | `--network <name>` | netns + veth to a per-network bridge; DNS by name | Standard microservices, Compose default |
| **bridge** (default `docker0`) | none / `--network=bridge` | netns + veth; **no** DNS between containers | Legacy; avoid |
| **host** | `--network=host` | None: shares the engine host's netns | Packet capture, host-level metrics, no NAT |
| **none** | `--network=none` | Only loopback | Offline batch jobs |
| **container** | `--network=container:<name>` | Joins another container's netns | Debug sidecars; the Kubernetes Pod model (all containers of a pod share one netns) |
| **overlay** (a network *driver*: `docker network create -d overlay`) | | VXLAN across hosts, needs Swarm mode | Multi-host; concept only here |
| **macvlan / ipvlan** (drivers) | | Container gets an address on the physical LAN | Legacy appliances needing L2 presence |

**Docker Desktop:** `--network=host` attaches to the **VM's** namespace, not your Mac's. To reach a host-network container's ports from macOS `localhost` you must enable "host networking" in Docker Desktop settings (Resources → Network). Linux engines behave as the table says with no setup.

---

### 2. Volumes & Storage Architecture

Containers are ephemeral: when a container is removed (`docker rm`), its writable overlay `upperdir` is deleted with it.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Container Filesystem                            │
│   /app/server                  (read-only image layers)                │
│   /tmp/scratch.log             (writable layer: copy-on-write)         │
│   /var/lib/postgresql/data ──► [mount in the container's mnt ns]       │
└───────────────────────────────────────────────┬────────────────────────┘
                 ┌──────────────────────────────┼────────────────────────┐
                 ▼                              ▼                        ▼
         [Named volume]                    [Bind mount]               [tmpfs]
 /var/lib/docker/volumes/<name>/_data     a host directory         kernel memory
 (inside the VM on Docker Desktop)        (Mac path via file       gone when the
 survives container removal               sharing on Mac)          container stops
```

#### Storage Types Comparison

| Type | Syntax | Lifecycle | Managed by | Ownership | Best for |
|:---|:---|:---|:---|:---|:---|
| **Named volume** | `-v pgdata:/var/lib/postgresql/data` | Until `docker volume rm` / `down -v` | Docker (`local` driver or plugin) | If empty on first mount, Docker copies the image's content *and ownership* at that path (Postgres data ends up `70:70`) | Databases, stateful stores |
| **Anonymous volume** | declared by `VOLUME` in the image, no `-v` given | Orphaned (dangling) after `docker rm` unless `docker rm -v` | Docker | as above | Accident. `postgres:16` declares `VOLUME /var/lib/postgresql/data`, so `docker run postgres` leaks one per container |
| **Bind mount** | `-v $(pwd)/src:/app/src` | The host directory's | You | **Linux:** numeric UID/GID pass through unchanged (host UID 1000 is UID 1000 in the container). **Docker Desktop (VirtioFS):** ownership is synthesized: a Mac file owned by 504 appears as `root` to a root process and as `1234` to a process running as 1234, and writes succeed either way | Hot-reload source in dev |
| **tmpfs** | `--tmpfs /tmp` or Compose `type: tmpfs` | Container run only | Kernel | n/a | Scratch data, throwaway test databases; keeps writes off disk |

Notes:
- On macOS a named volume's path (`/var/lib/docker/volumes/...`) does **not exist on your Mac**. Inspect it with a helper container: `docker run --rm -v orderflow-pgdata:/data alpine ls -la /data`.
- A bind mount hides whatever the image had at that path. Bind-mounting host `node_modules` or a build cache over a container directory injects host-OS binaries, so mount only source or use a separate named volume for dependency directories.
- Removing a volume deletes its files (the `local` driver removes the directory tree); there is no trash.
- On a shared machine, `docker volume prune` removes *every* dangling volume, not just yours. Remove by name.

---

### 3. Docker Compose Production Patterns

#### A. Dependency Ordering with Healthchecks
`depends_on: [postgres]` waits only until the dependency container has *started*, not until it works. Use `condition: service_healthy`. Who runs the check matters: the **engine** executes the `HEALTHCHECK` (image-defined or Compose-defined) inside the container and records the status; Compose merely reads it. A restart policy does *not* restart an unhealthy container (only an exit); the status only gates `depends_on` and `--wait`.
```yaml
services:
  postgres:
    image: postgres:16-alpine
    healthcheck:
      # -h 127.0.0.1 forces a TCP check. Without it pg_isready uses the unix socket,
      # which the entrypoint's temporary init-phase server already answers: a false "healthy".
      test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 3s
      timeout: 3s
      retries: 5
      start_period: 3s        # failures inside this window don't count against retries

  order-api:
    build: ../shared/order-api
    depends_on:
      postgres:
        condition: service_healthy
```
`$$` escapes Compose interpolation so the *container's* environment is used. The three Go services define their healthcheck once, in the image (`HEALTHCHECK CMD ["/app/server","-healthcheck"]`, no curl in distroless), and Compose inherits it; adding a `healthcheck:` block in Compose overrides the image's. One definition in the Dockerfile keeps `docker run`, Compose and CI identical; override in Compose only to change timing (the test file does).

`docker compose up -d --wait` blocks until every service is running/healthy (exits non-zero on failure), which is how you make a CI step deterministic. In this lab `order-api` does not actually use Postgres (in-memory store), so its Postgres gate is illustrative of the pattern.

#### B. Configuration Layering: Override Files and Merge Rules
- Compose auto-loads `docker-compose.override.yml` **only** when you pass no `-f`/`COMPOSE_FILE` *and* it sits next to `docker-compose.yml`. Once you name files explicitly, only those are loaded, in order, later files winning.
- Merge rules: scalars are replaced; mappings (`environment`, `labels`) merge by key; lists such as `ports` are combined (identical entries are de-duplicated, but the same port written differently, e.g. `8080:8080` in one file and `127.0.0.1:8080:8080` in the other, is added as a second publish: a bind conflict, or an unintended LAN exposure; write each port once, in one file); `volumes` merge by target path; `!reset []` empties an inherited list and `!override` replaces it wholesale.
- Convention used by the lab: the base file is production-parity topology (the only published port is `order-api`, bound to loopback). `docker-compose.override.yml` holds developer ergonomics (other ports, Postgres on host port **15432**, `ENABLE_DEBUG_ALLOC`). `docker-compose.test.yml` is the CI variant used *instead of* the dev override: no host ports, tmpfs Postgres, faster health intervals, and a one-shot `smoke` client.
- Commit all three; CI selects its set with explicit `-f`. A developer override is only a problem when CI would silently pick it up.
- `docker compose config` prints the merged, interpolated result: use it to debug any layering question.

#### C. Environment Precedence
Two different mechanisms with similar names:
1. **Interpolation** (`${VAR:-default}` inside the compose file) is resolved by Compose before anything starts. Precedence, highest first: your shell environment, then `--env-file` / the project's `.env` (read from the directory of the first compose file), then the `:-default`. `.env` is **not** passed into containers. A `.env` in the *current directory* (the course root) is also read and wins per variable over the one in `labs/day02/`, so keep the course root free of a `.env`.
2. **Container environment**: what the process sees. `environment:` wins over `env_file:` entries, which win over variables baked in the image (`ENV`). `env_file` content is *not* used for interpolation.
Keep secrets out of image layers and out of committed files; `.env` stays untracked, `.env.example` is committed.

#### D. Profiles, Aliases, Watch
- **Profiles** (`profiles: ["debug"]`) keep optional services (debug sidecars, one-shot test clients, admin UIs) out of a plain `up`. Start them with `--profile debug` or by naming the service.
- **Network aliases** add DNS names for a service on a network (`aliases: [payments.internal]`), useful for migrating a hostname or for per-network names when a service is on several networks.
- **`docker compose watch`** with `develop.watch` rules (`sync`, `rebuild`, `sync+restart`) rebuilds or syncs on file changes: the inner loop without bind-mounting source into a distroless image. Our `order-api` uses `action: rebuild` on its Go source and on the demo file `labs/day02/watch-trigger` (edit it and the container is recreated).
- `container_name:` (used here to keep names stable for the labs) prevents `--scale`; drop it in real projects unless something needs a fixed name.

#### E. Debugging Distroless Containers
`docker exec <c> sh` fails on distroless (no shell). Options, in order of preference:
1. **Network sidecar:** `docker run --rm -it --network container:<name> nicolaka/netshoot` (or a Compose `network_mode: "service:<svc>"` service behind a profile): same netns, so `ss`, `dig`, `curl localhost:<port>`, `tcpdump` see exactly what the app sees. Add `--pid container:<name>` to see its processes too.
2. **`docker debug <container>`** (Docker Desktop feature; may need you to be signed in): a toolbox shell attached to the container's filesystem and namespaces without changing the image. `docker debug -c 'ls -l /app' <container>` runs one command.
3. `docker cp`, `docker logs`, `docker inspect`, and `docker top` need no shell at all.
(Kubernetes equivalent (Day 7): `kubectl debug --target`.)

---

## Decision tree: Networking & Storage

```
Need inter-container communication?
├── Same host?
│   ├── User-defined bridge network (a named Compose network): default choice
│   ├── Share one netns (debug sidecar, pod-like) ──► --network container:<name>
│   └── Zero NAT / raw interface access ──► host mode (VM's netns on Docker Desktop)
└── Multiple hosts? ──► Overlay driver (Swarm) or a Kubernetes CNI

Must a backend be unreachable from the frontend tier?
└── Separate networks; attach only the service that needs both to both; `--internal` if it needs no egress

Need data persistence?
├── Database or persistent service state ──► Named volume (always declare it; never rely on the image's VOLUME)
├── Live code editing / hot-reload       ──► Bind mount (or `compose watch`)
└── Scratch / throwaway test DB          ──► tmpfs
```

---

## Exercises

### Exercise 1 — Bridge Isolation
You create two user-defined networks: `frontend-net` and `backend-net`. `order-api` is attached only to `frontend-net`, and `database` only to `backend-net`.
Can `order-api` resolve or connect to `database` by name or IP? Why? How do you fix it without putting every service on one network?

**Hint:** Two parts to the barrier: what answers DNS queries, and what the host does with packets routed between two of its bridges.

**Solution sketch:**
1. **No, by both name and IP.** The embedded DNS only answers for networks the asking container is attached to (`NXDOMAIN` for `database`). By IP, the packet reaches the host namespace via the gateway, but the per-bridge `DROP` rule in the `DOCKER` chain (`! -i br-X -o br-X -j DROP`) discards it. It is firewall policy rather than pure L2 separation, since the host can route between its bridges.
2. **Fix: multi-homing.** Attach `order-api` to both networks (`networks: [frontend-net, backend-net]`, or `docker network connect backend-net order-api`). It gets `eth0` and `eth1`, one per network, and resolves `database` over `backend-net`; other frontend services still cannot reach the backend. If the backend needs no internet, make it `internal: true`.

---

### Exercise 2 — Down, Volumes and Images
You run `docker compose down`. Does that delete the database data? The images? What does `docker compose down -v` add? And what does `docker compose down --rmi local` do?

**Hint:** Compose removes what it *created in this run*; volumes and images are separate objects.

**Solution sketch:**
- `down`: stops and removes the **containers and networks**. Named volumes survive. Images survive too (your next `up` does not rebuild).
- `down -v`: also removes the **named volumes declared in `volumes:`** (and anonymous volumes attached to the containers). The database is gone for good; the volume's directory is deleted, not archived.
- `down --rmi local`: also removes images built by Compose that have no custom tag (here `day02-*`); `--rmi all` also removes pulled images such as `postgres:16-alpine`. The lab teardown uses `--rmi local`.
- A plain `docker rm` of a container whose image declares `VOLUME` (Postgres) and that you started without a named volume leaves a dangling anonymous volume behind unless you use `docker rm -v`.

---

### Exercise 3 — The Loopback Trap
An engineer sets `PAYMENT_SERVICE_URL=http://localhost:8081` inside `order-api`. Why does every call fail with `connection refused`, even though `payment-service` is up and published on host port 8081?

**Hint:** Which network namespace does `localhost` resolve in, and what does Docker Desktop's published port actually point at?

**Solution sketch:**
Inside `order-api`'s netns, `127.0.0.1` is that container's own loopback, and nothing listens on 8081 there. Host-published ports are for traffic entering from outside the network; the Mac's `localhost:8081` is a different place entirely. **Fix:** `PAYMENT_SERVICE_URL=http://payment-service:8081`, resolved by the embedded DNS to the container IP over the shared bridge. (The same property is why a sidecar sharing the netns with `--network container:` *can* use `localhost`: that is the Kubernetes Pod model.)

---

### Exercise 4 — Which Value Wins?
`.env` has `POSTGRES_DB=orderflow`. You run `POSTGRES_DB=scratch docker compose up -d`, and `order-api` has `env_file: [app.env]` where `app.env` contains `PORT=9999` while the service's `environment:` sets `PORT: "8080"`. What database name does Postgres get, what port does `order-api` listen on, and does `order-api` see `POSTGRES_DB`?

**Hint:** Separate interpolation (resolved by Compose) from container environment (resolved per service).

**Solution sketch:** Postgres gets `scratch` (shell beats `.env` for interpolation; `.env` beats the `:-default`). `order-api` listens on **8080** (`environment:` beats `env_file:`). It does **not** see `POSTGRES_DB`: `.env` only feeds interpolation unless a service lists it in `environment:`/`env_file:`. Verify with `docker compose config <service>`. (Even with `scratch`, an *existing* `orderflow-pgdata` volume keeps its original database: `POSTGRES_DB` is only used when Postgres initializes an empty data directory.)

---

### Exercise 5 — "I changed the env var and restarted"
You change an environment value for `order-api` in the compose file (or the shell) and run `docker compose restart order-api`. Nothing changes. Why, and what is the right command?

**Hint:** What does `restart` reuse?

**Solution sketch:** `restart` stops and starts the *existing container*, whose configuration (env, ports, mounts) was fixed at creation. `docker compose up -d order-api` compares the desired config with the container's recorded config hash and **recreates** the container when it differs. Rule: config change → `up -d <service>`; same config, just bounce the process → `restart`.

---

## Anti-patterns / Common mistakes

1. **Using legacy `--link` / `links:`:** deprecated; writes IPs into `/etc/hosts` at start and goes stale. User-defined networks give DNS for free.
2. **`depends_on` without a health condition:** the dependent starts the instant the container process does, and crashes or flaps until the dependency is ready. Pair it with a real healthcheck, and use `up --wait` in CI.
3. **Healthchecks that lie:** `pg_isready` over the unix socket during init, a check that starts a second server on the same port, or a check against `/ready` that can fail for reasons unrelated to liveness.
4. **Hardcoding container IPs:** IPs are assigned by IPAM and change on recreation. Use service names; pin the *subnet* only when something external (a firewall rule, a doc) cites it.
5. **Publishing every port to all interfaces:** `-p 5432:5432` exposes your dev database to the LAN. Bind to `127.0.0.1`, use a non-default host port (the lab uses 15432), and publish only what a human or external client needs.
6. **Bind-mounting `node_modules` or build caches** over container directories (host binaries in a Linux container).
7. **No named volume for databases:** data lives in the writable layer or an anonymous volume and disappears (or orphans) with the container.
8. **`docker volume prune` / `system prune --volumes` on a shared machine:** deletes other projects' dangling volumes.
9. **Debugging by baking a shell into the production image:** use a network sidecar or `docker debug`.

---

## Recall drill

Answer from memory first, then open the answers.

1. What is on the other end of a container's `eth0@if183`, and what is it attached to?
2. Nothing "listens" on `127.0.0.11` in the usual sense. What actually answers a DNS query sent there?
3. Two containers on different user-defined bridges cannot ping each other. What blocks them, and why is it not simply "different L2 segments"?
4. A container reaches another on the same bridge by service name. Does the traffic pass through DNAT or the published ports?
5. `postgres` shows `healthy` in Compose before it accepts TCP connections. Most likely cause?
6. You edit an env var and run `docker compose restart svc`; nothing changes. Why?
7. `docker compose down` vs `down -v` vs `down --rmi local`: what does each remove?
8. On Docker Desktop, why does `ls /var/lib/docker/volumes` on your Mac fail, and how do you look inside a volume?

<details>
<summary>Answers</summary>

1. The host-side veth, interface index 183 in the engine host's namespace (the VM on Docker Desktop), enslaved to the network's Linux bridge (`br-<id>` or `docker0`).
2. A resolver that dockerd runs inside the container's netns. iptables DNAT rules in that netns (`DOCKER_OUTPUT`) redirect `127.0.0.11:53` to its ephemeral port; unknown names are forwarded to the host's DNS.
3. Firewall rules in the host namespace: a per-bridge `! -i br-X -o br-X -j DROP` in the `DOCKER` chain (Engine 28+ also has `DOCKER-FORWARD`/`DOCKER-BRIDGE`). The host routes between its bridges, so without the rule traffic would pass. DNS is also scoped per network.
4. No. It is direct container IP to container IP across the bridge; DNAT/published ports only apply to traffic entering from outside (tcpdump shows `172.28.0.5 > 172.28.0.2:8081`).
5. `pg_isready` checked the unix socket, which the entrypoint's temporary init server answers. Add `-h 127.0.0.1` to force TCP.
6. `restart` reuses the existing container with its creation-time config. `docker compose up -d svc` recreates it when the config changed.
7. `down`: containers and networks. `-v`: also the declared named volumes (data loss) and anonymous volumes. `--rmi local`: also untagged locally built images. Plain `down` never removes images or volumes.
8. Docker's volume store is inside the Docker Desktop VM, not on the Mac. Mount the volume into a helper: `docker run --rm -v <vol>:/data alpine ls -la /data`.

</details>

---

## Lab
See [`labs/day02/`](../labs/day02/). Run commands from the course root `k8s_docker_mastery/`.
- **The goal:** Run the OrderFlow stack (order-api, payment-service, notification-service, Postgres) in Compose with healthcheck gates, a pinned bridge network, a named volume and a dev override; inspect the veth/bridge/iptables/DNS internals with netshoot; break DNS and the volume on purpose; try profiles, env precedence, aliases, `compose watch`, a CI test override and distroless debugging.
- **Success signal:** `docker compose up -d --wait` leaves all 4 containers `(healthy)` in dependency order, `POST /orders` returns 201 and both downstream services log it, `dig payment-service` inside `order-api`'s netns returns the container IP via `127.0.0.11`, data survives `down` but not `down -v`, and the test stack passes its smoke client with no published ports.

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `docker network inspect <net> -f '{{json .IPAM.Config}}'` | Subnet, gateway |
| `docker run --rm --net=host --privileged nicolaka/netshoot ip -br link` / `bridge link` | Interfaces, bridges, veth attachment (engine host netns; the VM on Docker Desktop) |
| `docker run --rm --net=host --privileged nicolaka/netshoot iptables -t nat -S` | DNAT / MASQUERADE rules |
| `docker run --rm --network container:<c> nicolaka/netshoot dig <name>` | See DNS exactly as container `<c>` does |
| `docker volume inspect <vol>` | Volume mountpoint (inside the VM) |
| `docker run --rm -v <vol>:/data alpine ls -la /data` | Look inside a volume |
| `docker compose up -d --build --wait` | Build, start, block until healthy |
| `docker compose up -d <svc>` | Apply a config change (recreates only what changed) |
| `docker compose config [svc]` | Show merged + interpolated config |
| `docker compose --profile debug up -d netshoot` | Start a profile-gated service |
| `docker compose watch` | Rebuild/sync on source change (`develop.watch`) |
| `docker compose down [-v] [--rmi local]` | Remove containers+networks [+ volumes] [+ built images] |
| `docker debug <container>` | Toolbox shell for shell-less containers (Docker Desktop) |

---

## Teardown
Run from the course root `k8s_docker_mastery/` (the same commands as the lab README):
```bash
export COMPOSE_FILE=labs/day02/docker-compose.yml:labs/day02/docker-compose.override.yml
docker compose --profile '*' down -v --rmi local --remove-orphans
unset COMPOSE_FILE
rm -f labs/day02/.env
[ -f /tmp/d2-main.go.orig ] && cp /tmp/d2-main.go.orig labs/shared/order-api/main.go && rm -f /tmp/d2-main.go.orig || true
rm -f labs/day02/alt.env labs/day02/demo.env
find labs/shared/order-api -name '*.bak' -delete
printf 'v2\n' > labs/day02/watch-trigger
docker rm -f d2-fe d2-db d2-anon 2>/dev/null || true
docker network rm frontend-net backend-net 2>/dev/null || true
```
`--profile '*'` also removes the profile-gated debug/test containers. The optional helper images stay in your cache; remove with `docker rmi nicolaka/netshoot curlimages/curl` if you want them gone.
