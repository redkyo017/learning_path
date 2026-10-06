# Day 2 Lab: Docker Networking, Storage Volumes & Compose Orchestration

**Run every command from the course root** (`k8s_docker_mastery/`). Day 2 uses the Docker engine only, no Kubernetes. Mac-specific notes assume Docker Desktop on Apple Silicon (bridges, veths, iptables and volumes all live in its Linux VM).

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`. Check `docker version` works and ports 8080, 8081, 8082 and 15432 are free (`lsof -i :8080 -i :8081 -i :8082 -i :15432` prints nothing).
2. Copy `labs/day02/.env.example` to `labs/day02/.env` and set `COMPOSE_FILE` (Step 1) so every `docker compose` command uses the base file plus the dev override. Keep the course root free of a `.env` of its own: a `.env` in the current directory is also read and wins per variable over `labs/day02/.env`.
3. Start the stack with `docker compose up -d --build --wait`. It builds 3 images, starts Postgres first, then the Go services, then `order-api`. You are done with this step when `docker compose ps` shows all 4 containers `(healthy)`.
4. Create an order with `curl`, then read the logs of `payment-service` and `notification-service`: both should log the order ID that `order-api` sent over the bridge network.
5. Look at the plumbing with `nicolaka/netshoot`: the veth/bridge/iptables rules in the VM, then DNS (`127.0.0.11`) from inside `order-api`'s own network namespace.
6. Prove the volume holds data across `docker compose down`, then break DNS (bad service URL) and the volume (`down -v`) on purpose.
7. Try the Compose features: profiles, env precedence, aliases, `compose watch`, the dev vs test override, and debugging a distroless container.
8. You are done when each step's "You should see" line matched. Run **Teardown** at the end.

## Objective
Deploy the 4-service OrderFlow stack (Order API, Payment Service, Notification Service, PostgreSQL) with Docker Compose, then inspect what Docker built for you (veth pairs, bridge, DNAT/MASQUERADE rules, the embedded DNS resolver, the volume store) and learn the Compose patterns that make a local stack deterministic. `order-api` keeps orders in memory and does **not** use Postgres: Postgres is here to practise volumes, healthcheck gating and port publishing.

---

## Architecture Diagram

```
        Mac: localhost:8080 / 8081 / 8082 / 15432  (loopback only)
                     │  Docker Desktop forwarder → VM
                     ▼
   VM nat table: DNAT 127.0.0.1:<port> → container IP:<port>
                     │
   ┌─ bridge br-<id> = network "orderflow-network" 172.28.0.0/24 (gw .1) ─────────┐
   │  Embedded DNS 127.0.0.11 (per-container netns)                               │
   │                                                                              │
   │ [order-api :8080] ──HTTP──► [payment-service :8081] (alias payments.internal)│
   │        │ └─────────HTTP──► [notification-service :8082]                      │
   │        └ gated on:                  [postgres :5432] ── volume orderflow-pgdata
   │          all three service_healthy                       /var/lib/postgresql/data
   └──────────────────────────────────────────────────────────────────────────────┘
   debug profile: [netshoot] shares order-api's netns (network_mode: service:order-api)
```

Files: `docker-compose.yml` (base), `docker-compose.override.yml` (dev: extra ports, 15432, debug alloc), `docker-compose.test.yml` (CI variant), `.env.example`.

---

## Instructions

### Step 1: Configure and Start the Stack
```bash
cp labs/day02/.env.example labs/day02/.env
export COMPOSE_FILE=labs/day02/docker-compose.yml:labs/day02/docker-compose.override.yml
docker compose up -d --build --wait
docker compose ps
```
How the files are selected: Compose auto-loads `docker-compose.override.yml` only when you pass no `-f`/`COMPOSE_FILE` *and* it sits next to the base file. We run from the course root, so we name both files in `COMPOSE_FILE` (colon-separated). The project directory, and therefore the `.env` file and the `../shared/...` build contexts, resolve relative to the first file (`labs/day02/`). The `export` lasts for this terminal only: set it again in any new one (or pass `-f labs/day02/docker-compose.yml -f labs/day02/docker-compose.override.yml` each time). The project name is pinned to `day02`, so images are `day02-order-api`, `day02-payment-service`, `day02-notification-service`.

*You should see: the `--wait` output ends with all four containers `Healthy`, and `docker compose ps` lists 4 containers `Up ... (healthy)` with ports `127.0.0.1:8080->8080`, `8081`, `8082` and `127.0.0.1:15432->5432`. Startup takes about 10 s.* The three Go services inherit the image's `HEALTHCHECK` (`/app/server -healthcheck`); Postgres has its own check in the compose file.

### Step 2: Verify End-to-End API Integration
```bash
curl -i -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"Mechanical Keyboard","qty":2}'
curl -s http://localhost:8080/orders; echo
docker compose logs --no-log-prefix payment-service notification-service | tail -4
docker inspect -f '{{.State.Health.Status}} {{.Config.Healthcheck.Test}}' orderflow-order-api
docker exec orderflow-order-api sh      # fails on purpose: distroless has no shell
```
*You should see: `HTTP/1.1 201 Created` with an order JSON (status `PENDING`), the same ID in the payment and notification logs, `healthy [CMD /app/server -healthcheck]`, and `exec: "sh": executable file not found`.*

### Step 3: Bridge Network and DNS from Inside a Container
```bash
docker network inspect orderflow-network -f '{{json .IPAM.Config}}'
docker network inspect orderflow-network -f '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
```
Now enter `order-api`'s network namespace with a tool container (`--network container:` = same netns, so these commands see what `order-api` sees):
```bash
docker run --rm --network container:orderflow-order-api nicolaka/netshoot sh -c '
  cat /etc/resolv.conf; ip -br addr show eth0; ss -ltn
  dig +short payment-service; dig +short payments.internal; dig nonexistent-payment | grep status'
docker run --rm --cap-add NET_ADMIN --network container:orderflow-order-api nicolaka/netshoot iptables -t nat -S
```
*You should see: subnet `172.28.0.0/24` gateway `172.28.0.1` and four IPs on it; `nameserver 127.0.0.11` and `options ndots:0`; `eth0@ifNNN ... 172.28.0.x/24`; `ss` showing a listener on `127.0.0.11:<port>` and `*:8080`; both `payment-service` and the alias `payments.internal` resolving to the same IP; `status: NXDOMAIN` for the bad name; and `DOCKER_OUTPUT` DNAT rules sending `127.0.0.11:53` to that ephemeral port (that is the whole "DNS server": dockerd's resolver, reached through the container's own netns).*

### Step 4: The Engine's Side: veth, Bridge, NAT, Isolation Rules
`--net=host --privileged` puts the tool container in the **engine host's** network namespace (the Docker Desktop VM on a Mac):
```bash
n() { docker run --rm --net=host --privileged nicolaka/netshoot "$@"; }   # works in zsh and bash
n ip -br addr | grep -E 'br-|docker0'          # one bridge per network; ours is 172.28.0.1/24
n bridge link | tail -4          # each vethXXXX with `master br-<id>`
n iptables -t nat -S | grep -E '172.28|dport (8080|15432)'      # DNAT + MASQUERADE
n iptables -S DOCKER | grep -E '172.28|DROP' | head -8           # filter: per-network isolation
n iptables -S | grep -E 'DOCKER-(FORWARD|BRIDGE|CT)'            # Engine 28+ chains
```
*You should see: the veths enslaved to the `br-<id>` bridge whose address is `172.28.0.1/24` (the index of each `vethXXXX` equals the `@ifNNN` of a container's `eth0`); `-A DOCKER -d 127.0.0.1/32 -p tcp --dport 8080 -j DNAT --to-destination 172.28.0.5:8080` and `-A POSTROUTING -s 172.28.0.0/24 ! -o br-... -j MASQUERADE`; filter rules `! -i br-... -o br-... -j DROP` (one per bridge).* If `iptables` prints nothing useful, try `n nft list ruleset` (this VM's iptables is the nft backend).

Container-to-container traffic is not NATed. Watch it from the netns of `order-api`:
```bash
docker run --rm --network container:orderflow-order-api nicolaka/netshoot sh -c '
  tcpdump -nn -i eth0 -c 4 "tcp port 8081" & sleep 1
  curl -s -X POST localhost:8080/orders -H "Content-Type: application/json" -d "{\"item\":\"x\",\"qty\":1}" >/dev/null; wait'
```
*You should see: `172.28.0.5.<port> > 172.28.0.2.8081` SYN / SYN-ACK: plain container IP to container IP.*

Isolation: a container on a *different* network cannot reach an unpublished port or ping into ours, and DNS is scoped per network. Then multi-home it:
```bash
OA=$(docker inspect -f '{{(index .NetworkSettings.Networks "orderflow-network").IPAddress}}' orderflow-order-api)
docker run --rm alpine ping -c1 -W2 $OA; echo "exit $?"                 # dropped by the DOCKER chain
docker network create frontend-net; docker network create backend-net
docker run -d --name d2-fe --network frontend-net alpine sleep 300
docker run -d --name d2-db --network backend-net alpine sleep 300
docker exec d2-fe nslookup d2-db | tail -2                                      # NXDOMAIN
docker exec d2-fe ping -c1 -W2 $(docker inspect d2-db -f '{{(index .NetworkSettings.Networks "backend-net").IPAddress}}')
docker network connect backend-net d2-fe
docker exec d2-fe ping -c1 d2-db | tail -2                                      # now works: d2-fe has eth0 and eth1
docker exec d2-fe getent hosts d2-db
docker rm -f d2-fe d2-db; docker network rm frontend-net backend-net
```
*You should see: ping `100% packet loss` (exit 1) to our container, `NXDOMAIN` and 100% loss for the isolated pair, then `0% packet loss` and a name resolving after `docker network connect`.*

(Done with the helper: `unset -f n`.)

### Step 5: Volumes: Inspect and Prove Persistence
```bash
docker volume inspect orderflow-pgdata -f '{{.Mountpoint}}'
ls /var/lib/docker/volumes 2>&1 | head -1            # not on your Mac: it is inside the VM
docker run --rm -v orderflow-pgdata:/data alpine ls -la /data | head -6
docker run --rm -v orderflow-pgdata:/data alpine stat -c '%u:%g %n' /data/PG_VERSION
```
Populate a table, recreate the containers, and check:
```bash
docker exec orderflow-postgres psql -U orderflow -d orderflow -c "CREATE TABLE test_data (id serial PRIMARY KEY, note text); INSERT INTO test_data (note) VALUES ('persistence_verified');"
docker compose down
docker volume ls -f name=orderflow-pgdata; docker images 'day02-*' --format '{{.Repository}}'
docker compose up -d --wait
docker exec orderflow-postgres psql -U orderflow -d orderflow -c "SELECT * FROM test_data;"
nc -vz 127.0.0.1 15432           # the dev override published Postgres on host port 15432
```
*You should see: a mountpoint under `/var/lib/docker/volumes/orderflow-pgdata/_data` that `ls` cannot find on the Mac; Postgres files owned `70:70` (copied from the image on first mount); after `down` the volume **and the `day02-*` images are still there** (`down` removes containers and networks only); the row `persistence_verified` after `up`; `succeeded` for port 15432.*

Two more storage facts, quickly:
```bash
# (a) The postgres image declares VOLUME, so without a named volume you leak an anonymous one:
docker run -d --name d2-anon -e POSTGRES_PASSWORD=x postgres:16-alpine
docker inspect d2-anon -f '{{range .Mounts}}{{.Type}} {{.Name}}{{end}}'
V=$(docker inspect d2-anon -f '{{range .Mounts}}{{.Name}}{{end}}')
docker rm -f d2-anon; docker volume ls -qf dangling=true | grep -c "$V"      # 1: orphaned
docker volume rm "$V"                                                       # remove by name; never prune on a shared machine
# (b) Bind-mount ownership on Docker Desktop is synthesized:
mkdir -p /tmp/d2-bind && echo hi > /tmp/d2-bind/f; ls -ln /tmp/d2-bind/f
docker run --rm -v /tmp/d2-bind:/b alpine ls -ln /b/f
docker run --rm -u 1234 -v /tmp/d2-bind:/b alpine sh -c 'echo x > /b/g; ls -ln /b'
ls -ln /tmp/d2-bind; rm -r /tmp/d2-bind
```
*You should see: `volume <64-hex-name>` then `1`; the Mac file owned by your UID (e.g. 504) appears as `0` for root and as `1234` for the `-u 1234` process, and that write succeeds. On a Linux engine the numeric owner would pass through unchanged.*

### Step 6: BREAK IT — DNS Resolution Failure
`order-api`'s `PAYMENT_SERVICE_URL` can be overridden from the shell (`${PAYMENT_SERVICE_URL:-http://payment-service:8081}` in the compose file), so no file edit is needed:
```bash
PAYMENT_SERVICE_URL=http://nonexistent-payment:8081 docker compose restart order-api
docker inspect orderflow-order-api -f '{{range .Config.Env}}{{println .}}{{end}}' | grep PAYMENT   # unchanged!
PAYMENT_SERVICE_URL=http://nonexistent-payment:8081 docker compose up -d --wait order-api
curl -s -X POST http://localhost:8080/orders -H "Content-Type: application/json" -d '{"item":"Mouse","qty":1}'; echo
sleep 1; docker compose logs --no-log-prefix order-api | tail -2
docker compose up -d --wait order-api        # restore: the shell variable is gone, config differs again, so it is recreated
```
*You should see: after `restart` the env var still points at `payment-service` (restart reuses the container's creation-time config); after `up -d` it points at `nonexistent-payment`. The POST still returns `201` (the downstream call is fire-and-forget) but the log says `lookup nonexistent-payment on 127.0.0.11:53: no such host`. The failure is only visible in logs.*

### Step 7: BREAK IT — Volume Deletion Loss
```bash
docker compose down -v
docker volume ls -qf name=orderflow-pgdata | wc -l       # 0
docker compose up -d --wait
docker exec orderflow-postgres psql -U orderflow -d orderflow -c "SELECT * FROM test_data;"
```
*You should see: `ERROR:  relation "test_data" does not exist`. `-v` deleted the named volume, and the new Postgres initialized an empty cluster.*

### Step 8: Compose Features: Profiles, Env Precedence, Watch
**Profiles and the debug sidecar.** `netshoot` is declared with `profiles: ["debug"]` and `network_mode: "service:order-api"`:
```bash
docker compose config --services                  # no netshoot
docker compose --profile debug config --services  # now includes netshoot
docker compose --profile debug up -d netshoot
docker compose exec netshoot sh -c 'ss -ltn; curl -s localhost:8080/health; echo; curl -s payment-service:8081/health; echo'
docker compose rm -sf netshoot
```
*You should see: `netshoot` absent from the plain `config --services` list and present with `--profile debug`; inside it, `localhost:8080` answers (it shares `order-api`'s netns, like a Kubernetes sidecar) and `payment-service` resolves.*

**Env precedence.** Interpolation (shell > `--env-file`/`.env` > `:-default`) is separate from container environment (`environment:` > `env_file:`):
```bash
F=labs/day02/docker-compose.yml
docker compose -f $F config postgres | grep 'POSTGRES_DB:'
echo POSTGRES_DB=from_envfile > labs/day02/alt.env
docker compose -f $F --env-file labs/day02/alt.env config postgres | grep 'POSTGRES_DB:'
POSTGRES_DB=from_shell docker compose -f $F --env-file labs/day02/alt.env config postgres | grep 'POSTGRES_DB:'
rm labs/day02/alt.env
printf 'PORT=9999\nDRAIN_DELAY_SECONDS=2\n' > labs/day02/demo.env
printf 'services:\n  order-api:\n    env_file: [demo.env]\n' | docker compose -f $F -f - config order-api | grep -A5 'DRAIN_DELAY'
rm labs/day02/demo.env
```
*You should see: `orderflow`, then `from_envfile`, then `from_shell`; and for `order-api`: `DRAIN_DELAY_SECONDS: "2"` added from the env_file while `PORT` stays `"8080"` (`environment:` beats `env_file:`), and no `POSTGRES_*` variables (`.env` is not passed into containers).*

**`compose watch`.** `order-api` has two `develop.watch` rules with `action: rebuild`: one on its Go source and one on the demo file `labs/day02/watch-trigger`. Edit the trigger file and watch the container get replaced:
```bash
docker inspect -f '{{.Id}}' orderflow-order-api | cut -c1-12          # note the container ID
docker compose watch --no-up & W=$!                                   # drop --no-up to also (re)start the stack
sleep 3
echo "v2 $(date +%s)" > labs/day02/watch-trigger
sleep 15
docker inspect -f '{{.Id}}' orderflow-order-api | cut -c1-12          # a different ID
kill $W
```
*You should see: `Watch enabled`, then `Rebuilding service(s) ["order-api"] after changes were detected...`, `Image day02-order-api Built`, `Container orderflow-order-api Recreated`, and a new container ID.* Compose rebuilds (a cache hit when nothing in the image changed) and recreates the container on every trigger.

*Optional: see your own code change live.* This edits a shared source file, so it keeps the original in `/tmp` and restores it (Teardown restores it too if you get interrupted). No `.bak` file is created in the build context:
```bash
cp labs/shared/order-api/main.go /tmp/d2-main.go.orig
docker compose watch --no-up & W=$!
sleep 3
sed 's#{"status":"ok","service":"order-api"}#{"status":"ok","service":"order-api","v":2}#' /tmp/d2-main.go.orig > labs/shared/order-api/main.go
sleep 25; curl -s localhost:8080/health; echo        # shows "v":2 after the automatic rebuild
kill $W
cp /tmp/d2-main.go.orig labs/shared/order-api/main.go && rm -f /tmp/d2-main.go.orig
docker compose up -d --build --wait order-api        # rebuild from the restored source
curl -s localhost:8080/health; echo                  # original body again
```

### Step 9: Dev vs Test Override
Stop the dev stack, then bring up the CI variant (explicit `-f` list, no dev override):
```bash
docker compose down
t() { docker compose -f labs/day02/docker-compose.yml -f labs/day02/docker-compose.test.yml "$@"; }
t up -d --build --wait
t ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
t --profile test run --rm smoke
docker inspect orderflow-postgres -f '{{json .Mounts}}'
t down
unset -f t
```
*You should see: all containers `(healthy)` after ~5 s with **no host ports** (`8080/tcp` only, no `127.0.0.1:...`), the `smoke` client printing an order JSON (`201` path, `curl -f`) and `{"status":"ready","service":"order-api"}`, Postgres mounted as `"Type":"tmpfs"` (the dev stack's `orderflow-pgdata` volume is not used).* Compare with `docker compose config` in dev mode to see exactly what the test file removes (`ports: !reset []`) and replaces (volume → tmpfs, healthcheck timing).

### Step 10: Debugging a Distroless Container
`docker exec ... sh` failed in Step 2. Three tools that work (start the dev stack first: `docker compose up -d --wait`):
```bash
docker run --rm -it --network container:orderflow-order-api nicolaka/netshoot ss -ltnp   # same netns, full toolbox
docker run --rm --pid container:orderflow-order-api alpine ps                            # same PID namespace
docker debug -c 'ls -l /app; cat /proc/1/cmdline | tr "\0" " "; echo' orderflow-order-api
```
*You should see: `*:8080` listening in the netns; `/app/server` as PID 1 in the PID-namespace view; and `docker debug` listing `/app/server` (Docker Desktop feature, first run pulls a helper image; it may ask you to sign in).* The Kubernetes equivalent comes on Day 7 (`kubectl debug --target`).

---

## Stuck? Hints

- **`bind: address already in use` / `port is already allocated` on 8080, 8081, 8082 or 15432.** Something else holds the port (a leftover container or a local service). `lsof -i :8080`, `docker ps`, then stop that. Postgres is deliberately on **15432**, not 5432.
- **`no configuration file provided: not found`, or `up` ignores the override (ports missing).** `COMPOSE_FILE` is only set in the terminal where you exported it. Re-run the `export`, or use explicit `-f labs/day02/docker-compose.yml -f labs/day02/docker-compose.override.yml`. Also: after changing an env var, `docker compose restart` does nothing, use `docker compose up -d <svc>` (Step 6).
- **`Container name "/orderflow-..." is already in use`, or `Pool overlaps with other one on this address space`.** A previous stack (or a test/dev mix-up) is still around: run the Teardown, or `docker compose down` with the *same* file set you started with. If another network already uses `172.28.0.0/24`, change the subnet in `docker-compose.yml` (and the IPs you compare against).
- **`up --wait` fails with `container ... is unhealthy` or hangs.** `docker inspect -f '{{json .State.Health}}' <container>` shows the last probe output. The Go services are probed with `/app/server -healthcheck` (GET `127.0.0.1:$PORT/health`): a wrong `PORT` makes the service exit at startup (`invalid PORT`), see `docker compose logs <svc>`. For Postgres, a `-h` typo or wrong `POSTGRES_USER` in `.env` breaks `pg_isready`.
- **netshoot shows no iptables rules, `Permission denied`, or an empty list.** You need `--privileged` (or `--cap-add NET_ADMIN` for a container's own netns) and, for the engine's rules, `--net=host`. On Docker Desktop that namespace is the VM's, not your Mac's. If `iptables` is empty try `nft list ruleset`.
- **`compose watch` does nothing after an edit, or a step was interrupted.** Run it with the same `COMPOSE_FILE`, from the course root; it only watches services with `develop.watch`. If you interrupted the optional `main.go` edit, the Teardown block restores it from `/tmp/d2-main.go.orig`; check `labs/shared/order-api/` has no `*.bak`.

---

## Teardown
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
`--profile '*'` also removes the profile-gated debug/test containers; `--rmi local` removes the `day02-*` images built here. Pulled helper images (`nicolaka/netshoot`, `curlimages/curl`) stay in your cache; remove with `docker rmi nicolaka/netshoot curlimages/curl` if you want them gone.
