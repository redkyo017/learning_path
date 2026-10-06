# Day 4 — Kubernetes Networking, Services & the Gateway API

## Why this matters

Most Kubernetes outages that look like "the app is down" are really networking: a `503` from the edge because a Service has no endpoints, `dial tcp: i/o timeout` between microservices because a policy drops the packet, a CoreDNS pod saturated by search-path lookups. Beginners respond by changing ports and restarting pods.

Senior engineers debug networking because they know the packet path. A `ClusterIP` is not a server, an interface or a process: it is a virtual IP that exists only as packet-rewrite rules programmed into each node's kernel. CoreDNS turns names into those IPs; `ndots:5` multiplies lookups; an L7 proxy at the edge picks pods; and `NetworkPolicy` (when the CNI enforces it) decides which packets may flow at all.

You run API gateways, so the edge is the part you will judge hardest. **Ingress-nginx, the community Ingress controller this course used to teach, was retired by SIG Network in March 2026**, and the Ingress API itself is frozen. The forward path is the **Gateway API**; this lab uses **Envoy Gateway** as the implementation.

---

## The layer this covers

```
[Mac: curl http://localhost/orders]      (Docker Desktop publishes the LoadBalancer on localhost:80)
        │
        ▼
[LoadBalancer Service, ns envoy-gateway-system]  ──(kube-proxy DNAT)──►  [Envoy proxy pod]
        │                                                       owned by Gateway "edge" (ns gateway-infra)
        │   HTTPRoute (ns orderflow): /orders ──► Service order-api
        ▼
 Envoy reads the EndpointSlices of the backend Service and sends straight to a pod IP
 (it does NOT go through the ClusterIP, so no kube-proxy hop and Envoy does its own load balancing)
        │
        ▼
[order-api pod 10.244.x.x]  ── Service payment-service (ClusterIP) ──► KUBE-SERVICES → KUBE-SVC → KUBE-SEP (DNAT) ──► [payment pod]
                            └─ Service notification-service ─────────► (same mechanism)
```

`payment-service` and `notification-service` have **no route** at the edge: they are reachable only from inside the cluster, and (after the NetworkPolicy step, Step 7 of the lab) only from `order-api`.

---

## Core concepts

### 1. The pod network model, CNI and kubelet

Kubernetes requires: every Pod has its own IP; Pods reach each other across nodes without NAT; node agents reach all local Pods. How that is achieved is the CNI plugin's job.

Chain on pod start: **kubelet → CRI runtime (containerd) → CNI plugin**. The kubelet does not call the CNI itself; it asks the runtime to create the pod sandbox (the "pause" container that owns the network namespace), and the runtime invokes the CNI plugin with JSON on stdin to create the veth pair, assign the IP and program routes.

- **Flannel:** simple VXLAN overlay; no NetworkPolicy.
- **Calico:** routed (BGP) or overlay; NetworkPolicy via iptables or eBPF.
- **Cilium:** eBPF dataplane; can replace kube-proxy; L7-aware policy; observability (Hubble).
- **AWS VPC CNI (EKS):** pods get real VPC secondary IPs on ENIs. NetworkPolicy is a separate (newer) component.
- **kindnet (this lab's cluster, Docker Desktop kind provisioner):** minimal CNI that also enforces NetworkPolicy. Docker Desktop's older *kubeadm* provisioner does **not** enforce NetworkPolicy (policies are accepted and silently ignored). So never assume a policy works: the lab includes an enforcement check.

### 2. Services: ClusterIP, NodePort, LoadBalancer, Headless, ExternalName

A Service is a stable name and virtual IP in front of a changing set of pods. The controller plane keeps an **EndpointSlice** list of ready pod IPs per Service. (The older `Endpoints` API is deprecated since 1.33: it caps at 1000 addresses per object and is rewritten whole on every change. Use `kubectl get endpointslices`.) Pods that fail readiness are removed from the slices.

#### A. ClusterIP and kube-proxy
- A ClusterIP is bound to no interface; you cannot reliably `ping` it (in `iptables` mode there is nothing to answer ICMP; in IPVS mode the IP sits on a dummy interface and does answer).
- `kube-proxy` on each node watches Services and EndpointSlices and programs the kernel. Mode on this cluster: `iptables` (`kubectl -n kube-system get cm kube-proxy -o yaml | grep mode`). An `nftables` mode exists and is GA in recent releases; IPVS mode is being phased out.
- The real chain for a 2-pod Service, read live from the node in the lab (Step 9):

```text
KUBE-SERVICES      -d 10.96.202.204/32 -p tcp --dport 8081            -j KUBE-SVC-IQ7Q...   (match the ClusterIP)
KUBE-SVC-IQ7Q...   ! -s 10.244.0.0/16 -d <clusterIP> ...              -j KUBE-MARK-MASQ     (traffic from outside the pod CIDR gets SNAT-marked)
KUBE-SVC-IQ7Q...   -m statistic --mode random --probability 0.5       -j KUBE-SEP-W4QQ...   (pod 1)
KUBE-SVC-IQ7Q...                                                      -j KUBE-SEP-5RAI...   (pod 2, the remainder)
KUBE-SEP-W4QQ...   -p tcp -j DNAT --to-destination 10.244.0.67:8081
```
  Packets from a pod hit `KUBE-SERVICES` in the `nat` table's PREROUTING/OUTPUT path; DNAT rewrites the destination; **conntrack** remembers the translation so replies are un-NATed and later packets of the same connection skip the rules.
- **Load balancing is per connection, not per request.** The random choice happens once, when conntrack creates the entry. A keep-alive HTTP/1.1 client or a gRPC (HTTP/2) channel opens one TCP connection and pins to one pod for as long as it lives (conntrack's established timeout is 86400 s on this node). Result: after a scale-up the new pods get no traffic from existing clients. This is **the gRPC load-balancing pitfall**. gRPC is L7 (HTTP/2), so use an L7 balancer that sees individual requests (Envoy / a mesh / client-side balancing over a headless Service with `round_robin`), or cap connection lifetime (`MAX_CONNECTION_AGE`).
- **SNAT/MASQ:** `KUBE-MARK-MASQ` sets mark `0x4000`; `KUBE-POSTROUTING` MASQUERADEs marked packets so replies from a pod return via the node that did the DNAT (hairpin and external-source cases). Pod-to-Service traffic inside the pod CIDR keeps its source IP, which is why NetworkPolicy can match on pod identity.

#### B. NodePort & LoadBalancer
- **NodePort:** a port in `30000-32767` opened on every node by kube-proxy, forwarding to the Service.
- **LoadBalancer:** NodePort plus a cloud controller that provisions an external L4 load balancer pointing at the nodes. On Docker Desktop's kind provisioner a helper (`desktop-cloud-provider-kind`) assigns an address from the Docker network (here `172.21.0.5`) **and** Docker Desktop publishes the port on the Mac's `localhost`.
- **`externalTrafficPolicy`:** `Cluster` (default) lets any node forward to any pod (extra hop, source IP SNATed); `Local` only sends to pods on the receiving node, preserving the client IP and skipping the hop, but nodes with no local pod fail the cloud LB health check. Envoy Gateway's Service defaulted to `Local` on this cluster (single node, so no difference).
- **`internalTrafficPolicy: Local`** does the same for in-cluster clients (only same-node endpoints; traffic is dropped if none). Related: `trafficDistribution: PreferSameZone` (zone-aware preference; the new name for `PreferClose`, same behaviour, `PreferClose` is deprecated) and `PreferSameNode` (new). KEP-3015: alpha 1.33, beta 1.34, GA 1.35.

#### C. Headless Service (`clusterIP: None`)
No virtual IP, no kube-proxy rules. DNS returns the A records of all ready pods; clients choose. Needed for StatefulSets (stable per-pod names), databases with replicas, and client-side-balanced gRPC.

#### D. ExternalName
A Service of `type: ExternalName` is just a DNS CNAME (`external-demo.orderflow.svc` → `example.com`). No ClusterIP, no proxying, no port mapping, no health. Handy to give an external dependency a stable in-cluster alias. Caveat: TLS/HTTP `Host` still carries the external name, and an IP address as `externalName` is not meaningful.

### 3. DNS and `ndots:5`

CoreDNS runs as a Service (`10.96.0.10` here). Every pod gets:
```text
search orderflow.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```
A name with fewer than 5 dots is first tried with every search suffix. For `api.stripe.com` (2 dots) the resolver asks, in order: `api.stripe.com.orderflow.svc.cluster.local` (NXDOMAIN), `...svc.cluster.local` (NXDOMAIN), `...cluster.local` (NXDOMAIN), and finally `api.stripe.com`. That is **3 wasted queries before the real one, and typically each is done for both A and AAAA**, so up to 8 queries per cold lookup. Fixes, in order of preference: set `dnsConfig.options: [{name: ndots, value: "2"}]` on the pod spec (the declarative fix, no code change), use a node-local DNS cache, and in code a trailing dot (`api.stripe.com.`) where you control the string (it can break `Host` header and TLS SNI matching, so it is not a blanket fix). Cluster names: `<svc>.<ns>.svc.cluster.local`, and for a headless StatefulSet pod `<pod>.<svc>.<ns>.svc.cluster.local`.

Testing tip: query the **FQDN with a trailing dot** (`nslookup payment-service.orderflow.svc.cluster.local.`): it bypasses the search list, so you see exactly what you asked for.

### 4. North-south traffic: Ingress (legacy) vs Gateway API

#### Ingress: know it, you will meet it
`Ingress` (networking.k8s.io/v1) is a single resource that mixes everything: host/path rules, TLS, and (via controller-specific **annotations**) every feature beyond that. Pieces:
- **Ingress resource**: rules; **IngressClass**: which controller owns it (`spec.ingressClassName`); **controller**: the proxy that implements it. Without a controller the resource does nothing.
- **pathType**: `Exact`, `Prefix` (element-wise: `/orders` matches `/orders` and `/orders/1`, not `/ordersX`), or `ImplementationSpecific` (controller-defined; regex lives here, so a regex path is *not* a Prefix).
- **TLS**: `spec.tls[].hosts` + `secretName` (a `kubernetes.io/tls` Secret in the same namespace).

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: orderflow, namespace: orderflow}
spec:
  ingressClassName: nginx            # an IngressClass that no longer has a maintained community controller
  tls:
    - hosts: [orderflow.example.com]
      secretName: orderflow-tls
  rules:
    - host: orderflow.example.com
      http:
        paths:
          - path: /orders
            pathType: Prefix
            backend: {service: {name: order-api, port: {number: 8080}}}
```
**Why it is being left behind:** one object owns routing, TLS and policy, so platform and app teams collide; anything useful (rewrites, timeouts, auth, canary) is a non-portable annotation; no header matching, weights, or non-HTTP protocols in the core spec. Note that the rewrite pitfall: ingress-nginx `rewrite-target: /$2` with path `/api/orders(/|$)(.*)` forwards to `/` when the capture is empty, not `/orders`; rewrites change the path the backend sees, so state them deliberately.

**Migration:** the `ingress2gateway` tool converts Ingress resources (and some controller annotations) to Gateway/HTTPRoute; review its output, because unsupported annotations are dropped with a warning.

**IngressNightmare (CVE-2025-1974, March 2025):** the ingress-nginx *admission webhook* was reachable from any pod and let it inject nginx config; because the controller had cluster-wide Secret read access, one network-reachable pod became cluster takeover (CVSS 9.8). Lessons: an edge controller is the most privileged workload in the cluster; admission webhooks are an attack surface (restrict who can reach them with NetworkPolicy); configuration-injection via annotations is a class of bug the Gateway API's typed fields largely avoid; keep the controller patched and, ideally, off an unmaintained project.

#### Gateway API: the model
Three roles, three resources, so each team owns only its layer:

| Resource | Owner | Says |
|---|---|---|
| `GatewayClass` (`eg`) | infrastructure provider | "this controller implements Gateways" (`controllerName: gateway.envoyproxy.io/gatewayclass-controller`) |
| `Gateway` (`edge`, ns `gateway-infra`) | platform / cluster operator | listeners: port, protocol, TLS, **who may attach routes** (`allowedRoutes`) |
| `HTTPRoute` / `GRPCRoute` / `TLSRoute`... (ns `orderflow`) | application developer | matches (path, header, method, query) and `backendRefs` with **weights**, filters (redirect, rewrite, header modifiers, mirror) |

A route points at a Gateway with `parentRefs`; the Gateway accepts it only if `allowedRoutes` permits that namespace (the lab uses `from: All`; production usually uses `Selector`). A route in namespace A referencing a Service in namespace B needs a **ReferenceGrant** in B; likewise a listener's TLS `certificateRefs` pointing to a Secret in another namespace needs one. **Match precedence is by specificity, not by rule order:** the most specific match wins (exact path > longer prefix; then method; then more header matches; then more query-param matches), which is why the lab's `x-canary` header rule beats the weighted rule even though both match `/orders`. Ties go to the oldest route, then alphabetical. Status is first-class: `kubectl get httproute -o yaml` shows `Accepted`, `ResolvedRefs`, and the reason an attachment failed.

Compared with API-gateway products you know: matches replace ad-hoc location blocks, `backendRefs[].weight` is the built-in canary, filters are the portable subset of "policies", and everything beyond (rate limit, JWT, retries, timeouts, circuit breaking) is an implementation CRD attached by `targetRefs` (Envoy Gateway: `BackendTrafficPolicy`, `SecurityPolicy`, `ClientTrafficPolicy`). Portable and typed beats annotations, but be honest: the advanced features are still implementation-specific.

**Envoy Gateway** (v1.9.2 here) installs the Gateway API CRDs for you (v1.6.1, the *experimental* channel: on top of the *standard* channel's GatewayClass, Gateway, HTTPRoute, GRPCRoute, ReferenceGrant, BackendTLSPolicy, TLSRoute and ListenerSet (all Standard since Gateway API v1.5) it adds TCPRoute/UDPRoute and the alpha `x-k8s.io` types). CRDs are cluster-wide, so this affects every other Gateway API controller on the cluster; in production pin one channel/version deliberately. It is a controller that watches the Gateway API resources and, for each Gateway, creates an Envoy proxy Deployment and a LoadBalancer Service **in its own namespace** (`envoy-gateway-system`, not in the Gateway's namespace). That namespace is what a NetworkPolicy must allow. Control plane (`envoy-gateway`) and data plane (Envoy proxies) are separate pods.

**GRPCRoute** (GA) matches on gRPC service/method (`matches: [{method: {service: orderflow.Orders, method: Create}}]`) and handles HTTP/2 end to end; Envoy balances per *request*, which fixes the per-connection pitfall above. The course services are plain HTTP, so you will read this, not run it.

**Observed live:** an `HTTPRoute` for a Service with zero endpoints makes Envoy return `503` and the route status reports `BackendsAvailable=False / EndpointsNotFound`; no route match returns `404`.

### 5. NetworkPolicy

Default Kubernetes network: flat and open, any pod to any pod in any namespace. A `NetworkPolicy` selects pods (`podSelector`) and states which traffic is *allowed* for the listed `policyTypes`. Rules:
- A pod is **isolated for a direction only if a policy selecting it lists that direction** in `policyTypes`. A pod with no policy at all is wide open.
- Policies are **additive (a union of allows)**; there is no deny rule and no ordering. Default-deny = an empty `podSelector: {}` policy with no rules.
- Stateful: reply packets of an allowed connection are allowed automatically.
- **Enforced by the CNI**, not the API server. kindnet and Calico/Cilium enforce; the Docker Desktop kubeadm provisioner accepts the objects and ignores them. Test enforcement every time.
- **AND vs OR:**
```yaml
from:
  - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: envoy-gateway-system}}
    podSelector:       {matchLabels: {app.kubernetes.io/name: envoy}}     # ONE item, two selectors = AND
from:
  - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: envoy-gateway-system}}
  - podSelector:       {matchLabels: {app.kubernetes.io/name: envoy}}     # TWO items = OR (whole namespace, OR this label in MY namespace)
```
  One missing indent turns "the proxy in that namespace" into "everything in that namespace".
- **Egress default-deny breaks DNS** (pods can no longer reach CoreDNS in `kube-system` on port 53 UDP+TCP). Always pair it with an explicit DNS allow. Observed live: with only the deny applied, `order-api` logs `context deadline exceeded` on its downstream calls; after adding the DNS and pod allows they work.
- `ipBlock` allows CIDRs (mostly for traffic leaving or entering the cluster; it is not for pod IPs, which are ephemeral).
- Selecting ports: `port` plus optional `endPort`; use the *container's* port, because policy is evaluated after the Service DNAT.
- Pods share their pod's labels with `kubectl debug` ephemeral containers, so a debug container is subject to the same policies as the pod it joins; that is why it is a faithful test client.
- **AdminNetworkPolicy / BaselineAdminNetworkPolicy** (out-of-tree CRDs from sig-network's `network-policy-api` project, `policy.networking.k8s.io`, still `v1alpha1`, CNI support varies): cluster-scoped policies written by admins with explicit Allow/Deny/Pass and ordering. ANP is evaluated *before* namespace NetworkPolicies, BANP *after* them as a baseline default. The project is consolidating these into a single ClusterNetworkPolicy API, so check the current state before adopting. They fix "a team can delete my guardrail"; not used here.

---

## Decision tree: Service & networking strategy

```
Need to expose a workload?
├── Within the cluster only?
│   ├── Load-balanced across replicas? ──► Service: ClusterIP (+ NetworkPolicy)
│   ├── Clients must pick pods / client-side balancing (DB replicas, gRPC)? ──► Headless
│   └── Alias for something outside the cluster? ──► ExternalName
└── To external clients?
    ├── HTTP / HTTPS / gRPC routing, TLS? ──► Gateway API (Gateway + HTTPRoute/GRPCRoute); Ingress only for legacy
    └── Raw TCP/UDP, other protocols? ──► Service: LoadBalancer (or TCPRoute/UDPRoute, still experimental)
NodePort: debugging only.
```

---

## Exercises

### Exercise 1 — The Empty Endpoints Mystery
`kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=order-api` shows no addresses, and the edge returns `503`. Give the most common causes, and explain what happens if instead the Service's `targetPort` is wrong.

**Hint:** Look at which pods the EndpointSlice controller considers, and what it does *not* validate.

**Solution sketch:**
1. **Selector mismatch:** `spec.selector` of the Service does not match the pod labels (`kubectl get pods --show-labels`). Live: selector `app: non-existent` leaves the slice with `ENDPOINTS <unset>` and Envoy returns 503.
2. **No *ready* pods:** pods match but fail readiness (or are not yet started), so they are in the slice as not-ready/excluded.
3. **The pods do not exist / are in another namespace** (Services only select pods in their own namespace).
A wrong *numeric* `targetPort` is **not** an empty-endpoints cause: the controller does not probe ports, so the slice keeps both pod IPs with the wrong port (live: `PORT 9999`) and clients get `connection refused`/reset (Envoy: `503 ... remote connection failure`). (A *named* `targetPort` that matches no container port does produce an empty slice.)

### Exercise 2 — The iptables Packet Trace
Trace an HTTP request from `order-api` to `payment-service`: which IP does DNS return, which destination is in the first packet, and where is it rewritten? What does conntrack do with the next packet of the same connection?

**Hint:** Run `iptables-save -t nat` on the node and follow `KUBE-SERVICES → KUBE-SVC → KUBE-SEP`.

**Solution sketch:** CoreDNS answers `payment-service.orderflow.svc.cluster.local` with the ClusterIP (e.g. `10.96.202.204`). The packet leaves the pod with that destination; on the node `KUBE-SERVICES` matches it, `KUBE-SVC-*` picks an endpoint with `statistic --mode random`, and `KUBE-SEP-*` DNATs to `10.244.0.67:8081`. conntrack stores the mapping, so later packets (and the replies) are translated without re-evaluating the chain: the choice is per connection.

### Exercise 3 — NetworkPolicy Egress Blindspot
You apply only an *Ingress* policy to protect `payment-service`. Can it still call an external API? Then you add a default-deny *Egress* policy. What breaks first, and why does it look like an application bug?

**Hint:** What does every outbound request need before it can open a TCP connection?

**Solution sketch:** Yes: egress is untouched unless `Egress` is in `policyTypes`. After a default-deny egress, **DNS** breaks first (UDP/TCP 53 to CoreDNS), so every call fails at name resolution (`lookup ...: no such host` or a resolve timeout), which looks like a broken Service. Add an allow to `kube-system` pods `k8s-app=kube-dns` on port 53 (UDP and TCP) plus the specific downstream allows.

### Exercise 4 — AND or OR?
Which of the two `from:` blocks in "NetworkPolicy" above would let a compromised pod in `orderflow` labelled `app.kubernetes.io/name: envoy` reach `order-api`? Which would let any pod in `envoy-gateway-system` reach it?

**Hint:** Count the list items (dashes).

**Solution sketch:** The OR version admits the compromised pod (second item matches any pod in `orderflow` with that label) and every pod in `envoy-gateway-system` (first item). The AND version admits neither: it needs both namespace and label.

### Exercise 5 — Why does the new replica get no traffic?
You scale a gRPC backend from 2 to 4 pods behind a ClusterIP Service; the new pods stay idle. Why, and what are two fixes?

**Hint:** Where is the load-balancing decision made, and when?

**Solution sketch:** kube-proxy balances per TCP connection when conntrack creates the entry; gRPC multiplexes all calls on one long-lived HTTP/2 connection, so existing clients stay pinned. Fix: an L7 proxy/mesh that balances per request (Envoy/GRPCRoute), or client-side balancing over a headless Service plus `MAX_CONNECTION_AGE` so clients re-resolve and reconnect.

---

## Anti-patterns / Common mistakes

1. **Standing up a new ingress-nginx:** the project is retired and has had a critical CVE (IngressNightmare). Use Gateway API; migrate with `ingress2gateway`.
2. **Putting every service on the edge:** only routes you write are reachable; keep `payment-service` and `notification-service` internal (no route) and add policies as the second layer.
3. **NodePort in production:** unmanaged ports on every node, bypassing WAF/TLS/DDoS controls.
4. **Hardcoding Pod IPs:** they change on every rollout. Use Service DNS.
5. **Trusting NetworkPolicy without testing it:** on a CNI that does not enforce it the objects are silently ignored. Run a deny test.
6. **Egress default-deny without a DNS allow**, and `namespaceSelector`/`podSelector` as two list items when AND was meant.
7. **Expecting a ClusterIP to balance requests:** it balances connections; long-lived HTTP/2 and keep-alive clients pin.
8. **Ignoring `ndots:5`** for chatty external calls (lower `ndots` via `dnsConfig` first; trailing-dot FQDNs only where Host/SNI matching allows).
9. **Reading `Endpoints` objects:** deprecated in 1.33; use EndpointSlices.

---

## Recall drill

1. Which component creates the pod's network interface: kubelet, containerd or the CNI plugin?
2. Name the three iptables chain types a ClusterIP packet traverses.
3. What does `externalTrafficPolicy: Local` preserve, and what is the cost?
4. In a NetworkPolicy, what is the difference between one `from` item with two selectors and two items?
5. Which Gateway API resource decides *who may attach routes*, and who owns it?
6. After default-deny egress, what is the first thing to allow?
7. Why does a gRPC client keep hitting the same pod after a scale-up?

<details><summary>Answers</summary>

1. The CNI plugin, invoked by the container runtime (CRI), not directly by kubelet.
2. `KUBE-SERVICES` → `KUBE-SVC-*` → `KUBE-SEP-*` (DNAT).
3. The client source IP and no extra hop; but nodes without a local pod receive no traffic, so uneven load and LB health-check dependence.
4. One item with two selectors = AND; two items = OR.
5. The `Gateway` listener's `allowedRoutes`; owned by the platform team.
6. DNS (UDP+TCP 53 to CoreDNS in kube-system).
7. kube-proxy picks a pod once per TCP connection (conntrack), and gRPC reuses one connection.
</details>

---

## Lab
See [`labs/day04/`](../labs/day04/).
- **The goal:** Install Envoy Gateway; expose `order-api` at `/orders` through a shared Gateway while `payment-service` stays unreachable from outside; demo a header match and weighted canary; lock the namespace down with NetworkPolicies (edge → order-api → payment/notification only); fix an egress default-deny that breaks DNS; read the kube-proxy rules and conntrack on the node.
- **Success signal:** `curl http://localhost/orders` returns `200` through the Gateway, `curl http://localhost/payments` returns `404`, a non-`order-api` pod times out connecting to `payment-service`, and the node shows the `KUBE-SVC` → `KUBE-SEP` DNAT chain.

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `kubectl get endpointslices -n <ns> -l kubernetes.io/service-name=<svc>` | Pod IPs behind a Service (replaces `get endpoints`) |
| `kubectl get gatewayclass,gateway -A` / `kubectl get httproute -A` | Edge state and attachment |
| `kubectl get httproute <r> -n <ns> -o yaml` | `status.parents[].conditions`: Accepted, ResolvedRefs, reasons |
| `kubectl get networkpolicy -n <ns>` | Active policies |
| `kubectl debug <pod> -n <ns> --image=curlimages/curl --target=<container> --profile=general` | Ephemeral test client sharing the pod's network namespace and labels (distroless-safe) |
| `docker exec desktop-control-plane iptables-save -t nat` | Docker Desktop kind node: kube-proxy rules |
| `docker exec desktop-control-plane conntrack -L -d <clusterIP>` | Connection-tracking entries for a Service |

---

## Teardown
Removes the app (and with it its Services, HTTPRoute and NetworkPolicies) but **keeps the edge** (Envoy Gateway, GatewayClass `eg`, Gateway `edge`): Days 6 and 7 reuse it.
```bash
bash labs/shared/reset.sh
kubectl delete namespace orderflow
```
Optional full uninstall of the edge (only when you are finished with Days 6-7):
```bash
kubectl delete -f labs/day04/manifests/gateway.yaml
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
kubectl get crd -o name | grep -E 'gateway.networking.(x-)?k8s.io|gateway.envoyproxy.io' | xargs kubectl delete
```
