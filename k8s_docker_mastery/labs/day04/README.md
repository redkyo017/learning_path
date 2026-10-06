# Day 4 Lab: Gateway API Edge, Headless Services & Zero-Trust Network Policies

**Run every command from the course root** (`k8s_docker_mastery/`). Target cluster: Docker Desktop Kubernetes on the **kind provisioner** (context `docker-desktop`, node `desktop-control-plane`, kindnet CNI, kube-proxy in `iptables` mode). Alternatives: Docker Desktop's older *kubeadm* provisioner (node `docker-desktop`) sees local images directly, but its CNI does **not enforce NetworkPolicy** (Step 7's block test will not block) and the node is not a container (Step 9 needs `kubectl debug node/...` instead of `docker exec`); with plain `kind`, `load-images.sh` runs `kind load docker-image`, kindnet enforces policy, and `docker exec <cluster>-control-plane` works the same way (LoadBalancer addresses need MetalLB or `cloud-provider-kind`; use the port-forward fallback).

## Start here — plain steps

1. **Step 1:** open a terminal in `k8s_docker_mastery/` (`kubectl config current-context` = `docker-desktop`, one `Ready` node; `brew install helm` if missing), run `reset.sh` and `load-images.sh`, and apply the Day 3 files. You should see 5 pods `1/1 Running`.
2. **Steps 2-3:** install Envoy Gateway with Helm, apply `manifests/gateway.yaml` and `httproute.yaml`. The Gateway `edge` becomes `Programmed`; `curl http://localhost/orders` returns `200` and `curl http://localhost/payments` returns `404` (payment is not exposed).
3. **Step 4:** add a canary: header match (`x-canary: true`) and a 90/10 split; count where requests went in the Envoy access log.
4. **Step 5:** break the Service twice (wrong selector, wrong `targetPort`) and read the EndpointSlices and the `503`.
5. **Step 6:** query the headless Service via DNS and compare it with the ClusterIP name.
6. **Step 7:** apply the NetworkPolicies and prove they are enforced: `order-api` reaches payment/notification, `notification-service` cannot reach payment, the edge still reaches `order-api`.
7. **Step 8:** apply an egress default-deny, watch DNS and the downstream calls fail, then fix it.
8. **Steps 9-10:** read the kube-proxy rules and conntrack on the node (and optionally ExternalName). You are done when each "You should see" line matched; run **Teardown** (it keeps the edge for Days 6-7).

## Objective
Move the cluster edge from the retired ingress-nginx to the **Gateway API** (Envoy Gateway v1.9.2), with the platform/app role split: you play the platform team (GatewayClass + Gateway in `gateway-infra`) and the app team (HTTPRoute in `orderflow`). Then segment the namespace with NetworkPolicy, observe headless DNS and EndpointSlices, and read the Linux dataplane that implements Services.

---

## Architecture Diagram

```
 Mac: curl http://localhost/orders
   │  (Docker Desktop publishes the LoadBalancer Service on localhost:80)
   ▼
[Service envoy-gateway-infra-edge-<hash>  LoadBalancer :80]   ns envoy-gateway-system
   ▼
[Envoy proxy pod]  ◄── owned by Gateway "edge" (ns gateway-infra, GatewayClass eg)
   │   HTTPRoute "orderflow" (ns orderflow): /orders → order-api   (x-canary header / 90:10 weights in Step 4)
   ▼  (Envoy sends to pod IPs from the EndpointSlice, not through the ClusterIP)
[order-api pods]  ── NetworkPolicy: only the Envoy proxy pods may enter ──
   │                                         
   ├──► [payment-service]       (allow-order-api-to-payment; no route at the edge)
   └──► [notification-service]  (allow-order-api-to-notification; no route at the edge)
                ✗ notification → payment : dropped (default deny)
```

---

## Instructions

### Step 1: Fresh namespace, images, Day 3 workloads
```bash
bash labs/shared/reset.sh
bash labs/shared/load-images.sh
for f in configmap secret payment-service notification-service order-api; do
  kubectl apply -f labs/day03/manifests/$f.yaml
done
for d in payment-service notification-service order-api; do
  kubectl rollout status deploy/$d -n orderflow --timeout=60s
done
kubectl get pods -n orderflow
```
*You should see: 5 pods `1/1 Running` (order-api 2, payment-service 2, notification-service 1).* (The Day 3 files are read-only references here; Day 4 only adds to them.)

### Step 2: Install Envoy Gateway (platform step)
```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 \
  -n envoy-gateway-system --create-namespace
kubectl wait -n envoy-gateway-system --timeout=120s --for=condition=Available deployment/envoy-gateway
kubectl get crd | grep gateway.networking.k8s.io
```
*You should see: `deployment.apps/envoy-gateway condition met` and the Gateway API CRDs (`gatewayclasses`, `gateways`, `httproutes`, `grpcroutes`, `referencegrants`, ...) that the chart installs.* The chart pulls from Docker Hub (OCI), so it needs internet access. If `helm install` says `eg` already exists, an earlier day installed it: skip to Step 3.

### Step 3: Gateway + HTTPRoute, then reach it from the Mac
```bash
kubectl apply -f labs/day04/manifests/gateway.yaml        # GatewayClass eg, ns gateway-infra, Gateway edge
kubectl wait --for=condition=Programmed gateway/edge -n gateway-infra --timeout=120s
kubectl apply -f labs/day04/manifests/httproute.yaml       # app team: /orders -> order-api
kubectl get httproute -n orderflow
kubectl get pods,svc -n envoy-gateway-system
```
Where did the proxy run? In **`envoy-gateway-system`**, not in `gateway-infra`: Envoy Gateway creates the Envoy Deployment and a `LoadBalancer` Service in its own namespace. Remember this for Step 7.

**Reach it from the Mac.** On Docker Desktop (kind provisioner) the Service gets an `EXTERNAL-IP` from the Docker network (e.g. `172.21.0.5`), which is *not* routable from the Mac, but Docker Desktop also publishes the port on `localhost`:
```bash
curl -i http://localhost/orders                           # 200, body []
curl -i -X POST http://localhost/orders -H 'Content-Type: application/json' -d '{"item":"book","qty":1}'
curl -i http://localhost/payments                         # 404: no route, payment is internal
```
*You should see: `200 OK` `[]`; `201` with an order JSON; `404 Not Found` with an empty body for `/payments` (and for `/`: no route matched).*

**Fallback** (only for plain kind, or if port 80 is busy on your Mac; `http://localhost` works on Docker Desktop with either the kind or the kubeadm provisioner): port-forward the proxy Service.
```bash
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=edge -o name)
kubectl port-forward -n envoy-gateway-system $SVC 8888:80 &
curl -i http://localhost:8888/orders      # use :8888 instead of the bare localhost URLs below; kill %1 when done
```
Check the route's own status, the typed equivalent of reading the controller log:
```bash
kubectl get httproute orderflow -n orderflow -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```
*You should see: `Accepted=True Accepted` and `ResolvedRefs=True ResolvedRefs`.*

### Step 4: Header match and weighted canary
The canary is a second Deployment/Service of the same image. The route gets two rules: header `x-canary: true` goes to the canary; everyone else is split 90/10.
```bash
kubectl apply -f labs/day04/manifests/order-api-canary.yaml
kubectl rollout status deploy/order-api-canary -n orderflow --timeout=60s
kubectl apply -f labs/day04/manifests/httproute-canary.yaml
sleep 3
PROXY=$(kubectl get deploy -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=edge -o name)

# weighted: 100 plain requests, then count the upstream pod IPs in Envoy's access log
for i in $(seq 1 100); do curl -s -o /dev/null http://localhost/orders; done
kubectl get pods -n orderflow -o wide | grep order-api          # map pod name -> IP
sleep 10   # Envoy's access log reaches `kubectl logs` several seconds late
kubectl logs -n envoy-gateway-system $PROXY -c envoy --tail=100 | grep -o '"upstream_host":"[^"]*"' | sort | uniq -c

# header match: every request lands on the canary pod
for i in $(seq 1 10); do curl -s -o /dev/null -H 'x-canary: true' http://localhost/orders; done
sleep 10   # same access-log delay
kubectl logs -n envoy-gateway-system $PROXY -c envoy --tail=10 | grep -o '"upstream_host":"[^"]*"' | sort | uniq -c
```
*You should see: roughly 90 requests spread over the two `order-api` pod IPs and about 10 on the canary IP (weights are probabilistic: expect 5-15, not exactly 10); the 10 header-matched requests all on the canary IP.* Restore the plain route when done:
```bash
kubectl apply -f labs/day04/manifests/httproute.yaml
kubectl delete -f labs/day04/manifests/order-api-canary.yaml
```
Do this step **before** Step 7: a new backend pod is not covered by the allow policy, so once default-deny is in place the canary would be unreachable (Envoy logs `response_code 0`, flag `DC`, and requests hang) until you add its label to `allow-edge-to-order-api`. A new backend means a new policy line. `httproute-canary.yaml` and `httproute.yaml` are the same object (`orderflow`); applying either replaces the rules. Weights are relative (`90`/`10` means 90%/10%); other filters (redirect, URL rewrite, header modifiers, mirroring) live in the same `rules[]`.

### Step 5: BREAK IT — Service selector and targetPort
```bash
kubectl patch service order-api -n orderflow -p '{"spec":{"selector":{"app":"non-existent"}}}'
kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=order-api
curl -i http://localhost/orders
kubectl get httproute orderflow -n orderflow -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
kubectl patch service order-api -n orderflow -p '{"spec":{"selector":{"app":"order-api"}}}'
```
*You should see: the EndpointSlice with `ENDPOINTS <unset>`; `HTTP/1.1 503 Service Unavailable` from Envoy; and `BackendsAvailable=False EndpointsNotFound` on the route.*

Now the subtler one: a wrong **numeric** `targetPort` does *not* empty the slice.
```bash
kubectl patch service order-api -n orderflow --type=json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":9999}]'
kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=order-api \
  -o 'custom-columns=NAME:.metadata.name,PORT:.ports[*].port,ADDRS:.endpoints[*].addresses[0]'
curl -i http://localhost/orders
kubectl patch service order-api -n orderflow --type=json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":"http"}]'
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/orders
```
*You should see: both pod IPs still listed, with `PORT 9999`; `503` with body `upstream connect error or disconnect/reset before headers. reset reason: remote connection failure`; after the restore, `200`.* Nothing validates the port: endpoints exist, the connection is refused.

### Step 6: Headless Service and DNS
```bash
kubectl apply -f labs/day04/manifests/headless-service.yaml
kubectl run dns-test -n orderflow --image=busybox:1.37 --restart=Never --command -- sleep 600
kubectl wait -n orderflow --for=condition=Ready pod/dns-test --timeout=90s
kubectl exec -n orderflow dns-test -- nslookup payment-service-headless.orderflow.svc.cluster.local.
kubectl exec -n orderflow dns-test -- nslookup payment-service.orderflow.svc.cluster.local.
kubectl exec -n orderflow dns-test -- cat /etc/resolv.conf
kubectl get endpointslices -n orderflow
kubectl delete pod dns-test -n orderflow
```
The trailing dot makes each name fully qualified, so you see exactly what you asked for (no search-list expansion). *You should see: the headless name returns two `Address:` lines (the two payment pod IPs, `kubectl get pods -o wide` to compare); the normal Service returns one address, the ClusterIP; `resolv.conf` has three `search` domains and `options ndots:5`; an EndpointSlice for each Service, including `payment-service-headless-*`.* (`dns-test` carries only the label `run=dns-test`, so it never joins any Service's endpoints.)

### Step 7: NetworkPolicy, with an enforcement check
First, prove the network is open and that your test client works. `kubectl debug` adds an *ephemeral container* to a running pod: it shares the pod's network namespace **and labels' identity** (policies apply to it as to the pod). Output of a short-lived ephemeral container can be lost with `-i`, so we run it detached and read its logs.
```bash
NOTIF=$(kubectl get pods -n orderflow -l app=notification-service -o jsonpath='{.items[0].metadata.name}')
ORDER=$(kubectl get pods -n orderflow -l app=order-api -o jsonpath='{.items[0].metadata.name}')

kubectl debug $NOTIF -n orderflow --image=curlimages/curl --target=notification-service --profile=general \
  --container=open-test -q -- curl -sS -m3 -o /dev/null -w "code=%{http_code}\n" http://payment-service:8081/health
sleep 6; kubectl logs $NOTIF -n orderflow -c open-test
```
*You should see: `code=200`. Any pod can reach payment today (no policy yet).*

Apply the policies (`default-deny-all-ingress`; `allow-edge-to-order-api`; `allow-order-api-to-payment`; `allow-order-api-to-notification`):
```bash
kubectl apply -f labs/day04/manifests/networkpolicy.yaml
kubectl get networkpolicy -n orderflow
sleep 6      # kindnet needs a few seconds to program new rules
```
Test every edge of the graph:
```bash
# 1. edge -> order-api (allowed: Envoy proxy namespace + label)
curl -s -o /dev/null -w "edge: %{http_code}\n" http://localhost/orders

# 2. order-api -> payment and -> notification (allowed)
kubectl debug $ORDER -n orderflow --image=curlimages/curl --target=order-api --profile=general \
  --container=allow-test -q -- sh -c 'curl -sS -m3 -w " code=%{http_code}\n" http://payment-service:8081/health; curl -sS -m3 -w " code=%{http_code}\n" http://notification-service:8082/health'
sleep 6; kubectl logs $ORDER -n orderflow -c allow-test

# 3. notification -> payment (BLOCKED: enforcement check)
kubectl debug $NOTIF -n orderflow --image=curlimages/curl --target=notification-service --profile=general \
  --container=deny-test -q -- curl -sS -m3 -o /dev/null -w "code=%{http_code}\n" http://payment-service:8081/health
sleep 8; kubectl logs $NOTIF -n orderflow -c deny-test

# 4. a full request still works end to end, and the notification is delivered (no more failures logged)
curl -s -o /dev/null -w "POST: %{http_code}\n" -X POST http://localhost/orders -H 'Content-Type: application/json' -d '{"item":"np","qty":1}'
kubectl logs -n orderflow -l app=notification-service --tail=1
```
*You should see: `edge: 200`; two `code=200` lines with the payment and notification JSON; `curl: (28) Connection timed out after 3000 milliseconds` / `code=000` for the blocked path (a **drop**, not a refusal: no RST, so the client waits); `POST: 201` and a `dispatching notification` line.* The `ephemeral` containers stay listed in the pod spec until the pod is replaced.

**If step 3 prints `code=200`, your CNI is not enforcing policy** (the Docker Desktop kubeadm provisioner). Policies are API objects only; the CNI must act on them. **If *everything* times out, even after you delete the policies**, the kindnet policy agent may have wedged (`kubectl logs -n kube-system ds/kindnet` shows `netlink receive: no such file or directory`): `kubectl rollout restart ds/kindnet -n kube-system`.

Notes: policy is checked *after* Service DNAT, so ports in a policy are the **container** ports (8080/8081/8082). Look at `allow-edge-to-order-api`: the `namespaceSelector` and `podSelector` are in **one** `from` item (AND). Written as two items it would be OR, and would admit the whole `envoy-gateway-system` namespace plus any `app.kubernetes.io/name: envoy` pod in `orderflow`.

### Step 8: Egress default-deny, the DNS trap
```bash
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny-all-egress, namespace: orderflow}
spec: {podSelector: {}, policyTypes: [Egress]}
YAML
sleep 6
curl -s -o /dev/null -w "POST: %{http_code}\n" -m 15 -X POST http://localhost/orders -H 'Content-Type: application/json' -d '{"item":"eg","qty":1}'
sleep 5      # downstream calls are background goroutines with a 3 s timeout: failures are logged ~3 s later
kubectl logs -n orderflow -l app=order-api -c order-api --tail=3 --prefix
```
*You should see: the POST still returns `201` (order-api creates the order first, then calls downstream in the background); about 3 s later (hence the `sleep 5`) order-api logs `call to /payments failed ... context deadline exceeded` and the same for `/notify`: its DNS lookups (and everything else) are dropped.* Edge → order-api still works, since replies of an allowed ingress connection are not egress-filtered (stateful).

Fix with an explicit DNS allow plus the two downstream allows (file contains the deny too, re-applying it is harmless):
```bash
kubectl apply -f labs/day04/manifests/networkpolicy-egress.yaml
sleep 8
for i in 1 2 3; do curl -s -o /dev/null -X POST http://localhost/orders -H 'Content-Type: application/json' -d '{"item":"fixed","qty":1}'; done
sleep 5
kubectl logs -n orderflow -l app=notification-service --tail=3
kubectl logs -n orderflow -l app=order-api -c order-api --tail=2 --prefix
```
*You should see: three new `dispatching notification` lines and no new `failed` lines.* (Failures logged in the first seconds after applying are policy-propagation lag. The `lookup payment-service ... no such host` form of the error appears when the resolver's answer is dropped.) Why `kube-system` + `k8s-app=kube-dns`, UDP **and** TCP: DNS falls back to TCP for large answers.

### Step 9: The dataplane on the node
Mode and node tools (Docker Desktop kind provisioner: the node is the container `desktop-control-plane`; **on the kubeadm provisioner or a cloud node use `kubectl debug node/<node> -it --image=nicolaka/netshoot --profile=sysadmin` and `chroot /host`**):
```bash
kubectl -n kube-system get cm kube-proxy -o yaml | grep -E '^\s+mode:'
IP=$(kubectl get svc payment-service -n orderflow -o jsonpath='{.spec.clusterIP}'); echo $IP
docker exec desktop-control-plane sh -c "iptables-save -t nat | grep -E 'payment-service' "
```
Follow the chain by hand: take the `KUBE-SVC-...` name from the `KUBE-SERVICES` line, then:
```bash
SVC=$(docker exec desktop-control-plane sh -c "iptables-save -t nat | grep -E '^-A KUBE-SERVICES.*$IP' | grep -o 'KUBE-SVC-[A-Z0-9]*'"); echo $SVC
docker exec desktop-control-plane sh -c "iptables-save -t nat | grep -E -- '$SVC'"
docker exec desktop-control-plane sh -c "iptables-save -t nat | grep -E -- 'DNAT.*:8081'"
docker exec desktop-control-plane sh -c "iptables-save -t nat | grep -E -- 'KUBE-MARK-MASQ -j|KUBE-POSTROUTING'"
```
*You should see: `mode: iptables`; a `KUBE-SERVICES -d <ClusterIP> ... --dport 8081 -j KUBE-SVC-...` rule; in the `KUBE-SVC` chain a `statistic --mode random --probability 0.5` jump to the first `KUBE-SEP` and an unconditional jump to the second; each `KUBE-SEP` ends in `DNAT --to-destination 10.244.x.y:8081`; `KUBE-MARK-MASQ` sets mark `0x4000` and `KUBE-POSTROUTING` MASQUERADEs it.* (On an `nftables`-mode cluster use `nft list table ip kube-proxy` instead.)

Conntrack: generate a call, then look for the translation.
```bash
kubectl debug $ORDER -n orderflow --image=curlimages/curl --target=order-api --profile=general --container=ct-test -q -- curl -s -m3 http://payment-service:8081/health
sleep 6
docker exec desktop-control-plane conntrack -L -d $IP 2>/dev/null
docker exec desktop-control-plane sysctl net.netfilter.nf_conntrack_tcp_timeout_established
```
*You should see: a `tcp ... src=<order-api pod> dst=<ClusterIP> sport=... dport=8081 src=<payment pod IP> dst=<order-api pod> ...` entry: the left half is what the client sent, the right half (reply tuple) shows the DNAT'd real backend. A finished connection lingers in `TIME_WAIT`; an open one stays `ESTABLISHED` up to the 86400 s timeout.* That entry is why load balancing is per connection: the endpoint is chosen once, when it is created. Also note the proxy Service rules: `iptables-save -t nat | grep envoy-gateway-infra-edge` shows `KUBE-EXT-...` (the LoadBalancer/NodePort path) next to the normal ClusterIP chain.

### Step 10 (optional): ExternalName
```bash
kubectl apply -f labs/day04/manifests/externalname.yaml
kubectl get svc external-demo -n orderflow
kubectl debug $ORDER -n orderflow --image=busybox:1.37 --target=order-api --profile=general --container=ns-test -q -- nslookup -type=CNAME external-demo.orderflow.svc.cluster.local
sleep 6; kubectl logs $ORDER -n orderflow -c ns-test
kubectl delete -f labs/day04/manifests/externalname.yaml
```
*You should see: `TYPE ExternalName`, `CLUSTER-IP <none>`, and `canonical name = example.com`: only DNS, no virtual IP and no kube-proxy rule.*

---

## Stuck? Hints
- **`ImagePullBackOff` on the orderflow pods** → the kind-provisioner node cannot see your Docker images → run `bash labs/shared/load-images.sh` again (`v2` is not needed today).
- **`curl http://localhost/orders` refused, hangs, or `404`** → Gateway not `Programmed` yet, port 80 owned by another Mac app, or the route is not attached → `kubectl wait --for=condition=Programmed gateway/edge -n gateway-infra --timeout=120s`; `kubectl get httproute orderflow -n orderflow -o yaml` and read `status.parents[].conditions` (`Accepted=False` = wrong `parentRefs` or `allowedRoutes`); otherwise use the port-forward fallback in Step 3. The `EXTERNAL-IP` (172.x) is only reachable inside Docker's network, not from the Mac.
- **Requests to a new backend (e.g. the canary) hang after Step 7** → default-deny covers it and no allow selects it → add the pod's label to the policy that admits the edge, or do the canary before applying policies.
- **Block test in Step 7 returns 200, or everything times out even after deleting policies** → on the kubeadm provisioner the CNI does not enforce NetworkPolicy (the rest of the lab works, nothing is blocked; use the kind provisioner); a wedged kindnet policy agent (`netlink receive: no such file or directory` in `kubectl logs -n kube-system ds/kindnet`) → `kubectl rollout restart ds/kindnet -n kube-system`, wait, retry.
- **A `kubectl debug` test prints nothing, or the log is empty after `sleep 6`** → `-i` can lose the output of a short-lived container, and the first `curlimages/curl` pull can take longer than the sleep → run detached (as written), then re-run `kubectl logs <pod> -c <name>` after a few seconds. Container names must be unique per pod; pick a new `--container` name each time.
- **`helm install` cannot pull the chart** → the OCI registry needs internet access; no `helm registry login` is needed for the public chart.

---

## Teardown
Removes the app (its Services, HTTPRoute and NetworkPolicies go with the namespace) and **keeps the edge** (Envoy Gateway, GatewayClass `eg`, namespace `gateway-infra`, Gateway `edge`), which Days 6-7 reuse:
```bash
bash labs/shared/reset.sh
kubectl delete namespace orderflow
```
Optional full uninstall of the edge (when you have finished Days 6-7):
```bash
kubectl delete -f labs/day04/manifests/gateway.yaml
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
kubectl get crd -o name | grep -E 'gateway.networking.(x-)?k8s.io|gateway.envoyproxy.io' | xargs kubectl delete
```
