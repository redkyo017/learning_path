# Day 2 Lab: Solution & Explanations

Outputs below come from a live run (Docker Desktop, Engine 29.8, Compose v5.5.1, Apple Silicon). IDs, timestamps and the exact IP order vary per run; the subnet (`172.28.0.0/24`) and ports do not. Commands run from the course root with:
```bash
export COMPOSE_FILE=labs/day02/docker-compose.yml:labs/day02/docker-compose.override.yml
```

## Detailed Step-by-Step Walkthrough

### 1. Startup and Healthcheck Gating
```bash
docker compose up -d --build --wait
docker compose ps
```
`--wait` output ends (trimmed):
```text
 Container orderflow-postgres Healthy
 Container orderflow-payment Healthy
 Container orderflow-notification Healthy
 Container orderflow-order-api Healthy
```
```text
NAME                     IMAGE                        COMMAND                  SERVICE                CREATED         STATUS                   PORTS
orderflow-notification   day02-notification-service   "/app/server"            notification-service   6 seconds ago   Up 6 seconds (healthy)   127.0.0.1:8082->8082/tcp
orderflow-order-api      day02-order-api              "/app/server"            order-api              6 seconds ago   Up 3 seconds (healthy)   127.0.0.1:8080->8080/tcp
orderflow-payment        day02-payment-service        "/app/server"            payment-service        6 seconds ago   Up 6 seconds (healthy)   127.0.0.1:8081->8081/tcp
orderflow-postgres       postgres:16-alpine           "docker-entrypoint.s…"   postgres               6 seconds ago   Up 6 seconds (healthy)   127.0.0.1:15432->5432/tcp
```
Note `order-api` is created last and shows the youngest "Up": it only starts after Postgres, payment and notification are `healthy`.

#### Why the original healthcheck was permanently unhealthy
The old compose file ran `/app/server --check`. That flag did not exist, so the binary ignored it and tried to start a **second HTTP server** on the already-bound port, exited with `EADDRINUSE`, and the probe failed forever. The images now implement `/app/server -healthcheck` (GET `127.0.0.1:$PORT/health`, exit 0 on 200, 1 otherwise, 2 s timeout) and declare it as the Dockerfile `HEALTHCHECK`. We chose to **inherit** it in Compose rather than repeat it: one definition keeps `docker run`, Compose and CI identical. `docker inspect` confirms Compose is using the image's check:
```text
$ docker inspect -f '{{.State.Health.Status}} {{.Config.Healthcheck.Test}}' orderflow-order-api
healthy [CMD /app/server -healthcheck]
```
`docker-compose.test.yml` shows the override form (same command, faster `interval`).

#### Why gates and `-h 127.0.0.1` matter
- `depends_on: [postgres]` alone releases dependents when the container process *starts*. With `condition: service_healthy` Compose waits for the engine to record a passing healthcheck. (The engine runs the probe; Compose just reads the state. A restart policy does not restart an unhealthy container.) `order-api` does not actually use Postgres in this course; the gate illustrates the pattern.
- The Postgres entrypoint first runs a temporary server on a **unix socket only** for init scripts. `pg_isready` without `-h` checks that socket and reports ready too early; `-h 127.0.0.1` forces TCP, which only the final server opens.
- `$$POSTGRES_USER` (double dollar) defers expansion to the container's own environment instead of Compose's interpolation.

---

### 2. End-to-End Request
```text
$ curl -i -X POST http://localhost:8080/orders -H "Content-Type: application/json" -d '{"item":"Mechanical Keyboard","qty":2}'
HTTP/1.1 201 Created
Content-Type: application/json
...
{"id":"0c7e2f838468e87f","item":"Mechanical Keyboard","qty":2,"status":"PENDING","created_at":"2026-10-06T13:46:37.965910251Z"}

$ docker compose logs --no-log-prefix payment-service notification-service | tail -4
... [payment-service] processing payment for order: 0c7e2f838468e87f, amount: $29.99
... [notification-service] dispatching notification for order 0c7e2f838468e87f: Order 0c7e2f838468e87f registered

$ docker exec orderflow-order-api sh
OCI runtime exec failed: ... exec: "sh": executable file not found in $PATH
```
The downstream calls are fire-and-forget goroutines in `order-api`, so the 201 does not prove they worked: the payment and notification logs do.

---

### 3. Bridge Network and DNS (inside `order-api`'s netns)
```text
$ docker network inspect orderflow-network -f '{{json .IPAM.Config}}'
[{"Subnet":"172.28.0.0/24","Gateway":"172.28.0.1"}]
orderflow-payment 172.28.0.2/24
orderflow-notification 172.28.0.3/24
orderflow-postgres 172.28.0.4/24
orderflow-order-api 172.28.0.5/24
```
The subnet is pinned in the compose file (`ipam.config`), so the addresses in docs are stable (the assignment order within it is not guaranteed).
```text
$ docker run --rm --network container:orderflow-order-api nicolaka/netshoot sh -c '...'
nameserver 127.0.0.11
options ndots:0
# ExtServers: [host(192.168.65.7)]
eth0@if315       UP             172.28.0.5/24
LISTEN 0 4096      127.0.0.11:44067      0.0.0.0:*
LISTEN 0 4096               *:8080             *:*
172.28.0.2                      <- dig +short payment-service
172.28.0.2                      <- dig +short payments.internal  (network alias)
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN ...   <- dig nonexistent-payment
```
```text
$ docker run --rm --cap-add NET_ADMIN --network container:orderflow-order-api nicolaka/netshoot iptables -t nat -S
-A OUTPUT -d 127.0.0.11/32 -j DOCKER_OUTPUT
-A DOCKER_OUTPUT -d 127.0.0.11/32 -p tcp -m tcp --dport 53 -j DNAT --to-destination 127.0.0.11:44067
-A DOCKER_OUTPUT -d 127.0.0.11/32 -p udp -m udp --dport 53 -j DNAT --to-destination 127.0.0.11:49550
-A DOCKER_POSTROUTING -s 127.0.0.11/32 -p udp -m udp --sport 49550 -j SNAT --to-source :53
```
This is how `127.0.0.11` works: dockerd runs a resolver *in the container's netns*, bound to ephemeral ports (`ss` shows the TCP one), and these rules make it answer on the well-known `127.0.0.11:53`. It answers for service names, container names and aliases of networks this container is on; everything else is forwarded to the host's resolver (`ExtServers`). When `order-api` calls `http://payment-service:8081`: Go's resolver queries `127.0.0.11:53` → answer `172.28.0.2` → TCP connect straight to `172.28.0.2:8081` across the bridge, no DNAT, no masquerade.

---

### 4. The Engine's Side (the VM's namespace)
`--net=host --privileged` shares the **VM's** network namespace. Output is filtered to our network; the VM also holds other bridges (default `docker0`, kind, other projects).
```text
br-5340d2f09db7  UP   172.28.0.1/24 ...            <- our bridge (name = br- + first 12 chars of the network ID)

$ bridge link | tail -4
312: veth55dffd1@...  master br-5340d2f09db7 state forwarding
313: veth6b4d8d1@...  master br-5340d2f09db7 state forwarding
314: veth1b8eff0@...  master br-5340d2f09db7 state forwarding
315: vethee75cb4@...  master br-5340d2f09db7 state forwarding
```
Four veth ends are the four containers' cable ends. `order-api`'s `eth0@if315` in Section 3 is the other end of interface `315` (`vethee75cb4`): that is how you pair them.
```text
$ iptables -t nat -S | grep -E '172.28|dport (8080|15432)'
-A POSTROUTING -s 172.28.0.0/24 ! -o br-5340d2f09db7 -j MASQUERADE
-A POSTROUTING -s 172.28.0.5/32 -d 172.28.0.5/32 -p tcp -m tcp --dport 8080 -j MASQUERADE
-A DOCKER -d 127.0.0.1/32 -p tcp -m tcp --dport 8080 -j DNAT --to-destination 172.28.0.5:8080
-A DOCKER -d 127.0.0.1/32 -p tcp -m tcp --dport 15432 -j DNAT --to-destination 172.28.0.4:5432
```
- DNAT is matched on destination `127.0.0.1` because we published `127.0.0.1:8080:8080`; `-p 8080:8080` would drop the `-d` match and listen on every interface. 15432 on the host maps to 5432 in the container.
- The MASQUERADE for `172.28.0.0/24 ! -o br-...` is the outbound NAT for traffic leaving the bridge. The per-container `-s X -d X` masquerade handles hairpin (a container reaching its own published port via the host).
- Docker Desktop: your Mac's `localhost:8080` is opened by Docker Desktop's forwarder, which delivers into the VM; these rules exist only in the VM.

```text
$ iptables -S DOCKER | grep -E '172.28|DROP' | head -8
-A DOCKER -d 172.28.0.5/32 ! -i br-5340d2f09db7 -o br-5340d2f09db7 -p tcp -m tcp --dport 8080 -j ACCEPT
...                                  (one ACCEPT per published port: 5432, 8082, 8081)
-A DOCKER ! -i br-8c367c583a2d -o br-8c367c583a2d -j DROP
-A DOCKER ! -i br-5340d2f09db7 -o br-5340d2f09db7 -j DROP
$ iptables -S | grep -E 'DOCKER-(FORWARD|BRIDGE|CT)'
-A FORWARD -j DOCKER-FORWARD
-A DOCKER-FORWARD -j DOCKER-CT           (conntrack RELATED,ESTABLISHED per bridge)
-A DOCKER-FORWARD -j DOCKER-BRIDGE       (-o br-X -j DOCKER)
-A DOCKER-FORWARD -i br-5340d2f09db7 -j ACCEPT   (traffic leaving the bridge is allowed)
```
**Isolation is firewall policy:** traffic *into* a bridge from any other interface hits `DOCKER ! -i br-X -o br-X -j DROP` unless a published-port ACCEPT matched first. (Pre-Engine-28 these were `DOCKER-ISOLATION-STAGE-1/2` chains; the old claim "different L2 segments keep networks apart" is not the mechanism, since the host routes between its bridges.)

Container-to-container traffic (tcpdump in `order-api`'s netns during a `POST /orders`):
```text
IP 172.28.0.5.34696 > 172.28.0.2.8081: Flags [S] ...
IP 172.28.0.2.8081 > 172.28.0.5.34696: Flags [S.] ...
IP 172.28.0.5.34696 > 172.28.0.2.8081: Flags [P.] ... length 208
4 packets captured
```
Source and destination are container IPs: no NAT, no published port involved.

Isolation and multi-homing:
```text
$ docker run --rm alpine ping -c1 -W2 172.28.0.5      # default bridge -> our network
1 packets transmitted, 0 packets received, 100% packet loss        (exit 1)
$ docker exec d2-fe nslookup d2-db                    # frontend-net container, db on backend-net
** server can't find d2-db: NXDOMAIN
$ docker exec d2-fe ping -c1 -W2 172.20.0.2
1 packets transmitted, 0 packets received, 100% packet loss
$ docker network connect backend-net d2-fe
$ docker exec d2-fe ping -c1 d2-db | tail -2
1 packets transmitted, 1 packets received, 0% packet loss
$ docker exec d2-fe getent hosts d2-db
172.20.0.2        d2-db  d2-db
```
(Addresses of the throwaway networks differ per run.) After `connect`, `d2-fe` has `eth0` on `frontend-net` and `eth1` on `backend-net`.

---

### 5. Volumes
```text
$ docker volume inspect orderflow-pgdata -f '{{.Mountpoint}}'
/var/lib/docker/volumes/orderflow-pgdata/_data
$ ls /var/lib/docker/volumes
ls: /var/lib/docker/volumes: No such file or directory          <- on the Mac: the path is inside the VM
$ docker run --rm -v orderflow-pgdata:/data alpine ls -la /data | head -6
drwx------   19 70       70            4096 Oct  6 13:46 .
-rw-------    1 70       70               3 Oct  6 13:46 PG_VERSION
drwx------    6 70       70            4096 Oct  6 13:46 base
...
$ docker run --rm -v orderflow-pgdata:/data alpine stat -c '%u:%g %n' /data/PG_VERSION
70:70 /data/PG_VERSION
```
UID/GID 70 is the `postgres` user of the Alpine image: on the first mount of an empty named volume Docker copies the image's content *and ownership* at that path. That is also why a distroless non-root service that must write to a volume needs the directory created and `chown`ed to 65532 in the image first.

Persistence:
```text
$ docker exec orderflow-postgres psql -U orderflow -d orderflow -c "CREATE TABLE test_data ...; INSERT ..."
CREATE TABLE
INSERT 0 1
$ docker compose down
 Network orderflow-network Removed
$ docker volume ls -f name=orderflow-pgdata
local     orderflow-pgdata
$ docker images 'day02-*' --format '{{.Repository}}'
day02-order-api
day02-notification-service
day02-payment-service
$ docker compose up -d --wait
$ docker exec orderflow-postgres psql -U orderflow -d orderflow -c "SELECT * FROM test_data;"
 id |         note
----+----------------------
  1 | persistence_verified
$ nc -vz 127.0.0.1 15432
Connection to 127.0.0.1 port 15432 [tcp/*] succeeded!
```
`down` removes containers and networks. It does **not** remove the named volume, and it does **not** remove images (the old text claimed it did): that needs `-v` and `--rmi`. (`nc -vz localhost ...` may print one `Connection refused` first because `localhost` tries `::1` before IPv4; the published port is IPv4-only.)

When Compose recreates `postgres`, Docker mounts the existing volume directory at `/var/lib/postgresql/data` and Postgres finds an initialized cluster, so it skips init (this is also why `POSTGRES_PASSWORD` changes in `.env` do **not** affect an existing volume).

Anonymous volumes and bind ownership:
```text
$ docker run -d --name d2-anon -e POSTGRES_PASSWORD=x postgres:16-alpine
$ docker inspect d2-anon -f '{{range .Mounts}}{{.Type}} {{.Name}}{{end}}'
volume 47909175153c66f8...
$ docker rm -f d2-anon; docker volume ls -qf dangling=true | grep -c "$V"
1                                              <- orphaned: the image declares VOLUME
$ docker volume rm "$V"
```
`docker image inspect postgres:16-alpine -f '{{.Config.Volumes}}'` → `map[/var/lib/postgresql/data:{}]`. This is why the compose file always names the volume.
```text
Mac:        -rw-r--r--  1 504  0  3  /tmp/d2-bind/f
as root:    -rw-r--r--  1 0    0  3  /b/f
as -u 1234: -rw-r--r--  1 1234 0  3  /b/f , /b/g created (write succeeded)
Mac again:  f and g both owned by 504
```
On Docker Desktop (VirtioFS) bind-mount ownership is synthesized to look like whoever accesses it. On a Linux engine, numeric UID/GID pass through unchanged (a file owned by host UID 1000 is UID 1000 in the container), so UID mismatches that never show up on a Mac appear in Linux CI.

---

### 6. BREAK IT: DNS Failure
```text
$ PAYMENT_SERVICE_URL=http://nonexistent-payment:8081 docker compose restart order-api
$ docker inspect ... | grep PAYMENT
PAYMENT_SERVICE_URL=http://payment-service:8081               <- restart did NOT pick up the change
$ PAYMENT_SERVICE_URL=http://nonexistent-payment:8081 docker compose up -d --wait order-api
$ docker inspect ... | grep PAYMENT
PAYMENT_SERVICE_URL=http://nonexistent-payment:8081           <- up -d recreated the container
$ curl -s -X POST http://localhost:8080/orders ... -d '{"item":"Mouse","qty":1}'
{"id":"5e9be358b177f7dc","item":"Mouse","qty":1,"status":"PENDING",...}      <- still 201
$ docker compose logs --no-log-prefix order-api | tail -1
[order-api] call to /payments failed for order 5e9be358b177f7dc: Post "http://nonexistent-payment:8081/payments": dial tcp: lookup nonexistent-payment on 127.0.0.11:53: no such host
$ docker compose up -d --wait order-api     # no variable set: config differs again, container recreated
PAYMENT_SERVICE_URL=http://payment-service:8081
```
`restart` stops/starts the same container, whose env was fixed at creation. `up -d <svc>` hashes the desired config and recreates the container when the hash changed. The lookup error names `127.0.0.11:53`: that is the embedded resolver from Section 3 answering `NXDOMAIN`. The API still returns 201 because the downstream call is fire-and-forget: the failure only exists in the logs (a design smell worth a metric or a retry queue in a real system).

### 7. BREAK IT: Volume Deletion
```text
$ docker compose down -v          ->  Network orderflow-network Removed  (volume removed too)
$ docker volume ls -qf name=orderflow-pgdata | wc -l
0
$ docker compose up -d --wait
$ docker exec orderflow-postgres psql -U orderflow -d orderflow -c "SELECT * FROM test_data;"
ERROR:  relation "test_data" does not exist
```
`-v` removes the named volume declared in `volumes:` (and anonymous volumes of the removed containers): the engine deletes the files in the volume directory, there is no trash. A fresh Postgres then runs `initdb` on the empty new volume.

---

### 8. Compose Features
```text
$ docker compose ps --services                 notification-service order-api payment-service postgres   (no netshoot)
$ docker compose --profile debug up -d netshoot
$ docker compose exec netshoot sh -c 'ss -ltn; curl -s localhost:8080/health; ...'
LISTEN 0 4096  127.0.0.11:43967  0.0.0.0:*
LISTEN 0 4096           *:8080          *:*
{"status":"ok","service":"order-api"}
{"status":"ok","service":"payment-service"}
```
`localhost:8080` works inside `netshoot` because `network_mode: "service:order-api"` puts it in `order-api`'s netns (the Kubernetes pod-sidecar model).

Env precedence:
```text
POSTGRES_DB: orderflow        # .env value (same as the :-default here)
POSTGRES_DB: from_envfile     # --env-file beats the project's .env
POSTGRES_DB: from_shell       # shell beats --env-file
order-api: DRAIN_DELAY_SECONDS: "2" (from env_file), PORT: "8080" (environment: beats env_file's 9999), no POSTGRES_* variables
```
Interpolation order: shell > `--env-file`/`.env` > `${VAR:-default}`. Container order: `environment:` > `env_file:` > image `ENV`. `.env` never reaches containers by itself.

`compose watch` (trimmed). Trigger file `labs/day02/watch-trigger` edited while `docker compose watch --no-up` runs:
```text
$ docker inspect -f '{{.Id}}' orderflow-order-api | cut -c1-12
c18c954d5e02
$ echo "v2" > labs/day02/watch-trigger
Watch enabled
Rebuilding service(s) ["order-api"] after changes were detected...
 Image day02-order-api Built
 Container orderflow-order-api Recreated
$ docker inspect -f '{{.Id}}' orderflow-order-api | cut -c1-12
0d8551a64954                                   <- new container
```
Optional: editing `labs/shared/order-api/main.go` (rule 2) rebuilds with new code, e.g. `/health` then returns `"v":2`.

---

### 9. Dev vs Test Override
```text
$ t ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
orderflow-notification   Up 4 seconds (healthy)   8082/tcp
orderflow-order-api      Up 1 second (healthy)    8080/tcp
orderflow-payment        Up 4 seconds (healthy)   8081/tcp
orderflow-postgres       Up 4 seconds (healthy)   5432/tcp
$ t --profile test run --rm smoke
{"id":"39dc63b91a8a4023","item":"smoke","qty":1,"status":"PENDING","created_at":"..."}
{"status":"ready","service":"order-api"}
$ docker inspect orderflow-postgres -f '{{json .Mounts}}'
[{"Type":"tmpfs","Source":"","Destination":"/var/lib/postgresql/data","Mode":"","RW":true,"Propagation":""}]
```
The test file: `ports: !reset []` drops the base file's `127.0.0.1:8080` publish (CI runners share ports; tests reach services over the network), a `type: tmpfs` mount with the same target replaces the named volume (merge key = target path), `healthcheck:` blocks shorten intervals, and a `smoke` client behind `profiles: ["test"]` runs once on the same network and depends on `order-api` being healthy.

### 10. Distroless Debugging
```text
$ docker run --rm --network container:orderflow-order-api nicolaka/netshoot ss -ltnp
LISTEN 0 4096  127.0.0.11:38243  0.0.0.0:*
LISTEN 0 4096           *:8080          *:*
$ docker run --rm --pid container:orderflow-order-api alpine ps
    1 65532    0:00 /app/server
   24 root     0:00 ps
$ docker debug -c 'ls -l /app; cat /proc/1/cmdline | tr "\0" " "; echo' orderflow-order-api
-rwxr-xr-x 1 root root 5963960 ... server
/app/server
```
`--network container:` and `--pid container:` join the target's namespaces without touching its image; `docker debug` (Docker Desktop) mounts a toolbox over the container's filesystem. PID 1 is the Go binary running as `65532`.

---

### Notes on the earlier version
- Image names are `day02-<service>` (project name pinned with `name: day02`), not `day02-payment`/`day02-notification`.
- Compose files are listed explicitly through `COMPOSE_FILE`: auto-loading of `docker-compose.override.yml` only happens with no `-f` and when the file sits next to the base file.
- The dev override no longer repeats `8080` (a differently written duplicate, e.g. `127.0.0.1:8080:8080` next to `8080:8080`, would be published twice) and no longer sets an unused `LOG_LEVEL`; it sets `ENABLE_DEBUG_ALLOC` instead (which the services do read).
- Overlay is a network *driver* (needs Swarm), not a mode like host/none. On Docker Desktop, `--network=host` is the VM's namespace; use the "host networking" setting to reach those ports from macOS.
